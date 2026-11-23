output "dns_vm" {
  description = "DNS VM identity"
  value = {
    name = var.dns_vm.name
    id   = var.dns_vm.vm_id
    ip   = var.dns_vm.ip
  }
}

output "ldap_vm" {
  description = "LDAP VM identity"
  value = {
    name = var.ldap_vm.name
    id   = var.ldap_vm.vm_id
    ip   = var.ldap_vm.ip
  }
}
