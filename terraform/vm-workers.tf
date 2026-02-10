locals {
  worker_nodes = {
    for i in range(6) : "talos-worker-${i + 1}" => {
      memory_mb = 2048
      vcpu      = 2
    }
  }
}

# Boot disk per worker VM (backing store = talos_base, grows as needed).
resource "libvirt_volume" "worker_disk" {
  for_each = local.worker_nodes

  name     = "${each.key}-disk.qcow2"
  pool     = var.storage_pool_name
  capacity = 107374182400 # 100GB
  backing_store = {
    path   = libvirt_volume.talos_base.path
    format = { type = "qcow2" }
  }
  target = {
    format = { type = "qcow2" }
  }
}

# Cloud-init seed ISO (optional).
resource "libvirt_cloudinit_disk" "worker_seed" {
  for_each = var.enable_cloudinit ? local.worker_nodes : {}

  name = "${each.key}-cloudinit"

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

resource "libvirt_volume" "worker_seed_volume" {
  for_each = var.enable_cloudinit ? local.worker_nodes : {}

  name = "${each.key}-cloudinit.iso"
  pool = var.cloudinit_storage_pool_name
  create = {
    content = {
      url = "file://${libvirt_cloudinit_disk.worker_seed[each.key].path}"
    }
  }
}

# Virtual machine definition.
resource "libvirt_domain" "workers" {
  for_each = local.worker_nodes

  name      = each.key
  type      = "kvm"
  memory    = each.value.memory_mb * 1024 # KiB
  vcpu      = each.value.vcpu
  running   = true
  autostart = true

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
  }
  features = {
    acpi = true
  }
  cpu = {
    mode = "host-passthrough"
  }

  devices = {
    disks = concat(
      [
        {
          source = {
            volume = {
              pool   = libvirt_volume.worker_disk[each.key].pool
              volume = libvirt_volume.worker_disk[each.key].name
            }
          }
          target = { dev = "vda", bus = "virtio" }
          driver = { type = "qcow2" }
        }
      ],
      var.enable_cloudinit ? [
        {
          device = "cdrom"
          source = {
            volume = {
              pool   = libvirt_volume.worker_seed_volume[each.key].pool
              volume = libvirt_volume.worker_seed_volume[each.key].name
            }
          }
          target = { dev = "sda", bus = "sata" }
        }
      ] : []
    )
    interfaces = [
      {
        type  = "network"
        model = { type = "virtio" }
        source = {
          network = {
            network = libvirt_network.talos_network.name
          }
        }
        wait_for_ip = { timeout = 300, source = "any" }
      }
    ]
    consoles = [
      {
        type   = "pty"
        target = { type = "serial", port = "0" }
      }
    ]
    videos = [
      { model = { type = "virtio", heads = 1, primary = "yes" } }
    ]
    graphics = [
      {
        spice = {
          autoport = "no"
          port     = 5910 + index(sort(keys(local.worker_nodes)), each.key)
          listen   = var.vm_spice_listen
          listeners = [
            {
              type = "address"
              address = {
                address = var.vm_spice_listen
              }
            }
          ]
        }
      }
    ]
  }
}
