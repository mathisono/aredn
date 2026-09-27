# ADR: package ownership of table 28 on AREDN main

Status: implemented in r30; hardware validation not run

## Decision

PollyWAN r30 is self-contained and targets unmodified AREDN main/nightly
firmware. While enabled, PollyWAN is the single writer of default-like routes
in table 28. It also owns local selection table 26, the selected connected
route in table 27, candidate-private tables 101/102/103, health
classification, UI, and package telemetry.

The package does not replace `wan_monitor.uc`, `11-meshrouting`, core sysinfo,
or any other firmware-owned file. During takeover it stores the exact presence
and value of AREDN's `monitor1` and `monitor2` options, removes those targets,
commits the handoff, and signals only the native `wan_monitor` task to restart.
With no targets, that stock task exits rather than racing PollyWAN.

PollyWAN directly reconciles `default`, `0.0.0.0/1`, and `128.0.0.0/1` in
table 28. It writes only when the desired route set differs. A later package
hotplug handler synchronously removes routes that stock `11-meshrouting` may
have created before asynchronous health evaluation begins.

## Fail-closed behavior

Each qualified export refreshes a monotonic heartbeat. A separate procd
watchdog withdraws table 28 when that heartbeat is absent, moves backward, or
becomes stale. The timeout is at least 180 seconds and is extended to cover a
deliberately longer configured standby evaluation interval.

Stop, interface-change, failure, disable, upgrade, and removal paths withdraw
all three default-like prefixes. Failed selection transactions restore the
previous main/26/27/28 route snapshot.

## Lifecycle

- Disabled after installation: no takeover and no package network changes.
- Enable/start: save native monitor options, suppress its targets, restart that
  task, install package rules, and begin health evaluation.
- Healthy qualified path: publish the selected local WAN in table 28.
- First failed upstream decision: withdraw table 28 while local selection may
  remain under its separate hysteresis.
- Interface hotplug: synchronously withdraw stock/default-like exports, then
  requalify asynchronously.
- Daemon failure: the heartbeat watchdog withdraws stale export routes.
- Service stop while still configured enabled: fail closed and retain the
  native-monitor handoff.
- Disable/removal: withdraw package routes, restore ordinary WAN1 routing,
  restore the saved native monitor options, and restart that task.

If an administrator changes `monitor1` or `monitor2` while takeover is active,
the next reconciliation preserves the new value as the setting to restore and
continues suppressing the competing task.

## Routing boundaries

Tables 23 and 22 remain native inputs. Table 23 is the local DtD default;
table 22 is a remote Babel-learned Mesh default. PollyWAN reads and reports
them separately and never republishes either as a local WAN.

## Consequences

R30 no longer needs a custom firmware image or a feature marker. The package
has more lifecycle responsibility: native monitor configuration must always be
restored, hotplug races must remain covered, and the independent export
watchdog is mandatory. Static and mock validation do not replace live testing
on the pinned, unmodified nightly.
