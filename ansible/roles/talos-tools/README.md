# Talos Tools Role

This Ansible role installs packages used for Talos-related workflows on a hypervisor:

- **genisoimage** – create ISO images (e.g. for Talos machine configs)
- **tofu** – OpenTofu (IaC)
- **talosctl** – Talos Linux CLI (requires a repo that provides the package, e.g. misc-pkg)

## Requirements

- Debian/Ubuntu-based system
- Root/sudo access
- For `talosctl`: an APT repository that provides the `talosctl` package (e.g. misc-pkg) must be configured beforehand (e.g. via the `repos` role)

## Role Variables

Available variables are defined in `defaults/main.yml`:

- `talos_tools_packages`: list of package names to install (default: genisoimage, tofu, talosctl)

## Example Playbook

```yaml
---
- hosts: hypervisors
  become: true
  roles:
    - { role: talos-tools, tags: ["system", "talos-tools"] }
```

## License

Same as the parent repository.
