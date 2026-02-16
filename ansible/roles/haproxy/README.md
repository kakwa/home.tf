# haproxy role

Installs and enables HAProxy. Configured as **Kubernetes API gateway**: TCP frontend on 6443, backend to control plane nodes. Stats UI on :8404.

## Variables

- `haproxy_packages`: list of packages (default: `[haproxy]`).
- `haproxy_k8s_api_bind`: bind for k8s API frontend (default: `*:6443`). Use `192.168.1.19:6443` to bind only on the VIP.
- `haproxy_k8s_api_servers`: list of backends, each `{ name: "...", address: "ip_or_fqdn", port: 6443 }`. Required for k8s gateway.

## Example (gateway playbook / group_vars/gateway.yml)

```yaml
haproxy_k8s_api_bind: "192.168.1.19:6443"
haproxy_k8s_api_servers:
  - { name: cp1, address: 192.168.1.11, port: 6443 }
  - { name: cp2, address: 192.168.1.12, port: 6443 }
```
