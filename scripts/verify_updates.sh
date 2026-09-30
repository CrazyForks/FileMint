#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# This is deliberately separate from offline make verify: it downloads a real release.
swift build --package-path CorePackage
CORE_BUILD="$(swift build --package-path CorePackage --show-bin-path)"
if [[ -f "$CORE_BUILD/libFileMintCore.a" ]]; then
  CORE_LINK=(-I "$CORE_BUILD" "$CORE_BUILD/libFileMintCore.a")
else
  CORE_LINK=(-I "$CORE_BUILD/Modules" "$CORE_BUILD"/FileMintCore.build/*.o)
fi
SMOKE_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/filemint-update-smoke.XXXXXX")"
trap 'rm -rf "$SMOKE_DIRECTORY"' EXIT
swiftc -swift-version 6 -parse-as-library \
  App/FileMint/UpdateClient.swift scripts/update_smoke.swift \
  "${CORE_LINK[@]}" -o "$SMOKE_DIRECTORY/verify-updates"
"$SMOKE_DIRECTORY/verify-updates"
