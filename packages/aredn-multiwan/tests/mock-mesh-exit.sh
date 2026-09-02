#!/bin/sh
set -eu

ROOT="$(mktemp -d /tmp/pollywan-mesh-exit.XXXXXX)"
trap 'rm -rf "$ROOT"' EXIT HUP INT TERM
mkdir -p "$ROOT/hosts"

printf '%s\n' '#!/bin/sh' 'cat "$MESH_EXIT_DUMP"' > "$ROOT/socat"
chmod 755 "$ROOT/socat"
printf '%s\n' '#!/bin/sh' '[ -n "${MESH_EXIT_ROUTE:-}" ] && cat "$MESH_EXIT_ROUTE"' > "$ROOT/ip"
chmod 755 "$ROOT/ip"
# AREDNlink aggregates multiple node sections in one file. Put the exit second
# so the test rejects a resolver that only checks the first section header.
printf '%s\n' \
    '##10.11.22.33##' \
    '10.11.22.33	OTHER-MESH-NODE' \
    '10.11.22.34	lan.OTHER-MESH-NODE.local.mesh' \
    '' \
    '##10.44.55.66##' \
    '10.44.55.66	TEST-MESH-GATEWAY' \
    '10.44.55.67	lan.TEST-MESH-GATEWAY.local.mesh' \
    > "$ROOT/hosts/0"
printf '%s\n' \
    'BABEL 1.0' \
    'add route 100 prefix 0.0.0.0/0 from 0.0.0.0/0 installed yes id aa:bb:cc:dd:ee:ff:00:11 metric 384 refmetric 284 via fe80::1 nexthop 10.1.2.3 table 22 if br-dtdlink' \
    'add route 101 prefix 10.44.55.66/32 from 0.0.0.0/0 installed yes id aa:bb:cc:dd:ee:ff:00:11 metric 320 refmetric 220 via fe80::1 nexthop 10.1.2.3 table 20 if br-dtdlink' \
    > "$ROOT/dump"

actual="$(MESH_EXIT_DUMP="$ROOT/dump" SOCAT_BIN="$ROOT/socat" IP_BIN="$ROOT/ip" BABEL_SOCKET="$ROOT/babel.sock" HOSTS_DIR="$ROOT/hosts" files/usr/local/bin/wan-mesh-exit)"
[ "$actual" = '1|TEST-MESH-GATEWAY|10.44.55.66|10.1.2.3|br-dtdlink|384' ] || {
    echo "unexpected resolved mesh exit: $actual" >&2
    exit 1
}

printf '%s\n' 'BABEL 1.0' > "$ROOT/dump"
actual="$(MESH_EXIT_DUMP="$ROOT/dump" SOCAT_BIN="$ROOT/socat" IP_BIN="$ROOT/ip" BABEL_SOCKET="$ROOT/babel.sock" HOSTS_DIR="$ROOT/hosts" files/usr/local/bin/wan-mesh-exit)"
[ "$actual" = '0|||||' ] || {
    echo "unexpected absent mesh exit: $actual" >&2
    exit 1
}

printf '%s\n' 'default via 10.9.8.7 dev br-dtdlink proto babel metric 512' > "$ROOT/route"
actual="$(MESH_EXIT_DUMP="$ROOT/dump" MESH_EXIT_ROUTE="$ROOT/route" SOCAT_BIN="$ROOT/socat" IP_BIN="$ROOT/ip" BABEL_SOCKET="$ROOT/babel.sock" HOSTS_DIR="$ROOT/hosts" files/usr/local/bin/wan-mesh-exit)"
[ "$actual" = '1|Unknown||10.9.8.7|br-dtdlink|512' ] || {
    echo "unexpected table-22 fallback: $actual" >&2
    exit 1
}

echo 'remote mesh exit resolver passed'
