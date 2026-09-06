# Two buckets, both Standard tier, sharing the tenancy's single Always Free
# 10GB Standard Object Storage allowance:
#   - state:   holds *.tfstate for both terraform/oci and terraform/cloudflare
#   - backups: holds dev/ and prod/ backup archives (scripts/backup.sh)
# The state bucket has a chicken-and-egg problem (this module's own state
# would need to live in it before it exists) so it's created ONCE by hand —
# see docs/ARCHITECTURE.md. The backups bucket has no such problem and is
# safely managed here.

data "oci_objectstorage_namespace" "this" {
  compartment_id = var.compartment_ocid
}

resource "oci_objectstorage_bucket" "backups" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = "wp-backups"
  storage_tier   = "Standard"

  lifecycle {
    prevent_destroy = true
  }

}

# Moves backups older than 45 days into the Archive tier, which draws from
# its OWN separate 10GB Always Free allowance — so long-term backup history
# doesn't eat into the same 10GB Standard pool the state bucket shares.
# Backups are never deleted automatically; archived history is slower to
# restore because Archive objects require a restore request before reading.
resource "oci_objectstorage_object_lifecycle_policy" "backups_expiry" {
  bucket    = oci_objectstorage_bucket.backups.name
  namespace = data.oci_objectstorage_namespace.this.namespace

  rules {
    name        = "expire-after-45-days"
    action      = "ARCHIVE"
    time_amount = 45
    time_unit   = "DAYS"
    is_enabled  = true
    target      = "objects"
  }
}

output "backups_bucket_name" {
  value = oci_objectstorage_bucket.backups.name
}

output "object_storage_namespace" {
  value = data.oci_objectstorage_namespace.this.namespace
}
