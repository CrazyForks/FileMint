# Task: Custom Finder menu icons

Status: complete
Next action: Check the changed menu in an installed signed Finder extension when a QA candidate is available.

## Objective and scope

- User-visible outcome: Choose a macOS system symbol and its colors for Finder menu entries; templates have visible defaults and editable icons in Templates & Types.
- In scope: New File root and actions, template rows, File & Folder Tools root and actions including Move Here, Resource Tools root and actions, Open with App root, Favorite Locations root. The configured App and favorite child entries retain their current icons.
- Acceptance criteria: A searchable, incremental symbol gallery offers the bundled unrestricted catalog, with direct name input for newer symbols. Saved symbols and colors refresh Finder without relaunch; default/reset works; older preferences keep existing behavior; unsupported symbols fall back to the default; settings and Finder show the same selected icon. No arbitrary image upload or extra filesystem access.

## Selected context

- Domain contracts: [Presentation](../../specs/domains/presentation.md), [Templates](../../specs/domains/templates.md), [Creation](../../specs/domains/creation.md), [Finder](../../specs/domains/finder-permissions.md), [Startup](../../specs/domains/startup.md), [File tools](../../specs/domains/file-tools.md), [Resource tools](../../specs/domains/resource-tools.md), [Open with App](../../specs/domains/open-with.md), [Favorite locations](../../specs/domains/favorite-locations.md), [Distribution](../../specs/domains/distribution.md).
- Implementation entry points: `FileTemplate.swift`, `Preferences.swift`, `MenuIcons.swift`, `SharedUI/FileToolAppearance.swift`, `FinderSync.swift`, `TypesPane.swift`, `SettingsSections.swift`, `MenuIconControl.swift`, `SystemSymbolCatalog.swift`, `FileToolsSettingsView.swift`, `ResourceToolsView.swift`, `OpenWithSettingsView.swift`, `FavoriteLocationsView.swift`, `project.yml`.
- Verification: `make verify`, unsigned app build, affected settings and Finder icon appearance checks from [HARNESS](../../specs/HARNESS.md).
- Load additional context when: Creation behavior, favorite data or app opening logic changes beyond icon presentation.

## Decisions and progress

- User chose customization of both first-level entries and eligible children, using SF Symbol names and user-selected colors.
- App entries and saved favorite child entries are excluded; their root entries remain eligible.
- Keep bundled FileMint logo as the default New File root icon; an explicit selection replaces it with a system symbol.
- The first 35-name picker was too restrictive. Generate a 6,408-name text catalog from SFSafeSymbols stable commit `cb2e670a213ff42ae08528ee2c401bfb1d799675`, omitting its restricted and deprecated entries. Keep the 682 restricted names as a separate validation list so exact-name input cannot reintroduce them, except an action's own referential default. Bundle its MIT notice; do not add a package dependency or symbol artwork.
- Core stores validated symbol names and two sRGB colors, with legacy/default decoding. Finder renders saved choices and falls back when a symbol is unavailable. The type editor preserves per-template choices across edits and changes only uncustomized suffix defaults.
- The picker searches all bundled names, loads the grid 88 candidates at a time, previews the native colors, and resets each choice. The isolated settings fixture showed 6,408 names, 26 `folder` matches, a saved folder choice in the settings row, and a disabled Save button for restricted `airplayaudio` on an unrelated action.

## Evidence

Tested commit/worktree: base `21f65cd` with the working changes in this task
Environment: local macOS development checkout, Xcode Release build, isolated unsigned settings fixture

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| `make verify` | passed | 14 image tests, 172 Core tests, public harness, CLI and artifact checks; [log](../../build/custom-finder-menu-icons-verify.log). |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | Main app and Finder extension built; three symbol text/notice resources exist only in the main app; [log](../../build/custom-finder-menu-icons-build.log). |
| Isolated native settings fixture | passed | Search, selection preview and restricted-name gating inspected in Chinese light appearance; no real preferences touched. |
| Installed Finder callback/appearance | not-run | Requires a signed installed QA candidate and system-enabled extension; no installation or enablement was requested. |

## Handoff

- Remaining work: Installed signed Finder acceptance when preparing a release candidate.
- Files currently changed: Core icon model/tests, native picker/settings/Finder rendering, bundled name/notice resources, Xcode project source, and owning specifications.
- Known limitations / native checks still needed: Actual Finder callback and menu appearance, dark appearance, and macOS 13 runtime symbol availability were not observed in this checkout.
- Next action and the minimum context required: Use this task and [Finder/native checks](../../specs/verification/finder.md) with a signed installed candidate; preserve the user's extension-enable choice.
