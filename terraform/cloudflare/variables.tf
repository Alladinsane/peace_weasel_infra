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