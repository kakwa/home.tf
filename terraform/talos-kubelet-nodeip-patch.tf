# Talos merge patch for talosctl gen config (init-talos.sh). Keeps kubelet node IP on cluster NIC (network_cidr).

resource "local_file" "talos_kubelet_nodeip_patch" {
  depends_on = [null_resource.k8s_config_dir]

  content = templatefile("${path.module}/templates/talos-kubelet-nodeip-patch.yaml.tpl", {
    network_cidr = var.network_cidr
  })
  filename        = "${var.k8s_config_dir}/talos-kubelet-nodeip-patch.yaml"
  file_permission = "0644"
}
