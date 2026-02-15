# ldapcherry role

Installs and configures [LdapCherry](https://github.com/kakwa/ldapcherry) as a Web UI for the OpenLDAP server.

- Expects the **openldap** role to be applied first (same host).
- Connects to LDAP over **ldaps** using the CA certificate from the openldap role.
- Base DN and bind credentials are taken from openldap role variables.

## Variables

- All LDAP settings are derived from openldap role (`openldap_base_dn`, `openldap_admin_password`, `openldap_ca_cert`, etc.).
- `ldapcherry_listen_host` – Bind address (default: `127.0.0.1`); use `0.0.0.0` to listen on all interfaces.
- `ldapcherry_listen_port` – Port (default: `8080`).
- `ldapcherry_mail_domain` – Default domain for email autofill (default: `kakwalab.ovh`).

## Service

The role starts and enables the service provided by the ldapcherry package (typically `ldapcherryd`). Set `ldapcherry_service_name` if your package uses a different unit name.

## Nginx reverse proxy

LdapCherry is exposed via nginx on port 80 (default). The backend listens on `127.0.0.1:8080`.

- `ldapcherry_nginx_enable` – Set to `false` to skip nginx (default: `true`).
- `ldapcherry_nginx_server_name` – `server_name` for the vhost (default: `ldapcherry.kakwalab.ovh`).
- `ldapcherry_nginx_listen_port` – Port nginx listens on (default: `80`).

The default nginx site is disabled so this vhost handles port 80. Access the UI at `http://<utility-ip>/` or `http://ldapcherry.kakwalab.ovh/` (if DNS points to the utility host).
