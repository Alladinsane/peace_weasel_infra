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
  count   = var.dev_origin_ip == null ? 0 : 1
  zone_id = var.zone_id
  name    = var.dev_subdomain
  type    = "A"
  content = var.dev_origin_ip
  proxied = true
  ttl     = 1
  comment = "wp-oci-free-stack: separately managed dev host"
}
