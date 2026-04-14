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
  default     = "v1.12.6"
}

variable "talos_extensions" {
  description = "List of Talos system extensions to include"
  type        = list(string)
  default = [
    "siderolabs/binfmt-misc",
    # "siderolabs/qemu-guest-agent", # doesn't seem to start properly
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

variable "metallb_ip_pool" {
  description = "MetalLB IPAddressPool entry (CIDR or range), e.g. 192.168.1.48/28. L2 mode: client LAN must be L2-adjacent to nodes that run MetalLB speaker (or use routed alternatives)."
  type        = string
  default     = "192.168.1.48/28"
}

variable "utility_static_ip" {
  description = "Static IP for utility VM on bridge-network (CIDR, e.g. 192.168.1.13/24)"
  type        = string
  default     = "192.168.1.13/24"
}

# Keys must match worker VM names (talos-worker-1 …). Libvirt attaches host bridge (var.bridge_name) as 2nd NIC; Talos still uses 1st NIC (talos-network) for cluster by default — apply patches from talos-worker-lan.examples.yaml for LAN IPs.
variable "worker_lan_static_ips" {
  description = "Static CIDRs on 192.168.1.0/24 for each worker’s bridge NIC (2nd virtio). Apply via generated talos-worker-lan.examples.yaml (interface name may be eth1 — verify with talosctl get links)."
  type        = map(string)
  default = {
    "talos-worker-1" = "192.168.1.41/24"
    "talos-worker-2" = "192.168.1.42/24"
    "talos-worker-3" = "192.168.1.43/24"
    "talos-worker-4" = "192.168.1.44/24"
    "talos-worker-5" = "192.168.1.45/24"
    "talos-worker-6" = "192.168.1.46/24"
  }
}

variable "k8s_config_dir" {
  description = "Directory for Talos/Kubernetes outputs: talos-env.sh, external-dns-helm-values.yaml, and files created by init-talos.sh (kubeconfig, talosconfig, controlplane.yaml, worker.yaml). Override for non-hypervisor tofu apply (e.g. TF_VAR_k8s_config_dir=$PWD/k8s)."
  type        = string
  default     = "/opt/home.tf/k8s"
}

variable "control_plane_vip" {
  description = "Virtual IP for the Talos/Kubernetes control plane API (e.g. 192.168.100.10); used in talos-env.sh and RFC 2136 DNS talos-k8s record"
  type        = string
  default     = "192.168.100.10"
}

variable "debian_admin_user" {
  description = "Admin username for Debian VMs (utility); created via cloud-init with sudo"
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

variable "debian_sudoers_admin" {
  description = "Sudoers line for NOPASSWD (e.g. '%kakwa ALL=(ALL:ALL) NOPASSWD: ALL'). Set to empty string to skip creating /etc/sudoers.d/admin"
  type        = string
  default     = "%kakwa ALL=(ALL:ALL) NOPASSWD: ALL"
}

variable "vm_spice_listen" {
  description = "SPICE listen address (127.0.0.1 = localhost only; use SSH port-forward to connect remotely)"
  type        = string
  default     = "127.0.0.1"
}

variable "vm_spice_port_base" {
  description = "Base port for SPICE (each VM gets a unique port: control-plane 5900+, workers 5910+, utility 5930)"
  type        = number
  default     = 5900
}

# RFC 2136 DNS update (local BIND, etc.). For auto-load use dns.auto.tfvars.json.
variable "dns_update_server" {
  description = "DNS server for RFC 2136 updates"
  type        = string
  default     = ""
}

variable "dns_update_port" {
  description = "Port for RFC 2136 updates (e.g. 5353 for unprivileged BIND)"
  type        = number
  default     = 5353
}

variable "dns_tsig_key_name" {
  description = "TSIG key name for RFC 2136 (e.g. sec1_key); a trailing dot is added if missing (required by provider)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "dns_tsig_key_algorithm" {
  description = "TSIG algorithm (e.g. hmac-sha512)"
  type        = string
  default     = "hmac-sha512"
}

variable "dns_tsig_key_secret" {
  description = "TSIG key secret (base64). From nsupdate -y hmac-sha512:key_name:secret"
  type        = string
  default     = ""
  sensitive   = true
}

# Zone naming (used for record FQDNs and RFC 2136 zone)
variable "dns_zone" {
  description = "DNS zone for cluster names (e.g. kakwalab.ovh)"
  type        = string
  default     = "int.kakwalab.ovh."
}

# external-dns-helm-values.yaml (for init-external-dns.sh)
variable "external_dns_txt_owner_id" {
  description = "TXT registry owner id for ExternalDNS"
  type        = string
  default     = "talos-home-tf"
}

variable "external_dns_policy" {
  description = "ExternalDNS policy in generated Helm values (upsert-only avoids BIND AXFR)"
  type        = string
  default     = "upsert-only"
}

variable "external_dns_sources" {
  description = "ExternalDNS sources in generated Helm values"
  type        = list(string)
  default     = ["service", "ingress"]
}

# Traefik (init-traefik.sh) — in-cluster ingress controller
variable "traefik_service_type" {
  description = "Kubernetes Service type for Traefik (LoadBalancer uses MetalLB from init-traefik.sh; NodePort skips MetalLB VIPs)"
  type        = string
  default     = "LoadBalancer"

  validation {
    condition     = contains(["NodePort", "LoadBalancer", "ClusterIP"], var.traefik_service_type)
    error_message = "traefik_service_type must be NodePort, LoadBalancer, or ClusterIP."
  }
}

variable "traefik_web_node_port" {
  description = "HTTP NodePort when traefik_service_type is NodePort (must be in 30000-32767)"
  type        = number
  default     = 30080
}

variable "traefik_websecure_node_port" {
  description = "HTTPS NodePort when traefik_service_type is NodePort"
  type        = number
  default     = 30443
}

