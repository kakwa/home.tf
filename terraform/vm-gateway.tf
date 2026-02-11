# Debian cloud image (Trixie = Debian 13) - libvirt pulls directly from URL.
locals {
  debian_image_filename = "debian-13-generic-amd64.qcow2"
  debian_image_url      = "https://cloud.debian.org/images/cloud/trixie/latest/${local.debian_image_filename}"
}

# Debian base image in mid-pool (create from cloud URL, like Ubuntu cloud img example).
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

# Gateway VMs: boot disk with backing_store = debian_base (grows as needed), 2 NICs
locals {
  gateway_vms = {
    "gateway-1" = { memory_mb = 1024, vcpu = 2 }
    "gateway-2" = { memory_mb = 1024, vcpu = 2 }
  }
}

resource "libvirt_volume" "gateway_disk" {
  for_each = local.gateway_vms

  name     = "${each.key}-disk.qcow2"
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

resource "libvirt_cloudinit_disk" "gateway_seed" {
  for_each = var.enable_cloudinit ? local.gateway_vms : {}

  name = "${each.key}-cloudinit"

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
      - systemctl restart ssh

    timezone: UTC
  EOF

  meta_data = <<-EOF
    instance-id: ${each.key}
    local-hostname: ${each.key}
  EOF

  network_config = <<-EOF
    version: 2
    ethernets:
      enp1s0:
        addresses:
          - ${var.gateway_static_ips[each.key]}
        gateway4: 192.168.1.254
        nameservers:
          addresses:
            - 8.8.8.8
      enp2s0:
        dhcp4: true
  EOF
}

# Upload cloud-init ISO into pool (libvirt 0.9: cloudinit_disk has no pool; use a volume).
resource "libvirt_volume" "gateway_seed_volume" {
  for_each = var.enable_cloudinit ? local.gateway_vms : {}

  name = "${each.key}-cloudinit.iso"
  pool = var.cloudinit_storage_pool_name
  create = {
    content = {
      url = "file://${libvirt_cloudinit_disk.gateway_seed[each.key].path}"
    }
  }
}

resource "libvirt_domain" "gateway" {
  for_each = local.gateway_vms

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
              pool   = libvirt_volume.gateway_disk[each.key].pool
              volume = libvirt_volume.gateway_disk[each.key].name
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
              pool   = libvirt_volume.gateway_seed_volume[each.key].pool
              volume = libvirt_volume.gateway_seed_volume[each.key].name
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
          port     = 5920 + index(sort(keys(local.gateway_vms)), each.key)
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
