# Task: Fix the eight full-code-review findings

Status: complete
Next action: None for implementation; installed Finder and real release checks remain release-time acceptance.

## Objective and scope

- Fix all eight findings from the 2026-09-28 review of `684dba2` plus the existing favorite-location worktree changes.
- Preserve the pre-existing seven modified files and their behavior fixes. No version bump, publication or installed-app replacement.
- Acceptance: creation cannot be interrupted by ordinary quit; permission errors remain recoverable; ranks cannot overflow; favorites filter cleared recents, compute rows once and persist off the UI thread without lost updates; notarization resumes before/after stapling; native move/open-with fixtures compile.

## Selected context

- Contracts: [Creation](../../specs/domains/creation.md), [Templates](../../specs/domains/templates.md), [Finder](../../specs/domains/finder-permissions.md), [Favorites](../../specs/domains/favorite-locations.md), [Startup](../../specs/domains/startup.md), [Updates](../../specs/domains/updates.md), [Distribution](../../specs/domains/distribution.md).
- Checks: [HARNESS](../../specs/HARNESS.md), [Core](../../specs/verification/core.md), [Native](../../specs/verification/finder.md), [Distribution procedure](../DISTRIBUTION.md).

## Decisions and progress

- Use an actor for serialized favorite catalog transactions; apply versioned snapshots on the main actor so delayed completions cannot roll back newer state.
- Keep the submitted DMG intact while stapling a private copy; record both hashes before publishing the validated copy. Test with local command stubs only.
- Keep native QA fixtures isolated from real preferences; compile their actual source lists after repairing dependencies.
- Implemented the eight fixes. Core/script regression, unsigned Release build,
  both native fixture builds and the isolated favorite-model smoke have passed.
- Native UI confirmed recent clearing, pin persistence and name/group editing.
  It also exposed position-based quick-search row reuse; UUID row/scroll IDs
  fixed it. Searching Lake displayed Lake.png and Return selected that exact
  file in Finder. Fixture catalog readback confirmed the writes.

## Evidence

Tested commit/worktree: `684dba2` plus existing and current uncommitted changes.
Environment: local Apple silicon macOS / Xcode.

| Check | Status | Evidence |
| --- | --- | --- |
| Core and script regression / `make verify` | passed | [Log](../../build/review-fixes/verify.log): 164 Core + 14 image tests; Harness/CLI and release-script regressions |
| Unsigned Release app/extension build | passed | [Log](../../build/review-fixes/build.log): final production sources compile |
| Favorite model smoke | passed | [Log](../../build/review-fixes/favorite-model.log): 1,000 entries, concurrent edits, revoked policy, recovery |
| Move/open-with harness builds | passed | [Move](../../build/review-fixes/move-harness.log), [Open with](../../build/review-fixes/open-with-harness.log); no interactive folder grants |
| Isolated native favorites UI | passed | [Fixture build](../../build/review-fixes/design-harness.log); scenarios recorded in [acceptance](../ACCEPTANCE.md#2026-09-28--full-review-fixes-and-isolated-favorites-qa) |
| Installed Finder / real notarization / publication | not-run | Outside this repair run; no installed-app replacement or publication |

## Handoff

- Remaining implementation work: none. Changes remain uncommitted with the user's pre-existing edits preserved.
- Native limitation: isolated tests/builds do not prove installed Finder callbacks or system authorization UI.
