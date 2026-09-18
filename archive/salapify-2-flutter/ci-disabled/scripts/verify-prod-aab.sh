#!/usr/bin/env bash
# The production AAB must not borrow the preview build's identity.
#
# The static guards (flutter/test/production_identity_test.dart) prove the CONFIG
# is right on every branch. This proves the built ARTIFACT matches, at the one
# moment a production bundle actually exists: it is signed with the upload key
# and NOT the committed preview key, it is labelled "Salapify" and not "Salapify
# Preview", its merged manifest still matches the permission/backup allowlist,
# and the sample-data testing scaffolding was compiled OUT (release tree-shaking,
# because kTestingAids is a const false under SALAPIFY_PREVIEW=false).
#
# Run by .github/workflows/flutter-prod-aab.yml, which is manual only. It only
# runs when the founder is producing a real Play bundle, so it is exercised by
# doing the thing it guards, the same trust model as the preview publisher.
#
# Usage: verify-prod-aab.sh <aab> <prod-merged-manifest> <preview-keystore>
# Exit 0: safe to upload.  Exit 1: it borrows the preview identity, refuse it.

set -u

AAB="${1:-}"
MANIFEST="${2:-}"
PREVIEW_KS="${3:-}"

fail() {
  echo "PRODUCTION AAB REJECTED: $1"
  echo "This bundle must not reach Play. Fix it before uploading."
  exit 1
}

[ -n "$AAB" ] && [ -f "$AAB" ] || fail "no AAB at '${AAB:-}' (the build step did not produce one)."
[ -n "$MANIFEST" ] && [ -f "$MANIFEST" ] || fail "no prod merged manifest at '${MANIFEST:-}'."
[ -n "$PREVIEW_KS" ] && [ -f "$PREVIEW_KS" ] || fail "no preview keystore at '${PREVIEW_KS:-}' to compare against."

FLAT=$(tr '\n' ' ' < "$MANIFEST" | tr -s ' ')

# 1. Label: production says "Salapify", never "Salapify Preview".
case "$FLAT" in
  *'android:label="Salapify Preview"'*)
    fail "the launcher label is \"Salapify Preview\"; production must be \"Salapify\"." ;;
esac
case "$FLAT" in
  *'android:label="Salapify"'*) ;;
  *) fail "the launcher label is not \"Salapify\"; the prod flavor label did not apply." ;;
esac

# 2. Merged-manifest allowlist applies to production too (same permissions,
# exported components, backup off, no cleartext).
bash "$(dirname "$0")/check-merged-manifest.sh" "$MANIFEST" || \
  fail "the production merged manifest failed the permission/backup allowlist."

# 3. Signing certificate must NOT be the preview certificate. Extract the
# SHA-256 fingerprint from the AAB's signer and from the committed preview
# keystore, and refuse if they match. The preview store password is the
# committed one (public already, in build.gradle.kts).
aab_sha=$(keytool -printcert -jarfile "$AAB" 2>/dev/null \
  | grep -i 'SHA256:' | head -1 | sed -E 's/.*SHA256:[[:space:]]*//')
preview_sha=$(keytool -list -v -keystore "$PREVIEW_KS" -storepass salapify-preview 2>/dev/null \
  | grep -i 'SHA256:' | head -1 | sed -E 's/.*SHA256:[[:space:]]*//')
echo "AAB signer SHA256:     ${aab_sha:-<none>}"
echo "preview cert SHA256:   ${preview_sha:-<none>}"
[ -n "$aab_sha" ] || fail "could not read the AAB signing certificate (is it signed?)."
[ -n "$preview_sha" ] || fail "could not read the preview certificate to compare against."
if [ "$aab_sha" = "$preview_sha" ]; then
  fail "the AAB is signed with the PREVIEW certificate. Production must use the upload key."
fi

# 4. Testing aids must be tree-shaken out. In a release build with
# SALAPIFY_PREVIEW=false, kTestingAids is a const false, so the branches that
# carry these strings are dead code and the AOT compiler drops them. If any
# survives, the scaffolding shipped.
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
unzip -o -q "$AAB" -d "$WORK" || fail "could not unzip the AAB."
aids=0
for marker in 'TRY IT WITH SAMPLE DATA' 'SAMPLE DATA IS LOADED' 'Load sample data'; do
  if find "$WORK" -name 'libapp.so' -exec strings {} + 2>/dev/null | grep -qF "$marker"; then
    echo "Found testing-aid string in the bundle: $marker"
    aids=1
  fi
done
[ "$aids" -eq 0 ] || fail "sample-data testing aids are present in the production bundle."

echo "PRODUCTION AAB OK: upload key (not preview), \"Salapify\" label, allowlisted manifest, no testing aids."
exit 0
