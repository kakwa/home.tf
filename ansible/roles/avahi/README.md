# Avahi mDNS/Zeroconf Role

This Ansible role configures Avahi for mDNS/Zeroconf service discovery, allowing the hypervisor to be accessed via `.local` hostnames on the local network.

## Description

Avahi is the Linux implementation of Apple's Bonjour/Zeroconf. This role configures the system to announce itself on the local network using mDNS, making it accessible via easy-to-remember `.local` hostnames instead of IP addresses.

## Features

- ✅ Installs avahi-daemon and utilities
- ✅ Announces system hostname as `<hostname>.local` (e.g., `laphroaig.local`)
- ✅ Creates additional CNAME aliases (e.g., `kvm.local`)
- ✅ Enables mDNS resolution in nsswitch.conf
- ✅ Supports both IPv4 and IPv6
- ✅ Publishes workstation service for discovery

## Requirements

- Debian/Ubuntu-based system
- Network with multicast support
- Root/sudo access

## Role Variables

### Hostname Configuration
- `avahi_hostname`: Custom hostname to announce (default: `""` - uses system hostname)
- `avahi_additional_hostnames`: List of additional CNAME aliases (default: `["kvm"]`)
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

- `laphroaig.local` (the actual hostname)
- `kvm.local` (additional alias)

You can test the configuration:

```bash
# Test name resolution
ping laphroaig.local
ping kvm.local

# Browse available services
avahi-browse -at

# Check avahi status
systemctl status avahi-daemon

# Resolve hostname
avahi-resolve -n laphroaig.local
avahi-resolve -n kvm.local
```

## How It Works

1. **avahi-daemon**: Announces the hostname via mDNS multicast (224.0.0.251 for IPv4)
2. **Service files**: Creates XML service definitions in `/etc/avahi/services/`
3. **CNAME records**: Additional hostnames are published as CNAME aliases
4. **NSS integration**: Enables mDNS name resolution via libnss-mdns

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



