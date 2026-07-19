---
name: writing-skills
description: Use when creating a new Salapify skill or agent, or turning a repeatable workflow into a reusable one. Triggers on "make a skill for", "we keep doing X, capture it", "add an agent", or noticing the same multi-step process being re-derived across sessions.
---

# Writing skills: capture a workflow so it never has to be re-derived

Adapted for Salapify from obra/superpowers (MIT). A good skill turns hard-won
process into something every future session applies consistently. Salapify
skills live in .claude/skills/<name>/SKILL.md; agents (persona reviewers) live
in .claude/agents/<name>.md.

## SKILL.md structure

Frontmatter (YAML), name and description under 1024 chars total:
- name: letters, numbers, hyphens; active voice, verb-first where natural.
- description: THIRD person, starts with "Use when...", lists ONLY the
  triggering conditions, never the workflow. If the description summarizes the
  steps, agents follow the summary instead of reading the skill.

Body, only the sections that earn their place:
- Overview: the core principle in one or two sentences.
- When to use: a short flowchart only if the decision is non-obvious, plus
  bullet symptoms.
- The pattern or process: numbered steps, or before/after for a technique.
- Quick reference: a scannable table or bullets.
- Common mistakes: what breaks and the fix.

## Principles

- Progressive disclosure. Frontload searchable keywords (error strings,
  symptoms, tool and file names) so the skill is FOUND when relevant, and keep
  the body tight so it is cheap to read.
- Conciseness. Getting-started skills under ~150 words; most others under
  ~500. Cross-reference other skills by name (e.g. "see porting-money-logic")
  instead of repeating them; do not @-link, that force-loads and wastes
  context.
- Match the guidance form to the failure. A rule people break under pressure
  needs a hard prohibition plus a red-flags list, not "prefer" or "consider".
  A wrong-output-shape problem needs a positive contract of what IS correct.
  Conditional behavior needs observable predicates ("if X exists, do Y"), not
  unconditional rules with exemptions. Avoid "don't X unless important", it
  reopens negotiation; write the real exception as its own conditional.

## Salapify house rules a new skill must respect

- Never em dashes or en dashes anywhere. Commas or periods.
- Money math ships only behind the golden lock (see porting-money-logic).
- Merges follow CLAUDE.md: qa-tester plus the fitting specialist plus CI green
  on head, "Create a merge commit", never squash, founder-before-merge only
  for changes that could permanently lose user data.
- Every push touching flutter/ bumps the updateStamp in flutter/lib/main.dart.

## Checklist before a skill is done

- Frontmatter name and description correct; description is triggers only.
- Keywords sprinkled for discovery.
- One excellent concrete example, code inline or linked.
- Quick reference and common mistakes present.
- No em or en dashes; plain English for a beginner founder.
