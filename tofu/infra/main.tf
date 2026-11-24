# Debian cloud image, downloaded on the PVE node to `local` (dir storage).
# All VMs import their boot disk from this file into `local-lvm`.
resource "proxmox_virtual_environment_download_file" "debian" {
  node_name    = var.pve_node
  datastore_id = var.image_datastore
  content_type = "import"
  file_name    = var.debian_image_filename
  url          = var.debian_image_url
}

# DNS VM
resource "proxmox_virtual_environment_vm" "dns" {
  name      = var.dns_vm.name
  node_name = var.pve_node
  vm_id     = var.dns_vm.vm_id
  pool_id   = var.pve_pool
  machine   = "q35"
  tags      = var.vm_tags
  started   = true
  on_boot   = true

  cpu {
    type  = "host"
    cores = var.vm_cores
  }

  memory {
    dedicated = var.vm_ram_mb
  }

  disk {
    datastore_id = var.vm_datastore
    interface    = "scsi0"
    size         = var.vm_disk_size_gb
    import_from  = proxmox_virtual_environment_download_file.debian.id
  }

  network_device {
    bridge = var.vm_bridge
  }

  # Workaround: Debian 12+ cloud images kernel-panic on boot-disk resize
  # unless a serial device is present (bpg/proxmox issue).
  serial_device {
    device = "socket"
  }

  initialization {
    dns {
      # Explicit servers: otherwise PVE inherits the host's resolv.conf.
      servers = var.dns_upstream_servers
    }

    ip_config {
      ipv4 {
        address = "${var.dns_vm.ip}/${var.vm_subnet_mask}"
        gateway = var.vm_gateway
      }
    }

    user_account {
      username = var.vm_admin_user
      keys     = var.vm_authorized_keys
    }
  }
}

# LDAP VM
resource "proxmox_virtual_environment_vm" "ldap" {
  name      = var.ldap_vm.name
  node_name = var.pve_node
  vm_id     = var.ldap_vm.vm_id
  pool_id   = var.pve_pool
  machine   = "q35"
  tags      = var.vm_tags
  started   = true
  on_boot   = true

  cpu {
    type  = "host"
    cores = var.vm_cores
  }

  memory {
    dedicated = var.vm_ram_mb
  }

  disk {
    datastore_id = var.vm_datastore
    interface    = "scsi0"
    size         = var.vm_disk_size_gb
    import_from  = proxmox_virtual_environment_download_file.debian.id
  }

  network_device {
    bridge = var.vm_bridge
  }

  serial_device {
    device = "socket"
  }

  initialization {
    dns {
      # Point at the DNS VM.
      servers = var.ldap_vm.dns
    }

    ip_config {
      ipv4 {
        address = "${var.ldap_vm.ip}/${var.vm_subnet_mask}"
        gateway = var.vm_gateway
      }
    }

    user_account {
      username = var.vm_admin_user
      keys     = var.vm_authorized_keys
    }
  }
}

# Ansible master VM
resource "proxmox_virtual_environment_vm" "ansible_master" {
  name      = var.ansible_master_vm.name
  node_name = var.pve_node
  vm_id     = var.ansible_master_vm.vm_id
  pool_id   = var.pve_pool
  machine   = "q35"
  tags      = var.vm_tags
  started   = true
  on_boot   = true

  cpu {
    type  = "host"
    cores = var.vm_cores
  }

  memory {
    dedicated = var.vm_ram_mb
  }

  disk {
    datastore_id = var.vm_datastore
    interface    = "scsi0"
    size         = var.vm_disk_size_gb
    import_from  = proxmox_virtual_environment_download_file.debian.id
  }

  network_device {
    bridge = var.vm_bridge
  }

  serial_device {
    device = "socket"
  }

  initialization {
    dns {
      # Point at the DNS VM.
      servers = var.ansible_master_vm.dns
    }

    ip_config {
      ipv4 {
        address = "${var.ansible_master_vm.ip}/${var.vm_subnet_mask}"
        gateway = var.vm_gateway
      }
    }

    user_account {
      username = var.vm_admin_user
      keys     = var.vm_authorized_keys
    }
  }
}

# Registry VM (Docker registry data lives on its boot disk)
resource "proxmox_virtual_environment_vm" "registry" {
  name      = var.registry_vm.name
  node_name = var.pve_node
  vm_id     = var.registry_vm.vm_id
  pool_id   = var.pve_pool
  machine   = "q35"
  tags      = var.vm_tags
  started   = true
  on_boot   = true

  cpu {
    type  = "host"
    cores = var.vm_cores
  }

  memory {
    dedicated = var.vm_ram_mb
  }

  disk {
    datastore_id = var.vm_datastore
    interface    = "scsi0"
    size         = var.registry_disk_size_gb
    import_from  = proxmox_virtual_environment_download_file.debian.id
  }

  network_device {
    bridge = var.vm_bridge
  }

  serial_device {
    device = "socket"
  }

  initialization {
    dns {
      # Point at the DNS VM.
      servers = var.registry_vm.dns
    }

    ip_config {
      ipv4 {
        address = "${var.registry_vm.ip}/${var.vm_subnet_mask}"
        gateway = var.vm_gateway
      }
    }

    user_account {
      username = var.vm_admin_user
      keys     = var.vm_authorized_keys
    }
  }
}
