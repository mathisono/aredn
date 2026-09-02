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
4. Keep the preserved stable release at `0.1.0-r29`; corrective work uses APK
   version `0.1.0.29.5` with successive integer APK package revisions while
   product release R29.5 is reviewed, built, and validated on stable firmware.
5. Run standalone verification, integration synchronization/check, and
   integration verification. Record root-only verification as pending unless it
   actually succeeds.
6. Refresh or reconstruct the stable hAP ac2 build tree before compiling. Never
   use a nightly build tree for the stable r29 APK.
7. Back up hub5 and validate the development APK on its stable firmware.
8. After r29 validation, freeze a fresh authoritative nightly commit and begin
   r30. Do not mix the nightly source adaptation into the stable r29 APK.

## r29.5 release scope

Development for these corrective changes continues on `release/r29.5`. The
explicit Ethernet and Selection Policy apply controls are R29.5 changes; they
are not part of the published R29 APK.

### R29.5 pre-build checkpoint

- explicit Save/apply controls and visible `Done` warnings are implemented;
- ordered local/Remote Mesh WAN routing and recovery damping are implemented;
- Remote Mesh WAN exit-node telemetry is present in the dashboard and both the
  Connection Speed Test card and dialog;
- the initialization commit-order bug is fixed and required defaults are
  verified after the persistent commit;
- runtime telemetry and the dashboard identify product release `R29.5`; the APK
  uses dotted product version `0.1.0.29.5` plus integer APK package revision
  `r1`, because APK reserves `-rN` for the package revision;
- standalone verification, stable-tree synchronization/build, and independent
  live validation on both hAP ac2 nodes remain release gates.

### R29.5 build and two-node deployment checkpoint

- Review found and corrected two release blockers before the two-node rollout:
  the dashboard runtime summary was reading schema-1 health fields from
  schema-2 status, and an APK upgrade started rather than restarted the existing
  procd instance, leaving the old daemon in memory. Commit `32b67bb` adds the
  upgrade restart and its static regression guard.
- Stable AREDN `4.26.7.0` package build completed from source commit `7ec539c`
  for `ipq40xx/mikrotik`, architecture `arm_cortex-a7_neon-vfpv4`, kernel
  `6.12.94`. The installable APK is
  `aredn-multiwan-0.1.0.29.5-r1.apk`, SHA-256
  `ecc320d8f72ea6eae1cd8766672eaab4eca029c95fb6e889ffdc66dad11d1224`.
- Standalone and synchronized integration verification pass, including the
  ordered-route model, Remote Mesh WAN resolver mock, markup/template balance,
  and status endpoint fallback. The root-only port-manager, route-cache, and
  tunnel-guard chroot mocks remain pending because the build account does not
  have passwordless sudo.
- `KJ6DZB-WSB-hub5` upgraded successfully with PollyWAN still enabled. The APK
  upgrade replaced the old daemon automatically; live status reports product
  `0.1.0-r29.5`, ordered mode, WAN 1 healthy and active, and all four candidates
  including disabled Remote Mesh WAN. Radio modes and port-role opt-in state
  were preserved.
- `KP4DJT-HAP-AC2-VAN` upgraded successfully with PollyWAN still disabled. It
  remains inert with no SLA daemon, managed-port marker, or package-created
  default route. Its existing WAN default, radio mode, GPS service, and
  `/dev/ttyACM0` device were preserved.
- Pre-upgrade backups and checksummed post-upgrade snapshots are stored on
  MSE-88 under `/home/mat/pollywan-backups/`. The persistent setup/GPS UCI
  snapshot is byte-for-byte unchanged on both nodes.
- Neither node currently has a table-22 remote default, so positive live display
  of a Remote Mesh WAN exit nodename remains to be exercised when such an exit
  is reachable. The no-exit live state and positive/negative resolver mocks
  pass.

### R29.5 r2 UI and live-test checkpoint

- The Route Policy Setup dialog keeps its explicit `Save and apply policy`
  control but removes the redundant explanation about the footer `Done`
  button. Runtime decision and candidate telemetry live on the dashboard
  instead of inside the configuration dialog.
- The Remote Mesh WAN dashboard card now owns its exit-node, candidate,
  eligibility, controller-decision, route, and last-update status details.
- The dashboard header reports one current operating state derived from real
  controller signals. It covers disabled, starting, evaluating, paused, port
  change pending, failure pending, failed over, recovery pending, recovered,
  healthy, degraded, no eligible WAN, configuration error, and stale status.
- Route Policy Setup and Connection Speed Test use the same wide dialog layout
  as hAP Ports & XLinks. Speed-test refreshes update only the dialog body and
  preserve its vertical scroll position.
- APK `0.1.0.29.5-r2` passed standalone and synchronized checks, built on the
  stable tree, and upgraded successfully on hub5 and KP4DJT. The live KP4DJT
  table-22 route exposed a resolver defect: AREDNlink aggregates many node
  sections in one hosts file, but the r2 resolver inspected only its first
  section. The routing path remained healthy, but the exit name displayed as
  unknown, so r2 is not the final R29.5 candidate.

### R29.5 r3 Remote Mesh exit correction

- The exit resolver now evaluates every AREDNlink node section and correlates
  each primary `/32` with the Babel originator ID of the installed table-22
  default.
- The resolver mock uses a realistic multi-section hosts file with the wanted
  exit after an unrelated node, preventing regression to the first-section
  behavior.
- Stable AREDN `4.26.7.0` build from source commit `a01d57d` completed for
  `ipq40xx/mikrotik`, architecture `arm_cortex-a7_neon-vfpv4`, kernel
  `6.12.94`. The 66,140-byte artifact is
  `aredn-multiwan-0.1.0.29.5-r3.apk`, SHA-256
  `40f7950b08d081e41b839761707ff394f36588aaea628a1c12583fedcf55d55f`.
- Standalone verification, synchronized integration verification, package
  simulation, metadata inspection, and the multi-section resolver mock pass.
  The root-only port-manager, route-cache, and tunnel-guard chroot mocks remain
  pending because the build account does not have passwordless sudo.
- Both hAP ac2 nodes upgraded independently from r2 to r3 with PollyWAN still
  enabled, port-role management and WAN3 still disabled, and their complete
  setup/radio, XLink, PollyWAN, Mesh WAN, and GPS invariance snapshots unchanged.
  Both controllers are running with WAN1 healthy and active.
- KP4DJT now reports the live table-22 exit as `KP4DJT-hAPac3-home`, origin
  `10.77.51.13`, next hop `169.254.225.156` over `br-dtdlink`, proving the exit
  nodename path in installed telemetry. Its GPS process and `/dev/ttyACM0`
  device remain present. Hub5 currently has no table-22 default and correctly
  reports no Remote Mesh exit.
- Checksummed pre-r3 backups are stored separately on MSE-88 at
  `/home/mat/pollywan-backups/KJ6DZB-WSB-hub5/20260821T052504Z-r29.5-r3-preupgrade`
  and
  `/home/mat/pollywan-backups/KP4DJT-HAP-AC2-VAN/20260821T052504Z-r29.5-r3-preupgrade`.

### R29.5 r4 route-order persistence correction

- KP4DJT's r2 and r3 pre-upgrade snapshots both contain the default ordered
  policy, and their install invariance comparisons are byte-for-byte equal.
  The redeployments therefore preserved the UCI state they received; the
  operator's earlier route-order edit had never been committed.
- The Route Policy Setup dialog previously exposed four independent selectors
  while requiring every route to appear exactly once. Changing one selector to
  a route already present elsewhere produced a duplicate, caused the server to
  reject the entire save, and then re-rendered the persisted default order.
- Route-order selectors now swap positions automatically, so each edit remains
  a complete permutation that can be saved. The dashboard shows the complete
  saved order instead of only the first choice.
- The initializer's upgrade contract is covered explicitly: `set_default`
  writes only absent values, and an existing `selection_mode=ordered` bypasses
  migration. Thus an already-saved r29.5 route order remains untouched during
  an APK upgrade.
- The r4 APK must pass standalone and synchronized integration verification,
  then demonstrate on KP4DJT that a non-default saved order survives reinstall.

### R29.5 r5 GUI persistence and rollback correction

This checkpoint established the verified writer and exact transaction model;
its separate port opt-in controls were superseded by r7.

- Every PollyWAN settings dialog now uses one ownership-aware UCode writer. It
  prepares AREDN change tracking, repairs the `aredn.multiwan` section, checks
  set/commit results, and verifies every submitted value through a new
  `/etc/config.mesh` cursor before starting a controller or apply operation.
- Route Policy Setup is the sole owner of controller and WAN candidate enable
  flags. Ethernet Roles owns only its opt-in and port/DtD assignments; the USB
  dialog owns only `wan3_device`; Connection Speed Test owns only speed-test
  settings. Cross-dialog last-writer-wins behavior is removed.
- Ethernet apply now performs a checked preflight and surfaces launch or
  validation errors. The previous configuration is staged before a direct
  Save-and-Apply write.
- Timed rollback restores the exact pre-apply managed files, marker, and
  port-role UCI values. **Restore AREDN defaults** remains a separate operation
  and no longer silently disables WAN2 or WAN3 policy choices.
- Static guards cover ownership and verified-write use. The root-only port
  manager mock now exercises managed-to-managed rollback and preservation of
  WAN2/WAN3 flags during explicit Ethernet restore.

### R29.5 r6 persistent role reconciliation correction

This checkpoint repaired RapidConfig reconciliation; its separate GUI
Save/Apply/Restore presentation was superseded by r7.

- Live testing found `port_roles_enabled=1` after a configuration restart while
  the managed-port marker and files were absent. The dashboard incorrectly
  translated the saved flag alone into `ready`, and boot reconciliation treated
  the same mismatch as inactive instead of applying it or reporting an error.
- **Save roles** now persists and verifies role/DtD choices without changing
  activation. **Apply with rollback** is the sole GUI enable action and
  **Restore AREDN defaults** is the sole GUI disable action.
- A complete non-interactive configuration with `port_roles_enabled=1`, such as
  a RapidConfig restore, is authoritative during service reconciliation. The
  manager validates it, preserves the current AREDN files, arms rollback before
  network regeneration, and confirms only after regeneration succeeds. Invalid
  or failed first activation is disabled persistently and reported as an error.
- The per-apply file and UCI snapshot remains persistent while the timer token
  is temporary. After a reboot or interrupted process loses `/tmp`, reconcile
  restores and verifies the exact pre-apply values before normal operation. An
  orphaned enabled/no-marker snapshot is normalized to disabled instead of
  being displayed as active.
- The Ethernet dashboard and dialog now require both the persistent enable flag
  and the managed marker before reporting `ready` or `managed`. The root-only
  harness covers valid and invalid persisted activation plus interrupted timed
  and non-interactive recovery.

### R29.5 r7 release-candidate GUI and ownership checkpoint

- All four settings dialogs use standard AREDN **Cancel** and **Done** footer
  controls plus one explicit **Apply** for their settings. The port dialog is
  renamed **Ports & XLinks** and uses the native compact port matrix. The
  redundant WAN ownership, local-candidate policy, and port-management enable
  controls are removed.
- Route Policy Setup is the sole authoritative master and candidate-enable
  page. The Ports & XLinks page owns only port, DtD, and XLink assignments. Its
  internal `port_roles_enabled` state is synchronized to the master: enabling
  PollyWAN claims all Ethernet roles and disabling it restores AREDN defaults.
- A disabled node may save and verify its future port layout, avoiding a setup
  deadlock when WAN 2 needs a port before the master can be enabled. GUI enable
  stages the disabled state before committing policy, applies in a timed
  transaction, and requires confirmation. Timeout restores the exact master
  enable, role/DtD options, include files, marker, and XLink UCI file. Service
  restart during the window preserves the pending token instead of
  auto-confirming it.
- XLink writes use the same centralized persistent UCode module as PollyWAN
  settings. The commit is checked and every submitted XLink field is reread
  through a fresh `/etc/config.mesh` cursor. Any set, commit, verification,
  validation, or launch error is displayed and restores the staged snapshot.
- Direct Apply no longer creates a dangling AREDN-wide pending-change snapshot.
  PollyWAN refuses to mix with pre-existing AREDN pending changes; after a
  successful non-network Apply it advances the modal Cancel baseline. During a
  background network apply the footer retains Done but suppresses a stale
  Cancel action until the protected transaction finishes.
- Remote Mesh WAN cards query the live table-22 resolver on every render and
  fall back to a direct table-22 route when Babel control metadata is missing.
  The dashboard and speed views always show concise state, exit, and path
  information when an exit is present, even if Remote Mesh WAN is not selected
  as a route candidate.
- The controller init script now stops startup when Ethernet reconciliation
  fails instead of launching the SLA daemon behind an invalid port state. The
  disposable root harness covers GUI enable timeout, service restart during a
  pending transaction, XLink rollback, validation rollback, RapidConfig
  activation, and interruption recovery.

### Ordered Route Policy Setup

R29.5 replaces the Manual/Automatic and speed-ranked policy with one ordered
route list. WAN 1, WAN 2, Android USB tether, and Remote Mesh WAN each appear
exactly once in the preference order and have independent enable switches.
Failover moves downward immediately after the failure threshold; recovery moves
upward only after the configured success count and hold-down. Speed is a local
eligibility floor and never reorders the list.

The operator-facing page is renamed `Route Policy Setup`, has no Advanced
disclosure, and removes expected HTTP response-code fields, result lifetime,
automatic test scheduling, manual selection mode, and the return-to-preferred
toggle. It retains only settings useful to the routing decision: enabled
routes, route order, clear local and mesh-sharing data-rate floors, health URLs
and timing, recovery damping, and local-route mesh export.

Remote Mesh WAN status in R29.5 resolves the originator ID of the installed
Babel table-22 default to the originating node's primary address and AREDN node
name. The dashboard shows that exit node, origin address, next hop, interface,
and route availability. Connection Speed Test includes a read-only Remote Mesh
WAN row with the same exit status; it does not claim that a local speed test can
measure the remote gateway's own Internet link.

### Preserve and verify initialization

Live validation on `KP4DJT-HAP-AC2-VAN` found the R29 APK registered as
installed while the expected `aredn.multiwan` UCI section was absent and the
service was inactive. Running the packaged initializer again created the
section only after its conflicting runtime commit was removed, with
`enabled=0`.

The failure was reproduced under shell tracing. The initializer stages defaults
through `uci -c /etc/config.mesh`, but `cleanup_old_proxy_state()` then runs
`uci commit aredn` against the runtime configuration. On AREDN that commit
synchronizes runtime state back over the mesh configuration and erases the
staged `multiwan` defaults before the final mesh commit. The script nevertheless
returns zero. The R29 GUI then cannot save Enable because its `uciMesh` handler
assumes the missing `aredn.multiwan` section already exists and does not report
set or commit failures.

The package currently stores its section inside `/etc/config.mesh/aredn`.
AREDN can regenerate that file after installation, so a later configuration
save may discard the package-owned section. R29.5 must:

- make the post-install initializer fail when any required UCI write or commit
  fails instead of returning success unconditionally;
- remove or reorder the runtime `uci commit aredn` in
  `cleanup_old_proxy_state()` so it cannot overwrite staged mesh defaults, and
  add a regression test for this exact commit-order failure;
- verify after installation that `aredn.multiwan` exists and contains all
  required defaults;
- make every GUI save handler create or repair the `multiwan` section before
  setting options, verify the mesh commit, and show a visible error when a set,
  commit, or apply operation fails;
- keep the Ethernet Port Roles Save and Apply-with-rollback controls directly
  beneath the port-role table instead of below the unrelated XLinks editor and
  help content, so applying a role change is visible at the point of editing;
- keep the PollyWAN Selection Policy apply control directly beneath its form
  and label it `Save and apply policy`, matching the handler's existing commit
  and controller-restart behavior;
- state beside both apply controls that the dialog's `Done` button only closes
  the window and never saves or applies configuration;
- verify the saved persistent value is synchronized to runtime before starting
  or restarting PollyWAN services;
- preserve the section across AREDN configuration regeneration, or move
  package-owned state to a dedicated persistent UCI config with a compatible
  migration;
- add an idempotent repair path for an installed package whose section is
  missing;
- test first install, reinstall, firmware/config regeneration, reboot, and
  uninstall on both hAP ac2 validation nodes;
- keep repair and migration disabled by default and prove they do not change
  radios, ports, GPS, WAN routes, time/location, or USB power.

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
