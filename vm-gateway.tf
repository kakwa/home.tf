# Debian cloud image (Trixie = Debian 13)
locals {
  debian_image_filename = "debian-13-generic-amd64.qcow2"
  debian_image_url      = "https://cloud.debian.org/images/cloud/trixie/latest/${local.debian_image_filename}"
}

resource "utility_file_downloader" "debian_image" {
  url      = local.debian_image_url
  filename = "${var.talos_download_path}/${local.debian_image_filename}"
}

resource "libvirt_volume" "debian_base" {
  name   = "debian-base.qcow2"
  pool   = var.storage_pool_name
  source = utility_file_downloader.debian_image.filename
  format = "qcow2"

  depends_on = [utility_file_downloader.debian_image]
}

# Gateway VMs: 50GB disk, 2 NICs (bridge-network + talos)
locals {
  gateway_vms = {
    "gateway-1" = { memory_mb = 1024, vcpu = 2 }
    "gateway-2" = { memory_mb = 1024, vcpu = 2 }
  }
  gateway_disk_size = 50 * 1024 * 1024 * 1024 # 50GB
}

resource "libvirt_volume" "gateway_disk" {
  for_each = local.gateway_vms

  name           = "${each.key}-disk.qcow2"
  pool           = var.storage_pool_name
  base_volume_id = libvirt_volume.debian_base.id
  size           = local.gateway_disk_size
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "gateway_seed" {
  for_each = var.enable_cloudinit ? local.gateway_vms : {}

  name = "${each.key}-cloudinit"
  pool = var.storage_pool_name

  user_data = <<-EOF
    #cloud-config
    chpasswd:
      list: |
        root:password
      expire: false

    ssh_pwauth: true

    packages:
      - openssh-server

    timezone: UTC
  EOF

  meta_data = <<-EOF
    instance-id: ${each.key}
    local-hostname: ${each.key}
  EOF

  network_config = <<-EOF
    version: 2
    ethernets:
      ens3:
        dhcp4: false
      ens4:
        dhcp4: true
  EOF
}

resource "libvirt_domain" "gateway" {
  for_each = local.gateway_vms

  name   = each.key
  memory = each.value.memory_mb
  vcpu   = each.value.vcpu

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.gateway_disk[each.key].id
  }

  dynamic "disk" {
    for_each = var.enable_cloudinit ? [1] : []
    content {
      volume_id = regex("^[^;]+", libvirt_cloudinit_disk.gateway_seed[each.key].id)
    }
  }

  # First NIC: bridge-network (eth0)
  network_interface {
    network_id     = libvirt_network.bridge_network.id
    wait_for_lease = true
  }

  # Second NIC: talos network (eth1)
  network_interface {
    network_id     = libvirt_network.talos_network.id
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  video {
    type = "virtio"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
