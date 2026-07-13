# AREDN Multi-WAN package and USB/PdaNet setup

## Package status

`aredn-multiwan` starts as an **optional installable package**, not a base-firmware feature. It is built as an APK for:

- MikroTik hAP ac lite (`RB952Ui-5ac2nD`)
- MikroTik hAP ac2
- MikroTik hAP ac3

The package is disabled after installation. Existing AREDN single-WAN behavior remains unchanged until an authenticated administrator enables the package and selects another path.

The package source is `packages/aredn-multiwan`. The hAP target configurations use:

```text
CONFIG_PACKAGE_aredn-multiwan=m
```

`=m` builds the APK and its dependencies but does not place the package in the firmware image.

## Install and remove

After the package has been published to the node's configured package repository, install it from the AREDN package page or from an authenticated shell:

```sh
apk add aredn-multiwan
```

A local development build normally produces an artifact below:

```text
openwrt/bin/packages/<architecture>/arednlocal/aredn-multiwan-0.1.0-r1.apk
```

For a local file, use the APK command appropriate to the development image, for example:

```sh
apk add --allow-untrusted /tmp/aredn-multiwan-0.1.0-r1.apk
```

The package installs an administrator-only application icon named `aredn-multiwan`. Select it from the AREDN application bar to open `/a/multiwan`.

Before removal, select WAN 1 when possible. The package's removal script also attempts this automatically:

```sh
apk del aredn-multiwan
```

Saved `aredn.multiwan` UCI settings remain after removal so a later reinstall can reuse them. Runtime interfaces, proxy rules, processes, UI files, and application launcher files are removed with the package.

## Logical WANs

| Interface | Intended source | Package behavior |
|---|---|---|
| `wan` | Existing AREDN Ethernet or Wi-Fi WAN | Preserved as the default and fallback path |
| `wan2` | Second Ethernet WAN | Can be selected and calibrated when separately configured |
| `wan3` | USB RNDIS/CDC tether | Created dynamically by this package |

Private route tables are:

| Interface | Table |
|---|---:|
| `wan` | 101 |
| `wan2` | 102 |
| `wan3` | 103 |

Only one preferred IPv4 default route is copied into the main table. This is failover/selection, not bonding. Existing TCP sessions generally do not survive a WAN change.

> Current limitation: the package does **not yet create the physical or VLAN definition for `wan2`**. The second Ethernet interface must already exist before it can be selected or calibrated.

## USB device support

Package dependencies pull in:

- RNDIS USB networking
- CDC Ethernet
- CDC NCM
- `redsocks`
- nftables NAT support
- curl and the system CA bundle

The package uses sysfs to confirm a manually entered device is USB-backed. Automatic discovery recognizes USB-backed devices and conventional names such as `usb0`, `rndis0`, `wwan0`, and `enx...`.

## Administrator setup for a standard routed USB tether

1. Install `aredn-multiwan`.
2. Connect the Android device using a data-capable USB cable.
3. Enable Android USB tethering.
4. Log in to the AREDN node and open the `aredn-multiwan` application.
5. Open **USB WAN**.
6. Enable **USB WAN**.
7. Leave **USB interface** set to `auto` unless more than one USB network device is present.
8. Disable **Use upstream proxy** for an ordinary routed tether.
9. Select **Save USB WAN**.
10. Wait for `wan3` to show `up` and an IPv4 address.
11. Select **Use USB WAN now**.

## PdaNet USB setup

PdaNet USB mode commonly exposes an HTTP CONNECT proxy instead of a complete routed Internet path.

1. Connect the phone to the hAP USB host port with a data cable.
2. Open PdaNet+ on Android.
3. Enable **Activate USB Mode** and leave PdaNet running.
4. Open the package application and the **USB WAN** editor.
5. Enable **USB WAN** and **Use upstream proxy**.
6. Use the values shown by the phone. Common defaults are:

   ```text
   Address: 192.168.49.1
   Port:    8000
   Type:    HTTP CONNECT
   ```

7. Enter proxy credentials only when the phone proxy requires them. Leaving the password field blank preserves the saved password; use **Clear saved password** to remove it.
8. Save, wait for `wan3` DHCP, and select **Use USB WAN now**.

## Transparent proxy behavior

When `wan3` is selected and proxy mode is enabled:

1. `wan3-manager` starts a private redsocks process from a generated configuration.
2. nftables redirects public IPv4 TCP sessions from local AREDN clients to redsocks.
3. Redsocks creates HTTP CONNECT tunnels through the configured phone proxy.
4. The proxy endpoint itself is excluded so the redsocks connection is not redirected recursively.
5. LAN, mesh, private, carrier-grade NAT, multicast, reserved, and 44Net destinations are excluded.
6. Public UDP port 443 is rejected so browsers normally fall back from QUIC/HTTP/3 to TCP/HTTPS.

Important limitations:

- HTTP CONNECT carries TCP, not general UDP.
- Incoming connections and port forwarding through the phone proxy are unavailable.
- UDP-only voice, gaming, and application protocols may fail.
- WireGuard uses UDP and normally requires a TCP-capable alternative while PdaNet proxy mode is active.
- IPv6 Internet traffic is not transparently proxied.
- The package does not alter TTL, hop limit, or carrier-detection fields.

## Runtime verification

Run from an authenticated shell:

```sh
# Installed package
apk info -e aredn-multiwan

# Persistent settings
uci -c /etc/config.mesh show aredn.multiwan

# Package manager state
/usr/local/bin/wan3-manager status

# Dynamic USB WAN
ubus call network.interface.wan3 status

# USB network devices
for d in /sys/class/net/*; do
    printf '%s -> %s\n' "${d##*/}" "$(readlink -f "$d/device" 2>/dev/null)"
done

# Main and private defaults
ip -4 route show table main default
ip -4 route show table 101
ip -4 route show table 102
ip -4 route show table 103

# PdaNet proxy process and rules
cat /var/run/wan3-redsocks.pid 2>/dev/null
nft list table inet aredn_wan3_proxy

# Logs
logread -e wan3-manager
logread -e redsocks
```

Expected USB proxy state:

- `wan3` reports `"up": true`, an L3 device, and an IPv4 address.
- Table 103 contains the DHCP-learned default.
- When selected, the main table points through the USB device.
- The private redsocks PID exists.
- `nft list table inet aredn_wan3_proxy` succeeds.

## Troubleshooting

### Application icon is missing

```sh
apk info -e aredn-multiwan
ls -l /www/cgi-bin/apps/aredn-multiwan/admin
ls -l /www/apps/aredn-multiwan/icon.svg
```

The icon appears only to an authenticated administrator.

### USB WAN remains waiting

- Confirm the cable supports data.
- Confirm Android or PdaNet shows an active USB session.
- Inspect `/sys/class/net/*/device` using the verification command above.
- If automatic discovery selects the wrong adapter, enter the exact USB-backed interface name.
- Check drivers with `lsmod | grep -E 'rndis|cdc|usbnet'`.

### `wan3` has no IPv4 address

- Inspect `logread -e netifd` and `logread -e udhcpc`.
- Disable and re-enable tethering on the phone.
- Remove competing USB Ethernet adapters while using automatic discovery.

### Browsing fails with proxy mode enabled

Test the proxy directly:

```sh
source_ip="$(ubus call network.interface.wan3 status | jsonfilter -e '@["ipv4-address"][0].address')"
curl --interface "$source_ip" \
     --proxy http://192.168.49.1:8000 \
     --connect-timeout 10 \
     https://example.com/ -o /dev/null -v
```

Verify the address and port shown by PdaNet, inspect `logread -e redsocks`, and confirm the nftables table exists. Disable proxy mode when the phone supplies a normal routed tether.

## Recovery

```sh
/usr/local/bin/wan3-manager select wan
/etc/init.d/wan3-manager stop
```

If the package is still installed but should remain inactive:

```sh
uci -c /etc/config.mesh set aredn.multiwan.enabled='0'
uci -c /etc/config.mesh set aredn.multiwan.wan3_enable='0'
uci -c /etc/config.mesh set aredn.multiwan.active='wan'
uci -c /etc/config.mesh commit aredn
/usr/local/bin/wan3-manager remove
```

## Code-to-document verification map

| Behavior | Package source |
|---|---|
| Package metadata and dependencies | `packages/aredn-multiwan/Makefile` |
| UCI defaults | `packages/aredn-multiwan/files/etc/uci-defaults/95-aredn-multiwan` |
| USB discovery, `wan3`, route selection, proxy | `packages/aredn-multiwan/files/usr/local/bin/wan3-manager` |
| WAN 1/2 route cache | `packages/aredn-multiwan/files/usr/local/bin/wan-route-cache` |
| Calibration | `packages/aredn-multiwan/files/usr/local/bin/wan-calibrate` |
| Administrator application page | `packages/aredn-multiwan/files/app/main/multiwan.ut` |
| USB editor | `packages/aredn-multiwan/files/app/main/status/e/usb-wan.ut` |
| Calibration editor | `packages/aredn-multiwan/files/app/main/status/e/link-calibration.ut` |
| Application launcher | `packages/aredn-multiwan/files/www/cgi-bin/apps/aredn-multiwan/admin` |
| Static verification | `tests/verify-multiwan.sh` |

Run `tests/verify-multiwan.sh` whenever defaults, paths, dependencies, limits, or UI fields change.
