variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" { default = "us-chicago-1" }
variable "compartment_ocid" {}

# Hardcoded dev/prod design: ONE OCI instance runs both stacks (Docker
# Compose services db-prod/php-prod and db-dev/php-dev, fronted by one
# shared nginx). There is deliberately no per-environment instance count —
# that's what keeps this on the Always Free 4 OCPU / 24GB ceiling.
variable "ssh_public_key" {
  description = "Public key installed for interactive SSH access."
  type        = string
}

variable "instance_ocpus" {
  type    = number
  default = 4 # full Always Free A1 allotment — this is the only instance

  validation {
    condition     = var.instance_ocpus > 0 && var.instance_ocpus <= 4 && var.instance_ocpus == floor(var.instance_ocpus)
    error_message = "instance_ocpus must be a whole number from 1 through 4 to stay within the Always Free A1 allotment."
  }
}

variable "instance_memory_gb" {
  type    = number
  default = 24

  validation {
    condition     = var.instance_memory_gb > 0 && var.instance_memory_gb <= 24
    error_message = "instance_memory_gb must be greater than 0 and no more than 24 GB to stay within the Always Free A1 allotment."
  }
}

variable "admin_ssh_cidr" {
  description = "CIDR allowed to reach port 22. Use your own IP/32, never 0.0.0.0/0."
  type        = string
}

variable "git_repo_url" {
  description = "HTTPS URL of this repo, cloned by cloud-init on first boot."
  type        = string
}

variable "git_repo_branch" {
  type    = string
  default = "main"
}
