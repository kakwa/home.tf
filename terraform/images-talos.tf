# Talos Image Factory Configuration
data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_version
  filters = {
    names = var.talos_extensions
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = var.talos_extensions
      }
    }
  })
}

locals {
  talos_image_filename = "talos-${talos_image_factory_schematic.this.id}-${var.talos_version}-${var.talos_platform}-${var.talos_architecture}.qcow2"
  talos_image_url      = "https://factory.talos.dev/image/${talos_image_factory_schematic.this.id}/${var.talos_version}/${var.talos_platform}-${var.talos_architecture}.qcow2"
}

# Download the Talos image locally
resource "utility_file_downloader" "talos_image" {
  url      = local.talos_image_url
  filename = "${var.talos_download_path}/${local.talos_image_filename}"
}

# Base Talos image in the storage pool.
resource "libvirt_volume" "talos_base" {
  name   = "talos-base.qcow2"
  pool   = var.storage_pool_name
  source = utility_file_downloader.talos_image.filename
  format = "qcow2"

  depends_on = [utility_file_downloader.talos_image]
}

# Outputs
output "talos_image_factory_url" {
  description = "Talos Factory URL for the custom image"
  value       = "https://factory.talos.dev/?arch=${var.talos_architecture}&extensions=${join("&extensions=", [for ext in var.talos_extensions : replace(ext, "/", "%2F")])}&platform=${var.talos_platform}&target=cloud&version=${trimprefix(var.talos_version, "v")}"
}

output "talos_schematic_id" {
  description = "Talos Image Factory Schematic ID"
  value       = talos_image_factory_schematic.this.id
}

output "talos_image_path" {
  description = "Path to the downloaded Talos image"
  value       = utility_file_downloader.talos_image.filename
}

output "talos_image_url" {
  description = "Direct download URL for the Talos image"
  value       = local.talos_image_url
}
