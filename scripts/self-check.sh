#!/usr/bin/env bash
#
# The standing self-check for app/, written to be run unattended on a loop.
#
# WHY THIS EXISTS, and it is not "run the tests again". CI already runs the
# suite on every push. What CI does not do is any of the three things that
# actually caught defects in this project:
#
#   1. RENDER THE SCREENS. The render harness is opt-in by nature, because it
#      produces pictures and a picture nobody opens proves nothing. Two real
#      defects reached the founder's phone while 673 tests were green, both
#      obvious at a glance.
#   2. REPORT ONLY WHAT CHANGED. A check that prints the same green wall every
#      time gets skimmed and then ignored, which is how the delivery watchdog
#      got its battery taken out.
#   3. RUN AT THE PIN. The dev sandbox has an older Flutter at /opt/flutter,
#      and a local green run from the wrong SDK is not evidence about CI. One
#      agent's `flutter test` under the wrong SDK silently downgraded eight
#      packages in pubspec.lock on 2026-10-04.
#
# Exit codes: 0 nothing to report, 1 something needs a human.
#
# Usage:  scripts/self-check.sh [--quick]
#   --quick skips the render pass, for a fast gate before a push.

set -o pipefail

# THE PIN, NOT WHATEVER IS ON PATH. This is the version CI builds with, and
# the whole point of the check is to predict CI. /opt/flutter is older and
# must never be what verifies a push.
PIN="/opt/f3474/flutter/bin"
if [ ! -x "$PIN/flutter" ]; then
  echo "BLOCKED: the pinned Flutter is not at $PIN."
  echo "A run from any other SDK is not evidence about CI, so this stops"
  echo "rather than passing with a result nobody should trust."
  exit 1
fi
export PATH="$PIN:$PATH"

cd "$(dirname "$0")/../app" || exit 1

QUICK=0
[ "$1" = "--quick" ] && QUICK=1

STATE_DIR="${TMPDIR:-/tmp}/salapify-self-check"
mkdir -p "$STATE_DIR"
# ONE STATE FILE PER MODE. A --quick run has no render fields in its summary,
# so sharing a file with the full run made every alternation look like a
# change and every change look like noise. Found by running the two back to
# back, which is what a loop will do.
LAST="$STATE_DIR/last-summary-$([ "${1:-}" = '--quick' ] && echo quick || echo full)"

problems=()
summary=""

# ---------------------------------------------------------------------------
# 1. The lockfile, first, because everything after it is meaningless if the
#    dependency set is not the one CI resolves.
# ---------------------------------------------------------------------------
if ! git -C .. diff --quiet -- app/pubspec.lock; then
  problems+=("pubspec.lock is modified. Check WHICH SDK wrote it before committing: an older Flutter downgrades packages silently and neither analyze nor test notices.")
fi

# ---------------------------------------------------------------------------
# 2. Format and analyze.
# ---------------------------------------------------------------------------
# STRAY DEBUG AND PROBE FILES, checked FIRST because git cannot see them.
#
# They are gitignored, which is right, and that is exactly why they are
# invisible: `git status` is clean while `flutter test` collects every file
# matching *_test.dart and runs them. One such file sat in the suite for an
# hour on 2026-10-04 and only surfaced because the format check tripped on it.
strays="$(find test -name 'zz_*' -o -name '*probe*' 2>/dev/null)"
if [ -n "$strays" ]; then
  problems+=("Stray debug files are in test/ and `flutter test` is running them. Delete them:")
  problems+=("$strays")
fi

fmt_out="$(dart format --output=none --set-exit-if-changed lib/ test/ 2>&1)"
if [ $? -ne 0 ]; then
  problems+=("dart format would change files. Run: dart format lib/ test/")
  problems+=("$(echo "$fmt_out" | grep '^Changed' | head -10)")
fi

analyze_out="$(flutter analyze 2>&1)"
if ! echo "$analyze_out" | grep -q "No issues found"; then
  problems+=("flutter analyze is not clean:")
  problems+=("$(echo "$analyze_out" | grep -E '^\s+(error|warning|info)' | head -10)")
fi

# ---------------------------------------------------------------------------
# 3. The suite. `set -o pipefail` is at the top DELIBERATELY: a pipeline
#    reports the LAST command's exit code, so `flutter test | tail` once
#    reported a green suite over two red tests.
# ---------------------------------------------------------------------------
test_out="$(flutter test 2>&1)"
test_rc=$?
# `tr -d '-:'` reads the leading dash as an option and dies, so sed instead.
# Caught by the check's own first run, which is the correct way to find it.
passed="$(echo "$test_out" | grep -oE '\+[0-9]+' | tail -1 | sed 's/+//')"
failed="$(echo "$test_out" | grep -oE -- '-[0-9]+:' | tail -1 | sed 's/[-:]//g')"
: "${passed:=0}"
: "${failed:=0}"

if [ "$test_rc" -ne 0 ] || [ "$failed" != "0" ]; then
  problems+=("Suite RED: $failed failing, $passed passing.")
  problems+=("$(echo "$test_out" | grep -A6 'EXCEPTION CAUGHT\|\[E\]' | head -24)")
fi

summary="tests=$passed/$failed"

# ---------------------------------------------------------------------------
# 4. The renders. This is the half CI cannot do for anybody, because its
#    output is pictures. Running it proves the harness still works, which is
#    what was abandoned once already after a runtime failure nobody wrote down.
# ---------------------------------------------------------------------------
if [ "$QUICK" -eq 0 ]; then
  shot_out="$(flutter test test/shots/screens_shot.dart --update-goldens 2>&1)"
  if [ $? -ne 0 ]; then
    problems+=("The render harness FAILED, so nobody can look at a screen until it is fixed:")
    problems+=("$(echo "$shot_out" | grep -B2 -A6 'EXCEPTION\|Error' | head -20)")
  else
    shots="$(ls test/shots/out/*.png 2>/dev/null | wc -l | tr -d ' ')"

    # A FINGERPRINT OF THE PIXELS, not just how many files there are.
    #
    # The count alone reported NO CHANGE on 2026-10-04 after a merge that
    # visibly redrew every institution logo on the Accounts screen. For a
    # check whose entire purpose is "render the screens and notice", saying
    # nothing moved when the screens moved is the one failure it cannot
    # afford.
    #
    # REPORTED, NEVER FAILED. A pixel difference is information, not a defect,
    # and CLAUDE.md is explicit that a cross-environment pixel diff must never
    # gate a push. This runs in one environment against a deterministic
    # harness, so the digest is stable, and when it moves the line says to go
    # and LOOK rather than to go and fix.
    look="$(cat test/shots/out/*.png 2>/dev/null | md5sum | cut -c1-8)"
    summary="$summary shots=$shots px=$look"
  fi
fi

# ---------------------------------------------------------------------------
# 5. Report, and ONLY on change.
# ---------------------------------------------------------------------------
if [ ${#problems[@]} -eq 0 ]; then
  prev="$(cat "$LAST" 2>/dev/null)"
  echo "$summary" > "$LAST"
  if [ "$summary" = "$prev" ]; then
    echo "NO CHANGE  $summary"
  else
    echo "GREEN      $summary  (was: ${prev:-first run})"
  fi
  exit 0
fi

echo "NEEDS A HUMAN  $summary"
echo
for p in "${problems[@]}"; do
  echo "$p"
  echo
done
exit 1
