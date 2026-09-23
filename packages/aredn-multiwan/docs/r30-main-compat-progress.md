# PollyWAN r30 Main Compatibility Progress

Updated: 2026-09-23

## Frozen Baseline

- Authoritative source: `aredn/aredn` main
- Baseline source SHA: `f1fb190d44318250f127bdfb2aeb232dcdfab3eb`
- Validation baseline: AREDN nightly build from main at the same source SHA, not stable firmware and not mocks
- Validation firmware: not yet matched to a nightly lab node
- Stock versus patched nightly: pending

## Completed

- Created local development branches named `agent/pollywan-main-compat`.
- Preserved r29 history/tag; r30 changes are branch-local.
- Updated PollyWAN package metadata and fallback status output to `0.1.0-r30`.
- Distinguished AREDN table 22 remote Mesh WAN from table 23 local DtD default in PollyWAN status and withdrawal messages.
- Moved PollyWAN LAN default rule from preference 45 to 44 so tunnel isolation keeps preference 45 without a collision.
- Added required AREDN-core patch: `11-meshrouting` skips stock table 28 publication while `aredn.multiwan.enabled=1`, leaving PollyWAN as table 28 owner.
- Preserved standalone sysinfo posture; r30 still does not replace core sysinfo.
- Standalone verifier passed with root-only chroot mocks skipped.
- Synced standalone package into `mathisono/aredn` at `packages/aredn-multiwan`; sync check reports an exact match.
- Build host prerequisites recovered through `tools/meson/compile` and `tools/libressl/compile`; package compile then reached target toolchain packaging.
- Development commits prepared; use `git log --oneline -1` in each repo for the current branch tip after any amend/push.

## Gates

- Static regression tests: PASS (`tests/verify.sh`; root-only chroot mocks skipped)
- Subtree sync to `mathisono/aredn`: PASS
- APK build: FAIL (`make -C openwrt package/aredn-multiwan/compile V=sc -j1`; blocked by missing target toolchain artifact `staging_dir/toolchain-mips_24kc_gcc-14.3.0_musl/lib/libgcc_s.so.*`)
- Matching nightly lab node validation: NOT RUN
- Commit: PASS
- Push: PASS

## Remaining

- Build/install the frozen baseline target toolchain or run the full AREDN package build path, then rebuild the r30 APK and record SHA256.
- Validate only on an AREDN main/nightly lab node matching the frozen source SHA; stable firmware or mocks do not satisfy acceptance.
- Do not flash or disrupt hub5 without authorization and recovery access.
