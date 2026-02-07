# Create NAT network for VMs
resource "libvirt_network" "talos_network" {
  name      = var.network_name
  mode      = "nat"
  autostart = true
  addresses = [var.network_cidr]
}

# Bridge network (uses host bridge for external/LAN access)
resource "libvirt_network" "bridge_network" {
  name   = "bridge-network"
  mode   = "bridge"
  bridge = var.bridge_name
}

# Host bridge br0 (with enp0s6) via systemd-networkd — Debian-friendly, applied with sudo
locals {
  br0_netdev = templatefile("${path.module}/systemd-networkd/25-br0.netdev.tpl", {
    bridge_name = var.bridge_name
  })
  br0_network = templatefile("${path.module}/systemd-networkd/25-br0.network.tpl", {
    bridge_name = var.bridge_name
  })
  bridge_port_network = templatefile("${path.module}/systemd-networkd/25-bridge-port.network.tpl", {
    bridge_name      = var.bridge_name
    bridge_interface = var.bridge_interface
  })
}

resource "local_file" "br0_netdev" {
  content  = local.br0_netdev
  filename = "${path.module}/systemd-networkd/25-br0.netdev"
}

resource "local_file" "br0_network" {
  content  = local.br0_network
  filename = "${path.module}/systemd-networkd/25-br0.network"
}

resource "local_file" "bridge_port_network" {
  content  = local.bridge_port_network
  filename = "${path.module}/systemd-networkd/25-${var.bridge_interface}.network"
}

resource "null_resource" "systemd_networkd_apply" {
  count = var.bridge_manage_netplan ? 1 : 0

  triggers = {
    br0_netdev       = local.br0_netdev
    br0_network      = local.br0_network
    bridge_port      = local.bridge_port_network
    bridge_interface = var.bridge_interface
  }

  provisioner "local-exec" {
    command = <<-EOT
      sudo cp ${path.module}/systemd-networkd/25-br0.netdev \
             ${path.module}/systemd-networkd/25-br0.network \
             ${path.module}/systemd-networkd/25-${var.bridge_interface}.network \
             /etc/systemd/network/ && \
      sudo systemctl enable systemd-networkd && \
      sudo systemctl restart systemd-networkd
    EOT
  }

  depends_on = [
    local_file.br0_netdev,
    local_file.br0_network,
    local_file.bridge_port_network,
  ]
}
