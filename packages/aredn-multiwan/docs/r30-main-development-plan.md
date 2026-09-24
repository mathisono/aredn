# PollyWAN r30: AREDN main / nightly-only compatibility preparation

Prepared: 2026-09-23
Revision: 2 — supersedes POLLYWAN_R30_MAIN_DEVELOPMENT_PLAN.md and its previous launcher.
Audience: OpenClaw / Builder Bob
Scope: source adaptation and preparation for actual nightly validation; no claim that migration or live tests have run.

**Authoritative scope clarification:** r29 targets the previous stable AREDN release only. r30 is the new main/nightly compatibility line. Do not require r30 to support, build for, or pass acceptance on the old stable firmware. A passing r29/stable test is historical evidence, not evidence for current main. A host build or mock test is preparation, not a substitute for running the changed package on matching main-derived firmware.

## 1. Mission and established decisions

Update PollyWAN's development branch for the **current authoritative AREDN main branch**, using one pinned upstream commit and a positively identified matching nightly firmware for each development/test cycle. Preserve r29 and its old-stable source, APKs, build tree and evidence unchanged as the legacy reference/rollback line. This is a forward compatibility migration, not dual-stable/nightly support, another UI redesign, or a return to the earlier r27/r28 starting point.

The required runtime target is a designated lab node actually running that nightly/main-derived firmware. If the node still runs the previous stable firmware, only read-only inventory and backup work may use that node; it cannot satisfy any r30 runtime compatibility gate. Do not install r29 on a nightly and label that a completed migration, or test r30 on stable and label it main-compatible.

The inspected `docs/r29-development-plan.md` explicitly defines r29 as the last planned 4.26.7.0-targeted release and r30 as the nightly-targeted line. It also requires the native WAN manager to become the single table-28 owner. Read that document before modifying code. [S2]

Keep one authoritative PollyWAN source repository and a synchronized package subtree in the AREDN integration repository. Track native AREDN integration changes separately from the package subtree. Keep the public telemetry endpoint package-owned; **do not modify `/a/sysinfo`, `/cgi-bin/sysinfo.json`, or AREDN's `sysinfo.ut`** in this work.

### Historical planning snapshots — rediscover and freeze the execution baseline

| Item | Observed value |
| --- | --- |
| Authoritative upstream | `https://github.com/aredn/aredn.git` |
| AREDN main | `5105916f4449d98f2c46acecf6c9e1e5780065dc` |
| Latest commit at inspection | `Unify getStation(s) calls. (#2926)` |
| PollyWAN repository | `https://github.com/mathisono/AREDN_PollyWAN.git` |
| PollyWAN main | `358cd719dbca2a09a63ae0174340f58f7ef90a89` |
| Package release in inspected Makefile | `0.1.0-r29` |
| AREDN integration fork | `https://github.com/mathisono/aredn.git` |
| Recorded old integration branch | `agent/pollywan-r6` |
| Integration package path | `packages/aredn-multiwan` |
| Upstream OpenWrt selector | `v25.12.5` |

These are snapshots recorded during the earlier research, not a fresh assertion about branch heads or the test node. A commit title saying “current main” is not proof of which AREDN revision was tested. Rediscover authoritative main, package state and actual firmware identity before work starts. The OpenWrt tag alone is not proof that old kernel modules match a new firmware. [S1–S4]

## 2. Execution authority and boundaries

Proceed independently with repository discovery, source inspection, isolated changes, regression tests, builds, documentation, and pushes to scoped development branches. Open draft PRs for review. Do not merge into public main, publish a production release, or change upstream `aredn/aredn` without a separate release/promotion decision.

Do not flash or disrupt hub5 merely because it is reachable. Begin with read-only node discovery. A firmware-changing test requires a designated lab device, an independent management/recovery path, the appropriate authorization and a recorded rollback plan. This handoff is not blanket authorization to flash a field node. When a matching nightly lab device is unavailable, finish safe source/build work and return `POLLYWAN_R30_READY_FOR_NIGHTLY_TEST`; all dependent runtime tests remain NOT RUN. Never substitute the old stable node for the missing nightly target.

Never touch Crow, unrelated agents' workspaces, credentials, radios, GPS, USB power, DtD or XLinks outside the narrowly defined test. Do not install Python on routers. Host-side Python tests remain acceptable. Keep Android USB tethering optional, with no PdaNet/redsocks reintroduction and no bundled replacement kernel.

Do not force-install dependencies, bypass branch protection, force-push shared branches, or overwrite published APKs. Do not erase dirty trees, old build directories, recovery bundles, or historical evidence. Root routing tests belong in disposable namespaces/emulated roots, not the build host's real network namespace or a production router.

## 3. Resumable workspace and branch setup

Historical paths are discovery hints, not hard gates:

```
/home/bill/src/AREDN_PollyWAN-r6-consolidated
/home/bill/src/aredn
/home/bill/src/aredn-hub5-pollywan-r6
```

Create a new workspace, for example `/home/bill/src/pollywan-main-migration/`. Keep evidence and build artifacts outside source trees so they do not contaminate `SYNC_SOURCE` manifests.

Suggested layout:

```
pollywan-main-migration/
  package/              # independent PollyWAN clone
  integration/          # AREDN clone based on authoritative upstream main
  build-hap-ac2/        # disposable build clone, not the release source tree
  evidence/             # mode 0700; private raw logs and sanitized reports
  artifacts/
  BASELINES.json
  STATE.json
  NEXT_ACTION.md
```

Use `agent/pollywan-main-compat` in both repositories, or resume the existing branch when it is already the correct work. Preserve the old `agent/pollywan-r6` branch. Do not rebase the standalone package's unrelated history onto the AREDN repository.

First inspect remotes, branch tips, worktree status, and any uncommitted r29/r30 work in existing directories. Save private patches/copies before touching that work. Reconcile deliberate local changes into the chosen package baseline; do not silently leave them behind in a fresh clone.

Example initialization for **new, nonexistent destination directories**:

```sh
# Host shell: bash. Never run this blindly over an existing destination.
set -euo pipefail
umask 077
ROOT=/home/bill/src/pollywan-main-migration
mkdir -p "$ROOT/evidence" "$ROOT/artifacts"

git clone https://github.com/mathisono/AREDN_PollyWAN.git "$ROOT/package"
git clone --origin upstream https://github.com/aredn/aredn.git "$ROOT/integration"
git -C "$ROOT/integration" remote add origin git@github.com:mathisono/aredn.git

git -C "$ROOT/package" fetch origin main --tags
git -C "$ROOT/integration" fetch upstream main --tags
PKG_BASE=$(git -C "$ROOT/package" rev-parse origin/main)
AREDN_BASE=$(git -C "$ROOT/integration" rev-parse upstream/main)

git -C "$ROOT/package" switch -c agent/pollywan-main-compat "$PKG_BASE"
git -C "$ROOT/integration" switch -c agent/pollywan-main-compat "$AREDN_BASE"
printf 'PKG_BASE=%s\nAREDN_BASE=%s\n' "$PKG_BASE" "$AREDN_BASE"
```

Prefer independent clones initially. The inspected sync helper tests whether `.git` is a directory and therefore rejects normal linked worktrees whose `.git` is a file. Either use clones or deliberately fix and test that assumption first. It also suppresses rsync's exit status with `|| true`; correct error propagation before treating an empty dry-run as proof of equality. [S13]

Record in `BASELINES.json`: observed upstream-main SHA, chosen target-upstream SHA, package SHA, integration SHA, UTC timestamp, OpenWrt SHA after resolution, every feed SHA, target/subtarget, build config digest, compiler/toolchain identity, firmware kind, nightly build ID/source SHA, firmware filename and full SHA-256, and test-node identity when available. Record the actual full kernel-package identity and architecture independently of `uname -r`. Freeze these for the cycle. Never run an unrecorded `git pull` halfway through testing.

If the official nightly lags observed main, do not silently equate their commits. Resolve that difference in the next gate before finalizing the target/build. Retain both SHAs and the intervening diff.

## 3.1. Gate N0 — establish the nightly runtime baseline first

This gate is a prerequisite to runtime acceptance, not a prerequisite to safe source research.

1. Fetch authoritative `aredn/aredn` main and record its full SHA. Do not use the user fork's `origin/main` as upstream evidence.
2. Identify the actual published nightly for the exact lab board. Download and retain the firmware, its published checksum where available, and build/package metadata. Resolve its build commit to a full upstream SHA. AREDN documents that nightly filenames include a build date and commit identifier. [S15]
3. Record whether the nightly includes the main changes being targeted. A nightly may lag main. If its SHA differs, inspect and record that delta. Either explicitly select the available recent nightly's SHA for this cycle or build unmodified upstream main at the recorded target SHA. Do not claim testing of commits absent from the flashed image.
4. Name a private unmodified-main build accurately: `unmodified-main-build`, not an official downloaded nightly. If native integration patches are required, name that later image `patched-main-integration-build` and record its patch/integration SHA separately.
5. Rediscover the node over the existing authenticated route. Treat hostnames/IP addresses and historical firmware versions as hints only. Record board, running build/version, package architecture, full kernel identity, and installed PollyWAN version.
6. Require authorization and independent recovery before any flash. Follow current AREDN firmware procedures, not a copied legacy OpenWrt command. Current official guidance says CLI upgrades use `/usr/local/bin/aredn_sysupgrade`, not legacy `sysupgrade`; inspect the exact installed tool's usage and board procedure before invoking it. [S17]
7. Capture an **unmodified nightly AREDN baseline with PollyWAN absent or positively inert** before enabling changed code. Save sanitized bridge, VLAN, netifd, firewall, policy-rule, default-route, WAN-monitor, Babel and UI observations.
8. Re-read running firmware identity after any flash. A successful upload or boot is not sufficient; the running source/build must match the recorded test target.

### Prevent silent restoration of the old stable package

AREDN's package store can retain uploaded APKs and automatically reinstall packages after firmware upgrades. Inspect this on the selected build before migrating. [S16]

On the designated lab node, preserve private backups and inventories first. Then use the supported package-store/migration mechanism to ensure the old r29 APK, old USB kmods, generated stable-era include fragments, old service enablement and stale runtime state cannot silently restore themselves onto the nightly. Do not erase production configuration to achieve this. A clean nightly lab installation is the preferred first test; configuration migration is a separate lane.

Do not restore the whole old stable `/etc/config.mesh` tree or generated network files into nightly without validating each migration. Copy only reviewed user intent/settings through supported interfaces. Kernel modules require exact matching packages, not just the same board name or kernel release string.

### Required evidence and status

Keep `nightly-baseline.json`, the firmware checksum, relevant build metadata, and `native-before-pollywan/` captures under private evidence. Add these fields to `STATE.json`:

```json
{
  "scope": "r30-main-nightly-only",
  "stable_role": "r29-legacy-reference-only",
  "observed_upstream_main_sha": null,
  "target_upstream_sha": null,
  "firmware_kind": null,
  "firmware_build_id": null,
  "firmware_source_sha": null,
  "firmware_sha256": null,
  "node_board": null,
  "node_running_build_id": null,
  "nightly_runtime_gate": "NOT_RUN"
}
```

The nulls above are a schema example, not values to claim verified. Populate them only from actual commands/metadata. A stable node means `nightly_runtime_gate=NOT_RUN`, even if it previously passed all r29 tests. No stable compatibility CI lane or stable build is required for r30.

## 4. Milestone A — compatibility and ownership audit

Deliver `docs/main-compatibility-matrix.md` and `docs/adr/route-ownership-main.md`.

Read the existing r29 plan, Makefile, install/remove hooks, sync helper, verifiers, manager, port, route-cache, health, speed and telemetry code. Classify each requirement as already implemented, partially implemented, missing, or unverified. Preserve the existing upstream HTTPS and telemetry work rather than rebuilding it from the older prompt. [S2, S3, S5]

Inspect all changes since the previous recorded audit baseline, not just July PRs. Use git ancestry for inclusion in the pinned build; PR numbers or merge dates alone are not build identity.

```sh
# Run in the integration source clone after baselines have been recorded.
git log --oneline --date=iso-strict "$AREDN_BASE" -- \
  files/usr/local/bin/node-setup \
  files/etc/hotplug.d/iface \
  files/usr/local/mgr \
  files/usr/share/ucode/aredn \
  files/etc/config.mesh \
  files/etc/local/mesh-firewall \
  Makefile openwrt.mk configs

gh pr list -R aredn/aredn --state merged --limit 100 \
  --json number,title,mergedAt,mergeCommit > "$ROOT/evidence/recent-prs.json"
```

Review these known changes and later changes found at execution:

| Area | Current evidence and required action |
| --- | --- |
| Port configuration | #2918 adds explicit `none` for intentionally empty networks; empty/default and deliberately disabled are different. Test both. [S6] |
| Native WAN monitor | #2916 adds `wan_proto` gating. Current monitor is bound to `br-wan`, manipulates table 28, and can manage two /1 routes. Multi-WAN ownership must be explicit. [S7] |
| Hotplug routing | `11-meshrouting` separately adds/removes tables 27/28; audit it alongside the daemon. It inserts table 23 before table 22. [S8] |
| WireGuard | #2912/#2914/#2915 change per-tunnel MTU and migration; actual generation limits tunnel MTU using WAN MTU. Test switching to a lower-MTU uplink. [S9] |
| Babel restarts | #2920/#2921 change reset thresholds and hard-restart state handling. Do not duplicate or repeatedly trigger these mechanisms. [S10] |
| Low-memory behavior | #2902/#2903 change qdisc behavior on low-memory devices and avoid redundant replacement. Preserve upstream behavior. [S11] |
| RF/LQM/UI | Recheck #2814/#2816/#2817/#2818 plus #2907/#2908/#2923/#2925/#2926. In particular #2923 now classifies `br-wifi` as RF; do not freeze the earlier RRF interpretation. [S12] |

For every relevant route/table/rule, identify all writers and readers: native WAN monitor, native hotplug, netifd, Babel, PollyWAN manager, route-cache, daemon, install/upgrade/remove hooks, UI handlers and command-line tools. Include lifecycle events, route protocol, prefixes, preferences and lock ownership.

**Gate A:** no unknown table-28 writer, no unidentified table-23 policy, and every proposed modification linked to a specific source function or observed failure.

## 5. Milestone B — native-manager integration design

The nightly direction is **native WAN management with a single export owner**, preserving PollyWAN's behavioral contract. It is not “run both controllers and hope their routes agree.” [S2]

Preferred design: extend or delegate through AREDN's native UCode WAN manager using a small, explicit, feature-detectable integration contract. PollyWAN supplies configuration, per-WAN health/classification, UI and cached status. The native controller owns the export lifecycle. Keep short-lived shell helpers only where useful; do not run a second permanent route-writing daemon.

The exact module/hook API must follow the inspected manager lifecycle. Document its name, version, trust boundaries, inputs, outputs and fallback behavior in the ADR before coding. Source adapters must be bounded, root-owned and validated; do not execute arbitrary commands from JSON or HTTP parameters.

Important packaging boundary:

- A needed change to native `wan_monitor.uc` or hotplug belongs in a separately reviewable AREDN integration commit **outside** `packages/aredn-multiwan`.
- The PollyWAN APK must not silently overwrite those base-firmware files or sed-patch them during installation.
- First test the actual unmodified nightly/native behavior and document the proven missing integration contract. If no safe package-owned handoff is possible and a native hook is necessary, prepare that hook as a separate reviewable integration patch and, for an authorized lab test, an explicitly identified **patched main-derived integration firmware** from the same upstream baseline. A pass on patched firmware is not a pass on the official unmodified nightly. Do not broaden the core changes or modify sysinfo.
- A stock nightly without the necessary hook must report unsupported integration and remain non-mutating. Do not silently start the old controller beside the native one.
- The future sysinfo hook remains deferred even if a native WAN hook is required now.

Cover takeover, startup, shutdown, watchdog failure, unexpected process death, package upgrade, rollback and removal. Stop new route writes during handoff; do not allow a gap in tunnel isolation. Preserve administrator monitor settings and restore only values this integration actually owns. Do not erase legitimate later user changes.

### Route behavior contract

| State | Required behavior |
| --- | --- |
| Package disabled | Preserve ordinary AREDN behavior and administrator settings; no PollyWAN ownership. |
| Selected local WAN healthy | Maintain the desired local route and publish only when upstream health, policy and recovery requirements permit. |
| First completed upstream-failure decision | Withdraw this node's qualified export immediately; retain local selection only while configured local hysteresis allows. |
| Failure threshold reached | Select a freshly qualified fallback or withdraw local selection. |
| Recovery | Count new successful observations, not repeated readings of one cached success; respect recovery hold-down. |
| No state change | No unnecessary route/rule writes, flash commits or Babel restarts. |
| Remote default used | Preserve and distinguish DtD table 23 from remote Mesh table 22; never mislabel either as local WAN3. |

Inspect and test `/0`, `0.0.0.0/1` and `128.0.0.0/1`. Removing only `/0` does not prove all default-like paths have disappeared. Preserve intentional stock semantics; ensure no alternate locally exported prefix bypasses PollyWAN's qualification or tunnel restrictions. Do not globally flush unrelated routes.

Withdrawal is not proof that all Internet traffic from another mesh node stops: it may legitimately use another gateway via table 23 or 22. Test withdrawal of **this exit** and subsequent path selection separately.

## 6. Milestone C — port, network and firewall compatibility

Prefer the current AREDN configuration APIs and minimal package-owned additions over wholesale replacement of generated `br0` configuration. If the existing `.network.user` includes are retained, prove the current generator consumes them correctly in a disposable environment. File presence or a zero return code alone is insufficient.

Implement/test:

- Missing/default port configuration versus explicit `none`; no accidental restoration of disabled WAN/LAN ports.
- Ethernet WAN1 versus actual radio WAN-client mode. Mesh station mode is not an Internet WAN. Resolve the operational `l3_device` from netifd rather than guessing from a radio label.
- Keep legitimate `wifi0`/`wifi1` adhoc behavior where current upstream still generates it. Do not blindly replace every occurrence with `wifi`.
- Preserve `br-wifi`, `br-fast`, RF VLANs, `bridge_isolate`, custom VLANs, XLinks, tagged DtD and remote-RF behavior.
- Audit the effective RF VLAN and custom Ethernet VLANs against PollyWAN's reserved VLANs; reject unsafe collisions before apply.
- Ensure AREDN's RF-VLAN generator sees the same intended DtD ports as PollyWAN; stale base settings must not assign RF to the wrong physical port.
- Keep `wifi`/`fast` out of WAN candidates and the WAN firewall zone.
- Verify effective firewall membership/forwarding/NAT of WAN2 and dynamic WAN3, not just a `zone=wan` input field.
- Preserve upstream qdisc policies and avoid broad firewall reloads for status changes.
- Apply/confirm/rollback restores both files and owned UCI state; opening a dialog and pressing Cancel makes no changes.

Use exactly one authoritative rollback transaction for port changes. Do not layer competing watchdogs. Test confirm-at-deadline races, abandoned sessions, interrupted service restarts and firmware-version changes in backups. Never restore an old generated configuration into a different firmware blindly.

## 7. Milestone D — routing, probes, tunnels and telemetry

Retain r29's source-bound external HTTPS health gate, diagnostic gateway ping, primary/secondary endpoints, health-versus-speed separation, recovery/export damping, same-class stability and package telemetry. Verify the implementation rather than assuming the previous report proves it. [S5]

Specific compatibility requirements:

1. Check actual policy rules before/after tests. A source-bound socket alone is not sufficient proof of private-table egress. An empty private table must not fall through to the other WAN and yield false health.
2. Distinguish interface existence, route validity, gateway response, fresh upstream result, selection health, export eligibility and installed route state.
3. Invalidate cached health/speed data after source, gateway, interface generation, tunnel path or routing-contract changes—even if the device name stays the same. A firmware migration must not count stale samples as new successes.
4. Test identical-subnet and identical-public-IP WANs without falsely rejecting them. Prove egress using route lookup plus lab counters/capture.
5. Keep DNS diagnosis separate from actual external reachability and preserve TLS verification/SNI. Do not introduce insecure TLS or a new dependency merely to make a test pass.
6. Source-bound HTTPS failure tests must isolate one WAN in the lab. Do not replace a global health URL on the real gateway and assume it only breaks WAN1.
7. Use monotonic time for local intervals/hold-down where available. Publish UTC separately; GPS/NTP clock changes must not cause flap loops.
8. Separate WireGuard outer transport from inner tunnel traffic. Outer packets must use an eligible local uplink rather than RF/remote-default recursion; inner mesh routes must remain usable while default Internet transit from tunnel ingress remains blocked.
9. Test per-tunnel configured MTU and the actually selected uplink MTU during Ethernet/USB/Wi-Fi failover. Never silently overwrite user tunnel MTUs or keys.
10. Keep node-to-node iperf3 labeled as path throughput, not public-Internet proof. Require the intended tunnel and its underlay; mark unavailable server tests untested.
11. Preserve the public package CGI path and schema. Serve bounded, atomically replaced cached JSON only. Report absent/stale state honestly; do not treat missing data as proof the controller is disabled or an exit works.
12. Preserve existing sysinfo output unchanged. Do not claim Topologr or MeshMap already consumes the package endpoint unless verified.

Keep one validated representation of route identity and qualification shared between command-line actions, daemon/controller and UI. User actions may select a WAN, but may not bypass upstream/export safety by passing a literal `healthy=1`.

## 8. Milestone E — regression and integration tests

Run existing verifiers first; record baseline failures separately from migration regressions. Repair recoverable issues with focused commits. Do not delete safety tests, grant CI broad write access or regenerate manifests inside CI simply to get green.

Use real shell/UCode functions and generated configuration in tests, not only a separately written Python policy model. Kernel-routing tests use isolated namespaces; firmware generation/UI tests use the actual pinned UCode environment with controlled filesystem and service stubs. An x86/QEMU fixture can validate logic, not certify hAP switch or USB hardware.

Minimum matrix:

| ID | Scenario | Acceptance |
| --- | --- | --- |
| C00 | Actual nightly baseline | Running board/build/commit matches the target; unmodified native behavior captured; no active r29 controller or automatically restored old modules. |
| C01 | Clean r30 install on nightly, disabled | No package network/radio/GPS changes; valid UI and unknown/disabled telemetry as appropriate. |
| C02 | Explicit stable-r29 to nightly-r30 configuration migration | Preserve old data without executing r29 on nightly; inhibit automatic package restoration; migrate reviewed settings once on matching nightly, with one routing owner and no unexpected port restore. This is migration coverage, not stable compatibility. |
| C03 | Empty/default/`none` | Exact current AREDN semantics; no port resurrection. |
| C04 | WAN1 Ethernet / Wi-Fi WAN / mesh STA | Correct logical WAN; RF never misidentified. |
| C05 | WAN2 role apply/confirm/rollback/Cancel | Actual netifd device, DHCP and private routes; unaffected LAN/DtD/XLink/RF. |
| C06 | Android tether with/without drivers | WAN3 DHCP/table 103 with support; optional unavailable state without support; no GPS/serial access. |
| C07 | Gateway alive, upstream blackholed | Raw upstream false; export withdrawn after failed decision; local failure hysteresis independent. |
| C08 | Standby cache stale, address changes, all links fail | No false qualification, no fallback through another WAN, no stuck permanent lock. |
| C09 | Same class / promotion / recoveries | Stable selection and measured damping; only new observations advance streaks. |
| C10 | Identical healthy cycles | No package-induced no-op route churn or Babel restart. |
| C11 | Native monitor/hotplug/restart/upgrade races | One table-28 authority; no resurrected `/0` or split-default bypass. |
| C12 | DtD default 23 and mesh default 22 | Distinct precedence/ownership; no deletion or re-export as local. |
| C13 | Tunnel underlay/ingress/MTU changes | No tunnel recursion or Internet transit leak; mesh payload and legitimate transport still work. |
| C14 | CGI/HTMX/API/authentication | Authenticated UI renders; public telemetry is valid cache-only JSON; malformed/missing/stale state handled safely. |
| C15 | Restart/reboot/uninstall | Known management path recovers; settings/state match documented ownership. |
| C16 | Resource limits | Bounded memory/processes/files, no OOM or fork storm; no throughput-test starvation of health decisions. |

Capture exact command, exit status, timestamps, tested SHAs and sanitized evidence for every gate. Do not count a 401/403 response as successful authenticated rendering. Do not count ping to loopback as upstream or mesh connectivity.

## 9. Milestone F — build, sync and provenance

Create a clean build tree from the pinned integration source, never reuse the old 4.26.7.0 `staging_dir`, target build products or kernel modules. A common OpenWrt selector does not make the resulting ABI identical. [S4]

The inspected upstream Makefile uses `TARGET=ipq40xx-mikrotik` and `TARGET=ath79-mikrotik`. Verify the actual target config/profile still exists before invoking a build. The root `prepare` target assembles `.config` from the AREDN target files; a standalone manual `.config` edit may be overwritten. [S14]

Restore and check host tools as a batch: GNU awk including `asort()`, quilt, BusyBox, rsync, make, compiler/build prerequisites, Python for tests, and the OpenWrt host-tool chain. Recover user-space tool installations or a pinned builder container when sudo is unavailable; do not stop for every ordinary missing tool. Record the container digest when used.

Suggested sequence in the **new disposable build clone**, adapted to actual Makefile prerequisites:

```sh
make TARGET=ipq40xx-mikrotik feeds-update
# Register/install the package feed using this tree's supported feed mechanism.
make TARGET=ipq40xx-mikrotik prepare V=s
```

Ensure the package feed is actually indexed in `openwrt/tmp/.packageinfo`, dependencies resolve, and `CONFIG_PACKAGE_aredn-multiwan=m` survives defconfig. Do not mistake a symlink's existence for indexing. Prefer repairing a feed path; use a documented build-only real copy if necessary, with a content/mode equality check.

Discover the generated target before calling it. For example, only after discovery confirms it:

```sh
# Run with bash on the build host; log outside the source tree.
set -o pipefail
make -C openwrt package/feeds/arednlocal/aredn-multiwan/compile V=sc -j1 \
  2>&1 | tee "$ROOT/evidence/package-build.log"
rc=${PIPESTATUS[0]}
printf 'BUILD_RC=%s\n' "$rc"
test "$rc" -eq 0
```

Do not run `make openwrt-clean` repeatedly as a generic recovery action. Do not suppress missing host-tool errors such as libdeflate-gzip; complete the required host build dependencies.

Build hAP ac2 first. Add hAP ac lite and ac3 build/fixture lanes where supported; physical validation remains separate. Do not expand runtime board support to SXTsq or another device merely because its memory size is mentioned in a review.

Treat the next development package as r30 only after checking that the release number is unused. Record package version and tested upstream/integration SHAs. Subsequent installed revisions must have unique release numbers or supported prerelease version identifiers; do not silently replace an already published version.

Preserve the root-to-subtree synchronization contract, executable modes, and content-manifest verification. Update `SYNC_SOURCE` to the actual development branch contract rather than falsely leaving `main`/`agent/pollywan-r6` recorded. Run sync/check in both directions conceptually, but copy only from the declared authoritative package tree. Native integration changes remain outside the copied subtree.

Generate hashes from actual files. Inspect APK format, architecture, files and declared/transitive dependencies with the matching build's APK tooling. Tests, repository credentials and host-only Python must not appear as installed runtime content. New native-core hooks belong to the matched firmware, not hidden file replacements inside the APK.

Optional USB-driver APKs must match exact firmware/kernel package identity and complete dependency closure. Never reuse the earlier companion ZIP based on filename, kernel release or a report alone. Missing/unverified driver artifacts make WAN3 hardware testing pending; they do not block non-USB compatibility work.

## 10. Milestone G — controlled deployment and hardware validation

Before any live change, rediscover board, firmware source/build ID, full kernel package identity, installed PollyWAN release, free overlay, native services and management paths. The historical hub5 address and key route through MSE-88 are hints, not assumptions.

Read-only examples, run through the established protected SSH route:

```sh
ubus call system board
cat /etc/mesh-release
uname -r
apk info -e aredn-multiwan
apk info -a kernel
df -k /overlay
ip -4 rule show
ip -4 route show table all
ubus call network.interface dump
/usr/local/bin/wan-sla status
/usr/local/bin/wan-port-manager status
```

Check command availability; preserve failures as evidence rather than invent output. Avoid raw `wg showconf`, private keys, passwords or unredacted full configuration in public logs. Backups containing secrets remain local/private with restrictive permissions.

Require Gate N0 first: a designated lab hAP ac2 actually running the matched nightly/main-derived firmware, with original native behavior captured before PollyWAN is enabled. An old stable node is not an alternate acceptance target. If flashing is needed, obtain authorization and establish recovery before doing it. When the baseline is a patched main-derived integration build, label every resulting test as patched-firmware evidence; do not call it official-nightly compatibility.

Before installing r30 on that nightly, run the matching `apk add --simulate --no-network --allow-untrusted` against the deliberate local package set. Reject replacement kernels, unexpected removals, downgrades and incompatible dependencies. Inspect actual upgrade hooks before assuming only the UI restarts. Test clean installation first. Test reviewed r29-to-r30 configuration migration separately, without running the old stable-targeted r29 package on nightly and without relying on automatic package-store replay.

Run C00–C16 as applicable on the matching nightly/main-derived lab image, with a baseline capture before each stateful phase and a verified restore afterward. Start with two separate test upstreams; same-subnet tests are an additional lane, not independent-ISP failover evidence. Keep WAN1/management protected during fault injection. Packet capture/counters must prove the tested WAN and a remote peer's actual route.

For table-28 export testing, use the operator's sharing policy or a disposable test gateway. Do not silently enable mesh sharing on the live RF network. Measure raw failure-decision time, withdrawal time, local failover time and re-export time. Do not equate “immediate after a failed check” with instantaneous detection during a long timeout.

Soak after the functional suite: at least six measured hours on the lab hAP ac2 and, when available, a longer test on a supported 64 MB hAP ac lite. Use `/proc/meminfo` MemAvailable as well as per-process RSS/PSS, peak process count, CPU, cycle duration, lock age and bounded `/tmp` growth. A running or unavailable soak is reported as RUNNING or NOT RUN, never PASS. Do not promise completion outside the actual execution session.

## 11. Documentation, CI and upstream drift

Deliver/update:

```
docs/r30-main-development-plan.md
docs/main-compatibility-matrix.md
docs/adr/route-ownership-main.md
docs/main-migration-runbook.md
docs/multiwan-verification.md
README.md
SYNC_SOURCE
```

Keep the README's GUI installation first. Clearly distinguish a package requiring matched integration firmware from one verified on unmodified nightlies. Document exact tested source revisions, optional WAN3 support, table-23/table-22 semantics, migration/rollback, and deferred sysinfo integration. Do not copy unsupported throughput claims or old bundle hashes.

CI must check the actual committed source without modifying it: shell/UCode checks, regression suite, package-install manifest, deterministic source manifest, integration equality, and the pinned main/nightly build lane. Do not create or require a stable compatibility lane for r30. Keep old r29 results as historical reference only. CI/mocks/builds prepare for runtime acceptance; they cannot mark actual nightly hardware compatibility as passed.

Track upstream drift with a separate scheduled/read-only comparison or a manually run command. Changes to the pinned SHA require a documented refresh and re-execution of affected tests. Do not auto-merge new upstream commits or automatically flash every nightly. Retain the firmware, configs, feed SHAs, APKs and checksums for each completed cycle because nightly package sets are not permanent. [S15]

## 12. OpenClaw progress and finish contract

After each phase, update `STATE.json` and `NEXT_ACTION.md` with the actual SHAs, completed gates, exact failing command if any, safe node state, evidence paths and next command. Commit logical source changes; keep raw evidence outside the repo. When reconnecting, read these files, verify their observations against the repository/processes, then resume the first incomplete gate.

Continue through recoverable code, feed, toolchain and test-harness problems without requesting another prompt. Stop only the unsafe dependent phase when credentials, matching firmware, hardware, recovery access or ownership contracts are missing; continue independent work. Do not repeatedly label ordinary missing tools “nonrecoverable.”

Prepare scoped commits such as:

```
Record pinned AREDN main compatibility contract
Handle explicit empty port assignments
Integrate native single-owner WAN export control
Preserve default-route and tunnel policy across main changes
Add current-main generation and lifecycle regression tests
Document r30 migration and tested compatibility
```

Push branches and open draft PRs in the user's repositories. Clearly distinguish source-complete, build-complete and hardware-validated status. A green source verifier alone is not a release qualification.

Final report must include:

- New package and integration branch/commit IDs; pinned upstream and feed SHAs.
- Native AREDN files changed separately from the package subtree.
- Single-owner proof including boot/hotplug/upgrade/restart cases.
- Table 23 and 22 handling; `/0` and split-default checks.
- Port/firewall/RF/XLink/Cancel/rollback results.
- Source-bound blackhole, damping, no-op route and tunnel/MTU results.
- APK path, size, computed full SHA-256 and dependencies; actual flashed nightly filename/build/source SHA/kernel identity; observed main SHA and any untested delta.
- Unmodified-nightly baseline versus patched-integration results, clearly separated; proof old stable r29 did not auto-reinstall or run on nightly.
- GUI and package-telemetry results; sysinfo unchanged.
- Hardware/soak results explicitly split into PASS, FAIL, NOT RUN or RUNNING.
- Rollback/current node state, limitations and next actionable step.

Use one accurate status:

```
POLLYWAN_R30_READY_FOR_NIGHTLY_TEST
POLLYWAN_R30_NIGHTLY_COMPAT_VALIDATED_AT_<UPSTREAM_SHORT_SHA>
POLLYWAN_R30_PATCHED_MAIN_VALIDATED_AT_<UPSTREAM_SHORT_SHA>_<INTEGRATION_SHORT_SHA>
POLLYWAN_R30_NIGHTLY_COMPAT_BLOCKED_<SPECIFIC_GATE>
```

Use the READY status only when its source/build requirements genuinely passed and matching-nightly runtime work remains. The NIGHTLY_COMPAT_VALIDATED status requires actual tests on an unmodified official nightly or unmodified main-derived build at the recorded SHA (identify which). PATCHED_MAIN_VALIDATED explicitly does not claim stock-nightly compatibility. If a required acceptance gate is NOT RUN, return READY with its remaining gates instead of a validated status.

Do not report compatibility with all future main commits. No stable support qualification, production release or merge is part of this handoff by default.

## Source register

The following were inspected while preparing this plan; recheck at the pinned execution baseline. URLs are included for independent retrieval, not as evidence that a physical node was tested.

- [S1] AREDN main snapshot: `https://github.com/aredn/aredn/commit/5105916f4449d98f2c46acecf6c9e1e5780065dc`
- [S2] Existing r29/r30 handoff: `https://github.com/mathisono/AREDN_PollyWAN/blob/358cd719dbca2a09a63ae0174340f58f7ef90a89/docs/r29-development-plan.md`
- [S3] Package Makefile: `https://github.com/mathisono/AREDN_PollyWAN/blob/358cd719dbca2a09a63ae0174340f58f7ef90a89/Makefile`
- [S4] OpenWrt selector: `https://github.com/aredn/aredn/blob/5105916f4449d98f2c46acecf6c9e1e5780065dc/openwrt.mk`
- [S5] Existing health/telemetry code: `https://github.com/mathisono/AREDN_PollyWAN/blob/358cd719dbca2a09a63ae0174340f58f7ef90a89/files/usr/local/bin/wan-sla`
- [S6] Explicit empty-network change: `https://github.com/aredn/aredn/pull/2918`
- [S7] Native monitor and gating: `https://github.com/aredn/aredn/blob/5105916f4449d98f2c46acecf6c9e1e5780065dc/files/usr/local/mgr/wan_monitor.uc` and `https://github.com/aredn/aredn/pull/2916`
- [S8] Native route ownership and order: `https://github.com/aredn/aredn/blob/5105916f4449d98f2c46acecf6c9e1e5780065dc/files/etc/hotplug.d/iface/11-meshrouting`
- [S9] Current network generation and tunnel MTU: `https://github.com/aredn/aredn/blob/5105916f4449d98f2c46acecf6c9e1e5780065dc/files/usr/local/bin/node-setup` and `https://github.com/aredn/aredn/pull/2914`
- [S10] Babel lifecycle: `https://github.com/aredn/aredn/pull/2920` and `https://github.com/aredn/aredn/pull/2921`
- [S11] Queue handling: `https://github.com/aredn/aredn/pull/2902` and `https://github.com/aredn/aredn/pull/2903`
- [S12] Latest RF classification and radio API history: `https://github.com/aredn/aredn/pull/2923`, `https://github.com/aredn/aredn/pull/2925`, `https://github.com/aredn/aredn/pull/2926`
- [S13] Current synchronization helper: `https://github.com/mathisono/AREDN_PollyWAN/blob/358cd719dbca2a09a63ae0174340f58f7ef90a89/tools/sync-integration.sh`
- [S14] Current AREDN build entry point: `https://github.com/aredn/aredn/blob/5105916f4449d98f2c46acecf6c9e1e5780065dc/Makefile`
- [S15] Official nightly/stable guidance: `https://docs.arednmesh.org/en/latest/arednGettingStarted/downloading_firmware.html`

- [S16] Official package-store behavior on firmware upgrades: `https://docs.arednmesh.org/en/latest/arednGettingStarted/node_admin.html` (Package settings; checked 2026-09-23).
- [S17] Official current firmware-upgrade procedure: `https://docs.arednmesh.org/en/latest/arednHow-toGuides/firmware_tips.html` (CLI AREDN upgrade tool; checked 2026-09-23).
