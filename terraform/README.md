# Terraform Libvirt VM Module

OpenTofu/Terraform code to deploy a simple K8S/Talos Cluster

# Item Configured

- **Talos base image** — pulled from the [Talos Image Factory](https://factory.talos.dev) into `mid-pool` (`talos-base.qcow2`) with system extensions (default: `binfmt-misc`); version `v1.12.6`, platform `nocloud`/`amd64`.
- **Debian base image** — Debian 13 (Trixie) cloud `qcow2` into `mid-pool` (`debian-base.qcow2`), used as the utility VM backing store.
- **Cluster network** — libvirt NAT network `talos-network` (`192.168.100.0/24`), bridged as `virbr1`, autostart + DHCP.
- **Utility VM** — `utility` (1 GiB RAM, 2 vCPU, `q35`, host-passthrough CPU, 50 GiB `qcow2` backed by the Debian base). Two NICs: one direct-bridged to the LAN (`br0`) with a static IP (`192.168.1.13/24`, gateway `192.168.1.254`, DNS `192.168.1.25`) and one on `talos-network` (DHCP). Optional cloud-init seed (admin user, sudo, authorized keys, `qemu-guest-agent`).
- **Control-plane VMs** — 3× `talos-cp-*` (2 GiB RAM, 2 vCPU, 100 GiB each, backed by the Talos base).
- **Worker VMs** — 6× `talos-worker-*` (2 GiB RAM, 2 vCPU, 100 GiB each, backed by the Talos base).
- **DNS (RFC 2136 + TSIG)** — A records under `int.kakwalab.ovh.`: `utility` (static) plus `-k8s`-suffixed names for the utility and every Talos CP/worker (LAN/cluster IPs). Skipped entirely when `dns_update_server` is empty.
- **Ansible inventory** — `inventory.yml` (rendered from `inventory.yml.tpl`); each VM's IP resolved in order: libvirt provider → `virsh domifaddr` (`scripts/get-domain-ips.sh`) → static (utility only).
- **k8s config dir** — `talos-env.sh`, `talos-kubelet-nodeip-patch.yaml`, `talos-worker-lan.examples.yaml`, `metallb-namespace.yaml`, `metallb-lan.yaml`, `traefik-namespace.yaml`, `traefik-helm-values.yaml`, `external-dns-helm-values.yaml` written under `k8s_config_dir` (default `/opt/home.tf/k8s`).
- **Bootstrap scripts** — `init-talos.sh` (bootstrap cluster + `talosconfig`), `init-traefik.sh` (MetalLB Helm + L2 pool, then Traefik Helm), `init-external-dns.sh` (ExternalDNS Helm, RFC 2136 + TSIG); all consume the generated `k8s_config_dir` artifacts.

# Deploy

```bash
tofu init
tofu plan
tofu apply
```

## Local DNS via RFC 2136 (optional)

To manage DNS records under `int.kakwalab.ovh` with a local BIND (or other RFC 2136–capable) server, set TSIG credentials and server. Example `dns.auto.tfvars.json` (auto-loaded if present):

```json
{
  "dns_update_server": "192.168.1.25",
  "dns_update_port": 5353,
  "dns_tsig_key_name": "sec1_key",
  "dns_tsig_key_algorithm": "hmac-sha512",
  "dns_tsig_key_secret": "<base64-secret>"
}
```

The secret is the part after the second `:` in `nsupdate -y hmac-sha512:key_name:SECRET`. Zone is derived from `ovh_int_subdomain` and `ovh_zone` (e.g. `int` + `kakwalab.ovh` → `int.kakwalab.ovh`). Use a `*.auto.tfvars.json` filename so OpenTofu loads it automatically, or pass `-var-file=dns.auto.tfvars.json`.

**If you see** `"key_name", "key_secret" and "key_algorithm" should be non empty"`: ensure `dns_tsig_key_algorithm` is the algorithm name (e.g. `hmac-sha512`) and `dns_tsig_key_secret` is the base64 secret from your nsupdate key—not the other way around.

**If you see** `"key_name" should be fully-qualified"`: the provider expects a FQDN; the config now adds a trailing dot automatically (e.g. `sec1_key` → `sec1_key.`), so you can keep using the short name in your tfvars.

# Troubleshooting

## "Storage volume not found" / `path;uuid` volume key

The libvirt provider stores volume keys as `path;uuid` internally. If a volume was deleted outside Terraform (e.g. pool recreated, manual `virsh vol-delete`), state or a running domain may still reference it and refresh will fail.

**Fix:** Remove the stale resource from state and (if it’s a domain) undefine the VM in libvirt so Terraform can recreate it:

```bash
# Remove the worker domain from state (use the worker that errors, e.g. talos-worker-4)
tofu state rm 'libvirt_domain.workers["talos-worker-4"]'

# If the cloudinit disk is in state, remove it too
tofu state rm 'libvirt_cloudinit_disk.worker_seed["talos-worker-4"]'

# Undefine the VM in libvirt so Terraform can recreate it (stop it first if running)
virsh destroy talos-worker-4 2>/dev/null || true
virsh undefine talos-worker-4

tofu apply
```

Repeat for other workers (e.g. talos-worker-1 … talos-worker-6) if the same error appears.
