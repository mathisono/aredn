# Multi-WAN link calibration

This document describes the committed manual calibration implementation for the MikroTik hAP ac lite, hAP ac2, and hAP ac3 on the `feature/mikrotik-multiwan-usbwan` branch. It complements [the USB WAN and PdaNet setup guide](multiwan-usb-wan.md).

## Current scope

The calibration UI recognizes three logical paths:

| Interface | Intended source |
|---|---|
| `wan` | Existing AREDN WAN |
| `wan2` | Separately configured second Ethernet WAN |
| `wan3` | USB WAN created by `wan3-manager` |

The current code measures and classifies a selected path. It does **not yet automatically switch WANs based on the result**. Automatic SLA selection, hysteresis, and hold-down behavior remain a later controller phase.

The throughput classes are:

- `low`: 5 Mbit/s or less
- `medium`: greater than 5 Mbit/s and up to 30 Mbit/s
- `fast`: greater than 30 Mbit/s

## Authentication boundary

A full link calibration is an administrative data-transfer action.

- Only an authenticated AREDN administrator may start one.
- The handler lives at the secured `/status/e/link-calibration` route.
- The handler explicitly checks `auth.isAdmin` in addition to the request router's `/e/` protection.
- `GET` displays state and never starts a transfer.
- Calibration starts only from an authenticated `PUT` carrying the fixed `calibrate` action and one allow-listed interface: `wan`, `wan2`, or `wan3`.
- The browser cannot provide a destination URL, command fragment, device path, file path, byte count, or arbitrary interface name.
- A global process lock prevents simultaneous calibrations.
- Each interface has a configurable cooldown, with a minimum of 30 seconds and a supplied default of 300 seconds.
- A stale process lock is removed only after its recorded PID is no longer running.

This prevents a logged-out or remote caller from consuming cellular data by repeatedly invoking a speed test.

## Hurricane Electric / Hayward CDN contract

All active calibration downloads are intended to use the designated Hurricane Electric-connected CDN at the Hayward Internet Exchange.

- The hostname and object path come from the persistent image/deployment configuration, not from the HTTP request.
- HTTPS is mandatory and the system CA bundle validates the certificate.
- Redirects are disabled.
- The object must support HTTP byte ranges and return `206 Partial Content`.
- The client verifies the exact number of bytes received before accepting a sample.
- The code does not fall back to Ookla, Fast.com, Cloudflare, or an arbitrary operator-provided URL.
- The exact production hostname and object path are intentionally blank in this branch. Calibration remains disabled until a real endpoint is supplied.

Recommended object contract:

```text
https://<hayward-cdn-host>/aredn/link-calibration/v1/payload.bin
```

One immutable object of at least 64 MiB is sufficient when byte ranges are enabled.

## Measurement procedure

The runner resolves the selected logical interface through ubus and requires:

- interface state `up`
- a valid layer-3 device
- an IPv4 source address
- an available default route for that path

It then performs bounded progressive downloads:

1. Download a 1 MiB byte range.
2. When that sample is at least 4 Mbit/s, download an 8 MiB range.
3. When the latest sample is at least 25 Mbit/s, download a 32 MiB range.
4. Use curl's measured transfer duration and the exact received byte count to calculate Mbit/s.
5. Classify the final sample as low, medium, or fast.
6. Atomically write JSON state and result files under `/tmp/wan-calibration`.

A slow path uses about 1 MiB. A fast path uses at most about 41 MiB across all three stages.

The stored result includes the logical interface, layer-3 device, source address, gateway, UTC time, bytes, elapsed time, measured Mbit/s, bin, remote IP, CDN host, provider, and whether an upstream proxy was used. The UI marks a result stale when the current source address or gateway no longer matches it.

## USB WAN and PdaNet

When `wan3` proxy mode is enabled, `wan-calibrate` does not rely on the transparent nftables redirect. It invokes curl with the configured HTTP proxy directly and binds the connection to the `wan3` source address.

The supplied PdaNet-oriented defaults are:

```text
proxy address: 192.168.49.1
proxy port:    8000
proxy type:    HTTP CONNECT
```

The address and port are validated before use. Optional proxy credentials are read from the local `aredn.multiwan` UCI section. A direct WAN test explicitly disables inherited shell proxy variables so the selected path is measured rather than an unrelated environment proxy.

## Monitoring versus calibration

Full calibration is user initiated. Cheap automatic health observations are separate:

- carrier and USB-device presence
- DHCP/interface state
- route presence
- passive counters
- small reachability probes in a future SLA controller

The committed `wan3-manager` currently provides manual route selection and hard USB-loss fallback to WAN 1. It does not periodically download the CDN object and it does not use calibration bins to change the route automatically.

A later adaptive controller should add consecutive-observation thresholds, hold-down timers, metered-link budgets, and explicit user opt-in before it performs any automatic bandwidth sample.

## Source verification map

| Behavior | Source path |
|---|---|
| Administrator-only request handling and interface allow-list | `files/app/main/status/e/link-calibration.ut` |
| Status card for WAN 1, WAN 2, and USB WAN | `files/app/partial/link-calibration.ut` |
| Fixed endpoint, locking, cooldown, range validation, proxy binding, and bins | `files/usr/local/bin/wan-calibrate` |
| Endpoint and cooldown defaults | `files/etc/config.mesh/aredn` |
| USB WAN creation and route handling | `files/usr/local/bin/wan3-manager` |
| PdaNet setup and troubleshooting | `docs/multiwan-usb-wan.md` |

When an interface name, threshold, byte count, cooldown, endpoint rule, or authentication rule changes in code, this document must change in the same commit series.

## Open external dependency

The production HTTPS hostname and stable byte-range-capable object at the Hayward Internet Exchange are not present in the repository and have not been inferred. Runtime calibration must remain disabled rather than ship with a fabricated or generic public endpoint.
