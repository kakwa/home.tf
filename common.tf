terraform {
  required_version = ">= 1.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.7.0"
    }
    utility = {
      source  = "registry.terraform.io/frontiersgg/utility"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}
