# Connection speed tests and selection classes

## Health is not speed

PollyWAN health checks decide whether a WAN is usable. They are lightweight:

- interface and source address validation
- route validation through the WAN private table
- source-bound gateway ICMP
- source-bound HTTPS fallback

Health checks do not download speed-test payloads and do not run iperf3. A failed throughput test records a failure reason but does not withdraw a healthy WAN.

## Selection behavior

R29.5 uses an explicit ordered route policy. Operators rank WAN 1, WAN 2,
Android USB tether, and Remote Mesh WAN. The first enabled route that passes its
availability and data-rate policy wins. A failure moves downward immediately;
recovery moves upward only after the configured confirmation and hold-down.

Fresh local speed results classify each path:

- Low: less than 5 Mbps
- Medium: 5 through 30 Mbps
- Fast: greater than 30 Mbps
- Unknown: no fresh valid result

The class is an eligibility floor only; it never changes the configured order.
Remote Mesh WAN has no local speed class and is eligible when its table-22
default is present. Older manual, availability, adaptive, and automatic values
migrate to `ordered`.

Connection Speed Test shows Remote Mesh WAN as a status-only row. It reports
whether the table-22 route is disabled, absent, available, or active and names
the AREDN node that originated the default. Local Cloudflare and iperf3 buttons
remain limited to WAN 1, WAN 2, and USB because they cannot measure the remote
exit node's own upstream link from this node.

## AREDN node-to-node testing

The AREDN node test runs reverse iperf3:

```sh
iperf3 -c NODE -p PORT -t DURATION -R -J
```

The remote node must already run an iperf3 server. The node name is limited to letters, numbers, dots, and dashes before it is used.

This test measures throughput between two AREDN nodes over the selected path. It may not represent general Internet performance.

Before accepting a result, PollyWAN validates the WAN device, source address, gateway, private table, destination route, JSON throughput, transferred bytes, and active WAN stability.

## Internet-path testing with Cloudflare

The Cloudflare method first reads:

```text
https://cloudflare.com/cdn-cgi/trace
```

Then it downloads a bounded payload from:

```text
https://speed.cloudflare.com/__down?bytes=BYTES
```

Cloudflare uses Anycast routing. The displayed colo is the edge selected by BGP and ISP peering; it is not guaranteed to be the nearest facility.

Results record WAN, device, source address, public IP, country, Cloudflare colo, bytes, duration, Mbps, class, route proof, and message. WAN1 and WAN2 may share a public IP when they intentionally share an upstream router; route and source proof still decide whether the result is valid.

## Payload and data usage

Manual payload choices:

- 1 MB
- 5 MB
- 10 MB
- 20 MB

Adaptive payload sizing uses the previous valid class:

```text
low     -> 1 MB
medium  -> 5 MB
fast    -> 10 MB
unknown -> 2 MB
```

Routine testing defaults to 5 MB. PollyWAN never runs the full browser speed test.

## Result storage

Runtime results live in `/tmp`:

```text
/tmp/wan-speed/wan.json
/tmp/wan-speed/wan2.json
/tmp/wan-speed/wan3.json
```

Each file contains version, timestamp, WAN, method, validity, Mbps, class, duration, bytes, latency, source, device, gateway, public IP, country, colo, remote node, remote address, route proof, and message.

Failures update `*.status.json` and preserve the last valid `*.json` result.

## CLI

```sh
wan-speed-test test wan cloudflare 1000000
wan-speed-test test wan2 iperf3
wan-speed-test test-all cloudflare 5000000
wan-speed-test status wan
wan-speed-test status-all
wan-speed-test clear wan
wan-speed-test route-check wan
```

Tests run sequentially under one lock. They do not replace the active system default route.
