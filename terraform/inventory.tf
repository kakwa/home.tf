# Generate Ansible inventory from Terraform VM definitions.
# IPs are discovered via virsh domifaddr (qemu-guest-agent); fallback to static variables.

locals {
  inventory_domain_names = concat(
    keys(local.gateway_vms),
    ["utility"],
    keys(local.control_plane_nodes),
    keys(local.worker_nodes)
  )
  # Discovered IPs from virsh domifaddr --source agent (empty if VM not running or agent unavailable)
  discovered_ips = data.external.domain_ips.result
  # Resolved IPs: discovered when available, else static (gateways + utility)
  gateway_ips = {
    for k, v in var.gateway_static_ips :
    k => coalesce(lookup(local.discovered_ips, k, ""), replace(v, "/24", ""))
  }
  utility_ip = coalesce(lookup(local.discovered_ips, "utility", ""), replace(var.utility_static_ip, "/24", ""))
  talos_cp_ips = {
    for k in keys(local.control_plane_nodes) :
    k => lookup(local.discovered_ips, k, "")
  }
  talos_worker_ips = {
    for k in keys(local.worker_nodes) :
    k => lookup(local.discovered_ips, k, "")
  }
  # Ordered lists for env file (cp-1, cp-2, cp-3 and worker-1..worker-6)
  control_plane_ips_list = [for k in sort(keys(local.control_plane_nodes)) : lookup(local.talos_cp_ips, k, "")]
  worker_ips_list       = [for k in sort(keys(local.worker_nodes)) : lookup(local.talos_worker_ips, k, "")]
}

data "external" "domain_ips" {
  program = ["bash", "${path.module}/scripts/get-domain-ips.sh"]
  query = {
    domains = jsonencode(local.inventory_domain_names)
  }
}

resource "local_file" "inventory" {
  content = templatefile("${path.module}/inventory.yml.tpl", {
    gateway_ips        = local.gateway_ips
    utility_ip         = local.utility_ip
    control_plane_nodes = local.control_plane_nodes
    worker_nodes       = local.worker_nodes
    talos_cp_ips       = local.talos_cp_ips
    talos_worker_ips   = local.talos_worker_ips
    debian_admin_user  = var.debian_admin_user
  })
  filename        = "${path.module}/inventory.yml"
  file_permission = "0644"
}

resource "local_file" "env" {
  content = templatefile("${path.module}/env.tpl", {
    control_plane_ips = local.control_plane_ips_list
    worker_ips       = local.worker_ips_list
  })
  filename        = "${path.module}/talos-env.sh"
  file_permission = "0644"
}
