# OS Config Role

Catch-all for OS-level tweaks applied to every host. Kept intentionally small
for now.

## What it does

- Disables APT recommended packages by writing
  `/etc/apt/apt.conf.d/99no-recommends`:

  ```
  APT::Install-Recommends "false";
  ```

  Ansible's `apt` module leaves `install_recommends` unset by default, so it
  honours this system setting for all later package installs. Roles run in
  order, so `os_config` is listed first in each playbook.
- Installs the base package list (`man-db`, which provides the `man` command
  on Debian) after writing the APT config, so no-recommends applies to it.

Set `os_config_apt_disable_recommends: false` to remove the config file and
restore the distro default. Override `os_config_packages` to change or extend
the base package list.

## Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `os_config_apt_disable_recommends` | `true` | Write the no-recommends config |
| `os_config_apt_conf_dir` | `/etc/apt/apt.conf.d` | APT config directory |
| `os_config_apt_recommends_conf` | `{{ os_config_apt_conf_dir }}/99no-recommends` | Config file path |
| `os_config_packages` | `[man-db]` | Base packages installed on every host |

## Usage

```yaml
roles:
  - { role: os_config, tags: ["system", "os_config"] }
```
