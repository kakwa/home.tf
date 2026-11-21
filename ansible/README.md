# ansible-homelab

Ansible playbooks and roles for my homelab hosts.
Run from this directory (`ansible.cfg` sets the default inventory to
`inventory.yml` and the role paths).

## Playbooks

| Playbook | Target | What it configures |
| --- | --- | --- |
| `hypervisor.yml` | hypervisor (`kvm.local`) | base system roles, serial console, Talos tooling, Proxmox VE, terraform sync |
| `ai.yml` | AI server (`ai.local`) | base system roles, llama-server (ROCm + nginx proxy), Wake-on-LAN and idle suspend |
| `utility.yml` | utility VM | base system roles, certbot, OpenLDAP, ldapcherry, Docker registry |

Each playbook targets `all` and repeats the shared base roles, so each host can
be set up with a single command. `os_config` runs first in every playbook;
it disables APT recommended packages and installs the base package list
(`man-db`, i.e. the `man` command). The `ai.yml` roles are the
ones formerly appended to `hypervisor.yml`; hypervisor-specific roles
(Proxmox VE, LVM, terraform-sync, Talos tools, serial console) live only in
`hypervisor.yml`.

The `proxmox` role configures the `pve-no-subscription` repository (deb822
format), installs `proxmox-ve`, and enables the core PVE services. It defaults
to the trixie suite; Proxmox publishes no forky repository (see
`roles/proxmox/README.md`). Note that Terraform still provisions VMs via the
libvirt provider - migrating it to the Proxmox provider is a separate task.

The `avahi` role is configured per playbook so only the AI server announces
`ai.local` and only the hypervisor announces `kvm.local`.

Direct root SSH login is disabled on both physical hosts by the `root_ssh`
role (`PermitRootLogin no`); use the bootstrapped `kakwa` account with sudo.

## Inventory and static IPs

`inventory.yml` lists the two physical hosts (`kvm`, `ai`) and holds each
host's NIC → IP mapping under `static_ip_nics`. The `static_ip` role (first
role after `os_config` in both physical-server playbooks) writes those
addresses to `/etc/network/interfaces` and applies them. See
`roles/static_ip/README.md` for the exact mapping format.

Current mapping:

| Host | NIC | Address |
| --- | --- | --- |
| `ai` | `enp9s0` | `192.168.1.20/24` |
| `kvm` | *TODO* | `192.168.1.30/24` |

The hypervisor's NIC is not known yet, so its `static_ip_nics` is empty and
the role skips it. Fill it in before expecting a static address on that host.
On Proxmox the address normally belongs on the bridge (`vmbr0`) with the
physical NIC listed under `bridge_ports`.

The utility VM is not in this inventory: Terraform generates its own
(`../terraform/inventory.yml`) and cloud-init/netplan owns its network config.

## Bootstrap

`bootstrap.yml` is the single entry point for a new host. It:

1. Deploys the SSH public key, installs `sudo`, `python3`, `python3-apt` and
   `python3-debian`, and configures passwordless sudo. This part uses only
   `raw` tasks with fact gathering disabled, so it works on hosts with **no
   Python installed**. Elevation is auto-detected (passwordless sudo, falling
   back to `su`).
2. Once Python exists, runs the `static_ip` role to apply that host's NIC → IP
   mapping from `inventory.yml` (see the inventory section above). Hosts with
   no mapping are skipped.

Use the default inventory and `--limit` to target one host:

```bash
# SSH key auth already in place - AI server gets 192.168.1.20 on enp9s0
ansible-playbook --limit ai bootstrap.yml

# First-time login with a password (-k needs sshpass locally; -K asks for
# the become/su password)
ansible-playbook -k -K --limit ai bootstrap.yml

# Hypervisor (static IP is skipped until its NIC is added to inventory.yml)
ansible-playbook --limit kvm bootstrap.yml
```

### Selecting the target by inventory name (recommended)

Use the inventory name to pick the host, and override only the address used
for the **first connection** (useful before the static IP is active):

```bash
ansible-playbook -k -K --limit ai \
  -e "ansible_host=$HOSTNAME" -e "ansible_user=$LOGIN" bootstrap.yml
```

`ai` supplies the `static_ip_nics` mapping; `ansible_host` is only the
temporary connection target.

### Selecting the target with an inline `-i` host

`-i "$HOSTNAME,"` replaces the default inventory, so add `inventory.yml` as a
second source and name the host whose mapping should be reused. `--limit` is
required to avoid bootstrapping the other inventory hosts:

```bash
ansible-playbook -k -K -i inventory.yml -i "$HOSTNAME," \
  --limit "$HOSTNAME" -e "ansible_user=$LOGIN" \
  -e "bootstrap_inventory_host=ai" bootstrap.yml
```

`bootstrap_inventory_host=ai` copies `static_ip_nics` from the `ai` entry in
`inventory.yml` onto the ad-hoc host. You can still pass the mapping directly
if you prefer (`-e` accepts JSON), but naming the inventory host avoids
duplicating NIC/IP settings:

```bash
ansible-playbook -i "$HOSTNAME," -e "ansible_user=$LOGIN" \
  -e 'static_ip_nics={"enp9s0": {"address": "192.168.1.20/24", "gateway": "192.168.1.254", "dns": ["192.168.1.25"]}}' \
  bootstrap.yml
```

With a bare `-i "$HOSTNAME,"` and no `bootstrap_inventory_host` or mapping,
the `static_ip` role simply skips that host.

The key defaults to `~/.ssh/id_ed25519.pub`; override with
`-e bootstrap_ssh_key_path=/path/to/key.pub`. To force an elevation method,
use `-e bootstrap_become_method=sudo` (or `su`). To write network config
without activating it, pass `-e static_ip_apply=false`.

The `static_ip` role protects the current connection: it detects the interface
used to reach the node (`ip route get <ansible_host>`) and skips activation if
that interface is one of the managed ones, instead of dropping SSH mid-run. It
also only applies when the generated config actually changed. In that case the
config is written but you must activate it from the console, after a reboot,
or once connected through another interface (or set
`-e static_ip_force_apply=true` with console access).

Then run the host's regular playbook with the same inventory:

```bash
ansible-playbook --limit kvm hypervisor.yml
ansible-playbook --limit ai ai.yml
```

Tags let you run only part of a playbook, e.g.:

```bash
ansible-playbook --limit ai ai.yml --tags ai
ansible-playbook --limit kvm hypervisor.yml --tags hypervisor
ansible-playbook --limit ai bootstrap.yml --tags static_ip
```

## Serial Console

```bash
screen /dev/ttyUSB0 115200   # connect
# Ctrl-A D to detach, screen -r to reattach
```
