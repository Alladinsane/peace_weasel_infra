resource "cloudflare_ruleset" "wp_custom_waf" {
  zone_id     = var.zone_id
  name        = "wp-custom-waf"
  description = "Maximized Free-Tier WordPress + WooCommerce WAF"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  # --------------------------------------------------------------------------
  # RULE 1: Bypass / Allow Printify & Legitimate Webhooks
  # Priority 1: Prevent false-positive blocks/challenges on store automation.
  # --------------------------------------------------------------------------
  rules {
    description = "Allow Printify Webhooks and WooCommerce API calls"
    expression  = "(starts_with(http.request.uri.path, \"/wp-json/wc/\") or starts_with(http.request.uri.path, \"/wc-api/\")) and (http.user_agent contains \"Printify\" or http.request.headers[\"authorization\"][0] ne \"\")"
    action      = "skip"
    action_parameters {
      ruleset = "current"
    }
    enabled     = true

    logging {
      enabled = true
    }
  }

  # --------------------------------------------------------------------------
  # RULE 2: Lock wp-admin / wp-login to Admin IP
  # --------------------------------------------------------------------------
  rules {
    description = "Block wp-login and wp-admin except from trusted admin IP"
    expression  = "(http.request.uri.path contains \"/wp-login.php\" or (http.request.uri.path contains \"/wp-admin\" and not http.request.uri.path contains \"/wp-admin/admin-ajax.php\")) and ip.src ne ${var.admin_ip}"
    action      = "block"
    enabled     = true
  }

  # --------------------------------------------------------------------------
  # RULE 3: Consolidated Exploit, Recon & Scraper Block
  # Drops all known probe vectors in ONE rule so Nginx never sees them.
  # --------------------------------------------------------------------------
  rules {
    description = "Block exploits, uploads execution, recon, and user enumeration"
    expression  = join(" or ", [
      "http.request.uri.path contains \"/xmlrpc.php\"",
      "http.request.uri.path contains \"/wp-config.php\"",
      "http.request.uri.path contains \"/.env\"",
      "http.request.uri.path contains \"/.git\"",
      "(starts_with(lower(http.request.uri.path), \"/wp-content/uploads/\") and ends_with(lower(http.request.uri.path), \".php\"))",
      "http.request.uri.query contains \"author=\"",
      "starts_with(http.request.uri.path, \"/wp-json/wp/v2/users\")"
    ])
    action      = "block"
    enabled     = true
  }

  # --------------------------------------------------------------------------
  # RULE 4: Managed Challenge on Untrusted Dynamic Spikes / Bad Threat Scores
  # Cloudflare scores visitor threat levels (0-100). Catch automated headless browsers.
  # --------------------------------------------------------------------------
  rules {
    description = "Challenge suspicious visitors and high threat scores on dynamic routes"
    expression  = "cf.threat_score gt 14 and not starts_with(http.request.uri.path, \"/wp-content/\") and not starts_with(http.request.uri.path, \"/wp-includes/\")"
    action      = "managed_challenge"
    enabled     = true
  }

  # --------------------------------------------------------------------------
  # RULE 5: Protect WooCommerce Cart / Checkout / Search Floods
  # Attackers flood cart/search to exhaust PHP workers with heavy DB queries.
  # --------------------------------------------------------------------------
  rules {
    description = "Challenge aggressive scrapers hitting WooCommerce dynamic queries"
    expression  = "(http.request.uri.query contains \"s=\" or starts_with(http.request.uri.path, \"/cart\") or starts_with(http.request.uri.path, \"/checkout\")) and cf.client.bot"
    action      = "managed_challenge"
    enabled     = true
  }
}