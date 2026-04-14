# Generated from Terraform. Talos node IPs from virsh domifaddr when VMs are running.
# DNS_* lines are POSIX-safe exports (same values as Terraform dns provider / dns.auto.tfvars).

export DNS_UPDATE_SERVER="${dns_update_server}"
export DNS_UPDATE_PORT="${dns_update_port}"
export DNS_ZONE="${dns_zone}"
export DNS_TSIG_KEY_NAME='${dns_tsig_key_name_sq}'
export DNS_TSIG_KEY_SECRET='${dns_tsig_key_secret_sq}'
export DNS_TSIG_KEY_ALGORITHM="${dns_tsig_key_algorithm}"

export CONTROL_PLANE_IP=(${join(" ", [for ip in control_plane_ips : "${"\""}${ip}${"\""}"])})
export WORKER_IP=(${join(" ", [for ip in worker_ips : "${"\""}${ip}${"\""}"])})
export CONTROL_PLANE_VIP="${control_plane_vip}"
