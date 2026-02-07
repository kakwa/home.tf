# Utility VM: 50GB disk, 2 NICs (bridge-network + talos), Debian

moved {
  from = libvirt_volume.gateway_disk["utility"]
  to   = libvirt_volume.utility_disk
}

moved {
  from = libvirt_cloudinit_disk.gateway_seed["utility"]
  to   = libvirt_cloudinit_disk.utility_seed[0]
}

moved {
  from = libvirt_domain.gateway["utility"]
  to   = libvirt_domain.utility
}

locals {
  utility_vm = {
    memory_mb = 1024
    vcpu      = 2
  }
  utility_disk_size = 50 * 1024 * 1024 * 1024 # 50GB
}

resource "libvirt_volume" "utility_disk" {
  name           = "utility-disk.qcow2"
  pool           = var.storage_pool_name
  base_volume_id = libvirt_volume.debian_base.id
  size           = local.utility_disk_size
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "utility_seed" {
  count = var.enable_cloudinit ? 1 : 0

  name = "utility-cloudinit"
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
    instance-id: utility
    local-hostname: utility
  EOF

  network_config = <<-EOF
    version: 2
    ethernets:
      eth0:
        dhcp4: true
      eth1:
        dhcp4: true
  EOF
}

resource "libvirt_domain" "utility" {
  name   = "utility"
  memory = local.utility_vm.memory_mb
  vcpu   = local.utility_vm.vcpu

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.utility_disk.id
  }

  dynamic "disk" {
    for_each = var.enable_cloudinit ? [1] : []
    content {
      volume_id = "${var.storage_pool_name}/${libvirt_cloudinit_disk.utility_seed[0].name}"
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
