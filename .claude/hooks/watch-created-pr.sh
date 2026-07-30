#!/usr/bin/env bash
# PostToolUse hook: after a GitHub pull request is created, tell Claude to
# subscribe to that PR's activity so it is watched through to merged or closed.
#
# A hook cannot call an MCP tool on Claude's behalf, but it can inject the
# instruction plus the parsed owner/repo/number, which is all Claude needs to
# call subscribe_pr_activity itself. This makes "always watch the PRs I create"
# the default in every session in this repo, rather than a thing to remember.
#
# Reads the PostToolUse JSON on stdin. Emits nothing (a silent no-op) unless the
# tool response carries a real pull-request URL, so it never fires on anything
# but an actual PR creation.
set -euo pipefail

input=$(cat)

# jq is used everywhere else in this repo's tooling; if it is somehow missing,
# fail open (no reminder) rather than breaking the tool call.
command -v jq >/dev/null 2>&1 || exit 0

url=$(printf '%s' "$input" | jq -r '.tool_response.url // .tool_response.html_url // empty' 2>/dev/null || true)

if [[ "$url" =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
  owner="${BASH_REMATCH[1]}"
  repo="${BASH_REMATCH[2]}"
  num="${BASH_REMATCH[3]}"
  msg="You just created pull request ${url}. Standing preference for this repo: watch every PR you create. Call subscribe_pr_activity now with owner=${owner}, repo=${repo}, pullNumber=${num}, then check its CI status, and keep watching (drive-to-green: push fixes or reply with the blocker) until it is merged or closed."
  jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$m}}'
fi

exit 0
