# Create NAT network for VMs
resource "libvirt_network" "talos_network" {
  name      = var.network_name
  mode      = "nat"
  autostart = true
  addresses = [var.network_cidr]
}

# Bridge network (uses host bridge for external/LAN access)
resource "libvirt_network" "bridge_network" {
  name      = "bridge-network"
  mode      = "bridge"
  autostart = true
  bridge    = var.bridge_name
}