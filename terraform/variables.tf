variable "network_name" {
  description = "Libvirt network name for VMs"
  type        = string
  default     = "talos-network"
}

variable "network_cidr" {
  description = "CIDR for the VM network"
  type        = string
  default     = "192.168.100.0/24"
}

variable "storage_pool_name" {
  description = "Storage pool name for VM disks"
  type        = string
  default     = "mid-pool"
}

variable "cloudinit_storage_pool_name" {
  description = "Storage pool name for cloud-init seed volumes (ISOs)"
  type        = string
  default     = "slow-pool"
}

variable "talos_version" {
  description = "Talos version to use"
  type        = string
  default     = "v1.12.3"
}

variable "talos_extensions" {
  description = "List of Talos system extensions to include"
  type        = list(string)
  default = [
    "siderolabs/binfmt-misc",
    "siderolabs/qemu-guest-agent",
  ]
}

variable "talos_platform" {
  description = "Talos platform (nocloud, aws, azure, etc.)"
  type        = string
  default     = "nocloud"
}

variable "talos_architecture" {
  description = "Target architecture for Talos image"
  type        = string
  default     = "amd64"
}

variable "talos_download_path" {
  description = "Path where Talos images will be downloaded"
  type        = string
  default     = "./images"
}

variable "enable_cloudinit" {
  description = "Enable cloud-init seed disk for VMs (user_data, meta_data, network_config)"
  type        = bool
  default     = true
}

variable "bridge_name" {
  description = "Host bridge device name for bridge-network (e.g. br0)"
  type        = string
  default     = "br0"
}

variable "bridge_interface" {
  description = "Physical interface to attach to the bridge (e.g. enp0s6)"
  type        = string
  default     = "enp0s6"
}

variable "bridge_manage_netplan" {
  description = "Create br0 via systemd-networkd (writes to /etc/systemd/network, requires sudo on apply). Debian-friendly."
  type        = bool
  default     = true
}

variable "gateway_static_ips" {
  description = "Static IPs for gateway VMs on bridge-network (CIDR, e.g. 192.168.1.11/24)"
  type        = map(string)
  default = {
    "gateway-1" = "192.168.1.11/24"
    "gateway-2" = "192.168.1.12/24"
  }
}

variable "utility_static_ip" {
  description = "Static IP for utility VM on bridge-network (CIDR, e.g. 192.168.1.13/24)"
  type        = string
  default     = "192.168.1.13/24"
}

variable "debian_admin_user" {
  description = "Admin username for Debian VMs (gateway, utility); created via cloud-init with sudo"
  type        = string
  default     = "kakwa"
}

variable "debian_authorized_keys" {
  description = "SSH public keys for debian_admin_user (authorized_keys)"
  type        = list(string)
  default = [
    "ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBIefJ3PQVyfXunlkWc6Ukdw8EZNw8sLX1Pda0p+PckY/maze5K298CiSuE+5LR/9RM5lwx8N8NqnuKTUUSHsfs58jI03RNAuFHaT4Sc6PKS7SfG9t3ZDkCVSdn5Csopwgg== kakwa@tsingtao"
  ]
}

variable "vm_spice_listen" {
  description = "SPICE listen address (127.0.0.1 = localhost only; use SSH port-forward to connect remotely)"
  type        = string
  default     = "127.0.0.1"
}

variable "vm_spice_port_base" {
  description = "Base port for SPICE (each VM gets a unique port: control-plane 5900+, workers 5910+, gateway 5920+, utility 5930)"
  type        = number
  default     = 5900
}

# OVH credentials. For automatic loading, name the file ovh.auto.tfvars.json (same format; *.auto.tfvars.json is loaded by default).
# Format: {"application_key":"","application_secret":"","consumer_key":"","ovh_endpoint":"ovh-eu"} (ovh_endpoint optional)
variable "application_key" {
  description = "OVH API application key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "application_secret" {
  description = "OVH API application secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "consumer_key" {
  description = "OVH API consumer key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ovh_endpoint" {
  description = "OVH API endpoint (ovh-eu, ovh-ca, ovh-us)"
  type        = string
  default     = "ovh-eu"
}

variable "ovh_zone" {
  description = "OVH DNS zone for cluster public names (e.g. kakwalab.ovh)"
  type        = string
  default     = "kakwalab.ovh"
}

variable "ovh_int_subdomain" {
  description = "Subdomain under zone for cluster hosts (e.g. int -> gateway-1.int.kakwalab.ovh)"
  type        = string
  default     = "int"
}
