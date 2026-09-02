# Future AREDN sysinfo integration plan

PollyWAN r29 does not modify AREDN core sysinfo files and does not replace
`/app/main/sysinfo.ut`, `/www/cgi-bin/sysinfo.json`, or `/a/sysinfo`.

The standalone package owns this public cache-only endpoint instead:

```text
http://NODE/cgi-bin/apps/aredn-multiwan/status.json
```

That endpoint reads `/tmp/wan-sla/telemetry.json`, returns schema version 1,
and never starts probes or changes routes.

## Proposed AREDN-core hook

A future AREDN core change could include PollyWAN data in the normal sysinfo
object with a guarded optional read:

```ucode
try {
    info.pollywan = json(fs.readfile("/tmp/wan-sla/telemetry.json"));
}
catch (_) {
}
```

That is not implemented by the standalone r29 APK. It requires AREDN-core
review and merge.

## Generic extension directory

A more general future pattern would let packages drop small JSON files into:

```text
/tmp/sysinfo/extensions/
```

AREDN core could then merge approved read-only extension documents into
sysinfo. This also requires AREDN-core review and merge.
