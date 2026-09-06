# Always Free eligible image; verify current Ubuntu 22.04 Minimal aarch64 OCID
# for your region at https://docs.oracle.com/iaas/images/ and pin it here —
# using a data source instead of a hard-coded OCID avoids drift silently
# pulling in an image outside the Always Free list.
data "oci_core_images" "ubuntu_arm" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "wp" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "wp-host"
  shape               = "VM.Standard.A1.Flex" # Always Free ARM shape

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu_arm.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.this.id
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = join("\n", [
      var.ssh_public_key
    ])
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tpl", {
      git_repo_url    = var.git_repo_url
      git_repo_branch = var.git_repo_branch
      admin_ssh_cidr  = var.admin_ssh_cidr
    }))
  }

  # Boot volume is the only thing that persists on the instance itself.
  # It is NOT the backup strategy — see scripts/backup.sh + backup.yml,
  # which push WP DB + uploads off-box to Object Storage on a schedule.
  freeform_tags = {
    project = "wp-oci-free-stack"
  }

  lifecycle {
    # Prevent an accidental plan from destroying the only host and its local
    # Docker volumes. Intentional replacement requires removing this guard.
    prevent_destroy = true
  }
}
