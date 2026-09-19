#!/usr/bin/env bash
# Prevent the two-builds-one-stamp collision BEFORE the merge.
#
# The publisher (flutter-preview.yml) already REFUSES to record a patch whose
# stamp equals the one already delivered, and opens an issue, but only AFTER the
# patch is live on the phone. That is what happened to f3.10 patch 5: a test-only
# merge shipped under the unchanged stamp f3.10, and the founder's phone had it
# before anyone knew (docs/lunch-and-learn.md session 25). This script is the
# pre-merge half: it fails the branch check on the same condition, so the
# collision never merges.
#
# The decision is a pure function of three inputs so it can be proven in
# isolation, exactly like check-merged-manifest.sh. The git plumbing that feeds
# it (the delivered stamp, whether this branch touches flutter/) lives in the
# workflow step that calls this.
#
# Args:
#   $1 BRANCH     the stamp this branch would build   (e.g. f3.11)
#   $2 DELIVERED  the last stamp on the delivery log   (e.g. f3.11, or empty)
#   $3 TOUCHES    "yes" if this branch changes files under flutter/, else "no"
#
# Exit 1 ONLY on a real collision: a flutter/ change (so a merge ships a patch)
# whose stamp is one already delivered. Everything else exits 0.
set -euo pipefail

BRANCH="${1:-}"
DELIVERED="${2:-}"
TOUCHES="${3:-}"

echo "Branch stamp:     ${BRANCH:-unknown}"
echo "Delivered stamp:  ${DELIVERED:-none recorded}"
echo "Touches flutter/: ${TOUCHES:-unknown}"

# A change that does not touch flutter/ ships nothing (the publisher's trigger is
# flutter/**), so its stamp is free to stay where it is.
if [ "$TOUCHES" != "yes" ]; then
  echo "No flutter/ change: this merge ships nothing, so the stamp need not move."
  exit 0
fi

# Nothing delivered yet means there is no stamp to collide with.
if [ -z "$DELIVERED" ]; then
  echo "No delivered stamp on record yet: nothing to collide with."
  exit 0
fi

if [ "$BRANCH" = "$DELIVERED" ]; then
  echo
  echo "COLLISION: this branch changes files under flutter/, so merging it ships"
  echo "a Shorebird patch, but its stamp ($BRANCH) is the one already delivered."
  echo "The publisher would ship the patch and then FAIL to record it (two builds"
  echo "under one stamp), exactly as it did for f3.10 patch 5. There is no"
  echo "merge-flutter/-without-shipping path. Bump updateStamp in"
  echo "flutter/lib/main.dart to a new version, then this passes."
  echo "See docs/lunch-and-learn.md session 25."
  exit 1
fi

echo "Stamp differs from what is delivered: no collision."
