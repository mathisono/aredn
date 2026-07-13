#!/bin/sh
# Static consistency checks for the installable AREDN Multi-WAN package.

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

require_absent()
{
    [ ! -e "$1" ] || fail "$1 must not be part of the base firmware or package"
}

require_text()
{
    file="$1"
    text="$2"
    grep -F -- "$text" "$file" >/dev/null || fail "$file does not contain: $text"
}

reject_text()
{
    file="$1"
    text="$2"
    if grep -F -- "$text" "$file" >/dev/null; then
        fail "$file unexpectedly contains: $text"
    fi
}

PKG=packages/aredn-multiwan
PKG_FILES="$PKG/files"
MANAGER="$PKG_FILES/usr/local/bin/wan3-manager"
ROUTE_CACHE="$PKG_FILES/usr/local/bin/wan-route-cache"
CALIBRATE="$PKG_FILES/usr/local/bin/wan-calibrate"
INIT="$PKG_FILES/etc/init.d/wan3-manager"
USB_UI="$PKG_FILES/app/main/status/e/usb-wan.ut"
CAL_UI="$PKG_FILES/app/main/status/e/link-calibration.ut"
MAIN_UI="$PKG_FILES/app/main/multiwan.ut"
MULTIWAN_PAGE="$PKG_FILES/app/partial/multiwan-page.ut"
USB_CARD="$PKG_FILES/app/partial/usb-wan.ut"
DEFAULTS="$PKG_FILES/etc/uci-defaults/95-aredn-multiwan"
HELP="$PKG_FILES/www/apps/aredn-multiwan/help.html"
USB_DOC=docs/multiwan-usb-wan.md
CAL_DOC=docs/multiwan-link-calibration.md
VERIFY_DOC=docs/multiwan-verification.md

REQUIRED_FILES="
$PKG/Makefile
$MANAGER
$ROUTE_CACHE
$CALIBRATE
$INIT
$PKG_FILES/etc/hotplug.d/net/95-wan3-manager
$PKG_FILES/etc/hotplug.d/iface/95-wan3-manager
$DEFAULTS
$MAIN_UI
$PKG_FILES/app/main/u-multiwan.ut
$USB_UI
$CAL_UI
$MULTIWAN_PAGE
$USB_CARD
$PKG_FILES/app/partial/link-calibration.ut
$PKG_FILES/www/cgi-bin/apps/aredn-multiwan/admin
$PKG_FILES/www/apps/aredn-multiwan/icon.svg
$HELP
$USB_DOC
$CAL_DOC
$VERIFY_DOC
"
for file in $REQUIRED_FILES; do
    require_file "$file"
done

SHELL_FILES="
$MANAGER
$ROUTE_CACHE
$CALIBRATE
$INIT
$PKG_FILES/etc/hotplug.d/net/95-wan3-manager
$PKG_FILES/etc/hotplug.d/iface/95-wan3-manager
$DEFAULTS
$PKG_FILES/www/cgi-bin/apps/aredn-multiwan/admin
"
for file in $SHELL_FILES; do
    if command -v busybox >/dev/null 2>&1; then
        busybox ash -n "$file" || fail "BusyBox ash syntax failed: $file"
    else
        sh -n "$file" || fail "shell syntax failed: $file"
    fi
done

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    for file in $SHELL_FILES tests/verify-multiwan.sh; do
        mode="$(git ls-files -s -- "$file" | awk '{print $1}')"
        [ "$mode" = 100755 ] || fail "$file has git mode ${mode:-missing}, expected 100755"
    done
fi

# The feature must not be baked into the base overlay or device image patch.
for file in \
    files/usr/local/bin/wan3-manager \
    files/usr/local/bin/wan-route-cache \
    files/usr/local/bin/wan-calibrate \
    files/etc/init.d/wan3-manager \
    files/etc/hotplug.d/net/95-wan3-manager \
    files/etc/hotplug.d/iface/95-wan3-manager \
    files/app/main/status/e/usb-wan.ut \
    files/app/main/status/e/link-calibration.ut \
    files/app/partial/usb-wan.ut \
    files/app/partial/link-calibration.ut \
    patches/759-mikrotik-usb-wan.patch \
    "$PKG_FILES/etc/uci-defaults/98_wan3_redsocks"; do
    require_absent "$file"
done
reject_text files/app/partial/general.ut 'link-calibration'
reject_text files/app/partial/general.ut 'usb-wan'
reject_text files/etc/config.mesh/aredn "config multiwan 'multiwan'"

# Local feed and module-only target integration.
require_text feeds.conf 'src-link arednlocal ../packages'
require_text Makefile './scripts/feeds install -p arednlocal aredn-multiwan'
require_text configs/ipq40xx-mikrotik.config 'CONFIG_PACKAGE_aredn-multiwan=m'
require_text configs/ath79-mikrotik.config 'CONFIG_PACKAGE_aredn-multiwan=m'
reject_text configs/ipq40xx-mikrotik.config 'CONFIG_PACKAGE_aredn-multiwan=y'
reject_text configs/ath79-mikrotik.config 'CONFIG_PACKAGE_aredn-multiwan=y'

# Package metadata, dependencies, lifecycle, and installed paths.
require_text "$PKG/Makefile" 'PKG_NAME:=aredn-multiwan'
require_text "$PKG/Makefile" 'PKG_VERSION:=0.1.0'
require_text "$PKG/Makefile" 'PKG_RELEASE:=3'
require_text "$PKG/Makefile" 'PKGARCH:=all'
require_text "$PKG/Makefile" '+kmod-usb-net-rndis'
require_text "$PKG/Makefile" '+kmod-usb-net-cdc-ether'
require_text "$PKG/Makefile" '+kmod-usb-net-cdc-ncm'
require_text "$PKG/Makefile" '+TARGET_ath79:kmod-usb2'
require_text "$PKG/Makefile" '+redsocks'
require_text "$PKG/Makefile" '+curl'
require_text "$PKG/Makefile" '+ca-bundle'
require_text "$PKG/Makefile" '+kmod-nft-nat'
require_text "$PKG/Makefile" 'Package/aredn-multiwan/preinst'
require_text "$PKG/Makefile" 'Package/aredn-multiwan/postinst'
require_text "$PKG/Makefile" 'Package/aredn-multiwan/prerm'
require_text "$PKG/Makefile" '/usr/local/bin/wan-route-cache wan'
require_text "$PKG/Makefile" '/usr/local/bin/wan3-manager select wan'
require_text "$PKG/Makefile" 'phone USB tether WAN'
require_text "$PKG/Makefile" 'administrator-selected HTTPS object'
require_text "$PKG/Makefile" '$(INSTALL_DATA) ./files/app/main/multiwan.ut'
require_text "$PKG/Makefile" '$(INSTALL_BIN) ./files/www/cgi-bin/apps/aredn-multiwan/admin'
reject_text "$PKG/Makefile" '98_wan3_redsocks'

# Package-created defaults must match the UI and documentation.
require_text "$DEFAULTS" "set aredn.multiwan.enabled='0'"
require_text "$DEFAULTS" "set aredn.multiwan.active='wan'"
require_text "$DEFAULTS" "set aredn.multiwan.wan3_enable='0'"
require_text "$DEFAULTS" "set aredn.multiwan.wan3_device='auto'"
require_text "$DEFAULTS" "set aredn.multiwan.wan3_proxy_enable='1'"
require_text "$DEFAULTS" "set aredn.multiwan.wan3_proxy_host='192.168.49.1'"
require_text "$DEFAULTS" "set aredn.multiwan.wan3_proxy_port='8000'"
require_text "$DEFAULTS" "set aredn.multiwan.wan3_proxy_local_port='12346'"
require_text "$DEFAULTS" "set aredn.multiwan.calibration_provider='User-selected HTTPS calibration object'"
require_text "$DEFAULTS" "set aredn.multiwan.calibration_host=''"
require_text "$DEFAULTS" "set aredn.multiwan.calibration_url=''"
require_text "$DEFAULTS" "set aredn.multiwan.calibration_cooldown='300'"
require_text "$DEFAULTS" "calibration_provider 2>/dev/null)\" = 'Hurricane Electric / Hayward Internet Exchange'"

# USB WAN must be a phone-to-hAP USB network input with hAP-side proxy fields.
require_text "$MANAGER" 'json_add_string name wan3'
require_text "$MANAGER" 'json_add_string proto dhcp'
require_text "$MANAGER" 'json_add_string ip4table 103'
require_text "$MANAGER" 'usb[0-9]*|rndis[0-9]*|wwan[0-9]*|enx*'
require_text "$MANAGER" 'is_usb_netdev "$configured"'
require_text "$MANAGER" 'type = http-connect;'
require_text "$MANAGER" 'table inet $NFT_TABLE'
require_text "$MANAGER" 'fallback_to_wan'
require_text "$MANAGER" 'MANAGER_LOCK="$STATE_DIR/.manager.lock"'
require_text "$MANAGER" '[ -n "$local_port" ] || local_port=12346'
require_text "$MANAGER" '[ "$active" = wan ] || fallback_to_wan || true'
require_text "$ROUTE_CACHE" 'wan) cache_one wan 101'
require_text "$ROUTE_CACHE" 'wan2) cache_one wan2 102'
reject_text "$MANAGER" '/etc/init.d/redsocks stop'
reject_text "$INIT" '/etc/init.d/redsocks stop'
reject_text "$DEFAULTS" '/etc/init.d/redsocks disable'

require_text "$USB_UI" 'Phone USB Tether / PdaNet WAN'
require_text "$USB_UI" 'Android phone → USB cable → hAP USB host → logical interface wan3'
require_text "$USB_UI" 'Use PdaNet upstream proxy'
require_text "$USB_UI" 'wan3_proxy_host'
require_text "$USB_UI" 'wan3_proxy_port'
require_text "$USB_UI" 'wan3_proxy_username'
require_text "$USB_UI" 'wan3_proxy_password'
require_text "$USB_UI" 'Save USB tether settings'
require_text "$USB_CARD" 'Phone USB Tether'
require_text "$MULTIWAN_PAGE" 'phone-to-hAP USB RNDIS/CDC input'
require_text "$HELP" 'hAP USB host -> RNDIS/CDC network device -> wan3 DHCP'

# Calibration remains authenticated, bounded, allow-listed, proxy-aware, and user configurable.
require_text "$CALIBRATE" 'wan|wan2|wan3'
require_text "$CALIBRATE" 'valid_calibration_host'
require_text "$CALIBRATE" 'valid_calibration_url'
require_text "$CALIBRATE" 'User-selected HTTPS calibration object'
require_text "$CALIBRATE" 'measure 1048576 "1 MiB"'
require_text "$CALIBRATE" 'measure 8388608 "8 MiB"'
require_text "$CALIBRATE" 'measure 33554432 "32 MiB"'
require_text "$CALIBRATE" 'value <= 5.0'
require_text "$CALIBRATE" 'value <= 30.0'
require_text "$CALIBRATE" '--proxy "http://$PROXY_HOST:$PROXY_PORT"'
require_text "$CALIBRATE" '--max-redirs 0'
require_text "$CALIBRATE" 'Calibration object did not honor the byte-range request'

require_text "$USB_UI" 'if (!auth.isAdmin)'
require_text "$CAL_UI" 'if (!auth.isAdmin)'
require_text "$CAL_UI" 'action === "save-endpoint"'
require_text "$CAL_UI" 'name="calibration_provider"'
require_text "$CAL_UI" 'name="calibration_url"'
require_text "$CAL_UI" 'parseCalibrationUrl'
require_text "$CAL_UI" 'uciMesh.set("aredn", "multiwan", "calibration_host", parsed.host)'
require_text "$CAL_UI" 'uciMesh.set("aredn", "multiwan", "calibration_url", parsed.url)'
require_text "$CAL_UI" 'action === "calibrate"'
require_text "$CAL_UI" 'wan3: "USB WAN"'
require_text "$CAL_UI" 'it cannot supply or override the saved URL'
require_text "$MAIN_UI" 'Administrator authentication required'

# User documentation must describe the package boundary, USB topology, inputs, and URL boundary.
require_text "$USB_DOC" 'optional installable package'
require_text "$USB_DOC" 'aredn-multiwan-0.1.0-r3.apk'
require_text "$USB_DOC" 'CONFIG_PACKAGE_aredn-multiwan=m'
require_text "$USB_DOC" 'Required phone-to-hAP USB topology'
require_text "$USB_DOC" 'logical AREDN interface wan3 (DHCP)'
require_text "$USB_DOC" 'Address: 192.168.49.1'
require_text "$USB_DOC" 'Port:    8000'
require_text "$USB_DOC" 'private listener on TCP port `12346`'
require_text "$USB_DOC" 'does not disable or reuse the stock redsocks service'
require_text "$USB_DOC" 'Administrator-selected calibration object'
require_text "$USB_DOC" 'individual calibration request cannot provide or override a URL'
require_text "$USB_DOC" 'does **not yet create the physical or VLAN definition for `wan2`**'
require_text "$USB_DOC" 'packages/aredn-multiwan/Makefile'
require_text "$CAL_DOC" 'User-selectable HTTPS object'
require_text "$CAL_DOC" 'does **not yet automatically switch WANs based on the result**'
require_text "$CAL_DOC" 'A run request cannot supply or override a destination URL'
require_text "$CAL_DOC" 'at most about 41 MiB'
require_text "$VERIFY_DOC" 'Calibration object configuration test'
require_text "$VERIFY_DOC" 'phone → data-capable USB cable → hAP USB host'
require_text docs/README.md 'installable APK'

# The copies shipped on the node must be byte-for-byte identical to the source guides.
cmp -s "$USB_DOC" "$PKG_FILES/usr/share/doc/aredn-multiwan/multiwan-usb-wan.md" || fail 'packaged USB WAN guide is stale'
cmp -s "$CAL_DOC" "$PKG_FILES/usr/share/doc/aredn-multiwan/multiwan-link-calibration.md" || fail 'packaged calibration guide is stale'
cmp -s "$VERIFY_DOC" "$PKG_FILES/usr/share/doc/aredn-multiwan/multiwan-verification.md" || fail 'packaged verification guide is stale'

if [ -d openwrt ]; then
    [ -L openwrt/package/feeds/arednlocal/aredn-multiwan ] || \
        echo 'NOTE: prepared OpenWrt tree does not yet contain the arednlocal package symlink'
fi

echo 'aredn-multiwan package verification passed'
