# Bootstrap Role

Prepares a fresh Debian/Ubuntu host for Ansible. Runs before fact gathering and
before Python is installed: all remote work is done through `raw` over SSH.

## What it does

- Validates the login name and the controller's SSH public key.
- Detects elevation (passwordless sudo, falling back to `su`) and sets
  `ansible_become_method` for the rest of the playbook run.
- Installs `sudo`, `python3`, `python3-apt` and `python3-debian` if missing.
- Adds a passwordless-sudo drop-in for the login in `/etc/sudoers.d/`.
- Appends the controller's `~/.ssh/id_ed25519.pub` to the login's
  `authorized_keys`.
- Pins `ansible_python_interpreter` to `/usr/bin/python3` for later plays.
- Writes a marker file once all of the above succeeded.

The marker makes the role a no-op on subsequent runs: only one `raw` read is
sent to each host. Remove the marker on the host to re-run the steps, or pass
`-e bootstrap_force=true`. Bump `bootstrap_marker_content` when updating the
bootstrap steps so existing hosts pick up the changes.

Static IP configuration is deliberately **not** part of this role: it is
handled by the `static_ip` role so inventory address changes still apply on
normal runs.

## Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `bootstrap_login` | `ansible_user` or local `$USER` | Remote account to configure (must already exist) |
| `bootstrap_ssh_key_path` | `~/.ssh/id_ed25519.pub` | Public key deployed to the account |
| `bootstrap_ssh_key` | contents of the file above | Validated before any remote change |
| `bootstrap_become_method` | `""` (auto-detect) | Override elevation method |
| `bootstrap_become_password` | `""` | Explicit elevation password (otherwise use `-K`) |
| `bootstrap_marker_path` | `/etc/ansible/bootstrapped` | Marker checked/written with `raw` |
| `bootstrap_marker_content` | `bootstrap-v1` | Expected marker contents; bump to force a re-run |
| `bootstrap_force` | `false` | Ignore the marker and bootstrap anyway |

## Usage

Every configuration playbook starts with a short, fact-less play running this
role, so bootstrapping happens automatically on first contact:

```yaml
- name: Bootstrap hosts that are not ready for Ansible yet
  hosts: ai_servers
  gather_facts: false
  become: false
  roles:
    - role: bootstrap
      tags: ["system", "bootstrap"]
```

`bootstrap.yml` is a thin wrapper around the role (plus the `static_ip` play),
useful for the first password login or ad-hoc hosts:

```bash
ansible-playbook -k -K --limit ai -e "ansible_host=192.168.1.20" bootstrap.yml
```
