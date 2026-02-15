# openldap role

Installs and configures OpenLDAP (slapd) with:

- Base DN from `openldap_domain` (default: `kakwalab.ovh` → `dc=kakwalab,dc=ovh`)
- Self-signed CA and server certificate for TLS
- LDAP (port 389) with **STARTTLS enforced** (`olcSecurity: tls=1`)
- LDAPS (port 636)
- Base OUs: `ou=people`, `ou=groups`, and default group `cn=users` for ldapcherry

## Variables

- `openldap_domain` – Domain for base DN (default: `kakwalab.ovh`)
- `openldap_organization` – Organization name (default: `Kakwa Lab`)
- `openldap_admin_password` – Password for `cn=admin,<base_dn>` (**override with vault in production**)
- `openldap_fqdn` – FQDN for server cert (default: `utility.{{ openldap_domain }}`)

## Requirements

- Ansible collection: `community.general` (for `ldap_entry` and `openssl_*` modules). Install with:
  ```bash
  ansible-galaxy collection install community.general
  ```
