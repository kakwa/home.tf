# Proxmox Pools Role

Manages Proxmox "projects": named **pools**, a **user** (account) and an
**API token** per project, with the user granted a role on its own pool, and
**per-pool resource quotas** enforced by audit plus a pre-start hook.

Proxmox has no project abstraction; a pool is the closest thing. This role
gives each project its own account + token whose permissions are confined to
that pool, e.g. so different people or automation stacks (Terraform, a CI
user, experiments) each get an isolated slice of the hypervisor.

## What it does

For every entry in `pve_pools`:

1. Creates the user `user@pve_pools_realm` (default realm `pve`, i.e. the
   local internal realm) if it does not exist.
2. Creates the API token `user@realm!token` (default token name `token`) if
   it does not exist.
3. Creates the pool `name` if it does not exist.
4. Grants the configured role (default `PVEPoolAdmin`) on the pool to both
   the user and its token, if the grant is missing.
5. Audits pool usage against the entry's `quota` (see [Quotas](#quotas)).
6. Installs a pre-start hook that blocks VM start/migrate when it would push
   a pool over its CPU/RAM quota (skipped with a warning where `/etc/pve`
   cannot hold an executable file, see [Pre-start hook](#quotas)).

Everything is managed with `pvesh` (the local admin CLI), so no pre-existing
API token or controller-side credentials are needed. All tasks are
idempotent; re-running a converged host is a no-op.

The role targets the **PVE 9** API, which differs from older releases:

* Pools live at `/pools` (not `/access/pools`); create takes `--poolid`.
* User tokens live at `/access/users/<userid>/token/<tokenid>` (singular)
  and **PVE generates the secret** on create, returning it exactly once in
  the JSON response; the role captures it into the controller secret file.
  There is no `password` option for tokens.
* ACL grants use `/access/acl` with `--path /pool/<id>` (singular),
  `--users` and `--roles`; `GET /access/acl` has no filter options, so
  grants are matched client-side.
* A user's password can only be set **at creation time**; an existing
  account whose password file was lost cannot be resynchronized via the API
  (the role fails with instructions).
* On PVE 9, `/etc/pve` may be backed by **pmxcfs** (the `pve-cluster` FUSE
  filesystem), which rejects `chmod` and forces created files to 0640.

## Credentials

Secrets live in `pve_pools_secrets_dir` (default `{{ playbook_dir }}/pve_pools`,
i.e. `ansible/pve_pools/`, gitignored) on the **controller**, and are copied
to `pve_pools_dir` (default `/root/pve-credentials`) on the PVE host:

| File | Content | Generated | Permissions |
| --- | --- | --- | --- |
| `<user>.password` | plain password for `user@realm` (GUI/login) | controller, via `lookup('password', <file>)` (repo convention; stable across runs) | 0600 controller user / 0600 root on host |
| `<user>.token` | the API token secret for `user@realm!<token>` | by **PVE** at token create (returned exactly once), captured by the role | same |

On PVE 9 the token secret cannot be chosen up front: `pvesh create
/access/users/<userid>/token/<token>` has no password option and PVE
generates the secret, returning it once as JSON. The role parses it from
the create output and writes the controller file immediately after
creation.

The token **id** is not in the file — it is deterministic:
`<user>@<realm>!<token>` (e.g. `pocs@pve!token`).

Use the controller-side files wherever the credentials are needed. For
Terraform's `bpg/proxmox` provider:

```hcl
provider "proxmox" {
  pm_api_username = "pocs@pve!token"
  pm_api_token    = file("${path.module}/../../ansible/pve_pools/pocs.token")
}
```

### Lost credential files

* `<user>.password` missing: the password is regenerated **and** applied to
  the account (the file is resynchronized with the user).
* `<user>.token` missing: PVE only stores the token hash, so the secret is
  unrecoverable. The role prints a warning and leaves the token alone; delete
  the token and re-run to have it recreated:

  ```sh
  pvesh delete /access/users/pocs@pve/tokens/pocs@pve!token
  ```

## Quotas

PVE pools are permission groupings — they have **no native resource
quotas** — so this role implements them in two layers:

**Audit (every run).** A helper script (`pve_pools_quota_usage_script`,
default `/usr/local/sbin/pve-pool-usage`) reads
`/cluster/resources` once and sums the **allocated** (configured, not
live) resources of the VMs in each pool. The role reports the totals
against the entry's `quota` and, when `pve_pools_quota_enforce: true`,
fails the play on breach.

Quota keys (any subset): `max_vms`, `max_cpu` (sum of `cores * sockets`),
`max_ram_gb`, `max_disk_gb` (provisioned disk size).

**Pre-start hook (admission control).** When `pve_pools_quota_hook: true`
(default), the role renders a machine-readable quota config
(`pve_pools_quota_conf`, default `/etc/pve/pool-quotas.conf`, one line per
pool: `<pool> <max_cpu> <max_ram_gb>`) and installs
`/etc/pve/hooks/pre-start`, which PVE calls before a VM starts or migrates.
The hook computes the pool's current usage **excluding the starting VM**,
adds the VM's own allocation, and exits 1 (deny) if the result exceeds the
pool's CPU or RAM quota. Only CPU and RAM are enforced here: disk sizes are
reservations rather than usage, and VM counts are covered by the audit.

On PVE 9 hosts where `/etc/pve` is a pmxcfs FUSE mount the hook cannot be
made executable (`chmod` is rejected, files are forced to 0640), so the
role probes for this, skips the hook with a warning, and leaves quota
enforcement to the audit (set `pve_pools_quota_enforce: true` to fail the
play on breach).

To deny a start attempt, the hook prints
`pre-start: VM <id> would push pool '<pool>' CPU to N vCPU (quota M)` to
stderr, which PVE surfaces in the start error.

Example with quotas (see `inventory.yml`):

```yaml
pve_pools:
  - name: pocs
    user: pocs
    quota:
      max_vms: 2
      max_cpu: 10
      max_ram_gb: 12
      max_disk_gb: 60
  - name: k8s
    user: k8s
    email: k8s@example.com
```

## Role Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `pve_pools` | `[]` | One entry per project: `name` (pool id), `user`, `token` (default `token`), `role` (default `pve_pools_default_role`), optional `email`, optional `quota` (`max_vms`, `max_cpu`, `max_ram_gb`, `max_disk_gb`) |
| `pve_pools_realm` | `pve` | Realm of the created users |
| `pve_pools_default_role` | `PVEPoolAdmin` | Role granted on each pool (carries the `Pool.*` privileges, so the account can read and modify its own pool via API and UI) |
| `pve_pools_quota_enforce` | `false` | Fail the play when a quota is exceeded (otherwise report only) |
| `pve_pools_quota_dir` | `/usr/local/sbin` | Directory for the usage helper |
| `pve_pools_quota_usage_script` | `/usr/local/sbin/pve-pool-usage` | Path of the usage helper script |
| `pve_pools_quota_hook` | `true` | Install the pre-start hook (skipped with a warning if `/etc/pve` is a pmxcfs FUSE mount that cannot hold executable files) |
| `pve_pools_quota_hook_file` | `/etc/pve/hooks/pre-start` | Path of the pre-start hook |
| `pve_pools_quota_conf` | `/etc/pve/pool-quotas.conf` | Machine-readable quota config for the hook |
| `pve_pools_secrets_dir` | `{{ playbook_dir }}/pve_pools` | Controller-side secret files (gitignored) |
| `pve_pools_dir` | `/root/pve-credentials` | Host-side copy of the secret files |

`name`, `user` and `token` must match `^[a-zA-Z0-9_-]+$` (PVE id rules).

Useful built-in roles for a per-project account: `PVEPoolAdmin` (the
default; the `Pool.*` privileges — read and modify the pool itself),
`PVEVMAdmin` (create/manage VMs), `PVEVMUser` (start/stop/configure
existing VMs), `PVEAuditor` (read-only). See the
[Access Control wiki](https://pve.proxmox.com/wiki/Access_Control).

Two PVE quirks the defaults account for:

* The pool role governs the **pool path only**; PVE does not propagate pool
  grants to VM paths, so managing VMs additionally needs a `/vms` grant
  (included in `pve_pools_aux_grants`, granted to user and token).
* PVE 9 tokens default to `privsep:1`: a privsep token's effective
  permissions are the *intersection* of its own grants and its owning
  user's grants, so every grant must land on both.

Note: changing an entry's `role` adds the new grant; the old one is not
removed (other grants on the same path are preserved). PVE 9 has no ACL
delete endpoint, so stale grants are removed by editing the `acl` section
of `/etc/pve/user.cfg` (back up the file first; PVE picks up the change on
the next API request).

## Usage

```yaml
- hosts: hypervisor
  become: true
  roles:
    - { role: proxmox_pools, tags: ["hypervisor", "virtualization", "proxmox-pools"] }
```

`pve_pools` is configured per host in the inventory. Example (from
`inventory.yml`):

```yaml
kvm:
  pve_pools:
    - name: pocs
      user: pocs
    - name: k8s
      user: k8s
      role: PVEVMAdmin
      email: k8s@example.com
```

Adding a third project is just one more list entry.
