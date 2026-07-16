# PollyWAN, Mesh WAN, Babel and tunnel isolation


## Physical local candidates

- `wan` is WAN 1. AREDN Wi-Fi client mode keeps this logical name and uses `wlan0` or `wlan1`; otherwise it uses administrator-selected Ethernet `br-wan`. Wi-Fi WAN and Ethernet WAN 1 are mutually exclusive.
- `wan2` is administrator-selected Ethernet WAN 2.
- `wan3` is permanently the phone USB RNDIS/CDC input when existing kernel USB-network support is available.

All WAN-1 transports use private table 101. WAN 2 uses table 102 and WAN 3 uses table 103. Port-role application is separate from enabling the SLA controller and has an automatic rollback. PollyWAN observes but never changes AREDN radio mode. A disabled installation has no routing, port, radio, Babel, tunnel, proxy, USB, or GPS effect.

## Two different AREDN WAN concepts

AREDN exposes two independent settings:

- **Mesh to WAN** (`aredn.@wan[0].mesh_to_local_wan`) lets RF, DtD and xlink mesh traffic use this node's qualified local Internet path.
- **LAN to Mesh WAN** (`aredn.@wan[0].lan_to_remote_wan`) lets this node's LAN clients use a default learned from another mesh gateway.

The package does not create `wifiwan` or treat a remote Mesh WAN as `wan4`. Babel remains responsible for choosing the remote gateway. PollyWAN rotates only the local candidates `wan`, `wan2`, and `wan3`; when Wi-Fi client mode is configured, that Wi-Fi path is candidate `wan`.

## AREDN routing tables

| Table | Purpose |
|---:|---|
| 20 | Routes learned from other Babel mesh nodes |
| 21 | Supernode routes/guards |
| 22 | Remote default learned from a Babel mesh gateway |
| 26 | Package-selected local Internet default |
| 27 | Connected subnet of the package-selected local WAN |
| 28 | Qualified local default eligible for Babel export |
| 29 | Local LAN routes advertised into Babel |
| 99 | Blackhole used to prevent fall-through |
| main | Normal Linux table; the package mirrors the selected local default here for compatibility |

The package adds table 26 rather than overloading table 28. This separates **local Internet selection** from **permission to advertise a gateway to the mesh**.


## Wi-Fi WAN route path

AREDN generates Wi-Fi client WAN as the existing logical interface `wan`, so no new table is required:

```text
radio0_mode=wan → wan/wlan0 → table 101
radio1_mode=wan → wan/wlan1 → table 101
no Wi-Fi WAN     → wan/br-wan → table 101
```

When selected, the same atomic transaction copies the candidate into tables 26 and 27 plus the compatible main default. Table 28 is published only after health and the configured mesh-share bin pass. A DHCP source or gateway change makes the saved `wan` calibration stale.

The port manager rejects an Ethernet WAN-1 assignment while a radio owns `wan`, and the SLA manager rejects the invalid condition where both radios are configured as WAN clients. AREDN radio mode is never changed by the package.

## Required route transaction

Selecting a local WAN is an atomic operation:

```text
select wan / wan2 / wan3
    ├── verify interface, address, connected subnet and gateway
    ├── verify the path passed the selection health/quality decision
    ├── snapshot main, 26, 27 and 28
    ├── replace table 26 with the selected local default
    ├── replace table 27 with the selected WAN subnet
    ├── replace the compatible main-table default
    ├── publish table 28 only when Mesh to WAN is enabled and quality passes
    ├── start/stop the PdaNet proxy as required
    └── persist the selected WAN only after all steps succeed
```

If any route or proxy operation fails, the previous route tables are restored. A remote table-22 default is never copied into table 28.

## Selection algorithm

### Health gate

Each enabled candidate—including Wi-Fi WAN 1—must have:

- an up netifd interface (`wan` may have device `wlan0`, `wlan1`, or `br-wan`)
- an IPv4 address
- a connected subnet
- a default route in its private table
- a successful lightweight path probe

Availability is always decided by route validation, source-bound gateway ICMP, and source-bound HTTPS health fallback. Calibration requests one byte over HTTPS for speed classification only and must not withdraw an otherwise reachable path. A hard interface failure is immediate. The selected path receives the configured application-failure hysteresis, but a standby that fails its current probe is never eligible for promotion.

### Speed classes

Adaptive mode requires a fresh bounded calibration result:

- `low`: 5 Mbps or less
- `medium`: above 5 through 30 Mbps
- `fast`: above 30 Mbps

A candidate below `selection_min_bin`, or without a fresh result, is not automatically selected in adaptive mode. The controller also clamps an invalid direct-UCI configuration so `calibration_interval` cannot exceed `result_ttl`; this prevents every speed class from remaining stale between refreshes.

### Rotation and hysteresis

1. A healthy higher bin wins.
2. The configured preferred WAN wins a tie in the same bin.
3. A failed or ineligible active WAN is replaced immediately by the best eligible candidate.
4. A non-emergency promotion requires `promote_count` consecutive better observations.
5. `hold_down` prevents rapid switching after a successful promotion.
6. If no local WAN qualifies, tables 26, 27 and 28 are withdrawn. Table 22 may then provide the remote Mesh WAN fallback.
7. An administrator selecting **Use remote Mesh WAN fallback** places the controller in manual mode so the next adaptive pass does not immediately undo that explicit choice.

## How AREDN settings combine

| Local candidate state | Mesh to WAN | LAN to Mesh WAN | Result |
|---|---:|---:|---|
| Qualified local WAN | Off | Off/On | Node uses table 26; no table-28 export |
| Qualified local WAN | On | Off/On | Node uses table 26; table 28 advertises this node as a mesh gateway |
| Local WAN reachable but below mesh-share bin | On | Off/On | Local node may use table 26; table 28 stays empty, so Babel does not advertise a bad/slow gateway |
| No eligible local WAN | Off/On | On | Tables 26/27/28 are empty; LAN may use the remote table-22 gateway |
| No eligible local WAN | Off/On | Off | Local export is withdrawn; LAN traffic reaches AREDN's blackhole rather than leaking to an unintended default |

`mesh_share_min_bin` defaults to `medium`. This allows a low-speed local link to preserve local management connectivity while preventing the entire mesh from selecting it as an Internet gateway.

## Babel default-route safety

AREDN's Babel wrapper imports table 28 and installs a learned remote default in table 22. The package therefore uses these rules:

- Table 28 is flushed before every new health decision.
- While the controller is enabled, a managed Babel rule rejects a protocol-`boot` (`proto 3`) default before AREDN's generic default allow. AREDN's stock hotplug-created default is therefore unable to win the brief hotplug-to-evaluation race.
- The package publishes its qualified table-28 default explicitly as protocol `static`; only that selected, healthy and sufficiently fast route reaches AREDN's normal default-export allow.
- It is withdrawn immediately on a WAN netifd event, before a fresh evaluation.
- A remote table-22 route is never placed in table 28.
- When no local path qualifies, Babel naturally withdraws this node's exported default.

This prevents stale DHCP, a transient stock hotplug route, or a weak link from remaining advertised as a mesh gateway. Disabling the controller removes the protocol-boot guard and restores ordinary AREDN WAN-1 behavior.

## Tunnel Internet guard

Tunnel interfaces may carry AREDN mesh routes, but they must not use this node as an Internet exit and must not carry a Babel default route.

The package enforces this as a hard policy, not a user toggle:

1. For every `wg*` or `tun*` interface, install IPv4 and IPv6 rules at preference 45 that look up table 99.
2. Existing AREDN IPv4 mesh lookups at preferences 10, 20 and 30 still happen first.
3. The blackhole happens before table 26, table 28 and table 22; tunnel IPv6 also has no path to an Internet default.
4. Add managed Babel filters to `/etc/aredn_include/babel-deny.conf`:

   ```text
   in if <tunnel> ip 0.0.0.0/0 eq 0 deny
   out if <tunnel> ip 0.0.0.0/0 eq 0 deny
   in if <tunnel> ip ::/0 eq 0 deny
   out if <tunnel> ip ::/0 eq 0 deny
   ```

5. Keep the protocol-boot table-28 safety filter in the same managed block while the controller is enabled.
6. Restart Babel only when the generated filter block changes and Babel is already running.

The outer WireGuard connection generated by the node is unaffected because it is locally originated Internet traffic, not traffic arriving on the tunnel interface.

## PdaNet when Mesh to WAN is enabled

`wan3` is the phone-to-hAP USB RNDIS/CDC network using existing kernel support. In PdaNet proxy mode, public IPv4 TCP must be converted to HTTP CONNECT by redsocks on the hAP.

The package proxies:

- LAN ingress
- node-local public TCP
- RF/DtD/xlink mesh ingress only when table 28 is actually published

It deliberately does **not** proxy tunnel ingress. Tunnel Internet traffic is blackholed before local or remote defaults. The package reconciles its temporary firewall input rules whenever the active proxy policy is applied, so a normal AREDN firewall regeneration does not leave RF/DtD proxy sharing silently broken.

PdaNet gateway sharing remains TCP-only:

- HTTP, HTTPS, SSH and other TCP applications can work.
- UDP-only applications, incoming connections and port forwarding do not work through HTTP CONNECT.
- UDP/443 is rejected for eligible ingress so browsers normally fall back from QUIC/HTTP/3 to TCP/HTTPS.
- The phone connection may be metered; enabling Mesh to WAN can expose it to RF/DtD/xlink users, so the mesh-share bin should remain conservative.

## Status checks

```sh
# Selected local path and qualification
/usr/local/bin/wan-sla status
/usr/local/bin/wan3-manager status

# AREDN policy tables
ip -4 route show table 22
ip -4 route show table 26
ip -4 route show table 27
ip -4 route show table 28
ip -4 rule show

# Tunnel filters
/usr/local/bin/wan-tunnel-guard status
cat /etc/aredn_include/babel-deny.conf

# Proxy when wan3/PdaNet is active
nft list table inet aredn_wan3_proxy
cat /var/run/wan3-redsocks.pid
```

## GPS boundary

GPS is not a WAN candidate. AREDN continues to discover serial GPS receivers at `/dev/ttyACM0` or `/dev/ttyUSB0` and uses gpsd for location/time. PollyWAN only scans `/sys/class/net` after WAN 3 is enabled, and it never changes GPS time/location configuration or USB power.
