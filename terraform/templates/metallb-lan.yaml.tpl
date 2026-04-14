# Applied after Helm installs MetalLB (init-traefik.sh). Namespace must exist.
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: lan-pool
  namespace: metallb-system
spec:
  addresses:
    - ${metallb_pool}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: lan-pool-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - lan-pool
