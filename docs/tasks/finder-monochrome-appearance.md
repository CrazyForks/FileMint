# Task: Adaptive monochrome Finder menu icons

Status: complete (implementation, automated checks and user-confirmed real Finder acceptance)
Next action: None. Published in FileMint 0.6.4 / build 23.

## Objective and scope

- Fix [issue #5](https://github.com/FileMintApp/FileMint/issues/5): FileMint's own
  monochrome symbols and F logo must remain legible in light and dark Finder menus.
- Use the Finder extension's current system appearance when each menu is built;
  the main app's explicitly chosen window theme does not control Finder.
- Keep existing symbols, saved colors, labels, targets, app icons and toolbar/menu
  bar glyphs. No new preference, dependency, image catalog or theme observer.
- A system theme change must affect the next opened menu without a relaunch.
  Verify native main/submenus and highlighted rows separately from raster checks.

## Selected context

- Contracts: [Presentation](../../specs/domains/presentation.md),
  [Finder and permissions](../../specs/domains/finder-permissions.md).
- Entry points: `SharedUI/FileToolAppearance.swift`,
  `FinderSyncExtension/FileMintFinderSync/FinderSync.swift`,
  `scripts/file_tools_settings_smoke.swift`.
- Checks: [SharedUI/Finder and appearance rows](../../specs/HARNESS.md),
  [native Finder checks](../../specs/verification/finder.md),
  [icon QA](../FINDER_QA.md#file-and-folder-tools).

## Decisions and progress

- Keep template images for native settings previews. For Finder menus, add
  explicit white (dark theme) / black (light theme) pixels and clear template
  status on the exported image. This avoids depending on Finder's template
  handling or reinterpreting already resolved white pixels as a black template.
- Resolve the black/white tone in the extension's effective appearance once per
  menu, then reuse that immutable tone for all of its monochrome images. Do not
  use the callback thread's current drawing appearance as the system appearance.
- Render 1x and 2x bitmap representations from the same monochrome shape. Test
  TIFF round trips, because an image-only transfer cannot preserve template flags.
- Diagnostic on the unmodified renderer: `link` produces black pixels in both
  Aqua and Dark Aqua; a TIFF round trip clears `isTemplate`. An app explicitly set
  to Dark Aqua still reports Aqua as the idle/background current drawing appearance.
  This demonstrates why relying only on the flag/thread drawing state is
  insufficient; it does not establish Finder's internal serialization format.
- User supplied paired light/dark Finder screenshots. All own symbols and F logos
  remain black in the dark menu, including submenu items. The acceptance target
  is explicit white icons in this combination, with black icons in the light menu.

## Evidence

Tested commit/worktree: `1dde45f` plus this task's changes.
Environment: local Apple Silicon macOS 27.2, Xcode Swift 6.4; isolated native fixture.
Local logs/readback: `build/qa-2026-09-30-monochrome/` (ignored).

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| Offscreen pre-change rendering diagnostic | passed | Both appearances yielded black pixels; TIFF removed template status. |
| `make verify` | passed | 178 Core tests, 14 image tests, 5 public cases, 10 CLI regressions and the remaining offline checks passed. |
| Unsigned `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | Final App and Finder extension compiled for the macOS 13 deployment target. |
| Final isolated native icon fixture `run.hTtx9S`, `--verify-icons` | passed | 22 slots and 14 built-in templates, default/custom/unavailable symbols; black in Aqua, white in Dark Aqua at 1x/2x, including TIFF readback. Source templates stay intact, exported menu images are non-template, and Colored images pass through unchanged. |
| `git diff --check` | passed | No whitespace errors. |
| Local signed candidate | passed | Existing Developer ID identity, hardened runtime, nested signatures, arm64 bundle and sandbox entitlement checks passed. This was a local QA candidate, not a new notarized release. |
| Real Finder acceptance | passed | Candidate temporarily installed at `/Applications/FileMint.app`; the extension was active at that path and real main/submenus appeared in the owned test folder. The user completed visual acceptance and explicitly confirmed success. Details are in `native/user-acceptance.json`; no additional screenshots were taken after the request to stop. |
| Restore installed app/preferences/theme | passed | Original main/extension executables and preference bytes match their saved SHA-256 values. System appearance is back to Light; a single enabled extension is registered at the original install path. Temporary QA programs/window were closed. |
| macOS 13 runtime | not-run | Local environment is macOS 27.2; build compatibility is not macOS 13 runtime proof. |

## Handoff

- Completed: SPEC clarification, shared bitmap renderer, every own Finder symbol
  path, native regression fixture, QA checklist and acceptance record.
- Remaining work for this request: none. Visual acceptance is user-reported,
  distinct from the agent's menu-presence and image-pixel observations.
- Native limitation: no separate macOS 13 runtime or clean-install/notarization
  acceptance was performed.
- Issue reply/publication is outside this task.

## Publication follow-up

The user subsequently requested build/publication and issue association. Fix
commit `868bd8f` references `Fixes #5`; release tag `v0.6.4` points to `ccb3e87`.
The standard signed/notarized release was published, all three remote assets
matched their local originals, and release verification, CI and website
deployment passed. Issue #5 is closed; no issue comment was sent. See
[0.6.4 release evidence](../RELEASE_VERIFICATION_0.6.4.md).
