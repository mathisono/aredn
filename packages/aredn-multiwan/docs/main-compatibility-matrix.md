# AREDN main compatibility matrix

Baseline frozen 2026-09-23. The source target is authoritative `aredn/aredn`
main at `f45bfa0124036e82ff7170480924b9e9664cc29f`. The retained official hAP
ac2 nightly is `aredn-20260923-5105916f-ipq40xx-mikrotik-mikrotik_hap-ac2-squashfs-sysupgrade-v7.bin`
at source `5105916f4449d98f2c46acecf6c9e1e5780065dc`. The two revisions are not
treated as equivalent. Runtime results require firmware built from the stated
source and are not established by this matrix.

| Area | Main behavior | r30 treatment | Verification state |
| --- | --- | --- | --- |
| Table 28 | `wan_monitor.uc` and WAN hotplug both manage local export; `/0` and optional split `/1` routes are possible | Patched native monitor is the only writer. PollyWAN submits bounded, expiring schema-1 requests. Hotplug defers only when the feature marker and opt-in are both present. | Source/static testable; hardware NOT RUN |
| Tables 23 and 22 | Table 23 is a local DtD default and precedes table 22, the remote mesh default | Reported independently; neither is rewritten or presented as WAN3 | Static PASS; runtime NOT RUN |
| Explicit `none` ports | Main distinguishes an explicit empty assignment from unset/default | Package-owned role generation never rewrites `setup.globals.*_intf`; mock regression preserves `none` across apply/restore | Mock test pending execution |
| WAN transport | Logical `wan` can use Ethernet `br-wan` or one AREDN Wi-Fi client device | Resolve `network.interface.wan.l3_device`; reject two WAN-client radios; never classify mesh station or `br-wifi` as WAN | Existing mock/static coverage; hardware NOT RUN |
| RF/firewall/XLinks | Main generates RF bridges/VLANs and classifies `br-wifi` as RF | Preserve upstream files and `wifi`/`fast` zone membership; validate VLAN 2/3/4/5 collision before apply; add only package-owned includes | Existing mock coverage; hardware NOT RUN |
| WAN2/WAN3 | No native PollyWAN candidates | WAN2 uses private table 102 and WAN firewall membership. WAN3 is optional dynamic DHCP/table 103 using only matching installed USB support | Mock/static coverage; hardware NOT RUN |
| Health/damping | Native monitor uses gateway-oriented pings and a 60-second cycle | Retain source-bound HTTPS, secondary endpoint, TLS validation, immediate export withdrawal, local failure hysteresis, recovery observations and hold-down | Model/static coverage; blackhole hardware NOT RUN |
| Route idempotence | Native route writers may react to hotplug and monitor ticks | Native request reconciliation checks desired `/0` and split `/1` routes before writing; package local table helpers are replace-if-needed | Static/source coverage; churn capture NOT RUN |
| WireGuard MTU | Main limits generated per-tunnel MTU using WAN MTU | Do not overwrite tunnel MTU or keys; outer transport and failover MTU require matching-firmware lab validation | Audit complete; runtime NOT RUN |
| Tunnel isolation | Main retains mesh tunnel routes | Package guards tunnel ingress from tables 26, 28, 22 and main Internet fallthrough while retaining mesh routing | Existing namespace/mock coverage; firmware runtime NOT RUN |
| UI/telemetry | AREDN UCode UI; core sysinfo is firmware-owned | Admin UI exposes unsupported integration. Public package endpoint serves atomic cached JSON only. Core sysinfo is unchanged. | Static coverage; authenticated rendering NOT RUN |
| Low memory/Babel | Main contains current qdisc and Babel restart controls | No duplicate qdisc or Babel restart mechanism; no status-cycle service reload | Source audit complete; soak NOT RUN |

The package deliberately refuses to activate networking when
`/usr/share/aredn/features/pollywan-export-v1` is absent. Installation on a
stock nightly without the native contract remains disabled/non-mutating and is
reported as unsupported rather than starting the r29 controller.
