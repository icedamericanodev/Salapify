#!/usr/bin/env bash
# Did this build actually put something on the founder's phone?
#
# The publisher already says so loudly when a step EXITS NON-ZERO. This covers
# the other half, which nothing covered: a step that exits ZERO having shipped
# nothing.
#
# On the patch branch the patch number is parsed with `|| true`, deliberately,
# because a release run has no "Published Patch" line anywhere in its log and
# the absence of that `|| true` once cost a whole delivery. The cost of having
# it is that on a PATCH run, an empty patch number is indistinguishable from
# success at the exit-code level. The delivery row would then be written
# reading "patch: none" while the phone received nothing at all.
#
# That is the worst possible outcome for this project specifically, because a
# row in docs/delivery-log.md is the ONE thing here treated as proof that
# something shipped. A row that means nothing is worse than no row, because it
# is believed.
#
# Usage: verify-shipped.sh <mode> <patch> <ship-log> <apk-path>
# Exit 0: something genuinely shipped.  Exit 1: nothing did, say so loudly.

set -u

MODE="${1:-}"
PATCH="${2:-}"
LOG="${3:-}"
APK="${4:-}"

# The wording is fixed and greppable on purpose. It is what a person reads in
# a red run, and it is what the test asserts on, so the two cannot drift.
fail() {
  echo "NOTHING SHIPPED: $1"
  echo "The phone did not change, whatever the merged pull request said."
  exit 1
}

case "$MODE" in
  patch)
    [ -n "$PATCH" ] ||
      fail "the mode is patch but no patch number was published."
    case "$PATCH" in
      *[!0-9]*) fail "the patch number '$PATCH' is not a number." ;;
    esac
    [ -f "$LOG" ] ||
      fail "the mode is patch but the Shorebird log '$LOG' does not exist."
    grep -q 'Published Patch' "$LOG" ||
      fail "the Shorebird log has no 'Published Patch' line, so nothing was added to the release."
    echo "Shipped: patch $PATCH."
    ;;
  release)
    # Deliberately NOT asserting on the release log's wording.
    #
    # Nobody here has read a successful release log closely enough to quote it,
    # and a check written against a guessed string would fail on every release
    # forever, which is how a guard gets switched off. The APK is the thing the
    # founder actually installs, so its existence is what is worth asserting.
    [ -n "$APK" ] ||
      fail "the mode is release but no APK path was given."
    [ -f "$APK" ] ||
      fail "the mode is release but the APK '$APK' was never built."
    SIZE=$(wc -c < "$APK")
    [ "$SIZE" -gt 1000000 ] ||
      fail "the APK is only $SIZE bytes, which is not an installable app."
    echo "Shipped: a base APK of $SIZE bytes, which the founder must install by hand."
    ;;
  *)
    # Covers the ship step falling through without setting a mode at all, which
    # would otherwise reach the delivery log as a row with an empty Mode column
    # and read like any other successful build.
    fail "the ship step reported the mode '$MODE', which is neither patch nor release."
    ;;
esac
