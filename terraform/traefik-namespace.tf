resource "local_file" "traefik_namespace" {
  depends_on = [null_resource.k8s_config_dir]

  content = templatefile("${path.module}/templates/traefik-namespace.yaml.tpl", {
    namespace = var.traefik_namespace
  })
  filename        = "${var.k8s_config_dir}/traefik-namespace.yaml"
  file_permission = "0644"
}
