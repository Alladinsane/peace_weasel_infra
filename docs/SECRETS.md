# Secrets inventory — none of this lives in the repo

## SSH key custody

Use one Ed25519 keypair for this small deployment. Keep the private key on
your computer and in the GitHub repository secret `SSH_PRIVATE_KEY`; put only
its public key in Terraform as `ssh_public_key`. Terraform does not create,
store, or upload the private key.

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
| `SSH_HOST_PROD` | deploy, backup, restore, promotion, dev refresh (production VM) |
| `SSH_HOST_DEV` | deploy, backup, restore, promotion, dev refresh (dev VM, after it is created) |
| `SSH_HOST_DEV_PRIVATE` | self-hosted production runner's private-network address for dev deploys |
| `SSH_USER` | deploy, backup, restore, promotion, dev refresh (`ubuntu`) |
| `SSH_PRIVATE_KEY` | deploy, backup, restore, promotion, dev refresh — dedicated deploy key, not your personal key |
| `NGINX_ADMIN_IP` | deploy — your current IP; update when it changes |
| `CF_ORIGIN_CERT`, `CF_ORIGIN_KEY` | deploy — one cert covers both hostnames |
| `OCI_BACKUP_BUCKET` | deploy, backup, restore, promotion, dev refresh (`wp-backups`) |
| `OCI_CLI_CONFIG`, `OCI_CLI_KEY` | backup, restore, promotion, dev refresh — a user scoped to Object Storage only |

### Repository-level variables (non-secret, shared)
| Variable | Example |
|---|---|
| `PROD_HOST` | `shop.example.com` |
| `PROD_HOST_ALIASES` | `example.com` (empty until cutover) |
| `DEV_HOST` | `dev.shop.example.com` |
| `PHP_VERSION_PROD` | `8.3` |
| `PHP_VERSION_DEV` | `8.3` — bump this FIRST, test, then bump `PHP_VERSION_PROD` |

`SSH_HOST_DEV` and Cloudflare `dev_origin_ip` are intentionally absent while
the dev VM is destroyed. Add/update them after Terraform creates dev; remove
the DNS record when dev is destroyed.

### Per-Environment secrets (`dev` Environment / `prod` Environment)
| Secret | Notes |
|---|---|
| `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` | generate independently for dev and prod — never reuse |
| `WORDPRESS_TABLE_PREFIX` | anything but `wp_` is a cheap hardening win |

Use the same non-default `WORDPRESS_TABLE_PREFIX` in both environments. Their
database users, passwords, databases, and volumes stay separate; matching the
prefix allows the guarded promotion workflow to copy the dev database without
rewriting WordPress table names.

Consider adding a required reviewer on the `prod` Environment in GitHub's
UI — that alone gets you a manual approval gate on every prod deploy at
no cost.

## Terraform's own state
State is remote (`wp-terraform-state` bucket, S3-compatible backend)
because state files contain resource attributes — including IPs — you
don't want in git history. Bootstrap that one bucket by hand once; see
`docs/ARCHITECTURE.md`. The backups bucket is Terraform-managed and needs
no manual step.
