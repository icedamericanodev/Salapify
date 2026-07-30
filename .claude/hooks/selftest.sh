#!/usr/bin/env bash
# Proof that guard-destructive-edits.sh blocks what it claims and, just as
# importantly, stays silent on ordinary work.
#
# Both halves are here because the noisy half is the easy half. This guard had
# TWO false positives within minutes of being installed: it blocked the commit
# whose message described the banned pattern, and then blocked its own test
# harness, because a newline inside a quoted argument reads like a new command.
# A guard that fires on ordinary work gets switched off and is then absent for
# the real thing.
#
# Run from the repo root:  bash .claude/hooks/selftest.sh

set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
guard=.claude/hooks/guard-destructive-edits.sh
fails=0

check() { # name expected_exit command
  local name=$1 want=$2 cmd=$3 got
  printf '%s' "$cmd" | jq -Rs '{tool_input:{command:.}}' | bash "$guard" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then
    printf 'ok    %-44s (exit %s)\n' "$name" "$got"
  else
    printf 'FAIL  %-44s wanted %s got %s\n' "$name" "$want" "$got"
    fails=$((fails + 1))
  fi
}

echo "--- must BLOCK (exit 2) ---"
check 'python heredoc, .write' 2 "$(printf 'python3 - <<%sPY%s\nio.open(p,%sw%s).write(s)\nPY\n' "'" "'" "'" "'")"
check 'python heredoc, open for write' 2 "$(printf 'python3 <<PY\nf = open("a.dart", "w")\nPY\n')"
check 'python heredoc after a cd' 2 "$(printf 'cd flutter && python3 - <<PY\nopen("a","w").write("b")\nPY\n')"
check 'git checkout a tracked file' 2 'git checkout CLAUDE.md'
check 'git checkout a tracked path' 2 'git checkout flutter/lib/main.dart'
check 'git checkout dot' 2 'git checkout .'
check 'git restore a tracked file' 2 'git restore CLAUDE.md'
check 'git checkout -- file' 2 'git checkout -- CLAUDE.md'

echo "--- must ALLOW (exit 0) ---"
check 'python -c, read only' 0 'python3 -c "print(1)"'
check 'python heredoc, read only' 0 "$(printf 'python3 - <<PY\nprint(open("CLAUDE.md").read())\nPY\n')"
check 'git checkout a branch' 0 'git checkout main'
check 'git checkout -b' 0 'git checkout -b claude/whatever'
check 'git checkout a remote ref' 0 'git checkout origin/main'
check 'git status' 0 'git status --short'
check 'flutter test' 0 'flutter test'
# The two that actually bit. A commit message is allowed to DESCRIBE the pattern.
check 'commit message quoting rule 1' 0 "$(printf 'git commit -F- <<MSG\nRefuse the pattern\n\npython3 - <<PY ... open(p,"w").write(s) ... PY is banned.\nMSG\n')"
check 'commit message quoting rule 2' 0 "$(printf 'git commit -F- <<MSG\nRefuse it\n\ngit checkout CLAUDE.md is banned.\nMSG\n')"
check 'a test harness mentioning both' 0 "$(printf 't() { echo "$1"; }\npython3 - <<PY\nopen("x","w")\nPY\n')"

echo
if [ "$fails" = 0 ]; then
  echo "all checks passed"
else
  echo "$fails FAILED"
  exit 1
fi
