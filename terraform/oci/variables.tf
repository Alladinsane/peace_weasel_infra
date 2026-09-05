variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" { default = "us-ashburn-1" }
variable "compartment_ocid" {}

# Hardcoded dev/prod design: ONE OCI instance runs both stacks (Docker
# Compose services db-prod/php-prod and db-dev/php-dev, fronted by one
# shared nginx). There is deliberately no per-environment instance count —
# that's what keeps this on the Always Free 4 OCPU / 24GB ceiling.
variable "ssh_public_key" {
  description = "Public key installed on the instance for the 'ubuntu' user."
  type        = string
}

variable "instance_ocpus" {
  type    = number
  default = 4 # full Always Free A1 allotment — this is the only instance
}

variable "instance_memory_gb" {
  type    = number
  default = 24
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
