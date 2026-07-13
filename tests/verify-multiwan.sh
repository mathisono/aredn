#!/bin/sh
# Static consistency checks for the experimental multi-WAN/USB-WAN feature.
# Run from anywhere inside the repository:
#
#   tests/verify-multiwan.sh

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT"

fail()
{
    echo "ERROR: $*" >&2
    exit 1
}

require_file()
{
    [ -f "$1" ] || fail "missing $1"
}

require_text()
{
    file="$1"
    text="$2"
    grep -F -- "$text" "$file" >/dev/null || fail "$file does not contain: $text"
}

require_regex()
{
    file="$1"
    expression="$2"
    grep -E -- "$expression" "$file" >/dev/null || fail "$file does not match: $expression"
}

SHELL_FILES="
files/usr/local/bin/wan3-manager
files/usr/local/bin/wan-route-cache
files/usr/local/bin/wan-calibrate
files/etc/init.d/wan3-manager
files/etc/hotplug.d/net/95-wan3-manager
files/etc/hotplug.d/iface/95-wan3-manager
files/etc/uci-defaults/98_wan3_redsocks
"

for file in $SHELL_FILES; do
    require_file "$file"
    if command -v busybox >/dev/null 2>&1; then
        busybox ash -n "$file" || fail "BusyBox ash syntax failed: $file"
    else
        sh -n "$file" || fail "shell syntax failed: $file"
    fi
done

# Runtime scripts and hooks must remain executable in git.
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    for file in $SHELL_FILES; do
        mode="$(git ls-files -s -- "$file" | awk '{print $1}')"
        [ "$mode" = 100755 ] || fail "$file has git mode ${mode:-missing}, expected 100755"
    done
fi

CONFIG=files/etc/config.mesh/aredn
MANAGER=files/usr/local/bin/wan3-manager
ROUTE_CACHE=files/usr/local/bin/wan-route-cache
CALIBRATE=files/usr/local/bin/wan-calibrate
USB_UI=files/app/main/status/e/usb-wan.ut
CAL_UI=files/app/main/status/e/link-calibration.ut
USB_CARD=files/app/partial/usb-wan.ut
CAL_CARD=files/app/partial/link-calibration.ut
TARGET_PATCH=patches/759-mikrotik-usb-wan.patch
USB_DOC=docs/multiwan-usb-wan.md
CAL_DOC=docs/multiwan-link-calibration.md

for file in "$CONFIG" "$MANAGER" "$ROUTE_CACHE" "$CALIBRATE" "$USB_UI" "$CAL_UI" "$USB_CARD" "$CAL_CARD" "$TARGET_PATCH" "$USB_DOC" "$CAL_DOC" docs/README.md Makefile; do
    require_file "$file"
done

# Persistent defaults must match the UI and user guide.
require_text "$CONFIG" "option enabled '0'"
require_text "$CONFIG" "option active 'wan'"
require_text "$CONFIG" "option wan3_enable '0'"
require_text "$CONFIG" "option wan3_device 'auto'"
require_text "$CONFIG" "option wan3_proxy_enable '1'"
require_text "$CONFIG" "option wan3_proxy_host '192.168.49.1'"
require_text "$CONFIG" "option wan3_proxy_port '8000'"
require_text "$CONFIG" "option wan3_proxy_local_port '12345'"
require_text "$CONFIG" "option calibration_provider 'Hurricane Electric / Hayward Internet Exchange'"
require_text "$CONFIG" "option calibration_host ''"
require_text "$CONFIG" "option calibration_url ''"
require_text "$CONFIG" "option calibration_cooldown '300'"

# The manager must create an isolated DHCP WAN and proxy only through fixed,
# validated configuration.
require_text "$MANAGER" "case \"\$selected\" in wan|wan2|wan3)"
require_text "$MANAGER" "json_add_string name wan3"
require_text "$MANAGER" "json_add_string proto dhcp"
require_text "$MANAGER" "json_add_string zone wan"
require_text "$MANAGER" "json_add_string ip4table 103"
require_text "$MANAGER" "type = http-connect;"
require_text "$MANAGER" "local_ip = 0.0.0.0;"
require_text "$MANAGER" "table inet \$NFT_TABLE"
require_text "$MANAGER" "ip daddr \$proxy_host return"
require_text "$MANAGER" "metric 1 onlink proto static"
require_text "$MANAGER" "fallback_to_wan"
require_text "$MANAGER" "MANAGER_LOCK=\"\$STATE_DIR/.manager.lock\""

# WAN 1 and WAN 2 must retain independently usable defaults.
require_text "$ROUTE_CACHE" "wan) cache_one wan 101"
require_text "$ROUTE_CACHE" "wan2) cache_one wan2 102"
require_text "$ROUTE_CACHE" "metric 10 onlink proto static"

# Calibration is allow-listed, bounded, and proxy-aware.
require_text "$CALIBRATE" "wan|wan2|wan3"
require_text "$CALIBRATE" "measure 1048576 \"1 MiB\""
require_text "$CALIBRATE" "measure 8388608 \"8 MiB\""
require_text "$CALIBRATE" "measure 33554432 \"32 MiB\""
require_text "$CALIBRATE" "value <= 5.0"
require_text "$CALIBRATE" "value <= 30.0"
require_text "$CALIBRATE" "--proxy \"http://\$PROXY_HOST:\$PROXY_PORT\""
require_text "$CALIBRATE" "--proxy ''"
require_text "$CALIBRATE" "--max-redirs 0"
require_text "$CALIBRATE" "[ \"\$HTTP_CODE\" = 206 ]"

# Both write handlers must enforce administrator authentication server-side.
require_text "$USB_UI" "if (!auth.isAdmin)"
require_text "$CAL_UI" "if (!auth.isAdmin)"
require_text "$CAL_UI" "const allowedInterfaces = { wan: \"WAN 1\", wan2: \"WAN 2\", wan3: \"USB WAN\" };"
require_text "$USB_UI" "request.args.action"
require_text "$USB_UI" "USB interface must be 'auto'"
require_text "$USB_UI" "Use USB WAN now"
require_text "$USB_CARD" "network.interface.wan3"
require_text "$CAL_CARD" "{ name: \"wan3\", label: \"USB WAN\" }"

# Package/feed integration for all three target devices.
require_text Makefile "./scripts/feeds install redsocks"
require_text "$TARGET_PATCH" "define Device/mikrotik_hap-ac2"
require_text "$TARGET_PATCH" "define Device/mikrotik_hap-ac3"
require_text "$TARGET_PATCH" "define Device/mikrotik_routerboard-952ui-5ac2nd"
require_text "$TARGET_PATCH" "kmod-usb-net-rndis"
require_text "$TARGET_PATCH" "kmod-usb-net-cdc-ether"
require_text "$TARGET_PATCH" "kmod-usb-net-cdc-ncm"
require_text "$TARGET_PATCH" "redsocks"

# Documentation must expose the exact defaults, limitations and source map.
require_text "$USB_DOC" "Address: 192.168.49.1"
require_text "$USB_DOC" "Port:    8000"
require_text "$USB_DOC" "HTTP CONNECT"
require_text "$USB_DOC" "table 103"
require_text "$USB_DOC" "does **not yet create the physical or VLAN definition for `wan2`**"
require_text "$USB_DOC" "WireGuard uses UDP"
require_text "$USB_DOC" "Code-to-document verification map"
require_text "$USB_DOC" "files/usr/local/bin/wan3-manager"
require_text "$USB_DOC" "tests/verify-multiwan.sh"
require_text "$CAL_DOC" "does **not yet automatically switch WANs based on the result**"
require_text "$CAL_DOC" "wan3"
require_text "$CAL_DOC" "at most about 41 MiB"
require_text docs/README.md "Multi-WAN USB WAN and PdaNet setup"

# If an OpenWrt 25.12.5 tree is present, also verify the device patch applies.
if [ -f openwrt/target/linux/ipq40xx/image/mikrotik.mk ] && [ -f openwrt/target/linux/ath79/image/mikrotik.mk ]; then
    patch --dry-run -p1 -d openwrt < "$TARGET_PATCH" >/dev/null || fail "$TARGET_PATCH does not apply to the prepared OpenWrt tree"
else
    echo "NOTE: OpenWrt tree not present; target patch dry-run skipped"
fi

echo "multi-WAN static verification passed"
