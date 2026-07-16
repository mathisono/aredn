OpenClaw: finish and test PollyWAN r6 on mse-88/hub5. Show commands/results; never guess or mark unrun tests passed.

Repos: `mathisono/AREDN_PollyWAN:agent/pollywan-r6` and `mathisono/aredn:agent/pollywan-r6`; standalone root must equal `aredn/packages/aredn-multiwan`. First preserve/build verified r3 from commits `15feefd5`/`f05114d`, record APK/log/SHA256, then work only on r6 branches. Run both verifiers and require an empty `rsync -rnic --delete --exclude .git` diff before each commit/push.

Inspect hub5: supported hAP model, firmware, arch/kernel ABI, free overlay, radio modes, logical WAN device, GPS/gpsd/TTY/time/USB, routes/rules, Babel, tunnels and nftables. Build exact target only; never force ABI/dependency/space errors.

r6 requirements: `wan` is WAN1 Ethernet OR AREDN Wi-Fi client (`radio0=wan`→`wlan0`, `radio1=wan`→`wlan1`) in table101; reject both radios WAN and reject Ethernet WAN1 while Wi-Fi owns it. `wan2` is selected Ethernet/table102; `wan3` is USB RNDIS/CDC/table103 with hAP PdaNet proxy fields. Advanced-Ports-style roles need timed rollback. Disabled install changes no ports, radios, routes, GPS, time/location or USB power.

Use operator HTTPS range object; test 1/8/32 MiB and low≤5, medium≤30, fast>30. Verify health/bin/preference/failure/promotion/hold-down/stale rotation; table26 selected default, 27 subnet, 28 only qualified Mesh-to-WAN export, 22 untouched fallback. Reject boot/stale/bad Babel defaults. Hard-block `wg*`/`tun*` ingress from Internet while preserving mesh routes. PdaNet may serve LAN/RF/DtD only while WAN3/table28 is qualified; never proxy tunnels.

Build r6, inspect APK, backup hub5, install disabled, prove GPS/network unchanged, test rollback, Wi-Fi WAN1, WAN2, optional WAN3, calibration, adaptive failover, Babel/tunnels/proxy, uninstall/restore. Push both repos and report SHAs, APK SHA256, pass/fail evidence, failures and skipped tests. Stop on any failed gate.
