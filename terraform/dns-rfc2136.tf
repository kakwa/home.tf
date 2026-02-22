# Local DNS records for the cluster under int.<zone> (e.g. gateway-1.int.kakwalab.ovh).
# Uses RFC 2136 dynamic updates (e.g. BIND) with TSIG (HMAC-SHA512).
# for_each keys are static so that IPs (known only after apply) can be used in values.

locals {
  # Static records from variables (no -k8s): gateway-1, gateway-2, utility.
  dns_hosts_static = merge(
    { for k, v in var.gateway_static_ips : k => replace(v, "/24", "") },
    { "utility" = replace(var.utility_static_ip, "/24", "") }
  )
  # All DNS hosts: static (above) + -k8s suffixed (gateway, utility, talos cp/workers).
  dns_hosts = merge(
    local.dns_hosts_static,
    { for k, v in local.gateway_ips : "${k}-k8s" => v },
    { "utility-k8s" = local.utility_ip },
    { for k, v in local.talos_cp_ips : "${k}-k8s" => v },
    { for k, v in local.talos_worker_ips : "${k}-k8s" => v }
  )
  dns_host_keys = setunion(
    keys(local.dns_hosts_static),
    toset([for k in keys(local.gateway_ips) : "${k}-k8s"]),
    toset(["utility-k8s"]),
    toset([for k in keys(local.control_plane_nodes) : "${k}-k8s"]),
    toset([for k in keys(local.worker_nodes) : "${k}-k8s"])
  )
}

resource "dns_a_record_set" "cluster" {
  for_each  = local.dns_host_keys
  zone      = var.dns_zone
  name      = each.key
  addresses = [coalesce(lookup(local.dns_hosts, each.key, ""), "0.0.0.0")]
  ttl       = 300
}

resource "dns_a_record_set" "talos_k8s" {
  count     = var.dns_update_server != "" ? 1 : 0
  zone      = var.dns_zone
  name      = "talos-k8s"
  addresses = [var.control_plane_vip]
  ttl       = 300
}

# CNAME ldap.int.kakwalab.ovh -> utility.int.kakwalab.ovh (ldapcherry on utility VM)
resource "dns_cname_record" "ldap" {
  zone   = var.dns_zone
  name   = "ldap"
  cname  = "utility.${var.dns_zone}"
  ttl    = 300
}

output "cluster_fqdns" {
  description = "DNS names for cluster hosts under int.<zone>"
  value = {
    for k in local.dns_host_keys :
    k => "${k}.${var.dns_zone}"
  }
}
