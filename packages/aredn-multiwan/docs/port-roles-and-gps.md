# hAP Ethernet roles, Wi-Fi WAN, and GPS safety

## WAN 1 transport ownership

AREDN does not create a separate interface for a Wi-Fi client WAN. It keeps the logical interface name `wan` and changes its device:

```text
radio0_mode=wan → wan → wlan0
radio1_mode=wan → wan → wlan1
no radio in WAN mode → wan → Ethernet br-wan
```

PollyWAN therefore treats WAN 1 as **Ethernet or Wi-Fi, never both simultaneously**. The candidate remains `wan`, uses private table 101, and records speed-test state under `/tmp/wan-speed/wan.*` regardless of transport.

The package never changes `radio0_mode`, `radio1_mode`, SSID, key, channel, or radio power. It only observes AREDN's configuration. If both radios are set to WAN mode, validation and the SLA controller stop with an error rather than guessing which radio owns WAN 1.

## Port model

| Physical input | Untagged role | Optional tagged role |
|---|---|---|
| hAP port 1–5 | LAN, WAN 1, WAN 2, or disabled | DtD VLAN 2 |
| AREDN radio in WAN mode | WAN 1 | managed by AREDN, not this port page |
| USB host | WAN 3 only | none |

When Wi-Fi owns WAN 1, the port UI removes WAN 1 from every Ethernet selector. WAN 2 remains assignable to Ethernet and WAN 3 remains fixed to USB.

Route Policy Setup is the only page that enables WAN 1, WAN 2, WAN 3, and
Remote Mesh WAN. The Ports & XLinks page owns untagged roles, DtD choices, and
normal AREDN XLinks; it has no second ownership switch. Enabling PollyWAN makes
it own all Ethernet roles. Disabling PollyWAN restores the AREDN port files.

Multiple Ethernet ports may share LAN or a WAN role, but cellular and Starlink must be placed in different roles. At least one Ethernet port must remain LAN. An enabled Ethernet WAN must have an assigned port.

Default Ethernet roles when Wi-Fi does not own WAN 1:

| Port | Untagged | DtD VLAN 2 |
|---|---|---:|
| 1 | WAN 1 | no |
| 2 | LAN | no |
| 3 | LAN | no |
| 4 | LAN | no |
| 5 | disabled | yes |

Example while Wi-Fi owns WAN 1:

```text
AREDN radio: WAN 1 (wlan0 or wlan1)
Port 1:      WAN 2
Ports 2–4:  LAN
Port 5:      untagged disabled + tagged DtD VLAN 2
USB:         WAN 3
```

## Board mappings

### hAP ac2 / hAP ac3

| UI | Linux switch port |
|---|---|
| Port 1 | `wan` |
| Port 2 | `lan1` |
| Port 3 | `lan2` |
| Port 4 | `lan3` |
| Port 5 | `lan4` |

### hAP ac lite

| UI | Linux/switch mapping |
|---|---|
| Port 1 | dedicated `eth1` |
| Port 2 | switch0 port 4 |
| Port 3 | switch0 port 3 |
| Port 4 | switch0 port 2 |
| Port 5 | switch0 port 1 |

Internal VLANs are 3 (LAN), 2 (DtD), 4 (Ethernet WAN 1), and 5 (WAN 2). VLAN 4 and the package `wan.network.user` override are omitted while AREDN Wi-Fi client mode owns WAN 1. AREDN then generates `network.interface.wan` directly on `wlan0` or `wlan1`.

AREDN PR #2816 uses `br-wifi` for mesh AP/PTP/station radios and keeps that shared RF bridge in AREDN's generated `wifi_network_config`, outside PollyWAN's `bridge.network.user` fragment. PR #2817 assigns logical networks `wifi` and `fast` to the AREDN `wifi` firewall zone. PollyWAN must not write or classify `br-wifi` as WAN, must not modify `br-fast`, and must not move `wifi` or `fast` into the WAN firewall zone. On builds with configurable RF VLAN support, the configured RF VLAN must not be 2, 3, 4, or 5 because those VLANs are reserved by PollyWAN's Ethernet role layout.

## Apply and rollback

All saved role options pass through the shared PollyWAN configuration writer.
It refuses to mix a direct PollyWAN Apply with unrelated pending AREDN changes,
repairs a missing `aredn.multiwan` section, checks the commit, and reads every
submitted value back from `/etc/config.mesh` before an apply may start. Failed
commits or read-back checks restore and verify the preceding persistent values.

The page has the standard AREDN **Cancel**, **Done**, and **Apply** controls.
While PollyWAN is disabled, Apply records and verifies the future port/XLink
layout without changing live Ethernet ownership. Route Policy Setup is the
single authoritative master enable. Enabling it stages the disabled state and
starts the following protected apply:

1. validates the board, radio ownership, LAN count, and WAN role counts
2. backs up existing AREDN advanced-network include files
3. writes managed bridge, LAN, WAN/WAN2, DtD, and hAP ac lite switch files
4. runs AREDN `node-setup`
5. reloads networking and adds `wan2` to the WAN firewall zone
6. starts a rollback timer, default 180 seconds

Reconnect through a working LAN or mesh path and select **Confirm working**.
Without confirmation, the exact pre-apply include files, marker, XLink UCI
file, master enable, and port-role UCI values are restored and the network is
regenerated. A confirmed managed layout can therefore be edited and rolled
back without falling all the way back to AREDN defaults.

For non-interactive configuration restore, including RapidConfig, a persisted
`enabled=1` with no managed marker is an authoritative activation request at
service reconciliation; the internal `port_roles_enabled` value is reconciled
to the master automatically. The same validation and persistent recovery
snapshot are used. This path confirms itself only after `node-setup` and network
regeneration succeed; otherwise it restores AREDN files, disables the unapplied
flag, and records an error. If a reboot removes the temporary rollback token
while its persistent snapshot remains, startup restores and verifies the exact
pre-apply files and UCI values before continuing.

Touched files are limited to:

```text
/etc/aredn_include/bridge.network.user
/etc/aredn_include/lan.network.user
/etc/aredn_include/wan.network.user
/etc/aredn_include/dtdlink.network.user
/etc/aredn_include/swconfig
/etc/aredn_include/swconfig.user
```

The long-lived AREDN-default backup lives under
`/etc/aredn-multiwan-backup/ports`; the per-apply rollback snapshot lives under
`/etc/aredn-multiwan-backup/pending` only until confirmation or rollback.
Disabling PollyWAN restores AREDN defaults but does not change the saved WAN2
or WAN3 candidate choices. Dashboard `ready`/`managed`
requires both the enable flag and this marker; a saved flag alone is never
reported as active. The marker records the
transport used when the roles were applied. If a later AREDN radio change moves
WAN 1 between Ethernet and Wi-Fi, PollyWAN reports that the roles need review;
it does not silently remap ports.

Inspect transport and state:

```sh
/usr/local/bin/wan-port-manager wan-transport
/usr/local/bin/wan-port-manager status
ubus call network.interface.wan status
ip -4 route show table 101
```

Expected transport output is one of:

```text
ethernet:br-wan
wifi:wlan0
wifi:wlan1
```

## GPS safety contract

A disabled installation is inert. PollyWAN does not:

- open `/dev/ttyACM0` or `/dev/ttyUSB0`
- edit `/etc/config/gpsd` or `/etc/config.mesh/gpsd`
- change `aredn.@time[0].gps_enable`
- change AREDN location settings
- change `aredn.@usb[0].passthrough` or USB power
- stop or restart gpsd
- change either radio mode

WAN 3 discovery runs only after `enabled=1` and `wan3_enable=1`. It enumerates `/sys/class/net` and accepts only USB-backed network devices or conventional network names such as `usb0`, `rndis0`, `wwan0`, and `enx...`. Serial GPS TTYs never enter that path.

Verify before and after installation:

```sh
uci -q show aredn.@time[0]
uci -c /etc/config.mesh -q show aredn.@time[0]
uci -q show aredn.@location[0]
uci -q show aredn.@usb[0]
uci -q show gpsd 2>/dev/null || true
ls -l /dev/ttyACM0 /dev/ttyUSB0 2>/dev/null
pidof gpsd || true
/usr/local/bin/wan-port-manager gps-status
```

When WAN 3 is disabled, these values and GPS time behavior must remain unchanged. A powered USB hub may be required when a phone and GPS receiver are attached simultaneously; that is a hardware power/topology issue, not a routing function.
