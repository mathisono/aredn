# Multi-WAN link calibration design

This document records implementation constraints for the MikroTik multi-WAN work on the hAP ac lite, hAP ac2, and hAP ac3. It supplements the dual-WAN and USB-WAN design; it does not enable the feature by itself.

## Goals

- Keep the existing single-WAN behavior unchanged unless multi-WAN is enabled.
- Support independent Ethernet and USB-tethered WAN interfaces.
- Classify a WAN path into coarse throughput bins:
  - `low`: 5 Mbit/s or less
  - `medium`: greater than 5 Mbit/s and up to 30 Mbit/s
  - `fast`: greater than 30 Mbit/s
- Use calibration results as one input to WAN selection without making the existing AREDN network setup own a general-purpose speed-test service.

## Authentication boundary

A link calibration is an administrative action.

- Only an authenticated AREDN administrator may start a calibration.
- The request handler will live under an authenticated `/e/` route, for example `/status/e/link-calibration`.
- The handler must also explicitly check `auth.isAdmin`; it must not rely only on the UI hiding the control.
- `GET` is status-only and must never start network traffic.
- Calibration starts only from an authenticated `PUT` or `POST` carrying a fixed action and an allow-listed interface name.
- The calibration button is rendered only for an authenticated administrator.
- There will be no unauthenticated RPC, query-string trigger, or public URL that starts a transfer.
- The request cannot provide a destination URL, command fragment, device path, file path, byte count, or arbitrary interface name.
- The service accepts only configured logical WAN identifiers such as `wan` and `wan2` and resolves their current L3 device/source address through netifd/ubus.
- A lock prevents concurrent calibrations, and a cooldown prevents accidental repeated transfers.

The existing AREDN request router treats paths containing `/e/` as secured and rejects an unauthenticated request with HTTP 401. The new handler will retain an explicit administrator check as defense in depth.

## Hayward Internet Exchange CDN

All active calibration downloads must use the designated CDN at the Hayward Internet Exchange.

- The firmware must not fall back to Cloudflare, Ookla, Fast.com, a random public file, or an operator-supplied arbitrary URL.
- The CDN hostname and object path are fixed by the build/configuration contract rather than accepted from the calibration request.
- Use HTTPS and validate the certificate with the system CA bundle.
- The CDN object should support HTTP byte ranges and return an accurate `Content-Length`/`Content-Range`.
- The client must verify a successful HTTP response and the number of bytes transferred before accepting a measurement.
- Redirects, if permitted at all, must remain on an allow-listed Hayward CDN hostname. A redirect to an arbitrary host is a failed calibration.
- The exact production HTTPS hostname and object path must be supplied before runtime code is enabled; no hostname is guessed in this branch.

Recommended CDN contract:

```text
https://<hayward-cdn-host>/aredn/link-calibration/v1/payload.bin
```

A single object of at least 64 MiB is sufficient when range requests are supported. It avoids maintaining several test files and lets the node request only the sample size it needs.

## Calibration procedure

Calibration is bounded and progressive so that a slow or metered cellular path does not download a large object unnecessarily.

1. Resolve the selected logical WAN through ubus and confirm that it is up and has an IPv4 address and route table.
2. Perform a small HTTPS connection/first-byte check bound to that WAN.
3. Download a 1 MiB range and calculate application-layer throughput.
4. If the result is near or above the 5 Mbit/s boundary, download an 8 MiB range.
5. If the result is near or above the 30 Mbit/s boundary, download a 32 MiB range.
6. Use elapsed monotonic time and bytes actually received to calculate Mbit/s.
7. Store the result atomically with interface, source address, gateway, timestamp, bytes, elapsed time, measured Mbit/s, and bin.

The result must be discarded when the interface address or gateway changes, unless a later implementation deliberately keys historical results to the upstream identity.

## Monitoring versus calibration

A full active calibration is user initiated. Automatic WAN health monitoring is separate:

- Carrier state, DHCP state, route presence, and small reachability checks may run automatically.
- Passive byte counters may be observed without creating traffic.
- The automatic monitor must not invoke the full CDN calibration endpoint on behalf of an unauthenticated request.
- A future adaptive mode may use a deliberately bounded internal sample only after the user enables that mode; it must be separately named, configured, rate-limited, and accounted for so it is not confused with manual calibration.

This separation prevents an external caller from consuming cellular data while still allowing the failover controller to detect a dead path.

## Selection behavior

- `down` always loses to a reachable link.
- `fast` wins over `medium`; `medium` wins over `low`.
- When both links are in the same bin, the configured preferred WAN wins unless hard health checks mark it unusable.
- Promotion requires consecutive healthy observations and a hold-down timer.
- A hard loss of reachability may demote immediately.
- Existing sessions are not promised seamless migration; route changes primarily affect new flows.

## Required runtime pieces

The implementation is expected to add isolated components rather than place the calibration logic inside `node-setup`:

```text
files/usr/local/bin/wan-calibrate
files/etc/init.d/wan-sla
files/app/partial/link-calibration.ut
files/app/main/status/e/link-calibration.ut
```

`node-setup` should only generate the independent WAN interfaces, route tables, and firewall membership needed by the controller.

## Open external dependency

The production HTTPS hostname and stable range-capable object path for the Hayward Internet Exchange CDN are not present in the repository and have not been inferred. Runtime code must not ship with a fabricated or generic public endpoint.
