#!/bin/sh
# MetalLB (Helm) + L2 pool manifest, then Traefik (Helm, LoadBalancer by default).
# Uses metallb-lan.yaml and traefik-helm-values.yaml from tofu apply (K8S_DIR).
#
# Prerequisites: helm, kubectl; kubeconfig under K8S_DIR.
# Env: K8S_DIR, KUBECONFIG, TRAEFIK_NAMESPACE (default traefik),
#      METALLB_NAMESPACE (default metallb-system), METALLB_CHART_VERSION, TRAEFIK_CHART_VERSION (optional),
#      METALLB_APISERVER_BYPASS=0 to skip patching MetalLB to use CONTROL_PLANE_VIP:6443 instead of 10.96.0.1.
set -e

K8S_DIR="${K8S_DIR:-/opt/home.tf/k8s}"
METALLB_NS_MANIFEST="${K8S_DIR}/metallb-namespace.yaml"
METALLB_MANIFEST="${K8S_DIR}/metallb-lan.yaml"
TRAEFIK_NS_MANIFEST="${K8S_DIR}/traefik-namespace.yaml"
VALUES_FILE="${K8S_DIR}/traefik-helm-values.yaml"

: "${TRAEFIK_NAMESPACE:=traefik}"
: "${METALLB_NAMESPACE:=metallb-system}"

if ! [ -f "$METALLB_NS_MANIFEST" ] || ! [ -f "$METALLB_MANIFEST" ] || ! [ -f "$TRAEFIK_NS_MANIFEST" ] || ! [ -f "$VALUES_FILE" ]; then
  echo "error: missing manifests or values (run tofu apply). Expected:" >&2
  echo "  ${METALLB_NS_MANIFEST}" >&2
  echo "  ${METALLB_MANIFEST}" >&2
  echo "  ${TRAEFIK_NS_MANIFEST}" >&2
  echo "  ${VALUES_FILE}" >&2
  exit 1
fi

if [ -z "${KUBECONFIG:-}" ]; then
  export KUBECONFIG="${K8S_DIR}/kubeconfig"
fi

if ! [ -f "$KUBECONFIG" ]; then
  echo "error: kubeconfig not found at ${KUBECONFIG}" >&2
  exit 1
fi

for cmd in kubectl helm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: ${cmd} not found in PATH." >&2
    exit 1
  fi
done

echo "========================================"
echo " MetalLB (Helm + L2 pool)"
echo "========================================"
echo "Kubeconfig: ${KUBECONFIG}"
echo "Namespace:  ${METALLB_NS_MANIFEST}"
echo "Manifest:   ${METALLB_MANIFEST}"
echo "========================================"

# PSA privileged: speaker/FRR need NET_ADMIN, hostNetwork, etc. (Talos restricted default).
# METALLB_NAMESPACE must match tofu var metallb_namespace used to generate these files.
kubectl apply -f "$METALLB_NS_MANIFEST"

helm repo add metallb https://metallb.github.io/metallb --force-update
helm repo update metallb

if [ -n "${METALLB_CHART_VERSION:-}" ]; then
  helm upgrade --install metallb metallb/metallb \
    --namespace "$METALLB_NAMESPACE" \
    --version "$METALLB_CHART_VERSION"
else
  helm upgrade --install metallb metallb/metallb \
    --namespace "$METALLB_NAMESPACE"
fi

# Pods that use in-cluster config often get https://10.96.0.1:443; when kube-proxy/CNI path is broken,
# point client-go at the real apiserver (talos-env.sh CONTROL_PLANE_VIP, port 6443). Requires VIP in apiserver cert SANs (normal Talos VIP setup).
CONTROL_PLANE_VIP=""
if [ -r "${K8S_DIR}/talos-env.sh" ]; then
  eval "$(grep '^export CONTROL_PLANE_VIP=' "${K8S_DIR}/talos-env.sh" || true)"
fi
if [ "${METALLB_APISERVER_BYPASS:-1}" != "0" ] && [ -n "${CONTROL_PLANE_VIP}" ]; then
  echo "MetalLB: patching controller/speaker to use apiserver https://${CONTROL_PLANE_VIP}:6443 (bypass kubernetes Service ClusterIP)."
  _i=0
  while [ "$_i" -lt 45 ]; do
    if kubectl -n "$METALLB_NAMESPACE" get deploy metallb-controller >/dev/null 2>&1 &&
      kubectl -n "$METALLB_NAMESPACE" get daemonset metallb-speaker >/dev/null 2>&1; then
      kubectl -n "$METALLB_NAMESPACE" set env deployment/metallb-controller \
        KUBERNETES_SERVICE_HOST="${CONTROL_PLANE_VIP}" \
        KUBERNETES_SERVICE_PORT=6443 \
        --containers=controller
      kubectl -n "$METALLB_NAMESPACE" set env daemonset/metallb-speaker \
        KUBERNETES_SERVICE_HOST="${CONTROL_PLANE_VIP}" \
        KUBERNETES_SERVICE_PORT=6443 \
        --containers=speaker
      break
    fi
    _i=$((_i + 1))
    sleep 2
  done
fi

kubectl rollout status deployment/metallb-controller -n "$METALLB_NAMESPACE" --timeout=300s
kubectl rollout status daemonset/metallb-speaker -n "$METALLB_NAMESPACE" --timeout=300s

kubectl apply -f "$METALLB_MANIFEST"

echo "========================================"
echo " Traefik (Helm, in-cluster)"
echo "========================================"
echo "Namespace:  ${TRAEFIK_NAMESPACE}"
echo "Values:     ${VALUES_FILE}"
echo "========================================"

# PSA baseline: satisfies seccomp defaults vs cluster restricted mode (Talos).
kubectl apply -f "$TRAEFIK_NS_MANIFEST"

helm repo add traefik https://traefik.github.io/traefik-helm-chart --force-update || true
helm repo update traefik

if [ -n "${TRAEFIK_CHART_VERSION:-}" ]; then
  helm upgrade --install traefik traefik/traefik \
    --namespace "$TRAEFIK_NAMESPACE" \
    -f "$VALUES_FILE" \
    --version "$TRAEFIK_CHART_VERSION"
else
  helm upgrade --install traefik traefik/traefik \
    --namespace "$TRAEFIK_NAMESPACE" \
    -f "$VALUES_FILE"
fi

echo "========================================"
echo " MetalLB + Traefik installed."
echo " Pool: see ${METALLB_MANIFEST} (default 192.168.1.48/28)."
echo " Traefik LB: kubectl -n ${TRAEFIK_NAMESPACE} get svc"
echo "========================================"
