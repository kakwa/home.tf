# Avahi mDNS/Zeroconf Role

This Ansible role configures Avahi for mDNS/Zeroconf service discovery, allowing the hypervisor to be accessed via `.local` hostnames on the local network.

## Description

Avahi is the Linux implementation of Apple's Bonjour/Zeroconf. This role configures the system to announce itself on the local network using mDNS, making it accessible via easy-to-remember `.local` hostnames instead of IP addresses.

## Features

- ✅ Installs avahi-daemon and utilities
- ✅ Announces configured hostname as `<hostname>.local` (e.g., `kvm.local`)
- ✅ Publishes additional hostname aliases (e.g., `ai.local`) as mDNS A records via `avahi-publish`
- ✅ Enables mDNS resolution in nsswitch.conf
- ✅ Supports both IPv4 and IPv6

## Requirements

- Debian/Ubuntu-based system
- Network with multicast support
- Root/sudo access

## Role Variables

### Hostname Configuration
- `avahi_hostname`: Primary hostname to announce (default: `"kvm"` - set to `""` to use system hostname)
- `avahi_additional_hostnames`: List of additional hostname aliases, each resolvable as `<name>.local` (default: `["ai", "kvm"]`). Each entry gets a systemd unit running `avahi-publish -a` that announces an A record for the name
- `avahi_lan_ip`: LAN IP address published by the alias units. Empty (default) auto-detects the primary IPv4 address from facts, falling back to `ansible_host`
- `avahi_domain_name`: Domain name to use (default: `"local"`)

### Network Settings
- `avahi_use_ipv4`: Enable IPv4 (default: `yes`)
- `avahi_use_ipv6`: Enable IPv6 (default: `yes`)
- `avahi_allow_interfaces`: Specific interfaces to use (default: `""` - all)
- `avahi_deny_interfaces`: Interfaces to exclude (default: `""`)

### Service Publishing
- `avahi_publish_addresses`: Publish IP addresses (default: `yes`)
- `avahi_publish_workstation`: Publish as workstation (default: `yes`)
- `avahi_publish_hinfo`: Publish hostname info (default: `yes`)

### Service Control
- `avahi_service_enabled`: Enable avahi-daemon service (default: `true`)
- `avahi_service_state`: Service state (default: `started`)

### Packages
- `avahi_packages`: List of packages to install (default: `avahi-daemon`, `avahi-utils`, `libnss-mdns`)

## Example Playbook

```yaml
- name: Configure mDNS discovery
  hosts: hypervisor
  become: true
  roles:
    - role: avahi
      tags: ["network", "avahi"]
      vars:
        avahi_additional_hostnames:
          - "kvm"
          - "hypervisor"
```

## Usage

After running this role, the system will be accessible at:

- `kvm.local` (primary hostname announced by avahi-daemon)
- `ai.local` (additional alias, same machine)

You can test the configuration:

```bash
# Test name resolution
ping kvm.local
ping ai.local

# Browse discovered mDNS entries (services and addresses)
avahi-browse -at

# Check avahi status
systemctl status avahi-daemon

# Resolve hostname
avahi-resolve -n kvm.local
avahi-resolve -n ai.local
```

## How It Works

1. **avahi-daemon**: Announces the configured `host-name` via mDNS multicast (224.0.0.251 for IPv4)
2. **Alias A records**: The daemon only publishes an address record for its own `host-name`. For each entry in `avahi_additional_hostnames`, a systemd unit (`/etc/systemd/system/avahi-publish-<name>.service`) runs `avahi-publish -a -R <name>.local <ip>` to announce an A record, which is what makes `<name>.local` resolve
3. **NSS integration**: Enables mDNS name resolution via libnss-mdns

## Network Requirements

- Multicast must be enabled on the network
- Port 5353/UDP must not be blocked by firewall
- mDNS traffic uses multicast address 224.0.0.251 (IPv4) and ff02::fb (IPv6)

## Troubleshooting

### Can't resolve .local names

```bash
# Check if avahi is running
systemctl status avahi-daemon

# Check nsswitch.conf
grep hosts /etc/nsswitch.conf
# Should contain: mdns4_minimal [NOTFOUND=return]

# Test avahi resolution
avahi-resolve -n <hostname>.local
```

### Service not announcing

```bash
# Check avahi logs
journalctl -u avahi-daemon -f

# Verify network interfaces
avahi-browse -at

# Check firewall
sudo iptables -L | grep 5353
```

## Tags

- `system`: System configuration
- `network`: Network-related tasks
- `avahi`: Avahi-specific tasks

## Dependencies

None

## License

See repository LICENSE file

## Author Information

Created for ansible-hypervisor project



