# Cloudflare Free plan gives you 5 "Custom Rules" (the free-tier WAF) — no
# Managed Ruleset / OWASP Core Ruleset, which is Pro+ only. These rules cover
# BOTH hosts (dev and prod share the same zone-level ruleset) — the IP-lock
# and recon-path blocks apply regardless of which one is being hit.

resource "cloudflare_ruleset" "wp_custom_waf" {
  zone_id     = var.zone_id
  name        = "wp-custom-waf"
  description = "Free-tier custom WAF rules for WordPress (dev + prod)"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules {
    description = "Block wp-login/wp-admin except from admin IP, on either host"
    expression  = "(http.request.uri.path contains \"/wp-login.php\" or (http.request.uri.path contains \"/wp-admin\" and not http.request.uri.path contains \"/wp-admin/admin-ajax.php\")) and ip.src ne ${var.admin_ip}"
    action      = "block"
    enabled     = true
  }

  rules {
    description = "Block common WP recon/exploit paths not otherwise in use"
    expression  = "http.request.uri.path contains \"/xmlrpc.php\" or http.request.uri.path contains \"/wp-config.php\" or http.request.uri.path contains \"/.env\""
    action      = "block"
    enabled     = true
  }

  rules {
    description = "Block PHP execution attempts from WordPress uploads"
    expression  = "starts_with(lower(http.request.uri.path), \"/wp-content/uploads/\") and ends_with(lower(http.request.uri.path), \".php\")"
    action      = "block"
    enabled     = true
  }

  rules {
    description = "Block unusual HTTP methods not used by WordPress"
    expression  = "http.request.method in {\"CONNECT\" \"TRACE\" \"TRACK\"}"
    action      = "block"
    enabled     = true
  }

  rules {
    description = "Block public WordPress user enumeration"
    expression  = "http.request.uri.query contains \"author=\" or http.request.uri.path contains \"/wp-json/wp/v2/users\""
    action      = "block"
    enabled     = true
  }
}
