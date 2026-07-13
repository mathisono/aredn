# Multi-WAN link calibration

## Purpose

The `aredn-multiwan` package can measure `wan`, `wan2`, and `wan3` without depending on a hard-coded public speed-test service. It groups each usable path into a coarse throughput bin:

- `low`: 5 Mbps or less
- `medium`: above 5 Mbps through 30 Mbps
- `fast`: above 30 Mbps

Calibration is currently a **manual measurement tool**. It does **not yet automatically switch WANs based on the result**. Manual route selection and hard secondary-link fallback are separate package functions.

## Authentication and configuration boundary

Calibration creates potentially billable traffic and is therefore an administrative action.

- Only a logged-in AREDN administrator can see the package application and calibration controls.
- The write handler lives below a secured `/e/` route and also explicitly checks `auth.isAdmin`.
- An administrator may save or clear the persistent HTTPS calibration object from the UI.
- `GET` reads status only and creates no calibration traffic.
- A calibration run starts only from an authenticated `PUT` containing the fixed action `calibrate` and one allow-listed name: `wan`, `wan2`, or `wan3`.
- A run request cannot supply or override a destination URL, command fragment, device path, byte count, or arbitrary interface.
- A global lock prevents concurrent tests.
- A per-interface cooldown defaults to 300 seconds.

This separates two operations:

1. **Configure object:** an authenticated administrator stores one persistent HTTPS URL.
2. **Run calibration:** an authenticated request selects only the WAN to test; the runner reads the saved URL from UCI.

## User-selectable HTTPS object

The package source contains no active calibration URL. In **WAN Link Calibration**, the administrator enters:

- a descriptive label
- a complete HTTPS object URL

Example:

```text
Label: Hurricane Electric / Hayward Internet Exchange
URL:   https://speed.example.net/aredn/link-calibration/payload.bin
```

Hurricane Electric/Hayward can be used when an appropriate object is available, but it is not mandatory or hard-coded. Another administrator-controlled HTTPS object may be selected.

The handler derives the hostname from the URL and stores:

```text
aredn.multiwan.calibration_provider
aredn.multiwan.calibration_host
aredn.multiwan.calibration_url
aredn.multiwan.calibration_cooldown
```

Saving a blank URL clears the saved host and URL and disables calibration.

### Accepted URL form

The UI accepts a URL shaped like:

```text
https://dns-hostname/object/path
```

The current implementation requires:

- standard HTTPS with normal system CA validation
- a DNS-style hostname and a non-empty object path
- no embedded username or password
- no whitespace
- no URL fragment
- no custom port
- no redirects

The object itself must:

- support HTTP byte ranges
- return `206 Partial Content`
- return the exact requested byte count
- be at least 32 MiB
- be stable enough for repeated test comparisons

The runner independently validates the stored hostname and URL before opening a connection. This protects against malformed values inserted directly through UCI as well as malformed UI submissions.

## Progressive transfer

The runner binds each request to the selected WAN's IPv4 source address and requests:

1. 1 MiB
2. 8 MiB when the first result is at least approximately 4 Mbps
3. 32 MiB when the second result is at least approximately 25 Mbps

A slow path therefore stops after the smallest sample. A fast path transfers at most about 41 MiB total. The final completed sample determines the bin.

Each accepted result records:

- interface and Linux L3 device
- source address and gateway
- UTC timestamp
- total and final-sample byte counts
- elapsed time
- measured Mbps
- low/medium/fast bin
- remote address
- configured label and hostname
- whether the `wan3` upstream proxy was used

A result is shown as stale when the current interface address or gateway no longer matches the saved measurement.

## PdaNet and `wan3`

`wan3` is the network path created from the Android phone's USB RNDIS/CDC tether into the hAP. The hAP obtains an IPv4 address on this USB network before it can reach the PdaNet proxy.

When `wan3_proxy_enable=1`, calibration does not depend on the transparent nftables redirect. Curl is given the configured PdaNet HTTP CONNECT proxy directly while remaining bound to the `wan3` source address.

Common PdaNet values are:

```text
Proxy: 192.168.49.1:8000
Type:  HTTP CONNECT
```

Optional proxy credentials are read from persistent AREDN configuration and never accepted from the calibration-run request.

## Configure and verify an object

Use the package UI for normal configuration. For development, the equivalent UCI values are:

```sh
uci -c /etc/config.mesh set aredn.multiwan.calibration_provider='My calibration server'
uci -c /etc/config.mesh set aredn.multiwan.calibration_host='speed.example.net'
uci -c /etc/config.mesh set aredn.multiwan.calibration_url='https://speed.example.net/aredn/link-calibration/payload.bin'
uci -c /etc/config.mesh commit aredn
```

Verify the object before running a full calibration:

```sh
curl --fail --max-redirs 0 \
     --range 0-1048575 \
     --output /dev/null \
     --write-out 'HTTP=%{http_code} bytes=%{size_download}\n' \
     'https://speed.example.net/aredn/link-calibration/payload.bin'
```

Expected values are HTTP `206` and exactly `1048576` downloaded bytes.

## Runtime files

```text
/tmp/wan-calibration/<interface>.status.json
/tmp/wan-calibration/<interface>.result.json
/tmp/wan-calibration/<interface>.last
/tmp/wan-calibration/.lock
```

Status and result files are written atomically. They are runtime data and disappear after reboot.

## Verification

```sh
# Confirm persistent object configuration
uci -c /etc/config.mesh get aredn.multiwan.calibration_provider
uci -c /etc/config.mesh get aredn.multiwan.calibration_host
uci -c /etc/config.mesh get aredn.multiwan.calibration_url

# Run manually from a shell for development
/usr/local/bin/wan-calibrate wan
/usr/local/bin/wan-calibrate wan2
/usr/local/bin/wan-calibrate wan3

# Inspect results
cat /tmp/wan-calibration/wan3.result.json
logread -e wan-calibrate
```

Do not run manual tests repeatedly on a metered link. The same lock and cooldown apply to shell invocation.

## Future SLA behavior

The planned selector will treat reachability as a hard gate and speed bins as a coarse preference:

1. `down` loses to any reachable link.
2. `fast` wins over `medium`; `medium` wins over `low`.
3. The configured preferred WAN wins ties within the same bin.
4. Promotion requires consecutive good observations and a hold-down timer.
5. Hard loss may demote immediately.

This future automatic mode must be explicitly enabled, rate-limited, data-budgeted, and distinguished from administrator-initiated calibration.

## Source map

| Function | Package source |
|---|---|
| Runner and bounds | `packages/aredn-multiwan/files/usr/local/bin/wan-calibrate` |
| Authenticated object and run handler | `packages/aredn-multiwan/files/app/main/status/e/link-calibration.ut` |
| Status card | `packages/aredn-multiwan/files/app/partial/link-calibration.ut` |
| Defaults | `packages/aredn-multiwan/files/etc/uci-defaults/95-aredn-multiwan` |
| Package dependencies | `packages/aredn-multiwan/Makefile` |
| Static consistency checks | `tests/verify-multiwan.sh` |
