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

# CLOUDFLARE_API_TOKEN is read from the environment — never put it in a
# .tfvars file. Scope the token to Zone:DNS:Edit, Zone:WAF:Edit,
# and Zone:Bot Management:Edit for this zone only.
provider "cloudflare" {}

variable "zone_id" {
  description = "Cloudflare Zone ID for the domain you already own."
  type        = string
}

variable "prod_subdomain" {
  description = "e.g. 'prod' for prod.peaceweasel.com"
  type        = string
}

variable "prod_alias_subdomain" {
  description = "Optional second production record, e.g. '@' for the zone apex. Leave null until cutover."
  type        = string
  default     = null
}

variable "dev_subdomain" {
  description = "e.g. 'dev' for dev.peaceweasel.com"
  type        = string
}

variable "origin_ip" {
  description = "Public IP of the production OCI instance."
  type        = string
}

variable "dev_origin_ip" {
  description = "Optional public IP of the separately managed dev VM. Leave null while dev is destroyed."
  type        = string
  default     = null
}

variable "admin_ip" {
  description = "Your IP, allowed to reach /wp-login.php and /wp-admin on both hosts."
  type        = string
}
