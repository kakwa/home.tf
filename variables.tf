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

variable "talos_version" {
  description = "Talos version to use"
  type        = string
  default     = "v1.12.2"
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
