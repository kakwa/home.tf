# Ensure k8s output directory exists before writing talos-env.sh and Helm values.

resource "null_resource" "k8s_config_dir" {
  triggers = {
    path = var.k8s_config_dir
  }

  provisioner "local-exec" {
    command = "mkdir -p '${replace(var.k8s_config_dir, "'", "'\\''")}'"
  }
}
