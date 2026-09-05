# Secrets inventory — none of this lives in the repo

## Local-only files (gitignored, never committed)
- `terraform/oci/terraform.tfvars`
- `terraform/cloudflare/terraform.tfvars`
- `docker/.env`, `docker/prod.env`, `docker/dev.env`
- `docker/nginx/certs/cloudflare-origin.{pem,key}`
- `~/.oci/oci_api_key.pem`, `~/.oci/config`

## GitHub → Settings → Environments
Create **two GitHub Environments**, `dev` and `prod`. Since both run on the
SAME host, SSH connection details are repository-level secrets (below);
everything that differs between the two environments (DB creds, PHP
version) is scoped per-Environment so a dev credential leak can't touch
prod's database.

### Repository-level secrets (shared — one host)
| Secret | Used by |
|---|---|
| `SSH_HOST` | deploy, backup, restore |
| `SSH_USER` | deploy, backup, restore (`ubuntu`) |
| `SSH_PRIVATE_KEY` | deploy, backup, restore — dedicated deploy key, not your personal key |
| `NGINX_ADMIN_IP` | deploy — your current IP; update when it changes |
| `CF_ORIGIN_CERT`, `CF_ORIGIN_KEY` | deploy — one cert covers both hostnames |
| `OCI_BACKUP_BUCKET` | deploy, backup, restore (`wp-backups`) |
| `OCI_CLI_CONFIG`, `OCI_CLI_KEY` | backup, restore — a user scoped to Object Storage only |

### Repository-level variables (non-secret, shared)
| Variable | Example |
|---|---|
| `PROD_HOST` | `shop.example.com` |
| `DEV_HOST` | `dev.shop.example.com` |
| `PHP_VERSION_PROD` | `8.3` |
| `PHP_VERSION_DEV` | `8.3` — bump this FIRST, test, then bump `PHP_VERSION_PROD` |

### Per-Environment secrets (`dev` Environment / `prod` Environment)
| Secret | Notes |
|---|---|
| `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` | generate independently for dev and prod — never reuse |
| `WORDPRESS_TABLE_PREFIX` | anything but `wp_` is a cheap hardening win |

Consider adding a required reviewer on the `prod` Environment in GitHub's
UI — that alone gets you a manual approval gate on every prod deploy at
no cost.

## Terraform's own state
State is remote (`wp-terraform-state` bucket, S3-compatible backend)
because state files contain resource attributes — including IPs — you
don't want in git history. Bootstrap that one bucket by hand once; see
`docs/ARCHITECTURE.md`. The backups bucket is Terraform-managed and needs
no manual step.
