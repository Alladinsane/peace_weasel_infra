variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" { default = "us-chicago-1" }
variable "compartment_ocid" {}

variable "enable_dev_vm" {
  description = "Create the separate dev VM. Disable to destroy dev while preserving production."
  type        = bool
  default     = false
}

variable "availability_domain_index" {
  description = "Zero-based availability-domain index to try when placing the VM. Change this if OCI reports host capacity errors."
  type        = number
  default     = 0

  validation {
    condition     = var.availability_domain_index >= 0 && var.availability_domain_index == floor(var.availability_domain_index)
    error_message = "availability_domain_index must be a non-negative whole number."
  }
}

# Production is persistent and dev is an optional separate instance. The
# shared VCN/subnet is managed once; the A1 pool check covers both instances.
variable "ssh_public_key" {
  description = "Public key installed for interactive SSH access."
  type        = string
}

variable "instance_ocpus" {
  type    = number
  default = 1 # production allocation while optional dev is enabled

  validation {
    condition     = var.instance_ocpus > 0 && var.instance_ocpus <= 2 && var.instance_ocpus == floor(var.instance_ocpus)
    error_message = "instance_ocpus must be a whole number from 1 through 2."
  }
}

variable "instance_memory_gb" {
  type    = number
  default = 6

  validation {
    condition     = var.instance_memory_gb > 0 && var.instance_memory_gb <= 12
    error_message = "instance_memory_gb must be greater than 0 and no more than 12 GB."
  }
}

variable "dev_ocpus" {
  description = "Dev VM OCPU allocation; with prod enabled, keep the combined total within 2 OCPUs."
  type        = number
  default     = 1

  validation {
    condition     = var.dev_ocpus > 0 && var.dev_ocpus <= 2 && var.dev_ocpus == floor(var.dev_ocpus)
    error_message = "dev_ocpus must be a whole number from 1 through 2."
  }
}

variable "dev_memory_gb" {
  description = "Dev VM memory allocation; with prod enabled, keep the combined total within 12 GB."
  type        = number
  default     = 6

  validation {
    condition     = var.dev_memory_gb > 0 && var.dev_memory_gb <= 12
    error_message = "dev_memory_gb must be greater than 0 and no more than 12 GB."
  }
}

check "always_free_a1_pool" {
  assert {
    condition     = var.instance_ocpus + (var.enable_dev_vm ? var.dev_ocpus : 0) <= 2 && var.instance_memory_gb + (var.enable_dev_vm ? var.dev_memory_gb : 0) <= 12
    error_message = "The enabled A1 VMs exceed the current Always Free pool of 2 OCPUs and 12 GB RAM."
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
