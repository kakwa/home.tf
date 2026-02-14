# Generated from Terraform. Talos node IPs from virsh domifaddr when VMs are running.

CONTROL_PLANE_IP=(${join(" ", [for ip in control_plane_ips : "${"\""}${ip}${"\""}"])})
WORKER_IP=(${join(" ", [for ip in worker_ips : "${"\""}${ip}${"\""}"])})
CONTROL_PLANE_VIP="${control_plane_vip}"