#!/usr/bin/env bash
# Is app/'s money engine still the SAME code as the app on the founder's phone?
#
# The whole claim the rebuild rests on is that not one number moved, and a
# suite goes green whether that is true or not: `dart format` reflowed four of
# these files in Phase B2, and the same four again in Phase B3, both times with
# logic untouched and every one of 316 tests passing. A diff nobody can see is
# a claim nobody can check.
#
# The formatter cannot be told to skip them. `formatter: exclude:` in
# analysis_options.yaml is silently ignored by Dart 3.12.2 (tried, it did
# nothing), and `// dart format off` would change the bytes it is meant to
# protect. So it is caught rather than prevented: here, and in
# .github/workflows/app-check.yml which runs the identical comparison.
#
# Usage: bash .github/scripts/check-engine-identical.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

# Nothing to compare against once flutter/ is deleted at cutover. Delete this
# script with it; by then the vectors will have been green against two
# independent implementations for months.
if [ ! -d flutter/lib/money ] || [ ! -d app/lib/core/money ]; then
  exit 0
fi

fail=0

for f in app/test/goldens/*.json; do
  b=$(basename "$f")
  old="flutter/test/goldens/$b"
  if [ ! -f "$old" ]; then
    echo "::error::$b exists in app/ but not in flutter/. A new vector is not a port."
    fail=1
  elif ! cmp -s "$f" "$old"; then
    echo "::error::$b differs from the vector the shipped app uses."
    fail=1
  fi
done

for f in app/lib/core/money/*.dart; do
  b=$(basename "$f")
  # taglish.dart is the one intended rename (pan/normalize.dart), so it is
  # compared against its real source rather than skipped.
  if [ "$b" = "taglish.dart" ]; then
    old="flutter/lib/money/pan/normalize.dart"
  else
    old="flutter/lib/money/$b"
  fi
  if [ ! -f "$old" ]; then
    echo "::error::$b is in app/lib/core/money with no counterpart in flutter/. New money code is not a port."
    fail=1
  elif ! cmp -s "$f" "$old"; then
    echo "::error::$b differs from the shipped engine."
    echo "  If dart format did this, put the original back:"
    echo "    cp $old $f"
    echo "  If it is a real fix, it belongs in BOTH trees, and flutter/ is frozen."
    fail=1
  fi
done

if [ $fail -eq 0 ]; then
  echo "$(ls app/test/goldens/*.json | wc -l) fixtures and $(ls app/lib/core/money/*.dart | wc -l) engine files are byte-identical to the shipped app's."
fi
exit $fail
