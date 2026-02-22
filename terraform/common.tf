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
    dns = {
      source  = "hashicorp/dns"
      version = "~> 3.4"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Local DNS via RFC 2136 (e.g. BIND with TSIG). Zone updates use HMAC-SHA512.
# Set dns_update_server, dns_tsig_key_name, dns_tsig_key_secret (e.g. via dns.auto.tfvars.json).
# When dns_update_server is empty, no update block is set and DNS resources are skipped.
provider "dns" {
  dynamic "update" {
    for_each = var.dns_update_server != "" ? [1] : []
    content {
      server        = var.dns_update_server
      port          = var.dns_update_port
      key_name      = var.dns_tsig_key_name != "" && !endswith(var.dns_tsig_key_name, ".") ? "${var.dns_tsig_key_name}." : var.dns_tsig_key_name
      key_algorithm = var.dns_tsig_key_algorithm
      key_secret    = var.dns_tsig_key_secret
    }
  }
}
