# Generate an Ansible inventory for the infra VMs (same convention as
# terraform/inventory.tf). The file is written into the ansible inventory
# directory so the VMs are part of the default inventory; it is overwritten
# on every apply and not tracked in git.
resource "local_file" "inventory" {
  content = templatefile("${path.module}/inventory.yml.tpl", {
    dns_vm            = var.dns_vm
    ldap_vm           = var.ldap_vm
    ansible_master_vm = var.ansible_master_vm
    registry_vm       = var.registry_vm
    vm_admin_user     = var.vm_admin_user
  })
  filename        = "${path.module}/../../ansible/inventory/infra.yml"
  file_permission = "0644"
}
