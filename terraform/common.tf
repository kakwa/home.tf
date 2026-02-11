terraform {
  required_version = ">= 1.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9.2"
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
    ovh = {
      source  = "ovh/ovh"
      version = "~> 0.36"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# OVH: credentials from var-file. Load by default: name file ovh.auto.tfvars.json (auto-loaded). Format: {"application_key":"","application_secret":"","consumer_key":"","ovh_endpoint":"ovh-eu"}
provider "ovh" {
  endpoint           = var.ovh_endpoint
  application_key    = var.application_key
  application_secret = var.application_secret
  consumer_key       = var.consumer_key
}
