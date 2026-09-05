# Architecture

```
                    ┌──────────────────────────────────────┐
 visitor ─HTTPS──▶  │  Cloudflare (free plan)               │
                    │  - proxied DNS for BOTH hosts          │
                    │  - 2 custom WAF rules, host-agnostic:  │
                    │    wp-login/admin IP-lock, path blocks │
                    └───────────────┬────────────────────────┘
                                    │ HTTPS (one Origin CA cert, both hosts)
                                    ▼
        ┌───────────────────────────────────────────────────────┐
        │  ONE OCI VM.Standard.A1.Flex (Always Free, 4 OCPU/24GB) │
        │                                                          │
        │  ufw: 22 (your IP only), 80, 443                        │
        │                                                          │
        │   nginx (only shared component — routes by Host header) │
        │     ├─ shop.example.com ──▶ php-prod ──▶ db-prod         │
        │     └─ dev.shop.example.com ▶ php-dev  ──▶ db-dev         │
        │                                                          │
        │   prod and dev have FULLY separate PHP-FPM containers,   │
        │   databases, and file volumes — a WP core bump, plugin,  │
        │   or PHP version change in dev cannot touch prod at all  │
        └───────────────────────────┬──────────────────────────────┘
                                    │ scheduled / on-demand, per environment
                                    ▼
       ┌───────────────────────┐        ┌────────────────────────┐
       │ Bucket: wp-terraform-  │        │ Bucket: wp-backups      │
       │ state                  │        │  - prod/<stamp>/...     │
       │  - created by hand,    │        │    kept 14, then        │
       │    once (chicken/egg)  │        │    archived at 45d      │
       │  - holds both oci/ and │        │  - dev/<stamp>/...      │
       │    cloudflare/ state   │        │    kept 4, then         │
       │                        │        │    archived at 45d      │
       └───────────────────────┘        └────────────────────────┘
       Both Standard-tier, sharing ONE 10GB Always Free pool —
       archiving old backups moves them to the SEPARATE 10GB
       Always Free Archive pool, so history doesn't eat the Standard quota.
```

## Why dev/prod share one instance instead of two
Running two full OCI instances would each need their own slice of the
4 OCPU / 24GB Always Free ceiling — workable, but it also means two
separate boxes to patch, monitor, and pay egress attention to. Hardcoding
to exactly two environments on one box keeps this simple and still gives
you real isolation where it matters: **PHP version, WordPress core,
plugins, and the database are all independent per environment.** Only
nginx (routing) and the underlying VM/network are shared.

## Multiple environments, concretely
- `terraform/cloudflare` creates two DNS records (`prod_subdomain`,
  `dev_subdomain`) pointing at the SAME origin IP — nginx does the
  routing, not DNS.
- `docker/docker-compose.yml` defines `db-prod`/`php-prod` and
  `db-dev`/`php-dev` as entirely separate services with separate named
  volumes. `deploy.yml` only ever builds/restarts the one environment
  it's targeting.
- `docker/prod.env` and `docker/dev.env` hold that environment's DB
  credentials; `docker/.env` holds the handful of values nginx and both
  build steps need regardless of which environment is deploying
  (`PHP_VERSION_PROD`, `PHP_VERSION_DEV`, the two hostnames, the admin IP).

## One-time manual bootstrap (can't be Terraform'd chicken-and-egg-free)
1. Create the **state bucket** (`wp-terraform-state`) in OCI Object Storage
   by hand — it has to exist before Terraform can use it as a backend.
2. The **backups bucket** (`wp-backups`) does NOT have this problem —
   `terraform/oci/storage.tf` creates and manages it, including the
   45-day archive lifecycle rule.
3. Generate a Cloudflare Origin CA certificate covering BOTH hostnames
   (or a wildcard) — one cert works for both nginx server blocks.
4. Generate a dedicated SSH keypair for GitHub Actions to deploy with.
5. Create two GitHub Environments, `dev` and `prod`, and populate secrets
   per `docs/SECRETS.md`.

## A note on the nginx templating mechanism
The official nginx image auto-renders `*.template` files in
`/etc/nginx/templates/` via `envsubst`, but only substitutes variable
names that actually exist in the container's environment — so nginx's own
runtime variables (`$uri`, `$host`, `$document_root`, etc.) are left alone.
Just don't ever name a container env var `host`, `uri`, or similar.

## Why Docker Compose instead of bare-metal LEMP
PHP is its own image/Dockerfile (`docker/php/Dockerfile`) with
`PHP_VERSION` as a build arg, independently set per environment
(`PHP_VERSION_DEV` vs `PHP_VERSION_PROD`) — bump dev's PHP version, test
your plugins against it, and only then bump prod's. nginx and MariaDB
likewise upgrade independently by bumping their image tags.
