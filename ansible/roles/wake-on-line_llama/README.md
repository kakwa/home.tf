# AI Power Role

This Ansible role configures power management for the physical AI host (`ai.local`): Wake-on-LAN so the machine can be woken remotely, and automatic sleep when `llama-server` sits idle (default: `mem`, S3 suspend-to-RAM).

## Features

- Persists Wake-on-LAN (magic packet) on the configured NICs via a udev rule, so WOL survives reboots
- Applies `ethtool` WOL settings immediately for the current boot
- Installs `ai-power-monitor.service`, a python3 daemon that polls `llama-server`'s Prometheus `/metrics` endpoint (localhost only)
- Puts the host to sleep after a configurable idle timeout (default: `mem`, S3 suspend-to-RAM written directly to `/sys/power/state`; also supports `standby`/`disk`/`freeze` raw states and `systemctl` modes like `suspend`/`hibernate`)
- Pins the kernel memory sleep mode via `/etc/systemd/sleep.conf.d/90-ai-power.conf` (applies to `systemctl suspend` only, not `standby`)
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

- `ai_power_sleep_mode`: sleep mode used when idle (default: `mem`). Two families:
  - **Raw `/sys/power/state` values** (written directly, no systemd-sleep involved):
    - `standby`: S1 CPU idle; peripherals stay fully powered, so Wake-on-LAN works without any BIOS/firmware sleep-state involvement. Fastest entry/exit.
    - `mem`: S3 suspend-to-RAM (equivalent to `systemctl suspend`).
    - `disk`: S4 suspend-to-disk (hibernate).
    - `freeze`: freeze processes only, no hardware sleep.
  - **systemd-level modes** (issued via `systemctl <mode>`):
    - `suspend`, `hibernate`, `hybrid-sleep`, `suspend-then-hibernate`
- `ai_power_mem_sleep`: kernel memory sleep mode used by `mem`/`suspend`, written to `/sys/power/mem_sleep` by systemd (default: `s2idle`). Only relevant when `ai_power_sleep_mode` is `suspend` or `mem`. One of:
  - `s2idle`: suspend-to-idle; the CPUs enter idle states but the platform stays powered. Fastest to enter and resume, and the safe choice on this host.
  - `shallow`: a shallow platform sleep state, only if the firmware supports it.
  - `deep`: suspend-to-RAM (S3), the most power-saving but slowest mode. **Not recommended on `laphroaig`**: the freezer times out for 20s on `deep` and again on `shallow` before falling back, and `amdgpu`/KFD fails to restore `llama-server`, making a sleep cycle take 4–5 minutes.
  - `""` (empty): leave the kernel default untouched.
- `ai_power_idle_timeout`: Suspend when `llama-server` has been idle this long, in seconds (default: `600` = 10 minutes)
- `ai_power_stop_llama_on_sleep`: Stop `llama-server` before sleeping and restart it after wake (default: `true`). Freeing the GPU's pinned model buffers makes suspend/resume fast and avoids the `amdgpu`/KFD resume failure seen when the model is loaded (see "Notes").
- `ai_power_llama_service`: The systemd unit to stop/start around each sleep cycle (default: `llama-server.service`)
- `ai_power_llama_stop_timeout`: How long to wait for that unit to become fully inactive with an empty cgroup before sleeping, in seconds (default: `120`). The model unload / GPU flush can take a while. On timeout the monitor sends SIGKILL to the remaining processes and waits `ai_power_llama_stop_kill_grace` more seconds; if the unit is still not completely down it refuses to sleep and restarts `llama-server` instead.
- `ai_power_llama_stop_poll_interval`: How often to re-check the unit while waiting for it to stop, in seconds (default: `1`)
- `ai_power_llama_stop_kill_grace`: Extra time to wait after the SIGKILL escalation, in seconds (default: `10`)
- `ai_power_metrics_url`: `llama-server` metrics endpoint (default: `http://127.0.0.1:8080/metrics`)
- `ai_power_poll_interval`: How often to poll the metrics endpoint, in seconds (default: `30`)
- `ai_power_status_log_interval`: How often to log a state dump with the sleep countdown, in seconds (default: `20`; `0` logs on every poll)

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
3. **Sleep mode**: Writes `/etc/systemd/sleep.conf.d/90-ai-power.conf` with `SuspendState=mem` and `MemorySleepMode=<ai_power_mem_sleep>`. Only applies when `ai_power_sleep_mode` goes through systemd (i.e. `suspend` or `mem`); raw states like `standby` bypass systemd entirely.
4. **Monitor**: Writes `/usr/local/lib/ai-power/monitor.py` and `/etc/systemd/system/ai-power-monitor.service`, then enables and starts the service.
5. **Idle detection**: The daemon polls the metrics endpoint and treats activity as either movement of the monotonic `llamacpp:tokens_predicted_total` counter or any in-flight request (`llamacpp:requests_processing` / `llamacpp:requests_deferred` > 0). Every `ai_power_status_log_interval` seconds it logs a state dump with the last activity time, idle seconds, sleep countdown (`sleep_in`/`sleep_at`), counter and in-flight requests.
6. **Sleep**: When neither happens for `ai_power_idle_timeout` seconds, `llama-server` is stopped (if `ai_power_stop_llama_on_sleep`) and the monitor waits until the unit is fully inactive with no processes left in its cgroup before putting the host to sleep. If the shutdown does not complete within `ai_power_llama_stop_timeout`, the monitor SIGKILLs the remaining processes and waits `ai_power_llama_stop_kill_grace` more seconds; if the unit is still not completely down it refuses to sleep and restarts `llama-server` instead. The host is then put to sleep per `ai_power_sleep_mode`, and `llama-server` is restarted after wake. For raw states (`standby`, `mem`, `disk`, `freeze`) the value is written directly to `/sys/power/state`; for systemd modes (`suspend`, `hibernate`, etc.) the command is `systemctl <mode>`. `ai_power_mem_sleep` only applies to the `mem`/`suspend` path.

    The monitor also supports a one-shot `--now` flag for immediate sleep: `python3 /usr/local/lib/ai-power/monitor.py --now`. It performs one full stop-llama/sleep/wake/restart-llama cycle and exits. It also records a fresh activity baseline, which a concurrently running daemon adopts on its next poll, so the idle clock does not immediately re-trigger a sleep.
7. **State**: The activity baseline (last counter value + last-activity timestamp) is persisted to `/var/lib/ai-power/state.json`, so the idle clock survives service restarts and suspend/resume cycles. A counter value lower than the saved one means `llama-server` restarted (zeroed counters, e.g. after resume); the clock restarts from now in that case.

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

# Effective systemd sleep configuration
systemd-analyze cat-config systemd/sleep.conf | grep -A5 '^\[Sleep\]'

# Memory sleep mode currently selected by the kernel (the active mode is
# shown in brackets; systemd switches it to ai_power_mem_sleep on suspend)
cat /sys/power/mem_sleep

# Wake-up latency after a WOL magic packet (HTTPS readiness)
time curl -sk -o /dev/null -w '%{http_code}\n' https://ai.local/
```

To test the full cycle:

1. Wait for the idle timeout (or shorten `ai_power_idle_timeout`), or trigger it immediately with `python3 /usr/local/lib/ai-power/monitor.py --now`, and confirm the host suspends.
2. Wake it with a magic packet from the NetBSD proxy (`netbsd-waker` role).
3. Confirm `llama-server` has been restarted and is responsive, and that the monitor resumes tracking. The idle clock is reset on resume so the host does not immediately suspend again.

## Notes

- The monitor resets the idle clock after the sleep call returns (i.e. after resume), so a wake does not immediately trigger another sleep.
- Stopping `llama-server` before sleep (`ai_power_stop_llama_on_sleep: true`) releases the GPU's pinned model buffers, which is what makes suspend/resume fast on `laphroaig`: the `amdgpu`/KFD "Restore process ... failed during resume" error only happens when the model is loaded, and it is what made `deep` cycles take minutes. The monitor confirms the unit is fully inactive **and** its cgroup is empty before sleeping, escalating to SIGKILL after `ai_power_llama_stop_timeout`; if it still cannot confirm shutdown it skips the sleep cycle rather than suspending with the model resident.
- `Restart=always` (15s delay) keeps the monitor alive if it ever exits unexpectedly; a failed sleep is logged and retried after the idle timeout.
- The udev rule only matches on `add|change` events for the NICs listed in `ai_power_wol_nics`; rename a NIC and update the variable accordingly.
- The metrics endpoint must remain reachable on localhost; failed polls are logged and simply do not reset the idle clock.
- Swap is only required when `ai_power_sleep_mode` is `disk` or `hibernate`.
- With `standby` (S1), all peripherals including the NIC remain fully powered, so Wake-on-LAN works without any BIOS/ACPI sleep-state configuration — the most reliable WOL option on this host. With `mem`/`suspend`, the NIC may be powered down depending on the BIOS/ACPI wake configuration; if magic packets do not wake the host, check `cat /proc/acpi/wakeup` and the BIOS "Wake on LAN" / "Power on by PCI-E" setting.
- On `laphroaig`, `deep` is effectively unusable: the freezer times out for 20s (`Freezing remaining freezable tasks failed ... wq_busy=1`), systemd then tries `shallow` and times out again, and the eventual `s2idle` entry plus `amdgpu`/KFD resume failure (`Restore process pid ... failed during resume`, pointing at `llama-server`) stretched one cycle to ~5m36s. Pinning `s2idle` avoids the fallback attempts and keeps the GPU powered, so it resumes in seconds instead of minutes.
- The sleep-mode drop-in (`/etc/systemd/sleep.conf.d/90-ai-power.conf`) only affects modes that go through systemd-sleep (`suspend`, `mem`); raw states like `standby` bypass it entirely.

## Dependencies

- `llama-server`: provides the `/metrics` endpoint the monitor polls (must be configured with `llama_server_endpoint_metrics: true`)

## License

Same as the parent repository.
