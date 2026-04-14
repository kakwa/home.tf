# MetalLB L2 pool manifest for init-traefik.sh (applied after metallb Helm release).

resource "local_file" "metallb_lan" {
  depends_on = [null_resource.k8s_config_dir]

  content = templatefile("${path.module}/templates/metallb-lan.yaml.tpl", {
    metallb_pool           = var.metallb_ip_pool
    namespace              = var.metallb_namespace
    metallb_l2_interfaces  = var.metallb_l2_interfaces
    metallb_l2_workers_only = var.metallb_l2_workers_only
  })
  filename = "${var.k8s_config_dir}/metallb-lan.yaml"

  file_permission = "0644"
}
