# First-time OCI and Cloudflare setup

This project uses three separate credentials. Keep each credential in its
intended location; none belongs in Git.

| Purpose | Credential | Where it is used |
|---|---|---|
| Provision OCI resources | OCI API signing key | `terraform/oci` provider |
| Store Terraform state | OCI customer secret key / auth token | Terraform S3 backend |
| Manage DNS and WAF | Cloudflare API token | `terraform/cloudflare` provider |

## 1. Create OCI credentials

1. In the OCI Console, note your tenancy OCID, your user OCID, and the OCID
   of the compartment where this stack will live. They are available from
   **Profile** and **Identity & Security > Compartments**.
2. Generate an RSA API signing key locally and protect it with a passphrase:
   ```sh
   mkdir -p ~/.oci
   openssl genrsa -out ~/.oci/oci_api_key.pem 2048
   openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem
   ```
3. In **Profile > User settings > API keys**, add the public key. OCI shows
   the fingerprint; copy it into `terraform/oci/terraform.tfvars`.
4. In **Profile > User settings > Customer secret keys**, generate a key and
   save its access key ID and secret immediately. Export them only in the
   shell where Terraform runs:
   ```sh
   export AWS_ACCESS_KEY_ID='your-oci-customer-secret-access-key-id'
   export AWS_SECRET_ACCESS_KEY='your-oci-customer-secret-key'
   ```

Your OCI user needs permission to manage the resources declared by this
stack in its target compartment, plus Object Storage access to the state
bucket. Start with a dedicated user or group rather than an administrator
account. OCI tenancy policies vary, so have a tenancy administrator grant
the least permissions needed for Compute, Networking, and Object Storage.

## 2. Bootstrap remote Terraform state

Terraform cannot create the bucket that holds its own first state file.
In **OCI Console > Object Storage & Archive Storage > Buckets**, select the
same region as `terraform/oci/terraform.tfvars` and create a Standard bucket
named `wp-terraform-state`. Do not make it public.

Find the Object Storage namespace in the bucket details or **Tenancy details**.
Then create the local backend files:

```sh
cd terraform/oci
cp state.backend.hcl.example state.backend.hcl
cp terraform.tfvars.example terraform.tfvars

cd ../cloudflare
cp state.backend.hcl.example state.backend.hcl
cp terraform.tfvars.example terraform.tfvars
```

In both `state.backend.hcl` files, replace `<object-storage-namespace>` and
use the OCI region that you selected. Leave the two different `key` values in
place: they prevent the OCI and Cloudflare stacks from overwriting each other.

The OCI Terraform module is deliberately guarded to one Always Free
`VM.Standard.A1.Flex` instance with at most 4 OCPUs and 24 GB RAM. Terraform
also refuses to destroy that instance or the managed backups bucket during a
normal destroy or replacement. Removing those protections should be an
explicit, reviewed recovery decision.

These checks do not enforce tenancy-wide billing. They cannot prevent costs
from resources created outside this module, unexpected network egress, or an
OCI account exceeding its free allowance through another workload. Review the
OCI Console's cost analysis and budgets before treating the account as cost
bounded.

Fill the OCI `terraform.tfvars` values from step 1. Set
`admin_ssh_public_key` to your personal public key and
`deploy_ssh_public_key` to the public half of the dedicated GitHub Actions
deployment key. Set `admin_ssh_cidr` to your current public IP with `/32`,
and point `git_repo_url` at your fork.

## 3. Create a scoped Cloudflare token

1. Add your domain as a Cloudflare zone and change its registrar nameservers
   to the two names Cloudflare assigns. Wait until the zone status is active.
2. Go to **My Profile > API Tokens > Create Token > Create Custom Token**.
3. Grant **Zone > DNS > Edit**, **Zone > Firewall Services > Edit**, and
   **Zone > Bot Management > Edit**. Scope all permissions to only this zone.
   The Bot Management permission enables Cloudflare Free Bot Fight Mode.
   Create the token and export it:
   ```sh
   export CLOUDFLARE_API_TOKEN='your-cloudflare-api-token'
   ```
4. Find the zone ID in the zone's Overview page and put it in
   `terraform/cloudflare/terraform.tfvars`. Choose the production and dev
   labels (for example `shop` and `dev`) and set `admin_ip` to your public IP.

## 4. Apply in dependency order

Run the OCI stack first, review the plan, then apply it:

```sh
cd terraform/oci
terraform init -backend-config=state.backend.hcl
terraform plan
terraform apply
terraform output -raw instance_public_ip
```

Put that output into `terraform/cloudflare/terraform.tfvars` as `origin_ip`.
Then apply the Cloudflare stack:

```sh
cd ../cloudflare
terraform init -backend-config=state.backend.hcl
terraform plan
terraform apply
```

Terraform will create the backups bucket; only the state bucket is created
manually. Continue with the Origin CA certificate and GitHub Environment
configuration in `docs/SECRETS.md` before the first deployment.

Each `dev` or `prod` deployment can run by itself. It starts that
environment's database and PHP containers plus the shared nginx edge. You can
later stop either isolated stack without interrupting the other; its hostname
will return a 502 response until that stack is started again.

To pause one environment after both are deployed, SSH to the instance and run:

```sh
cd /opt/wp-stack/docker
docker compose --profile dev stop
```

This leaves `prod` and nginx running. Substitute `prod` to pause production.
Restart an environment with `docker compose --profile dev up -d`; its named
database and WordPress volumes are preserved while it is stopped.

## 5. Start prod, promote dev, and cut over

For the first production deployment, run **Actions > Deploy > Run workflow**,
select the `main` branch, and choose `prod`. This creates only the production
database and PHP runtime plus nginx. Start development later by running the
same workflow from the `dev` branch and choosing `dev`.

Use **Actions > Manage Dev Runtime** to start or stop development when it is
not needed. Stopping dev leaves production and nginx running; only the dev
hostname returns 502.

Use **Actions > Promote Dev to Prod** after testing changes in dev. It requires
the exact confirmation `PROMOTE_DEV_TO_PROD`, creates an off-server production
backup, replaces production's database and `wp-content` with dev's, rewrites
the dev hostname to `PROD_HOST` in WordPress data, and restarts production.
It stops dev by default. Configure a required reviewer on the `prod` GitHub
Environment before using promotion.

Because production content changes independently, use **Actions > Refresh Dev
From Prod** to make a new dev baseline after the initial production site is
ready or whenever desired. It requires `REFRESH_DEV_FROM_PROD`, backs up the
current dev site first, copies production's database and `wp-content` into dev,
rewrites WordPress URLs for `DEV_HOST`, and starts dev. It does not modify
production.

**Restore** defaults to validation only. After confirming that a backup passes,
run it again with `validate_only` disabled and type `RESTORE_DEV` or
`RESTORE_PROD` for the selected target. The workflow creates a new off-server
backup of that target before it can overwrite any data.

Set `PROD_HOST` to the canonical public hostname and optionally set
`PROD_HOST_ALIASES` to additional hostnames nginx should serve. For a future
cutover from `prod.example.com` to `example.com`, obtain an Origin CA
certificate covering both names, set
`PROD_HOST=example.com` and `PROD_HOST_ALIASES=prod.example.com`, deploy prod,
then change WordPress's `home` and `siteurl` to `https://example.com`.

`prod_alias_subdomain = "@"` creates the apex record only for the Cloudflare
zone in `zone_id`. It creates `example.com` only when Cloudflare manages the
entire `example.com` zone. If Cloudflare manages a delegated child zone such
as `shop.example.com`, `@` means `shop.example.com`; your spouse must instead
change the `example.com` record at their existing DNS provider for the final
cutover. That apex traffic will not receive Cloudflare protection unless the
full parent zone is later moved to Cloudflare.
