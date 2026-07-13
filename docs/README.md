# Feature documentation

These documents describe branch-specific features that are not yet part of an AREDN production release.

- [Multi-WAN USB WAN and PdaNet setup](multiwan-usb-wan.md) — administrator setup, proxy behavior, route switching, calibration, limitations, and troubleshooting for `wan3` on the MikroTik hAP ac lite, hAP ac2, and hAP ac3.
- [Multi-WAN link calibration](multiwan-link-calibration.md) — authentication, Hurricane Electric / Hayward CDN contract, bounded transfer sizes, proxy-aware measurement, and link classification.
- [Multi-WAN implementation verification](multiwan-verification.md) — repository checks, prepared-tree patch verification, target build commands, hardware test cases, and the current validation boundary.

Documentation and implementation are expected to change together. The guides contain source verification maps, and `tests/verify-multiwan.sh` checks their key contracts against the committed code.
