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
}

# Boot disk (backing store = debian_base, grows as needed).
resource "libvirt_volume" "utility_disk" {
  name     = "utility-disk.qcow2"
  pool     = var.storage_pool_name
  capacity = 53687091200 # 50GB
  backing_store = {
    path   = libvirt_volume.debian_base.path
    format = { type = "qcow2" }
  }
  target = {
    format = { type = "qcow2" }
  }
}

resource "libvirt_cloudinit_disk" "utility_seed" {
  count = var.enable_cloudinit ? 1 : 0

  name = "utility-cloudinit"

  user_data = <<-EOF
    #cloud-config
    users:
      - name: ${var.debian_admin_user}
        groups: [sudo]
        shell: /bin/bash
        ssh_authorized_keys:
${join("\n", [for k in var.debian_authorized_keys : "          - ${replace(k, "\n", "")}"])}

    chpasswd:
      list: |
        root:password
      expire: false

    ssh_pwauth: true

    packages:
      - openssh-server
      - qemu-guest-agent

    runcmd:
      - systemctl enable --now qemu-guest-agent

    timezone: UTC
  EOF

  meta_data = <<-EOF
    instance-id: utility
    local-hostname: utility
  EOF

  network_config = <<-EOF
    version: 2
    ethernets:
      enp1s0:
        addresses:
          - ${var.utility_static_ip}
        gateway4: 192.168.1.254
        nameservers:
          addresses:
            - 8.8.8.8
      enp2s0:
        dhcp4: true
  EOF
}

resource "libvirt_volume" "utility_seed_volume" {
  count = var.enable_cloudinit ? 1 : 0

  name = "utility-cloudinit.iso"
  pool = var.cloudinit_storage_pool_name
  create = {
    content = {
      url = "file://${libvirt_cloudinit_disk.utility_seed[0].path}"
    }
  }
}

resource "libvirt_domain" "utility" {
  name      = "utility"
  type      = "kvm"
  memory    = local.utility_vm.memory_mb * 1024 # KiB
  vcpu      = local.utility_vm.vcpu
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
              pool   = libvirt_volume.utility_disk.pool
              volume = libvirt_volume.utility_disk.name
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
              pool   = libvirt_volume.utility_seed_volume[0].pool
              volume = libvirt_volume.utility_seed_volume[0].name
            }
          }
          target = { dev = "sda", bus = "sata" }
        }
      ] : []
    )
    interfaces = [
      # Use direct bridge (not libvirt network) to avoid provider bug: source.network read back as null after apply
      {
        type  = "bridge"
        model = { type = "virtio" }
        source = { bridge = { bridge = var.bridge_name } }
      },
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
          port     = 5930
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
