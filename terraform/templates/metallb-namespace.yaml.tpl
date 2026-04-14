# PSA: MetalLB speaker/FRR need NET_ADMIN, hostNetwork, etc. — not compatible with restricted.
apiVersion: v1
kind: Namespace
metadata:
  name: ${namespace}
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
