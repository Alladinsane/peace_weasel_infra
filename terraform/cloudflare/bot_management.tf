# Bot Fight Mode is available on the Cloudflare Free plan. It challenges
# likely automated traffic before it reaches the OCI origin and does not use
# one of the five Custom Rules slots in waf.tf.
resource "cloudflare_bot_management" "this" {
  zone_id    = var.zone_id
  enable_js  = true
  fight_mode = true
}