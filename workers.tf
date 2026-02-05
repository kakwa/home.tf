locals {
  worker_nodes = {
    for i in range(6) : "talos-worker-${i + 1}" => {
      memory_mb = 2048
      vcpu      = 2
    }
  }
}

# Create volumes for worker nodes
resource "libvirt_volume" "worker_disk" {
  for_each = local.worker_nodes

  name           = "${each.key}-disk.qcow2"
  pool           = var.storage_pool_name
  base_volume_id = libvirt_volume.talos_base.id
  size           = 107374182400 # 100GB in bytes
  format         = "qcow2"
}

# Create worker VMs
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

  network_interface {
    network_id     = libvirt_network.talos_network.id
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
