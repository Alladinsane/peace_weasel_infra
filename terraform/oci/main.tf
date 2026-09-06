terraform {
  required_version = ">= 1.7.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }

  # Terraform state must never be committed (it contains IPs, and can contain
  # secrets rendered into resources). It lives in its OWN OCI Object Storage
  # bucket (S3-compatible API), separate from the backups bucket — created
  # once by hand (see docs/ARCHITECTURE.md) since a backend can't provision
  # the bucket it's about to store its own state in. Fill in bucket/key/region
  # via `terraform init -backend-config=...`, never hard-coded here.
  backend "s3" {
    # bucket, key, region, endpoints.s3 are supplied at `terraform init` time,
    # e.g.: terraform init -backend-config=state.backend.hcl
    # (state.backend.hcl is gitignored — see .gitignore's *.backend.hcl)
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}
