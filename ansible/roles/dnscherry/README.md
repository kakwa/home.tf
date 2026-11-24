# dnscherry role

Web UI for BIND zones (the DNS counterpart of `ldapcherry`): manages records
in `int.kakwalab.ovh` via **TSIG (RFC 2136) dynamic updates** — the same
`sec1_key` the `bind_dns` role configures in `named.conf` and Terraform pushes
with. Runs behind **nginx** (self-signed TLS by default) with **LDAP
authentication** against the OpenLDAP server.

- Package: `dnscherry` from the [kakwalab-pkg](https://github.com/kakwa/kakwalab-pkg)
  repo (added by the `repos` role); listens on `127.0.0.1:8080`.
- Auth: `dnscherry.auth.modLdap` — users from `ou=people,dc=kakwalab,dc=ovh`,
  restricted to `cn=admins,ou=groups,...` (change `dnscherry_ldap_groupdn` to
  allow other groups; empty groupdn = all LDAP users).
- The config contains the TSIG key and the LDAP bind password — file is
  `root:dnscherry 0640`, service runs as the `dnscherry` user.

## Variables

- `dnscherry_zone` – zone to manage (default: from `bind_dns_zone`)
- `dnscherry_tsig_key` – TSIG key secret (default: from `bind_dns_tsig_secret`)
- `dnscherry_ldap_uri` – LDAP server (default: `ldaps://ldap.int.kakwalab.ovh`)
- `dnscherry_ldap_userdn` / `dnscherry_ldap_groupdn` – auth base DNs
- `dnscherry_ldap_binddn` / `dnscherry_ldap_bindpassword` – LDAP service
  account (default: `cn=admin` + `openldap_admin_password`, so the password
  file generated for the LDAP VM is reused)
- `dnscherry_nginx_*` – nginx reverse proxy (same conventions as `ldapcherry`)

## Access

`https://dnscherry.int.kakwalab.ovh/` (or `https://192.168.1.25/`), log in
with an LDAP account that is a member of `cn=admins` (e.g. `carpenti`).
