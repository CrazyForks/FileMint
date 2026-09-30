# Task: Homebrew tap installation and release synchronization

Status: planned
Next action: When implementation is requested, follow the restart checklist below, update the owning distribution contract, then implement the Cask and synchronization tooling. Do not implement or publish during this planning task.

## Objective and scope

Provide a FileMint-maintained Homebrew tap so users can install the same signed,
notarized DMG distributed through GitHub Releases:

```sh
brew install --cask filemintapp/tap/filemint
```

This is the **target command, not an available installation method yet**.
Source request: [issue #4](https://github.com/FileMintApp/FileMint/issues/4).

The first delivery includes the tap, repeatable version synchronization, bilingual
usage instructions, and installation/upgrade/uninstallation acceptance. Submission
to `homebrew/cask` is a separate future task. No new server, binary build pipeline,
package dependency, updater implementation, or Apple credential storage is needed.

On 2026-09-30 the user explicitly requested planning only. This record is written
in English and must remain detailed enough to resume without this conversation.
Implementation, repository creation, installation, publication and issue replies
have not been performed. A later implementation request starts local work;
publication and changes to the user's installed app follow that request's scope.

## Selected context

- Owning contract: [Distribution](../../specs/domains/distribution.md).
- Related contracts: [Updates](../../specs/domains/updates.md),
  [Creation and drafts](../../specs/domains/creation.md),
  [Finder and permissions](../../specs/domains/finder-permissions.md),
  [Presentation](../../specs/domains/presentation.md).
- Existing entry points: `scripts/publish_local.sh`,
  `scripts/wait_release_verification.sh`, `scripts/verify_release_artifact.sh`,
  `scripts/update_appcast.py`, `scripts/release_metadata.py`, `project.yml`.
- Data preservation: `FileMintPreferencesStore` / `FileMintStorage` in
  `CorePackage/Sources/FileMintCore/Preferences.swift` and `DocumentTemplateStore.swift`.
- Quit behavior: `CorePackage/Sources/FileMintCore/ApplicationTerminationPolicy.swift`,
  `App/FileMint/AppDelegate.swift`, `SharedUI/CustomFileSavePanelController.swift`.
- Checks: [HARNESS](../../specs/HARNESS.md) and
  [Distribution procedure](../DISTRIBUTION.md). Load detailed
  [Finder checks](../../specs/verification/finder.md) and
  [update checks](../../specs/verification/updates.md) when planning native acceptance.

## Current baseline and evidence limits

Reviewed source: `921e91d`, version 0.6.4 / build 23, on 2026-09-30.
The release API reported 0.6.4 with DMG, portable SHA-256 and appcast assets.
The expected public `FileMintApp/homebrew-tap` repository returned 404 during
research; check again before creating anything. No Cask exists in this checkout.

The main app ID is `io.github.daigua.filemint`; the extension ID is
`io.github.daigua.filemint.findersync`. Current distribution targets M-series Macs
running macOS 13 or later and contains arm64 code only. Homebrew's architecture
constraint denotes Apple silicon and cannot independently enforce an M-series-only
support policy; preserve that distinction in the documentation.

`publish_local.sh` already validates the local release manifest, publishes the
three assets, downloads and compares them byte-for-byte, then waits for the
published-release verification job. Tap synchronization must follow all of those
steps. The latest version and digest in this snapshot are not future constants.

The review inspected Homebrew 6.0.11, revision
`6bd951d96e7ebc54787799dba77bfb26ec956c4c`. Its `uninstall quit:` also runs during
upgrade/reinstall; a failed quit times out with a warning rather than guaranteeing
that replacement stops. FileMint's ordinary Quit permits discarding an idle draft,
while its Sparkle restart path checks for drafts. These source observations inform
the first-delivery policy below; they do not prove native upgrade behavior.

This is static/source and remote-metadata evidence. It is not a new DMG signature,
notarization, Homebrew installation, or Finder runtime acceptance result.

## Repository and file ownership

| Repository | Proposed path | Responsibility |
| --- | --- | --- |
| `FileMintApp/homebrew-tap` | `Casks/filemint.rb` | Generated Cask for one verified stable release |
| tap | `README.md`, `README.en.md` | Installation, updates, migration, removal, requirements and support links |
| tap | `.github/workflows/validate.yml` | Read-only Cask validation on PRs/pushes; no publishing or signing credentials |
| main | `scripts/homebrew/filemint.rb.in` | Canonical Cask layout with version/digest placeholders |
| main | `scripts/homebrew_tap.py` | Prepare/publish commands, validation, retry and remote readback |
| main | `scripts/test_homebrew_tap.py` | Offline validation, failure and synchronization regression cases |
| main | `scripts/publish_local.sh`, `Makefile` | Post-verification integration and offline test registration |
| main | domain/docs/README/install pages | Distribution contract, maintainer procedure and user instructions |

The tap is a separate checkout, never a nested tracked repository or submodule of
FileMint. Inspect/reuse an existing suitable checkout before creating one. The tap
contains no DMGs, appcasts, certificates, private keys or copied application source.

## Cask design

Generate these fields in Homebrew's stanza order:

| Field | Value / rule |
| --- | --- |
| token / name | `filemint` / `FileMint` |
| version | Validated three-component stable version, e.g. `0.6.4`; never `:latest` |
| sha256 | SHA-256 calculated from the verified final DMG; never `:no_check` |
| url | `https://github.com/FileMintApp/FileMint/releases/download/v#{version}/FileMint-#{version}.dmg` |
| desc | `Create files and use file tools from Finder` |
| homepage | `https://filemintapp.github.io/FileMint/` |
| livecheck | `url :url`, `strategy :github_latest`, strict three-component tag matching |
| auto_updates | `true`, because the app can replace itself through Sparkle |
| depends_on | `arch: :arm64` and `macos: :ventura` (minimum); confirm syntax against the supported brew version |
| app | `FileMint.app` |
| uninstall | Omitted in the first delivery; the `app` artifact handles removal after the user quits FileMint |
| zap | Omitted intentionally in the first delivery; settings and user-imported template assets are retained |

Use `GithubLatest` because release tags exist before notarization/publication and
are not sufficient evidence of a downloadable stable release. Match only the tag
name with `^v(\d+\.\d+\.\d+)$`, not an arbitrary release-title version. Livecheck
reports upstream availability; it does not authorize a tap update or replace the
published-artifact verification gate.

Keep the Cask declarative: no installer scripts, shell commands, permission
changes, quarantine removal, hidden Finder activation or custom updater logic.
Put extension/folder setup guidance in the tap README and existing app onboarding.
Do not use a moving latest-download URL or repackage the DMG.
Do not add `quit:`, `signal:` or process-management hooks: an ordinary quit event
can discard a draft, and a refused quit is not an installation interlock. The
required user sequence and its limits are defined under updates below.

## Synchronization interface and data flow

Implement one Python standard-library entry point with explicit modes:

```text
python3 scripts/homebrew_tap.py prepare --manifest <release.json> --output-dir <staging-dir>
python3 scripts/homebrew_tap.py publish --manifest <release.json>
```

`prepare` performs read-only remote validation and writes only its staging output.
It neither commits nor pushes. `publish` repeats validation rather than trusting
an old staging receipt, then updates the tap. Both modes derive version, build and
commit from the specified manifest; they must not silently select a moving latest
release. Use subprocess argument arrays and existing git/gh credentials; never
interpolate remote strings into shell code or evaluate Cask Ruby to parse versions.

### Existing manifest and checksum contract

Accept the existing unversioned JSON object produced by `scripts/release_local.sh`.
Its fields are strings: `version`, `build`, `tag`, `commit`, `dmgSHA256`,
`certificateSHA256`, `appcastSHA256` and `notarySubmissionID`. Validate three-component
version, positive decimal build, matching `vVERSION` tag, full commit hash,
64-character lowercase SHA-256 values and UUID submission ID. Reject missing,
duplicate or unexpected fields and wrong JSON types. Do not require a new
`schemaVersion` or `checksumSHA256` field or rewrite an existing release manifest.

| Input | Required comparison |
| --- | --- |
| `FileMint-VERSION.dmg` | Calculate SHA-256 and compare with `dmgSHA256` |
| `FileMint-VERSION.appcast.xml` | Calculate SHA-256 and compare with `appcastSHA256`; pass this local filename explicitly to the existing verifier |
| `FileMint-VERSION.dmg.sha256` | Require exactly one LF-terminated line containing the calculated DMG digest, two spaces and the exact DMG basename; reject other filenames, paths, additional lines or digest mismatch |
| `Config/Signing/DeveloperIDApplication-8S66M2ZLD5.cer` | Compare SHA-256 with `certificateSHA256`, retaining the existing expected signing-identity checks |

The checksum file contains the **DMG's** digest; the manifest has no hash of the
checksum file itself. Reuse `verify_release_artifact.sh`'s portable-checksum rule.
The local submission ID is evidence metadata, not proof of accepted notarization;
ticket, signature, bundle and appcast checks remain mandatory. Remote readback
still compares all three release assets byte-for-byte, mapping remote `appcast.xml`
to the versioned local feed. A freshly computed checksum-file hash may be recorded
in the staging receipt without becoming a required input-manifest field.

Validation sequence:

1. Apply the manifest/checksum contract above. Resolve only the expected artifact
   names next to the manifest; compare the DMG/appcast hashes and checksum contents
   separately. Reuse existing artifact/appcast checks, including the expected
   signing identity, architecture and notarization requirements.
2. Resolve `vVERSION` to the manifest commit locally and remotely, including annotated
   tag peeling. Bootstrap may use an existing release whose source predates the
   new tooling; the helper must not require the tool's HEAD to equal that old tag.
3. Require the selected release to be published, stable and the currently designated
   latest stable release. Reject drafts, prereleases, missing/extra assets, foreign
   repository URLs and mismatched names. Reject an older bootstrap/update request.
4. Download the exact DMG, checksum and appcast to an owned temporary directory and
   compare all three against the verified local bytes. Calculate the DMG hash;
   GitHub's digest field alone is not sufficient. Run the existing release workflow
   verification for the exact tag/commit. A passed unrelated CI run is insufficient.
5. Render the Cask deterministically. `prepare` writes `filemint.rb` plus a receipt
   containing version, build, source commit, hashes and release verification
   evidence to its output directory. Never include machine-specific private paths
   or credentials in published files.
6. `publish` clones the exact tap remote to an owned temporary checkout. Require
   default branch `main` and validate the current Cask against the expected layout;
   preserve README/workflow files. Unexpected hand edits require review, not overwrite.
7. Compare numeric version components. Same version + identical Cask is an
   idempotent success. Same version + different DMG digest, a lower version, or
   unrecognized Cask layout fails. Do not rewrite published version history.
8. Run Cask style/readall/online audit on the candidate before any push. Commit only
   `Casks/filemint.rb` as `chore: update filemint to VERSION`, then perform a normal
   fast-forward push to `main`. Never force-push or bypass repository protection.
9. Read back the remote branch and Cask bytes and compare them with the candidate.
   Record the tap commit and version. An ambiguous push result is resolved by
   readback before retrying. If another writer advances the branch, stop and rerun
   from a fresh checkout; never reset their work or automatically downgrade.
10. Remove only owned temporary downloads/checkouts and release-validation mounts.
    Do not touch an installed App, existing developer checkout or application data.

Use the owner's existing local GitHub authentication for the first delivery.
Do not introduce a cross-repository PAT, GitHub App or Apple secrets in CI.
If branch protection prevents a fast-forward push, report that concrete blocker;
do not silently switch delivery strategy or weaken protection.

### Integration, bootstrap and failure behavior

- Add the publish-mode call **after** `wait_release_verification.sh` succeeds in
  `publish_local.sh`. Document tap synchronization as the final distribution step
  before enabling it; local builds and `release-local` never publish the tap.
- Bootstrap from the latest already verified stable release when its local manifest
  and exact artifacts are available. If absent, recover the verified local evidence
  first; do not rebuild/re-sign an already published version or bypass verification.
- Prepare the tap skeleton and generated Cask locally, validate them, then create
  and publish the remote repository only within the authorized publication scope.
  Initial publication includes the Cask; do not advertise an empty tap.
- Install the initial tap before enabling the main release hook in routine use.
  A missing tap remote is an explicit synchronization failure, not an implicit
  instruction for the release script to create a public repository.
- On tap failure after the app release succeeds, return nonzero with separate
  outcomes: `App release published and verified; Homebrew synchronization failed`.
  Print the manifest-based retry command. Do not roll back the app release or alter
  its three assets. A helper retry can finish without rerunning notarization.
- A retry after successful push/readback must be a no-op. Authentication, rate-limit,
  network, workflow and audit failures must preserve the currently published Cask.
- Exit codes: 0 for verified success/no-op; 2 for invalid input or invariant failure;
  3 for remote/auth/workflow failure; 4 for Cask validation failure. Include the
  failing phase without leaking tokens or user file paths.

## User workflows and data policy

### Fresh installation and first launch

After launch, users enable the Finder extension and grant folder access through the
existing system/app UI. Homebrew cannot grant those permissions. Preserve quarantine
and normal Gatekeeper assessment. No Finder restart, login-item enablement, silent
app launch or permission-database modification is part of installation.

### Updates and Sparkle coexistence

Keep FileMint's existing weekly discovery and user-requested Sparkle installation.
Do not introduce a brew-specific application preference or disable the updater.
Document `brew update`, ordinary `brew upgrade`, and the app's Update and Restart
path. Explain explicitly that Cask receipts may lag after an in-app update.

The first delivery does not ask Homebrew to quit or relaunch FileMint. Before any
brew upgrade that can include FileMint, reinstall, adoption or uninstall, users
must save or explicitly cancel drafts, finish creation/template-import/file
operations and any Sparkle installation, then manually quit FileMint and confirm
it has exited. Do not start either installer while the other is active. If Quit
is refused or an operation is still running, stop the procedure and wait; never
force termination to continue. `brew update` only refreshes package metadata and
does not itself require quitting FileMint.

Put this prerequisite immediately before the relevant commands in both languages,
including the ordinary bulk `brew upgrade` example. Omission of `quit:` prevents
the Cask from requesting a draft-discarding quit; it does **not** make Homebrew
refuse replacement of a running bundle. `--no-quit` is not a busy-state guard
either. Do not claim unattended upgrades, safe simultaneous Sparkle/brew installs,
or that declining Quit cancels an external brew operation. The supported first
delivery uses an exited app; an enforced running-app interlock would need a
separate design and owning-contract review.

Native acceptance must also probe bypassed prerequisites in the isolated QA
environment: an open edited draft, active writes and a refused Quit. Record process,
draft, bundle and file outcomes, including whether brew continues replacement.
These probes characterize the unsupported running-app path; they cannot establish
that it is safe merely because brew exits zero. Any candidate-induced quit, draft
loss or interrupted/corrupted write blocks publication until resolved. Even a
replacement without observed data loss does not establish support for running-app
updates or concurrent installers.

Current Homebrew can compare the actual bundle version for suitable `auto_updates`
Casks; explicit named upgrades and `--greedy` can bypass that default decision.
Do not present `--greedy`, `reinstall` or a named upgrade as an unconditional repair.
When the app is newer than the tap, keep the app and wait for tap synchronization.
Test this on the actual supported brew version, recording its version/revision.
No product code change is planned to alter Homebrew's own upgrade behavior.

### Existing manual installation

- An ordinary install encountering an existing App should fail without overwriting it.
- Same released version/build: validate bundle ID, Developer ID identity and installed
  version, then test `brew install --cask --adopt filemintapp/tap/filemint`.
- Older manual install: update it to the tap's version using the existing supported
  installation path, then adopt. Respect historical 0.5.7/0.5.8 manual-update limits.
- Newer manual install: retain it; wait until the tap catches up before migration.
- Do not rely on `--adopt` as a signature/version check: the inspected brew code
  skips its usual content/version comparison for `auto_updates` Casks.
- Do not recommend `--force`, delete the existing App automatically, or install a
  second app bundle to hide a conflict. Only document adoption after native testing.

### Uninstall and reinstall

Document `brew uninstall --cask filemintapp/tap/filemint`. Ask users to finish
active work and quit the app first using the prerequisite above. If it cannot
quit safely, defer removal. The Cask neither quits nor force-kills FileMint, its
extension, Sparkle helpers or Finder, and does not relaunch the app after reinstall.

Normal removal deletes the managed app only. Preserve the FileMint application
support directory, `preferences.json`, `document-templates`, saved bookmarks,
legacy containers and every user-created file. The first delivery has no `zap`
cleanup contract; explicitly state that settings/templates are retained, including
when users expect a full reset. Do not add a broad `~/Library/*filemint*` deletion.
A future reset/cleanup feature needs a separate data-retention design.

macOS may keep an extension process alive temporarily after removal. Verify the
bundle registration/menu lifecycle without resetting system databases; distinguish
that from leftover app files. Reinstallation should restore the preserved settings,
while permission usability remains subject to the actual system state.

## Native QA isolation

Use a disposable Apple-silicon macOS VM or a dedicated disposable test Mac for
the first delivery. A temporary account on the user's working Mac is insufficient:
`/Applications`, a reused Homebrew prefix and its Caskroom can still be shared.
Changing `--appdir` alone also does not isolate Finder registration. Account-only
QA is not an alternative in this task.

- Keep the guest/test system's Homebrew prefix, Caskroom, app directory, home data
  and Finder/LaunchServices state separate from the user's working environment.
  Do not share or mount host application, Homebrew or user-data directories into
  the VM; transfer only reviewed artifacts and synthetic fixtures.
- Before adoption, upgrade, uninstall or reinstall, record the effective prefix,
  Caskroom, configured app directory and resolved FileMint bundle identity. Stop
  if a path resolves outside the disposable system or an unexpected installation
  or registration is present. Keep private paths in local QA evidence only.
- Use a clean VM snapshot/test-system baseline for fresh installation and conflicts;
  keep controlled fixture data across an upgrade or removal/reinstall case to
  prove retention. Run the exact public install command with default guest paths.
- Never remove/adopt/replace the user's installed app to unblock QA. If no suitable
  environment is available, record native acceptance as `blocked`, complete local
  tooling/documentation, and leave initial tap publication and completion pending.

## Implementation sequence

1. [ ] Refresh the restart checks; update distribution SPEC and distribution docs
   with the tap contract, manual-quit prerequisite and its limits, retention policy,
   post-release ordering and failure states. Preserve the existing draft/update rules.
2. [ ] Add the deterministic template, helper and offline regression cases. Register
   applicable tests in the existing Makefile checks; preserve all current release gates.
   Include the existing manifest shape without a checksum-file hash and verify that
   the Cask contains no quit, signal or custom process-management hooks.
3. [ ] Prepare the separate tap skeleton, bilingual README and read-only validation
   workflow. Use reviewed pinned GitHub Action SHAs and least-privilege permissions.
   Test PRs must not have write credentials or publish anything.
4. [ ] Validate `prepare` against a verified stable release. Review the exact generated
   Cask and skeleton before publication; do not use the illustrative 0.6.4 forever.
5. [ ] Establish the isolation checks above, then run native acceptance in the
   disposable VM/test Mac, including running-app negative cases. Resolve safety
   failures before initial publication; do not substitute the user's installed app.
6. [ ] Publish the initial tap within scope, verify a clean-machine installation from
   its public URL, then finish/enable the final release hook and retry procedure.
7. [ ] Update Chinese/English README and installation pages with verified commands;
   remove the pending roadmap item only when implementation and required acceptance
   are complete. Do not claim the live website changed until it is deployed.
8. [ ] Record code/tap commits and evidence here. Post completion to issue #4 only
   if messaging is authorized; otherwise leave a ready-to-send summary locally.

## Verification matrix

These are future checks, not actions authorized by this planning turn.

| Area | Required cases and pass condition |
| --- | --- |
| Pure generation | Numeric version ordering (`0.6.9` / `0.6.10`), strict tag/hash parsing, exact URL and reproducible Cask; reject shell/Ruby injection strings |
| Manifest/checksum compatibility | Existing eight-string-field manifest passes without `schemaVersion`/`checksumSHA256`; wrong/missing/duplicate fields, wrong types, certificate/feed/digest mismatch, checksum with wrong basename/path, extra line or missing final LF: no tap write |
| Source/artifact validation | Bad manifest, wrong tag commit, invalid signatures/minimum OS/architecture, draft/prerelease, extra/missing assets, checksum/appcast mismatch, unrelated/failed release job: no tap write |
| Synchronization | Initial Cask, newer release, exact no-op, same-version hash change, downgrade, unexpected layout, auth failure, concurrent push, push-success/readback-failure retry; mock network/push using disposable fixtures |
| Release integration | Failure at every preexisting gate prevents tap sync; tap failure preserves verified app assets and returns the documented partial-success state |
| Homebrew tooling | `brew style`, `brew readall`, `brew audit --cask --online --strict`, `brew livecheck --cask` and checksum-verified fetch against the local/remote tap; no fake success for unavailable network |
| Cask process policy | No `quit:`, `signal:`, process-management scripts or custom relaunch; user guidance requires completed work and confirmed exit before replacement/removal and does not claim a running-app interlock |
| QA isolation | Disposable VM/test Mac; prefix/Caskroom/app paths and bundle identity verified inside it; no host app/data/shared Homebrew access; unavailable isolation blocks native QA and initial publication |
| Fresh install | Supported Apple-silicon host: install, Gatekeeper launch, correct app version, first-run extension/folder guidance and real Finder creation |
| Requirements | Intel and pre-macOS-13 dependency rejection via Homebrew configuration checks; real macOS 13 app/Finder acceptance separately when an environment is available |
| brew upgrade | Two distinct published signed versions; save/cancel drafts, finish operations and confirm app exit first; preserve config/templates/bookmarks, load new Finder extension, create a file after upgrade |
| Running-app negative cases | In isolated fixtures, probe an edited draft, active creation/import/file operation, and Quit refusal; observe whether brew proceeds and verify exact draft/file retention and successful completion of writes. Candidate-induced quit, draft loss or interrupted/corrupted writes block publication; continued replacement must never be described as a protective refusal |
| Sparkle coexistence | In-app upgrade then ordinary brew upgrade; app newer than tap; named/greedy/reinstall behavior characterized on supported brew without recommending destructive results |
| Manual migration | Same-version adoption, old/newer/manual conflicts and wrong bundle identity; preserve app and data on rejection |
| Removal/reinstall | Managed app removed, user files/settings/templates unchanged; no stale duplicate install; reinstall restores preferences and real creation works |
| Documentation | Context/local links, bilingual roadmap/install consistency, `SITE_BASE=/FileMint/ pnpm run site:build`, rendered home/install pages |

Run `make verify` after implementation because release/test infrastructure changes.
Apply existing release artifact checks; app builds/native update checks follow the
actual changed surface. For native tests use fixture preferences and synthetic
files only; record app version/build/hash, brew version, macOS/architecture and
source/tap commits. Static parsing, audit and fake receivers do not prove Finder
or installed update behavior. Unavailable native environments remain `not-run` or
`blocked`, not silently passed.

## Completion criteria

- [ ] The public fully qualified install command works against the intended tap.
- [ ] Cask bytes refer only to a verified stable release and pass the agreed checks.
- [ ] Publication and tap synchronization are ordered, idempotent and recoverable.
- [ ] Required installation, upgrade, migration and removal scenarios have evidence;
  remaining environment limits are explicitly accepted/documented rather than hidden.
- [ ] Native QA isolation is recorded; running-app negative cases and manual-quit
  prerequisites are documented. No unresolved candidate-induced quit, draft loss or
  interrupted/corrupted writes; no claim that Homebrew enforces these prerequisites.
- [ ] Data/permission boundaries and Sparkle coexistence are documented accurately.
- [ ] Bilingual instructions and roadmap match availability; no unsupported claim of
  official Homebrew endorsement, complete cleanup or unattended permission grants.

## Evidence and handoff

| Check | Status | Evidence |
| --- | --- | --- |
| Issue, current source, release metadata and Homebrew design research | passed | Read-only review at `921e91d`, 2026-09-30; baseline and references in this task |
| Initial planning documentation | passed (prior planning) | `make verify-context`, local link targets and `git diff --check`; task remains English and `planned` |
| Review amendments, 2026-09-30 | passed | `921e91d` plus task-only amendments: `make verify-context` (21 documents, 115 links, 6992/7000 bytes), explicit task link/anchor check (9 targets), task whitespace check and `git diff --check`; no implementation/native check implied |
| Bilingual roadmap build | passed (prior planning) | `SITE_BASE=/FileMint/ pnpm run site:build`; both generated homepages contain the pending Homebrew item; not rerun for these task-only amendments; no live deployment or browser visual acceptance claimed |
| Cask implementation / installation / synchronization | not-run | Planning only; no Cask, helper, tap or release-hook implementation exists |

All implementation checkboxes remain open. Do not change status to `in-progress`
until implementation begins, or to `complete` merely because this plan is finished.

Restart checklist:

1. Read this task, inspect current worktree/branch and verify relevant instructions.
2. Refresh the latest stable release, local manifest/artifacts, remote tag, existing
   tap and Homebrew version; do not reuse historical API results as current evidence.
3. Load the selected domain contracts and relevant script sections only, including
   creation/quit behavior; confirm the supported brew revision and isolated QA
   environment before any native installation or replacement.
4. Follow the implementation sequence. The first concrete edit is the distribution
   contract, followed by the Cask template/helper and their targeted tests.
5. If authorization excludes publishing or installed-app changes, complete all local
   implementation/reviewable artifacts and record the remaining delivery steps.

References checked during planning:

- [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)
- [Creating and maintaining a tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)
- [Homebrew FAQ: self-updating applications](https://docs.brew.sh/FAQ)
- [Livecheck strategies](https://docs.brew.sh/Brew-Livecheck)
- [Package Acceptance Policy](https://docs.brew.sh/Package-Acceptance-Policy)
- [Acceptable Casks](https://docs.brew.sh/Acceptable-Casks)

Recheck official admission rules when that separate task starts. Meeting numerical
notability criteria does not guarantee acceptance; self-submissions have different
criteria. None of those thresholds blocks maintaining this project-owned tap.
