# CLOUDFLARE_API_TOKEN is read from the environment — never put it in a
# .tfvars file. Scope the token to Zone:DNS:Edit, Zone:WAF:Edit,
# and Zone:Bot Management:Edit for this zone only.
provider "cloudflare" {}


terraform {
  required_version = ">= 1.7.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}


