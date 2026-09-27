# AREDN main compatibility matrix

Baseline frozen 2026-09-23. The source target is authoritative `aredn/aredn`
main at `f45bfa0124036e82ff7170480924b9e9664cc29f`. The retained official hAP
ac2 nightly is `aredn-20260923-5105916f-ipq40xx-mikrotik-mikrotik_hap-ac2-squashfs-sysupgrade-v7.bin`
at source `5105916f4449d98f2c46acecf6c9e1e5780065dc`. The two revisions are not
treated as equivalent. Runtime results require firmware built from the stated
source and are not established by this matrix.

| Area | Main behavior | r30 treatment | Verification state |
| --- | --- | --- | --- |
| Table 28 | `wan_monitor.uc` and WAN hotplug both manage local export; `/0` and optional split `/1` routes are possible | The package saves and suppresses native monitor targets while enabled, synchronously removes stock hotplug exports, directly reconciles `/0` and split `/1` routes, and restores native settings on disable/removal. | Mock and live takeover/hotplug/watchdog/restore PASS on `20260924-f45bfa01`; live qualified RF export deliberately not enabled |
| Tables 23 and 22 | Table 23 is a local DtD default and precedes table 22, the remote mesh default | Reported independently; neither is rewritten or presented as WAN3 | Static/mock PASS; neither route was present for a live precedence test |
| Explicit `none` ports | Main distinguishes an explicit empty assignment from unset/default | Package-owned role generation never rewrites `setup.globals.*_intf`; mock regression preserves `none` across apply/restore | Mock test pending execution |
| WAN transport | Logical `wan` can use Ethernet `br-wan` or one AREDN Wi-Fi client device | Resolve `network.interface.wan.l3_device`; reject two WAN-client radios; never classify mesh station or `br-wifi` as WAN | Mock PASS; live Ethernet `br-wan` PASS; live Wi-Fi WAN unavailable |
| RF/firewall/XLinks | Main generates RF bridges/VLANs and classifies `br-wifi` as RF | Preserve upstream files and `wifi`/`fast` zone membership; validate VLAN 2/3/4/5 collision before apply; add only package-owned includes | Existing mock coverage; hardware NOT RUN |
| WAN2/WAN3 | No native PollyWAN candidates | WAN2 uses private table 102 and WAN firewall membership. WAN3 is optional dynamic DHCP/table 103 using only matching installed USB support | Mock PASS; live devices/upstreams unavailable and WAN3 failed closed |
| Health/damping | Native monitor uses gateway-oriented pings and a 60-second cycle | Retain source-bound HTTPS, secondary endpoint, TLS validation, immediate export withdrawal, local failure hysteresis, recovery observations and hold-down | Model/mock PASS; live bounded upstream-failure and recovery PASS |
| Route idempotence | Native route writers may react to hotplug and monitor ticks | Package reconciliation checks desired `/0` and split `/1` routes before writing; a separate heartbeat watchdog withdraws stale exports | Mock PASS; live identical-cycle, stock-hotplug, and watchdog tests PASS |
| WireGuard MTU | Main limits generated per-tunnel MTU using WAN MTU | Do not overwrite tunnel MTU or keys; outer transport and failover MTU require matching-firmware lab validation | Audit complete; runtime NOT RUN |
| Tunnel isolation | Main retains mesh tunnel routes | Package guards tunnel ingress from tables 26, 28, 22 and main Internet fallthrough while retaining mesh routing | Namespace/mock PASS; live preference-45/table-99 guard PASS; MTU failover unavailable |
| UI/telemetry | AREDN UCode UI; core sysinfo is firmware-owned | Admin UI controls package ownership on stock firmware. Public package endpoint serves atomic cached JSON only. Core sysinfo is unchanged. | Public endpoint PASS; unauthenticated admin rejection PASS; authenticated rendering NOT RUN |
| Low memory/Babel | Main contains current qdisc and Babel restart controls | No duplicate qdisc or Babel restart mechanism; no status-cycle service reload | Functional resource sample PASS; soak NOT RUN |

The package has no patched-firmware marker dependency. It remains inert until
explicitly enabled, then performs a reversible package-side ownership handoff.
Acceptance still requires live tests on the pinned, unmodified main/nightly
baseline.
