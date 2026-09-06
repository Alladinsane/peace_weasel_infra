output "prod_instance_public_ip" {
  value       = oci_core_instance.prod.public_ip
  description = "Production VM public IP."
}

output "prod_instance_private_ip" {
  value       = oci_core_instance.prod.private_ip
  description = "Production VM private IP."
}

output "prod_instance_ocid" {
  value = oci_core_instance.prod.id
}

output "dev_instance_public_ip" {
  value       = var.enable_dev_vm ? oci_core_instance.dev[0].public_ip : null
  description = "Optional dev VM public IP."
}

output "dev_instance_private_ip" {
  value       = var.enable_dev_vm ? oci_core_instance.dev[0].private_ip : null
  description = "Optional dev VM private IP for runner-to-dev SSH."
}

output "dev_instance_ocid" {
  value = var.enable_dev_vm ? oci_core_instance.dev[0].id : null
}
