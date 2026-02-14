# Generated from Terraform. Talos node IPs from virsh domifaddr when VMs are running.

export CONTROL_PLANE_IP=(${join(" ", [for ip in control_plane_ips : "${"\""}${ip}${"\""}"])})
export WORKER_IP=(${join(" ", [for ip in worker_ips : "${"\""}${ip}${"\""}"])})
export CONTROL_PLANE_VIP="${control_plane_vip}"
