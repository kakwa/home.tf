# Create NAT network for VMs (libvirt 0.9 schema: forward + ips)
resource "libvirt_network" "talos_network" {
  name      = var.network_name
  autostart = true
  forward   = { mode = "nat" }
  ips = [{
    address = cidrhost(var.network_cidr, 1)
    prefix  = tonumber(split("/", var.network_cidr)[1])
    dhcp = {
      ranges = [{
        start = cidrhost(var.network_cidr, 2)
        end   = cidrhost(var.network_cidr, 254)
      }]
    }
  }]
}

# Bridge network (uses host bridge for external/LAN access)
resource "libvirt_network" "bridge_network" {
  name      = "bridge-network"
  autostart = true
  forward   = { mode = "bridge" }
  bridge    = { name = var.bridge_name }
}
