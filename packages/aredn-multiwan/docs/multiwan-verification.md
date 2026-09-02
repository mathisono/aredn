# PollyWAN r29.5 build and verification

## 1. Static source verification

```sh
./tests/verify.sh
```

The verifier checks package boundaries, executable modes, BusyBox shell syntax,
metadata/dependencies, administrator-only UI handlers, centralized verified
configuration ownership, DSA and swconfig port generation, exact pre-apply
rollback, GPS non-interference, WAN 3 network-only discovery, speed-test bounds,
routing-table ownership, Babel guards, tunnel isolation, markup, documentation,
and repository-sync metadata.

Static success is not an APK build or physical-node pass.

## 2. Package-only build

In the AREDN integration checkout:

```sh
make openwrt-clean
make feeds-update

# hAP ac2/ac3
make MAINTARGET=ipq40xx SUBTARGET=mikrotik prepare
# hAP ac lite
make MAINTARGET=ath79 SUBTARGET=mikrotik prepare

grep '^CONFIG_PACKAGE_aredn-multiwan=m$' openwrt/.config
make -C openwrt package/aredn-multiwan/clean V=sc -j1
make -C openwrt package/aredn-multiwan/compile V=sc -j1 2>&1 | tee /tmp/pollywan-r29.5-build.log
find openwrt/bin -name 'aredn-multiwan-0.1.0.29.5-r10.apk' -print -exec sha256sum {} \;
```

If matching kernel-module APKs are unavailable, build the full exact target. Never mix architecture, firmware, or kernel ABI.

## 3. Disabled-install, radio, and GPS test

Before installation record:

```sh
mkdir -p /tmp/pollywan-before
uci -q show aredn > /tmp/pollywan-before/aredn.runtime
uci -c /etc/config.mesh -q show aredn > /tmp/pollywan-before/aredn.mesh
uci -c /etc/config.mesh -q show setup > /tmp/pollywan-before/setup.mesh
uci -q show gpsd > /tmp/pollywan-before/gpsd.runtime 2>/dev/null || true
uci -c /etc/config.mesh -q show gpsd > /tmp/pollywan-before/gpsd.mesh 2>/dev/null || true
ls -l /dev/ttyACM0 /dev/ttyUSB0 > /tmp/pollywan-before/gps.devices 2>&1 || true
pidof gpsd > /tmp/pollywan-before/gpsd.pid 2>/dev/null || true
ubus call network.interface.wan status > /tmp/pollywan-before/wan.status 2>/dev/null || true
ubus call network.wireless status > /tmp/pollywan-before/wireless.status 2>/dev/null || true
ip -4 rule show > /tmp/pollywan-before/rules4
ip -6 rule show > /tmp/pollywan-before/rules6
for t in 22 26 27 28 99 101 102 103; do ip -4 route show table "$t" > "/tmp/pollywan-before/table.$t"; done
ip -4 route show table main > /tmp/pollywan-before/main
```

Install without enabling:

```sh
apk add --allow-untrusted /tmp/aredn-multiwan-0.1.0.29.5-r10.apk
[ "$(uci -c /etc/config.mesh get aredn.multiwan.enabled)" = 0 ]
[ "$(uci -c /etc/config.mesh get aredn.multiwan.port_roles_enabled)" = 0 ]
[ "$(uci -c /etc/config.mesh get aredn.multiwan.wan3_enable)" = 0 ]
```

Confirm there is no managed port marker, `wan3`, package route/rule state, radio-mode change, or GPS difference. Only the new `aredn.multiwan` UCI section is expected.

## 4. Wi-Fi WAN ownership test

Record AREDN radio modes:

```sh
uci -c /etc/config.mesh -q get setup.globals.radio0_mode || true
uci -c /etc/config.mesh -q get setup.globals.radio1_mode || true
/usr/local/bin/wan-port-manager wan-transport
ubus call network.interface.wan status
```

Expected ownership:

```text
radio0_mode=wan → wifi:wlan0 → logical wan → table 101
radio1_mode=wan → wifi:wlan1 → logical wan → table 101
neither WAN     → ethernet:br-wan → logical wan → table 101
```

Prove:

- both radios in WAN mode are rejected
- an Ethernet WAN-1 port is rejected while Wi-Fi owns `wan`
- the generated bridge/switch configuration omits Ethernet VLAN 4 and `wan.network.user` while Wi-Fi owns `wan`
- mesh AP/PTP/station radios remain on AREDN's `br-wifi`/RF VLAN path and are not local WAN candidates
- `br-fast` is not written by PollyWAN and is not treated as a WAN
- firewall zone `wifi` still contains logical networks `mesh`, `fast`, `wifi`, `wifi0`, and `wifi1`
- firewall zone `wan` contains `wan`, plus `wan2` when enabled; WAN 3 is a dynamic `wan3` interface with `zone wan`
- PollyWAN never adds `wifi` or `fast` to the WAN firewall zone
- a configured RF VLAN of 2, 3, 4, or 5 is rejected before PollyWAN writes role include files
- WAN 2 remains available on Ethernet
- PollyWAN never changes either radio mode
- switching AREDN radio ownership after roles were applied produces an attention state rather than a silent port remap

## 5. Ethernet role and rollback test

Test the advanced-Ports-style UI on all three models. When Wi-Fi does not own WAN 1, an example layout is:

```text
Port 1: WAN 1 cellular
Port 2: WAN 2 Starlink
Ports 3–4: LAN
Port 5: disabled untagged + DtD VLAN 2 tagged
USB: WAN 3
```

When Wi-Fi owns WAN 1:

```text
AREDN radio: WAN 1
Port 1: WAN 2
Ports 2–4: LAN
Port 5: disabled untagged + DtD VLAN 2 tagged
USB: WAN 3
```

Apply, reconnect, inspect all logical interfaces, and confirm with the token.
Then edit a confirmed managed layout, allow the second apply to time
out, and prove that its exact preceding managed files and port-role UCI values
and XLink file return. Finally disable PollyWAN and prove that `enabled` and
`port_roles_enabled` become `0` while the saved `wan2_enable` and `wan3_enable`
candidate choices remain unchanged. Inspect `swconfig` on hAP ac lite.

## 5a. GUI persistence and ownership

For Route Policy, Ethernet Roles, USB device selection, and Connection Speed
Test settings:

1. save a non-default value;
2. confirm that the success message says the value was verified;
3. close and reopen the dialog;
4. verify the exact value with `uci -c /etc/config.mesh get`;
5. force a mocked set, commit, and read-back failure and confirm that each is
   displayed as an error, preceding values are restored, and no apply/restart
   begins;
6. create an unrelated pending AREDN change and confirm PollyWAN refuses Apply
   until it is committed or reverted;
7. after a successful Apply, select Cancel and confirm it cannot restore a stale
   pre-Apply modal snapshot or create an AREDN-wide pending-change banner.

Confirm that only Route Policy Setup can write `wan_enable`, `wan2_enable`,
`wan3_enable`, and `mesh_enable`; only Ports & XLinks can write port assignments
and XLinks; only the USB dialog can write
`wan3_device`; and only Connection Speed Test can write speed-test settings.
Confirm that the Ports page exposes no ownership checkbox and that its internal
`port_roles_enabled` value follows the Route Policy master enable.

For the RapidConfig/reboot path, persist a complete valid role set with
`enabled=1` while no managed marker exists, restart
`wan3-manager`, and prove that reconciliation creates the marker and reports
`ready`. Repeat with an invalid no-LAN role set and prove that reconciliation
returns an error, leaves AREDN files active, and verifies the flag was reset to
`0`. During a timed apply, remove the temporary token as a reboot would while
leaving `/etc/aredn-multiwan-backup/pending`; the next reconcile must restore
the exact pre-apply files, XLinks, and UCI values and remove the completed
snapshot. Separately enable from the GUI, restart the service during its live
confirmation window, and prove the restart neither auto-confirms nor discards
the rollback token.

## 6. Candidate-private routing

```sh
/usr/local/bin/wan-route-cache all
ip -4 rule show | grep -E '^(81|82|83):'
ip -4 route show table 101
ip -4 route show table 102
ip -4 route show table 103
```

Each source-bound health or speed-test request must stay in its private table. When WAN 1 is Wi-Fi, table 101 must use the same `wlan0`/`wlan1` reported by `network.interface.wan`.

## 7. Speed tests and classes

Save an administrator-selected HTTPS range object. Reject HTTP, credentials, fragments, whitespace, custom ports, missing paths, redirects, non-206, and short responses.

```sh
/usr/local/bin/wan-speed-test route-check wan
/usr/local/bin/wan-speed-test test wan cloudflare 1000000
/usr/local/bin/wan-speed-test test wan2 cloudflare 1000000
/usr/local/bin/wan-speed-test test wan3 cloudflare 1000000   # only when configured
```

Confirm route proof, bounded payloads, global lock, source/gateway binding, Cloudflare colo parsing, iperf3 node-name validation, and low/medium/fast thresholds. Changing Wi-Fi DHCP address or gateway must make the `wan` result stale.

## 7a. PR #2817 remote forwarding gate

With Mesh to WAN enabled and a selected healthy local WAN, verify a remote mesh node connected through RF can actually forward Internet traffic through `br-wifi`, not merely learn a Babel default:

```sh
# local gateway node
uci -q show firewall | grep -E "zone.*name='(wifi|wan)'|network"
ip -4 route show table 28
/usr/local/bin/wan3-manager status

# remote RF node
ip -4 route get 1.1.1.1
curl --max-time 10 --proxy '' https://connectivitycheck.gstatic.com/generate_204 -o /dev/null -w '%{http_code}\n'
```

Force an upstream-health failure or run `wan3-manager withdraw 'test' 1` on the gateway and confirm the remote curl fails immediately after table 28 is withdrawn. Restore a healthy selected local WAN, wait for `mesh_export_recover_count` and `mesh_export_hold_down`, then confirm the remote curl succeeds again.

## 8. Ordered route failover

Test:

1. each of WAN 1, WAN 2, USB, and Remote Mesh WAN in every priority slot
2. disabled routes being skipped without changing the configured order
3. A → B → C immediate downward failover
4. C → B → A recovery using `promote_count` and `hold_down`
5. standby probe failure preventing recovery
6. active application failure hysteresis
7. stale or missing speed results at each minimum allowable data-rate setting
8. no local route meeting `selection_min_bin`
9. Wi-Fi WAN disconnect/reconnect
10. enabled and disabled table-22 Remote Mesh WAN
11. selected local route below `mesh_share_min_bin`

Inspect `/usr/local/bin/wan-sla status`, `/usr/local/bin/wan3-manager status`, and tables after each transition.

## 9. Route transaction and Babel

```sh
ip -4 route show table 22
ip -4 route show table 26
ip -4 route show table 27
ip -4 route show table 28
ip -4 route show table main default
cat /etc/aredn_include/babel-deny.conf
```

Expected:

- table 26 = selected local default
- table 27 = selected local connected subnet
- table 28 = one protocol-static default only when Mesh to WAN is enabled and the selected bin meets `mesh_share_min_bin`
- table 22 is untouched
- a WAN netifd event immediately withdraws table 28
- `redistribute proto 3 ... deny` closes the stock protocol-boot race
- route failure restores the previous main/26/27/28 snapshot
- no eligible local WAN leaves 26/27/28 empty, allowing table-22 fallback only through AREDN policy

## 10. Tunnel isolation

For every `wg*` and `tun*` interface, verify IPv4 and IPv6 preference 45 look up table 99. AREDN mesh route preferences 10/20/30 remain usable, but tunnel ingress cannot reach tables 26, 28, 22, or a main Internet default. Babel may learn an incoming IPv4 default into table 22 for this node's Remote Mesh WAN candidate, but it must not advertise IPv4 or IPv6 defaults back out a tunnel.

## 11. Android USB tether

With a phone physically tethered and WAN 3 active, verify:

- `wan3` is a USB-backed network device with DHCP and table 103
- RNDIS, CDC Ethernet, and CDC NCM detection paths remain covered
- Android supplies an IPv4 address and gateway
- health uses direct gateway and source-bound HTTPS checks
- Cloudflare WAN 3 tests use `curl --interface "$SOURCE" --proxy ''`
- WAN 3 can be selected and deselected
- disabling USB tethering falls back safely
- re-enabling tethering recovers
- reboot preserves disabled/enabled configuration without changing GPS ownership

## 12. Removal and evidence

```sh
apk del aredn-multiwan
```

Verify previous AREDN include files and roles are restored, normal Ethernet or Wi-Fi WAN 1 returns, WAN 3/package tables/rules/guards/UI are removed, and GPS/radio state remains unchanged.

Collect Git SHAs, subtree sync result, APK/dependency checksums, build logs, exact ABI, before/after GPS/radio snapshots, role/rollback evidence, route/rule dumps, calibration/SLA JSON, Babel/tunnel/Android USB tests, and uninstall results. Do not mark r29 ready until package build and physical target gates pass.
