#!/bin/sh
# MetalLB (Helm) + L2 pool manifest, then Traefik (Helm, LoadBalancer by default).
# Uses metallb-lan.yaml and traefik-helm-values.yaml from tofu apply (K8S_DIR).
#
# Prerequisites: helm, kubectl; kubeconfig under K8S_DIR.
# Env: K8S_DIR, KUBECONFIG, TRAEFIK_NAMESPACE (default traefik),
#      METALLB_NAMESPACE (default metallb-system), METALLB_CHART_VERSION, TRAEFIK_CHART_VERSION (optional).
set -e

K8S_DIR="${K8S_DIR:-/opt/home.tf/k8s}"
METALLB_MANIFEST="${K8S_DIR}/metallb-lan.yaml"
VALUES_FILE="${K8S_DIR}/traefik-helm-values.yaml"

: "${TRAEFIK_NAMESPACE:=traefik}"
: "${METALLB_NAMESPACE:=metallb-system}"

if ! [ -f "$METALLB_MANIFEST" ] || ! [ -f "$VALUES_FILE" ]; then
  echo "error: missing ${METALLB_MANIFEST} and/or ${VALUES_FILE} (run tofu apply)." >&2
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
echo "Manifest:   ${METALLB_MANIFEST}"
echo "========================================"

helm repo add metallb https://metallb.github.io/metallb --force-update
helm repo update metallb

if [ -n "${METALLB_CHART_VERSION:-}" ]; then
  helm upgrade --install metallb metallb/metallb \
    --namespace "$METALLB_NAMESPACE" \
    --create-namespace \
    --version "$METALLB_CHART_VERSION" \
    --wait
else
  helm upgrade --install metallb metallb/metallb \
    --namespace "$METALLB_NAMESPACE" \
    --create-namespace \
    --wait
fi

kubectl apply -f "$METALLB_MANIFEST"

echo "========================================"
echo " Traefik (Helm, in-cluster)"
echo "========================================"
echo "Namespace:  ${TRAEFIK_NAMESPACE}"
echo "Values:     ${VALUES_FILE}"
echo "========================================"

helm repo add traefik https://traefik.github.io/traefik-helm-chart --force-update
helm repo update traefik

if [ -n "${TRAEFIK_CHART_VERSION:-}" ]; then
  helm upgrade --install traefik traefik/traefik \
    --namespace "$TRAEFIK_NAMESPACE" \
    --create-namespace \
    -f "$VALUES_FILE" \
    --version "$TRAEFIK_CHART_VERSION"
else
  helm upgrade --install traefik traefik/traefik \
    --namespace "$TRAEFIK_NAMESPACE" \
    --create-namespace \
    -f "$VALUES_FILE"
fi

echo "========================================"
echo " MetalLB + Traefik installed."
echo " Pool: see ${METALLB_MANIFEST} (default 192.168.1.48/28)."
echo " Traefik LB: kubectl -n ${TRAEFIK_NAMESPACE} get svc"
echo "========================================"
