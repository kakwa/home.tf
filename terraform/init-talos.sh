#!/usr/bin/env bash
set -euo pipefail

source ./talos-env.sh

CLUSTER_NAME="kawkalab-talos-cluster"
BOOTSTRAP_CP="${CONTROL_PLANE_IP[0]}"
TEMP_ENDPOINT="https://${BOOTSTRAP_CP}:6443"

echo "========================================"
echo " Phase 1: Initial Cluster Bring-Up"
echo "========================================"
echo "Bootstrap Control Plane: ${BOOTSTRAP_CP}"
echo "========================================"

########################################
# Generate config (temporary endpoint)
########################################

talosctl gen config "${CLUSTER_NAME}" "${TEMP_ENDPOINT}"
export TALOSCONFIG=./talosconfig

########################################
# Apply control planes
########################################

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

echo "Waiting for cluster health..."
talosctl health --endpoints "${BOOTSTRAP_CP}" --nodes "${BOOTSTRAP_CP}" --wait-timeout 10m

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

