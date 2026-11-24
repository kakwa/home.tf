# home.tf

Insfrastructure as Code stuff for my self-hosted homelab experiments (Talos/Kubernetes, VMs, Ansible).

It might also leverage stuff (reverse proxy, DNS) deploged in 

- [ansible-netbsd](https://github.com/kakwa/ansible-netbsd)
- [ansible-openbsd](https://github.com/kakwa/ansible-openbsd)

## Layout

- **`terraform/`**: declarative `hcl` code for my lab, with a few templates and scripts thrown in.
- **`ansible/`**: Ansible roles and playbooks for the VMs
- **`helm-charts/`** — small Helm/K8s charts used to deploy some basic apps
- **`docs/`** — operational how-tos, starting with the [bootstrap guide](docs/bootstrap.md)

## Bootstrap

The end-to-end order (bare Proxmox host → pools/API tokens → infra VMs → BIND DNS →
OpenLDAP) is documented in [docs/bootstrap.md](docs/bootstrap.md). The AI server
is covered there as a separate track.

## Disclaimer

This code is heavily tied to my environment. Don't expect to reuse it. At most, it can only serve as an inspiration.

## Stuff Currently Deployed

* Talos K8s cluster
* Docker Registry on a classic VM
* Ldap Server on a classic VM
* Proxmox VE hypervisor (manual [ISO install](https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso); Ansible handles no-subscription repo, packages, nested virtualization)
* llama.cpp AI server on a separate host (manual [Debian testing install](https://cdimage.debian.org/cdimage/daily-builds/daily/current/amd64/iso-cd/debian-testing-amd64-netinst.iso); ROCm, Wake-on-LAN, idle suspend)