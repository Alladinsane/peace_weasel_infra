# Architecture

```text
visitor -> Cloudflare -> prod.peaceweasel.com -> persistent prod VM
                      -> dev.peaceweasel.com  -> optional dev VM

prod VM: 1 OCPU/6 GB default, nginx + PHP-FPM + MariaDB + prod volumes
dev VM:  1 OCPU/6 GB default, nginx + PHP-FPM + MariaDB + dev volumes

Both VMs share the OCI VCN/subnet and the off-server OCI backup bucket.
Dev is created and destroyed by Terraform; refresh and promotion transfer
backups through Object Storage.
```

## Resource model

The current Always Free A1 pool is 2 OCPUs and 12 GB RAM total. Terraform
allocates 1 OCPU and 6 GB to each VM while dev exists. When dev is destroyed,
production may be resized within the same pool if desired.

The production VM is persistent. The dev VM is disposable: its local Docker
volumes disappear when Terraform destroys it. The authoritative recovery path
for both environments is the `wp-backups` Object Storage bucket.

The VCN, subnet, route table, internet gateway, and security list are shared
network infrastructure. SSH is restricted to the administrator CIDR; HTTP and
HTTPS are public so Cloudflare can reach each origin.

## Data movement

- `backup.yml` creates a database dump and `wp-content` archive under
  `prod/<timestamp>/` or `dev/<timestamp>/`.
- `refresh-dev-from-prod.yml` backs up prod, restores that archive on dev, and
  rewrites URLs to the dev hostname.
- `promote-dev-to-prod.yml` backs up dev and prod, restores dev into prod, and
  rewrites URLs to the production hostname.
- `restore.yml` defaults to validation-only and requires an explicit target
  confirmation before overwriting an environment.

No promotion or refresh depends on Docker volumes being mounted on the same
host.

## Bootstrap

1. Create the state bucket manually; Terraform cannot create its own backend.
2. Apply `terraform/oci` with `enable_dev_vm = false` to create the network,
   backup bucket, and persistent production VM.
3. Apply `terraform/cloudflare` with the production IP. Add `dev_origin_ip`
   only after the dev VM exists.
4. Deploy prod manually through GitHub Actions.
5. For testing, set `enable_dev_vm = true`, apply Terraform, add the dev IP to
   Cloudflare and GitHub, and deploy dev.
6. Back up dev, set `enable_dev_vm = false`, and apply Terraform to destroy
   dev. Recreate and refresh it from prod later.

## Runner

A self-hosted runner may be installed on the production VM after bootstrap so
GitHub does not need inbound SSH from changing GitHub-hosted runner IPs. Keep
runner registration manual because its token is short-lived, and constrain
its systemd CPU and memory usage. Do not enable self-hosted workflows until
the runner is installed and the workflows have been converted from SSH actions
to local commands.
