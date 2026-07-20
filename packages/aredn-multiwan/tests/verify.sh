#!/bin/sh
# Static and disposable-mock verification for the standalone PollyWAN r27 source.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT"

fail() { echo "ERROR: $*" >&2; exit 1; }
require_file() { [ -f "$1" ] || fail "missing $1"; }
require_text() { grep -F -- "$2" "$1" >/dev/null || fail "$1 missing: $2"; }
reject_text() { ! grep -F -- "$2" "$1" >/dev/null || fail "$1 unexpectedly contains: $2"; }

SHELL_FILES='files/usr/local/bin/wan-port-manager
files/usr/local/bin/wan3-manager
files/usr/local/bin/wan-route-cache
files/usr/local/bin/wan-sla
files/usr/local/bin/wan-tunnel-guard
files/usr/local/bin/wan-calibrate
files/usr/local/bin/wan-speed-test
files/etc/init.d/wan3-manager
files/etc/hotplug.d/iface/95-wan3-manager
files/etc/hotplug.d/net/95-wan3-manager
files/etc/uci-defaults/95-aredn-multiwan
files/www/cgi-bin/apps/aredn-multiwan/admin
tests/verify.sh
tests/mock-port-manager.sh
tests/mock-route-cache.sh
tests/mock-tunnel-guard.sh
tools/sync-integration.sh'

REQUIRED='Makefile
README.md
LICENSE
AREDNLicense.txt
.github/workflows/verify.yml
SYNC_SOURCE
docs/README.md
docs/port-roles-and-gps.md
docs/multiwan-usb-wan.md
docs/multiwan-link-calibration.md
docs/multiwan-mesh-wan.md
docs/multiwan-verification.md
tools/openclaw-build-test-prompt.md
tools/sync-integration.sh
tests/test-selection-model.py
files/app/main/u-multiwan.ut
files/app/main/u-wan-policy.ut
files/app/main/u-ethernet-ports.ut
files/app/main/u-usb-wan.ut
files/app/main/u-link-calibration.ut
files/app/main/status/e/wan-policy.ut
files/app/main/status/e/ethernet-ports.ut
files/app/main/status/e/usb-wan.ut
files/app/main/status/e/link-calibration.ut
files/app/partial/multiwan-page.ut
files/app/partial/multiwan-style.ut
files/app/partial/multiwan.ut
files/app/partial/wan-policy.ut
files/app/partial/ethernet-ports.ut
files/app/partial/usb-wan.ut
files/app/partial/link-calibration.ut
files/www/apps/aredn-multiwan/help.html
files/www/apps/aredn-multiwan/icon.svg'

for file in $REQUIRED $SHELL_FILES; do require_file "$file"; done
[ ! -e .bootstrap ] || fail 'broken bootstrap directory remains'
[ ! -e .github/workflows/bootstrap.yml ] || fail 'temporary bootstrap workflow remains'

for file in $SHELL_FILES; do
    busybox ash -n "$file" || fail "BusyBox ash syntax: $file"
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        mode="$(git ls-files -s -- "$file" | awk '{print $1}')"
        [ -z "$mode" ] || [ "$mode" = 100755 ] || fail "$file mode $mode, expected 100755"
    else
        [ -x "$file" ] || fail "$file is not executable"
    fi
done
[ -x tests/test-selection-model.py ] || fail 'tests/test-selection-model.py is not executable'
[ -x tests/test-ip-compat.sh ] || fail 'tests/test-ip-compat.sh is not executable'

# Package metadata and optional-only target contract.
require_text Makefile 'PKG_NAME:=aredn-multiwan'
require_text Makefile 'PKG_VERSION:=0.1.0'
require_text Makefile 'PKG_RELEASE:=27'
require_text Makefile 'URL:=https://github.com/mathisono/AREDN_PollyWAN'
reject_text Makefile '+ip-tiny'
reject_text Makefile '+redsocks'
reject_text Makefile '+libevent2-core7'
reject_text Makefile '+nftables-json'
reject_text Makefile '+kmod-nft-nat'
reject_text Makefile '+kmod-usb-net-rndis'
reject_text Makefile '+kmod-usb-net-cdc-ether'
reject_text Makefile '+kmod-usb-net-cdc-ncm'
reject_text Makefile '+kmod-usb-net '
require_text Makefile '+TARGET_ath79:swconfig'
require_text Makefile 'WAN 1 as either administrator-selected hAP Ethernet or the'
require_text Makefile 'existing AREDN Wi-Fi client logical interface'
require_text Makefile 'Installation is disabled and inert'
require_text Makefile 'Package/aredn-multiwan/prerm'
require_text Makefile 'files/app/partial/multiwan-style.ut'
require_text Makefile 'files/app/partial/multiwan.ut'
require_text Makefile 'files/usr/local/bin/wan-speed-test'
reject_text Makefile 'files/app/main/multiwan.ut'
require_text LICENSE 'GNU General Public License'
require_text AREDNLicense.txt 'not represented as an official'

# AREDN 4.26's UCode renderer does not support JavaScript optional chaining.
! grep -R -nF '?.' files/app || fail 'UI templates must not use optional chaining'
! grep -R -nF 'strftime(' files/app || fail 'UI templates must not depend on strftime'

# Defaults are inert and GPS/radio neutral.
DEFAULTS=files/etc/uci-defaults/95-aredn-multiwan
require_text "$DEFAULTS" 'set_default enabled 0'
require_text "$DEFAULTS" 'set_default port_roles_enabled 0'
require_text "$DEFAULTS" 'set_default selection_mode manual'
require_text "$DEFAULTS" 'set_default wan_enable 1'
require_text "$DEFAULTS" 'set_default wan2_enable 0'
require_text "$DEFAULTS" 'set_default wan3_enable 0'
require_text "$DEFAULTS" 'set_default port1_role wan'
require_text "$DEFAULTS" 'set_default port2_role lan'
require_text "$DEFAULTS" 'set_default port5_dtd 1'
require_text "$DEFAULTS" 'set_default selection_min_bin low'
require_text "$DEFAULTS" 'set_default mesh_share_min_bin medium'
require_text "$DEFAULTS" "set_default health_url 'https://connectivitycheck.gstatic.com/generate_204'"
require_text "$DEFAULTS" 'set_default health_expected_codes 204'
require_text "$DEFAULTS" 'set_default failure_count 2'
require_text "$DEFAULTS" 'set_default promote_count 2'
require_text "$DEFAULTS" 'set_default hold_down 120'
require_text "$DEFAULTS" 'set_default speed_result_ttl 21600'
require_text "$DEFAULTS" 'set_default speed_test_auto 0'
require_text "$DEFAULTS" 'set_default speed_test_interval 21600'
require_text "$DEFAULTS" 'set_default speed_test_method cloudflare'
require_text "$DEFAULTS" "availability|adaptive"
require_text "$DEFAULTS" 'cleanup_old_proxy_state()'
require_text "$DEFAULTS" 'nft delete table inet aredn_wan3_proxy'
require_text "$DEFAULTS" 'firewall.aredn_multiwan_proxy_wifi'
require_text "$DEFAULTS" 'wan3_proxy_enable'
require_text "$DEFAULTS" '/tmp/wan3/redsocks.conf'
reject_text "$DEFAULTS" 'set gpsd'
reject_text "$DEFAULTS" '@time['
reject_text "$DEFAULTS" '@location['
reject_text "$DEFAULTS" 'radio0_mode='
reject_text "$DEFAULTS" 'radio1_mode='
reject_text "$DEFAULTS" 'usb_passthrough'

# Ethernet roles, Wi-Fi ownership, rollback, and GPS boundary.
PORTS=files/usr/local/bin/wan-port-manager
require_text "$PORTS" 'WAN3 is never assigned here'
require_text "$PORTS" 'radio_mode()'
require_text "$PORTS" 'wifi_wan_device()'
require_text "$PORTS" "printf '%s\\n' wlan0"
require_text "$PORTS" "printf '%s\\n' wlan1"
require_text "$PORTS" "printf 'wifi:%s\\n'"
require_text "$PORTS" 'invalid:both-radios'
require_text "$PORTS" 'no Ethernet port may be assigned to WAN 1'
require_text "$PORTS" 'our Ethernet WAN override'
require_text "$PORTS" 'version=6'
require_text "$PORTS" 'wan_transport='
require_text "$PORTS" 'WAN 1 transport changed from'
require_text "$PORTS" 'mikrotik,routerboard-952ui-5ac2nd) echo swconfig'
require_text "$PORTS" 'mikrotik,hap-ac2|mikrotik,hap-ac3) echo dsa'
require_text "$PORTS" 'at least one Ethernet port must remain LAN'
require_text "$PORTS" 'schedule_rollback'
require_text "$PORTS" 'POLLYWAN_TEST_MODE'
require_text "$PORTS" 'pending-token'
require_text "$PORTS" 'confirm_roles'
require_text "$PORTS" 'restore_backups'
require_text "$PORTS" '/usr/local/bin/node-setup'
require_text "$PORTS" 'add_list "firewall.$zone.network=wan2"'
require_text "$PORTS" 'option ip4table '\''102'\'''
require_text "$PORTS" 'gps_status()'
reject_text "$PORTS" 'uci set gpsd'
reject_text "$PORTS" 'uci -c /etc/config.mesh set gpsd'
reject_text "$PORTS" 'gpsd stop'
reject_text "$PORTS" 'gpsd restart'
reject_text "$PORTS" 'usb_passthrough'

# WAN3 is network-class only, opt-in, and does not touch serial GPS.
WAN3=files/usr/local/bin/wan3-manager
require_text "$WAN3" '/sys/class/net/'
require_text "$WAN3" 'usb[0-9]*|rndis[0-9]*|wwan[0-9]*|enx*'
require_text "$WAN3" 'usb_support_report()'
require_text "$WAN3" 'module_status()'
require_text "$WAN3" 'module_available()'
require_text "$WAN3" 'load_existing_usb_modules()'
require_text "$WAN3" 'WAN3 unavailable: no compatible existing kernel USB-network support'
require_text "$WAN3" 'usb-support) usb_support_report'
require_text "$WAN3" '[ "$(uci_get enabled)" != 1 ] || [ "$(uci_get wan3_enable)" != 1 ]'
require_text "$WAN3" 'json_add_string name wan3'
require_text "$WAN3" 'json_add_string ip4table 103'
require_text "$WAN3" 'wan_transport_valid()'
require_text "$WAN3" 'Both AREDN radios are configured as WAN clients'
reject_text "$WAN3" '/dev/ttyACM'
reject_text "$WAN3" '/dev/ttyUSB'
reject_text "$WAN3" 'gpsd'
reject_text "$WAN3" 'usb_passthrough'
require_text files/etc/hotplug.d/net/95-wan3-manager 'wan3_enable'
require_text files/etc/hotplug.d/net/95-wan3-manager '/sys/class/net/'

# Private route tables, selected-route transaction, Babel, and Mesh WAN.
CACHE=files/usr/local/bin/wan-route-cache
require_text "$CACHE" 'wan)  printf '\''101|81'
require_text "$CACHE" 'wan2) printf '\''102|82'
require_text "$CACHE" 'wan3) printf '\''103|83'
require_text "$CACHE" 'from "$source/32" lookup "$table"'
require_text "$WAN3" 'LOCAL_TABLE=26'
require_text "$WAN3" 'LOCAL_SUBNET_TABLE=27'
require_text "$WAN3" 'BABEL_EXPORT_TABLE=28'
require_text "$WAN3" 'REMOTE_MESH_TABLE=22'
require_text "$WAN3" 'snapshot_routes'
require_text "$WAN3" 'restore_route_snapshot'
require_text "$WAN3" 'function cidr_prefix'
require_text "$WAN3" 'split(value, parts, "/") == 2'
require_text "$WAN3" 'connected_prefix_from_cidr "$source/$mask"'
require_text "$WAN3" 'install_default "$LOCAL_TABLE" "$device" "$source" "$gateway" 1'
require_text "$WAN3" 'install_default main "$device" "$source" "$gateway" 1'
require_text "$WAN3" 'table 22 is available'
reject_text "$WAN3" 'start_proxy'
reject_text "$WAN3" 'stop_proxy'
reject_text "$WAN3" 'proxy-start'
reject_text "$WAN3" 'proxy-stop'
reject_text "$WAN3" 'redsocks'
reject_text "$WAN3" 'HTTP CONNECT'

# Adaptive SLA algorithm.
SLA=files/usr/local/bin/wan-sla
require_text "$SLA" 'WAN1_TRANSPORT=unknown'
require_text "$SLA" 'wan-port-manager wan-transport'
require_text "$SLA" 'for name in wan wan2 wan3'
require_text "$SLA" 'low) echo 2'
require_text "$SLA" 'medium) echo 3'
require_text "$SLA" 'fast) echo 4'
require_text "$SLA" 'selection_role=standby'
require_text "$SLA" 'probe_reason'
require_text "$SLA" 'persisted_active'
require_text "$SLA" 'route_active'
reject_text "$SLA" 'standby_probe_failed'
require_text "$SLA" 'route_valid'
require_text "$SLA" '(src|from) $source'
require_text "$SLA" 'unreachable|prohibit|blackhole|throw'
require_text "$SLA" 'gateway_icmp_probe'
require_text "$SLA" 'ping -c 1 -W 2 -I "$source" "$gateway"'
require_text "$SLA" 'https_probe'
require_text "$SLA" '--interface "$source"'
require_text "$SLA" "--proxy ''"
require_text "$SLA" 'PROBE_REASON=gateway_icmp'
require_text "$SLA" 'PROBE_REASON=https_reachable'
require_text "$SLA" 'PROBE_REASON=route_invalid'
require_text "$SLA" 'PROBE_REASON=probe_failed'
require_text "$SLA" 'health_expected_codes'
require_text "$SLA" 'https://connectivitycheck.gstatic.com/generate_204'
require_text "$SLA" 'failure_count'
require_text "$SLA" 'promote_count'
require_text "$SLA" 'promotion_ready'
require_text "$SLA" 'hold_down'
require_text "$SLA" 'result_ttl'
require_text "$SLA" 'speed_test_interval'
require_text "$SLA" '/tmp/wan-speed/$name.json'
require_text "$SLA" 'selection_mode=automatic'
require_text "$SLA" '[ "$raw_score" -eq 1 ] || [ "$raw_score" -ge "$min_score" ]'
require_text "$SLA" 'table 22 may provide the remote Mesh WAN fallback'
require_text "$SLA" 'wan1_transport'

# Tunnel guards and Babel race prevention.
GUARD=files/usr/local/bin/wan-tunnel-guard
require_text "$GUARD" 'RULE_PREF=45'
require_text "$GUARD" 'BLACKHOLE_TABLE=99'
require_text "$GUARD" 'ip -4 rule add pref "$RULE_PREF" iif "$dev" lookup "$BLACKHOLE_TABLE"'
require_text "$GUARD" 'ip -6 rule add pref "$RULE_PREF" iif "$dev" lookup "$BLACKHOLE_TABLE"'
require_text "$GUARD" 'redistribute proto 3 ip 0.0.0.0/0 eq 0 deny'
require_text "$GUARD" 'in if %s ip 0.0.0.0/0 eq 0 deny'
require_text "$GUARD" 'out if %s ip ::/0 eq 0 deny'

# Speed-test CLI boundary, route proof, bins, and data limits.
CAL=files/usr/local/bin/wan-speed-test
require_text "$CAL" 'wan|wan2|wan3'
require_text "$CAL" 'test-all'
require_text "$CAL" 'route-check'
require_text "$CAL" 'cloudflare.com/cdn-cgi/trace'
require_text "$CAL" 'speed.cloudflare.com/__down?bytes='
require_text "$CAL" 'iperf3 -c "$REMOTE_NODE" -p "$PORT" -t "$DURATION" -R -J'
require_text "$CAL" 'valid_node'
require_text "$CAL" 'getent hosts'
require_text "$CAL" 'Private table $TABLE does not use $DEVICE'
require_text "$CAL" '--max-redirs 0'
require_text "$CAL" '--proto-redir'
require_text "$CAL" "--proxy ''"
reject_text "$CAL" 'wan3_proxy_enable'
reject_text "$CAL" '--noproxy'
require_text "$CAL" 'Cloudflare trace did not report a colo'
require_text "$CAL" 'Active WAN changed during test'
require_text "$CAL" 'Cloudflare download returned too few bytes'
require_text "$CAL" 'cp "$STATE_DIR/$WAN.json" "$STATE_DIR/$WAN.status.json"'
require_text files/usr/local/bin/wan-calibrate 'wan-speed-test test'
require_text tests/test-ip-compat.sh 'TABLE=251'
require_text tests/test-ip-compat.sh 'PREF1=32501'
require_text tests/test-ip-compat.sh 'ip -4 route get "$DEST" from "$SOURCE" oif "$DEVICE"'
require_text tests/test-ip-compat.sh 'onlink proto static'
require_text tests/test-ip-compat.sh 'ip -6 route replace blackhole default table "$TABLE"'

# Authenticated UI and requested controls.
for file in files/app/main/status/e/*.ut; do require_text "$file" 'if (!auth.isAdmin)'; done
require_text files/app/main/status/e/ethernet-ports.ut 'hAP Ethernet port roles'
require_text files/app/main/status/e/ethernet-ports.ut 'Apply with rollback'
require_text files/app/main/status/e/ethernet-ports.ut 'Wi-Fi client on wlan0'
require_text files/app/main/status/e/ethernet-ports.ut 'Wi-Fi client on wlan1'
require_text files/app/main/status/e/ethernet-ports.ut 'no Ethernet port may also be assigned to WAN 1'
require_text files/app/main/status/e/ethernet-ports.ut 'WAN 3 remains Android USB tether'
require_text files/app/main/status/e/ethernet-ports.ut 'never edits gpsd'
require_text files/app/main/status/e/usb-wan.ut 'Connect an Android phone by USB and enable USB tethering on the phone'
require_text files/app/main/status/e/usb-wan.ut 'USB charging alone is insufficient'
require_text files/app/main/status/e/usb-wan.ut 'Existing kernel support'
require_text files/app/main/status/e/usb-wan.ut 'PollyWAN does not replace kernel modules'
require_text files/app/main/status/e/usb-wan.ut 'Detected device'
require_text files/app/main/status/e/usb-wan.ut 'IPv4 address'
require_text files/app/main/status/e/usb-wan.ut 'gateway'
require_text files/app/main/status/e/usb-wan.ut 'Requesting DHCP'
reject_text files/app/main/status/e/usb-wan.ut 'Proxy IPv4 address'
reject_text files/app/main/status/e/usb-wan.ut 'Proxy TCP port'
require_text files/app/main/status/e/link-calibration.ut 'Connection speed test'
require_text files/app/main/status/e/link-calibration.ut 'AREDN node test'
require_text files/app/main/status/e/link-calibration.ut 'Internet test - Cloudflare'
require_text files/app/main/status/e/link-calibration.ut 'Cloudflare uses Anycast'
require_text files/app/main/status/e/link-calibration.ut 'Estimated Internet-test data use'
require_text files/app/main/status/e/link-calibration.ut 'Not tested'
require_text files/app/main/status/e/link-calibration.ut 'Expired'
require_text files/app/main/status/e/link-calibration.ut 'last.valid === true'
require_text files/app/main/status/e/wan-policy.ut 'private table 101'
require_text files/app/main/status/e/wan-policy.ut 'tunnel guards'
require_text files/app/main/status/e/wan-policy.ut 'Use remote Mesh WAN'
require_text files/app/main/status/e/wan-policy.ut 'Manual'
require_text files/app/main/status/e/wan-policy.ut 'Automatic'
reject_text files/app/main/status/e/wan-policy.ut '>Availability<'
reject_text files/app/main/status/e/wan-policy.ut '>Adaptive speed bins<'
for file in files/app/partial/wan-policy.ut files/app/partial/ethernet-ports.ut files/app/partial/usb-wan.ut files/app/partial/link-calibration.ut; do
    require_text "$file" 'hx-target="#ctrl-modal"'
    require_text "$file" 'hx-swap="innerHTML"'
done

# Documentation and two-repository contract.
require_text README.md '`wan` — WAN 1'
require_text README.md '`wan3` — Android USB tether'
require_text docs/port-roles-and-gps.md 'GPS safety contract'
require_text docs/port-roles-and-gps.md 'radio0_mode=wan'
require_text docs/port-roles-and-gps.md '/dev/ttyACM0'
require_text docs/multiwan-usb-wan.md 'RNDIS, CDC Ethernet, or CDC NCM'
require_text docs/multiwan-usb-wan.md 'USB charging alone is insufficient'
require_text docs/multiwan-link-calibration.md 'Health is not speed'
require_text docs/multiwan-link-calibration.md 'AREDN node-to-node testing'
require_text docs/multiwan-link-calibration.md 'Cloudflare uses Anycast routing'
require_text docs/multiwan-link-calibration.md 'wan-speed-test route-check wan'
require_text docs/multiwan-mesh-wan.md 'table 101'
require_text docs/multiwan-mesh-wan.md 'table 22'
require_text docs/multiwan-mesh-wan.md 'protocol-`boot`'
require_text docs/multiwan-verification.md 'Disabled-install, radio, and GPS test'
require_text docs/multiwan-verification.md 'Wi-Fi WAN ownership'
require_text tools/openclaw-build-test-prompt.md 'mse-88/hub5'
require_text tools/openclaw-build-test-prompt.md 'main'
require_text tools/openclaw-build-test-prompt.md 'Wi-Fi client'
require_text tools/openclaw-build-test-prompt.md 'r27 requirements'
[ "$(wc -c < tools/openclaw-build-test-prompt.md)" -lt 2000 ] || fail 'OpenClaw prompt exceeds 2000 characters'
require_text SYNC_SOURCE 'standalone_branch=main'
require_text SYNC_SOURCE 'integration_branch=agent/pollywan-r6'
require_text SYNC_SOURCE 'sync_contract=standalone-root-equals-integration-subtree'
require_text tools/sync-integration.sh 'rsync -rnic --delete --exclude .git'

# No obsolete/broken bootstrap or older release claims.
if grep -RIn --exclude-dir=.git --exclude=SYNC_SOURCE --exclude=verify.sh -E 'source\.tar\.gz\.b64|chunk-0[0-9]|PKG_RELEASE:=(3|5|6|10|16|25)|PollyWAN r(3|5|6|10|16|25)|0\.1\.0-r(3|5|6|10|16|25)|main contains r3|incomplete source' . >/tmp/pollywan-stale.$$; then
    cat /tmp/pollywan-stale.$$ >&2
    rm -f /tmp/pollywan-stale.$$
    fail 'stale release/bootstrap references remain'
fi
rm -f /tmp/pollywan-stale.$$

# The manifest excludes SYNC_SOURCE itself to avoid self-reference.
expected_manifest="$(sed -n 's/^content_manifest_sha256=//p' SYNC_SOURCE)"
[ -n "$expected_manifest" ] || fail 'SYNC_SOURCE has no content manifest'
actual_manifest="$(
    find . -path './.git' -prune -o -type f ! -path './SYNC_SOURCE' -print |
    LC_ALL=C sort |
    while IFS= read -r file; do
        if [ -x "$file" ]; then mode=755; else mode=644; fi
        hash="$(sha256sum "$file" | awk '{print $1}')"
        printf '%s  %s  %s\n' "$mode" "${file#./}" "$hash"
    done |
    sha256sum | awk '{print $1}'
)"
[ "$actual_manifest" = "$expected_manifest" ] || fail "content manifest mismatch: $actual_manifest != $expected_manifest"

./tests/mock-port-manager.sh
./tests/mock-route-cache.sh
./tests/mock-tunnel-guard.sh
./tests/test-selection-model.py

python3 - <<'PY'
from html.parser import HTMLParser
from pathlib import Path
from xml.etree import ElementTree
import re

root = Path('.')
ElementTree.parse(root / 'files/www/apps/aredn-multiwan/icon.svg')

class Parser(HTMLParser):
    pass

Parser().feed((root / 'files/www/apps/aredn-multiwan/help.html').read_text())
for path in (root / 'files/app').rglob('*.ut'):
    raw = path.read_bytes()
    if raw.startswith(b'\xef\xbb\xbf'):
        raise SystemExit(f'UTF-8 BOM present: {path}')
    source = raw.decode('utf-8')
    if re.search('[\u00c3\u00c2\ufffd]', source):
        raise SystemExit(f'mojibake marker present: {path}')
    if source.count('{%') != source.count('%}'):
        raise SystemExit(f'unbalanced ucode template markers: {path}')
for path in (root / 'files/www').rglob('*'):
    if path.is_file():
        raw = path.read_bytes()
        if raw.startswith(b'\xef\xbb\xbf'):
            raise SystemExit(f'UTF-8 BOM present: {path}')
        source = raw.decode('utf-8')
        if re.search('[\u00c3\u00c2\ufffd]', source):
            raise SystemExit(f'mojibake marker present: {path}')
style = (root / 'files/app/partial/multiwan-style.ut').read_text()
if style.count('id="pollywan-style"') != 1:
    raise SystemExit('style partial must contain one #pollywan-style')
if 'id="pollywan-style"' in (root / 'files/app/main/u-multiwan.ut').read_text():
    raise SystemExit('u-multiwan must not render #pollywan-style directly')
page = (root / 'files/app/partial/multiwan-page.ut').read_text()
for required in ['id="multiwan-page"', 'wan-card-1', 'wan-card-2', 'usb-wan', 'mesh-card', 'Table 22', 'Table 26', 'Table 27', 'Table 28']:
    if required not in page and required not in (root / 'files/app/partial/wan-policy.ut').read_text():
        raise SystemExit(f'missing dashboard marker: {required}')
for port in range(1, 6):
    if f'P{port}' not in (root / 'files/app/partial/ethernet-ports.ut').read_text():
        raise SystemExit(f'missing port tile marker: P{port}')
for cls in ['pw-status-ok', 'pw-status-warn', 'pw-status-bad', 'pw-status-off', 'pw-status-unknown', 'pw-status-active']:
    if cls not in ''.join(p.read_text() for p in (root / 'files/app').rglob('*.ut')):
        raise SystemExit(f'missing status class: {cls}')
for line in style.splitlines():
    stripped = line.strip()
    if not stripped or stripped.startswith(('<style', '</style>', '@media', '#multiwan-page', '.pollywan-dialog')):
        continue
    if '{' in stripped and not stripped.startswith('@'):
        raise SystemExit('PollyWAN CSS contains an unscoped selector')
obsolete_init = '/etc/init.d/' + 'aredn-' + 'multiwan'
if obsolete_init in ''.join(p.read_text(errors='ignore') for p in root.rglob('*') if p.is_file() and '.git' not in p.parts and str(p) != 'tests/verify.sh'):
    raise SystemExit('obsolete init-script reference remains')
print('markup/template balance passed')
PY

require_text "$SLA" 'manual selected WAN failed; selected healthy fallback $active'
require_text "$SLA" 'choose_healthy_candidate'
require_text "$SLA" '[ -n "$manual_recovery" ] && switch_to "$manual_recovery"'
require_text files/usr/local/bin/wan3-manager 'function cidr_prefix'
require_text files/usr/local/bin/wan-route-cache 'function cidr_prefix'
require_text files/usr/local/bin/wan-route-cache 'connected_prefix_from_cidr "$cidr"'

echo 'PollyWAN r27 static and mock verification passed'
