# Multi-WAN implementation verification

This page explains how to verify that the multi-WAN documentation, UI defaults, runtime scripts, and target-image integration remain consistent.

## Run the repository verifier

From the repository root:

```sh
tests/verify-multiwan.sh
```

The script checks:

- BusyBox `ash` syntax for the runtime manager, route cache, calibration runner, init script, hotplug scripts, and first-boot hook
- executable git modes for runtime shell files
- the default-disabled USB WAN configuration
- the PdaNet-oriented `192.168.49.1:8000` HTTP CONNECT defaults
- route tables 101, 102, and 103
- `wan`, `wan2`, and `wan3` allow-lists
- server-side administrator checks in both write handlers
- bounded 1 MiB, 8 MiB, and 32 MiB calibration stages
- low, medium, and fast thresholds
- direct and proxy-aware curl behavior
- USB networking and redsocks target packages for all three hAP images
- selective feed installation of the `redsocks` package
- required setup, limitation, and code-map statements in the user documentation

When an OpenWrt source tree has already been prepared in `openwrt/`, the verifier also performs a dry-run of `patches/759-mikrotik-usb-wan.patch` against that tree. Without a prepared tree, it prints a skip notice rather than claiming that test passed.

## Prepare an OpenWrt tree and verify the target patch

The AREDN build system pins OpenWrt in `openwrt.mk`. For this branch the intended base is OpenWrt 25.12.5.

```sh
make prepare
tests/verify-multiwan.sh
```

A successful prepared-tree run should end with:

```text
multi-WAN static verification passed
```

This does not prove that an image fits in flash or that USB hardware works. It proves that the patch applies to the prepared source and that the repository's cross-file contracts agree.

## Build the target images

The relevant AREDN build targets are:

```sh
# hAP ac lite
make MAINTARGET=ath79 SUBTARGET=mikrotik

# hAP ac2 and hAP ac3
make MAINTARGET=ipq40xx SUBTARGET=mikrotik
```

After each build, inspect image metadata and sizes. The hAP ac lite has the least flash headroom and requires particular attention after adding USB network modules and redsocks.

A build failure caused by image size is a real validation failure; do not remove the size check or claim support without addressing the package footprint.

## On-device verification

After installing a private build on a test device, follow the setup guide and collect:

```sh
uci -c /etc/config.mesh show aredn.multiwan
/usr/local/bin/wan3-manager status
ubus call network.interface.wan3 status
ip -4 route show table main default
ip -4 route show table 101
ip -4 route show table 102
ip -4 route show table 103
nft list table inet aredn_wan3_proxy
logread -e wan3-manager
logread -e redsocks
```

Test at least these transitions:

1. Boot with USB WAN disabled; existing WAN remains unchanged.
2. Enable USB WAN with no phone attached; status reports waiting.
3. Attach a standard Android USB tether; `wan3` receives DHCP state.
4. Attach PdaNet USB mode; verify explicit proxy access at the phone's displayed address and port.
5. Select USB WAN; new LAN TCP sessions use the proxy.
6. Confirm local LAN, mesh, and 44Net destinations are not redirected.
7. Confirm a browser falls back from QUIC to TCP when public UDP/443 is rejected.
8. Unplug the active USB device; the node attempts to restore WAN 1.
9. Reattach USB and select it again.
10. Run one authenticated calibration on each usable path; verify cooldown and stale-result behavior.
11. Try the calibration endpoint while logged out; verify HTTP 401/403 and no transfer.

## Known validation boundary

At the time this document was added:

- shell syntax and cross-file static checks are available in the repository
- target patch contexts were reviewed against the pinned OpenWrt source
- the exact Hurricane Electric / Hayward CDN object is still unconfigured
- a full firmware build has not yet been recorded for this branch
- physical tests have not yet been recorded for all three target devices
- independent physical/VLAN provisioning for `wan2` remains a separate implementation slice
- automatic speed-bin route selection is not yet implemented

Do not turn any of those open items into a success claim until the corresponding build log or hardware result exists.

## Documentation contract

The verifier is intentionally coupled to these documents:

- `docs/multiwan-usb-wan.md`
- `docs/multiwan-link-calibration.md`
- `docs/multiwan-verification.md`

When code changes a default, interface name, route table, proxy scope, package, byte limit, authentication rule, or known limitation, update the affected document and `tests/verify-multiwan.sh` in the same change set.
