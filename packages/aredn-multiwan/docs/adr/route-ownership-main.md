# ADR: native ownership of table 28 on AREDN main

Status: proposed for patched-main integration validation

## Decision

AREDN's native `wan_monitor.uc` is the single writer for routing table 28.
PollyWAN r30 owns local selection table 26, the selected connected route in
table 27, candidate-private tables 101/102/103, health classification, the UI,
and package telemetry. It never adds, replaces, deletes, flushes, snapshots, or
restores table 28.

The package atomically writes `/var/run/pollywan/export-v1.json`, mode 0600 in
a mode-0700 directory. Schema 1 contains only an eligibility boolean, validated
device/source/gateway values, split-default intent, a monotonic timestamp, and
a reason. It contains no command. The native monitor validates the schema,
characters, IPv4 values, and a 180-second maximum age. Missing, malformed,
future-dated, stale, or ineligible requests withdraw `/0`, `0.0.0.0/1`, and
`128.0.0.0/1` owned by table 28.

The package touches `/tmp/mgr/wan_monitor` and signals the existing manager
only when request semantics change. Refresh-only writes extend freshness
without causing route churn or a manager restart. The monitor reconciles at a
10-second bound and writes only when the installed route set differs.

## Firmware boundary

The AREDN hook is a separate integration change to:

- `files/usr/local/mgr/wan_monitor.uc`
- `files/etc/hotplug.d/iface/11-meshrouting`
- `files/usr/share/aredn/features/pollywan-export-v1`

The APK does not install or overwrite these files. The feature marker is both
capability negotiation and a safety gate. If it is absent, r30 records
`integration_supported=false`, does not reconcile ports, create WAN3, install
tunnel rules, or change routes, and the UI rejects enablement.

## Lifecycle

- Disabled: stock hotplug and native monitor behavior remains active.
- Startup/enable: a request begins ineligible; local selection is installed,
  then fresh HTTPS observations may produce an eligible request.
- First failed upstream observation: the request becomes ineligible even while
  local selection hysteresis retains the path.
- Interface hotplug: the package invalidates the request before reevaluation;
  native hotplug does not race a second table-28 writer.
- Package daemon death: request refresh stops and the native monitor withdraws
  it after the age bound.
- Native manager restart: it rereads UCI and the request, then reconciles the
  complete `/0` and split-default set.
- Disable/removal: the package writes an ineligible request and restarts the
  native monitor after disabling its UCI opt-in; ordinary AREDN WAN ownership
  resumes.
- Failed local route transaction: main/26/27 are restored; the prior export
  request is retained unless the interface event already invalidated it.

Tables 23 and 22 remain native inputs. Table 23 is the local DtD default;
table 22 is a remote Babel-learned mesh default. PollyWAN reads and reports
them separately and never deletes or republishes either as a local WAN.

## Consequences

Stock official nightlies lacking the hook are intentionally unsupported for
active r30 routing. Passing on a firmware containing this change is reported as
patched-main evidence, not stock-nightly compatibility. A future upstreamed
contract could make the same package compatible with an unmodified nightly.
