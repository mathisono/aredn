# Feature documentation

These documents describe the experimental `aredn-multiwan` package. The package is built as an installable APK for the MikroTik hAP ac lite, hAP ac2, and hAP ac3; it is not installed in the base firmware image.

- [Package and phone USB/PdaNet setup](multiwan-usb-wan.md) — phone-to-hAP USB tether topology, hAP-side proxy inputs, installation, manual WAN selection, troubleshooting, recovery, and uninstall.
- [Link calibration](multiwan-link-calibration.md) — administrator-selected HTTPS object, authenticated measurement runs, transfer limits, speed bins, and current limitations.
- [Implementation verification](multiwan-verification.md) — static checks, package build checks, URL validation, and hardware test matrix.

The package source is under [`packages/aredn-multiwan`](../packages/aredn-multiwan). Run `tests/verify-multiwan.sh` after changing code, defaults, dependencies, UI fields, or documentation.
