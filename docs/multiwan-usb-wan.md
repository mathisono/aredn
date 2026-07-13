# Multi-WAN USB WAN and PdaNet setup

This guide describes the optional third WAN (`wan3`) added for the MikroTik hAP ac lite, hAP ac2, and hAP ac3 on the `feature/mikrotik-multiwan-usbwan` branch. It is intentionally tied to the current code paths listed in the verification map near the end of this document.

## Scope and defaults

The feature is **off by default**. Existing AREDN single-WAN behavior is unchanged until a logged-in administrator enables USB WAN.

The three target images request these USB network classes:

- RNDIS, commonly exposed by Android USB tethering
- CDC Ethernet
- CDC NCM

They also request `redsocks`, which converts transparently redirected TCP connections into HTTP CONNECT requests for an upstream proxy.

The logical WAN names are:

| Name | Intended source | Private route table |
|---|---|---:|
| `wan` | Existing AREDN Ethernet or Wi-Fi WAN | 101, cached while multi-WAN is in use |
| `wan2` | Second Ethernet WAN when separately configured | 102, cached while multi-WAN is in use |
| `wan3` | USB tethering device managed by `wan3-manager` | 103, owned by netifd |

This branch creates `wan3` dynamically through netifd. It does **not yet create the physical or VLAN definition for `wan2`**; WAN 2 remains visible to the calibration/status code but must be provided separately until that part of the feature is implemented.

`wan3` obtains its address, gateway, and DNS information through DHCP. Netifd places its learned default in table 103. `wan-route-cache` preserves the learned WAN 1 and WAN 2 defaults in tables 101 and 102. Selecting a path installs one preferred IPv4 default in the main table.

USB discovery, proxying, and route selection remain outside the existing `node-setup` network generator. This keeps the current single-WAN generator unchanged.

## Administrator setup

Only a logged-in AREDN administrator can open or change the USB WAN controls.

1. Connect the Android phone to the hAP USB host port using a data-capable cable.
2. On Android, enable the mode that exposes a USB network interface. For PdaNet+, enable **Activate USB Mode** and leave PdaNet running.
3. Open the node **Status** page and select the **USB WAN** card.
4. Enable **USB WAN**.
5. Leave **USB interface** set to `auto` initially. The manager recognizes USB-backed interfaces and conventional names such as `usb0`, `rndis0`, `wwan0`, and `enx...`. Enter an exact interface name only when automatic discovery selects the wrong device.
6. Enable **Use upstream proxy** when PdaNet requires it.
7. Enter the proxy IPv4 address and port. The supplied defaults are:

   ```text
   Address: 192.168.49.1
   Port:    8000
   Type:    HTTP CONNECT
   ```

   These are common PdaNet USB values. The values shown by the phone application take precedence.
8. Enter a proxy username and password only when the phone proxy requires authentication. Leaving the password field blank keeps the saved password. Select **Clear saved password** to remove it.
9. Select **Save USB WAN**.
10. Confirm the card changes from `waiting` to `up` and displays an IPv4 address.
11. Select **Use USB WAN now** to install `wan3` as the main default path. **Use WAN 1** returns the default path to the existing WAN without recreating `wan3`.

The configuration is stored in `/etc/config.mesh/aredn`, section `multiwan`. Proxy credentials, when used, are stored in that local UCI configuration; they are not displayed back in the UI, but they are not encrypted at rest.

## Route and failure behavior

The manager preserves each usable WAN independently and changes only the preferred IPv4 default in the main routing table.

- Selecting USB WAN does not bridge the phone with an Ethernet WAN.
- A failed route installation restores the previous main default.
- A proxy-start failure restores the previous default and reports an error.
- Unplugging the active USB device stops the proxy and attempts to select WAN 1.
- Disabling USB WAN while it is active first attempts to restore WAN 1. If WAN 1 is not ready, the UI leaves USB WAN enabled rather than intentionally removing the only known path.
- Existing TCP and UDP sessions are not promised seamless migration. New sessions use the newly selected path.

Automatic quality-based selection is separate from this manual USB-WAN slice. Link calibration records measurements, but this commit does not yet make the calibration bins automatically change the active WAN.

## PdaNet proxy behavior

PdaNet USB mode can present an HTTP proxy rather than a fully routed Internet connection. When proxy mode is selected:

1. `wan3-manager` starts an AREDN-managed redsocks listener on TCP port 12345. The generated configuration is stored under `/tmp/wan3` and is checked with `redsocks -t` before it is started.
2. A dedicated nftables table redirects public IPv4 TCP sessions arriving from the AREDN LAN interface to redsocks.
3. Public IPv4 TCP connections created by the node itself are also redirected.
4. Redsocks opens an HTTP CONNECT tunnel through the configured phone proxy.
5. The proxy address and private, mesh, LAN, carrier-grade NAT, documentation, multicast, and 44Net destinations are excluded, preventing proxy loops and preserving local connectivity.
6. `wan3` accepts DHCP-provided DNS servers with a preferred DNS metric. This is important when the phone supplies its own reachable DNS service.
7. General UDP is not converted to HTTP CONNECT. Public UDP port 443 from the LAN and node is rejected while proxy mode is active so browsers can normally fall back from QUIC/HTTP/3 to TCP/HTTPS.

The transparent redirect currently covers **LAN-originated and node-originated TCP**. It does not automatically proxy traffic arriving from mesh RF, DtD, or VPN interfaces. That restriction avoids turning redirected mesh traffic into local input that conflicts with the existing AREDN firewall policy.

Important limitations:

- The proxy handles TCP, not general UDP.
- UDP-only voice, gaming, discovery, and VPN protocols may not work through PdaNet proxy mode.
- WireGuard uses UDP and cannot be carried through a plain HTTP CONNECT proxy by this implementation.
- Incoming connections and port forwarding through the phone proxy are not supported.
- A VPN may need a TCP-capable mode while `wan3` proxy mode is active.
- IPv6 Internet traffic is not proxied by this implementation.
- This feature does not change TTL, hop limit, or other carrier-detection fields.

A standard Android USB tether that provides ordinary routed Internet access can be used with **Use upstream proxy** disabled.

## Link calibration

The **WAN Link Calibration** card includes `wan3`. A calibration can only be started by an authenticated administrator.

For `wan3`, the calibration command uses the configured HTTP proxy directly when proxy mode is enabled and binds the connection to the `wan3` source address. It therefore does not depend on the transparent redirect rules to measure the USB path.

The intended test destination is the fixed Hurricane Electric / Hayward Internet Exchange CDN object configured in the image. The browser cannot provide or override a URL. The exact production HTTPS hostname and range-capable object remain blank in the branch; until they are configured, calibration buttons remain disabled.

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
ip -4 route show table 101
ip -4 route show table 102
ip -4 route show table 103

# Refresh cached WAN 1/WAN 2 defaults manually
/usr/local/bin/wan-route-cache all

# Transparent proxy process, generated configuration, and rules
cat /var/run/wan3-redsocks.pid 2>/dev/null
sed -n '1,120p' /tmp/wan3/redsocks.conf 2>/dev/null
nft list table inet aredn_wan3_proxy

# Recent messages
logread -e wan3-manager
logread -e redsocks
```

Expected healthy state:

- `wan3-manager status` reports `ready`, or `configuring` followed by `ready`.
- `ubus ... wan3 status` reports `"up": true`, a valid `l3_device`, an IPv4 address, and DHCP route/DNS data.
- Table 101 contains WAN 1's cached default when WAN 1 is up.
- Table 102 contains WAN 2's cached default only after a separate WAN 2 interface is configured and becomes usable.
- Table 103 contains the USB DHCP default.
- When `wan3` is active, the main table contains a metric-1 static default through the USB device.
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
- Inspect the DHCP and DNS fields in `ubus call network.interface.wan3 status`.

### Web pages fail with proxy mode enabled

- Verify the address and port shown by PdaNet.
- Test the proxy explicitly:

  ```sh
  SOURCE="$(ubus call network.interface.wan3 status | jsonfilter -e '@["ipv4-address"][0].address')"
  curl --interface "$SOURCE" \
       --proxy http://192.168.49.1:8000 \
       --connect-timeout 10 https://example.com/ -o /dev/null -v
  ```

- Inspect `logread -e redsocks`.
- Confirm `nft list table inet aredn_wan3_proxy` succeeds.
- Confirm the generated redsocks configuration says `type = http-connect` and has the expected phone address and port.
- If names do not resolve, inspect the `dns-server` array in the `wan3` ubus status and test that server directly.
- If the phone provides ordinary routed USB tethering, disable **Use upstream proxy**.

### Some applications work and others do not

This normally indicates an application depends on UDP or IPv6. HTTP, HTTPS, SSH, and many other IPv4 TCP applications can traverse the proxy. UDP-only voice, gaming, QUIC, and some VPN configurations cannot be transparently converted to HTTP CONNECT.

### WAN 1 cannot be selected again

```sh
/usr/local/bin/wan-route-cache wan
ip -4 route show table 101
/usr/local/bin/wan3-manager select wan
```

If table 101 remains empty, verify `ubus call network.interface.wan status` reports an active IPv4 address and a default route.

## Code-to-document verification map

| Documented behavior | Source path |
|---|---|
| Defaults and PdaNet proxy values | `files/etc/config.mesh/aredn` |
| Administrator UI, validation, safe activation, and safe disable | `files/app/main/status/e/usb-wan.ut` |
| Status card | `files/app/partial/usb-wan.ut` |
| USB discovery, dynamic `wan3`, fallback, route selection, redsocks, nftables | `files/usr/local/bin/wan3-manager` |
| WAN 1/WAN 2 private route caching | `files/usr/local/bin/wan-route-cache` |
| USB device hotplug | `files/etc/hotplug.d/net/95-wan3-manager` |
| Gateway cache and route/proxy reapplication after interface events | `files/etc/hotplug.d/iface/95-wan3-manager` |
| Boot ordering and manager startup | `files/etc/init.d/wan3-manager` |
| Disabling stock redsocks and enabling the AREDN manager | `files/etc/uci-defaults/98_wan3_redsocks` |
| Proxy-aware calibration | `files/usr/local/bin/wan-calibrate` |
| Three-link calibration UI | `files/app/main/status/e/link-calibration.ut` |
| Target-specific USB drivers and redsocks package | `patches/759-mikrotik-usb-wan.patch` |

When a field name, default, path, interface name, table number, proxy scope, or calibration limit changes in code, update this document in the same change set.

## Disable and recover

The UI performs the safe sequence automatically. From a shell, return to WAN 1 before removing USB WAN:

```sh
/usr/local/bin/wan-route-cache wan
/usr/local/bin/wan3-manager select wan
uci -c /etc/config.mesh set aredn.multiwan.wan3_enable='0'
uci -c /etc/config.mesh commit aredn
/usr/local/bin/wan3-manager remove
```

Disabling the feature removes the dynamic interface, stops the AREDN-managed redsocks process, and deletes the dedicated nftables table. It does not modify the existing AREDN WAN definition.

## Current validation boundary

The committed shell programs have been checked with BusyBox `ash -n`, and the generated redsocks configuration is syntax-tested at runtime before startup. A full AREDN image build and physical tests on all three hAP models are still required. In particular, the hAP ac lite image must be checked for flash-size headroom after adding USB-network modules and redsocks.
