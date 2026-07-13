# Multi-WAN package verification

## Static consistency check

Run from the repository root:

```sh
tests/verify-multiwan.sh
```

The checker verifies:

- the feature exists under `packages/aredn-multiwan`
- no runtime feature files remain in the base `files/` overlay
- no device-image patch installs the feature into base firmware
- the local feed is registered and installed by the build
- hAP MikroTik targets build `aredn-multiwan` with `=m`
- runtime scripts and hooks have shell syntax and executable modes
- package dependencies include USB networking, the hAP ac lite USB host module, redsocks, curl, CA data, and nftables NAT
- the package runs its own redsocks instance without disabling or reusing the stock service
- only authenticated handlers can change settings or start calibration
- `wan`, `wan2`, and `wan3` remain allow-listed
- PdaNet and calibration defaults match the documentation
- transfer sizes and speed thresholds match the documentation
- the source guides and copies shipped inside the APK are byte-for-byte identical

When a prepared OpenWrt tree exists, the checker also confirms the local feed package is visible below `openwrt/package/feeds/arednlocal/aredn-multiwan`.

## Build preparation

```sh
make openwrt-clean
make feeds-update
```

Verify feed integration:

```sh
test -L openwrt/package/feeds/arednlocal/aredn-multiwan
openwrt/scripts/feeds list -r arednlocal | grep aredn-multiwan
```

Verify target configuration:

```sh
make MAINTARGET=ipq40xx SUBTARGET=mikrotik prepare
grep '^CONFIG_PACKAGE_aredn-multiwan=m' openwrt/.config
```

For the hAP ac lite target:

```sh
make openwrt-clean
make MAINTARGET=ath79 SUBTARGET=mikrotik prepare
grep '^CONFIG_PACKAGE_aredn-multiwan=m' openwrt/.config
```

The package must be `m`, not `y`.

## Package-only build

After preparing one target:

```sh
make -C openwrt package/aredn-multiwan/compile V=s
```

Locate the APK:

```sh
find openwrt/bin/packages -name 'aredn-multiwan-*.apk' -print
```

The current development artifact is version `0.1.0-r2`.

Inspect metadata and contents with the available APK tooling. Confirm that the package contains:

```text
/app/main/multiwan.ut
/app/main/status/e/usb-wan.ut
/app/main/status/e/link-calibration.ut
/www/cgi-bin/apps/aredn-multiwan/admin
/www/apps/aredn-multiwan/icon.svg
/usr/local/bin/wan3-manager
/usr/local/bin/wan-route-cache
/usr/local/bin/wan-calibrate
/etc/init.d/wan3-manager
/etc/hotplug.d/net/95-wan3-manager
/etc/hotplug.d/iface/95-wan3-manager
/usr/share/doc/aredn-multiwan/
```

Confirm the base rootfs does **not** contain those files when the package is not installed.

## Installation test

On each target device:

1. Save a configuration backup.
2. Record free overlay space with `df -h /overlay` and package storage with `apk info -s` where available.
3. Install the matching architecture APK and all dependencies.
4. Confirm installation succeeds only on the hAP ac lite, hAP ac2, or hAP ac3.
5. Log out and verify the application icon is hidden.
6. Log in and verify the `aredn-multiwan` icon appears.
7. Open the application and confirm the package is disabled.
8. Confirm the existing default route and ordinary WAN behavior are unchanged.
9. Confirm an independently enabled stock redsocks service, when present, was not stopped or disabled by installation.

Commands:

```sh
apk info -e aredn-multiwan
apk info -a aredn-multiwan
ls -l /www/cgi-bin/apps/aredn-multiwan/admin
ls -l /app/main/multiwan.ut
uci -c /etc/config.mesh show aredn.multiwan
ip -4 route show table main default
df -h /overlay
```

## USB test matrix

Test at least:

| Case | Expected result |
|---|---|
| No USB device | `waiting`; no dynamic `wan3` |
| RNDIS Android tether | USB device found and DHCP attempted |
| CDC Ethernet tether | USB device found and DHCP attempted |
| CDC NCM tether | USB device found and DHCP attempted |
| Power-only cable | No device; existing WAN unchanged |
| Two USB NICs with `auto` | Document which adapter wins; exact-name override works |
| Non-USB interface entered manually | Rejected |
| USB unplugged while standby | `wan3` removed; active WAN unchanged |
| USB unplugged while active | proxy stops and WAN 1 fallback is attempted |

## PdaNet proxy test

With PdaNet active:

```sh
/usr/local/bin/wan3-manager status
ubus call network.interface.wan3 status
cat /var/run/wan3-redsocks.pid
nft list table inet aredn_wan3_proxy
uci -c /etc/config.mesh get aredn.multiwan.wan3_proxy_local_port
```

The private listener defaults to TCP port `12346`. Confirm that port `12345`, commonly used by the feed package's example service, remains independent.

Test TCP:

```sh
curl -4 --connect-timeout 15 https://example.com/ -o /dev/null -v
```

Confirm:

- public TCP is redirected through the package's redsocks process
- the proxy endpoint is excluded from recursive redirection
- private, mesh, LAN, CGNAT, reserved, and 44Net destinations are not redirected
- UDP/443 is rejected only while USB proxy mode is active
- selecting WAN 1 removes the private proxy process and nftables table
- the stock `/etc/init.d/redsocks` enable/running state is unchanged

## Route selection test

For every configured path:

```sh
/usr/local/bin/wan3-manager select wan
ip -4 route show table main default

/usr/local/bin/wan3-manager select wan2
ip -4 route show table main default

/usr/local/bin/wan3-manager select wan3
ip -4 route show table main default
```

Verify tables 101, 102, and 103 retain usable defaults and DHCP renewal on a standby WAN does not replace the selected main-table route.

## Calibration test

Use a development range-capable HTTPS object. For each interface:

- logged-out requests are rejected
- `GET` creates no traffic
- only `PUT action=calibrate` with `wan`, `wan2`, or `wan3` starts a test
- a second simultaneous request returns busy
- cooldown blocks repeated tests
- 1 MiB, 8 MiB, and 32 MiB stages stop at the expected thresholds
- non-206 responses and incomplete byte counts fail
- `wan3` uses the configured HTTP proxy directly
- maximum total data is about 41 MiB

## Upgrade test

Install `0.1.0-r1` on a development node, retain its settings, and upgrade to `0.1.0-r2`. Confirm:

- the package remains disabled unless the administrator previously enabled it
- a saved old default listener value of `12345` migrates to `12346`
- proxy credentials and the selected interface remain intact
- the stock redsocks service is not stopped or disabled
- the application page and runtime scripts are replaced cleanly

## Removal test

With the package active on `wan3`:

```sh
apk del aredn-multiwan
```

Verify:

- WAN 1 fallback was attempted
- `wan3` no longer exists
- the package's private redsocks process is stopped
- `aredn_wan3_proxy` is gone
- the application icon and page are removed
- core AREDN pages and existing WAN files are unchanged
- the stock redsocks service state is unchanged
- saved `aredn.multiwan` settings remain for reinstall

## Release gate

Do not publish the package as generally available until all three devices have:

- a successful package build
- dependency installation from the intended repository
- install, upgrade, and removal testing
- standard tether and PdaNet testing
- route recovery after cable and DHCP events
- flash-space measurements, especially on the hAP ac lite
- documentation reviewed against `tests/verify-multiwan.sh`
