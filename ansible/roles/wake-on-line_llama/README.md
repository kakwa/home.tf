# AI Power Role

This Ansible role configures power management for the physical AI host (`ai.local`): Wake-on-LAN so the machine can be woken remotely, and automatic suspend-to-RAM when `llama-server` sits idle.

## Features

- Persists Wake-on-LAN (magic packet) on the configured NICs via a udev rule, so WOL survives reboots
- Applies `ethtool` WOL settings immediately for the current boot
- Installs `ai-power-monitor.service`, a python3 daemon that polls `llama-server`'s Prometheus `/metrics` endpoint (localhost only)
- Suspends the host (`systemctl suspend`, suspend-to-RAM) after a configurable idle timeout
- Tracks activity via the `llamacpp:tokens_predicted_total` counter and in-flight request gauges, so the idle clock survives service restarts and suspend/resume cycles

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

### Idle Suspend

- `ai_power_sleep_mode`: systemd sleep action used when idle: `suspend` for suspend-to-RAM (light sleep, quick wake) or `hibernate` for suspend-to-disk (default: `suspend`)
- `ai_power_idle_timeout`: Suspend when `llama-server` has been idle this long, in seconds (default: `900` = 15 minutes)
- `ai_power_metrics_url`: `llama-server` metrics endpoint (default: `http://127.0.0.1:8080/metrics`)
- `ai_power_poll_interval`: How often to poll the metrics endpoint, in seconds (default: `30`)
- `ai_power_status_log_interval`: How often to log a state dump with the sleep countdown, in seconds (default: `30`; `0` logs on every poll)

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
4. **Idle detection**: The daemon polls the metrics endpoint and treats activity as either movement of the monotonic `llamacpp:tokens_predicted_total` counter or any in-flight request (`llamacpp:requests_processing` / `llamacpp:requests_deferred` > 0). Every `ai_power_status_log_interval` seconds it logs a state dump with the last activity time, idle seconds, sleep countdown (`sleep_in`/`sleep_at`), counter and in-flight requests.
5. **Sleep**: When neither happens for `ai_power_idle_timeout` seconds, the host is suspended via `systemctl suspend` (or hibernated via `systemctl hibernate` when `ai_power_sleep_mode` is set to `hibernate`).
6. **State**: The activity baseline (last counter value + last-activity timestamp) is persisted to `/var/lib/ai-power/state.json`, so the idle clock survives service restarts and suspend/resume cycles. A counter value lower than the saved one means `llama-server` restarted (zeroed counters, e.g. after resume); the clock restarts from now in that case.

The NetBSD proxy side (`netbsd-waker`) is documented in
`ansible-netbsd/roles/netbsd-waker/README.md`.

## Verification

```bash
# WOL enabled on the NICs
ethtool enp4s0f0 | grep "Wake-on"   # expect: Wake-on: g

# Monitor service running
systemctl status ai-power-monitor

# Monitor log (periodic state dumps, sleep countdown and suspend events)
journalctl -u ai-power-monitor -f

# Persisted activity baseline
cat /var/lib/ai-power/state.json
```

To test the full cycle:

1. Wait for the idle timeout (or shorten `ai_power_idle_timeout`) and confirm the host suspends.
2. Wake it with a magic packet from the NetBSD proxy (`netbsd-waker` role).
3. Confirm `llama-server` is responsive and the monitor resumes tracking. The idle clock is reset on resume so the host does not immediately suspend again.

## Notes

- The monitor resets the idle clock after `systemctl suspend` returns (i.e. after resume), so a wake does not immediately trigger another suspend.
- `Restart=always` (15s delay) keeps the monitor alive if it ever exits unexpectedly; a failed `systemctl suspend`/`hibernate` is logged and retried after the idle timeout.
- The udev rule only matches on `add|change` events for the NICs listed in `ai_power_wol_nics`; rename a NIC and update the variable accordingly.
- The metrics endpoint must remain reachable on localhost; failed polls are logged and simply do not reset the idle clock.
- Swap is only required when `ai_power_sleep_mode` is `hibernate`; suspend-to-RAM does not use swap.
- Wake-on-LAN from suspend-to-RAM keeps the NIC powered but still depends on the BIOS/ACPI wake configuration; if magic packets do not wake the host, check `cat /proc/acpi/wakeup` and the BIOS "Wake on LAN" / "Power on by PCI-E" setting.

## Dependencies

- `llama-server`: provides the `/metrics` endpoint the monitor polls (must be configured with `llama_server_endpoint_metrics: true`)

## License

Same as the parent repository.
