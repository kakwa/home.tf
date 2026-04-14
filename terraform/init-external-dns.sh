#!/bin/sh
# Install ExternalDNS (Helm) with RFC 2136 + TSIG. Reads talos-env.sh and Helm values from K8S_DIR
# (default /opt/home.tf/k8s), same layout as tofu apply / init-talos.sh.
#
# POSIX sh. talos-env.sh contains bash-only arrays for Talos IPs; we only eval export DNS_* lines.
#
# Prerequisites: kubectl, helm. Override: K8S_DIR=/path KUBECONFIG=/path ./init-external-dns.sh
set -e

K8S_DIR="${K8S_DIR:-/opt/home.tf/k8s}"

if ! [ -r "${K8S_DIR}/talos-env.sh" ]; then
  echo "error: ${K8S_DIR}/talos-env.sh not found (run tofu apply; check k8s_config_dir)." >&2
  exit 1
fi

eval "$(grep '^export DNS_' "${K8S_DIR}/talos-env.sh")"

: "${DNS_UPDATE_PORT:=5353}"
: "${DNS_ZONE:=int.kakwalab.ovh.}"
: "${DNS_TSIG_KEY_ALGORITHM:=hmac-sha512}"
: "${EXTERNAL_DNS_NAMESPACE:=external-dns}"

if [ -z "${KUBECONFIG:-}" ]; then
  export KUBECONFIG="${K8S_DIR}/kubeconfig"
fi

if ! [ -f "$KUBECONFIG" ]; then
  echo "error: kubeconfig not found at ${KUBECONFIG} (run init-talos.sh or set KUBECONFIG)." >&2
  exit 1
fi

for cmd in kubectl helm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: ${cmd} not found in PATH." >&2
    exit 1
  fi
done

if [ -z "$DNS_UPDATE_SERVER" ] || [ -z "$DNS_TSIG_KEY_NAME" ] || [ -z "$DNS_TSIG_KEY_SECRET" ]; then
  echo "error: missing DNS RFC2136 settings in talos-env.sh (DNS_UPDATE_SERVER, DNS_TSIG_KEY_NAME, DNS_TSIG_KEY_SECRET)." >&2
  echo "  Set them via Terraform / dns.auto.tfvars.json and run tofu apply." >&2
  exit 1
fi

DNS_ZONE_LABEL=${DNS_ZONE%.}
TSIG_KEYNAME=${DNS_TSIG_KEY_NAME%.}

VALUES_FILE="${K8S_DIR}/external-dns-helm-values.yaml"
if ! [ -f "$VALUES_FILE" ]; then
  echo "error: ${VALUES_FILE} missing (run tofu apply)." >&2
  exit 1
fi

echo "========================================"
echo " ExternalDNS (RFC 2136 + TSIG)"
echo "========================================"
echo "K8S_DIR:     ${K8S_DIR}"
echo "Kubeconfig:  ${KUBECONFIG}"
echo "DNS server:  ${DNS_UPDATE_SERVER}:${DNS_UPDATE_PORT}"
echo "Zone:        ${DNS_ZONE_LABEL}"
echo "Namespace:   ${EXTERNAL_DNS_NAMESPACE}"
echo "========================================"

kubectl create namespace "$EXTERNAL_DNS_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$EXTERNAL_DNS_NAMESPACE" create secret generic external-dns-rfc2136 \
  --from-literal=rfc2136-tsig-secret="$DNS_TSIG_KEY_SECRET" \
  --from-literal=rfc2136-tsig-keyname="$TSIG_KEYNAME" \
  --dry-run=client -o yaml | kubectl apply -f -

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/ --force-update
helm repo update external-dns

if [ -n "${EXTERNAL_DNS_CHART_VERSION:-}" ]; then
  helm upgrade --install external-dns external-dns/external-dns \
    --namespace "$EXTERNAL_DNS_NAMESPACE" \
    -f "$VALUES_FILE" \
    --version "$EXTERNAL_DNS_CHART_VERSION"
else
  helm upgrade --install external-dns external-dns/external-dns \
    --namespace "$EXTERNAL_DNS_NAMESPACE" \
    -f "$VALUES_FILE"
fi

echo "========================================"
echo " ExternalDNS installed."
echo " Check: kubectl -n ${EXTERNAL_DNS_NAMESPACE} get pods,logs deploy/external-dns"
echo "========================================"
