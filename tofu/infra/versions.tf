# PVE infra VMs (DNS + LDAP).
#
# Provider note: bpg/proxmox is pinned to the last legacy SDKv2 release
# (0.82.x). 0.84.0+ is a rewrite with a different resource schema, so the
# pin is exact rather than a pessimistic constraint.
terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.82.0"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

# Authenticated with the "infra" pool API token (see ansible/pve_pools/).
# The token file holds only the secret UUID; the provider expects the full
# "user@realm!token=secret" form.
provider "proxmox" {
  endpoint  = var.pve_endpoint
  username  = "infra@pve"
  api_token = join("", ["infra@pve!token=", trimspace(file(var.pve_infra_token_file))])
  insecure  = true
}
