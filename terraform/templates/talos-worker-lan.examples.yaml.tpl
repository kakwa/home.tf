# Examples: patch Talos machine config so the 2nd NIC (bridge / 192.168.1.x) gets a static address.
# First NIC stays the default for the cluster (192.168.100.x). Confirm link name on the node:
#   talosctl get links -n <node-talos-ip>
# If not eth1, replace interface below. Do not add a default route here unless you intend split routing.
%{ for name in worker_name_list ~}
# ----- ${name} (${worker_lan_ips[name]}) -----
# talosctl patch machineconfig --nodes <${name} Talos IP on 192.168.100.x> --patch "$(cat <<'PATCH'
machine:
  network:
    interfaces:
      - interface: eth1
        addresses:
          - ${worker_lan_ips[name]}
# PATCH
# )"
---
%{ endfor ~}
