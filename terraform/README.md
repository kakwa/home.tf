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

## OVH DNS (optional)

To manage DNS records under `int.kakwalab.ovh`, add `ovh.json` in this directory with your OVH API credentials:

```json
{"application_key":"","application_secret":"","consumer_key":"","ovh_endpoint":"ovh-eu"}
```

**Load by default:** create a symlink so OpenTofu auto-loads the file (no `-var-file` needed):

```bash
ln -sf ovh.json ovh.auto.tfvars.json
```

Then `tofu apply` will use the credentials automatically. Otherwise run `tofu apply -var-file=ovh.json`.

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
