# Set of security group rules to allow known IPS from Cloudflare

# Network Security Group for the web instance
resource "oci_core_network_security_group" "web_origin" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "nsg-wp-cloudflare-origin"
}

# 1. Allow Inbound HTTPS (443) ONLY from Cloudflare
resource "oci_core_network_security_group_security_rule" "ingress_cloudflare_https" {
  count                     = length(var.cloudflare_ipv4_cidrs)
  network_security_group_id = oci_core_network_security_group.web_origin.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source_type               = "CIDR_BLOCK"
  source                    = var.cloudflare_ipv4_cidrs[count.index]
  description               = "Allow Cloudflare Edge Proxy HTTPS"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

# 2. Allow Inbound HTTP (80) ONLY from Cloudflare (for HTTP -> HTTPS redirects)
resource "oci_core_network_security_group_security_rule" "ingress_cloudflare_http" {
  count                     = length(var.cloudflare_ipv4_cidrs)
  network_security_group_id = oci_core_network_security_group.web_origin.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source_type               = "CIDR_BLOCK"
  source                    = var.cloudflare_ipv4_cidrs[count.index]
  description               = "Allow Cloudflare Edge Proxy HTTP"

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

# 3. Allow SSH (22) ONLY from your Admin CIDR
resource "oci_core_network_security_group_security_rule" "ingress_admin_ssh" {
  network_security_group_id = oci_core_network_security_group.web_origin.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source_type               = "CIDR_BLOCK"
  source                    = var.admin_ssh_cidr
  description               = "Allow SSH from trusted admin IP"

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# 4. Standard Egress (Allow all outbound traffic)
resource "oci_core_network_security_group_security_rule" "egress_all" {
  network_security_group_id = oci_core_network_security_group.web_origin.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination_type          = "CIDR_BLOCK"
  destination               = "0.0.0.0/0"
  description               = "Allow full outbound connectivity"
}