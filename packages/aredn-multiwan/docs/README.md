# PollyWAN documentation

- [Ethernet/Wi-Fi WAN roles and GPS safety](port-roles-and-gps.md)
- [Android USB tether WAN setup](multiwan-usb-wan.md)
- [Connection speed tests and selection classes](multiwan-link-calibration.md)
- [Mesh WAN, Babel, routing tables, sharing, and tunnel isolation](multiwan-mesh-wan.md)
- [Build, static, installation, GPS, route, Babel, and rollback verification](multiwan-verification.md)
- [OpenClaw prompt for mse-88 → hub5](../tools/openclaw-build-test-prompt.md)

All user-visible defaults, paths, table numbers, limits, and limitations are checked by `tests/verify.sh`.

## Repository synchronization

The standalone root must match `packages/aredn-multiwan` in the integration checkout. Run `tools/sync-integration.sh check /path/to/aredn`; use `apply` to update the vendored subtree. The deterministic manifest in `SYNC_SOURCE` excludes only `SYNC_SOURCE` itself.
