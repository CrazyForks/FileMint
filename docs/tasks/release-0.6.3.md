# Task: FileMint 0.6.3 release

Status: complete
Next action: None for the selected standard publication scope; retain the remaining native QA limitations.

## Objective and scope

- Publish FileMint 0.6.3, build 22, through the standard distribution workflow.
- On 2026-09-30 the user selected the standard release workflow instead of
  completing the remaining exhaustive native QA. Preserve earlier observations
  without treating the unfinished checklist as a completed full QA pass.
- Preserve owner files, preferences, clipboard and authorization choices. Use
  disposable fixtures and record unavailable hardware or permission scenarios.

## Selected context

- [Distribution](../../specs/domains/distribution.md),
  [Presentation](../../specs/domains/presentation.md),
  [release procedure](../DISTRIBUTION.md), [HARNESS](../../specs/HARNESS.md),
  [native QA](../FINDER_QA.md),
  [update verification](../../specs/verification/updates.md).
- Version source: `project.yml`; bilingual notes: `docs/RELEASE_NOTES.md`.
- Use `make release-local` for local signing/notarization/artifact checks and
  `make publish-local` after those checks pass.

## Decisions and progress

- Live GitHub latest is v0.6.2; local main matches origin/main at `1926822`.
- Release changes are custom menu symbols/colors, global monochrome menu icons
  and Copy Paths from captured Finder folder backgrounds.
- Earlier work began an exhaustive QA run. The user's current standard-workflow
  selection supersedes that remaining scope; routine publication does not repeat
  temporary installation, UI review or old-to-new runtime acceptance.
- The first native fixture build exposed stale dependency lists after menu icon
  and terminal features were added. Repair the QA scripts before rerunning them;
  retain the failed logs and do not count a compile-only result as feature proof.
- macOS 27.2 / arm64 with Xcode 27.0 is available; macOS 13 and a clean Mac are
  separate environments and must not be represented as tested here.

## Evidence

Current checks: `1926822` plus release preparation and QA-script repairs,
2026-09-30, macOS 27.2 / arm64, Xcode 27.0 (27A266a).

| Check | Status | Evidence |
| --- | --- | --- |
| Offline suite and CLI regressions | passed | `build/release-0.6.3/verify.log`: 178 Core tests, 14 image tests, 5 public cases, 10 CLI regressions and release-script checks |
| Bilingual website and README includes | passed | `build/release-0.6.3/site-build.log` |
| Release metadata and script syntax | passed | 0.6.3/build 22 exceeds live v0.6.2/build 21; `git diff --check` and repaired-script `bash -n` passed |
| Native settings, icon rendering, creation, templates and image panels | not-run this publication turn | Earlier observations retained under `build/qa-0.6.3/`; exhaustive installed Finder checks remain incomplete |
| Sandbox file operations and update checks | not-run this publication turn | Earlier sandbox and signed replacement/relaunch observations retained under `build/qa-0.6.3/`; they are not evidence for the final notarized DMG |
| Installed Finder behavior, macOS 13 and clean-Mac acceptance | not-run | Outside the selected routine-release scope; no new installation or permission changes |
| Notarization, final DMG and appcast | passed | `make release-local`, release commit `5d4d0fa`, notarization `b43741cf-3123-4c1c-b5ef-4a4c92889c0d` Accepted; final SHA-256 and artifact checks in the release evidence |
| Public upload and remote verification | passed | `make publish-local`, three assets downloaded and compared byte for byte; release verification, CI and website deployment passed |

Final source: `v0.6.3` at `5d4d0fa17a2cfac85231df816ee6bf3dc4b3f584`.
Publication and runtime boundaries are recorded in
[release verification](../RELEASE_VERIFICATION_0.6.3.md).

## Handoff

- The selected release scope is complete. Remaining exhaustive native scenarios
  stay unverified and are not represented as release passes.
- Evidence logs remain under ignored `build/`; final results are recorded
  in `docs/RELEASE_VERIFICATION_0.6.3.md` and acceptance history.
- Do not weaken a failed check or count old evidence as a current pass.
