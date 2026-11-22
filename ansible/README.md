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

## Inventory and static IPs

`inventory.yml` lists the two physical hosts (`kvm`, `ai`) and holds NIC configuration.

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
export HOSTNAME=192.168.1.227
export LOGIN=kakwa

ansible-playbook -k -K --limit kvm -i inventory.yml  -e "ansible_host=$HOSTNAME" -e "ansible_user=$LOGIN" bootstrap.yml
```

## Configuration

To configuration the hosts:

```bash
# apply everywher
ansible-playbook -i inventory.yml
# apply only one a specific host
ansible-playbook -i inventory.yml --limit kvm
# apply only a specific configuration
ansible-playbook -i inventory.yml --limit kvm --tags proxmos
```
