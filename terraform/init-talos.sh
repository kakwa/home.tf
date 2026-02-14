#!/usr/bin/env bash
set -euo pipefail

source ./talos-env.sh

CLUSTER_NAME="kawkalab-talos-cluster"
BOOTSTRAP_CP="${CONTROL_PLANE_IP[0]}"
TEMP_ENDPOINT="https://${BOOTSTRAP_CP}:6443"
export TALOSCONFIG=./talosconfig

########################################
# Detect re-run: already bootstrapped?
########################################
ALREADY_BOOTSTRAPPED=false
_kc_file="/tmp/talos-kc-check.$$"
if command -v timeout &>/dev/null; then
  _kc_cmd=( timeout 10 talosctl kubeconfig "${_kc_file}" --endpoints "${BOOTSTRAP_CP}" --nodes "${BOOTSTRAP_CP}" )
else
  _kc_cmd=( talosctl kubeconfig "${_kc_file}" --endpoints "${BOOTSTRAP_CP}" --nodes "${BOOTSTRAP_CP}" )
fi
if "${_kc_cmd[@]}" 2>/dev/null; then
  rm -f "${_kc_file}"
  ALREADY_BOOTSTRAPPED=true
  echo "Cluster already bootstrapped (kubeconfig reachable); skipping apply-config and bootstrap."
fi
rm -f "${_kc_file}"

echo "========================================"
echo " Phase 1: Initial Cluster Bring-Up"
echo "========================================"
echo "Bootstrap Control Plane: ${BOOTSTRAP_CP}"
echo "========================================"

########################################
# Generate config (temporary endpoint)
########################################
if [[ -f controlplane.yaml && -f worker.yaml && -f talosconfig ]]; then
  echo "Config files (controlplane.yaml, worker.yaml, talosconfig) exist; skipping gen config."
else
  talosctl gen config "${CLUSTER_NAME}" "${TEMP_ENDPOINT}"
fi

########################################
# Apply control planes (skip if already bootstrapped)
########################################
if [[ "${ALREADY_BOOTSTRAPPED}" != "true" ]]; then
  for ip in "${CONTROL_PLANE_IP[@]}"; do
    echo "Applying control plane config to ${ip}"
    talosctl apply-config --insecure --nodes "${ip}" --file controlplane.yaml
  done

  ########################################
  # Apply workers
  ########################################
  for ip in "${WORKER_IP[@]}"; do
    echo "Applying worker config to ${ip}"
    talosctl apply-config --insecure --nodes "${ip}" --file worker.yaml
  done

  echo "Waiting 120 seconds for reboot..."
  sleep 120

  ########################################
  # Bootstrap (ONLY ONCE)
  ########################################
  # --endpoints: where to connect for Talos API (gRPC); required so talosctl can reach the node
  talosctl bootstrap --endpoints "${BOOTSTRAP_CP}" --nodes "${BOOTSTRAP_CP}"
fi

echo "Waiting for cluster health..."
# Use explicit node lists (from talos-env.sh) so we don't rely on discovery.
# Note: 'waiting for all nodes to finish boot sequence' can lag after etcd/kubelet
# are already OK; Talos marks node stage 'running' only after internal controllers
# finish. If it times out but etcd/kubelet passed, cluster is usually usable.
talosctl health --endpoints "${BOOTSTRAP_CP}" --nodes "${BOOTSTRAP_CP}" \
  --control-plane-nodes "$(IFS=,; echo "${CONTROL_PLANE_IP[*]}")" \
  --worker-nodes "$(IFS=,; echo "${WORKER_IP[*]}")" \
  --wait-timeout 10m

########################################
# Get kubeconfig
########################################

talosctl kubeconfig .

echo "========================================"
echo " Phase 2: Enable Control Plane VIP"
echo "========================================"
echo "VIP: ${CONTROL_PLANE_VIP}"
echo "========================================"

########################################
# Skip Phase 2 if VIP already configured
########################################
VIP_ALREADY_SET=false
if talosctl get mc --endpoints "${BOOTSTRAP_CP}" --nodes "${BOOTSTRAP_CP}" -o yaml 2>/dev/null | grep -q "ip: ${CONTROL_PLANE_VIP}"; then
  VIP_ALREADY_SET=true
  echo "VIP ${CONTROL_PLANE_VIP} already present in machine config; skipping VIP patches."
fi

if [[ "${VIP_ALREADY_SET}" != "true" ]]; then
  ########################################
  # Enable VIP on control planes
  ########################################
  for ip in "${CONTROL_PLANE_IP[@]}"; do
    echo "Enabling VIP on ${ip}"
    talosctl patch mc \
      --endpoints "${ip}" \
      --nodes "${ip}" \
      --patch "
machine:
  network:
    interfaces:
      - interface: eth0
        dhcp: true
        vip:
          ip: ${CONTROL_PLANE_VIP}
"
  done

  echo "Waiting 15 seconds for VIP election..."
  sleep 15

  ########################################
  # Update cluster endpoint to VIP
  ########################################
  echo "Updating cluster endpoint to VIP"

  for ip in "${CONTROL_PLANE_IP[@]}"; do
    talosctl patch mc \
      --endpoints "${ip}" \
      --nodes "${ip}" \
      --patch "
cluster:
  controlPlane:
    endpoint: https://${CONTROL_PLANE_VIP}:6443
"
  done
fi

########################################
# Regenerate kubeconfig with VIP
########################################
# Use node IP; VIP may not yet serve Talos API
talosctl kubeconfig . --endpoints "${BOOTSTRAP_CP}"

echo "========================================"
echo " VIP Enabled Successfully"
echo "========================================"
echo "Test with:"
echo "  kubectl get nodes"
echo "Verify VIP:"
echo "  ping ${CONTROL_PLANE_VIP}"
echo "========================================"

