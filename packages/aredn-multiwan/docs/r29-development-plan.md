# PollyWAN r29 Development Plan

## Release target

PollyWAN r29 is the final planned package release targeting AREDN `4.26.7.0`.
It remains a development package until live validation is complete.

- Stable source tag: `4.26.7.0`
- Stable source commit: `93ad9ea94fb2c0edd829c513305ffbaa90c07858`
- Test node: `KJ6DZB-WSB-hub5`
- Board and target: `mikrotik,hap-ac2`, `ipq40xx/mikrotik`
- Architecture: `arm_cortex-a7_neon-vfpv4`
- Observed stable kernel: `6.12.94`

Development builds and live validation must use this stable ABI. Current AREDN
`main` is a compatibility-audit target, not the r29 build target. PollyWAN r30
will start the nightly-targeted development line.

## Forward-compatibility baseline

The authoritative upstream repository is `https://github.com/aredn/aredn.git`.
Do not use the `mathisono/aredn` fork's `origin/main` as evidence of current
AREDN nightly state.

Initial nightly audit commit:

```text
eb2a89c10adf2ae22165ae2b5589f2d44531cbe6
```

Refresh and record this commit whenever the compatibility audit is repeated.
Do not silently change the audit baseline during an r29 test cycle.

## Compatibility gates

| Area | Stable 4.26.7.0 | Audited nightly behavior | r29 requirement |
| --- | --- | --- | --- |
| Local selected route | PollyWAN tables 26 and 27 | AREDN retains table 27 and adds more routing controls | Preserve PollyWAN's stable behavior; detect incompatible ownership before changing routes |
| Mesh-exported default | PollyWAN exclusively qualifies and manages table 28 | AREDN `wan_monitor.uc` also adds and removes table-28 routes | Adapt the native monitor to PollyWAN's qualification and damping contract; it must be the sole table-28 owner on nightly |
| Remote Mesh WAN | Table 22 | Table 23 is inserted ahead of table 22 for a local default learned over DtD | Treat table 23 as a distinct future input; do not silently classify it as table 22 |
| Internet health | Source-bound HTTPS with primary and optional secondary endpoint | AREDN monitor uses source-interface ping targets | Do not weaken PollyWAN qualification to gateway reachability or ping-only monitoring |
| Babel lifecycle | PollyWAN dampens restarts and restarts only when required | Network option changes can explicitly request Babel and WAN-monitor restarts | Preserve idempotence and identify external restarts in telemetry/tests |
| RF topology | Stable per-release network generation | PR #2816 moves RF modes onto shared `br-wifi` | Never classify `br-wifi` or `br-fast` as an Internet WAN candidate |
| Firewall | Stable zone layout | PR #2817 assigns `wifi` and `fast` to the `wifi` zone | Never move logical networks `wifi` or `fast` into the WAN zone |
| Port management | Stable advanced-port behavior | Nightly changes port migration and phantom-change handling | Keep role changes isolated from XLinks and retain rollback/Cancel semantics |

## r29 work sequence

1. Preserve and review all post-r28 uncommitted work already present in both
   PollyWAN trees.
2. Complete the stable-to-nightly compatibility matrix for network generation,
   firewall, Babel, LQM, ports, UCode, OpenWrt, kernel, and APK packaging.
3. On stable `4.26.7.0`, retain the r28 route contract and all r28 GUI,
   telemetry, damping, XLink, and Cancel behavior.
4. Keep the development package at `0.1.0-r29` while the preserved work is
   reviewed, built, and validated on stable firmware.
5. Run standalone verification, integration synchronization/check, and
   integration verification. Record root-only verification as pending unless it
   actually succeeds.
6. Refresh or reconstruct the stable hAP ac2 build tree before compiling. Never
   use a nightly build tree for the stable r29 APK.
7. Back up hub5 and validate the development APK on its stable firmware.
8. After r29 validation, freeze a fresh authoritative nightly commit and begin
   r30. Do not mix the nightly source adaptation into the stable r29 APK.

## Native WAN manager direction

AREDN stable `4.26.7.0` does not contain the new native `wan_monitor.uc`, so the
stable r29 package continues to use `wan-sla`. The native-manager work begins
with r30 and must not be copied into the stable r29 build tree.

PollyWAN r30 will target a recorded AREDN nightly baseline. Its native manager
must become the single table-28 owner and adopt PollyWAN's source-bound HTTPS
qualification, immediate withdrawal, export recovery count, hold-down, route
idempotence, and cached telemetry contract. The r30 handoff must inspect active
route managers and route ownership and must never leave both `wan-sla` and the
native WAN manager able to mutate table 28.

The nightly manager must not merely reproduce PollyWAN's implementation
language-for-language. It must reproduce the behavioral contract:

- distinguish interface, route, gateway, upstream, selection, and export state;
- qualify Internet access with a source-bound HTTPS request;
- use an optional secondary endpoint only after primary failure;
- withdraw table 28 on the first confirmed upstream failure;
- keep local selection hysteresis separate from mesh-export recovery;
- restore export only after the configured recovery count and hold-down;
- change table 28 only when the desired route differs from current state;
- avoid unnecessary Babel restarts;
- publish internal status and cache-only public telemetry;
- coordinate tables 22 and 23 without treating them as interchangeable;
- remain inert when PollyWAN is disabled or ownership has not been granted.

## Stop conditions

Stop implementation or deployment when any of these is true:

- another active service can add or remove PollyWAN-owned table-28 routes;
- table 23 is present and its ownership or policy precedence is unknown;
- generated network or firewall configuration would move RF paths into a WAN
  role;
- a route change can strand management access without a tested rollback;
- the build ABI differs from the stable test-node architecture or kernel ABI;
- verification or integration synchronization fails.

Root-only verification remains pending until it is actually run successfully.
