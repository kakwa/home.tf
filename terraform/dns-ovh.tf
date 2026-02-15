# Public DNS names for the cluster under int.<zone> (e.g. gateway-1.int.kakwalab.ovh).
# Requires OVH_APPLICATION_KEY, OVH_APPLICATION_SECRET, OVH_CONSUMER_KEY.
# for_each keys are static so that IPs (known only after apply) can be used in values.

locals {
  ovh_dns_hosts = merge(
    local.gateway_ips,
    { "utility" = local.utility_ip },
    local.talos_cp_ips,
    local.talos_worker_ips
  )
  # Static key set for for_each; values (IPs) may be unknown until apply.
  ovh_dns_host_keys = setunion(
    keys(var.gateway_static_ips),
    ["utility"],
    keys(local.control_plane_nodes),
    keys(local.worker_nodes)
  )
}

resource "ovh_domain_zone_record" "cluster" {
  for_each  = local.ovh_dns_host_keys
  zone      = var.ovh_zone
  subdomain = "${each.key}.${var.ovh_int_subdomain}"
  fieldtype = "A"
  target    = coalesce(lookup(local.ovh_dns_hosts, each.key, ""), "0.0.0.0")
  ttl       = 300
}

resource "ovh_domain_zone_record" "talos_k8s" {
  zone      = var.ovh_zone
  subdomain = "talos-k8s.${var.ovh_int_subdomain}"
  fieldtype = "A"
  target    = var.control_plane_vip
  ttl       = 300
}

# CNAME ldap.int.kakwalab.ovh -> utility.int.kakwalab.ovh (ldapcherry on utility VM)
resource "ovh_domain_zone_record" "ldap_cname" {
  zone      = var.ovh_zone
  subdomain = "ldap.${var.ovh_int_subdomain}"
  fieldtype = "CNAME"
  target    = "utility.${var.ovh_int_subdomain}.${var.ovh_zone}"
  ttl       = 300
}

output "ovh_cluster_fqdns" {
  description = "Public DNS names for cluster hosts under int.<zone>"
  value = {
    for k in local.ovh_dns_host_keys :
    k => "${k}.${var.ovh_int_subdomain}.${var.ovh_zone}"
  }
}
