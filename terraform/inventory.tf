# Generate Ansible inventory from Terraform VM definitions.
# IPs from libvirt provider (domain interface addresses) when VMs are running;
# fallback to virsh domifaddr (external script) then static (gateways + utility only).

# Provider-based IP discovery (same source as virsh domifaddr --source agent when source = "agent").
# Use domain name (not id): libvirt looks up by UUID or name; provider .id can be numeric domain id.
data "libvirt_domain_interface_addresses" "gateway" {
  for_each = local.gateway_vms
  domain   = libvirt_domain.gateway[each.key].name
  source   = "any"
}

data "libvirt_domain_interface_addresses" "utility" {
  domain = libvirt_domain.utility.name
  source = "any"
}

data "libvirt_domain_interface_addresses" "control_plane" {
  for_each = local.control_plane_nodes
  domain   = libvirt_domain.control_plane[each.key].name
  source   = "any"
}

data "libvirt_domain_interface_addresses" "workers" {
  for_each = local.worker_nodes
  domain   = libvirt_domain.workers[each.key].name
  source   = "any"
}

locals {
  inventory_domain_names = concat(
    keys(local.gateway_vms),
    ["utility"],
    keys(local.control_plane_nodes),
    keys(local.worker_nodes)
  )
  # First non-loopback IPv4 from first interface (provider); fallback to first addr.
  provider_gateway_ips = {
    for k in keys(local.gateway_vms) :
    k => try(
      [for a in data.libvirt_domain_interface_addresses.gateway[k].interfaces[0].addrs : a.addr if substr(coalesce(a.addr, ""), 1, 4) != "127."][0],
      try(data.libvirt_domain_interface_addresses.gateway[k].interfaces[0].addrs[0].addr, "")
    )
  }
  provider_utility_ip = try(
    [for a in data.libvirt_domain_interface_addresses.utility.interfaces[0].addrs : a.addr if substr(coalesce(a.addr, ""), 1, 4) != "127."][0],
    try(data.libvirt_domain_interface_addresses.utility.interfaces[0].addrs[0].addr, "")
  )
  provider_talos_cp_ips = {
    for k in keys(local.control_plane_nodes) :
    k => try(data.libvirt_domain_interface_addresses.control_plane[k].interfaces[0].addrs[0].addr, "")
  }
  provider_talos_worker_ips = {
    for k in keys(local.worker_nodes) :
    k => try(data.libvirt_domain_interface_addresses.workers[k].interfaces[0].addrs[0].addr, "")
  }
  # Discovered IPs from virsh domifaddr (fallback when provider has no IP, e.g. VM not running during apply)
  discovered_ips = data.external.domain_ips.result
  # Resolved: provider first, then virsh, then static (gateways + utility only)
  gateway_ips = {
    for k, v in var.gateway_static_ips :
    k => coalesce(lookup(local.provider_gateway_ips, k, ""), lookup(local.discovered_ips, k, ""), replace(v, "/24", ""))
  }
  utility_ip = coalesce(local.provider_utility_ip, lookup(local.discovered_ips, "utility", ""), replace(var.utility_static_ip, "/24", ""))
  talos_cp_ips = {
    for k in keys(local.control_plane_nodes) :
    k => coalesce(lookup(local.provider_talos_cp_ips, k, ""), lookup(local.discovered_ips, k, ""))
  }
  talos_worker_ips = {
    for k in keys(local.worker_nodes) :
    k => coalesce(lookup(local.provider_talos_worker_ips, k, ""), lookup(local.discovered_ips, k, ""))
  }
  # Ordered lists for env file (cp-1, cp-2, cp-3 and worker-1..worker-6)
  control_plane_ips_list = [for k in sort(keys(local.control_plane_nodes)) : lookup(local.talos_cp_ips, k, "")]
  worker_ips_list        = [for k in sort(keys(local.worker_nodes)) : lookup(local.talos_worker_ips, k, "")]
}

data "external" "domain_ips" {
  program = ["bash", "${path.module}/scripts/get-domain-ips.sh"]
  query = {
    domains = jsonencode(local.inventory_domain_names)
  }
}

resource "local_file" "inventory" {
  content = templatefile("${path.module}/inventory.yml.tpl", {
    gateway_ips         = local.gateway_ips
    utility_ip          = local.utility_ip
    control_plane_nodes = local.control_plane_nodes
    worker_nodes        = local.worker_nodes
    talos_cp_ips        = local.talos_cp_ips
    talos_worker_ips    = local.talos_worker_ips
    debian_admin_user   = var.debian_admin_user
  })
  filename        = "${path.module}/inventory.yml"
  file_permission = "0644"
}

resource "local_file" "env" {
  content = templatefile("${path.module}/env.tpl", {
    control_plane_ips = local.control_plane_ips_list
    worker_ips        = local.worker_ips_list
    control_plane_vip = var.control_plane_vip
  })
  filename        = "${path.module}/talos-env.sh"
  file_permission = "0644"
}
