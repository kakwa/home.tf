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

# Talos base image in mid-pool (libvirt pulls directly from Image Factory URL).
resource "libvirt_volume" "talos_base" {
  name = "talos-base.qcow2"
  pool = var.storage_pool_name
  create = {
    content = {
      url = local.talos_image_url
    }
  }
  target = {
    format = { type = "qcow2" }
  }
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
  description = "Path to the Talos base image in pool"
  value       = libvirt_volume.talos_base.path
}

output "talos_image_url" {
  description = "Direct download URL for the Talos image"
  value       = local.talos_image_url
}
