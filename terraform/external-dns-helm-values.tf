# Helm values for init-external-dns.sh (RFC 2136 + env-based TSIG; no secrets in this file).

locals {
  external_dns_dns_zone_label = trimsuffix(var.dns_zone, ".")
}

resource "local_file" "external_dns_helm_values" {
  depends_on = [null_resource.k8s_config_dir]

  content = templatefile("${path.module}/templates/external-dns-helm-values.yaml.tpl", {
    rfc2136_host   = var.dns_update_server
    rfc2136_port   = tostring(var.dns_update_port)
    dns_zone_label = local.external_dns_dns_zone_label
    tsig_algorithm = var.dns_tsig_key_algorithm
    txt_owner_id   = var.external_dns_txt_owner_id
    policy         = var.external_dns_policy
    sources        = var.external_dns_sources
  })
  filename        = "${var.k8s_config_dir}/external-dns-helm-values.yaml"
  file_permission = "0644"
}
