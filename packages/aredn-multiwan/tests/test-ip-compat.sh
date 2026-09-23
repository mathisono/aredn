#!/bin/sh
# Isolated compatibility probe for the base AREDN ip command syntax PollyWAN
# needs after dropping the ip-tiny dependency.
set -eu

TABLE=251
PREF1=32501
PREF2=32502
PREF3=32503

cleanup()
{
    ip -4 rule del pref "$PREF1" >/dev/null 2>&1 || true
    ip -4 rule del pref "$PREF2" >/dev/null 2>&1 || true
    ip -6 rule del pref "$PREF3" >/dev/null 2>&1 || true
    ip -4 route flush table "$TABLE" >/dev/null 2>&1 || true
    ip -6 route flush table "$TABLE" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM
cleanup

IP_BIN="$(command -v ip)"
printf 'ip=%s\n' "$IP_BIN"
readlink -f "$IP_BIN" 2>/dev/null || true
ip -V 2>&1 || true
apk info --who-owns "$IP_BIN" 2>/dev/null || true
busybox ip 2>&1 | head -n 5 || true

DEVICE="${POLLYWAN_IP_TEST_DEVICE:-}"
SOURCE="${POLLYWAN_IP_TEST_SOURCE:-}"
GATEWAY="${POLLYWAN_IP_TEST_GATEWAY:-}"
NETWORK="${POLLYWAN_IP_TEST_NETWORK:-}"
DEST="${POLLYWAN_IP_TEST_DEST:-1.1.1.1}"
LAN_DEVICE="${POLLYWAN_IP_TEST_LAN_DEVICE:-$DEVICE}"
TUNNEL_DEVICE="${POLLYWAN_IP_TEST_TUNNEL_DEVICE:-}"

if [ -z "$DEVICE" ] || [ -z "$SOURCE" ] || [ -z "$NETWORK" ]; then
    DEVICE="$(ip -4 route show default 2>/dev/null | awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')"
    SOURCE="$(ip -4 addr show dev "$DEVICE" 2>/dev/null | awk '/ inet / { sub(/\/.*/, "", $2); print $2; exit }')"
    NETWORK="$(ip -4 route show dev "$DEVICE" scope link 2>/dev/null | awk '$1 ~ /^[0-9.]+\/[0-9]+$/ { print $1; exit }')"
    GATEWAY="$(ip -4 route show default 2>/dev/null | awk 'NR == 1 { for (i = 1; i <= NF; i++) if ($i == "via") { print $(i + 1); exit } }')"
    LAN_DEVICE="${LAN_DEVICE:-$DEVICE}"
fi
[ -n "$DEVICE" ] && [ -n "$SOURCE" ] && [ -n "$NETWORK" ] || { echo 'SKIP: no IPv4 test interface available'; exit 0; }
[ -n "$GATEWAY" ] || GATEWAY="$SOURCE"
[ -n "$TUNNEL_DEVICE" ] || TUNNEL_DEVICE="$DEVICE"

ip -4 route show table 101 >/dev/null 2>&1 || true
ip -4 route show table all dev "$DEVICE" scope link >/dev/null
ip -4 route get "$DEST" from "$SOURCE" oif "$DEVICE" >/dev/null
ip -4 route replace table "$TABLE" default via "$GATEWAY" dev "$DEVICE" src "$SOURCE" metric 1 onlink proto static
ip -4 route replace table "$TABLE" "$NETWORK" dev "$DEVICE" src "$SOURCE" scope link proto static
ip -4 route flush table "$TABLE"

ip -4 rule add pref "$PREF1" lookup "$TABLE"
ip -4 rule add pref "$PREF2" iif "$LAN_DEVICE" lookup "$TABLE"
ip -4 rule del pref "$PREF1"
ip -4 rule del pref "$PREF2"

ip -4 route replace blackhole default table "$TABLE"
ip -6 route replace blackhole default table "$TABLE"
ip -6 rule add pref "$PREF3" iif "$TUNNEL_DEVICE" lookup "$TABLE"
ip -6 rule del pref "$PREF3"

cleanup
echo 'base ip compatibility passed'
