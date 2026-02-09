# Libvirt/KVM Role

This Ansible role sets up a basic libvirt/KVM hypervisor for virtualization.

## Description

This role provides a complete KVM/QEMU virtualization environment using libvirt. It replaces the Proxmox setup with a more minimal and flexible solution for managing virtual machines.

## Features

- ✅ Installs libvirt, QEMU/KVM, and related tools
- ✅ Checks for hardware virtualization support (Intel VT-x or AMD-V)
- ✅ Enables nested virtualization (optional)
- ✅ Configures libvirt default network
- ✅ Sets up storage pools for VM images
- ✅ User management for libvirt groups
- ✅ Includes management tools (virt-manager, virt-top, libguestfs-tools)

## Requirements

- Debian/Ubuntu-based system
- CPU with hardware virtualization support (Intel VT-x or AMD-V)
- Root/sudo access

## Role Variables

### Service Configuration
- `libvirt_service_enabled`: Enable libvirtd service (default: `true`)
- `libvirt_service_state`: Service state (default: `started`)

### Packages
- `libvirt_packages`: List of packages to install (see defaults/main.yml)

### User Management
- `libvirt_users`: List of users to add to libvirt groups (default: `[]`)

### Network Configuration
- `libvirt_default_network_autostart`: Autostart default network (default: `true`)
- `libvirt_default_network_state`: Network state (default: `active`)

### Storage Pools
- `libvirt_storage_pools`: List of storage pools to configure (default: fast-pool, slow-pool, mid-pool)

Each storage pool has:
  - `name`: Pool name
  - `type`: Pool type (usually 'dir' for directory-based)
  - `path`: Directory path
  - `autostart`: Whether to autostart the pool
  - `state`: Desired state ('active' or 'inactive')

### Virtualization Features
- `libvirt_enable_nested_virt`: Enable nested virtualization (default: `true`)

### Security
- `libvirt_qemu_user`: QEMU user (default: `libvirt-qemu`)
- `libvirt_qemu_group`: QEMU group (default: `libvirt-qemu`)
- `libvirt_security_driver`: Security driver (default: `apparmor`)

## Example Playbook

```yaml
- name: Configure hypervisor
  hosts: hypervisor
  become: true
  roles:
    - role: libvirt
      tags: ["hypervisor", "virtualization"]
      vars:
        libvirt_users:
          - myuser
```

## Usage

Run the playbook with:

```bash
# Install everything
ansible-playbook hypervisor.yml

# Only install libvirt
ansible-playbook hypervisor.yml --tags libvirt

# Only virtualization-related tasks
ansible-playbook hypervisor.yml --tags virtualization
```

## Managing VMs

After setup, you can manage VMs using:

### Command Line (virsh)
```bash
# List VMs
virsh list --all

# Start a VM
virsh start <vm-name>

# Stop a VM
virsh shutdown <vm-name>

# List storage pools
virsh pool-list

# List networks
virsh net-list
```

### GUI (virt-manager)
```bash
# Launch virt-manager (requires X11/Wayland display)
virt-manager
```

### Create a VM
```bash
# Using virt-install
virt-install \
  --name myvm \
  --memory 2048 \
  --vcpus 2 \
  --disk path=/var/lib/vms/fast-pool/myvm.qcow2,size=20 \
  --cdrom /path/to/installer.iso \
  --os-variant debian11 \
  --network network=default
```

## Storage Pools

The role automatically configures three storage pools:
- **fast-pool**: `/var/lib/vms/fast-pool` (for high-performance VMs)
- **slow-pool**: `/var/lib/vms/slow-pool` (for archival/backup VMs)
- **mid-pool**: `/var/lib/vms/mid-pool` (for general-purpose VMs)

These correspond to the LVM volumes set up by the `lvm` role.

## Nested Virtualization

Nested virtualization allows you to run VMs inside VMs. This is useful for testing hypervisors.

To check if nested virtualization is enabled:

**Intel:**
```bash
cat /sys/module/kvm_intel/parameters/nested
```

**AMD:**
```bash
cat /sys/module/kvm_amd/parameters/nested
```

## Tags

- `hypervisor`: Hypervisor-related tasks
- `virtualization`: Virtualization setup
- `libvirt`: Libvirt-specific tasks

## Dependencies

None, but works well with the `lvm` role for storage setup.

## License

See repository LICENSE file

## Author Information

Created for ansible-hypervisor project

