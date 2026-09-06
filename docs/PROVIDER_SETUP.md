# First-time OCI and Cloudflare setup

This project uses three separate credentials. Keep each credential in its
intended location; none belongs in Git.

Use Terraform 1.7 or newer. The OCI S3-compatible backend requires the
`skip_s3_checksum` option, which older Terraform versions do not support.

There is no requirement to create every GitHub secret before the first
Terraform apply. Bootstrap in phases: Terraform creates the VM first, that
VM produces the public IP needed by the later steps, and GitHub deployment
secrets are added only after the VM and Cloudflare origin certificate exist.

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

Because OCI Object Storage is S3-compatible rather than Amazon S3, keep
`skip_s3_checksum = true` in both backend configuration files. Without it,
Terraform may use AWS chunked encoding, which OCI rejects with
`AWS chunked encoding not supported`.

If applying the backups bucket lifecycle rule returns
`InsufficientServicePermissions`, have a tenancy administrator add an OCI
policy for the regional Object Storage service principal. For Chicago, the
policy is:

```text
Allow service objectstorage-us-chicago-1 to manage object-family in compartment <project-compartment-name>
```

Use the actual compartment name and region in that policy. The policy is for
OCI's service principal, not for your Terraform user's customer secret key.

The OCI Terraform module keeps production persistent and can create a
separate dev VM on demand. The current Always Free A1 pool is 2 OCPUs and
12 GB RAM total, so the defaults allocate 1 OCPU/6 GB to each while dev exists.
Terraform rejects enabled VM sizes above that pool. The dev VM is intentionally
destroyable; its recovery source is the OCI backup bucket. The production VM
and managed backups bucket should only be destroyed as an explicit recovery
decision.

These checks do not enforce tenancy-wide billing. They cannot prevent costs
from resources created outside this module, unexpected network egress, or an
OCI account exceeding its free allowance through another workload. Review the
OCI Console's cost analysis and budgets before treating the account as cost
bounded.

The Compose resource budget reserves most of the machine for production:
`db-prod` is capped at 1.5 CPU/8 GB, `php-prod` at 1 CPU/3 GB, `db-dev` at
0.75 CPU/4 GB, `php-dev` at 0.5 CPU/2 GB, and nginx at 0.25 CPU/256 MB. Dev is
normally stopped, so those limits protect production when dev is enabled.

## Runner bootstrap

The VM can host a self-hosted GitHub Actions runner without opening SSH to
GitHub's changing runner IP ranges. Register it manually after first boot:

1. In GitHub, open **Settings > Actions > Runners > New self-hosted runner**
   for this repository and choose Linux/ARM64.
2. SSH to the VM with the admin key and follow GitHub's displayed commands in
   `/opt/actions-runner`. The registration token is short-lived and must never
   be placed in Terraform, cloud-init, or the repository.
3. Give the runner a dedicated label such as `peaceweasel` and install it as
   a service. Keep workflows manual-only and require approval for production.
4. Configure the runner service with a systemd CPU and memory limit so a job
   cannot consume production's reserved headroom. Remove the old offline
   runner from GitHub before registering its replacement after a VM rebuild.

The workflows now run on the self-hosted prod runner. Production operations
connect to `127.0.0.1`; dev operations use `SSH_HOST_DEV_PRIVATE` over the
private OCI network. GitHub-hosted runners are no longer used for deployment
or data operations.

The bootstrap helper is in `scripts/bootstrap-runner.sh`. On the production VM,
run it as root with the short-lived token supplied directly in the shell:

```sh
sudo -i
export RUNNER_REPO=OWNER/REPOSITORY
export RUNNER_TOKEN='token shown by GitHub'
/opt/wp-stack/scripts/bootstrap-runner.sh
```

When dev exists, register a second runner on the dev VM with a distinct label
such as `peaceweasel-dev`; a runner on prod cannot execute commands inside dev
without private-network access.

Fill the OCI `terraform.tfvars` values from step 1. Set `ssh_public_key` to
the public half of your SSH key, `admin_ssh_cidr` to your current public IP
with `/32`, and point `git_repo_url` at your fork.

## 3. Create a scoped Cloudflare token

1. Add your domain as a Cloudflare zone and change its registrar nameservers
   to the two names Cloudflare assigns. Wait until the zone status is active.
2. Go to **My Profile > API Tokens > Create Token > Create Custom Token**.
3. Grant **Zone > DNS > Edit**, **Zone > WAF > Edit**, and
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

### Phase A: create OCI infrastructure

At this point you need only the local OCI API signing key, the OCI S3
customer-secret profile, the manually created state bucket, and
`terraform/oci/terraform.tfvars`.

Run the OCI stack first, review the plan, then apply it:

```sh
cd terraform/oci
terraform init -backend-config=state.backend.hcl
terraform plan
terraform apply
terraform output -raw prod_instance_public_ip
```

Save the output. It becomes GitHub's `SSH_HOST_PROD` and Cloudflare's
`origin_ip`. The first boot installs Docker, Compose, the firewall, swap, and
the repository, but intentionally starts no application containers.

### Phase B: create Cloudflare records and the origin certificate

Put the saved production IP into `terraform/cloudflare/terraform.tfvars` as
`origin_ip`, set `prod_subdomain = "prod"` and `dev_subdomain = "dev"`, then apply the
Cloudflare stack:

```sh
cd ../cloudflare
terraform init -backend-config=state.backend.hcl
terraform plan
terraform apply
```

Terraform will create the backups bucket; only the state bucket is created
manually. In Cloudflare, create an Origin CA certificate covering
`peaceweasel.com` and `*.peaceweasel.com`, then keep its certificate and key
ready for GitHub secrets `CF_ORIGIN_CERT` and `CF_ORIGIN_KEY`.

### Phase C: add GitHub deployment configuration

Now create the GitHub repository secrets and variables listed in
`docs/SECRETS.md`. The values that depended on earlier phases are:

| GitHub value | Set it to |
|---|---|
| `SSH_HOST_PROD` | OCI `prod_instance_public_ip` output |
| `SSH_USER` | `ubuntu` |
| `OCI_BACKUP_BUCKET` | `wp-backups` |
| `CF_ORIGIN_CERT` | Cloudflare Origin CA certificate PEM |
| `CF_ORIGIN_KEY` | Cloudflare Origin CA private key PEM |

The SSH private key, database credentials, Cloudflare token, OCI CLI config,
and OCI CLI key are generated or obtained independently; Terraform does not
produce them. Add them to GitHub only after generating them locally and never
commit them.

### Phase D: first application deployment

Run **Actions > Deploy > Run workflow**, select the `main` branch, and choose
`prod`. This writes the runtime files and starts only the production database
and PHP containers plus nginx. WordPress then becomes available at
`https://prod.peaceweasel.com` for its browser installation. Deploy dev later
when you are ready.

## Optional dev VM lifecycle

To create dev, set `enable_dev_vm = true` in `terraform/oci/terraform.tfvars`
and apply a fresh Terraform plan. Capture `dev_instance_public_ip`, set it as
Cloudflare `dev_origin_ip`, and save it as GitHub's `SSH_HOST_DEV`. Then run
the dev deployment workflow.

Before destroying dev, run **Actions > Backup** for `dev`. Set
`enable_dev_vm = false` and apply a fresh plan to destroy only the dev VM.
Production remains untouched. The dev VM's local volumes disappear, so the
OCI backup archive is the recovery source.

To recreate dev, enable it again, apply Terraform, update `dev_origin_ip` and
`SSH_HOST_DEV`, deploy dev, and run **Actions > Refresh Dev From Prod**. That
workflow transfers production through OCI backups and rewrites URLs for the
dev hostname. Promotion works in the opposite direction.

Each VM runs only the environment deployed to its own SSH host. When dev is
destroyed, its DNS record should be removed by setting `dev_origin_ip = null`;
the dev hostname is unavailable until the VM is recreated.

## 5. Promote, refresh, and cut over

For the first production deployment, run **Actions > Deploy > Run workflow**,
select the `main` branch, and choose `prod`. Start dev only after its VM and
DNS record exist.

Use **Actions > Promote Dev to Prod** after testing changes in dev. It requires
the exact confirmation `PROMOTE_DEV_TO_PROD`, creates off-server backups,
restores dev's database and `wp-content` into prod through OCI, rewrites the
dev hostname to `PROD_HOST`, and restarts production. Configure a required
reviewer on the `prod` GitHub Environment before using promotion.

Because production content changes independently, use **Actions > Refresh Dev
From Prod** to make a new dev baseline after the initial production site is
ready or whenever desired. It requires `REFRESH_DEV_FROM_PROD`, backs up the
current dev site first, copies production's database and `wp-content` into dev
through OCI, rewrites WordPress URLs for `DEV_HOST`, and starts dev. It does
not modify production.

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
