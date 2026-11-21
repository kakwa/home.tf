# Proxmox VE Role

Sets up a Proxmox VE (PVE) host: APT repositories, packages, core services,
optional nested virtualization and optional Linux bridge.

Repository layout follows the official
[Proxmox Package Repositories wiki](https://pve.proxmox.com/wiki/Package_Repositories)
(deb822 `/etc/apt/sources.list.d/proxmox.sources`, keyring in
`/usr/share/keyrings/`).

## What it does

1. Validates the configured Debian suite (see the forky note below).
2. Installs the Proxmox archive keyring (verified sha256 from the wiki).
3. Disables the subscription-only `pve-enterprise` repo if present.
4. Enables `pve-no-subscription` for the selected suite.
5. Preseeds and installs Postfix, then installs `proxmox-ve`, `pve-firmware`
   and `chrony`.
6. Enables the core PVE services (`pve-cluster`, `pvedaemon`, `pveproxy`,
   `pvestatd`, `pvescheduler`).
7. Optionally writes nested-virtualization options for the KVM modules and
   optionally creates the VM bridge in `/etc/network/interfaces`.

## Suite support / forky

Proxmox currently publishes `pve-no-subscription` only for `bookworm`,
`bullseye` and `trixie` (PVE 9, based on trixie). **There is no forky
repository.** The role defaults to `trixie` and fails early if you set
`pve_suite: forky` unless you also set `pve_allow_unsupported_suite: true`.
Forcing it will make `apt update` fail unless you point `pve_repo_uri` /
`pve_repo_component` at a repository you maintain. Override the keyring URL
and checksum too if you pin an older suite:

```yaml
- role: proxmox
  vars:
    pve_suite: bookworm
    pve_keyring_url: "https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg"
    pve_keyring_checksum: "sha256:<checksum of the bookworm keyring>"
  tags: ["hypervisor", "virtualization", "proxmox"]
```

## Role Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `pve_suite` | `trixie` | Debian codename used as the APT suite |
| `pve_supported_suites` | `[bookworm, bullseye, trixie]` | Suites with an official PVE repo |
| `pve_allow_unsupported_suite` | `false` | Permit an unsupported suite anyway |
| `pve_repo_uri` | `http://download.proxmox.com/debian/pve` | PVE APT URI |
| `pve_repo_component` | `pve-no-subscription` | APT component |
| `pve_repo_name` | `proxmox` | Name of the deb822 source file |
| `pve_keyring_url` / `pve_keyring_path` / `pve_keyring_checksum` | trixie keyring | Signing key |
| `pve_disable_enterprise_repo` | `true` | Disable subscription-only repo |
| `pve_packages` | `[proxmox-ve, postfix, pve-firmware, chrony]` | Packages to install |
| `pve_mailname` | `ansible_fqdn` | Postfix mailname |
| `pve_services` | core PVE services | Services to enable/start |
| `pve_nested_virtualization` | `true` | Write `nested=1` for Intel/AMD KVM modules |
| `pve_kvm_modprobe_file` | `/etc/modprobe.d/qemu-system-x86.conf` | Nested virt config path |
| `pve_configure_bridge` | `false` | Manage the bridge in `/etc/network/interfaces` |
| `pve_bridge_name` | `vmbr0` | Bridge device name |
| `pve_bridge_physical_interface` | `enp9s0` | NIC attached to the bridge |

## Usage

```yaml
- name: Hypervisor Server Setup
  hosts: all
  become: true
  roles:
    - role: proxmox
      tags: ["hypervisor", "virtualization", "proxmox"]
```

Run only the PVE parts:

```bash
ansible-playbook -i $HOSTNAME, hypervisor.yml --tags proxmox
```

If PVE was installed from the official ISO it already has `vmbr0` and a
working network config - leave `pve_configure_bridge: false`. When installing
on a plain Debian host, enable it and set the physical interface to match.
Terraform currently expects a bridge named `br0` (`var.bridge_name`), so set
`pve_bridge_name: br0` if you want that name.

Nested virtualization is written to a modprobe file and needs a reboot before
it takes effect; the role prints a reminder when the file changes.

## Status

This role replaces the old `libvirt`/KVM role for host setup only. Terraform
still provisions VMs through the `dmacvicar/libvirt` provider (`qemu:///system`);
migrating those resources to the Proxmox provider is a separate task.
