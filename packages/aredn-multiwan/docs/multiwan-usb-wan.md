# WAN 3 phone USB tether and PdaNet

## Physical topology

```text
Android phone running PdaNet or standard USB tether
        |
        | data-capable USB cable
        v
hAP USB host
        |
        | RNDIS / CDC Ethernet / CDC NCM
        v
wan3 DHCP (private table 103)
        |
        +-- optional HTTP CONNECT proxy configured on the hAP
```

The phone must expose a USB network interface and DHCP path. A proxy address alone is insufficient when the hAP has no USB network device/address.
PollyWAN uses USB-network drivers already present in the running kernel. It does not install or replace kernel modules; when existing RNDIS/CDC support is unavailable, WAN 3 remains down and no dynamic interface, route, or firewall state is created.

## Standard routed tether

1. Connect the phone to the hAP USB host using a data cable.
2. Enable Android USB tethering.
3. Open PollyWAN → **WAN 3: phone USB tether / PdaNet**.
4. Enable WAN 3 and leave the interface at `auto`.
5. Disable the PdaNet proxy option.
6. Save and wait for `wan3` to receive IPv4.
7. Select WAN 3 manually or allow adaptive selection.

## PdaNet

1. Enable **Activate USB Mode** in PdaNet and leave it running.
2. Confirm the hAP sees an existing RNDIS/CDC network interface and `wan3` receives DHCP.
3. Enable **Use PdaNet HTTP CONNECT proxy**.
4. Enter the values displayed by PdaNet. Common defaults are:

```text
IPv4: 192.168.49.1
TCP:  8000
Type: HTTP CONNECT
```

Optional username/password fields are stored on the hAP. A blank password keeps the saved value unless **Clear saved password** is selected.

## Proxy operation

When WAN 3 is selected and proxy mode is enabled, PollyWAN starts a private redsocks instance on TCP port `12346`, with its own configuration and PID. It does not stop or reuse the stock redsocks service.

Eligible public IPv4 TCP from LAN and the node is redirected. RF/DtD/xlink ingress is added only when the link is qualified and table 28 is published. Tunnel ingress is never proxied and is hard-blocked from Internet defaults.

Excluded destinations include:

- proxy endpoint itself
- AREDN mesh and 44Net
- LAN/private/CGNAT/link-local/reserved/multicast ranges
- source-bound WAN 1/WAN 2 health and calibration probes

HTTP CONNECT limitations:

- general UDP does not work
- UDP/443 is rejected to encourage browser fallback from QUIC to TCP/HTTPS
- incoming connections and port forwarding do not work
- UDP-only voice/gaming/VPN profiles may fail
- IPv6 Internet traffic is not transparently proxied

## Verification

```sh
ubus call network.interface.wan3 status
ip -4 route show table 103
/usr/local/bin/wan3-manager status
cat /var/run/wan3-redsocks.pid
nft list table inet aredn_wan3_proxy
logread -e aredn-multiwan
logread -e redsocks
```

Direct proxy test:

```sh
source_ip="$(ubus call network.interface.wan3 status | jsonfilter -e '@["ipv4-address"][0].address')"
curl --interface "$source_ip" --proxy http://192.168.49.1:8000 \
  --connect-timeout 10 https://example.com/ -o /dev/null -v
```

## GPS coexistence

With WAN 3 disabled, PollyWAN never enumerates or opens serial GPS devices and does not scan USB networking. Existing USB network kernel support does not change AREDN's GPS configuration. See [port-roles-and-gps.md](port-roles-and-gps.md) for the required before/after checks.
