# Terraform Libvirt VM Module

OpenTofu/Terraform code to deploy a simple K8S/Talos Cluster

# Item Configured

TODO

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
