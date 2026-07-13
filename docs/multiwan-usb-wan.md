# Multi-WAN USB WAN and PdaNet setup

This document describes the optional third WAN (`wan3`) added for the MikroTik hAP ac lite, hAP ac2, and hAP ac3. It is written against the implementation on the `feature/mikrotik-multiwan-usbwan` branch.

## Scope and defaults

The feature is **off by default**. Existing AREDN single-WAN behavior is unchanged until an administrator enables USB WAN.

The three target images include these USB network classes:

- RNDIS, commonly exposed by Android USB tethering
- CDC Ethernet
- CDC NCM

They also include `redsocks`, which converts transparently redirected TCP connections into HTTP CONNECT requests for an upstream proxy.

The logical interfaces are:

| Name | Intended source |
|---|---|
| `wan` | Existing AREDN Ethernet or Wi-Fi WAN |
| `wan2` | Second Ethernet WAN when separately configured |
| `wan3` | USB tethering device managed by `wan3-manager` |

`wan3` is created dynamically through netifd. Its DHCP default route is placed in routing table 103. Selecting it copies one preferred default route into the main table. USB discovery and proxy behavior therefore remain outside the existing `node-setup` network generator.

## Administrator setup

Only a logged-in AREDN administrator can open or change the USB WAN controls.

1. Connect the Android phone to the hAP USB host port using a data-capable cable.
2. On Android, enable the mode that exposes a USB network interface. For PdaNet+, enable **Activate USB Mode** and leave PdaNet running.
3. Open the node **Status** page and select the **USB WAN** card.
4. Enable **USB WAN**.
5. Leave **USB interface** set to `auto` initially. The manager recognizes USB-backed interfaces and conventional names such as `usb0`, `rndis0`, `wwan0`, and `enx...`. Enter an exact interface name only when automatic discovery selects the wrong device.
6. Enable **Use upstream proxy** when PdaNet requires it.
7. Enter the proxy IPv4 address and port. The defaults are:

   ```text
   Address: 192.168.49.1
   Port:    8000
   Type:    HTTP CONNECT
   ```

   These are common PdaNet USB values; the values shown by the installed phone application take precedence.
8. Enter a proxy username and password only when the upstream proxy requires authentication. Leaving the password field blank keeps the saved password. Select **Clear saved password** to remove it.
9. Select **Save USB WAN**.
10. Confirm the card changes from `waiting` to `up` and displays an IPv4 address.
11. Select **Use USB WAN now** to install `wan3` as the main default path. **Use WAN 1** returns the default path to the existing WAN.

The configuration is stored in `/etc/config.mesh/aredn`, section `multiwan`.

## PdaNet proxy behavior

PdaNet USB mode can present an HTTP proxy rather than a fully routed Internet connection. The implementation handles that case as follows:

1. `wan3-manager` starts a private redsocks instance on `127.0.0.1:12345`.
2. A dedicated nftables table redirects public IPv4 TCP sessions from local AREDN clients to redsocks.
3. Redsocks opens an HTTP CONNECT tunnel through the configured phone proxy.
4. Private, mesh, local, carrier-grade NAT, multicast, and 44Net destinations are excluded from redirection.
5. UDP is not sent through an HTTP CONNECT proxy. Public UDP port 443 is rejected while this mode is active so browsers normally fall back from QUIC/HTTP/3 to TCP/HTTPS.

Important limitations:

- The transparent proxy handles TCP, not general UDP.
- Applications that require UDP-only Internet protocols may not work through PdaNet proxy mode.
- Incoming connections and port forwarding through the phone proxy are not supported.
- Existing sessions normally do not survive a WAN change; new sessions use the selected path.
- A VPN may use UDP and may need a TCP-capable profile while `wan3` proxy mode is active.
- This feature does not change TTL, hop limit, or other carrier-detection fields.

A standard Android USB tether that provides ordinary routed Internet access can be used with **Use upstream proxy** disabled.

## Link calibration

The **WAN Link Calibration** card includes `wan3`. A calibration can only be started by an authenticated administrator.

For `wan3`, the calibration command uses the configured HTTP proxy directly when proxy mode is enabled and still binds the request to the `wan3` source address.

The test destination is the fixed Hurricane Electric / Hayward Internet Exchange CDN object configured in the image. The browser cannot provide or override a URL. Until a valid HTTPS hostname and byte-range-capable object are configured, calibration buttons remain disabled.

Progressive download sizes are 1 MiB, 8 MiB, and 32 MiB, with at most about 41 MiB transferred. Results are classified as:

- `low`: 5 Mbps or less
- `medium`: over 5 Mbps through 30 Mbps
- `fast`: over 30 Mbps

## Runtime verification

Run these commands over an authenticated shell:

```sh
# Persistent settings
uci -c /etc/config.mesh show aredn.multiwan

# Manager state
/usr/local/bin/wan3-manager status

# Dynamic netifd interface
ubus call network.interface.wan3 status

# See USB-backed network devices
for d in /sys/class/net/*; do
    printf '%s -> %s\n' "${d##*/}" "$(readlink -f "$d/device" 2>/dev/null)"
done

# Selected and private routes
ip -4 route show table main default
ip -4 route show table 103

# Transparent proxy process and rules
cat /var/run/wan3-redsocks.pid 2>/dev/null
nft list table inet aredn_wan3_proxy

# Recent messages
logread -e wan3-manager
logread -e redsocks
```

Expected healthy state:

- `wan3-manager status` reports `ready`, or `configuring` followed by `ready`.
- `ubus ... wan3 status` reports `"up": true`, a valid `l3_device`, and an IPv4 address.
- Table 103 contains a default route learned by DHCP.
- When `wan3` is active, the main table contains a default route through the USB device.
- With proxy mode enabled, a redsocks PID and the `aredn_wan3_proxy` nftables table exist.

## Troubleshooting

### USB WAN remains waiting

- Confirm the cable carries data, not power only.
- Confirm the phone shows an active USB tether or PdaNet session.
- Run the sysfs device listing above. If the device exists with an unusual name, enter it explicitly in **USB interface**.
- Verify a driver loaded with `lsmod | grep -E 'rndis|cdc|usbnet'`.

### `wan3` exists but has no IPv4 address

- Check `logread -e netifd` and `logread -e udhcpc`.
- Disable and re-enable USB mode on the phone.
- Remove competing USB Ethernet adapters while using automatic detection.

### Web pages fail with proxy mode enabled

- Verify the address and port shown by PdaNet.
- Test the proxy explicitly:

  ```sh
  curl --interface "$(ubus call network.interface.wan3 status | jsonfilter -e '@["ipv4-address"][0].address')" \
       --proxy http://192.168.49.1:8000 \
       --connect-timeout 10 https://example.com/ -o /dev/null -v
  ```

- Inspect `logread -e redsocks`.
- Confirm the nftables table exists.
- If the phone provides ordinary routed USB tethering, disable **Use upstream proxy**.

### Some applications work and others do not

This normally indicates an application depends on UDP. HTTP, HTTPS, SSH, and many TCP applications can traverse the proxy. UDP-only voice, gaming, QUIC, and some VPN configurations cannot be transparently converted to HTTP CONNECT.

## Code-to-document verification map

| Documented behavior | Source path |
|---|---|
| Defaults and PdaNet proxy values | `files/etc/config.mesh/aredn` |
| Administrator UI, validation, and activation | `files/app/main/status/e/usb-wan.ut` |
| Status card | `files/app/partial/usb-wan.ut` |
| USB discovery, dynamic `wan3`, route selection, redsocks, nftables | `files/usr/local/bin/wan3-manager` |
| USB device hotplug | `files/etc/hotplug.d/net/95-wan3-manager` |
| Route/proxy reapplication after interface events | `files/etc/hotplug.d/iface/95-wan3-manager` |
| Proxy-aware calibration | `files/usr/local/bin/wan-calibrate` |
| Three-link calibration UI | `files/app/main/status/e/link-calibration.ut` |
| Target-specific USB drivers and redsocks package | `patches/759-mikrotik-usb-wan.patch` |

When a field name, default, path, interface name, table number, proxy mode, or calibration limit changes in code, update this document in the same change set.

## Disable and recover

Use the UI to disable USB WAN, or run:

```sh
uci -c /etc/config.mesh set aredn.multiwan.wan3_enable='0'
uci -c /etc/config.mesh set aredn.multiwan.active='wan'
uci -c /etc/config.mesh commit aredn
/usr/local/bin/wan3-manager remove
/usr/local/bin/wan3-manager select wan
```

Disabling the feature removes the dynamic interface, stops the private redsocks process, and deletes the dedicated nftables table. It does not modify the existing AREDN WAN definition.
