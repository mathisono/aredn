# Link calibration and speed bins

## Administrator-selected object

A logged-in administrator stores a descriptive label and one HTTPS object URL. Nothing is hard-coded. Hurricane Electric/Hayward may be selected when a suitable object is available, but any controlled object meeting the contract may be used.

Accepted shape:

```text
https://dns-hostname/path/payload.bin
```

The current implementation rejects non-HTTPS URLs, spaces, fragments, embedded credentials, custom ports, malformed hostnames, and missing paths. The object must:

- have a valid public certificate
- avoid redirects
- support byte ranges and return HTTP `206`
- return the exact requested byte count
- contain at least 32 MiB

Saving a blank URL disables calibration.

A run request may select only `wan`, `wan2`, or `wan3`. It cannot contain or override a URL. The runner independently validates persistent UCI before opening a connection.

## Progressive measurement

```text
1 MiB
  └─ if approximately >=4 Mbps: 8 MiB
       └─ if approximately >=25 Mbps: 32 MiB
```

Maximum total transfer is approximately 41 MiB.

Classification:

- low: 5 Mbps or less
- medium: above 5 through 30 Mbps
- fast: above 30 Mbps

Results include interface, device, source, gateway, timestamp, bytes, duration, Mbps, bin, remote address, object label/host, manual/automatic trigger, and PdaNet proxy state.

## Manual and automatic triggers

Manual runs require an authenticated administrator. Automatic runs occur only when PollyWAN is explicitly enabled in adaptive mode. A global lock prevents simultaneous runs and a per-interface cooldown defaults to 300 seconds.

Adaptive selection also requires the result to match the candidate's current source/gateway and be younger than `result_ttl`. `calibration_interval` is clamped to not exceed that lifetime.

## WAN binding

Each request is bound to the candidate's source address/private route table:

- WAN 1 → table 101
- WAN 2 → table 102
- WAN 3 → table 103

For PdaNet, curl is bound to the WAN 3 USB source and receives the proxy address/port/credentials directly. It does not rely on transparent redirection.

## Validate an object

```sh
curl --fail --max-redirs 0 --range 0-1048575 --output /dev/null \
  --write-out 'HTTP=%{http_code} bytes=%{size_download}\n' \
  'https://host.example/path/payload.bin'
```

Expected: `HTTP=206 bytes=1048576`.

## Runtime

```sh
/usr/local/bin/wan-calibrate wan manual
cat /tmp/wan-calibration/wan.result.json
logread -e wan-calibrate
```

Do not repeatedly calibrate metered links outside the documented test plan.
