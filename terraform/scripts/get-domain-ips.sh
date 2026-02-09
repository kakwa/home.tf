#!/usr/bin/env bash
# Reads Terraform external data query from stdin: {"domains": "[\"name1\",\"name2\",...]"}
# Outputs JSON map of domain name -> first IPv4 address (from virsh domifaddr --source agent).
# Requires: jq, virsh. Guests must be running with qemu-guest-agent for IP discovery.
# On any error (missing jq/virsh, parse error) outputs {} and exits 0 so Terraform can fall back to static IPs.

set -e
output_empty() { echo '{}'; exit 0; }
trap output_empty ERR

input=$(cat)
domains=$(echo "$input" | jq -r '.domains | fromjson | .[]?' 2>/dev/null) || output_empty
result="{}"
while IFS= read -r dom; do
  [[ -z "$dom" ]] && continue
  # virsh domifaddr --source agent returns table with Address column (last column for ipv4); skip loopback
  ip=$(virsh domifaddr "$dom" --source agent 2>/dev/null | awk '/ipv4/ {gsub(/\/.*/,"",$NF); if ($NF != "127.0.0.1") { print $NF; exit } }')
  if [[ -n "$ip" ]]; then
    result=$(echo "$result" | jq -n --argjson r "$result" --arg d "$dom" --arg i "$ip" '$r + {($d): $i}')
  fi
done <<< "$domains"
echo "$result"
