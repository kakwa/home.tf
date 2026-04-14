# Examples: patch Talos machine config so the 2nd NIC (bridge / 192.168.1.x) gets a static address.
# First NIC stays the default for the cluster (${cluster_network_cidr}). Confirm link name on the node:
#   talosctl get links -n <node-talos-ip>
# If not eth1, replace interface below. Do not add a default route here unless you intend split routing.
# kubelet.nodeIP pins InternalIP to the cluster subnet so pods can reach apiserver via ClusterIP (10.96.0.1).
%{ for name in worker_name_list ~}
# ----- ${name} (${worker_lan_ips[name]}) -----
# talosctl patch machineconfig --nodes <${name} Talos IP on ${cluster_network_cidr}> --patch "$(cat <<'PATCH'
machine:
  network:
    interfaces:
      - interface: eth1
        addresses:
          - ${worker_lan_ips[name]}
  kubelet:
    nodeIP:
      validSubnets:
        - ${cluster_network_cidr}
# PATCH
# )"
---
%{ endfor ~}
