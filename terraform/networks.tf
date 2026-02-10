# Create NAT network for VMs (libvirt 0.9 schema: forward + ips)
# Note: ansible/nets shows working libvirt XML uses <ip family="ipv4" address="..." prefix="24">;
# the "not working" variant uses <ip address="..." netmask="255.255.255.0">. If NAT/DHCP fails,
# try ensuring the provider emits prefix (e.g. use prefix = local.network_prefix in ips if supported).
locals {
  network_prefix = tonumber(split("/", var.network_cidr)[1])
  network_netmask = lookup(
    {
      "8"  = "255.0.0.0"
      "16" = "255.255.0.0"
      "24" = "255.255.255.0"
      "25" = "255.255.255.128"
      "26" = "255.255.255.192"
      "27" = "255.255.255.224"
      "28" = "255.255.255.240"
      "29" = "255.255.255.248"
      "30" = "255.255.255.252"
    },
    tostring(local.network_prefix),
    "255.255.255.0"
  )
}

resource "libvirt_network" "talos_network" {
  name      = var.network_name
  autostart = true
  forward   = { mode = "nat" }
  bridge = {
    name  = "virbr1"
    stp   = "on"
    delay = "0"
  }
  ips = [{
    address  = cidrhost(var.network_cidr, 1)
    netmask  = local.network_netmask
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
