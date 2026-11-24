# Root SSH Role

Disables direct root login over SSH on the physical hosts.

## What it does

- Removes the legacy `/etc/ssh/sshd_config.d/99-allow-root.conf` drop-in so
  two conflicting `PermitRootLogin` directives cannot coexist.
- Writes `/etc/ssh/sshd_config.d/99-root-login.conf` containing:

  ```
  PermitRootLogin no
  ```

- Restarts `ssh` via the handler.

The role no longer manages `/root/.ssh` or root `authorized_keys`. Any keys
that were written by earlier runs are left in place but cannot be used for
SSH login. Administer the hosts with a normal account and `sudo` —
the `bootstrap` role (run by `bootstrap.yml` and every playbook) creates that
account's passwordless sudo and SSH key.

## Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `ssh_permit_root_login` | `no` | Value written to `PermitRootLogin` |
| `ssh_permit_root_login_conf` | `/etc/ssh/sshd_config.d/99-root-login.conf` | New drop-in |
| `ssh_permit_root_login_conf_deprecated` | `/etc/ssh/sshd_config.d/99-allow-root.conf` | Old drop-in removed on upgrade |

To temporarily allow key-only root logins, override
`-e ssh_permit_root_login=prohibit-password`.

## Usage

```yaml
roles:
  - { role: root_ssh, tags: ["system", "ssh"] }
```

Included by `hypervisor.yml` and `ai.yml`. Verify with:

```bash
ssh -o PreferredAuthentications=password root@ai.local  # must be refused
```
