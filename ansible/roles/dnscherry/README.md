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

## Gotchas

### The `[dns.zones]` section is mandatory

`dnscherryd` mounts the ini with `cherrypy.tree.mount(...)`, so the file is
parsed by **CherryPy's config parser**, which **silently ignores any line
before the first section header**. Zone parameters
(`ip.<zone>`, `algorithm.<zone>`, `key.<zone>`) must therefore live under a
literal `[dns.zones]` section — the app reads them via
`config['dns.zones']` (`_parse_zones`). If the section is missing, the service
crashes on start with `KeyError: 'dns.zones'` (and `Restart=always` turns that
into an `activating (auto-restart)` loop that nginx answers with `502`).

### `[global]` needs `tools.sessions.on = True`

The app keeps the authenticated user in a CherryPy session
(`cherrypy.session[...]` in `check_auth()`). Without
`tools.sessions.on = True` in the ini, every authenticated request fails with
`AttributeError: module 'cherrypy' has no attribute 'session'` (HTTP 500 on
`/`).

### The TSIG key name must match named's `allow-update` key

dnscherry signs its RFC 2136 updates with the TSIG key *name*
`name.<zone>` from `[dns.zones]` (default: the zone name). named's
`allow-update { key sec1_key; }` matches that name, so a key named after the
zone is rejected with `PeerBadKey` ("Modification on zone ... refused by DNS").
The role sets `name.<zone> = 'sec1_key'` (from `dnscherry_tsig_key_name`,
default `bind_dns_tsig_key_name`).

### The zone's `allow-transfer` must cover loopback

dnscherry *reads* the zone over **AXFR** from `127.0.0.1` (unsigned). The
`bind_dns` role therefore adds `127.0.0.0/8` to `bind_dns_allowed_transfer`;
without it the index page shows "Unkwown error." (the zone transfer is
REFUSED and the app's catch-all handler swallows the traceback).

### The unit ships `KillMode=process`

The package's `dnscherry.service` uses `Type=forking` with
`KillMode=process`, so a restart only signals the main PID. A stale
daemonized python can survive the stop and keep holding `127.0.0.1:8080`;
the next start then fails with `Port 8080 not free on 127.0.0.1.` (and
`Restart=on-failure` loops). The role drops an override
(`/etc/systemd/system/dnscherry.service.d/kill-mode.conf`) with
`KillMode=control-group` and restarts via `systemd_service` with
`daemon_reload: true`.
