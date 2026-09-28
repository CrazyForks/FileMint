#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

DMG_PATH="${1:-$PWD/build/FileMint.dmg}"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found: $DMG_PATH"
  exit 2
fi

if [[ -n "${APPLE_NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  credentials=(--keychain-profile "$APPLE_NOTARY_KEYCHAIN_PROFILE")
elif [[ -n "${APPLE_NOTARY_KEY_PATH:-}" && -n "${APPLE_NOTARY_KEY_ID:-}" && -n "${APPLE_NOTARY_ISSUER_ID:-}" ]]; then
  credentials=(--key "$APPLE_NOTARY_KEY_PATH" --key-id "$APPLE_NOTARY_KEY_ID" --issuer "$APPLE_NOTARY_ISSUER_ID")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  credentials=(--apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID")
else
  echo 'Notarization needs a local notarytool Keychain profile, Team API key or app-specific password.' >&2
  exit 2
fi

submission_record="$DMG_PATH.notary.json"
record_temporary=''
stapling_directory=''
cleanup_notarization() {
  if [[ -n "$record_temporary" ]]; then rm -f "$record_temporary"; fi
  if [[ -n "$stapling_directory" ]]; then
    rm -f "$stapling_directory/$(basename "$DMG_PATH")"
    rmdir "$stapling_directory" 2>/dev/null || true
  fi
}
trap cleanup_notarization EXIT
if [[ -f "$submission_record" ]]; then
  submission_id="$(jq -r '.id // empty' "$submission_record")"
  submitted_sha256="$(jq -r '.dmgSHA256 // empty' "$submission_record")"
  stapled_sha256="$(jq -r '.stapledSHA256 // empty' "$submission_record")"
  current_sha256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
  [[ "$submission_id" =~ ^[0-9a-fA-F-]{36}$ && "$submitted_sha256" =~ ^[0-9a-f]{64}$ ]] || {
    echo 'Invalid saved notarization submission' >&2
    exit 1
  }
  if [[ "$stapled_sha256" =~ ^[0-9a-f]{64}$ && "$stapled_sha256" == "$current_sha256" ]]; then
    xcrun stapler validate "$DMG_PATH"
    echo "Verified previously notarized DMG: $DMG_PATH"
    exit 0
  fi
  [[ "$submitted_sha256" == "$current_sha256" ]] || {
    echo 'The saved notarization submission does not match this signed DMG' >&2
    exit 1
  }
  echo "Resuming Apple notarization submission: $submission_id"
else
  submission="$(xcrun notarytool submit "$DMG_PATH" "${credentials[@]}" --output-format json)"
  submission_id="$(printf '%s' "$submission" | jq -r '.id // empty')"
  [[ "$submission_id" =~ ^[0-9a-fA-F-]{36}$ ]] || { echo 'Apple did not return a notarization submission ID' >&2; exit 1; }
  submitted_sha256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
  record_temporary="$(mktemp "$submission_record.XXXXXX")"
  jq -n --arg id "$submission_id" --arg sha "$submitted_sha256" \
    '{id: $id, dmgSHA256: $sha}' > "$record_temporary"
  mv -f "$record_temporary" "$submission_record"
  record_temporary=''
  echo "Submitted to Apple notarization: $submission_id"
fi

if ! submission="$(xcrun notarytool wait "$submission_id" "${credentials[@]}" --timeout 30m --output-format json)"; then
  printf 'Apple notarization wait stopped for %s. Retain %s and resume this same submission.\n' \
    "$submission_id" "$DMG_PATH" >&2
  exit 1
fi
submission_status="$(printf '%s' "$submission" | jq -r '.status // empty')"
if [[ "$submission_status" != 'Accepted' ]]; then
  printf 'Notarization %s status: %s\n' "$submission_id" "${submission_status:-unknown}" >&2
  printf '%s\n' "$submission" >&2
  exit 1
fi
printf 'Notarization accepted: %s\n' "$submission_id"

# Keep the exact submitted bytes until a private copy has a validated ticket.
# Persist both accepted hashes before replacement: either side of an interrupted
# rename is then verifiable, with no second submission or hash-check bypass.
stapling_directory="$(mktemp -d "$DMG_PATH.stapling.XXXXXX")"
stapled_dmg="$stapling_directory/$(basename "$DMG_PATH")"
cp -p "$DMG_PATH" "$stapled_dmg"
xcrun stapler staple "$stapled_dmg"
xcrun stapler validate "$stapled_dmg"
stapled_sha256="$(shasum -a 256 "$stapled_dmg" | awk '{print $1}')"
record_temporary="$(mktemp "$submission_record.XXXXXX")"
jq --arg sha "$stapled_sha256" '. + {stapledSHA256: $sha}' "$submission_record" > "$record_temporary"
mv -f "$record_temporary" "$submission_record"
record_temporary=''
mv -f "$stapled_dmg" "$DMG_PATH"

echo "Notarized DMG:"
echo "$DMG_PATH"
