# Terraform sync role

Syncs the repository `terraform/` directory to the hypervisor and adds a `cdtf` alias for root to change into that directory.

## Requirements

- Source path `terraform_sync_src` must be set when including the role (e.g. from the playbook).
- Controller must have `rsync` available when using `synchronize`.

## Role variables

- `terraform_sync_dest`: Directory on the hypervisor where terraform files are synced (default: `/root/home.tf/terraform`).
- `terraform_sync_src`: **Required.** Path to the terraform directory on the controller (e.g. `"{{ playbook_dir }}/../terraform"`).
- `terraform_sync_excludes`: List of rsync exclude patterns (default excludes `.terraform/`, `*.tfstate*`, `.terraform.lock.hcl`).

## Example playbook

```yaml
- name: Hypervisor setup
  hosts: hypervisor
  become: true
  roles:
    - role: terraform-sync
      vars:
        terraform_sync_src: "{{ playbook_dir }}/../terraform"
      tags: ["terraform-sync"]
```

## Usage

After the role runs, on the hypervisor as root:

- `cdtf` changes to the synced terraform directory (e.g. `/root/home.tf/terraform`).
- Works in both bash and zsh.
