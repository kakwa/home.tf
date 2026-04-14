# Applied by init-talos.sh: talosctl gen config ... --config-patch @talos-kubelet-nodeip-patch.yaml (see talos-kubelet-nodeip-patch.tf).
# Pin kubelet --node-ip to the cluster data-plane subnet (${network_cidr}) so multi-homed workers
# (Talos NAT + LAN bridge) do not register the LAN address as InternalIP, which can break pod→ClusterIP→apiserver.
machine:
  kubelet:
    nodeIP:
      validSubnets:
        - ${network_cidr}
