# AREDN PollyWAN

PollyWAN is an experimental installable package for the MikroTik hAP ac lite, hAP ac2, and hAP ac3. It adds a native AREDN dashboard for managing multiple local Internet connections while leaving the base AREDN image unchanged.

PollyWAN is disabled and inert immediately after installation. It does not remap ports, change radio modes, scan USB devices, start WAN3, edit GPS settings, or publish a Mesh WAN default until an administrator explicitly enables those features.

PollyWAN is experimental and is not an official AREDN release.

## Features

- manages WAN1, WAN2, and optional WAN3 as local Internet candidates
- keeps the Babel-learned remote Mesh WAN as the fallback in table 22
- passively ranks up to five Babel-advertised Mesh WAN exits without changing selection
- separates lightweight health checks from occasional throughput tests
- offers one explicit ordered route policy with deterministic failover
- supports AREDN node-to-node iperf3 and Cloudflare Internet-path tests
- assigns hAP Ethernet roles with timed rollback and confirmation
- supports optional Android USB tethering for WAN3
- blocks traffic arriving from tunnels from using Internet defaults while allowing this node to learn a remote Mesh WAN default

## Supported hardware

- MikroTik hAP ac lite
- MikroTik hAP ac2
- MikroTik hAP ac3

The current R29.5 test package uses APK version `0.1.0.29.5-r11`. APK reserves
`-rN` for its integer package revision, so the product release is represented
as dotted `PKG_VERSION` components and the package revision is `r11`. The latest
published GitHub release remains `0.1.0-r29` until R29.5 validation is complete.

## Release files

- `wan` — WAN 1. When an AREDN radio is in client/WAN mode, the existing logical interface `wan` uses `wlan0` or `wlan1`. Otherwise WAN 1 uses administrator-selected hAP Ethernet port(s).
- `wan2` — WAN 2 on administrator-selected Ethernet port(s).
- `wan3` — Android USB tether using RNDIS, CDC Ethernet, or CDC NCM when existing kernel USB-network support is available.
- Remote Mesh WAN remains the Babel-learned default in table 22. It is an
  opt-in ordered route candidate, but it is never treated as a local WAN or
  copied into table 28.

Wi-Fi WAN and Ethernet WAN 1 are mutually exclusive because AREDN gives both the same logical interface name, `wan`. PollyWAN never changes a radio mode; it observes AREDN's existing configuration and prevents an Ethernet WAN-1 assignment while Wi-Fi owns `wan`.

Mesh AP/PTP/station radios are not WAN candidates. On AREDN builds with the shared RF bridge, they remain on AREDN's `br-wifi` path and AREDN's `wifi` firewall zone. PollyWAN never moves logical networks `wifi` or `fast` into the WAN zone, and any configured RF VLAN must avoid PollyWAN's Ethernet VLANs 2, 3, 4, and 5.

## Install From a GitHub Release

Download the APK for the matching PollyWAN release from:

```text
https://github.com/mathisono/AREDN_PollyWAN/releases/tag/v0.1.0-r29
```

### Core PollyWAN APK

```text
aredn-multiwan-0.1.0-r29.apk
SHA-256: 8c4893d48e0b9af3d4bef0a14d5c0ed28f6ebe98677d29e7a527f8194e705e23
```

The core APK provides WAN1 and WAN2 without the optional USB-driver bundle. On the tested AREDN 4.26.7.0 hAP ac2 image, it installs offline as a single local APK with no dependency downloads.

### Optional WAN3 USB-driver bundle

```text
pollywan-usb-drivers-aredn-4.26.7.0-hap-ac2-k6.12.94.zip
SHA-256: a3c5b8e7f9d2c4e1a6b3d7f5c9a2e1b4f6d8c7e3b9a0c4d5f1e7b2a1f3c4d5
```

> **Compatibility warning:** This bundle is only for AREDN 4.26.7.0 on a MikroTik hAP ac2 running kernel 6.12.94 with the exact kernel ABI listed in its manifest. Do not install it on another firmware version, board, architecture, or kernel.

The optional bundle is required only when the installed AREDN firmware does not already provide compatible Android USB-network drivers. WAN1 and WAN2 remain fully usable without it.

Verify downloaded release files with `SHA256SUMS-release.txt`.

## Install the core APK

### Recommended: AREDN web interface

1. Download `aredn-multiwan-0.1.0-r29.apk` to your computer.
2. Log in to the AREDN node as an administrator.
3. Open **Packages**.
4. Under **Upload Package**, choose the PollyWAN APK.
5. Select **Fetch and Install**.
6. Wait for **Package installed** before closing the dialog.
7. Refresh the browser and open:

```text
http://NODE/a/multiwan
```

Release r29 declares `ca-bundle`, `curl`, `jshn`, and `jsonfilter`. `libc` is provided by the base system. It does not declare `ip-tiny`, `redsocks`, `libevent2-core7`, `nftables-json`, or `kmod-nft-nat`.

PollyWAN remains disabled after installation. Installing the APK alone does not reload networking or apply Ethernet port roles.

If the page does not appear after refreshing, restart only the web interface from SSH:

```sh
/etc/init.d/uhttpd restart
```

Do not run `node-setup`, reload networking, or apply port roles merely to finish package installation.

### SSH installation alternative

```sh
ssh root@NODE
cd /tmp

VERSION='0.1.0-r29'
TAG="v${VERSION}"
APK="aredn-multiwan-${VERSION}.apk"

curl -fL --retry 3 \
  -o "$APK" \
  "https://github.com/mathisono/AREDN_PollyWAN/releases/download/${TAG}/${APK}"

sha256sum "$APK"

apk add --simulate --no-network --allow-untrusted \
  "$APK"

apk add --no-network --allow-untrusted \
  "$APK"

/etc/init.d/uhttpd restart
```

Compare the SHA-256 value with `SHA256SUMS-release.txt` before installing.

### Upgrade

Use the same **Packages** → **Upload Package** workflow and select the newer APK. A normal upgrade preserves PollyWAN UCI configuration and confirmed Ethernet-port roles.

## First-time setup

1. Open the PollyWAN dashboard.
2. Open **Ports & XLinks**, assign each Ethernet port, and select **Apply**.
   While PollyWAN is disabled this saves and verifies the future layout without
   taking over the live AREDN ports.
3. Open **Route Policy Setup**, enable the allowed routes, arrange all four
   choices from first preference through last resort, and select **Apply**.
4. Reconnect through a known-good LAN or mesh path.
5. Open **Ports & XLinks** and select **Confirm** before the rollback timer
   expires. A timeout restores the disabled master state and exact prior port
   and XLink configuration.
6. Run speed tests only after health checks show the WANs are working.

Keep at least one LAN or mesh management path available while changing Ethernet roles.

Configuration ownership is intentionally non-overlapping: Route Policy Setup
owns the controller and all WAN candidate enable flags; Ethernet Ports owns the
port/DtD and XLink assignments; Android USB tether owns only
the USB network-device selection; Connection Speed Test owns only its test
settings. Every dialog uses the same persistent writer and reports an error
unless all submitted values match after the `/etc/config.mesh` commit.

## Local WAN candidates

- `wan` — WAN 1. Uses AREDN Wi-Fi client mode when a radio owns logical interface `wan`; otherwise it uses administrator-selected Ethernet ports.
- `wan2` — WAN2 on administrator-selected Ethernet ports.
- `wan3` — Android USB tether; optional Android USB-tethered Ethernet using RNDIS, CDC Ethernet, or CDC NCM.
- Remote Mesh WAN — the Babel-learned default in table 22. R29.5 exposes it as
  an enabled route and an ordered failover choice, while Babel continues to own
  the remote gateway.

Wi-Fi WAN and Ethernet WAN1 are mutually exclusive because AREDN assigns both the logical interface name `wan`. PollyWAN observes the existing radio configuration and does not change radio modes.

## Ordered route policy (R29.5)

Route Policy Setup provides four explicit priority slots covering WAN 1, WAN 2,
Android USB tether, and Remote Mesh WAN. PollyWAN uses the first enabled,
eligible route. It fails downward immediately after the configured failure
threshold and returns upward only after the recovered route passes the success
count and hold-down. This produces deterministic A → B → C failover and
C → B → A recovery.

Health and speed are separate. Health checks decide whether a local WAN is
usable. An optional minimum allowable local data rate can make a measured local
route ineligible, but speed never reorders the configured priorities. Remote
Mesh WAN eligibility is based on the presence of an AREDN/Babel table-22
default, not a local speed test.

The dashboard also has a passive Mesh WAN Exit Ranking tile. It lists at most
five distinct Babel default-route originators, sorts them by the total Babel
metric observed at this node, and links a known node name to its AREDN page.
The displayed Babel RTT is the already-known next-hop-neighbor RTT, not an
end-to-end Internet measurement. Data-throughput and ping-quality fields remain
`Not sampled` in this first stage. The tile sends no probe traffic and cannot
change PollyWAN's configured order, eligibility, or selected WAN.

Gateway reachability is diagnostic only. A local gateway that responds to ICMP does not make a WAN healthy unless the source-bound external HTTPS health check also succeeds. If the active WAN fails that raw upstream check, table 28 is withdrawn immediately so the mesh stops using the known-bad exit while local selection hysteresis decides whether to keep or replace the active path. Recovered exits are re-advertised only after the configured export recovery count and hold-down.

Default classes:

- Low: less than 5 Mbps
- Medium: 5 through 30 Mbps
- Fast: greater than 30 Mbps
- Unknown: no fresh valid measurement

The GUI presents these thresholds as Any healthy local route, at least 5 Mbps,
or at least 30 Mbps. Response-code lists remain safe package defaults and are
not operator-facing fields.

## Connection speed tests

Open **Connection speed test** from the PollyWAN dashboard.

### AREDN node test

Runs reverse iperf3 to another AREDN node:

```sh
iperf3 -c NODE -p PORT -t DURATION -R -J
```

This measures node-to-node throughput over the selected route. It may not represent general Internet performance.

### Cloudflare Internet test

Queries Cloudflare trace data and downloads a bounded payload:

```text
https://cloudflare.com/cdn-cgi/trace
https://speed.cloudflare.com/__down?bytes=BYTES
```

The result includes the public IP, country, Cloudflare colo, payload size, duration, Mbps, and speed class. The colo is the Anycast edge selected by BGP and ISP peering; it is not necessarily the geographically nearest facility.

Payload choices are 1 MB, 5 MB, 10 MB, and 20 MB. Routine testing defaults to 5 MB. PollyWAN never runs the full browser speed test.

Runtime results are stored under `/tmp/wan-speed/` and are cleared by reboot.

## WAN3 Android USB tethering

WAN3 uses a normal Android USB-tethered Ethernet connection. The phone supplies DHCP, a gateway, DNS, NAT, and Internet access. PollyWAN does not use PdaNet, an HTTP proxy, or a transparent proxy.

```text
Android phone
  -> data-capable USB cable
  -> RNDIS, CDC Ethernet, or CDC NCM driver
  -> USB-backed Linux network interface
  -> logical interface wan3
  -> DHCP
  -> private routing table 103
```

### Android setup

1. Use a data-capable USB cable.
2. Connect the Android phone to the hAP USB port.
3. Unlock the phone.
4. Open Android hotspot/tethering settings.
5. Enable **USB tethering**.
6. Enable WAN3 in PollyWAN.
7. Wait for an IPv4 address and gateway.
8. Verify health before selecting WAN3.

Charging alone is not sufficient. The phone must expose a USB network interface.

The interface may be named `usbnet`, `usb0`, `eth1`, `enx...`, or something else. PollyWAN inspects sysfs USB ancestry and does not require one specific interface name.

Possible WAN3 states include:

- Disabled
- Waiting for phone
- USB network driver unavailable
- USB device detected
- Requesting DHCP
- Connected

`USB network driver unavailable` does not indicate a general PollyWAN failure. WAN1 and WAN2 continue to operate normally.

### Optional hAP ac2 driver bundle

Use the optional bundle only for this exact tested platform:

```text
AREDN:        4.26.7.0
Board:        MikroTik hAP ac2
Kernel:       6.12.94
Architecture: arm_cortex-a7_neon-vfpv4
```

The bundle contains matching packages for:

- `kmod-usb-net`
- `kmod-usb-net-rndis`
- `kmod-usb-net-cdc-ether`
- `kmod-usb-net-cdc-ncm`

#### Install through the AREDN web interface

1. Download the driver ZIP to your computer.
2. Verify the ZIP against `SHA256SUMS-release.txt`.
3. Extract the ZIP. **Do not upload the ZIP itself.**
4. Read `README.txt` and `UPLOAD_ORDER.txt`.
5. Log in to the AREDN node.
6. Open **Packages**.
7. Under **Upload Package**, upload each driver APK in the order listed in `UPLOAD_ORDER.txt`.
8. Select **Fetch and Install** after choosing each APK.
9. Reboot after all required APKs install successfully.

#### Install through SSH

The extracted bundle includes `INSTALL-SSH.sh`:

```sh
cd /tmp/pollywan-usb-drivers
sha256sum -c SHA256SUMS
sh ./INSTALL-SSH.sh
```

The installer performs an offline simulation before installing the matching module APKs. It does not use forced-dependency flags and does not install a replacement `kernel-*.apk` package.

#### Verify USB support

```sh
lsmod | grep -E 'usbnet|rndis_host|cdc_ether|cdc_ncm'
/usr/local/bin/wan3-manager usb-support
```

Not every driver must appear in `lsmod`; a driver may be built in, loadable but unused, or not selected by the connected phone.

#### Remove the optional drivers

The bundle includes `UNINSTALL-SSH.sh`:

```sh
cd /tmp/pollywan-usb-drivers
sh ./UNINSTALL-SSH.sh
```

The removal process disables WAN3, removes only the companion driver APKs in reverse dependency order, and leaves PollyWAN installed. WAN1 and WAN2 remain available.

### Tested WAN3 example

The optional bundle was validated on one MikroTik hAP ac2 running AREDN 4.26.7.0 and kernel 6.12.94 with an Android phone exposing a USB-backed interface.

Observed during that test:

```text
WAN3 address:    192.168.10.57
Gateway:         192.168.10.1
Cloudflare colo: SJC
Measured result: approximately 210 Mbps with a 1 MB test
```

This is one observed result, not a performance specification or a claim of compatibility with every Android phone.

For detailed WAN3 setup and troubleshooting, see [docs/multiwan-usb-wan.md](docs/multiwan-usb-wan.md).

## Routing tables

- table 101 — WAN1 private routing table
- table 102 — WAN2 private routing table
- table 103 — WAN3 private routing table
- table 26 — selected local Internet default
- table 27 — selected local WAN connected subnet
- table 28 — qualified local default eligible for Babel export
- table 22 — remote Mesh WAN learned by Babel

Tunnel ingress is blocked from local and remote Internet defaults while PollyWAN is enabled.

## Command-line checks

```sh
/usr/local/bin/wan-port-manager wan-transport
/usr/local/bin/wan-port-manager status
/usr/local/bin/wan-port-manager gps-status
/usr/local/bin/wan-sla status
/usr/local/bin/wan3-manager status
/usr/local/bin/wan3-manager usb-support
/usr/local/bin/wan-speed-test status-all
/usr/local/bin/wan-tunnel-guard status
/usr/local/bin/wan-mesh-exits
```

Package-owned public telemetry is available at:

```text
http://NODE/cgi-bin/apps/aredn-multiwan/status.json
```

It returns schema version 1 from `/tmp/wan-sla/telemetry.json`, uses JSON `null` for unavailable scalar values, and does not run probes or modify routes. Integration into `/cgi-bin/sysinfo.json` is deferred until AREDN core accepts a reviewed hook; r29 does not replace AREDN core sysinfo files.

Run bounded speed tests from SSH:

```sh
/usr/local/bin/wan-speed-test route-check wan
/usr/local/bin/wan-speed-test test wan cloudflare 1000000
/usr/local/bin/wan-speed-test test wan2 cloudflare 1000000
/usr/local/bin/wan-speed-test test wan3 cloudflare 1000000
/usr/local/bin/wan-speed-test test-all cloudflare 5000000
/usr/local/bin/wan-speed-test test wan iperf3
```

## GPS safety

WAN3 discovery runs only after PollyWAN and WAN3 are enabled. It enumerates network devices under `/sys/class/net` and does not open `/dev/ttyACM0` or `/dev/ttyUSB0`, edit gpsd, change AREDN GPS time/location settings, change radio mode, or change USB power.

## Recovery

Disable PollyWAN routing without removing the package:

```sh
uci -c /etc/config.mesh set aredn.multiwan.enabled='0'
uci -c /etc/config.mesh commit aredn
/usr/local/bin/wan3-manager disable
/etc/init.d/wan3-manager stop
```

Restore managed Ethernet-role changes:

```sh
/usr/local/bin/wan-port-manager restore
```

Remove PollyWAN:

```sh
apk del aredn-multiwan
```

Package removal stops PollyWAN, restores managed port files, removes package-created route/rule state, and disables the service. It does not change AREDN radio mode or GPS configuration.

## Build

Vendor this repository at `packages/aredn-multiwan` in an AREDN checkout and select it as a module:

```text
CONFIG_PACKAGE_aredn-multiwan=m
```

Then run:

```sh
./tests/verify.sh
make -C openwrt package/aredn-multiwan/clean V=s
make -C openwrt package/aredn-multiwan/compile V=s
find openwrt/bin -name 'aredn-multiwan-0.1.0.29.5-r11.apk' -print -exec sha256sum {} \;
```

Static verification is not a substitute for exact kernel-ABI checks, disabled-install testing, port rollback testing, or physical hardware validation.

## Development workflow

Development is synchronized between:

- standalone package: `mathisono/AREDN_PollyWAN`
- AREDN integration repository: `mathisono/aredn`
- integration path: `packages/aredn-multiwan`

Use:

```sh
tools/sync-integration.sh check /path/to/aredn
tools/sync-integration.sh apply /path/to/aredn
```

## Documentation

Start with [docs/README.md](docs/README.md). Additional verification procedures are in [docs/multiwan-verification.md](docs/multiwan-verification.md), and the upstream USB-driver plan is in [docs/aredn-usb-network-upstream-plan.md](docs/aredn-usb-network-upstream-plan.md).

See `LICENSE` and `AREDNLicense.txt` for licensing and AREDN attribution requirements.
