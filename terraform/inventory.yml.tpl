# Ansible inventory generated from Terraform (inventory.yml.tpl).
# IPs from virsh domifaddr when VMs are running (qemu-guest-agent), else static vars.

all:
  children:
    utility:
      hosts:
        utility:
          ansible_host: ${utility_ip}

    debian:
      children:
        utility:

    talos_control_plane:
      hosts:
%{ for name, ip in talos_cp_ips ~}
%{ if ip != "" ~}
        ${name}:
          ansible_host: ${ip}
%{ else ~}
        ${name}: {}
%{ endif ~}
%{ endfor ~}

    talos_workers:
      hosts:
%{ for name, ip in talos_worker_ips ~}
%{ if ip != "" ~}
        ${name}:
          ansible_host: ${ip}
%{ else ~}
        ${name}: {}
%{ endif ~}
%{ endfor ~}

  vars:
    ansible_user: ${debian_admin_user}
