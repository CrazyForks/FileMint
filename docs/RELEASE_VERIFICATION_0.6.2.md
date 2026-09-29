# FileMint 0.6.2 release verification

Published on 2026-09-29. Version **0.6.2**, build **21**.

## Source and local package checks

- Tag `v0.6.2` points to release commit `8490835cbe207f369cbf90d3592fda7fbda6bd58` on `main`.
- `make release-local` passed on macOS 27.2 / arm64 with Xcode 27.0 (27A266a). It ran `make verify` (168 Core tests, 14 image tests, 5 public Harness cases, 10 CLI regressions and release-script checks), built the app and Finder extension, and passed the production Sparkle driver checks.
- The app, Finder extension and embedded Sparkle executables were Developer ID signed and verified as arm64-only. The mounted DMG checks passed nested signatures, resolved sandbox/installer entitlements, version/build, checksum and the signed `appcast.xml`.
- Apple notarization submission `e6cb8bb8-4665-475d-8e12-6b2c6e0f7424` was **Accepted**. Stapling and ticket validation passed before the final checksum.
- Final DMG size: **5,794,425 bytes**. SHA-256: `8a5b24cb5bc1b5ee990998c6526f07594aba797a29d4a262b1235eeb8634f61a`.

## Isolated update acceptance

The changed update restart guard and release packaging triggered a targeted Sparkle installation check. A disposable sandbox host used the production signing script and an in-memory test-only Ed25519 key. Its first ad-hoc-signed fixture could not load Sparkle on macOS 27.2 because the process and framework had different Team IDs. Rebuilding the fixture with the FileMint Developer ID identity resolved that fixture error; it did not require a change to the released app or DMG.

The re-signed fixture then checked the local loopback feed and installed build 2 over build 1 at the same isolated path. The original PID `9892` exited, PID `9922` ran from that path, its bundle reported build `2`, and strict nested signature verification passed after replacement. The test-only host automatically initiated the update because desktop UI inspection timed out; its event log recorded check, discovery, download, extraction and install handoff. This verifies isolated Sparkle replacement/relaunch, not a public-feed update of the FileMint app or installed Finder callbacks.

Earlier source-level and isolated native checks for clipboard text, directory delivery, Terminal/Warp working directories and settings are recorded in [the feature task](tasks/2026-09-28-clipboard-text-and-directory-tools.md) and [acceptance history](ACCEPTANCE.md). They are not repeated as installed-app evidence for this release.

## Published assets and remote checks

[GitHub Release v0.6.2](https://github.com/FileMintApp/FileMint/releases/tag/v0.6.2) is stable and contains exactly the following three assets. `make publish-local` downloaded each asset and compared its bytes with the verified local original.

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| `FileMint-0.6.2.dmg` | 5,794,425 | `8a5b24cb5bc1b5ee990998c6526f07594aba797a29d4a262b1235eeb8634f61a` |
| `FileMint-0.6.2.dmg.sha256` | 85 | `b9ea6211d5ca7773eba790a35cf5b467b4281003f34b61ddd790ab418fe40d0d` |
| `appcast.xml` | 852 | `8374f8fa1874440c21257c1d0e0fd157a1d5aaa1d5091f7c57b3c9ceaba1dccc` |

- [Published-release verification](https://github.com/FileMintApp/FileMint/actions/runs/36510469297), [CI](https://github.com/FileMintApp/FileMint/actions/runs/36510458939) and [website deployment](https://github.com/FileMintApp/FileMint/actions/runs/36510458814) all passed for the release commit.
- `SITE_BASE=/FileMint/ pnpm run site:build` passed before the tag. The deployed Chinese and English guide/privacy pages returned HTTP 200 and contained the new clipboard/directory and 0.6.2 privacy copy. The homepage's 0.6.1 screenshot labels remain historical descriptions of those images; its download link points to the latest stable release.

The installed `/Applications/FileMint.app` was not replaced. Current-source installed Finder callbacks, iTerm2/Ghostty directory behavior, actual terminal window/tab counts, macOS 13 runtime, managed-device authorization and an actual public-feed upgrade from 0.6.1 to 0.6.2 remain unverified.
