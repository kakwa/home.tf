# AI Power Role

This Ansible role configures power management for the physical AI host (`ai.local`): Wake-on-LAN so the machine can be woken remotely, and automatic hibernation when `llama-server` sits idle.

## Features

- Persists Wake-on-LAN (magic packet) on the configured NICs via a udev rule, so WOL survives reboots
- Applies `ethtool` WOL settings immediately for the current boot
- Installs `ai-power-monitor.service`, a python3 daemon that polls `llama-server`'s Prometheus `/metrics` endpoint (localhost only)
- Hibernates the host (`systemctl hibernate`) after a configurable idle timeout
- Tracks activity via the `llamacpp:tokens_predicted_total` counter and in-flight request gauges, so the idle clock survives service restarts and hibernate/wake cycles

## Requirements

- Debian/Ubuntu-based system with systemd
- Root/sudo access
- A running `llama-server` with a metrics endpoint on localhost (see the `llama-server` role)
- BIOS "Wake on LAN" / "Power on by PCI-E" enabled **manually** (not possible via Ansible)
- A magic packet sender to wake the host (the `netbsd-waker` role on the NetBSD proxy)

## Role Variables

Available variables are defined in `defaults/main.yml`:

### Wake-on-LAN

- `ai_power_wol_nics`: NICs to enable WOL on, matched by kernel name in the udev rule (default: `["enp4s0f0", "enp9s0"]`)
- `ai_power_wol_flags`: `ethtool` WOL flags (default: `g` = magic packet, unicast)

### Idle Hibernation

- `ai_power_idle_timeout`: Hibernate when `llama-server` has been idle this long, in seconds (default: `900` = 15 minutes)
- `ai_power_metrics_url`: `llama-server` metrics endpoint (default: `http://127.0.0.1:8080/metrics`)
- `ai_power_poll_interval`: How often to poll the metrics endpoint, in seconds (default: `30`)

### Paths

- `ai_power_state_dir`: State directory for the activity baseline (default: `/var/lib/ai-power`)
- `ai_power_lib_dir`: Where the monitor script lives (default: `/usr/local/lib/ai-power`)
- `ai_power_python`: Python interpreter used by the monitor (default: `/usr/bin/python3`)

## Example Playbook

Basic usage with defaults (see `ai.yml`):

```yaml
---
- name: AI Host Power Management
  hosts: ai.local
  become: true
  roles:
    - { role: ai-power, tags: ["ai", "power"] }
```

Custom configuration:

```yaml
---
- name: AI Host Power Management
  hosts: ai.local
  become: true
  roles:
    - role: ai-power
      vars:
        ai_power_wol_nics:
          - enp4s0
        ai_power_idle_timeout: 1800
        ai_power_poll_interval: 60
```

`ai.local` is a physical host and is not part of the Terraform-generated inventory, so run it with an inline inventory:

```bash
ansible-playbook -i "ai.local ansible_host=192.168.1.20 ansible_user=root," ai.yml
```

## How It Works

1. **Packages**: Installs `python3` and `ethtool` via apt.
2. **Wake-on-LAN**: Writes `/etc/udev/rules.d/90-ai-power-wol.rules`, which runs `ethtool -s <nic> wol g` whenever a configured NIC is added or changed. The role also applies the same settings immediately so WOL is active without a reboot.
3. **Monitor**: Writes `/usr/local/lib/ai-power/monitor.py` and `/etc/systemd/system/ai-power-monitor.service`, then enables and starts the service.
4. **Idle detection**: The daemon polls the metrics endpoint and treats activity as either movement of the monotonic `llamacpp:tokens_predicted_total` counter or any in-flight request (`llamacpp:requests_processing` / `llamacpp:requests_deferred` > 0).
5. **Hibernate**: When neither happens for `ai_power_idle_timeout` seconds, the host is hibernated via `systemctl hibernate`.
6. **State**: The activity baseline (last counter value + last-activity timestamp) is persisted to `/var/lib/ai-power/state.json`, so the idle clock survives service restarts and hibernate/wake cycles. A counter value lower than the saved one means `llama-server` restarted (zeroed counters, e.g. after wake); the clock restarts from now in that case.

The NetBSD proxy side (`netbsd-waker`) is documented in
`ansible-netbsd/roles/netbsd-waker/README.md`.

## Verification

```bash
# WOL enabled on the NICs
ethtool enp4s0f0 | grep "Wake-on"   # expect: Wake-on: g

# Monitor service running
systemctl status ai-power-monitor

# Monitor log (activity tracking, hibernate events)
journalctl -u ai-power-monitor -f

# Persisted activity baseline
cat /var/lib/ai-power/state.json
```

To test the full cycle:

1. Wait for the idle timeout (or shorten `ai_power_idle_timeout`) and confirm the host hibernates.
2. Wake it with a magic packet from the NetBSD proxy (`netbsd-waker` role).
3. Confirm `llama-server` is back up and the monitor resumes tracking from the saved baseline.

## Notes

- The monitor uses `Restart=always` (15s delay): if `systemctl hibernate` returns (unsupported, dry-run, swap error) the script keeps the service alive instead of spin-restarting.
- The udev rule only matches on `add|change` events for the NICs listed in `ai_power_wol_nics`; rename a NIC and update the variable accordingly.
- The metrics endpoint must remain reachable on localhost; failed polls are logged and simply do not reset the idle clock.
- Swap must be configured on the host for `systemctl hibernate` to work.

## Dependencies

- `llama-server`: provides the `/metrics` endpoint the monitor polls (must be configured with `llama_server_endpoint_metrics: true`)

## License

Same as the parent repository.
