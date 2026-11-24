#!/usr/bin/env python3
"""Patch the installed dnscherry so the TSIG key name used for RFC 2136
updates is configurable (name.<zone> in [dns.zones] of dnscherry.ini).

The shipped 0.1.4 signs its updates with the zone name as the TSIG key name,
but named's allow-update matches the key name it defined (e.g. "sec1_key")
and rejects the update with PeerBadKey. The same fix lives in the git
source (~/Geek/GitHub/dnscherry); until the package is repackaged this
script keeps the installed copy in sync. Re-run it after any package
upgrade.

Idempotent: prints "already patched" and exits 0 if the fix is present.
"""
import sys

import dnscherry

f = dnscherry.__file__
src = open(f).read()

if "tsig_key_name" in src:
    print("already patched")
    sys.exit(0)

old = """        keyring = dns.tsigkeyring.from_text({
            zone: self.zone_list[zone]['key']
        })"""
new = """        # TSIG key name: 'name.<zone>' if configured, else the zone name.
        # (named's allow-update matches the key name in the TSIG signature.)
        tsig_key_name = self.zone_list[zone].get('name', zone)
        keyring = dns.tsigkeyring.from_text({
            tsig_key_name: self.zone_list[zone]['key']
        })"""

assert old in src, "pattern not found in %s; the package changed, update this script" % f
open(f, "w").write(src.replace(old, new, 1))
print("patched")
