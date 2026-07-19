# AREDN PollyWAN

PollyWAN is an experimental installable package for the MikroTik hAP ac lite, hAP ac2, and hAP ac3. It adds a native AREDN web dashboard for managing up to three local Internet candidates while leaving the base AREDN image unchanged.

PollyWAN is disabled and inert immediately after installation. It does not remap ports, change radio modes, scan USB devices, start WAN 3, edit GPS settings, or publish a Mesh WAN default until an administrator explicitly enables those features.

## What PollyWAN Does

- manages WAN 1, WAN 2, and optional WAN 3 as local Internet candidates
- keeps the remote Mesh WAN as the normal Babel-learned fallback in table 22
- separates lightweight health checks from occasional throughput tests
- offers only two selection modes: Manual and Automatic
- provides bounded speed tests using either AREDN node-to-node iperf3 or Cloudflare Internet-path testing
- assigns hAP Ethernet roles with an explicit timed rollback and confirmation step
- supports optional WAN 3 phone USB tethering and hAP-side PdaNet HTTP CONNECT settings
- hard-blocks tunnel ingress from local and remote Internet defaults

PollyWAN is experimental and is not an official AREDN release.

## Supported Hardware

- MikroTik hAP ac lite
- MikroTik hAP ac2
- MikroTik hAP ac3

The current package release is `0.1.0-r26`.

## Local candidates

- `wan` — WAN 1. When an AREDN radio is in client/WAN mode, the existing logical interface `wan` uses `wlan0` or `wlan1`. Otherwise WAN 1 uses administrator-selected hAP Ethernet port(s).
- `wan2` — WAN 2 on administrator-selected Ethernet port(s).
- `wan3` — WAN 3 fixed to a phone USB RNDIS/CDC tether when existing kernel USB-network support is available, with optional hAP-side PdaNet HTTP CONNECT settings.
- Remote Mesh WAN remains the Babel-learned default in table 22 and is never treated as a fourth local candidate.

Wi-Fi WAN and Ethernet WAN 1 are mutually exclusive because AREDN gives both the same logical interface name, `wan`. PollyWAN never changes a radio mode; it observes AREDN's existing configuration and prevents an Ethernet WAN-1 assignment while Wi-Fi owns `wan`.

## Install From GitHub Release

Download the `aredn-multiwan-0.1.0-r26.apk` asset from the latest GitHub release:

```text
https://github.com/mathisono/AREDN_PollyWAN/releases
```

Copy the APK to the AREDN node, then install it from an SSH session:

```sh
scp aredn-multiwan-0.1.0-r26.apk root@NODE:/tmp/
ssh root@NODE
apk add --allow-untrusted /tmp/aredn-multiwan-0.1.0-r26.apk
/etc/init.d/wan3-manager restart
/etc/init.d/uhttpd restart
```

Replace `NODE` with the node hostname or IP address. The install should add the PollyWAN UI without changing the active network configuration. Restarting `uhttpd` reloads AREDN's cached UI templates.

After installation, open:

```text
http://NODE/a/multiwan
```

The page is also reachable from the package app entry:

```text
http://NODE/cgi-bin/apps/aredn-multiwan/admin
```

## First-Time Setup

1. Open the PollyWAN page in the AREDN web UI.
2. Review the status cards for WAN 1, WAN 2, WAN 3 USB, remote Mesh WAN, route policy, Ethernet ports, and speed-test results.
3. Open **WAN policy** and choose **Manual** or **Automatic**.
4. Choose the preferred connection.
5. Enable only the WAN candidates you actually intend to use.
6. If using Ethernet WAN roles, open **Ethernet ports**, assign port roles, then use **Apply with rollback**.
7. Reconnect through a known-good LAN or mesh path and select **Confirm working** before the rollback timer expires.
8. If using WAN 3, open **USB WAN** and configure the phone tether and optional PdaNet proxy settings.
9. Use **Connection speed test** only after the basic health status is correct.

Keep at least one LAN or mesh management path available when changing port roles. Installation alone is safe, but applying port roles intentionally rewrites AREDN advanced-network include files and reloads networking.

## Selection Modes

PollyWAN exposes two operator-facing modes:

- **Manual** — uses the selected connection while it is healthy. If it fails, PollyWAN immediately selects the best healthy fallback. It does not automatically return to the original preferred connection unless the operator chooses it again or enables the advanced return option.
- **Automatic** — ranks only healthy WANs by the newest valid speed class: Fast, Medium, Low, or Unknown. Same-class Mbps differences do not cause switching. A higher class requires consecutive observations before promotion, while a failed current WAN is replaced immediately.

Health and speed are separate. Health checks decide whether a WAN is usable. Speed tests only classify healthy WANs for Automatic ranking. A failed or expired speed test never marks an otherwise healthy WAN down.

Default classes:

- Low: less than 5 Mbps
- Medium: 5 through 30 Mbps
- Fast: greater than 30 Mbps
- Unknown: no fresh valid measurement

- private candidate tables: 101 (`wan`), 102 (`wan2`), 103 (`wan3`)
- table 26: selected local Internet default
- table 27: selected local WAN connected subnet
- table 28: qualified local default eligible for Babel export
- table 22: remote Mesh WAN learned by Babel and left untouched

Tunnel ingress is hard-blocked from local and remote Internet defaults while PollyWAN is enabled. A protocol-boot default is denied from Babel so only the package-qualified protocol-static table-28 route can be advertised.

## Connection Speed Tests

Open **Connection speed test** from the PollyWAN dashboard.

### AREDN Node Test

This method runs reverse iperf3 to a remote AREDN node:

```sh
iperf3 -c NODE -p PORT -t DURATION -R -J
```

Use it when the remote AREDN node already runs an iperf3 server. PollyWAN validates the node name, route, source address, expected WAN path, JSON result, byte count, and active WAN stability before accepting the measurement.

This test measures throughput between two AREDN nodes over the selected path. It may not represent general Internet performance.

### Internet Test - Cloudflare

This method first reads Cloudflare trace data, then downloads a bounded payload from Cloudflare speed:

```text
https://cloudflare.com/cdn-cgi/trace
https://speed.cloudflare.com/__down?bytes=BYTES
```

The result records public IP, country, Cloudflare colo, payload size, duration, Mbps, and speed class. Cloudflare uses Anycast routing, so the displayed colo is the edge selected by BGP and ISP peering, not necessarily the geographically nearest location.

Manual payload choices are 1 MB, 5 MB, 10 MB, and 20 MB. Routine testing defaults to 5 MB. PollyWAN never runs the full browser speed test.

Runtime speed results are stored under `/tmp/wan-speed/` and are cleared by reboot. Configuration stays in UCI.

## Command-Line Checks

Useful status commands on the node:

```sh
/usr/local/bin/wan-port-manager wan-transport
/usr/local/bin/wan-port-manager status
/usr/local/bin/wan-port-manager gps-status
/usr/local/bin/wan-sla status
/usr/local/bin/wan3-manager status
/usr/local/bin/wan-speed-test status-all
/usr/local/bin/wan-tunnel-guard status
```

Run bounded speed tests from SSH:

```sh
/usr/local/bin/wan-speed-test route-check wan
/usr/local/bin/wan-speed-test test wan cloudflare 1000000
/usr/local/bin/wan-speed-test test wan2 cloudflare 1000000
/usr/local/bin/wan-speed-test test-all cloudflare 5000000
/usr/local/bin/wan-speed-test test wan iperf3
/usr/local/bin/wan-speed-test clear wan
```

WAN names are `wan`, `wan2`, and `wan3`.

Inspect routing tables:

```sh
ip -4 route show table 22
ip -4 route show table 26
ip -4 route show table 27
ip -4 route show table 28
ip -4 route show table 101
ip -4 route show table 102
ip -4 route show table 103
```

## Ports, PdaNet, and GPS

The UI follows AREDN's advanced Ports layout. Each Ethernet port receives one untagged role—LAN, WAN 1, WAN 2, or disabled—and may carry tagged DtD VLAN 2. Port application is opt-in and protected by a timed rollback. WAN 1 is not offered as an Ethernet role while AREDN Wi-Fi client mode owns it.

PdaNet is expected over a data-capable USB cable into the hAP USB host. The hAP obtains `wan3` DHCP on an existing RNDIS/CDC kernel network interface and uses the proxy address, port, and optional credentials entered by the administrator. PollyWAN does not install or replace USB kernel modules; unsupported kernels leave WAN 3 down without route or firewall changes.

A disabled installation does not remap ports, change radio modes, scan USB, open serial GPS devices, edit gpsd, change AREDN GPS time/location settings, or change USB power. WAN 3 scans only `/sys/class/net` after explicit enablement; `/dev/ttyACM0` and `/dev/ttyUSB0` remain owned by AREDN/gpsd.

## Recovery

Disable PollyWAN routing without removing the package:

```sh
uci -c /etc/config.mesh set aredn.multiwan.enabled='0'
uci -c /etc/config.mesh commit aredn
/usr/local/bin/wan3-manager disable
/etc/init.d/wan3-manager stop
```

Restore Ethernet port-role changes from the package backup:

```sh
/usr/local/bin/wan-port-manager restore
```

Remove the package:

```sh
apk del aredn-multiwan
```

Package removal stops PollyWAN, restores managed port files, removes package route/rule state, and disables the service. It does not change AREDN radio mode or GPS configuration.

## Build

Vendor this repository at `packages/aredn-multiwan` in the AREDN checkout and select it as a module:

```sh
CONFIG_PACKAGE_aredn-multiwan=m
```

Then run:

```sh
./tests/verify.sh
make -C openwrt package/aredn-multiwan/clean V=s
make -C openwrt package/aredn-multiwan/compile V=s
find openwrt/bin -name 'aredn-multiwan-0.1.0-r26.apk' -print -exec sha256sum {} \;
```

A successful static verifier is not a substitute for the package build, exact kernel-ABI dependency check, disabled-install GPS test, port rollback test, or physical hAP validation described in [docs/multiwan-verification.md](docs/multiwan-verification.md).

## Two-repository workflow

Development is synchronized between:

- standalone package: `mathisono/AREDN_PollyWAN:agent/pollywan-r6`
- AREDN integration branch: `mathisono/aredn:agent/pollywan-r6`
- integration path: `packages/aredn-multiwan`

The standalone root must match the integration subtree byte-for-byte, excluding Git metadata. Use:

```sh
tools/sync-integration.sh check /path/to/aredn
tools/sync-integration.sh apply /path/to/aredn
```

`SYNC_SOURCE` records the branch/path contract and deterministic content manifest.

## Documentation

Start with [docs/README.md](docs/README.md). The complete build and hub5 test sequence is in [tools/openclaw-build-test-prompt.md](tools/openclaw-build-test-prompt.md).

PollyWAN is experimental and is not an official AREDN release. See `LICENSE` and `AREDNLicense.txt`.
