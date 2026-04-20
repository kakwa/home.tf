# home.tf

Insfrastructure as Code stuff for my self-hosted homelab experiments (Talos/Kubernetes, VMs, Ansible).

It might also leverage stuff (reverse proxy, DNS) deploged in 

- [ansible-netbsd](https://github.com/kakwa/ansible-netbsd)
- [ansible-openbsd](https://github.com/kakwa/ansible-openbsd)

## Layout

- **`terraform/`**: declarative `hcl` code for my lab, with a few templates and scripts thrown in.
- **`ansible/`**: Ansible roles and playbooks for the VMs
- **`helm-charts/`** — small Helm/K8s charts used to deploy some basic apps

## Disclaimer

This code is heavily tied to my environment. Don't expect to reuse it. At most, it can only serve as an inspiration.

## Stuff Currently Deployed

* Talos K8s cluster
* Docker Registry on a classic VM
* Ldap Server on a classic VM
* Bits of libvirtd hypervisor configuration