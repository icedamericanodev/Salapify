---
name: brainstorming
description: Use when about to build any non-trivial Salapify feature, screen, or money behavior and the design is not yet written down and agreed. Triggers on "let's add", "build a feature for", "what should we do about", a vague founder request, or the urge to start coding before a design exists.
---

# Brainstorming: design before you build

Adapted for Salapify from obra/superpowers (MIT). Turn an idea into an agreed
design BEFORE writing code, so unexamined assumptions do not become wasted
work. Simple features are exactly where a hidden assumption costs the most.

## The gate (do not skip)

Do NOT write code, port a money function, scaffold a screen, or open a PR
until a design is written down and the decision is settled. For a Salapify
change that is "significant" under CLAUDE.md (stored data shape, money math,
backup/restore, security, notifications, pricing, deleting user data, or an
APK rebuild), the design and its risks go to the FOUNDER before building.
Everything else: settle the design yourself against the specialist lens that
fits, then build.

## Process

1. Read the real context first. Open the RN original in mobile/ and the
   Flutter target in flutter/, the relevant engine (money/), and how similar
   cards already read. Never design against an imagined codebase.
2. Ask clarifying questions ONE at a time, only the ones whose answer changes
   what you build. Purpose, the user it serves, the honest constraint.
3. Convene the fitting specialist lens for the decision, not a menu of ten:
   financial-coach or bank-officer/tax-professional/compensation-benefits for
   money soundness, behavior-scientist for behavior change, product-manager
   for scope, flutter-ux-craftsman for the screen. Have them converge on ONE
   recommendation, not a survey.
4. Propose 2-3 approaches with honest trade-offs. Recommend one, say why.
5. Write the design down: the question it answers, exact inputs it reads, the
   plain computation (so it can be golden or unit tested), the copy tone, and
   how it renders as a DECISION, not just a chart. Keep it short for small
   work, a few sentences is fine.
6. Self-check the design for placeholders, contradictions, and any number the
   app would have to invent. If it invents a number, redesign.
7. For significant changes, get founder approval. Otherwise proceed.

## Then, and only then

Hand off to implementation on the Salapify rails: port money logic behind the
golden lock (see the porting-money-logic skill), build the screen on the
Barako theme, then gate and merge per CLAUDE.md (qa-tester plus the fitting
specialist plus CI green on head).

## Common mistakes

- Coding first, designing after. The gate exists to stop this.
- A menu of ten options with no recommendation. Pick one, defend it.
- Designing a money feature that shows a figure no engine computed. Every
  peso on screen must come from a tested function.
