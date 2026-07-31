#!/usr/bin/env bash
# The shipped manifest is not the source manifest.
#
# The source AndroidManifest.xml declares four permissions. The app actually
# ships more, because every plugin merges its own permissions, receivers, and
# providers into the final manifest at build time. Nobody sees that merged file
# unless they go looking, so a dependency bump can add a permission or export a
# component and no human would ever know.
#
# This reads the MERGED manifest out of a real build and holds it to an
# allowlist: the exact permissions we intend, the exact components we export,
# backup switched off with both rule files wired, and no cleartext. Anything
# unexpected fails the build and PRINTS what it was, so a new permission is a
# decision somebody makes on purpose, not a thing that arrives silently.
#
# The allowlists are typed sets on purpose (a promise, not a guess): a new
# permission reddens CI until a human adds it here, having decided it belongs.
#
# The extraction of the merged manifest happens in CI (only a real build has
# one). The LOGIC below is driven on the branch by
# flutter/test/merged_manifest_guard_test.dart, through every failure shape,
# because a workflow step can otherwise only be tested by shipping.
#
# Usage: check-merged-manifest.sh <merged-AndroidManifest.xml>
# Exit 0: the manifest matches the allowlists.  Exit 1: it does not, loudly.

set -u

MANIFEST="${1:-}"
if [ -z "$MANIFEST" ] || [ ! -f "$MANIFEST" ]; then
  echo "MANIFEST CHECK FAILED: no merged manifest at '${MANIFEST:-}'."
  echo "Nothing was verified, which must never read as a pass."
  exit 1
fi

# Every permission the app is allowed to ship. Update this ONLY when a new
# permission is a reviewed decision. INTERNET (updates + rate lookups),
# USE_BIOMETRIC (App Lock), POST_NOTIFICATIONS + RECEIVE_BOOT_COMPLETED
# (reminders), VIBRATE (haptics), WAKE_LOCK + ACCESS_NETWORK_STATE +
# FOREGROUND_SERVICE (home-widget plumbing, unused by us but merged in).
ALLOWED_PERMS=(
  "android.permission.INTERNET"
  "android.permission.USE_BIOMETRIC"
  "android.permission.POST_NOTIFICATIONS"
  "android.permission.RECEIVE_BOOT_COMPLETED"
  "android.permission.VIBRATE"
  "android.permission.WAKE_LOCK"
  "android.permission.ACCESS_NETWORK_STATE"
  "android.permission.FOREGROUND_SERVICE"
)

# The only components allowed to be exported, by their short (last-segment)
# name. MainActivity is the launcher; YourNumberWidget is the home-screen tile
# receiver, exported so OEM launchers honor it. Everything else must be
# exported="false".
ALLOWED_EXPORTED=(
  "MainActivity"
  "YourNumberWidget"
)

# Collapse to one line so a pretty-printed or minified manifest reads the same.
FLAT=$(tr '\n' ' ' < "$MANIFEST" | tr -s ' ')

fail() {
  echo "MANIFEST CHECK FAILED: $1"
  exit 1
}

in_list() {
  local needle="$1"; shift
  local x
  for x in "$@"; do [ "$x" = "$needle" ] && return 0; done
  return 1
}

# 1. Permissions: every declared permission must be on the allowlist.
while IFS= read -r perm; do
  [ -z "$perm" ] && continue
  if ! in_list "$perm" "${ALLOWED_PERMS[@]}"; then
    fail "unexpected permission '$perm'. If it belongs, add it to ALLOWED_PERMS with a reason; if not, remove the dependency that pulled it in."
  fi
done < <(grep -oE 'uses-permission[^>]*android:name="[^"]+"' <<<"$FLAT" \
  | grep -oE 'android\.permission\.[A-Za-z_.]+' | sort -u)

# 2. Exported components: every component tag carrying exported="true" must be
# on the allowlist, matched by its last name segment.
while IFS= read -r tag; do
  case "$tag" in
    *'android:exported="true"'*) ;;
    *) continue ;;
  esac
  name=$(grep -oE 'android:name="[^"]+"' <<<"$tag" | head -1 | sed -E 's/.*="([^"]+)".*/\1/')
  short="${name##*.}"
  if ! in_list "$short" "${ALLOWED_EXPORTED[@]}"; then
    fail "component '$name' is exported but not on the allowlist. An exported component is reachable by other apps; add it to ALLOWED_EXPORTED only if that is intended."
  fi
done < <(grep -oE '<(activity|service|receiver|provider)[^>]*>' <<<"$FLAT")

# 3. Backup posture, checked here too so the merged artifact itself proves it
# (backup_posture_test.dart checks the source; this checks the shipped file).
case "$FLAT" in
  *'android:allowBackup="false"'*) ;;
  *) fail "allowBackup is not false in the merged manifest; the ledger would be eligible for cloud backup." ;;
esac
case "$FLAT" in
  *'android:fullBackupContent="@xml/backup_rules"'*) ;;
  *) fail "fullBackupContent is not wired in the merged manifest (Android 11 backup rules)." ;;
esac
case "$FLAT" in
  *'android:dataExtractionRules="@xml/data_extraction_rules"'*) ;;
  *) fail "dataExtractionRules is not wired in the merged manifest (Android 12+ backup and transfer rules)." ;;
esac

# 4. Cleartext: an offline app that only talks HTTPS must never allow cleartext.
case "$FLAT" in
  *'android:usesCleartextTraffic="true"'*)
    fail "usesCleartextTraffic is true; the app must talk HTTPS only." ;;
esac

echo "MANIFEST CHECK PASSED: permissions, exported components, backup, and cleartext all match the allowlist."
exit 0
