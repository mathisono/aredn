#!/bin/sh
# Static and disposable-mock verification for the standalone PollyWAN r29.5 source.
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
files/usr/local/bin/wan-mesh-exit
files/etc/init.d/wan3-manager
files/etc/hotplug.d/iface/95-wan3-manager
files/etc/hotplug.d/net/95-wan3-manager
files/etc/uci-defaults/95-aredn-multiwan
files/www/cgi-bin/apps/aredn-multiwan/admin
files/www/cgi-bin/apps/aredn-multiwan/status.json
tests/verify.sh
tests/mock-port-manager.sh
tests/mock-route-cache.sh
tests/mock-tunnel-guard.sh
tests/mock-mesh-exit.sh
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
docs/aredn-sysinfo-integration-plan.md
tools/openclaw-build-test-prompt.md
tools/sync-integration.sh
tests/test-selection-model.py
tests/test-route-order-ui.js
tests/mock-mesh-exit.sh
files/app/main/u-multiwan.ut
files/app/main/u-wan-policy.ut
files/app/main/u-ethernet-ports.ut
files/app/main/u-usb-wan.ut
files/app/main/u-link-calibration.ut
files/app/main/status/e/wan-policy.ut
files/app/main/status/e/ethernet-ports.ut
files/app/main/status/e/usb-wan.ut
files/app/main/status/e/link-calibration.ut
files/usr/share/ucode/aredn/pollywan.uc
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
require_text Makefile 'PKG_VERSION:=0.1.0.29.5'
require_text Makefile 'PKG_RELEASE:=9'
require_text Makefile '/etc/init.d/uhttpd restart'
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
require_text Makefile 'if [ "$${PKG_UPGRADE:-0}" = 1 ]'
require_text Makefile '/etc/init.d/wan3-manager restart'
require_text Makefile 'files/app/partial/multiwan-style.ut'
require_text Makefile 'files/app/partial/multiwan.ut'
require_text Makefile 'files/usr/local/bin/wan-speed-test'
require_text Makefile 'files/usr/local/bin/wan-mesh-exit'
require_text Makefile 'files/usr/share/ucode/aredn/pollywan.uc'
require_text Makefile 'files/www/cgi-bin/apps/aredn-multiwan/status.json'
require_text Makefile 'docs/aredn-sysinfo-integration-plan.md'
reject_text Makefile 'files/app/main/multiwan.ut'
reject_text Makefile '/app/main/sysinfo.ut'
require_text LICENSE 'GNU General Public License'
require_text AREDNLicense.txt 'not represented as an official'

# AREDN 4.26's UCode renderer does not support JavaScript optional chaining.
! grep -R -nF '?.' files/app || fail 'UI templates must not use optional chaining'
! grep -R -nF 'strftime(' files/app || fail 'UI templates must not depend on strftime'

# Every PollyWAN GUI settings write uses one ownership-aware, verified
# persistent writer.  No dialog may silently become a second owner.
GUI_CONFIG=files/usr/share/ucode/aredn/pollywan.uc
reject_text "$GUI_CONFIG" 'configuration.prepareChanges()'
require_text "$GUI_CONFIG" 'configuration.countChanges() > 0'
require_text "$GUI_CONFIG" 'function restoreValues('
require_text "$GUI_CONFIG" 'previous persistent values could not be restored'
require_text "$GUI_CONFIG" 'uci.cursor("/etc/config.mesh")'
require_text "$GUI_CONFIG" 'cursor.commit("aredn") === false'
require_text "$GUI_CONFIG" 'did not match after commit'
require_text "$GUI_CONFIG" 'export function saveXlinks'
require_text "$GUI_CONFIG" 'cursor.commit("xlink") === false'
require_text "$GUI_CONFIG" 'Persistent XLink count did not match after commit'
require_text "$GUI_CONFIG" 'policy: {'
require_text "$GUI_CONFIG" 'ports: {'
require_text "$GUI_CONFIG" 'usb: {'
require_text "$GUI_CONFIG" 'speed: {'
for file in \
    files/app/main/status/e/wan-policy.ut \
    files/app/main/status/e/ethernet-ports.ut \
    files/app/main/status/e/usb-wan.ut \
    files/app/main/status/e/link-calibration.ut
do
    require_text "$file" 'import * as pollywan from "aredn.pollywan";'
    reject_text "$file" 'uciMesh.set("aredn", "multiwan"'
    reject_text "$file" 'uciMesh.commit("aredn")'
done
require_text files/app/main/status/e/wan-policy.ut 'pollywan.save("policy"'
require_text files/app/main/status/e/ethernet-ports.ut 'pollywan.save("ports"'
require_text files/app/main/status/e/usb-wan.ut 'pollywan.save("usb"'
require_text files/app/main/status/e/link-calibration.ut 'pollywan.save("speed"'
require_text files/app/main/status/e/wan-policy.ut 'name="wan_enable"'
require_text files/app/main/status/e/wan-policy.ut 'name="wan2_enable"'
require_text files/app/main/status/e/wan-policy.ut 'name="wan3_enable"'
reject_text files/app/main/status/e/ethernet-ports.ut 'name="wan_enable"'
reject_text files/app/main/status/e/ethernet-ports.ut 'name="wan2_enable"'
reject_text files/app/main/status/e/usb-wan.ut 'name="wan3_enable"'
require_text files/app/main/status/e/ethernet-ports.ut 'const values = { port_roles_enabled: controllerEnabled ? "1" : "0" };'
require_text files/app/main/status/e/ethernet-ports.ut 'pollywan.saveXlinks('
require_text files/app/main/status/e/ethernet-ports.ut 'wan-port-manager restore-stage'
reject_text files/app/main/status/e/ethernet-ports.ut 'name="port_roles_enabled"'
reject_text files/app/main/status/e/ethernet-ports.ut 'WAN 1 ownership'
reject_text files/app/main/status/e/ethernet-ports.ut 'Local candidate policy'
reject_text files/app/main/status/e/ethernet-ports.ut 'Manage Ethernet roles with PollyWAN'
require_text files/app/partial/ethernet-ports.ut 'roleEnabled && fs.access("/etc/aredn_include/.aredn-multiwan-ports")'
require_text files/app/partial/ethernet-ports.ut '"Needs attention"'

# Defaults are inert and GPS/radio neutral.
DEFAULTS=files/etc/uci-defaults/95-aredn-multiwan
require_text "$DEFAULTS" 'set_default enabled 0'
require_text "$DEFAULTS" 'set -eu'
require_text "$DEFAULTS" 'set_default port_roles_enabled 0'
require_text "$DEFAULTS" 'set_default selection_mode ordered'
require_text "$DEFAULTS" 'set_default wan_enable 1'
require_text "$DEFAULTS" 'set_default wan2_enable 0'
require_text "$DEFAULTS" 'set_default wan3_enable 0'
require_text "$DEFAULTS" 'set_default mesh_enable 0'
require_text "$DEFAULTS" 'set_default priority_1 wan'
require_text "$DEFAULTS" 'set_default priority_2 wan2'
require_text "$DEFAULTS" 'set_default priority_3 wan3'
require_text "$DEFAULTS" 'set_default priority_4 mesh'
require_text "$DEFAULTS" '$UCI -q get "aredn.multiwan.$option" >/dev/null 2>&1 || $UCI set "aredn.multiwan.$option=$value"'
require_text "$DEFAULTS" 'ordered) ;;'
require_text "$DEFAULTS" 'set_default port1_role wan'
require_text "$DEFAULTS" 'set_default port2_role lan'
require_text "$DEFAULTS" 'set_default port5_dtd 1'
require_text "$DEFAULTS" 'set_default selection_min_bin low'
require_text "$DEFAULTS" 'set_default mesh_share_min_bin medium'
require_text "$DEFAULTS" 'set_default standby_health_interval 90'
require_text "$DEFAULTS" 'set_default failed_probe_interval 120'
require_text "$DEFAULTS" 'set_default failed_probe_interval_max 300'
require_text "$DEFAULTS" "set_default health_url 'https://connectivitycheck.gstatic.com/generate_204'"
require_text "$DEFAULTS" 'set_default health_expected_codes 204'
require_text "$DEFAULTS" "set_default health_url_secondary ''"
require_text "$DEFAULTS" 'set_default health_secondary_expected_codes 200,204'
require_text "$DEFAULTS" 'set_default failure_count 2'
require_text "$DEFAULTS" 'set_default promote_count 2'
require_text "$DEFAULTS" 'set_default hold_down 120'
require_text "$DEFAULTS" 'set_default mesh_export_recover_count 3'
require_text "$DEFAULTS" 'set_default mesh_export_hold_down 60'
require_text "$DEFAULTS" 'set_default speed_result_ttl 21600'
require_text "$DEFAULTS" 'set_default speed_test_auto 0'
require_text "$DEFAULTS" 'set_default speed_test_interval 21600'
require_text "$DEFAULTS" 'set_default speed_test_method cloudflare'
require_text "$DEFAULTS" "selection_mode='ordered'"
reject_text "$DEFAULTS" 'uci commit aredn >/dev/null'
require_text "$DEFAULTS" 'PollyWAN initialization failed: missing aredn.multiwan.$required'
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
require_text "$PORTS" 'setup_get()'
require_text "$PORTS" 'radio_mode()'
require_text "$PORTS" 'wifi_wan_device()'
require_text "$PORTS" 'validate_rf_vlan()'
require_text "$PORTS" 'configured RF VLAN $vlan conflicts with PollyWAN Ethernet VLANs 2/3/4/5'
require_text "$PORTS" "printf '%s\\n' wlan0"
require_text "$PORTS" "printf '%s\\n' wlan1"
require_text "$PORTS" "printf 'wifi:%s\\n'"
require_text "$PORTS" 'invalid:both-radios'
require_text "$PORTS" 'no Ethernet port may be assigned to WAN 1'
require_text "$PORTS" 'our Ethernet WAN override'
require_text "$PORTS" 'version=9'
require_text "$PORTS" 'wan_transport='
require_text "$PORTS" 'WAN 1 transport changed from'
require_text "$PORTS" 'mikrotik,routerboard-952ui-5ac2nd) echo swconfig'
require_text "$PORTS" 'mikrotik,hap-ac2|mikrotik,hap-ac3) echo dsa'
require_text "$PORTS" 'at least one Ethernet port must remain LAN'
require_text "$PORTS" 'schedule_rollback'
require_text "$PORTS" 'stage_transaction'
require_text "$PORTS" 'restore_transaction'
require_text "$PORTS" 'XLINK_CONFIG=/etc/config.mesh/xlink'
require_text "$PORTS" 'xlink.config.absent'
require_text "$PORTS" 'activate_staged()'
require_text "$PORTS" "awaiting confirmation"
require_text "$PORTS" 'set_role_management()'
require_text "$PORTS" 'ROLLBACK_DIR=/etc/aredn-multiwan-backup/pending'
require_text "$PORTS" 'rolled back to the previous managed configuration'
require_text "$PORTS" 'Applying persisted Ethernet role configuration'
require_text "$PORTS" 'apply_roles persistent'
require_text "$PORTS" 'Interrupted persisted activation restored AREDN files; PollyWAN was disabled for review'
require_text "$PORTS" 'an Ethernet role recovery snapshot already exists'
reject_text "$PORTS" '$CONFIG_PACKAGE.$CONFIG_SECTION.wan2_enable=0'
reject_text "$PORTS" '$CONFIG_PACKAGE.$CONFIG_SECTION.wan3_enable=0'
require_text "$PORTS" 'POLLYWAN_TEST_MODE'
require_text "$PORTS" 'pending-token'
require_text "$PORTS" 'confirm_roles'
require_text "$PORTS" 'restore_backups'
require_text "$PORTS" '/usr/local/bin/node-setup'
require_text "$PORTS" 'add_list "firewall.$zone.network=wan2"'
require_text "$PORTS" '[ "$(uci_get port_roles_enabled)" = 1 ] && [ -e "$MARKER" ]'
reject_text "$PORTS" 'firewall.$zone.network=wifi'
reject_text "$PORTS" 'firewall.$zone.network=fast'
require_text "$PORTS" 'option ip4table '\''102'\'''
require_text "$PORTS" 'gps_status()'
reject_text "$PORTS" 'uci set gpsd'
reject_text "$PORTS" 'uci -c /etc/config.mesh set gpsd'
reject_text "$PORTS" 'gpsd stop'
reject_text "$PORTS" 'gpsd restart'
reject_text "$PORTS" 'usb_passthrough'
require_text files/etc/init.d/wan3-manager 'Ethernet role reconciliation failed; controller startup stopped'

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
require_text "$WAN3" 'lo|br*|wlan*|phy*|ifb*|wg*|tun*|dtd*) return 1'
require_text "$WAN3" 'json_add_string name wan3'
require_text "$WAN3" 'json_add_string zone wan'
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
require_text "$CACHE" 'IP_BIN="${IP_BIN:-ip}"'
require_text "$WAN3" 'LOCAL_TABLE=26'
require_text "$WAN3" 'LOCAL_SUBNET_TABLE=27'
require_text "$WAN3" 'BABEL_EXPORT_TABLE=28'
require_text "$WAN3" 'REMOTE_MESH_TABLE=22'
require_text "$WAN3" 'snapshot_routes'
require_text "$WAN3" 'restore_route_snapshot'
require_text "$WAN3" 'function cidr_prefix'
require_text "$WAN3" 'split(value, parts, "/") == 2'
require_text "$WAN3" 'connected_prefix_from_cidr "$source/$mask"'
require_text "$WAN3" 'replace_default_if_needed "$LOCAL_TABLE" "$device" "$source" "$gateway" 1'
require_text "$WAN3" 'replace_default_if_needed main "$device" "$source" "$gateway" 1'
require_text "$WAN3" 'default_route_matches'
require_text "$WAN3" 'replace_default_if_needed'
require_text "$WAN3" 'withdraw_export_if_needed'
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
reject_text "$SLA" 'for name in wan wan2 wan3 wifi fast'
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
reject_text "$SLA" 'PROBE_REASON=gateway_icmp'
require_text "$SLA" 'PROBE_REASON=https_reachable'
require_text "$SLA" 'PROBE_REASON=https_secondary_reachable'
require_text "$SLA" 'PROBE_REASON=route_invalid'
require_text "$SLA" 'PROBE_REASON=upstream_unreachable'
require_text "$SLA" 'PROBE_REASON=gateway_and_upstream_unreachable'
require_text "$SLA" 'health_expected_codes'
require_text "$SLA" 'health_url_secondary'
require_text "$SLA" 'health_secondary_expected_codes'
require_text "$SLA" 'https://connectivitycheck.gstatic.com/generate_204'
require_text "$SLA" 'failure_count'
require_text "$SLA" 'promote_count'
require_text "$SLA" 'promotion_ready'
require_text "$SLA" 'hold_down'
require_text "$SLA" 'result_ttl'
require_text "$SLA" 'speed_test_interval'
require_text "$SLA" '/tmp/wan-speed/$name.json'
require_text "$SLA" 'selection_mode=ordered'
require_text "$SLA" 'evaluate_mesh_candidate'
require_text "$SLA" 'remote_mesh_exit_node'
require_text "$SLA" '/usr/local/bin/wan-mesh-exit'
require_text "$SLA" 'for slot in 1 2 3 4'
require_text "$SLA" 'Ordered policy selected Remote Mesh WAN'
require_text "$SLA" 'candidate_rank'
require_text "$SLA" 'wan1_transport'
require_text "$SLA" 'TELEMETRY_FILE="$STATE_DIR/telemetry.json"'
require_text "$SLA" 'PACKAGE_VERSION=0.1.0-r29.5'
require_text "$SLA" '"schema_version":1'
require_text "$SLA" 'active_upstream_reachable'
require_text "$SLA" 'mesh_exported'
require_text "$SLA" 'export_recovery_ready'
require_text "$SLA" 'mesh_export_recover_count'
require_text "$SLA" 'mesh_export_hold_down'
require_text "$SLA" 'EXPORT_CANDIDATE_FILE="$STATE_DIR/export-recover-candidate"'
require_text "$SLA" 'EXPORT_STREAK_FILE="$STATE_DIR/export-recover-streak"'
require_text "$SLA" 'EXPORT_CHANGE_FILE="$STATE_DIR/last-export-change"'
require_text "$SLA" 'standby_health_interval'
require_text "$SLA" 'failed_probe_interval'
require_text "$SLA" 'failed_probe_interval_max'
require_text "$SLA" 'probe_due'
require_text "$SLA" 'mark_next_probe'
require_text "$SLA" 'MANUAL_CHECK=1'
require_text "$SLA" '"selection_healthy":%s'
require_text "$SLA" '"export_eligible":%s'
require_text "$SLA" '"probe_endpoint":%s'
require_text "$SLA" '"next_probe_epoch":%s'
require_text "$SLA" '"candidates":['

# Tunnel guards and Babel race prevention.
GUARD=files/usr/local/bin/wan-tunnel-guard
require_text "$GUARD" 'RULE_PREF=45'
require_text "$GUARD" 'BLACKHOLE_TABLE=99'
require_text "$GUARD" 'IP_BIN="${IP_BIN:-ip}"'
require_text "$GUARD" '"$IP_BIN" -4 rule add pref "$RULE_PREF" iif "$dev" lookup "$BLACKHOLE_TABLE"'
require_text "$GUARD" '"$IP_BIN" -6 rule add pref "$RULE_PREF" iif "$dev" lookup "$BLACKHOLE_TABLE"'
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
for file in \
    files/app/main/status/e/wan-policy.ut \
    files/app/main/status/e/ethernet-ports.ut \
    files/app/main/status/e/usb-wan.ut \
    files/app/main/status/e/link-calibration.ut
do
    require_text "$file" '_R("dialog-footer"'
    require_text "$file" 'REQUEST_METHOD === "DELETE"'
    require_text "$file" 'configuration.revertModalChanges()'
    [ "$(grep -o '>Apply<' "$file" | wc -l)" -eq 1 ] || fail "$file must expose exactly one settings Apply button"
done
require_text files/app/main/status/e/wan-policy.ut '_R("dialog-footer", runtimeStarted ? "nocancel" : "")'
require_text files/app/main/status/e/ethernet-ports.ut '_R("dialog-footer", applyStarted ? "nocancel" : "")'
for file in files/app/main/status/e/usb-wan.ut files/app/main/status/e/link-calibration.ut; do
    require_text "$file" '{{_R("dialog-footer")}}'
    reject_text "$file" '"nocancel"'
done
require_text files/app/main/status/e/ethernet-ports.ut 'Ports &amp; XLinks'
require_text files/app/main/status/e/ethernet-ports.ut '<div>DtD</div><div>VLAN 2</div>'
require_text files/app/main/status/e/ethernet-ports.ut 'type="radio" name="role_{{p.name}}" value="lan"'
require_text files/app/main/status/e/ethernet-ports.ut 'type="radio" name="role_{{p.name}}" value="wan2"'
require_text files/app/main/status/e/ethernet-ports.ut 'pw-ethernet-role-actions'
require_text files/app/main/status/e/ethernet-ports.ut 'Wi-Fi client on wlan0'
require_text files/app/main/status/e/ethernet-ports.ut 'Wi-Fi client on wlan1'
require_text files/app/main/status/e/ethernet-ports.ut 'no Ethernet port may also be assigned to WAN 1'
require_text files/app/main/status/e/usb-wan.ut 'PollyWAN does not replace kernel modules'
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
require_text files/app/main/status/e/link-calibration.ut 'Remote Mesh WAN'
require_text files/app/main/status/e/link-calibration.ut 'Status only — speed is measured at the remote exit node'
require_text files/app/main/status/e/link-calibration.ut 'function liveMeshExit()'
require_text files/app/partial/link-calibration.ut 'Remote Mesh WAN'
require_text files/app/partial/link-calibration.ut 'No table 22 route'
require_text files/app/partial/link-calibration.ut 'function liveMeshExit()'
require_text files/app/partial/wan-policy.ut '<div class="pw-label">Exit</div>'
require_text files/app/partial/wan-policy.ut 'function liveMeshExit()'
require_text files/app/main/status/e/wan-policy.ut 'Route Policy Setup'
require_text files/app/main/status/e/wan-policy.ut 'Preferred connection order'
require_text files/app/main/status/e/wan-policy.ut 'Selecting a route already used in another position swaps the two positions.'
require_text files/app/main/status/e/wan-policy.ut 'select[data-priority-order]'
require_text files/app/main/status/e/wan-policy.ut 'data-previous-priority'
require_text files/app/main/status/e/wan-policy.ut 'Remote Mesh WAN'
require_text files/app/main/status/e/wan-policy.ut 'Minimum allowable local data rate'
require_text files/app/main/status/e/wan-policy.ut 'Internet check URL'
require_text files/app/main/status/e/wan-policy.ut 'Backup Internet check URL'
reject_text files/app/main/status/e/wan-policy.ut 'Primary expected response codes'
reject_text files/app/main/status/e/wan-policy.ut 'Secondary expected response codes'
reject_text files/app/main/status/e/wan-policy.ut '<details class="pw-advanced">'
require_text files/app/main/status/e/wan-policy.ut 'Export recovery observations must be between 1 and 10'
require_text files/app/main/status/e/wan-policy.ut 'Export recovery hold-down must be between 0 and 3600'
require_text files/app/main/status/e/wan-policy.ut 'mesh_export_recover_count'
require_text files/app/main/status/e/wan-policy.ut 'PollyWAN policy saved, verified, and controller restarted'
require_text files/app/main/status/e/wan-policy.ut 'protected Ethernet activation'
require_text files/app/main/status/e/wan-policy.ut 'wan-port-manager stage'
require_text files/app/main/status/e/wan-policy.ut 'wan-port-manager activate-staged'
require_text files/app/main/status/e/wan-policy.ut 'pw-policy-actions'
require_text files/app/main/status/e/wan-policy.ut 'pollywan-wide-page'
reject_text files/app/main/status/e/wan-policy.ut 'Runtime decision'
reject_text files/app/main/status/e/wan-policy.ut 'Done</b> only closes this window and does not save or apply changes.'
reject_text files/app/main/status/e/wan-policy.ut '>Manual<'
reject_text files/app/main/status/e/wan-policy.ut '>Automatic<'
require_text files/app/partial/wan-policy.ut 'Ordered failover'
require_text files/app/partial/wan-policy.ut 'Preferred order'
require_text files/app/partial/wan-policy.ut 'preferredOrder()'
require_text files/app/partial/wan-policy.ut '<div class="pw-label">State</div>'
require_text files/app/partial/wan-policy.ut '<div class="pw-label">Path</div>'
require_text files/app/partial/multiwan-page.ut 'runtimeState(enabled, status)'
require_text files/app/partial/multiwan-page.ut 'status.active_health === "healthy"'
require_text files/app/partial/multiwan-page.ut 'Port change pending'
require_text files/app/partial/multiwan-page.ut 'Failure pending'
require_text files/app/partial/multiwan-page.ut 'Recovery pending'
require_text files/app/partial/multiwan-page.ut 'Status stale'
require_text files/app/partial/multiwan-page.ut 'Configuration error'
require_text files/app/partial/multiwan-page.ut 'fs.access("/tmp/wan-sla/.lock")'
require_text files/app/partial/multiwan-page.ut 'status.generated_at_epoch'
require_text files/app/partial/multiwan-page.ut 'pw-state-current'
reject_text files/app/partial/multiwan-page.ut 'manual_check'
require_text files/app/partial/multiwan-page.ut 'Current operating state'
require_text files/app/partial/multiwan-style.ut '.pw-state-strip'
require_text files/app/partial/multiwan-style.ut '.pollywan-ports-page'
reject_text files/app/main/status/e/ethernet-ports.ut 'throw "'
require_text files/app/partial/multiwan-style.ut '.pollywan-wide-page'
require_text files/app/partial/multiwan-style.ut 'width: 96vw'
require_text files/app/partial/multiwan-style.ut 'max-width: 1440px'
require_text files/app/partial/multiwan-style.ut '.pollywan-ports-table-wrap'
require_text files/app/partial/multiwan-style.ut 'overflow-x: auto'
require_text files/app/main/status/e/ethernet-ports.ut 'Ports &amp; XLinks'
require_text files/app/main/status/e/ethernet-ports.ut 'pollywan-ports-page'
require_text files/app/main/status/e/ethernet-ports.ut 'pollywan-ports-table-wrap'
require_text files/app/main/status/e/ethernet-ports.ut 'function normalizedXlinks'
reject_text files/app/main/status/e/ethernet-ports.ut 'uciMesh.commit("xlink")'
reject_text files/app/main/status/e/ethernet-ports.ut 'action === "save-xlinks"'
reject_text files/app/main/status/e/ethernet-ports.ut 'WAN 1 transport'
require_text files/app/partial/wan-policy.ut '{{_R("usb-wan")}}'
dashboard_order="$(awk '/id="wan-card-2"/{w2=NR} /_R\("usb-wan"\)/{u=NR} /id="mesh-card"/{m=NR} END{if(w2 && u && m && w2<u && u<m) print "ok"}' files/app/partial/wan-policy.ut)"; [ "$dashboard_order" = ok ] || fail 'dashboard source order must place Android USB tether between WAN 2 and Remote Mesh WAN'
reject_text files/app/partial/usb-wan.ut 'WAN 3 is disabled. USB networking and route publication are idle.'
require_text files/app/partial/usb-wan.ut 'No USB network device detected'
require_text files/app/partial/usb-wan.ut 'Waiting for DHCP'
require_text files/app/partial/usb-wan.ut 'Upstream reachable'
require_text files/app/main/status/e/link-calibration.ut 'pollywan-scroll-dialog'
require_text files/app/main/status/e/link-calibration.ut 'pollywan-wide-page'
require_text files/app/main/status/e/link-calibration.ut 'hx-swap="outerHTML show:none"'
require_text files/app/main/status/e/link-calibration.ut 'hx-target="#link-calibration-dialog"'
require_text files/app/main/status/e/link-calibration.ut 'hx-select="#link-calibration-dialog"'
require_text files/app/main/status/e/link-calibration.ut 'speedPage.scrollTop = savedScroll'
reject_text files/app/main/status/e/link-calibration.ut 'hx-target="#ctrl-modal" hx-swap="innerHTML show:none"'
require_text files/app/partial/multiwan-style.ut '.pollywan-scroll-dialog'
require_text files/app/partial/multiwan-style.ut 'overflow-y: auto'
require_text files/app/partial/multiwan-style.ut 'min-height: 0'
reject_text files/app/partial/multiwan-style.ut 'overflow: hidden'
reject_text files/app/partial/multiwan-style.ut 'height: 1200px'
for file in files/app/partial/wan-policy.ut files/app/partial/ethernet-ports.ut files/app/partial/usb-wan.ut files/app/partial/link-calibration.ut; do
    require_text "$file" 'hx-target="#ctrl-modal"'
    require_text "$file" 'hx-swap="innerHTML"'
done

# Documentation and two-repository contract.
require_text README.md '`wan` — WAN 1'
require_text README.md '`wan3` — Android USB tether'
require_text README.md 'http://NODE/cgi-bin/apps/aredn-multiwan/status.json'
require_text README.md 'schema version 1'
require_text docs/port-roles-and-gps.md 'GPS safety contract'
require_text docs/port-roles-and-gps.md 'radio0_mode=wan'
require_text docs/port-roles-and-gps.md '/dev/ttyACM0'
require_text docs/multiwan-usb-wan.md 'RNDIS, CDC Ethernet, or CDC NCM'
require_text docs/multiwan-usb-wan.md 'USB charging alone is insufficient'
require_text docs/multiwan-link-calibration.md 'Health is not speed'
require_text docs/multiwan-link-calibration.md 'AREDN node-to-node testing'
require_text docs/multiwan-link-calibration.md 'Cloudflare uses Anycast routing'
require_text docs/multiwan-link-calibration.md 'wan-speed-test route-check wan'
require_text docs/port-roles-and-gps.md 'PR #2816'
require_text docs/port-roles-and-gps.md 'PR #2817'
require_text docs/port-roles-and-gps.md 'configured RF VLAN must not be 2, 3, 4, or 5'
require_text docs/multiwan-mesh-wan.md 'table 101'
require_text docs/multiwan-mesh-wan.md 'table 22'
require_text docs/multiwan-mesh-wan.md 'protocol-`boot`'
require_text docs/multiwan-verification.md 'Disabled-install, radio, and GPS test'
require_text docs/multiwan-verification.md 'Wi-Fi WAN ownership'
require_text docs/multiwan-verification.md 'br-wifi'
require_text docs/multiwan-verification.md 'br-fast'
require_text docs/multiwan-verification.md 'PR #2817 remote forwarding gate'
require_text docs/multiwan-verification.md 'firewall zone `wifi` still contains logical networks `mesh`, `fast`, `wifi`, `wifi0`, and `wifi1`'
require_text docs/multiwan-verification.md 'WAN 3 is a dynamic `wan3` interface with `zone wan`'
require_text docs/multiwan-verification.md "wan3-manager withdraw 'test' 1"
require_text docs/aredn-sysinfo-integration-plan.md 'not implemented by the standalone r29 APK'
require_text docs/aredn-sysinfo-integration-plan.md '/tmp/sysinfo/extensions/'
require_text tools/openclaw-build-test-prompt.md 'mse-88/hub5'
require_text tools/openclaw-build-test-prompt.md 'main'
require_text tools/openclaw-build-test-prompt.md 'Wi-Fi client'
require_text tools/openclaw-build-test-prompt.md 'r29 requirements'
[ "$(wc -c < tools/openclaw-build-test-prompt.md)" -lt 2000 ] || fail 'OpenClaw prompt exceeds 2000 characters'
require_text SYNC_SOURCE 'standalone_branch=main'
require_text SYNC_SOURCE 'integration_branch=agent/pollywan-r6'
require_text SYNC_SOURCE 'sync_contract=standalone-root-equals-integration-subtree'
require_text tools/sync-integration.sh 'rsync -rnic --delete --exclude .git'

# No obsolete/broken bootstrap or older release claims.
if grep -RIn --exclude-dir=.git --exclude=SYNC_SOURCE --exclude=verify.sh -E 'source\.tar\.gz\.b64|chunk-0[0-9]|PKG_RELEASE:=(10|16|25)([^0-9]|$)|PollyWAN r(3|10|16|25)([^0-9]|$)|0\.1\.0-r(3|10|16|25)([^0-9]|$)|main contains r3([^0-9]|$)|incomplete source' . >/tmp/pollywan-stale.$$; then
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

if [ "$(id -u)" = 0 ]; then
    ./tests/mock-port-manager.sh
    ./tests/mock-route-cache.sh
    ./tests/mock-tunnel-guard.sh
elif command -v unshare >/dev/null 2>&1 && unshare -Ur true >/dev/null 2>&1; then
    unshare -Ur ./tests/mock-port-manager.sh
    unshare -Ur ./tests/mock-route-cache.sh
    unshare -Ur ./tests/mock-tunnel-guard.sh
else
    ./tests/mock-port-manager.sh
    ./tests/mock-route-cache.sh
    ./tests/mock-tunnel-guard.sh
fi
./tests/mock-mesh-exit.sh
./tests/test-selection-model.py
node tests/test-route-order-ui.js

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
for required in ['id="multiwan-page"', 'wan-card-1', 'wan-card-2', 'usb-wan', 'mesh-card']:
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

require_text "$SLA" 'hard failure or ineligible path: selected $active immediately'
require_text "$SLA" 'recovered higher-priority route; waiting for recovery confirmation'
require_text "$SLA" '[ "$best_rank" -lt "$active_rank" ]'
require_text files/usr/local/bin/wan3-manager 'function cidr_prefix'
require_text files/usr/local/bin/wan-route-cache 'function cidr_prefix'
require_text files/usr/local/bin/wan-route-cache 'connected_prefix_from_cidr "$cidr"'

python3 - <<'PY'
import json, os, subprocess
env = dict(os.environ, TELEMETRY_FILE='/tmp/pollywan-verifier-no-telemetry')
raw = subprocess.check_output(['sh', 'files/www/cgi-bin/apps/aredn-multiwan/status.json'], env=env).decode()
body = raw.split('\r\n\r\n', 1)[1]
data = json.loads(body)
assert data['schema_version'] == 1
assert data['package_version'] == '0.1.0-r29.5'
assert data['remote_mesh_exit_node'] is None
assert data['remote_mesh_exit_ip'] is None
assert data['remote_mesh_metric'] is None
PY

echo 'PollyWAN r29.5 static and mock verification passed'
