#!/bin/sh
# Refresh the BIND RPZ adblock zone from the StevenBlack hosts list.
# (The bind_dns Ansible role does this on every run; this is for manual updates.)
set -eu

RPZ_ZONE="adblock.local"
ZONE_FILE="/var/cache/bind/adblock.local.zone"
URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling/hosts"

# Each "0.0.0.0 <domain>" line becomes "<domain> IN CNAME ." plus a
# "*.domain IN CNAME ." wildcard: the CNAME to the root is the RPZ action
# that makes named answer NXDOMAIN for the domain (BIND's QNAME trigger
# matches exact names only, hence the wildcard for subdomains).
{
  echo '$TTL 3600'
  echo '$ORIGIN adblock.local.'
  echo '@ IN SOA ns1.adblock.local. hostmaster.adblock.local. ('
  echo '    1 ; serial'
  echo '    3600 ; refresh'
  echo '    900 ; retry'
  echo '    3600000 ; expire'
  echo '    3600 ) ; minimum'
  echo ' IN NS ns1.adblock.local.'
  # Glue A record for the NS name: without it BIND refuses to load the zone
  # ("NS has no address records") and the entire RPZ silently stops working.
  echo 'ns1 IN A 127.0.0.1'
  curl -fsSL "$URL" \
    | grep -E '^0\.0\.0\.0[[:space:]]' \
    | awk '{print $2}' \
    | grep -vE '^(0\.0\.0\.0|::1|localhost|255\.255\.255\.255)$' \
    | sort -u \
    | awk '{print $0 " IN CNAME ."; print "*." $0 " IN CNAME ."}'
} > "$ZONE_FILE.new"
mv "$ZONE_FILE.new" "$ZONE_FILE"
chown root:bind "$ZONE_FILE"
chmod 0644 "$ZONE_FILE"
systemctl restart named
