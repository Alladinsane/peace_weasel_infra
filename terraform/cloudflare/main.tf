terraform {
  required_version = ">= 1.5.0"

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
    force_path_style            = true
  }
}

# CLOUDFLARE_API_TOKEN is read from the environment — never put it in a
# .tfvars file. Scope the token to Zone:DNS:Edit, Zone:Firewall Services:Edit,
# and Zone:Zone Settings:Edit for this zone only.
provider "cloudflare" {}

variable "zone_id" {
  description = "Cloudflare Zone ID for the domain you already own."
  type        = string
}

variable "prod_subdomain" {
  description = "e.g. 'shop' for shop.example.com"
  type        = string
}

variable "dev_subdomain" {
  description = "e.g. 'dev' for dev.shop.example.com — your safe space to test upgrades/plugins"
  type        = string
}

variable "origin_ip" {
  description = "Public IP of the single OCI instance (Terraform OCI output) — same for both records, nginx routes by hostname."
  type        = string
}

variable "admin_ip" {
  description = "Your IP, allowed to reach /wp-login.php and /wp-admin on both hosts."
  type        = string
}
