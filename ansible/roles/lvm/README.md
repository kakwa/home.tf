# LVM Storage Role

This Ansible role configures LVM volumes with RAID support for hypervisor storage pools.

## Description

This role sets up three storage pools for VM storage:

1. **Fast Pool**: RAID 1 array across 6x OCZ-VELO DRIVE 139.7G SSDs (~419G usable with mirroring) with LVM
2. **Slow Pool**: Single 1.8TB WDC WD20EZRX drive with LVM
3. **Mid Pool**: Simple directory (no LVM)

## Requirements

- Debian/Ubuntu-based system (for mdadm and update-initramfs)
- Physical disks available at specified paths
- Root/sudo access

## Important: Use Stable Device Identifiers

⚠️ **Always use stable device identifiers** instead of `/dev/sdX` paths, as those can change between reboots!

**Recommended**: Use `/dev/disk/by-id/` paths which are based on hardware serial numbers.

To find your disk IDs, run:
```bash
ls -l /dev/disk/by-id/
```

Example output:
```
lrwxrwxrwx 1 root root  9 Dec  9 10:00 ata-Samsung_SSD_860_EVO_500GB_S3Z9NB0K123456 -> ../../sda
lrwxrwxrwx 1 root root  9 Dec  9 10:00 ata-WDC_WD40EFRX-68N32N0_WD-WCC7K1234567 -> ../../sdb
```

Use the full `/dev/disk/by-id/ata-...` path in your configuration.

## Role Variables

### Safety Controls
- `lvm_enable`: Must be set to `true` to enable LVM operations (default: `false`). This prevents accidental data loss.

### Fast Pool (RAID 1)
- `lvm_fast_pool_devices`: List of devices for RAID 1 array (6x OCZ SSDs). **Uses `/dev/disk/by-id/` paths for stable device identification!**
- `lvm_fast_pool_vg_name`: Volume group name (default: "fast-pool")
- `lvm_fast_pool_lv_name`: Logical volume name (default: "fast-pool-lv")
- `lvm_fast_pool_mount_point`: Mount point path (default: "/var/lib/vms/fast-pool")
- `lvm_fast_pool_filesystem`: Filesystem type (default: "ext4")
- `lvm_fast_pool_raid_level`: RAID level (default: "1")
- `lvm_fast_pool_lv_size`: Logical volume size (default: "100%FREE")

### Slow Pool
- `lvm_slow_pool_devices`: List of devices (1.8TB WD drive). **Uses `/dev/disk/by-id/` paths for stable device identification!**
- `lvm_slow_pool_vg_name`: Volume group name (default: "slow-pool")
- `lvm_slow_pool_lv_name`: Logical volume name (default: "slow-pool-lv")
- `lvm_slow_pool_mount_point`: Mount point path (default: "/var/lib/vms/slow-pool")
- `lvm_slow_pool_filesystem`: Filesystem type (default: "ext4")
- `lvm_slow_pool_lv_size`: Logical volume size (default: "100%FREE")

### Mid Pool
- `lvm_mid_pool_directory`: Directory path (default: "/var/lib/vms/mid-pool")

### General
- `lvm_mount_options`: Mount options (default: "defaults,noatime,nofail,x-systemd.device-timeout=9")
- `lvm_wipe_signatures`: Whether to wipe existing signatures (default: yes)
- `lvm_force_recreate`: Force recreation of LVM setup, destroying existing data (default: false). When enabled, will:
  - Unmount filesystems
  - Remove logical volumes and volume groups
  - Stop RAID arrays
  - Zero RAID superblocks
  - Perform thorough signature wipe with wipefs

## Example Playbook

**IMPORTANT**: You must explicitly enable LVM operations by setting `lvm_enable: true`:

```yaml
- name: Configure storage
  hosts: hypervisor
  become: true
  roles:
    - role: lvm
      vars:
        lvm_enable: true  # Required to actually perform LVM operations
      tags: ["storage", "lvm"]
```

Without `lvm_enable: true`, the role will fail with a safety message.

The default configuration uses the actual hardware on the laphroaig server:
- RAID 1 with 6x OCZ-VELO DRIVE 139.7G SSDs
- Slow pool with 1x WDC WD20EZRX 1.8TB drive

### Force Recreation Example

**⚠️ WARNING: This will destroy all data!**

```yaml
- name: Force recreate storage (DESTROYS DATA!)
  hosts: hypervisor
  become: true
  roles:
    - role: lvm
      vars:
        lvm_enable: true
        lvm_force_recreate: true  # Will thoroughly wipe and rebuild everything
      tags: ["storage", "lvm"]
```

## Tags

- `system`: General system configuration
- `storage`: Storage-related tasks
- `lvm`: LVM-specific tasks

## Warnings

⚠️ **LVM operations are disabled by default** for safety. You must explicitly set `lvm_enable: true` to run this role.

⚠️ This role will **wipe existing data** on the specified devices when `lvm_wipe_signatures` is set to `yes`. Make sure you have backups before running this role.

⚠️ **Force recreation (`lvm_force_recreate: true`) will destroy all existing data!** This option will:
- Unmount all filesystems
- Remove all logical volumes and volume groups
- Stop all RAID arrays
- Thoroughly wipe all signatures and superblocks
Use this option only when you intentionally want to completely rebuild the storage from scratch.

## Dependencies

None

## License

See repository LICENSE file

## Author Information

Created for ansible-hypervisor project

