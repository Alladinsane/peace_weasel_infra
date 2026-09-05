# Bot Fight Mode is available on the Cloudflare Free plan. It challenges
# likely automated traffic before it reaches the OCI origin and does not use
# one of the five Custom Rules slots in waf.tf.
resource "cloudflare_zone_settings_override" "bot_fight_mode" {
  zone_id = var.zone_id

  settings {
    bot_fight_mode = "on"
  }
}