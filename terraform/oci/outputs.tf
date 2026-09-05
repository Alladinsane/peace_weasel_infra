output "instance_public_ip" {
  value       = oci_core_instance.wp.public_ip
  description = "Feed this into the Cloudflare Terraform (A record target) for this environment."
}

output "instance_ocid" {
  value = oci_core_instance.wp.id
}
