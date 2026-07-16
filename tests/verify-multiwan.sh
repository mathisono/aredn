#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
exec "$ROOT/packages/aredn-multiwan/tests/verify.sh" "$@"

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
