# WAN 3 Android USB Tether

WAN 3 is a normal Android USB tethered Ethernet WAN:

```text
Android phone -> data-capable USB cable -> hAP USB host
              -> RNDIS, CDC Ethernet, or CDC NCM network device
              -> wan3 DHCP -> private routing table 103
```

The phone supplies DHCP, gateway, DNS, and NAT Internet access. PollyWAN does
not run a proxy, redirector, transparent firewall table, or phone-side helper.

## Android Setup

1. Connect a data-capable USB cable between the Android phone and the hAP USB host.
2. Unlock the Android phone.
3. Open Android hotspot/tethering settings.
4. Enable USB tethering.
5. Enable WAN 3 in PollyWAN.
6. Wait for DHCP.
7. Verify health before selecting WAN 3.

USB charging alone is insufficient. The phone must expose a USB network device
and lease an IPv4 address to `wan3`.

Supported Android phones normally expose RNDIS, CDC Ethernet, or CDC NCM. Driver
availability depends on the running AREDN kernel and hardware. PollyWAN detects
existing `usbnet`, `rndis_host`, `cdc_ether`, and `cdc_ncm` support at runtime,
but it does not bundle or force-install kernel modules from another firmware
build.

WAN 1 and WAN 2 remain fully usable when USB host or USB-network support is not
available.

## Verification

Expected dynamic network state after Android USB tethering is enabled:

```sh
/usr/local/bin/wan3-manager usb-support
ubus call network.interface.wan3 status
ip -4 route show table 103
```

Expected status fields:

```text
detected device
IPv4 address
gateway
link state
```

Expected UI states:

```text
Disabled
Waiting for phone
USB device detected
Requesting DHCP
Connected
No compatible USB network driver
```

WAN 3 health and Cloudflare speed tests use direct source-bound HTTPS:

```sh
curl --interface "$SOURCE" --proxy ''
```

The AREDN node-to-node iperf3 method is unchanged.

## GPS Safety

WAN 3 discovery runs only after PollyWAN and WAN 3 are enabled. It enumerates
network devices under `/sys/class/net` and never opens `/dev/ttyACM0` or
`/dev/ttyUSB0`, edits gpsd, changes AREDN GPS time/location settings, changes
radio mode, or changes USB power.
