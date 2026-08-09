# Phase 6B Batch C1B: Implementation Report

The ID-safe display regrouping of the Money Courses library. Stamp f3.95.
Status: implemented, tested, validated in Fable, returned for review before
the content-density rewrites begin.

This batch does exactly one thing: it changes how the expansion library is
PRESENTED, and nothing about how it is STORED. It is the deliberate first step
the approved C1 report called for, so that the later content work lands on a
hierarchy that is already correct, rather than moving shelves and rewriting
books at the same time.

## The one rule this batch lives by: presentation, never identity

Every decision here is about display order and labels. Not one pathId,
groupId, lessonId, progress key, backup field, or deep-link changed. A
learner's completion and percentage cannot move because a course now sits
under a different header. The proof of that is structural, not a promise: all
of the regrouping metadata lives in one new file, `expansion_display.dart`,
which holds display order, an advanced-path flag, the advanced-Grow set, and
the per-course notes, and touches no identity or progress at all. The screens
read that metadata; the readers still return every lesson regardless of which
header shows it.

## The new Learn hierarchy

Under CHOOSE YOUR NEXT PATH, the three published paths now read in this order:

1. Protect Your Future, first, because everyone with a payslip already pays
   SSS, PhilHealth and Pag-IBIG, so protection is the most everyday tier.
2. Grow Your Money, second, mainstream money growth.
3. Build Your Business, last, under a quiet ADVANCED tier marker.

The ADVANCED marker is a muted header, not a warning. Business stays fully
discoverable and one tap from Start; it simply reads as advanced through a
label rather than any alarming treatment, so it never competes with the two
paths a typical working adult needs first. Every path keeps its own lesson
count (Protect 18, Grow 29, Business 24), untouched.

## Grow's "Go deeper" disclosure

Grow has five courses, and two of them are technical. Rather than sit them at
equal priority beside the mainstream three, the two technical courses now sit
behind a collapsed "Go deeper, advanced topics, optional" disclosure inside
Grow:

- Mainstream, shown by default: Are You Ready to Invest?, Stocks and Bonds
  Without the Hype, Deposits and Pooled Funds.
- Behind Go deeper: Crypto Without the Hype, Philippine Government Securities.

Both advanced courses stay INSIDE Grow. They are never moved to a new
top-level category; the hierarchy carries the difficulty, no new bucket does.
Each carries a DISTINCT one-line note so the two never read as sharing a risk
profile:

- Crypto Without the Hype: "Optional. Higher risk, can lose value."
- Philippine Government Securities: "More technical. Not higher risk."

Two details that keep the disclosure honest:

- The course count still totals every course, hidden or not. Grow reads
  "0 of 5 courses done", never "0 of 3", so the disclosure hides nothing from
  the arithmetic.
- If a learner is already mid-way through one of the advanced courses, the
  section opens for them, so an in-progress course is never trapped behind a
  tap. A fresh visitor still meets it collapsed.

Reference material stays within-course progressive disclosure, exactly as
before, and was not promoted to a top-level category.

## The fragmented income intervention

The approved intervention for the fragmented income and cash-flow picture is a
concise connection, not a rewrite. SSS, PhilHealth and Pag-IBIG are the
deductions between gross pay and take-home pay, so the SSS & PhilHealth course
gained one action that opens the existing Take-home pay calculator (the
`salary` route), which shows gross pay minus SSS, PhilHealth, Pag-IBIG and tax.
The contributions then read as the deductions they are. Nothing new was
calculated and no money math was added; the link resolves through the same
closed action-route switch every other course action uses, and the calculator
opens exactly as the Tools hub opens it.

## The pending piece this batch completed

The regrouping was implemented but three existing tests still assumed all five
Grow courses render in one flat list, so they failed the moment the Go deeper
disclosure hid the two advanced courses by default:

- path_screen_test: "lists every course with its own count"
- path_screen_test: "exactly one course carries the filled button"
- learn_screen_grow_path_test: "All lessons groups the flat list under each
  course's own title"

These are now updated to assert the approved behavior rather than the old flat
list: the mainstream courses show by default, the advanced ones are hidden
until Go deeper opens, every course is reachable and still its own card once it
does, and the count is unchanged. The updates verify the real invariant the
regrouping must hold, which is that no course became unreachable.

Break-then-prove: the Go deeper section was temporarily forced to never render
its children, and the tests failed exactly at "course is its own card once Go
deeper opens" (in both files), which proves the guard catches a broken
disclosure rather than passing regardless. The break was restored only after
the run reported.

## Validated in Fable

Rendered against the lived-in fixture and looked at, dark first, then light,
then at 1.5x system text:

- The Learn order: Protect, then Grow, then Business under ADVANCED, with all
  three lesson counts intact.
- Grow collapsed: the mainstream three plus the closed Go deeper row, count
  reading "0 of 5 courses done".
- Grow expanded: both advanced courses as their own cards, each with its own
  distinct note.
- Grow at 1.5x text: titles and the Go deeper header wrap cleanly, no overflow
  and no clipping.

The screenshots were surfaced to the founder in the conversation.

## Test results

flutter analyze: 0 issues. The full course, learn, path and expansion suite is
green (165 tests across course_funnel, course_plan, course_sequences,
expansion_content_policy, expansion_lesson_reader_widget, expansion_progress,
expansion_progress_store, expansion_recommendation, learn_journey_hero,
learn_screen and its per-path variants, learning_path, money_courses_registry,
and path_screen). The full local suite is green. The runner Flutter check is
the standing backstop, since the dev sandbox has no outbound network.

## Deliberately NOT done in this batch

Per the approved sequence and the stop conditions:

- No rewrite of the roughly 82,000 words of course content. This batch moved
  shelves, it did not rewrite books.
- No Protect density or source-governance work.
- No quiz or calculator interaction batch.
- No Phase 7.

## What comes next, pending review

The next step in the approved plan is the first content-density group. This
report is returned for review before that begins, so the hierarchy can be
confirmed correct before any content is rewritten on top of it.
