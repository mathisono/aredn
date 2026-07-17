# PollyWAN r16 build and verification

## 1. Static source verification

```sh
./tests/verify.sh
```

The verifier checks package boundaries, executable modes, BusyBox shell syntax, r10 metadata/dependencies, administrator-only UI handlers, DSA and swconfig port generation, Wi-Fi WAN ownership, rollback, GPS non-interference, WAN 3 network-only discovery, calibration bounds, routing-table ownership, Babel guards, tunnel isolation, markup, documentation, and repository-sync metadata.

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
make -C openwrt package/aredn-multiwan/compile V=sc -j1 2>&1 | tee /tmp/pollywan-r16-build.log
find openwrt/bin -name 'aredn-multiwan-0.1.0-r16.apk' -print -exec sha256sum {} \;
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
nft list ruleset > /tmp/pollywan-before/nft
```

Install without enabling:

```sh
apk add --allow-untrusted /tmp/aredn-multiwan-0.1.0-r16.apk
[ "$(uci -c /etc/config.mesh get aredn.multiwan.enabled)" = 0 ]
[ "$(uci -c /etc/config.mesh get aredn.multiwan.port_roles_enabled)" = 0 ]
[ "$(uci -c /etc/config.mesh get aredn.multiwan.wan3_enable)" = 0 ]
```

Confirm there is no managed port marker, `wan3`, redsocks PID, proxy nftables table, package route/rule state, radio-mode change, or GPS difference. Only the new `aredn.multiwan` UCI section is expected.

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

Apply with rollback, reconnect, inspect all logical interfaces, and confirm with the token. Also allow one deliberate management-breaking configuration to time out and prove restoration. Inspect `swconfig` on hAP ac lite.

## 6. Candidate-private routing

```sh
/usr/local/bin/wan-route-cache all
ip -4 rule show | grep -E '^(81|82|83):'
ip -4 route show table 101
ip -4 route show table 102
ip -4 route show table 103
```

Each source-bound health/calibration request must stay in its private table. When WAN 1 is Wi-Fi, table 101 must use the same `wlan0`/`wlan1` reported by `network.interface.wan`.

## 7. Calibration object and bins

Save an administrator-selected HTTPS range object. Reject HTTP, credentials, fragments, whitespace, custom ports, missing paths, redirects, non-206, and short responses.

```sh
/usr/local/bin/wan-calibrate wan manual
/usr/local/bin/wan-calibrate wan2 manual
/usr/local/bin/wan-calibrate wan3 manual   # only when configured
```

Confirm 1/8/32 MiB progression, maximum approximately 41 MiB, exact bytes, cooldown, global lock, source/gateway binding, manual/automatic trigger, and low/medium/fast thresholds. Changing Wi-Fi DHCP address or gateway must make the `wan` result stale.

## 8. Adaptive rotation

Test:

1. different healthy bins
2. equal bins and preferred-WAN ties
3. standby probe failure preventing promotion
4. immediate hard interface demotion
5. active application failure hysteresis
6. `promote_count`
7. `hold_down`
8. stale calibration
9. no local candidate meeting `selection_min_bin`
10. Wi-Fi WAN disconnect/reconnect
11. explicit table-22 fallback
12. selected link below `mesh_share_min_bin`

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
- route/proxy failure restores the previous main/26/27/28 snapshot
- no eligible local WAN leaves 26/27/28 empty, allowing table-22 fallback only through AREDN policy

## 10. Tunnel isolation

For every `wg*` and `tun*` interface, verify IPv4 and IPv6 preference 45 look up table 99. AREDN mesh route preferences 10/20/30 remain usable, but tunnel ingress cannot reach tables 26, 28, 22, or a main Internet default. Babel must neither learn nor advertise IPv4/IPv6 defaults on a tunnel.

## 11. PdaNet

With a phone physically tethered and WAN 3 active, verify:

- `wan3` is a USB-backed network device with DHCP and table 103
- proxy address/port/credentials are stored on the hAP
- LAN/node TCP is proxied
- proxy recursion and private/mesh/44Net destinations are excluded
- WAN1/2 source-bound probes bypass transparent proxying
- RF/DtD/xlink ingress is included only while table 28 is published
- tunnel ingress is never proxied
- UDP/443 fallback and cleanup work as documented

## 12. Removal and evidence

```sh
apk del aredn-multiwan
```

Verify previous AREDN include files and roles are restored, normal Ethernet or Wi-Fi WAN 1 returns, WAN 3/proxy/package tables/rules/guards/UI are removed, and GPS/radio state remains unchanged.

Collect Git SHAs, subtree sync result, APK/dependency checksums, build logs, exact ABI, before/after GPS/radio snapshots, role/rollback evidence, route/rule dumps, calibration/SLA JSON, Babel/tunnel/PdaNet tests, and uninstall results. Do not mark r10 ready until package build and physical target gates pass.
