# Money Courses experience audit

Audit only. No Flutter code or course content was changed. This is the
expert review of whether the Money Courses actually keep users engaged,
requested 2026-08-06, and it is deliberately blunt. It was produced by a
nine-specialist review panel (product design and Flutter UI, behavioral
science, financial coaching, a simulated three-person Filipino user panel,
accessibility, product management, learning experience design, content and
copy strategy, and information architecture), each reviewing independently
before consolidation, plus a firsthand walkthrough of the real rendered
screens via the screenshot harness (dark theme first). Where a finding
names a file and line, it was verified in code, not assumed.

Companion document: docs/money_courses_expansion_audit.md (the architecture
audit written before the expansion shipped). This one is about the learner.

---

## Executive summary

The Money Courses are two different products wearing one name.

The core 22 lessons are genuinely good: about 194 words each, warm,
Filipino, block-structured like a conversation, and every lesson ends in a
button that does something real in the app. The simulated user panel had
all three archetypes finish one. That is rare.

The 71 expansion lessons average 824 words each (Insurance Decoded reaches
about 1,047), open with definitions instead of the reader's life, carry a
three-to-five-card compliance stack on every single lesson, and render as
one long scroll of prose followed by a worksheet. The founder's complaint,
"reading feels like reading an article," is not a feeling. It is the
literal render order in the expansion reader: all content blocks, then all
interaction blocks, then the quiz (widgets/expansion_lesson_reader.dart,
build loop). And the four block types designed specifically to prevent
article-ness (Discovery, Story, Trap, Challenge) are used exactly zero
times across all 71 expansion lessons.

Above all of it sits one product fact that outranks every content finding:
Money Courses is not a tab. It is one row on the Tools screen, listed below
the currency converter (screens/tools.dart:158). The app's largest content
investment, 93 lessons and roughly 63,000 words, is behind a door most
users will never open. And for those who do, finishing a lesson is a dead
end: a quiet text row, no next-lesson button, no celebration, while a
confetti system and a share-card engine already ship in the app and fire
for debt payoff, never for learning.

### Scores

| Dimension | Score | One-line reason |
|---|---|---|
| Overall | 4.5 / 10 | World-class bones, article-shaped delivery, buried front door |
| Learning experience | 4 / 10 | Reader architecture defeats the pedagogy the blocks were built for |
| UX and journey | 4 / 10 | Buried entry, dead-end finishes, accordion hub past its limit |
| Visual design | 6 / 10 | Typography is handsome; ten block types collapse into one beige card |
| Content quality | 5 / 10 | Bimodal: core 9/10, business courses 2 to 4/10 |
| Engagement and behavior | 3 / 10 | No loop, no celebration, no habit cue, no momentum |
| Accessibility | 5 / 10 | Expansion interactions strong; core reader failing for blind users |

### Completion likelihood, as shipped

- Core tracks, for users who find them: roughly 50 to 70 percent of
  starters per track (Cushion and Debt highest).
- Expansion courses: roughly 15 to 45 percent of starters per course
  (Insurance Decoded lowest at an estimated 15 to 20 percent, Pag-IBIG
  highest at about 40).
- Whole catalog for a typical new user: low single digits, because the
  entry point caps everything upstream.

These are expert estimates from lesson length, drop-off points, and mobile
microlearning norms, not measurements. The app records five progress
states per lesson on-device and surfaces none of them, so the real funnel
is currently unknowable. Fixing that is a Phase 1 item.

### What is genuinely excellent and must not regress

The panel was asked to be brutal, and it was. It also found decisions here
that are better than most funded edtech products, and every recommendation
below is built on top of them, not instead of them:

- Opening a lesson is not finishing it. Progress is earned by engaging,
  never by scrolling, and the five-state model (viewed, understood,
  completed, applied) never demotes.
- Required interactions genuinely gate expansion completion, fire only on
  real user gestures, and un-complete on retry. Most gamified apps fake
  this.
- Every recommendation shows its reason. Prerequisites advise and never
  lock. Wrong quiz answers are never stained red and the copy never says
  "wrong."
- Every core lesson ends in a real in-app action, optional by design so
  nobody invents financial records to finish a lesson.
- The content safety posture (no product names, no return promises, no
  eligibility verdicts, verified official sources) is correct and none of
  this audit proposes loosening it.
- Education is free forever. Nothing below paywalls any of it.

---

## Critical findings

Ranked by severity. File references verified in code.

### Critical

**C1. The entry point buries the whole feature.** Money Courses is a row
on the Tools screen (screens/tools.dart:158), below the currency
converter, plus a cross-link from Mindset. It is not a tab and has no
presence on Home. Nothing else in this audit matters until this does: the
best lesson in the world has a completion rate of zero behind a door
nobody opens.

**C2. Finishing anything produces nothing, and there is no next step.**
Both finish rows (screens/learn.dart:1190, expansion_lesson_reader.dart:318)
render a static "Done. One useful thing." with no animation, no haptic, no
recap, and no "Next lesson" button. The user backs out to the hub and must
re-find the card among seven. For a 30-lesson path that is 30 hub hunts.
Meanwhile showCelebration (widgets/celebration.dart:23, confetti, haptic,
reduce-motion aware) and the milestone share-card engine already exist and
fire for debt payoff. Course completion and path completion render nothing
at all beyond a progress bar recolor the user is not looking at when it
happens. This is not a missing system, it is a missing wire.

**C3. The expansion reader's architecture manufactures the article
feeling.** The build loop renders every content block, then every
interaction block, then the quiz, in one ListView
(expansion_lesson_reader.dart:146-182). An author cannot place a practice
moment next to the idea it tests. An 824-word lesson is therefore an
article followed by a worksheet by construction. The core reader is better
(blocks in authored teaching order), so this is a regression specific to
the 71 longest lessons.

**C4. The lively blocks were never used.** lesson_blocks.dart defines
DiscoveryBlock ("curiosity before instruction"), StoryBlock, TrapBlock,
and ChallengeBlock ("check a guess against your own Salapify data").
Verified by grep: zero uses of any of them across all twelve expansion
course files. Every expansion lesson is Prose plus Nuggets plus compliance
cards plus quiz-shaped interactions. The tools built to prevent the
article problem sat on the shelf while 71 article-shaped lessons were
written. All 29 expansion lessons in the Grow path open with the identical
heading "Why it matters," and in the render walkthrough that heading
introduces definitions, not stakes: two of three user-panel archetypes
stopped at the first sentence of the crypto course ("A crypto asset is a
digitally represented asset that uses distributed-ledger or related
technology...").

**C5. The voice fractures between core and expansion.** Measured: the
word "generally" appears 151 times across the four Build Your Business
files and zero times in the core 22. Mean sentence length roughly 14 words
in core versus 30 to 41 in the business files, with 128 sentences over 40
words. BIR Setup for New Businesses contains 29 "this lesson never..."
self-descriptions and knowledge checks that quiz the disclaimer ("does
this course determine which obligation categories apply to a specific
reader?"). Insurance Decoded has comparison exercises whose every cell
reads "Stated in its own schedule of benefits," a comparison with no
difference in it. A learner who loved Track 1 will believe the app
changed hands.

**C6. Real defect: a finished expansion lesson presents as unfinished on
reopen.** _completedBlockIds is ephemeral widget state
(expansion_lesson_reader.dart:91) and the reader never reads the stored
LessonState back. Reopening a completed lesson shows "0 of N required
interactions completed" with a disabled Finish button, even while the hub
shows the tick. Showing a learner their earned progress as zeroed is
corrosive, and this one is a bug, not a design choice.

**C7. The core reader is not honestly usable by a blind user.** The core
quiz result ("That is it." / "Close. Here is the thinking.") has no live
region so TalkBack announces nothing on answer (learn.dart:1158-1184);
choices carry no button role, no selected state, and the correct answer is
marked only by border color and an unlabeled icon; the Discovery reveal is
silent and drops focus; hub lesson rows carry done/in-progress state only
in an unlabeled icon; and nothing in a five-minute lesson is marked as a
heading for traversal. The expansion interaction stack already contains
the correct patterns (live regions, merged semantics, 48dp rows), so four
of the five fixes are copy-paste from the app's own newer code.

### High

**H1. The compliance chrome tax.** Across the 29 Grow-path lessons alone:
63 OfficialSource cards, 29 verbatim EducationalBoundary paragraphs, and
roughly 36 RiskWarning cards. Several lessons end with three source cards
back to back, so the transition from reading to doing, exactly where
quitting happens, is three to five gray legal cards in a row. In the
render walkthrough, the Readiness Card lesson's first two screens are
almost entirely disclaimer and citation. The compliance content is
necessary; its per-lesson repetition and placement are presentation
choices, not governance requirements.

**H2. The hub answers "how much work is left," not "what do I do next."**
First visit leads with a zeroed progress bar and "0 of 22 lessons, 0 of 4
courses, about 43 min left" (verified in the dark render). Homework
framing. Worse, the headline metric counts only the 22 core lessons: a
user who finishes all 18 Protect Your Future lessons still reads "0 of 22
lessons" at the top of the screen. The header ignores 76 percent of the
catalog.

**H3. The expand-inside-card hub pattern is past its limit.** Expanding
Grow Your Money injects about 30 two-line rows (roughly 2,500 px) into the
middle of the hub scroll via AnimatedSize; the collapse control scrolls
away from the user; there is no per-course entry point at all, so "Crypto
Without the Hype" cannot be discovered without expanding and scrolling the
whole path blob. Fine at 6 rows, broken at 30.

**H4. Knowledge checks that grade the disclaimer.** Insurance L2 and L6,
SSS L3 and L6, Pag-IBIG L4 and L6, and most of BIR Setup spend the
lesson's single graded moment testing the app's legal posture instead of
the material. The correct answer is also usually the longest, most hedged
choice, so learners pattern-match on length and the retrieval attempt
never happens.

**H5. Unmanaged redundancy across the catalog.** Scam verification is
taught in full four times (stocks-bonds, crypto, government securities,
insurance, with deposits carrying the same pressure-pitch material); the
PDIC deposit-insurance boundary is re-taught in roughly eight places; the
"check your posted contribution record" checklist exists three times (SSS,
Pag-IBIG, core own-your-benefits); two closing recap lessons (SSS L6 and
Pag-IBIG L6) share copy-pasted scenario and answer text a user taking both
courses will notice. Re-teaching instead of retrieval inflates the catalog
by an estimated 1,500 to 2,000 words per path.

**H6. Two recommendation engines, two badges, both can glow at once.**
recommendedTrack always stars a core card; recommendedExpansionCourse
stars a path card whenever one is started. A user who has touched both
sees two orange star cards ("RECOMMENDED" and "CONTINUE THIS PATH"). Two
simultaneous "do this next" signals equal none.

**H7. Walls of text that exceed working memory.** Worst measured
offenders: one crypto sentence listing eleven scam patterns; one
government-securities sentence listing seven risks followed immediately by
seven warning signs; an eight-question opening paragraph; five glossary
definitions in one paragraph explaining bond math three times with no
worked peso example anywhere. Declared minutes also undercount reality
(one "6 min" lesson is 1,379 words plus an 8x8 categorize matrix plus two
more interactions, realistically 12 to 15 minutes), which trains users to
distrust every time promise in the feature.

**H8. The reader is a headless scroll.** Both readers' AppBars carry no
title, no course context, and no progress indicator. Once the hero scrolls
off, the learner has no idea which lesson they are in, how far along, or
how much is left.

### Medium

**M1. Ten block types collapse into one visual.** Discovery, Trap, Rules,
OfficialSource, RiskWarning, Boundary, the interaction card, the prereq
box, and the scope note all render as the same 1px-border rounded
rectangle with an identical 12px muted caps kicker. Only Nuggets, Story,
and Reflection look like themselves. A long lesson scrolls as a monotone
column.

**M2. The core quiz is one-shot forever; the expansion quiz offers Try
again.** Two different rules for the same-looking card (learn.dart:1119
versus expansion_lesson_reader.dart:304). A mis-tap in a core lesson locks
the wrong answer for the visit.

**M3. RiseIn replays its entrance animation every time a block re-enters
the viewport,** so scrolling back up makes already-read cards vanish and
fade in again, up to 270 ms late, and it ignores the reduce-motion
setting that PressableScale and the celebration overlay honor.

**M4. Course sequencing.** Government Securities, the lowest-risk
instrument family, is taught with the most abstract material and sits
after crypto; a Filipino saver's natural ladder is deposits, then
government securities, then stocks and bonds, then crypto last. Insurance
Decoded gates its genuinely protective lessons (VUL mechanics, pressure
red flags) behind two taxonomy lessons and roughly 3,000 words.

**M5. Naming.** Core titles sell outcomes ("Utang without losing the
friendship," "The minimum payment trap"). Seven expansion titles label a
syllabus ("Deposits and Pooled Funds," "Philippine Government Securities,"
"Permits, People, and Compliance," "BIR Registration and Local Permits"
versus "BIR Setup for New Businesses," indistinguishable siblings). Also
"Without the Hype" appears four times; twice is a voice, four times is a
template showing.

**M6. Everyone sees everything.** A 19-year-old student scrolls past 24
business-compliance lessons; a parent with a side business gets "Your
first cushion" starred. The forFreelancers flag exists and is unused. The
recommendation engine already proves on-device personalization works;
it reorders one star and never the catalog.

**M7. Small-text legibility stack.** The PHILIPPINES tag renders at
fontSize 9, below the type system's own declared floor of 10 to 11
(learn.dart:582, 1076); lesson metadata stacks the smallest size, lightest
weight, and faintest ink at 4.56:1, passing AA with almost no margin.

**M8. Missing high-value content, present low-value content.** Missing:
a kinsenas/katapusan sweldo-cycle lesson (the defining Filipino salaried
cash-flow problem, and the app already has the Sweldo Timeline screen to
route to); the borrower's side of utang; 5-6 and predatory lending apps
(the most dangerous credit products the audience actually uses). Present
but drifting: health-is-wealth is the only core lesson that wanders into
general wellness, has no challenge block, and duplicates a Goals route.
Suppressed by over-applied volatility rules: MP2's five-year maturity, a
stable structural fact the whole liquidity argument depends on, is never
stated; the insurance cooling-off period could safely say "days, not
months."

### Low

**L1.** Off-ladder font sizes 27 and 19 are exactly the sizes
typography.dart says were purged; the lesson hero also uses the body face
where the display face (Fraunces) is reserved for such moments.
**L2.** The official-source card's only button is "Share link," which
hands a citation to the share sheet when the user's intent is reading.
**L3.** "MASTERY CHECK" overclaims for one multiple-choice question.
**L4.** The applied state, the top rung of the progress model, is
visually identical to completed and triggers no acknowledgment, though it
is the single behavior most worth reinforcing.
**L5.** Reflection free-text prompts are never referred to again even in
session, so they read as skippable homework.

---

## Course-by-course review

Engagement is scored 1 to 10. Completion is the estimated share of users
who start lesson 1 of that course and finish it, for users who reach the
course at all.

### Core tracks (lessons.dart), the standard everything else should meet

| Track | Engagement | Est. completion | Verdict |
|---|---|---|---|
| Your first cushion | 9 | 60 to 70% | Keep. Add the kinsenas/katapusan lesson here. |
| Debt zero | 9 | 60 to 70% | Keep. Add 5-6 and lending-app lesson; add borrower-side utang. |
| Swing income survival | 8 | ~45% | Keep. The 8 percent paragraph (118 words) and the tax-forms lesson (nine paragraphs, six form numbers) need the split treatment. |
| Big money moments | 8 | 55 to 65% | Keep. Trim or demote health-is-wealth. |

Strengths: voice, brevity, action routes, correct and correctly ordered
finance (starter cushion before debt attack, snowball versus avalanche
with a real in-app comparison, the May-15 first-quarter trap, the 2024
abolition of the registration fee with "ignore old guides"). Weakness:
the three content gaps in M8.

### Grow Your Money (5 courses, 29 lessons)

| Course | Engagement | Est. completion | What to do |
|---|---|---|---|
| Are You Ready to Invest? | 7 | 55 to 65% | The model expansion course. Tightest prose, real interactivity, the Readiness Card is a genuine payoff. Fix only the disclaimer stack and openings. |
| Stocks and Bonds Without the Hype | 6 | 40 to 50% | Split L5 (bond anatomy plus five risks, 1,038 words, 4 interactions) into two lessons. Cut "generally" x30. L6 becomes the canonical scam module. |
| Deposits and Pooled Funds | 5 | 35 to 45% | Heaviest course by words. L4's 8-criteria regulator table is the dullest stretch in the path; L6 (1,283 words, 6 interactions, labeled 7 min) is a full exam. Rename ("Where Should Your Savings Sleep?"). PDIC re-taught three times inside one course. |
| Crypto Without the Hype | 7 | 45 to 55% | Best interactions in the path (loss simulator, four branching custody scenarios). Rewrite the definition-first opening that loses readers; split L4 (stablecoins plus yield plus leverage is three lessons); break the eleven-scam sentence. |
| Philippine Government Securities | 4 | 30 to 40% | Most PH-specific value, driest delivery ("generally" x46). L3 needs one worked peso example and a price/yield see-saw interaction; L5 (1,379 words plus an 8x8 matrix) splits in two, with its scam half becoming a retrieval check. Consider moving the whole course before stocks and bonds. |

### Protect Your Future (3 courses, 18 lessons)

| Course | Engagement | Est. completion | What to do |
|---|---|---|---|
| Insurance Decoded | 4 | 15 to 20% | The longest lessons in the app guarding the best material. Merge L1 and L2 (L2 has no facts, only a worksheet). Delete the two contentless comparison blocks. Rewrite the disclaimer-grading checks. Add the "agent is your tita" scenario and a copyable three-question script for any pitch. Target under 700 words per lesson. |
| SSS & PhilHealth Essentials | 5 | ~35% | L2's eight identical "may apply here, worth checking" explanations each get one real structural fact. L3 becomes the job-change trigger moment. Merge L4 and L5. Fold L6 (a recap sharing copy-pasted blocks with Pag-IBIG L6) into L5. Cross-route freelancers to the Contribution checker the core lesson already uses. |
| Pag-IBIG Savings & Housing | 6 | ~40% | Best of the three: MP2 myth-busting maps onto this week's actual TikTok hype, and the housing-loan true-cost lesson is the most complete expansion lesson shipped. State the five-year maturity as the structural fact it is. Consider opening the course with the MP2 lesson; MP2 curiosity is a real acquisition hook. |

### Build Your Business (4 courses, 24 lessons)

| Course | Engagement | Est. completion | What to do |
|---|---|---|---|
| Start Your Business Legally | 3 | ~25% | Passive checklists ("has been considered" x3) become first-person; the eight-dimension 70-word opening sentence becomes a sari-sari analogy; 47-word takeaways get the two-sentence cap. |
| BIR Registration and Local Permits | 4 | ~30% | The only business course that states real facts (fee abolished, ATP free, threshold moved) and it buries the good news under citation. Lead with the news, cite after. "generally" x67 is the worst count in the app. |
| BIR Setup for New Businesses | 2 | ~20% | The weakest course shipped. It deliberately states no fact, so what remains is meta-commentary about what it will not say, quizzed. Either give each lesson one stateable habit (the core file's "move the tax slice out the day you get paid" pattern) or fold the course into its two siblings. |
| Permits, People, and Compliance | 3 | ~25% | Same treatment as its siblings; delete the triple-verbatim "not a licensing decision" repetitions; 62-word takeaway gets capped. |

Path-level call, agreed by the PM, IA, and coach reviews: do not delete
this path (shipped, tested, verified, and the enhance-never-regress rule
applies), but demote it to a collapsed "For freelancers and business
owners" section rather than equal rank with courses 90 percent of the
launch audience needs. Freeze new course authoring until completion data
exists.

---

## UI review

Rendered via the screenshot harness against the lived-in fixture, dark
first, and shared in the session conversation: courses-dark.png (hub),
lesson-dark.png (core reader), insurance-vul-no-sales-pitch-dark.png,
grow-readiness-card-dark.png (all under flutter/test/shots/, gitignored
working images, reproducible with
`flutter test test/screens_shot.dart --update-goldens`).

What the renders show, annotated:

- **Hub:** handsome type, clear cards, and the first viewport leads with
  three zeros and a 43-minute bill. The recommended card's 1px orange
  border is nearly invisible in the light theme. Seven near-identical
  full-width cards share equal weight.
- **Core lesson (Your first shield):** the good pattern, visible. Chips
  with ticks, a THINK FIRST discovery card with a "Show me" button, short
  paragraphs, generous rhythm. This is what the expansion should feel
  like.
- **VUL lesson:** the first full screen after the title is four dense
  paragraphs under WHY IT MATTERS, no interaction in sight. The wall is
  real.
- **Readiness Card lesson:** the first two screens are a disclaimer box
  and two full-height OFFICIAL SOURCE cards with Share buttons before any
  teaching. The compliance chrome dominates the exact real estate where a
  learner decides whether to continue.

Visual system recommendations (detail in findings M1, H8, L1):
differentiate block families (interactions get raised surface and accent
kickers; reference material gets a quieter collapsed treatment; coaching
keeps borders); give the reader a title and a thin scroll-progress bar;
snap the off-ladder sizes; let the hero title use Fraunces; and reserve
the current bordered-card look for at most one family instead of ten.

---

## Quick wins

High impact, small effort, all pure Dart, all OTA-patchable. Ordered.

1. **Wire the existing confetti to lesson, course, and path completion.**
   Two imports and about ten lines per reader. The emotional endpoint of
   every lesson changes.
2. **"Next: {title}, {minutes} min" button in the finish row** of both
   readers, using the ordered lists and nextLessonId logic that already
   exist. Kills the dead end outright.
3. **Restore stored completion on reopen** (fixes defect C6): pass the
   stored LessonState into the readers; completed lessons open finished,
   with interactions replayable.
4. **Reader header: "3 of 6, Insurance Decoded" plus a thin progress
   bar** in the AppBar of both readers.
5. **Accessibility pack for the core reader:** live region on quiz
   feedback, button/selected semantics and 48dp on choices, heading
   semantics on kickers and titles, a spoken state word on hub rows,
   live region on the Discovery reveal. Four of five are copy-paste from
   the expansion code.
6. **Calm the zero-state hub:** hide the "0 of X" stat rows until
   something is started; surface two or three human-titled lessons as
   direct tap-in hooks; count all 93 lessons in the header once progress
   exists.
7. **A neutral cold-start line for the expansion section** ("Most people
   start with Are You Ready to Invest, 22 min"), since its recommender is
   correctly mute for new users.
8. **Honest minutes** recomputed from word count plus interactions.
9. **Fix the 9px PHILIPPINES tag** (use micro at 11 as-is) and drop the
   .w4 on faint micro metadata.
10. **Haptic plus celebrate-color pulse on correct answers**, and port
    the expansion's "Try again" back to the core quiz.

---

## Major opportunities

The three changes that would transform the feature, each a real project.

**1. Paginate the lesson: card-per-screen, practice interleaved.**
Replace the two sequential render loops with one authored sequence
(content and interactions in one ordered list), presented one segment per
screen with a Continue button and progress dots, Brilliant-style. Prose
block, then the interaction that tests it, ten seconds later. The sealed
block system is already a perfect page source; gating falls out naturally
(Continue enables when the block completes); RiseIn finally makes sense
as a page transition. Roughly a 300-line shared PagedLessonReader, both
readers adopt it, zero content rewrites needed for the first pass. This
single change converts every existing lesson from article-plus-worksheet
into teach-try-teach-try, which is the founder's exact complaint fixed at
the root. Completion semantics (required interactions still gate finish)
and the content tests must stay intact per the enhance-never-regress rule.

**2. Restructure the catalog: Path, then Course, then Lesson, with real
screens.** Retire the tracks-versus-paths split (it is build history
leaking into UI): the four core tracks become the four courses of a
"Money Foundations" path, presentation-only, no id changes. The hub
becomes four things: one merged "Up next" hero (one arbiter over both
recommendation engines, one badge ever), a "Continue" shelf of started
courses, then path cards that push a real Path screen (courses as a
visible numbered journey, the already-authored recommendedPriorGroupIds
finally rendered as tappable "best after" chips), each course pushing its
own six-lesson screen. The 30-row accordion disappears structurally.
Business path and Government Securities sit under a collapsed Advanced
section. Rename the seven syllabus titles. And move the entry point: at
minimum a persistent "Up next lesson" card on Home fed by the
always-answering core recommender, honestly evaluated against a bottom
tab.

**3. Deploy the unused pedagogy and de-chrome the compliance.** Open
every expansion lesson with a Discovery hook or second-person scenario
instead of "Why it matters" plus definition (the core lessons already
model this). Convert the best fictional scenarios into recurring named
characters (Liza, Mika) and drop the 38 spoken "fictional" prefixes; the
boundary block already declares it. Move the full boundary text and
source list to a once-per-course intro screen, collapsing the per-lesson
stack to one slim expandable "Educational, not advice. Sources: PSE, SEC
(verified 2026-08)" footer, keeping every compliance statement reachable
and testable. Build two more simulator-grade blocks on the
LossImpactSimulator pattern (a price/yield see-saw for bonds, a fee-drag
slider for funds) to replace the two driest prose stretches. Create one
canonical "Verify before money moves" module and turn the other three
scam re-teaches into two-minute retrieval checks, converting the
catalog's biggest weakness into spaced repetition.

---

## Prioritized roadmap

Effort: S is hours, M is a session, L is multiple sessions. All phases
ship OTA unless noted. Metrics come first so later phases are
evidence-driven instead of guessed.

### Phase 1: Quick UX and copy improvements (effort M total, impact: the largest completion lift available)

The ten quick wins above, plus on-device funnel metrics: a diagnostics
section showing the lesson-state distribution per track and path (counts
only, respecting the diagnostics privacy test), and a completedAt
timestamp added to progress writes. The timestamp touches the stored data
shape, so it is flagged loudly and goes past the founder before merging,
per the merge rules.

### Phase 2: Content simplification (effort M to L, impact: perceived length drops ~30 percent without touching a verified fact)

Presentation first, prose second. Collapse the per-lesson compliance
stack to the course-level screen plus footer (governance tests move with
it). Rewrite every disclaimer-grading knowledge check to grade the world
(named-person scenarios, varied whyWrong wording). Enforce a "one
generally per lesson" budget and a 25-word sentence cap for the business
files with a content test, the same way the stamp cap is enforced. Cap
keyTakeaways at two sentences. Strip "fictional" prefixes and the
"has been considered" passives. Delete the contentless insurance
comparisons. State MP2's five-year maturity and the cooling-off "days,
not months" phrasing as structural facts under existing governance. Note:
any touched course's full source list must be re-searched per the
CLAUDE.md rule, so batch edits per file and prefer presentation-layer
changes where possible. Rewrite in the measured core voice; twelve
before/after pairs from this audit are ready to use.

### Phase 3: Interactive learning features (effort L, impact: fixes the article complaint at the root)

The PagedLessonReader (major opportunity 1). Authored interleaving of
interactions into content order. Split the overweight lessons (stocks-
bonds L5, crypto L4, deposits L6, gov-securities L5, insurance L1+L2
merge) into micro-lessons of 250 to 400 words with one idea and one
interaction each; new stable ids per the id-stability rule, more
completion events as a side benefit. Deploy Discovery, Story, and
Challenge blocks. Two new simulator blocks. The canonical scam module
plus retrieval checks. Cap categorize matrices at four buckets.

### Phase 4: UI modernization (effort L, impact: discoverability and orientation)

The hub and catalog restructure (major opportunity 2): Home entry card,
merged recommender, Path and Course screens, Advanced tier, renames,
block-family visual differentiation, Fraunces heroes, ladder-snapped
sizes. Screenshot harness renders before merge, per house rules.

### Phase 5: Gamification and behavioral design (effort M, impact: day-2 return, the thing content cannot provide)

Copied from the app's own philosophy, never against it: a learning chain
on the hub reusing the week-chain pattern (gap-tolerant, "Missed a day?
Nothing resets here.", gold only at a full week, never a resetting
streak); per-course completion badges and a shareable recap card through
the existing milestone share pipeline (keeper sentences on it, education
framing preserved); the applied state made visible ("Used in app") and
differentially acknowledged; one non-recurring continuation nudge for a
course stalled seven days, aligned to the payday window, silent if coach
nudges are off. Explicitly rejected: XP, points, levels, leaderboards,
and anything social. A points economy teaches optimizing for points and
would sit dishonestly beside the app's scrupulously honest progress
model.

### Phase 6: Advanced learning experience (deferred until Phase 1 metrics exist)

The three-question offline persona chooser (student / salaried /
freelancing / business owner, plus debt and dependents), stored in
settings, reordering paths and cold-start picks, never hiding content.
Spaced review of completed lessons (the retrieval checks from Phase 3
become a review queue). New content only where the audit found real gaps:
kinsenas/katapusan, borrower-side utang, 5-6 and lending apps. Do not
build sequencing sophistication on an unwalked path; that is why this
phase waits for data.

### Standing kills

No new expansion courses until completion data justifies one. No
prerequisite locks. No paywalling anything in Learn, ever. No loosening
of the no-products, no-promises, no-verdicts content policy.

---

## Guiding principles check

Every recommendation above was tested against the brief's goals: teach
faster (micro-lessons, interleaving, one idea per screen), reduce reading
fatigue (de-chrome, sentence caps, pagination), increase completion
(chaining, celebration, honest minutes, entry point), make learning
enjoyable (discovery hooks, simulators, named characters), build
confidence (never-shame feedback preserved, applied state celebrated),
simple everyday language (the core voice as styleguide, enforced by
test), real-life decisions (the tita pitch, the sweldo cycle, MP2 hype),
and mobile-first (paged reader, four-bucket cap, 48dp everywhere).

The one-sentence version of this entire audit: the core 22 lessons
already prove Salapify knows how to teach; the expansion shipped the
curriculum without the classroom, and the front door is behind the
currency converter. Fix the door, the loop, and the reader, and the
content problems shrink to an editing pass.
