# Debian cloud base image (Trixie) for utility VM backing store.

locals {
  debian_image_filename = "debian-13-generic-amd64.qcow2"
  debian_image_url      = "https://cloud.debian.org/images/cloud/trixie/latest/${local.debian_image_filename}"
  debian_sudoers_cloudinit = var.debian_sudoers_admin != "" ? join("\n", [
    "    write_files:",
    "      - path: /etc/sudoers.d/admin",
    "        content: |",
    "          ${indent(10, var.debian_sudoers_admin)}",
    "        permissions: '0400'",
    "        owner: root:root",
    ""
  ]) : ""
}

resource "libvirt_volume" "debian_base" {
  name = "debian-base.qcow2"
  pool = var.storage_pool_name
  create = {
    content = {
      url = local.debian_image_url
    }
  }
  target = {
    format = { type = "qcow2" }
  }
}
