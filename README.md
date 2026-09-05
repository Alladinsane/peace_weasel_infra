# wp-oci-free-stack

A fully free, engineered-not-duct-taped WordPress hosting setup with a
built-in **dev/prod split**: **Oracle Cloud Always Free** compute,
**Cloudflare Free** as the edge/WAF, **Docker Compose** for fully isolated
dev and prod LEMP stacks on one box, and **GitHub Actions** for deploy +
off-server backup/restore — with **zero dollars spent now or ever**, and
**zero secrets in this repo**.

## Stack
- **Compute**: ONE OCI `VM.Standard.A1.Flex` (Always Free ARM, full
  4 OCPU/24GB allotment) running both environments
- **Isolation**: dev and prod get their own PHP-FPM container, own
  MariaDB container, own file volumes — only nginx (edge routing) is
  shared, since only one process can bind 80/443
- **Edge**: Cloudflare free plan — proxied DNS for both hosts, free TLS,
  2 custom WAF rules (wp-login/wp-admin IP-lock, common WP recon blocks)
- **Backups**: DB dump + wp-content tarball per environment, to a
  dedicated Object Storage bucket (`wp-backups`, Always Free 10GB,
  shared with the separate `wp-terraform-state` bucket) — prod kept 14
  backups, dev kept 4, older ones archived (not deleted) for free
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
terraform/oci/          # single Always Free ARM instance + both buckets
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
   terraform apply
   ```
   Then `terraform/cloudflare`, feeding in the OCI output IP for both
   `prod_subdomain` and `dev_subdomain`.
4. Push to `dev` to stand up/update your test site, `main` for prod —
   `deploy.yml` builds and restarts only that environment's containers.

## The dev/prod workflow this is built for
Test a WordPress core update, a new plugin, or a PHP version bump on
`dev.yourdomain.com` first — bump `PHP_VERSION_DEV` in repo Variables,
push to `dev`, and dev's PHP-FPM/DB is entirely separate from prod's.
Happy with it? Do the same thing to `PHP_VERSION_PROD` and push to `main`.

## Reusing this for your own project
Nothing here is specific to any one site. Fork it, swap the domain and
hostnames in your own `tfvars`/Variables, point `git_repo_url` at your
fork, and it stands up the same dev/prod stack for you.
