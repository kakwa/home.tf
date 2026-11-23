# Generate an Ansible inventory for the infra VMs (same convention as
# terraform/inventory.tf). The generated file is overwritten on every apply;
# it is not tracked in git.
resource "local_file" "inventory" {
  content = templatefile("${path.module}/inventory.yml.tpl", {
    dns_vm            = var.dns_vm
    ldap_vm           = var.ldap_vm
    ansible_master_vm = var.ansible_master_vm
    vm_admin_user     = var.vm_admin_user
  })
  filename        = "${path.module}/inventory.yml"
  file_permission = "0644"
}
