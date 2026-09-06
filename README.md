# wp-oci-free-stack

A cost-controlled WordPress hosting setup with a built-in **dev/prod split**:
**Oracle Cloud Always Free** compute, **Cloudflare Free** as the edge/WAF,
separate Docker hosts for prod and optional dev, and **GitHub Actions** for
deployment plus off-server backup/restore. It is designed to stay within
Always Free resources, with no secrets in this repo.

## Stack
- **Compute**: one persistent prod `VM.Standard.A1.Flex` plus an optional
  separately managed dev VM. The current Always Free pool is 2 OCPUs/12 GB;
  defaults allocate 1 OCPU/6 GB to each while dev exists.
- **Isolation**: dev and prod have separate hosts, PHP-FPM containers,
  MariaDB containers, file volumes, and public IPs. Dev can be destroyed when
  not needed and recreated from an OCI backup.
- **Edge**: Cloudflare free plan — proxied DNS for both hosts, free TLS,
  2 custom WAF rules (wp-login/wp-admin IP-lock, common WP recon blocks)
- **Backups**: DB dump + wp-content tarball per environment to a dedicated
  Object Storage bucket (`wp-backups`), used as the transfer mechanism for
  dev refresh and promotion.
- **IaC**: Terraform for both OCI and Cloudflare, remote state in its own
  bucket (S3-compatible backend)
- **CI/CD**: GitHub Actions — `deploy.yml`, `backup.yml`, `restore.yml` —
  each targets exactly one environment without touching the other

See `docs/ARCHITECTURE.md` for the full diagram and `docs/SECRETS.md` for
exactly where every credential lives (spoiler: not here).

New to OCI or Cloudflare? Follow `docs/PROVIDER_SETUP.md` before running
Terraform; it covers credential creation, remote-state bootstrap, and the
required apply order.

## Layout
```
terraform/oci/          # prod VM + optional dev VM + both buckets
terraform/cloudflare/   # DNS for both hosts + free-tier WAF custom rules
docker/                 # docker-compose.yml: isolated db/php-prod + db/php-dev + shared nginx
scripts/                # backup.sh / restore.sh (+ their container image)
.github/workflows/      # deploy / backup / restore, each environment-scoped
docs/                   # architecture + secrets inventory
```

## Getting started
1. Read `docs/SECRETS.md` and `docs/ARCHITECTURE.md` first.
2. One-time manual bootstrap: the `wp-terraform-state` bucket, a Cloudflare
   Origin CA cert covering both hostnames, a dedicated deploy SSH key, and
   the `dev`/`prod` GitHub Environments.
3. ```
   cd terraform/oci
   cp terraform.tfvars.example terraform.tfvars   # fill in, gitignored
   terraform init -backend-config=state.backend.hcl
  terraform plan -out=tfplan
  terraform apply tfplan
  ```
  Then apply `terraform/cloudflare` with the production output IP. Enable
  dev later with `enable_dev_vm = true`, then add its output IP as
  `dev_origin_ip` before deploying dev.
4. Run the manual deployment workflow for the selected environment. Dev
  lifecycle is controlled by Terraform, not by stopping prod containers.

## The dev/prod workflow this is built for
Test a WordPress core update, a new plugin, or a PHP version bump on
`dev.peaceweasel.com`. Refresh dev from prod through the OCI backup bucket,
then promote the tested dev backup to prod. Destroy dev when finished and
recreate it later with Terraform.

## Reusing this for your own project
Nothing here is specific to any one site. Fork it, swap the domain and
hostnames in your own `tfvars`/Variables, point `git_repo_url` at your
fork, and it stands up the same dev/prod stack for you.
