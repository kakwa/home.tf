# Create NAT network for VMs
resource "libvirt_network" "talos_network" {
  name      = var.network_name
  mode      = "nat"
  autostart = true
  addresses = [var.network_cidr]
}
