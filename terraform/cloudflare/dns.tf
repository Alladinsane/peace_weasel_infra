resource "cloudflare_record" "prod" {
  zone_id = var.zone_id
  name    = var.prod_subdomain
  type    = "A"
  content = var.origin_ip
  proxied = true
  ttl     = 1
  comment = "wp-oci-free-stack: prod"
}

resource "cloudflare_record" "prod_alias" {
  count   = var.prod_alias_subdomain == null ? 0 : 1
  zone_id = var.zone_id
  name    = var.prod_alias_subdomain
  allow_overwrite = true
  type    = "A"
  content = var.origin_ip
  proxied = true
  ttl     = 1
  comment = "wp-oci-free-stack: prod hostname alias"
}

# www is created only when production includes the zone apex.
resource "cloudflare_record" "www" {
  count   = var.prod_subdomain == "@" || var.prod_alias_subdomain == "@" ? 1 : 0
  zone_id = var.zone_id
  allow_overwrite = true
  name    = "www"
  type    = "A"
  content = var.origin_ip
  proxied = true
  ttl     = 1
  comment = "wp-oci-free-stack: www alias for apex"
}

resource "cloudflare_record" "dev" {
  count   = var.dev_origin_ip == null ? 0 : 1
  zone_id = var.zone_id
  name    = var.dev_subdomain
  allow_overwrite = true
  type    = "A"
  content = var.dev_origin_ip
  proxied = true
  ttl     = 1
  comment = "wp-oci-free-stack: separately managed dev host"
}

