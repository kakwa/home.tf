# Reference patches for worker LAN (bridge) addresses — keys must match worker VMs.

check "worker_lan_ips_match_workers" {
  assert {
    condition = (
      length(var.worker_lan_static_ips) == length(local.worker_nodes) &&
      length(setsubtract(toset(keys(var.worker_lan_static_ips)), toset(keys(local.worker_nodes)))) == 0
    )
    error_message = "worker_lan_static_ips keys must match talos-worker-* names in vm-workers exactly (same set)."
  }
}

resource "local_file" "talos_worker_lan_examples" {
  depends_on = [null_resource.k8s_config_dir]

  content = templatefile("${path.module}/templates/talos-worker-lan.examples.yaml.tpl", {
    worker_name_list = sort(keys(local.worker_nodes))
    worker_lan_ips   = var.worker_lan_static_ips
  })
  filename        = "${var.k8s_config_dir}/talos-worker-lan.examples.yaml"
  file_permission = "0644"
}
