locals {
  worker_nodes = {
    for i in range(6) : "talos-worker-${i + 1}" => {
      memory_mb = 2048
      vcpu      = 2
    }
  }
}

# Writable copy-on-write layer for worker VMs.
resource "libvirt_volume" "worker_disk" {
  for_each = local.worker_nodes

  name           = "${each.key}-disk.qcow2"
  pool           = var.storage_pool_name
  base_volume_id = libvirt_volume.talos_base.id
  size           = 107374182400 # 100GB
  format         = "qcow2"
}

# Cloud-init seed ISO (optional).
resource "libvirt_cloudinit_disk" "worker_seed" {
  for_each = var.enable_cloudinit ? local.worker_nodes : {}

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
      eth0:
        dhcp4: true
  EOF
}

# Virtual machine definition.
resource "libvirt_domain" "workers" {
  for_each = local.worker_nodes

  name   = each.key
  memory = each.value.memory_mb
  vcpu   = each.value.vcpu

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.worker_disk[each.key].id
  }

  dynamic "disk" {
    for_each = var.enable_cloudinit ? [1] : []
    content {
      volume_id = regex("^[^;]+", libvirt_cloudinit_disk.worker_seed[each.key].id)
    }
  }

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
