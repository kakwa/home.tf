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
      source = "registry.terraform.io/frontiersgg/utility"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}
