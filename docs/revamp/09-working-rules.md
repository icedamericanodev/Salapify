# 09. Working rules for the revamp

This replaces the constitution's sixty-two sections with the few rules that
actually change how a session works. CLAUDE.md remains the concrete
enforcement layer (branches, stamps, no em or en dashes, the guard hooks,
the merge rules); nothing here loosens it.

## Authority, in order

1. Direct founder direction in the conversation.
2. This folder, docs/revamp.
3. CLAUDE.md, for how work is done and shipped.
4. Everything else in docs/, as reference only (see 08-docs-inventory.md).

## Autonomy

Once the founder approves a phase in 05-roadmap.md, routine engineering
inside that phase proceeds without asking: branch, implement, test, render,
review, fix, commit, push, open the PR, report. The approved phase is the
boundary.

Stop and ask the founder before any of these, however clean the change
looks:

- Anything that changes what a peso figure means: rounding, signs, which
  transactions count, how net worth or safe to spend is computed.
- Anything that touches stored data: schema, migration, backup format,
  deletion, anything not reversible.
- Anything that touches security or privacy: lock, encryption, permissions,
  network calls, telemetry.
- A real product fork: two reasonable options that would change navigation,
  hierarchy, a workflow or a financial interpretation.
- Deleting or archiving files that exist on main (moves are fine on a branch
  once the founder has seen the inventory).
- Releasing or publishing anything.

Merging is NOT on that list any more. Founder direction, 2026-09-13: "Happy
for you to merge we have agents for that, fix any issues and flag to any
major that needed my review". So Claude merges its own PRs. Every merge
condition in CLAUDE.md still has to hold first, unchanged: the approval step
went, the checks did not. A red check is still a stop, and "the founder said
merge" is not a waiver for one.

The second half of that direction is a duty, not a courtesy. Say what was
merged and why it matters, right after merging, using CLAUDE.md's own
definition of significant. Merging without asking is not merging without
telling.

Note the shape of the list above: those items stop the WORK, before it is
started or while it is being done. Merging was the odd one out, a gate at the
end of work already finished, which is exactly the loop the founder closed.

## Show, do not describe

Every screen change comes with a rendered PNG in the conversation, dark
first, then light, before the PR is presented. The founder reviews the
picture, not the diff. This rule already exists in CLAUDE.md; it is
repeated here because it is the one that catches what tests cannot.

## Small and finished

One screen or one feature per PR. A PR that touches three screens is three
PRs. The founder is a beginner and reviews by looking; a small PR can be
looked at.

## Keep it readable

Plain English for the founder. No jargon without a one-line explanation the
first time. Every document in this folder must be readable by the founder
without asking what a word means.

## Numbers rot in prose

Do not write counts, timings or version numbers into documents that are not
generated. A sentence that says "sixty tests" is wrong a week later. Point
at the file or the command that produces the number instead.
