# DNS records for the infra VMs under var.dns_zone (e.g. dns.int.kakwalab.ovh),
# pushed to BIND on the DNS VM via RFC 2136 dynamic updates with TSIG.
#
# Skipped entirely when dns_update_server is empty (no TSIG key configured):
# the for_each map is empty, so no DNS resources are created or touched.
# Values live in dns.auto.tfvars.json (gitignored).

provider "dns" {
  dynamic "update" {
    for_each = var.dns_update_server != "" ? [1] : []
    content {
      server        = var.dns_update_server
      port          = var.dns_update_port
      key_name      = var.dns_tsig_key_name != "" && !endswith(var.dns_tsig_key_name, ".") ? "${var.dns_tsig_key_name}." : var.dns_tsig_key_name
      key_algorithm = var.dns_tsig_key_algorithm
      key_secret    = var.dns_tsig_key_secret
    }
  }
}

locals {
  # A records for the infra VMs. Empty when DNS updates are not configured.
  dns_records = var.dns_update_server != "" ? {
    "dns"            = var.dns_vm.ip
    "ldap"           = var.ldap_vm.ip
    "ansible-master" = var.ansible_master_vm.ip
    "ns1"            = var.dns_vm.ip
  } : {}
}

resource "dns_a_record_set" "infra" {
  for_each  = local.dns_records
  zone      = var.dns_zone
  name      = each.key
  addresses = [each.value]
  ttl       = 3600
}

output "infra_fqdns" {
  description = "FQDNs of the infra VMs under var.dns_zone (empty when DNS updates are disabled)"
  value = {
    for k, v in local.dns_records : k => "${k}.${trimsuffix(var.dns_zone, ".")}"
  }
}
