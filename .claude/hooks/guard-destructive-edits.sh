#!/usr/bin/env bash
# Refuse two Bash command shapes that have silently destroyed work in this repo.
#
# Installed at the founder's request on 2026-07-30, after the first of the two
# below failed for the TENTH time. Two consecutive retrospectives had concluded
# "nothing can observe how a file gets edited, this is a rule and cannot be a
# machine", and neither had checked whether the mechanism existed. It does: a
# PreToolUse hook sees the command string before the command runs.
#
# Exit 2 blocks the call and shows this script's stderr to Claude.
#
# 1. A PYTHON HEREDOC THAT WRITES TO A FILE.
#    The shape is `python3 - <<'PY' ... open(p,'w').write(...) ... PY`, usually
#    with an `assert` before the write as a safety check. The assert is the
#    problem: when it throws, the script exits BEFORE the write, so the edit
#    silently does not land, and the next `flutter analyze` reports errors from
#    code that was never changed. The failure looks like a code bug and is not.
#    Ten occurrences, at least two of which cost a full round.
#
# 2. `git checkout <path>` OR `git restore <path>`.
#    Discards uncommitted work in that file with no confirmation and no undo.
#    Used once to revert a deliberate one-line break and it took an entire
#    delivery's edits with it, which then had to be rewritten from memory.
#
# What is deliberately NOT blocked, because a guard that fires on ordinary work
# gets switched off and is then absent for the real thing:
#   - `python3 -c '...'` one-liners, and any python that only reads. No heredoc,
#     no write, no block.
#   - `git checkout <branch>`, `git checkout -b <new>`, `git checkout origin/main`.
#     A ref is not a path. The discriminator is whether the argument EXISTS on
#     disk, which is exactly the thing that makes the command destructive.

set -uo pipefail

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[ -z "$cmd" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-$PWD}"

# What command is being RUN, as opposed to what words appear in the string.
#
# Two false positives, both hit within minutes of installing this, taught the
# shape of this problem:
#
#   1. Matching python anywhere blocked the commit whose MESSAGE describes the
#      banned pattern. A guard that cannot tell an invocation from a mention
#      makes it impossible to write about the thing it guards.
#   2. Splitting on `;`, `|` and `&` to find "segments" then blocked a test
#      harness, because a newline inside a quoted argument looks exactly like the
#      start of a new command.
#
# Shell is not parseable with regex and trying harder makes this worse, not
# better. So: only the command's FIRST word counts, after stripping any leading
# `cd ...` or `export ...` prefix. The destructive shapes always ARE the command;
# they are never buried mid-script.
#
# That means this under-blocks rather than over-blocks, and that is the correct
# direction on purpose. A missed python heredoc costs one round. A guard that
# fires on ordinary work gets switched off, and is then absent for the real
# thing, which is how the delivery watchdog failed.
head_cmd=$(printf '%s' "$cmd" \
  | sed -n '1p' \
  | sed -E 's/^[[:space:]]*//' \
  | sed -E 's/^(cd|export|source|\.)[[:space:]]+[^&;|]*(&&|;)[[:space:]]*//g' \
  | awk 'NF {print $1}' \
  | sed -E 's#.*/##')

# ---------------------------------------------------------------- rule 1
# python (any version) IS the command, plus a here-document, plus a write.
if printf '%s' "$head_cmd" | grep -qE '^python[0-9.]*$' \
  && printf '%s' "$cmd" | grep -qE '<<' \
  && printf '%s' "$cmd" | grep -qE \
       -e "open\([^)]*['\"][wa]" \
       -e '\.write\(' \
       -e 'writelines\(' \
       -e 'write_text\('; then
  cat >&2 <<'MSG'
BLOCKED: a python here-document that writes to a file.

This shape has silently discarded an edit ten times in this repository. An
assert or exception earlier in the script exits before the write, so the file is
never changed while everything looks like it succeeded, and the next analyze
reports errors from code that does not exist.

Use the Edit tool for a targeted change, or Write for a whole file. Both fail
loudly and visibly when they do not apply.

If you genuinely need python to transform a file, read it with python and apply
the result with Edit or Write, so the write goes through a tool that reports.
MSG
  exit 2
fi

# ---------------------------------------------------------------- rule 2
# git checkout / git restore naming something that EXISTS on disk.
if [ "$head_cmd" = 'git' ] \
  && printf '%s' "$cmd" | sed -n '1p' \
     | grep -qE '(^|&&|;)[[:space:]]*git[[:space:]]+(checkout|restore)([[:space:]]|$)'; then
  # Everything after the subcommand on the FIRST line, flags dropped. It only
  # needs to know whether any bare argument is a real path.
  args=$(printf '%s' "$cmd" | sed -n '1p' \
    | sed -E 's/.*git[[:space:]]+(checkout|restore)[[:space:]]*//' \
    | tr ';|&' '\n' | head -1)
  for a in $args; do
    case "$a" in
      -*) continue ;;                      # a flag, including -b and --
    esac
    # A ref (origin/main, a branch, a tag) does not exist as a file. A path
    # does. That difference IS the difference between safe and destructive.
    if [ -e "$root/$a" ] || [ -e "$a" ]; then
      cat >&2 <<MSG
BLOCKED: git checkout/restore on '$a', which exists on disk.

This discards uncommitted work in that path with no confirmation and no undo. It
was used once here to reverse a deliberate one-line break and took an entire
delivery's edits with it.

To undo one specific change, use the Edit tool to put the original text back.
That way only the line you meant to revert is reverted.

Branch operations are not affected: git checkout <branch>, git checkout -b, and
git checkout origin/main all pass, because a ref does not exist as a file.
MSG
      exit 2
    fi
  done
fi

exit 0
