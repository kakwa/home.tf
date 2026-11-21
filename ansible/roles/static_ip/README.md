# Static IP Role

Configures static IPv4 addresses through `/etc/network/interfaces` (ifupdown).
There is no netplan/systemd-networkd support: the utility VM is provisioned by
Terraform cloud-init and keeps its netplan config.

## Inventory mapping

The mapping is per host, keyed by interface name. Gateway and DNS are
**per-NIC** — the role has no global network defaults.

```yaml
all:
  hosts:
    ai:
      ansible_host: 192.168.1.20
      static_ip_nics:
        enp9s0:
          address: 192.168.1.20/24
          gateway: 192.168.1.254
          dns:
            - 192.168.1.25
```

See `ansible/inventory.yml` for the live mapping (AI server: `enp9s0` →
`192.168.1.20`; hypervisor: `192.168.1.30` with the NIC still to be filled in).
A host with `static_ip_nics: {}` (or no variable at all) is skipped entirely.

### Per-NIC keys

| Key | Required | Meaning |
| --- | --- | --- |
| `address` | yes | IPv4 address in CIDR form, e.g. `192.168.1.20/24` |
| `gateway` | yes (may be `null`) | Default gateway. Only one NIC across the host may set it |
| `dns` | yes (may be `[]`) | List of nameservers |
| `bridge_ports` | no | List of ports for a bridge interface; ports get `inet manual` stanzas |
| `bridge_stp` / `bridge_fd` | no | Bridge options |
| `mtu` | no | Interface MTU |

For Proxmox, put the address on the bridge, not the physical NIC:

```yaml
static_ip_nics:
  vmbr0:
    address: 192.168.1.30/24
    gateway: 192.168.1.254
    dns: [192.168.1.25]
    bridge_ports: [enp9s0]
    bridge_stp: "off"
    bridge_fd: 0
```

Keep `pve_configure_bridge: false` in that case so the `proxmox` role does not
write a second `vmbr0` stanza.

## What it does

1. Validates the mapping (CIDR addresses, at most one gateway).
2. Ensures `auto lo` / `iface lo inet loopback` exist.
3. Writes a managed block into `/etc/network/interfaces` with one
   `iface ... inet static` stanza per NIC, plus `inet manual` stanzas for
   bridge ports.
4. Updates `/etc/resolv.conf` from the per-NIC DNS lists, but only when it is a
   regular file (a symlink is left to systemd-resolved).
5. Applies the config **only when it changed**: `ifreload -a` when ifupdown2 is
   installed, otherwise `ifdown --force` / `ifup` per managed interface.

## Connection safety

The role will not remove the address currently used to reach the node:

- The apply step is skipped entirely unless the generated config changed
  (or `static_ip_force_apply: true`), so re-runs do not bounce interfaces.
- The interface carrying the current Ansible/SSH connection is detected with
  `ip route get <ansible_host>`. If it is one of the managed interfaces (or a
  managed bridge port), the apply is skipped with a warning and the written
  config must be activated from the console, after a reboot, or from another
  interface. Nothing is written *less* — only the activation is deferred.
- `static_ip_apply: false` writes config without activating anything.
- `static_ip_force_apply: true` bypasses both guards (use only with console
  access).

## Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `static_ip_nics` | `{}` | NIC → settings mapping (normally set in inventory) |
| `static_ip_interfaces_file` | `/etc/network/interfaces` | ifupdown config file |
| `static_ip_marker` | `# {mark} ANSIBLE MANAGED BLOCK - static_ip` | blockinfile marker |
| `static_ip_ensure_loopback` | `true` | Ensure loopback stanzas |
| `static_ip_apply` | `true` | Apply immediately |
| `static_ip_protect_connection` | `true` | Never bounce the interface used by the current connection |
| `static_ip_force_apply` | `false` | Override the change/connection guards |
| `static_ip_manage_resolvconf` | `true` | Sync `/etc/resolv.conf` |
| `static_ip_resolvconf_path` | `/etc/resolv.conf` | Resolver file |
| `static_ip_resolvconf_search` | `[]` | Optional `search` domains |

## Usage

```yaml
roles:
  - { role: static_ip, tags: ["system", "network", "static_ip"] }
```

`bootstrap.yml` runs this role as its final play (after Python is installed),
so a fresh host gets its static address in the same run:

```bash
ansible-playbook --limit ai bootstrap.yml
```

Run only this part on an existing host:

```bash
ansible-playbook hypervisor.yml --tags static_ip
```
