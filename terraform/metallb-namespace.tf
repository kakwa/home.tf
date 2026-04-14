# Namespace with PSA privileged — MetalLB speaker/FRR cannot satisfy pod-security restricted.

resource "local_file" "metallb_namespace" {
  depends_on = [null_resource.k8s_config_dir]

  content = templatefile("${path.module}/templates/metallb-namespace.yaml.tpl", {
    namespace = var.metallb_namespace
  })
  filename        = "${var.k8s_config_dir}/metallb-namespace.yaml"
  file_permission = "0644"
}
