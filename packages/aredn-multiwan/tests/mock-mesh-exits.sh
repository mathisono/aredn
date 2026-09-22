#!/bin/sh
set -eu

ROOT="$(mktemp -d /tmp/pollywan-mesh-exits.XXXXXX)"
trap 'rm -rf "$ROOT"' EXIT HUP INT TERM
mkdir -p "$ROOT/hosts"

printf '%s\n' '#!/bin/sh' 'cat "$MESH_EXITS_DUMP"' > "$ROOT/socat"
chmod 755 "$ROOT/socat"

printf '%s\n' \
    '10.1.0.1 EXIT-ONE' \
    '10.2.0.1 EXIT-TWO' \
    '10.3.0.1 EXIT-THREE' \
    '10.4.0.1 EXIT-FOUR' \
    '10.5.0.1 EXIT-FIVE' \
    '10.6.0.1 EXIT-SIX' \
    > "$ROOT/hosts/0"

printf '%s\n' \
    'BABEL 1.0' \
    'add neighbour 1 address fe80::1 if br-dtdlink reach ffff ureach ffff rxcost 96 txcost 96 rtt 12.500 rttcost 4 cost 100' \
    'add neighbour 2 address fe80::2 if wgmesh reach ffff ureach ffff rxcost 128 txcost 128 rtt 48.250 rttcost 12 cost 140' \
    'add route 100 prefix 0.0.0.0/0 from 0.0.0.0/0 installed no id 00:00:00:00:00:00:00:01 metric 320 refmetric 220 via fe80::1 nexthop 172.16.0.1 table 22 if br-dtdlink' \
    'add route 101 prefix 10.1.0.1/32 from 0.0.0.0/0 installed yes id 00:00:00:00:00:00:00:01 metric 180 refmetric 80 via fe80::1 nexthop 172.16.0.1 table 20 if br-dtdlink' \
    'add route 102 prefix 0.0.0.0/0 from 0.0.0.0/0 installed no id 00:00:00:00:00:00:00:02 metric 180 refmetric 40 via fe80::2 nexthop 172.16.0.2 table 22 if wgmesh' \
    'add route 103 prefix 10.2.0.1/32 from 0.0.0.0/0 installed yes id 00:00:00:00:00:00:00:02 metric 160 refmetric 20 via fe80::2 nexthop 172.16.0.2 table 20 if wgmesh' \
    'add route 104 prefix 0.0.0.0/0 from 0.0.0.0/0 installed yes id 00:00:00:00:00:00:00:03 metric 240 refmetric 140 via fe80::1 nexthop 172.16.0.3 table 22 if br-dtdlink' \
    'add route 105 prefix 0.0.0.0/0 from 0.0.0.0/0 installed no id 00:00:00:00:00:00:00:03 metric 120 refmetric 20 via fe80::2 nexthop 172.16.0.9 table 22 if wgmesh' \
    'add route 106 prefix 10.3.0.1/32 from 0.0.0.0/0 installed yes id 00:00:00:00:00:00:00:03 metric 170 refmetric 70 via fe80::1 nexthop 172.16.0.3 table 20 if br-dtdlink' \
    'add route 107 prefix 0.0.0.0/0 from 0.0.0.0/0 installed no id 00:00:00:00:00:00:00:04 metric 400 refmetric 300 via fe80::1 nexthop 172.16.0.4 table 22 if br-dtdlink' \
    'add route 108 prefix 10.4.0.1/32 from 0.0.0.0/0 installed yes id 00:00:00:00:00:00:00:04 metric 180 refmetric 80 via fe80::1 nexthop 172.16.0.4 table 20 if br-dtdlink' \
    'add route 109 prefix 0.0.0.0/0 from 0.0.0.0/0 installed no id 00:00:00:00:00:00:00:05 metric 500 refmetric 400 via fe80::1 nexthop 172.16.0.5 table 22 if br-dtdlink' \
    'add route 110 prefix 10.5.0.1/32 from 0.0.0.0/0 installed yes id 00:00:00:00:00:00:00:05 metric 190 refmetric 90 via fe80::1 nexthop 172.16.0.5 table 20 if br-dtdlink' \
    'add route 111 prefix 0.0.0.0/0 from 0.0.0.0/0 installed no id 00:00:00:00:00:00:00:06 metric 600 refmetric 500 via fe80::1 nexthop 172.16.0.6 table 22 if br-dtdlink' \
    'add route 112 prefix 10.6.0.1/32 from 0.0.0.0/0 installed yes id 00:00:00:00:00:00:00:06 metric 200 refmetric 100 via fe80::1 nexthop 172.16.0.6 table 20 if br-dtdlink' \
    'add route 113 prefix 0.0.0.0/0 from 0.0.0.0/0 installed no id 00:00:00:00:00:00:00:07 metric 65535 refmetric 65535 via fe80::1 nexthop 172.16.0.7 table 22 if br-dtdlink' \
    > "$ROOT/dump"

actual="$(MESH_EXITS_DUMP="$ROOT/dump" SOCAT_BIN="$ROOT/socat" BABEL_SOCKET="$ROOT/babel.sock" HOSTS_DIR="$ROOT/hosts" files/usr/local/bin/wan-mesh-exits)"
expected='1|observed|EXIT-TWO|10.2.0.1|00:00:00:00:00:00:00:02|172.16.0.2|wgmesh|180|40|48.250|12
2|active|EXIT-THREE|10.3.0.1|00:00:00:00:00:00:00:03|172.16.0.3|br-dtdlink|240|140|12.500|4
3|observed|EXIT-ONE|10.1.0.1|00:00:00:00:00:00:00:01|172.16.0.1|br-dtdlink|320|220|12.500|4
4|observed|EXIT-FOUR|10.4.0.1|00:00:00:00:00:00:00:04|172.16.0.4|br-dtdlink|400|300|12.500|4
5|observed|EXIT-FIVE|10.5.0.1|00:00:00:00:00:00:00:05|172.16.0.5|br-dtdlink|500|400|12.500|4'

[ "$actual" = "$expected" ] || {
    echo 'unexpected passive Mesh WAN ranking:' >&2
    printf '%s\n' "$actual" >&2
    exit 1
}

[ "$(printf '%s\n' "$actual" | wc -l)" -eq 5 ]
! printf '%s\n' "$actual" | grep -q 'EXIT-SIX'

printf '%s\n' 'not a Babel response' > "$ROOT/dump"
[ -z "$(MESH_EXITS_DUMP="$ROOT/dump" SOCAT_BIN="$ROOT/socat" BABEL_SOCKET="$ROOT/babel.sock" HOSTS_DIR="$ROOT/hosts" files/usr/local/bin/wan-mesh-exits)" ]

echo 'passive Mesh WAN ranking passed'
