# PollyWAN r30 Main Compatibility Progress

Updated: 2026-09-27

## Frozen cycle

- Runtime target: unmodified hAP ac2 main/nightly build
  `20260924-f45bfa01`, source
  `f45bfa0124036e82ff7170480924b9e9664cc29f`.
- Kernel identity:
  `6.12.94~8b7411e54da196132ba85bfa6ac989cd-r1`.
- This cycle validates the nightly already installed on the designated node.
  A new cycle must be opened against the newly installed nightly each week
  until the release-candidate baseline is selected.
- No patched firmware image is an r30 acceptance artifact.

## Source and build

- Package-owned table-28 handoff implemented without replacing native AREDN
  files or adding a feature marker.
- Added executable user-namespace/chroot coverage for monitor save/restore,
  later administrator values, split-default idempotence, synchronous hotplug
  withdrawal, watchdog expiry, and table 22/23 non-interference.
- Fixed immediate-disable restoration so later administrator monitor values
  are not overwritten by an older snapshot.
- Added checked UCI takeover/release commits and fail-closed error handling.
- Migrated the retained r29.5 `ordered` selection mode to r30 `automatic`.
- Cache-unavailable public telemetry now reports unknown `enabled` and `mode`
  values rather than inventing disabled/manual state.
- Full static, selection, markup, port, route-cache, tunnel, and export-owner
  tests: PASS under an isolated user namespace.
- Standalone/integration subtree equality: PASS.
- Native `wan_monitor.uc` and `11-meshrouting`: unchanged from the target
  upstream source.
- Current APK build: PASS, 65,566 bytes,
  SHA-256 `b6cfb354dbc5ea0f47bafe47fb025fccb3a6ea1373b96875a9178c942b89d6fb`.
- Exact-node offline install simulation: PASS for the immediately preceding
  APK with identical package metadata and dependency closure; one same-version
  package replacement, no dependency fetch, kernel replacement, downgrade,
  removal, or additional package transaction. Re-simulation of the final APK
  hash remains pending after SSH recovery.

## 20260924-f45bfa01 runtime matrix

| Gate | Status | Evidence summary |
| --- | --- | --- |
| C00 | PASS | Board, build, source, kernel, native hashes, routes, and absence of the old feature marker captured. |
| C01 | PASS | Disabled install preserved network, firewall, wireless, native monitor settings, and stock table 28. |
| C02 | PASS | Retained `ordered` intent migrated to `automatic`; r29 controller/modules were absent. |
| C03 | PARTIAL | Current Ethernet-role validation passed; explicit-none behavior passed in the real-function mock. |
| C04 | PASS | WAN1 resolved to `ethernet:br-wan`; RF was not classified as WAN. |
| C05 | PARTIAL | Apply/confirm/rollback passed in the real-function mock; no live WAN2 upstream was attached. |
| C06 | PASS-UNAVAILABLE | No USB network device or matching driver support was present; WAN3 remained absent without GPS/serial changes. |
| C07 | PASS | A bounded bad HTTPS endpoint kept the first failure locally, withdrew all local defaults on the threshold, and recovered through fresh successful probes. |
| C08 | PARTIAL | All configured local links failed closed without cross-WAN fallback; live DHCP-address change was not injected. |
| C09 | PARTIAL | Failure/recovery observations and zero-hold test recovered correctly; multiple healthy WAN classes were unavailable. |
| C10 | PASS | Two identical healthy cycles left routes, last-switch, and last-export-change unchanged. |
| C11 | PASS | Stock hotplug recreated `/0` plus split `/1`; the package handler removed them synchronously. Watchdog expiry, service restart, disable, upgrade, and removal behaved correctly. |
| C12 | PARTIAL | Code/mocks preserve tables 22 and 23; neither route was present for a live path-precedence test. |
| C13 | PARTIAL | IPv4/IPv6 tunnel preference-45 guards and table-99 blackholes were present for five WireGuard interfaces; live uplink-MTU failover was unavailable. |
| C14 | PARTIAL | Public JSON returned 200 and valid schema; unauthenticated admin UI correctly returned 403. Authenticated rendering remains unproved. |
| C15 | BLOCKED | Stop/disable/remove/reinstall restoration passed. After the disabled reboot the node returned on WAN HTTP, but the protected mesh SSH route did not reconverge, so enabled reboot and further mutation stopped. |
| C16 | PARTIAL | Controller and watchdog stayed bounded during functional tests; six-hour soak has not started. |

## Safe node state and remaining work

The node is running the unmodified target nightly and is reachable at its
existing WAN HTTP address. PollyWAN was reinstalled disabled before reboot;
public telemetry confirms it remains disabled after boot. RF reports on and
five tunnels are configured, but the protected mesh SSH route is unavailable.
No attempt was made to bypass the WAN firewall or enable RF gateway sharing.

Remaining acceptance work:

1. Restore the protected mesh management route and confirm the stock disabled
   state over SSH.
2. Install the final APK hash above, repeat C01, then run the enabled reboot.
3. Complete the live portions of C05/C08/C09/C12/C13/C14 when the required
   second upstream, USB device, remote peer, and authenticated UI session are
   available.
4. Run and record the six-hour hAP ac2 soak.
5. Repeat the frozen cycle against the next installed nightly; do not carry a
   compatibility claim forward merely because the package hash is unchanged.
6. The source commits are pushed for review. Update runtime evidence after the
   node is recovered; do not publish a release before the release-candidate
   cycle passes.

Current status:
`POLLYWAN_R30_NIGHTLY_COMPAT_BLOCKED_C15_MANAGEMENT_ROUTE_AFTER_REBOOT`.
