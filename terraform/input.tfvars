# Example Terraform variables file
# Copy this to terraform.tfvars and customize for your environment

# Libvirt connection URI
# For remote connections: "qemu+ssh://root@kvm.local/system"
# For local system-level: "qemu:///system" (requires libvirt group membership)
# For local user-level: "qemu:///session"
libvirt_uri = "qemu:///system"

# Network configuration
networks = {
  bridge = {
    name      = "bridge-network"
    device    = "virbr-enp6s0"
    interface = "enp6s0"  # Physical NIC to bridge to
  }
  internal = {
    name    = "internal-network"
    device  = "virbr-internal"
    domain  = "internal.local"
    gateway = "192.168.200.1"
    subnet  = "192.168.200.0/24"
  }
}

# Storage pools (pool_name = path)
storage_pools = {
  "fast-pool" = "/var/lib/vms/fast-pool"
  "slow-pool" = "/var/lib/vms/slow-pool"
  "mid-pool"  = "/var/lib/vms/mid-pool"
}
