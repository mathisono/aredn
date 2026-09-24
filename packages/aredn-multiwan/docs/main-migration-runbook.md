# r29 stable to r30 main/nightly migration runbook

r29 is the rollback line for the previous stable firmware. Do not run its APK,
USB kernel modules, generated network includes, or controller on main/nightly.
r30 is tested only with firmware derived from the recorded AREDN source.

## Before any live change

1. Identify the board, AREDN build/source revision, architecture, full kernel
   package identity, feed revisions, installed package state, overlay space,
   and independent management/recovery path.
2. Retain the exact firmware image and SHA-256. Confirm its source SHA matches
   the frozen cycle. A date or OpenWrt version alone is insufficient.
3. Inventory AREDN's package store and prevent automatic restoration of the
   r29 APK and old USB kmods. Preserve private backups before changing it.
4. Capture unmodified native routing, rules, network dump, firewall, Babel,
   WAN monitor, tunnel MTU, UI and sysinfo with PollyWAN absent or inert.
5. Do not flash without explicit authorization and recovery access. Use the
   firmware's documented `/usr/local/bin/aredn_sysupgrade` procedure.

## Clean install lane

Use a clean matching main-derived lab image first. Confirm the native feature
marker, then simulate installation against only the deliberate local APK set:

```sh
test -r /usr/share/aredn/features/pollywan-export-v1
apk add --simulate --no-network --allow-untrusted /tmp/aredn-multiwan-0.1.0-r30.apk
```

Reject kernel replacement, package downgrade/removal, or a dependency fetch.
Install while disabled and compare the baseline: no port, radio, GPS, firewall,
route, rule, WAN3, or sysinfo change is allowed. Then execute C00-C16 from the
development plan with state capture and recovery between phases.

## Reviewed configuration migration lane

After the clean lane, copy only administrator intent through supported UCI/UI
fields. Do not restore old `/etc/config.mesh`, generated `.network.user` files,
runtime state, or package-store payloads wholesale. Explicit `none` assignments
must remain explicit. Apply port roles with the single rollback transaction and
confirm only after the known management path has recovered.

USB support is optional. Install drivers only when every APK matches the exact
firmware feed and kernel package identity with complete dependency closure.
An unavailable WAN3 is acceptable; an old stable module is not.

## Rollback

Disable PollyWAN before removing it. Confirm the native monitor has resumed
ordinary WAN ownership, package tables/rules and includes are absent, table 23
and 22 remain distinct, tunnel guard rules are removed, and management works.
Firmware rollback returns to the retained stable image and r29 artifacts only;
never install r29 into the nightly as a shortcut.

Raw backups and evidence may contain credentials or keys and remain private.
Public reports contain sanitized identities, full artifact hashes, commit IDs,
and explicit PASS/FAIL/NOT RUN results only.
