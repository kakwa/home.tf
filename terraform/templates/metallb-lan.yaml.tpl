# Applied after Helm installs MetalLB (init-traefik.sh). Namespace must exist.
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: lan-pool
  namespace: ${namespace}
spec:
  addresses:
    - ${metallb_pool}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: lan-pool-l2
  namespace: ${namespace}
spec:
  ipAddressPools:
    - lan-pool
%{ if length(metallb_l2_interfaces) > 0 ~}
  interfaces:
%{ for iface in metallb_l2_interfaces ~}
    - ${iface}
%{ endfor ~}
%{ endif ~}
%{ if metallb_l2_workers_only && length(metallb_l2_interfaces) > 0 ~}
  nodeSelectors:
    - matchExpressions:
        - key: node-role.kubernetes.io/control-plane
          operator: DoesNotExist
        - key: node-role.kubernetes.io/master
          operator: DoesNotExist
%{ endif ~}
