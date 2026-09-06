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
  type    = "A"
  content = var.origin_ip
  proxied = true
  ttl     = 1
  comment = "wp-oci-free-stack: prod hostname alias"
}

resource "cloudflare_record" "dev" {
  zone_id = var.zone_id
  name    = var.dev_subdomain
  type    = "A"
  content = var.origin_ip # same origin as prod — nginx routes by Host header
  proxied = true
  ttl     = 1
  comment = "wp-oci-free-stack: dev (isolated PHP/DB, shared nginx only)"
}
