# Helm values for init-traefik.sh (in-cluster Traefik).

resource "local_file" "traefik_helm_values" {
  depends_on = [null_resource.k8s_config_dir]

  content = templatefile("${path.module}/templates/traefik-helm-values.yaml.tpl", {
    service_type         = var.traefik_service_type
    web_node_port        = var.traefik_web_node_port
    websecure_node_port  = var.traefik_websecure_node_port
  })
  filename        = "${var.k8s_config_dir}/traefik-helm-values.yaml"
  file_permission = "0644"
}
