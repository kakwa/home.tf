# keepalived role

Configures Keepalived with a virtual IP on a given interface (for gateway / LB failover).

## Variables

- `keepalived_vip`: virtual IP (default: `192.168.1.19`).
- `keepalived_vip_prefix`: prefix length (default: `24`).
- `keepalived_interface`: NIC to bind the VIP to (default: `ansible_default_ipv4.interface`). Set per host in inventory for gateway machines, e.g. `eth0`, `ens18`, `br0`.
- `keepalived_router_id`, `keepalived_priority`, `keepalived_auth_pass`: VRRP tuning (for multi-node).
- `keepalived_chk_haproxy_interval`, `keepalived_chk_haproxy_weight`: health check for HAProxy (script `killall -0 haproxy`). On failure, priority is reduced by `|weight|` so another node can take the VIP.

## Example (inventory)

```ini
[gateway]
gw1 ansible_host=192.168.1.20
gw2 ansible_host=192.168.1.21

[gateway:vars]
keepalived_vip: 192.168.1.19

# Per host if NIC differs:
# gw1 keepalived_interface=eth0
# gw2 keepalived_interface=ens18
```
