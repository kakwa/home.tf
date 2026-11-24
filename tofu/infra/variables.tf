# PVE endpoint and credentials
variable "pve_endpoint" {
  description = "Proxmox VE API endpoint"
  type        = string
  default     = "https://192.168.1.30:8006"
}

variable "pve_infra_token_file" {
  description = "Path to the infra pool API token secret (file contains only the secret UUID)"
  type        = string
  default     = "../../ansible/pve_pools/infra.token"
}

# Placement
variable "pve_node" {
  description = "PVE node to place the VMs on"
  type        = string
  default     = "pve"
}

variable "pve_pool" {
  description = "PVE pool the VMs are added to"
  type        = string
  default     = "infra"
}

# Cloud image
variable "debian_image_url" {
  description = "Debian cloud image URL"
  type        = string
  default     = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
}

variable "debian_image_filename" {
  description = "Debian cloud image filename as stored on the PVE node"
  type        = string
  default     = "debian-13-generic-amd64.qcow2"
}

variable "image_datastore" {
  description = "PVE storage the cloud image is downloaded to (dir storage with import content)"
  type        = string
  default     = "local"
}

# VM sizing (infra pool quotas: 5 VMs, 8 GB RAM, 320 GB disk)
variable "vm_datastore" {
  description = "PVE storage for VM disks (LVM thin)"
  type        = string
  default     = "local-lvm"
}

variable "vm_disk_size_gb" {
  description = "VM disk size in GB"
  type        = number
  default     = 30
}

variable "registry_disk_size_gb" {
  description = "Boot disk size in GB for the registry VM (holds the Docker registry data)"
  type        = number
  default     = 200
}

variable "vm_ram_mb" {
  description = "VM dedicated RAM in MB"
  type        = number
  default     = 1024
}

variable "vm_cores" {
  description = "VM vCPU cores"
  type        = number
  default     = 2
}

variable "vm_tags" {
  description = "Tags applied to all infra VMs"
  type        = list(string)
  default     = ["infra"]
}

# VM networking
variable "vm_bridge" {
  description = "LAN bridge for the VM network"
  type        = string
  default     = "vmbr2"
}

variable "vm_subnet_mask" {
  description = "Netmask for the VM static IPs"
  type        = string
  default     = "24"
}

variable "vm_gateway" {
  description = "Default gateway for the VMs"
  type        = string
  default     = "192.168.1.254"
}

# VM admin account (cloud-init user_account; the guest hostname is set to the VM name by PVE)
variable "vm_admin_user" {
  description = "Admin username created in each VM via cloud-init"
  type        = string
  default     = "kakwa"
}

variable "vm_authorized_keys" {
  description = "SSH public keys for the admin user"
  type        = list(string)
  default = [
    "ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBIefJ3PQVyfXunlkWc6Ukdw8EZNw8sLX1Pda0p+PckY/maze5K298CiSuE+5LR/9RM5lwx8N8NqnuKTUUSHsfs58jI03RNAuFHaT4Sc6PKS7SfG9t3ZDkCVSdn5Csopwgg== kakwa@tsingtao"
  ]
}

# DNS VM
variable "dns_vm" {
  description = "DNS VM identity (name is also used as the guest hostname)"
  type = object({
    name  = string
    vm_id = number
    ip    = string
  })
  default = {
    name  = "dns"
    vm_id = 100
    ip    = "192.168.1.25"
  }
}

variable "dns_upstream_servers" {
  description = "Upstream DNS servers used by the DNS VM itself"
  type        = list(string)
  default     = ["192.168.1.254"]
}

# LDAP VM
variable "ldap_vm" {
  description = "LDAP VM identity (name is also used as the guest hostname)"
  type = object({
    name  = string
    vm_id = number
    ip    = string
    dns   = list(string)
  })
  default = {
    name  = "ldap"
    vm_id = 101
    ip    = "192.168.1.15"
    dns   = ["192.168.1.25"]
  }
}

# RFC 2136 DNS updates to the DNS VM's BIND (TSIG). The zone records are
# pushed only when dns_update_server (and the TSIG key) are configured;
# otherwise DNS record configuration is skipped entirely.
# See dns.auto.tfvars.json (gitignored) for the local values.
variable "dns_update_server" {
  description = "DNS server for RFC 2136 updates (the DNS VM)"
  type        = string
  default     = ""
}

variable "dns_update_port" {
  description = "Port for RFC 2136 updates (BIND listens on 53)"
  type        = number
  default     = 53
}

variable "dns_tsig_key_name" {
  description = "TSIG key name for RFC 2136 (a trailing dot is added if missing)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "dns_tsig_key_algorithm" {
  description = "TSIG algorithm for RFC 2136"
  type        = string
  default     = "hmac-sha512"
}

variable "dns_tsig_key_secret" {
  description = "TSIG key secret (base64); keep in sync with ansible/dns_tsig_secret.txt"
  type        = string
  default     = ""
  sensitive   = true
}

variable "dns_zone" {
  description = "DNS zone for the infra host names (trailing dot included)"
  type        = string
  default     = "int.kakwalab.ovh."
}

# Ansible master VM
variable "ansible_master_vm" {
  description = "Ansible master VM identity (name is also used as the guest hostname)"
  type = object({
    name  = string
    vm_id = number
    ip    = string
    dns   = list(string)
  })
  default = {
    name  = "ansible-master"
    vm_id = 102
    ip    = "192.168.1.35"
    dns   = ["192.168.1.25"]
  }
}

variable "registry_vm" {
  description = "Registry VM identity (name is also used as the guest hostname)"
  type = object({
    name  = string
    vm_id = number
    ip    = string
    dns   = list(string)
  })
  default = {
    name  = "registry"
    vm_id = 103
    ip    = "192.168.1.36"
    dns   = ["192.168.1.25"]
  }
}
