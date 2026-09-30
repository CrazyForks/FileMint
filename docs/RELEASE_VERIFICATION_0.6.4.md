# FileMint 0.6.4 release verification

Published on 2026-09-30. Version **0.6.4**, build **23**.

## Source and local package checks

- Tag `v0.6.4` points to release commit
  `ccb3e87f213b14379c98ae25de1da5b73477ff3d` on `main`.
- Fix commit `868bd8f` adapts Finder's monochrome menu images to the system's
  appearance and references `Fixes #5`. The bilingual release notes link
  [issue #5](https://github.com/FileMintApp/FileMint/issues/5).
- `make release-local` passed on local macOS 27.2 / Apple silicon. It ran
  `make verify` (178 Core tests, 14 image tests, 5 public Harness cases,
  10 CLI regressions and the remaining offline checks), built the App and Finder
  extension, and passed the production Sparkle-driver checks.
- The App, extension, embedded Sparkle executables and DMG were Developer ID
  signed. Arm64-only contents, hardened runtime, resolved sandbox/installer
  entitlements, mounted-DMG contents and version/build checks passed.
- Apple notarization submission `ed92a358-0ce8-4a61-bbe5-28697b43755c` was
  **Accepted**, confirmed again with `notarytool info`. Stapling and ticket
  validation passed before the final checksum and Ed25519 appcast signature.
- The signed feed binds build 23, version 0.6.4, macOS 13.0 and arm64 to the
  verified DMG. The final local source manifest is
  `build/FileMint-0.6.4.release.json`; it was not uploaded.
- `SITE_BASE=/FileMint/ pnpm run site:build` passed for the README updates.
  Logs and notarization readback are under ignored `build/release-0.6.4/`.

## Published assets and remote checks

[GitHub Release v0.6.4](https://github.com/FileMintApp/FileMint/releases/tag/v0.6.4)
is stable and contains exactly the following three assets. `make publish-local`
downloaded all three and compared them byte for byte with the verified originals.

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| `FileMint-0.6.4.dmg` | 5,946,702 | `bab5a31642b4cd6c30c38e9df167083e7133947b944bbca4c4e425b6e4c31eab` |
| `FileMint-0.6.4.dmg.sha256` | 85 | `bc6000b0ec1dc61b03e26d69b57ca8083fd8eecbd63b8cdfc825ab119b6ce8bb` |
| `appcast.xml` | 852 | `a63609a8cbb85b4d394217fb1f9435c2b0b3d5460bad2a5d93e3102ca35fec77` |

- [Published-release verification](https://github.com/FileMintApp/FileMint/actions/runs/36690496987),
  [CI](https://github.com/FileMintApp/FileMint/actions/runs/36690478561) and
  [website deployment](https://github.com/FileMintApp/FileMint/actions/runs/36690478675)
  all passed for the release commit.
- Issue #5 was linked by the fix commit and release notes, and automatically
  closed when the fix reached `main`. No issue comment was sent.

## Runtime evidence boundary

The same icon implementation underwent a temporary signed local installation
before version preparation. The changed extension loaded in real Finder, and
the user completed visual acceptance and explicitly confirmed success. The
original installation, preference bytes and system appearance were restored.
See the [fix task](tasks/finder-monochrome-appearance.md) and
[acceptance record](ACCEPTANCE.md#finder-monochrome-system-appearance-fix--2026-09-30).

That local QA candidate carried 0.6.3/build 22 metadata and was not a new notarized
release. This publication used the accepted 0.6.4/build 23 artifact and did not
repeat installation, screenshots or an old-to-new update. macOS 13 runtime,
clean-Mac/managed-device trust and a public-feed update to this exact DMG were not
independently tested.
