# AREDN PollyWAN

PollyWAN is an experimental installable package for the MikroTik hAP ac lite, hAP ac2, and hAP ac3. It regulates three local Internet candidates without placing the feature in the base AREDN image.

## Local candidates

- `wan` — WAN 1. When an AREDN radio is in client/WAN mode, the existing logical interface `wan` uses `wlan0` or `wlan1`. Otherwise WAN 1 uses administrator-selected hAP Ethernet port(s).
- `wan2` — WAN 2 on administrator-selected Ethernet port(s).
- `wan3` — WAN 3 fixed to a phone USB RNDIS/CDC tether when existing kernel USB-network support is available, with optional hAP-side PdaNet HTTP CONNECT settings.
- Remote Mesh WAN remains the Babel-learned default in table 22 and is never treated as a fourth local candidate.

Wi-Fi WAN and Ethernet WAN 1 are mutually exclusive because AREDN gives both the same logical interface name, `wan`. PollyWAN never changes a radio mode; it observes AREDN's existing configuration and prevents an Ethernet WAN-1 assignment while Wi-Fi owns `wan`.

## Selection and AREDN routing

Reachability is a hard gate. Adaptive mode uses a user-selected HTTPS range object and classifies each local path as low (≤5 Mbps), medium (>5–30 Mbps), or fast (>30 Mbps). Promotion requires consecutive better observations and a hold-down; hard interface failure demotes immediately.

- private candidate tables: 101 (`wan`), 102 (`wan2`), 103 (`wan3`)
- table 26: selected local Internet default
- table 27: selected local WAN connected subnet
- table 28: qualified local default eligible for Babel export
- table 22: remote Mesh WAN learned by Babel and left untouched

Tunnel ingress is hard-blocked from local and remote Internet defaults while PollyWAN is enabled. A protocol-boot default is denied from Babel so only the package-qualified protocol-static table-28 route can be advertised.

## Ports, PdaNet, and GPS

The UI follows AREDN's advanced Ports layout. Each Ethernet port receives one untagged role—LAN, WAN 1, WAN 2, or disabled—and may carry tagged DtD VLAN 2. Port application is opt-in and protected by a timed rollback. WAN 1 is not offered as an Ethernet role while AREDN Wi-Fi client mode owns it.

PdaNet is expected over a data-capable USB cable into the hAP USB host. The hAP obtains `wan3` DHCP on an existing RNDIS/CDC kernel network interface and uses the proxy address, port, and optional credentials entered by the administrator. PollyWAN does not install or replace USB kernel modules; unsupported kernels leave WAN 3 down without route or firewall changes.

A disabled installation does not remap ports, change radio modes, scan USB, open serial GPS devices, edit gpsd, change AREDN GPS time/location settings, or change USB power. WAN 3 scans only `/sys/class/net` after explicit enablement; `/dev/ttyACM0` and `/dev/ttyUSB0` remain owned by AREDN/gpsd.

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
find openwrt/bin -name 'aredn-multiwan-0.1.0-r8.apk' -print -exec sha256sum {} \;
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
