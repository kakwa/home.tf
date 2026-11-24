# bind_dns role

Debian port of the `openbsd-dns` role (knot + unbound) from
`ansible/ansible-openbsd`: a single BIND (`named`) instance on port 53 is both
the authoritative server for `int.kakwalab.ovh` and the recursive resolver for
the LAN.

- Authoritative master zone with **TSIG (RFC 2136) dynamic updates** — the same
  key the Terraform `hashicorp/dns` provider uses (`sec1_key`, hmac-sha512).
  In `tofu/infra/dns.auto.tfvars.json` (gitignored) set:

  ```json
  {
    "dns_update_server": "192.168.1.25",
    "dns_update_port": 53,
    "dns_tsig_key_name": "sec1_key",
    "dns_tsig_key_secret": "<contents of ansible/dns_tsig_secret.txt>"
  }
  ```

  When `dns_update_server` is empty, `tofu/infra/dns.tf` skips DNS record
  configuration entirely.
- Recursive resolver for the private ranges (loopback, `10.0.0.0/8`,
  `172.16.0.0/12`, `192.168.0.0/16`), forwarding to the upstream server, with
  DNSSEC validation.
- Adblock: the [StevenBlack hosts list](https://github.com/StevenBlack/hosts)
  (`fakenews-gambling` alternate), fetched on every run and loaded as a
  **Response Policy Zone** (RPZ, RFC 8125) — each `0.0.0.0 <domain>` line
  becomes a `CNAME .` record (plus a `*.domain` wildcard) in
  `/var/cache/bind/adblock.local.zone` (~165k domains). The CNAME-to-root is
  the RPZ action that makes named answer **NXDOMAIN** for blocked domains and
  their subdomains.
- The generated RPZ zone header carries a **glue `A` record for the NS name**
  (`ns1.adblock.local. IN A 127.0.0.1`). BIND will not load a master zone whose
  NS has no address record — it logs `NS … has no address records` and the zone
  is "not loaded due to errors", which **silently disables the whole RPZ** even
  though `named-checkconf` passes and the zone file looks valid. Don't remove it.
- The zone master file is deployed **only if it does not exist**, so dynamic
  updates from Terraform persist across runs. Delete
  `/var/cache/bind/int.kakwalab.ovh.db` to redeploy the static records.
- Takes over port 53 from systemd-resolved (`RESOLVCONF=no`,
  `DNSStubListener=no`) and points the VM's own `/etc/resolv.conf` at
  `127.0.0.1`.
- The config is validated with `named-checkconf` before the service is
  (re)started, so config errors fail the play cleanly.

## Variables

- `bind_dns_zone` – zone name (default: `int.kakwalab.ovh`)
- `bind_dns_tsig_key_name` / `bind_dns_tsig_algorithm` / `bind_dns_tsig_secret` –
  TSIG key for dynamic updates. The secret is loaded from the gitignored
  `ansible/dns_tsig_secret.txt` (or `vault_bind_dns_tsig_secret`) by
  `infra-dns.yml`; the role default is empty.
- `bind_dns_forwarders` – upstream servers for recursion (default: `192.168.1.254`)
- `bind_dns_allowed_query` / `bind_dns_allowed_recursion` / `bind_dns_allowed_transfer`
  – access lists (default: loopback + RFC 1918 private ranges; transfer is
  `192.168.1.0/24`)
- `bind_dns_zone_records` – static records written to the zone master on first
  deploy (`ns1`, `dns`, `ldap`, `ansible-master`)
- `bind_dns_adblock_url` – StevenBlack hosts list to use
- `bind_dns_rpz_zone` / `bind_dns_adblock_zone_file` – RPZ zone name and file

## Manual adblock refresh

`/usr/local/bin/update-dns-adblock` (deployed by the role) refetches the list
and restarts named.
