# Phase 6B Batch C5: Cross-Course Integration Report

Money Courses reviewed as ONE learning product. The final cross-course
content and integration pass before Batch D. Coherence over rewriting,
consistency over content, journey over individual-lesson perfection. Verified
domain content (Core 22 from Batch B, Protect from C2, Grow from C3, Business
from C4) was frozen; each substantive edit below is justified by a documented
defect. A six-agent specialist panel (product, learning-experience/content,
financial coach, behavioral, Flutter/UX) plus a targeted tax review informed
this report.

## 1. Curriculum health summary

The curriculum hangs together well as one product. All five panel reviewers
independently found the courses disciplined and mutually consistent: no
guaranteed-outcome language, product-neutral, decision-oriented, and the
concept reuse is overwhelmingly intentional reinforcement (a concept applied to
a new decision), not duplication. The START HERE / CONTINUE hero, the collapsed
"Go deeper" disclosure, the ADVANCED tier marker, and the guide-not-lock
prerequisite model all work as intended. The real seams were a small set of
integration defects, now fixed, plus a body of Batch D interaction-fatigue
opportunities. One hard cross-course contradiction (a graded step order) was
found and corrected under a tax review. Word count was never a target and none
was cut.

## 2. Final learning architecture

- CORE MONEY SKILLS (22 lessons): everyday foundations, each with one
  KnowledgeCheck, no interaction blocks.
- PROTECT (protect_your_future): Insurance Decoded, SSS & PhilHealth, Pag-IBIG
  / MP2 / Housing.
- GROW (grow_your_money): Investing Readiness, Stocks & Bonds, Deposits &
  Pooled Funds, and under GO DEEPER: PH Government Securities (advanced =
  technical), Crypto (advanced = optional, higher-risk).
- ADVANCED > BUSINESS (build_your_business): Start a Business Legally, BIR
  Registration & Local Permits, Taxes & Filing for Your Business, Business
  Permits & Compliance (advanced = life-situation, for a subset of users).

The order and the three distinct reasons for "advanced" are legible in the UI,
with one gap noted in section 8 (Business's ADVANCED marker has no "why" line
the way Grow's Go-deeper courses do).

## 3. Redundancy matrix

Classification: RE = intentional reinforcement (same idea, new decision),
PR = necessary prerequisite recap, DUP = reteaches without adding context.
Only DUP is a reduction candidate. The full matrix (all 18 concepts) is KEEP
except the two rows called out below.

| Concept | Verdict |
|---|---|
| income / take-home pay, expenses, cash flow, needs vs wants, budgeting, emergency fund, debt, interest/coupon/yield/dividend, insurance, risk/volatility, diversification, investing readiness, government contributions, Pag-IBIG/MP2, financial position/net worth | RE or single-treatment. KEEP. |
| scams / verify-before-you-invest | RE, noted: the red-flag "Red flag / Reasonable sign" sort is near-verbatim in five courses; only the verification channel differs. Defensible because each course is independently takeable, but it is the most-repeated interaction in the product, so it is the top Batch D consolidation target (section 12). |
| business registration order | Contained the one hard DUP-adjacent CONTRADICTION, now fixed (section 4). |

The emergency-fund repetition across eight courses is the textbook
"different decision in a new context" case (build it, it is not a policy, fund
it before investing, it is not a benefit or MP2): KEEP explicitly.

## 4. Changes made (five defect-driven edits)

Each edit carries cross-referenced evidence; nothing was changed for style.

1. **BIR step-order contradiction, corrected under tax review (hard defect).**
   `lessons_bir_local_permits.dart` Lesson 1's SortingBlock graded BIR
   registration at position 2 (ahead of the barangay clearance and Business
   Permit), while its sibling `lessons_business_permits_compliance.dart` Lesson
   2 grades BIR at position 5, and that file's own header records the
   independently-confirmed order as local-permits-then-BIR. Course 1 even
   contradicted its own prose and nugget. A tax-professional review ruled the
   authoritative order is local-permits-then-BIR (the Business Permit is a
   documentary requirement for BIR registration; RA 7160 fixes barangay before
   the Mayor's Permit; RA 11976/EOPT changed BIR fees and channel, not the
   permit-then-BIR dependency), and that the order genuinely varies at the
   BIR-vs-local joint by LGU and RDO. Fix: reordered the SortingItemDef
   declarations (name, barangay, Mayor's Permit, BIR, books, ongoing), reworded
   the KnowledgeCheck explanation whose "before barangay clearance and the
   Business Permit" claim became false, and aligned the keyTakeaway listing
   order. The existing MythOrFact "this is not a fixed legal requirement" and
   the prose hedges keep the variation honest. The two courses now grade the
   same order.
2. **Recommendation reason named a course that does not exist by that name.**
   `expansion_recommendation.dart` returned "Finish Investment Readiness before
   exploring specific investment topics," but no course is titled "Investment
   Readiness" (the course is "Are You Ready to Invest?"). Corrected to the real
   title.
3. **Protect path description described only Course 1.** It read "Understand
   your protection needs and compare policy types before you talk to an insurer
   or agent," naming only insurance and hiding SSS/PhilHealth and Pag-IBIG (two
   of three courses). Broadened to "Insurance, plus SSS, PhilHealth, and
   Pag-IBIG, explained before you need them."
4. **Grow path description described only Course 1.** It read "Start with
   whether your foundation, and your money, are ready for investing," hiding
   stocks, bonds, funds, government securities, and crypto. Broadened to "Get
   ready to invest, then how stocks, bonds, funds, government securities, and
   crypto actually work."
5. **Fallback reader renamed the check and dropped its screen-reader heading.**
   `expansion_lesson_reader.dart` labeled the mastery check "MASTERY CHECK" in a
   plain Text, while the production paged reader and learn.dart use "QUICK
   CHECK" wrapped in `Semantics(header: true)`. Aligned the fallback reader to
   "QUICK CHECK" with the heading, so the two readers agree and the heading is
   navigable.

No path, course, group, lesson, or progress id, no progress key, backup, or
deep-link contract was changed. All edits are content copy or a display string.

## 5. Terminology audit

Consistent and praised (no change): take-home pay (plain-first, agrees across
Core/Protect and the SSS take-home link); interest / coupon / yield / dividend
(kept distinct per instrument, no course redefines another's term); liquidity
(near-identical definition in three courses); registration / filing / the
abolished 500 peso fee (Core and Business agree on RA 11976).

One inconsistency found, recommended not executed (would be a broad rewrite,
against the C5 mandate): the emergency fund has three names, "emergency fund"
and "cushion" in Core and Insurance, but "emergency buffer" / "buffer" in Grow,
SSS, and Pag-IBIG prose (62 occurrences), while those same lessons link to an
action literally named "Emergency Fund goal." A learner reads "buffer" then
taps a button that says "Emergency Fund." Recommendation for a future small
pass: standardize the sentence noun on "emergency fund," keep "cushion" as
Core's friendly kicker, demote "buffer" to an occasional gloss. Not done here
because a 62-site sweep is exactly the broad rewrite C5 forbids.

Soft, low priority: Grow says "financial foundation / the base" where Core
teaches "net worth (what you own minus what you owe)." Not a conflict (they are
not the same object); a half-sentence gloss tying Grow's "the base" back to
Core's picture would connect the vocabularies. Recommendation only.

## 6. Accounting mental model

- Financial position (own minus owe = net worth): COHERENT. Named plainly and
  by its accounting term in the see-it-first orientation, reinforced in
  card-interest, cushion-or-debt, Grow readiness, and the stocks balance sheet.
- Cash flow (money in to money out): COHERENT. In the orientation diagram, a
  whole app screen the lessons route to, the swing track, and applied to
  companies in stocks.
- Financial performance (money earned minus money spent = surplus/shortfall):
  the FRAGMENTED one. It is taught only behaviorally (50/30/20, pay-yourself-
  first; the word "surplus" appears once in the whole curriculum) and never
  gets a reused plain-English name. The concrete seam: see-it-first displays
  money in and money out but resolves only net worth (own minus owe); a
  beginner expecting "what is left" to be their monthly surplus meets it
  assigned to net worth instead. Recommendation (Core 22 frozen, no new
  lesson): one clause in the see-it-first diagram/caption naming money in minus
  money out as monthly surplus or shortfall, distinct from net worth.

## 7. Income / cash-flow finding

Classification: IMPROVED BUT FRAGMENTED (not RESOLVED, not a genuine remaining
gap). Income and cash flow are taught well (see-it-first, 50/30/20,
pay-yourself-first, the swing track and Cash flow screen), and C2's SSS ->
Take-home Pay link genuinely closed the gross-to-net gap. The residual seam:
the core cushion track's first use of "take-home pay" (50/30/20) treats it as
already known, and the good gross-to-net bridge C2 built lives in the Protect
path and a Track-4 refund lesson, both off the core entry path a first-time
salaried user walks. Recommendation (smallest fix, no new lesson): a one-line
cross-link from 50/30/20 to the same Take-home pay calculator (route 'salary')
at the first use of the term. Low priority; the content already exists.

MP2: thoroughly covered in the Pag-IBIG course (four lessons), correctly not
duplicated into Grow. A one-line navigational pointer from Grow (deposits or
readiness) to the Pag-IBIG course would help discoverability without
duplicating content, since a Grow reader comparing low-risk options gets no
signal that MP2 is taught at all. Recommendation, pointer-only.

## 8. Titles and descriptions

Course titles are a coherent set. "Without the Hype" twice (Stocks, Crypto) is
deliberate brand voice; the ampersand-vs-"and" split is cosmetic and, per the
brief, not worth the churn (C4 already settled BIR naming). Confirm, no change.
Descriptions: the two path-card descriptions that described only Course 1 were
fixed (section 4, items 3 and 4). Course cards carry no description (only title
plus progress), which is fine.

Recommendation (not executed, small UI): Business's ADVANCED tier marker has no
"why" line, so it can read as difficulty-advanced like Crypto/Gov-Securities;
Grow's Go-deeper courses each carry a distinct note ("More technical. Not
higher risk." / "Optional. Higher risk, can lose value."). A one-line
situational note under Business ("For when you are starting or running a
business") would complete the three-distinct-reasons distinction.

## 9. Progress / completion UX

Per-path progress isolation is correct and was not touched. The finding
(recommendation, presentation only): the Learn header aggregates lessons and
courses across every path with no distinction, so a learner who has finished
the Core 22 plus Protect plus Grow's mainstream three still reads roughly
"60 of 93" and a two-thirds-empty bar because Business, Crypto, and Government
Securities are lumped in with foundational education. This makes someone who
finished everything meant for them feel half done. Recommendation: split the
header into a "Foundations" count (core plus the everyday courses) and a
quieter "Keep exploring" line for advanced/optional (derived from the existing
`isAdvancedPath` and `advancedGrowGroupIds` predicates), so finishing
foundations reads as near-complete and advanced stays an invitation. Do not
change progress or completion semantics; this is a header-framing change only.

Also recommended: surface the already-authored `recommendedPriorGroupIds` as a
muted "Recommended first: <course>" advisory on a course card in
`path_screen.dart` (it is modeled in data but rendered nowhere), so a learner
who taps straight into Stocks & Bonds sees the guide-not-lock pointer to Are
You Ready to Invest?.

## 10. Interaction inventory (Batch D source of truth)

Measured with a typed-block harness. 71 expansion lessons, about 300
interactions, about 30,000 interaction words. Core 22 carry at most one
interaction each (their KnowledgeCheck). Every one of the 71 lessons ends with
a KnowledgeCheck; every capstone lesson also carries a SalapifyActions block.

| Course | Lessons | Interactions | Interaction words |
|---|---|---|---|
| Insurance Decoded | 6 | 37 | 4,218 |
| SSS & PhilHealth | 6 | 24 | 2,306 |
| Pag-IBIG / MP2 / Housing | 6 | 25 | 2,448 |
| Investing Readiness | 5 | 19 | 1,837 |
| Stocks & Bonds | 6 | 28 | 2,745 |
| Deposits & Pooled Funds | 6 | 26 | 3,261 |
| PH Government Securities | 6 | 24 | 2,818 |
| Crypto | 6 | 29 | 3,289 |
| Start a Business Legally | 6 | 21 | 2,286 |
| BIR Registration & Local Permits | 6 | 19 | 1,564 |
| Taxes & Filing for Your Business | 6 | 18 | 1,491 |
| Business Permits & Compliance | 6 | 20 | 1,661 |

Insurance is the heaviest course; Business is the leanest (18 to 21 per
course) and, with SSS & PhilHealth, is the pacing model (2 to 4 interactions
plus a check is enough to teach a decision). MythOrFact and Scenario dominate.

Highest-load lessons: Insurance "Verify, Compare and Decide" (9 interactions,
1,130 words), Crypto "Custody and Irreversible Mistakes" (7, incl. four
Scenarios in a row), Deposits "Match the Product to the Goal" (7, 871),
Insurance "VUL" (7, 782), Business "Compare Business Structures" (5, 970 in one
heavy Compare), Gov-Sec "Risks and Scam Checks" (4, 908 across two adjacent
Categorize blocks).

## 11. Interaction fatigue findings (ranked for Batch D)

1. The "Red flag / Reasonable sign" 2-bucket Categorize is duplicated in five
   courses (stocks, deposits, gov-sec, crypto, insurance) with near-identical
   items. A learner who commits to the library sorts the same pattern five
   times; by the third the answer is memorized.
2. Crypto "Custody" fires four binary Scenarios back to back, each with a
   transparently naive wrong option, so discrimination is near zero.
3. Insurance "Verify, Compare and Decide" carries eight blocks at the
   course-completion celebration moment; the 4-item Checklist and the 10-item
   RiskReviewChecklist overlap.
4. Deposits "Match the Product to the Goal": the Comparison pre-answers the
   following Categorize; the mastery Scenario and the scam Categorize teach the
   same fixed-return fact twice.
5. Gov-Sec "Risks and Scam Checks": an 8-into-8 risk-name Categorize is a
   memory test, immediately followed by the 6-item red-flag sort.
6. Pag-IBIG "MP2 Without the Hype": four consecutive MythOrFact blocks, all
   answering "Myth," two of them teaching the same idea.
7. Lesson-ending free-text ReflectionPrompts that merely paraphrase the
   takeaway (several Grow lessons) read as skippable furniture.
8. Structural: every Grow and Protect course ends on its heaviest lesson, so
   the completion reward moment lands as the maximum tap-load, which is exactly
   backwards for starting the next course.

## 12. Batch D conversion map (recommended, NOT implemented)

Ranked, format course / lesson / interaction / classification / proposed type:

1. Five courses / duplicated Red-flag/Reasonable-sign sort / CONSOLIDATE: keep
   the richest single instance (crypto L5) as the canonical scam sort; convert
   the other four into one two-option Scenario applying the flags to that
   course's own product.
2. Crypto L3 Custody / four binary scenarios / CONVERT to one Categorize
   ("Recoverable or Permanent?").
3. Insurance L6 / eight blocks / CONSOLIDATE: merge the Checklist into the
   RiskReviewChecklist; collapse the three "What would you ask next?" scenarios
   into one. Target about 4 blocks.
4. Deposits L6 / Comparison + Categorize restate each other / CONVERT the sort
   into the completion of the comparison; drop one of the two duplicate
   fixed-return interactions.
5. Gov-Sec L5 / 8x8 risk-match / IMPROVE to a 4-bucket grouping.
6. Pag-IBIG L3 / four MythFacts / CONSOLIDATE the two that teach the same idea;
   library-wide, avoid clusters where every answer resolves the same way.
7. Insurance L4 VUL / guaranteed-vs-illustrated taught three ways / CONSOLIDATE,
   REMOVE the overlapping MythOrFact.
8. Stocks L5 / four required dense blocks incl. 5x5 risk-match / IMPROVE (make
   the risk-match optional or fewer buckets; keep the timeline Sort).
9. Grow path / lesson-ending free-text reflections that paraphrase the takeaway
   / REMOVE CANDIDATE (keep the ones that force a personal self-assessment).
10. Insurance L1 / two back-to-back non-required scenarios / CONSOLIDATE to one.

KEEP (do not touch): crypto L2 LossImpactSimulator, the ReadinessCard and
RiskReviewChecklist as course-payoff summaries, deposits L4 8-criteria fund
comparison, all SalapifyActions blocks.

## 13. Deep-link audit

Eight resolvable routes (goals, debts, budget, mindset, accounts, recurring,
notifications, salary); every authored SalapifyAction resolves, so no dead
buttons in shipped content. KEEP: the "clear expensive debt before investing"
debts link, the Emergency Fund goals link everywhere, the accounts
"record a holding by hand" link, the SSS take-home salary link. Recommendations
(Batch D content, plus a small resolver addition): the Taxes & Filing course
cannot reach the app's Tax calculator because `resolveExpansionActionRoute` has
no `tools-tax` entry (the core tax lesson already links it); SSS/Pag-IBIG could
offer the Contribution calculator (`tools-contrib`) as a more precise
destination than `salary`; the `notifications` action appears in about seven
courses but each admits no matching reminder exists yet. A maintenance note:
core uses `budget-tab` (a tab jump) while expansion uses `budget` (a pushed
screen) for the same concept; internally sensible, a divergence to watch.

## 14. Governance / freshness register (consolidated from C2 to C4)

Per the brief, verified claims were NOT re-searched; this consolidates the
recorded C2 to C4 verifications.

| Domain / course | Claim category | Authority | Verified | Freshness | Next review |
|---|---|---|---|---|---|
| Protect / Insurance | RA 11765 IRR, CL 2017-34 VUL guidelines title | Insurance Commission | 2026-08 (C2) | evergreen-ish | 2027-08 |
| Protect / SSS & PhilHealth | 8 source URLs, YAKAP is the current primary-care program (replaced Konsulta Jul 2025) | SSS, PhilHealth | 2026-08 (C2) | annual | 2027-02 |
| Protect / Pag-IBIG | 6 URLs incl. Virtual Pag-IBIG portal and calculator; MP2 | Pag-IBIG / HDMF | 2026-08 (C2) | annual | 2027-02 |
| Grow / Deposits | PDIC max coverage 1,000,000 pesos per depositor/bank, effective 2025-03-15 | PDIC | 2026-08 (C3) | high (Board can revise) | 2027-02 |
| Grow / Crypto | VASP registration, BSP Verifier, Circular 1108, Virtual Assets page; SEC advisories | BSP, SEC | 2026-08 (C3) | annual | 2027-02 |
| Grow / Stocks, Gov-Sec | PSE Academy concepts; SEC eRAMP; Bureau of Treasury GS mechanics; SEC Investment 101 | PSE, SEC, BTr | 2026-08 (C3) | evergreen | 2027-08 |
| Business / BIR | BIR-vs-local-permit order (corrected C5); Ease of Paying Taxes RA 11976; invoicing reform | BIR, LGU, RA 7160 | 2026-08 (C4), order re-ruled C5 | annual | 2027-02 |

Watch items carried forward: (a) SEC Investment 101 is cited via the
appointment-system mirror; canonical is www.sec.gov.ph, recommended for a
dedicated source pass. (b) The "Protect the Base First" sole-source citation to
SEC Investment 101 should be confirmed or co-sourced. Neither is a C5 defect.

## 15. Fable review

Rendered the Learn hub's path section dark and light and looked at it: the two
broadened Protect and Grow descriptions render cleanly and wrap without
overflow, and the path now advertises its whole span rather than course 1. Sent
to the founder. The check-card wording/heading change is in the fallback reader
and is covered by the reader widget test (semantic-label and layout checks
pass); the production paged reader was already correct.

## 16. Accessibility / offline

Learn is in good accessibility shape: consistent 48dp touch targets, non-color
meaning (selection by icon shape plus border plus tint plus words), live
regions on result surfaces, disclosure semantics on the Go-deeper expander and
reference footers, and reorder announcements in the Sorting view. C5 fixed the
one screen-reader heading gap (the fallback reader's check kicker). Two items
recommended, out of C5 scope: reduced-motion is not honored in the reader
(RiseIn and the paged reader animate regardless of "remove animations"); the
Learn-local slice is small, the full sweep is Phase 7. Offline: confirmed clean
with no blockers. Lesson content is const Dart, progress is local, all
interaction state is local widget state, and the only external thing (source
URLs) is shown as selectable text and shared via the OS sheet, never fetched.

## 17. Progress compatibility

No progress-affecting change was made. No path, course, group, or lesson id, no
progress key, no completion semantic, no backup or deep-link contract was
touched. The BIR SortingBlock fix reorders authored items within one existing
block (its blockId is unchanged), so completion state is unaffected. Existing
learners keep their progress and percentages.

## 18. Tests

Exact results: flutter analyze 0 issues. The affected suites pass, including
expansion_recommendation, learn_screen_recommendation, learn_screen_grow_path,
learn_screen_protect_path, lessons_bir_local_permits_content,
lessons_business_permits_compliance_content, and
expansion_lesson_reader_widget (132 tests). Two pinned assertions were updated
to match the corrected reason string and Protect description; no golden was
regenerated. Full suite result recorded on the delivering commit. No em/en
dashes in any edited file.

## 19. Batch D handoff (prioritized implementation plan)

Batch D owns the interaction redesign. Recommended order, by expected effect on
retention and by risk:

1. CONSOLIDATE the five-course duplicated scam sort into one canonical sort
   plus per-course applications (fixes fatigue that only the committed learner
   hits, the exact person not to burn out).
2. Thin the four course-completion "decision-lab" lessons (insurance L6,
   deposits L6, crypto L6, and the L3 custody scenarios) so the reward moment
   is not the heaviest lesson.
3. CONVERT the repeated-pattern clusters (crypto custody scenarios to one
   Categorize; Pag-IBIG MP2 four MythFacts to two).
4. IMPROVE the two memory-test matches (gov-sec 8x8, stocks 5x5).
5. Add the missing high-value deep links (Tax calculator to Taxes & Filing;
   Contribution calculator to SSS/Pag-IBIG) once the resolver gains the routes,
   and drop or replace the no-op `notifications` action.
6. Presentation product decisions to schedule alongside: the Foundations vs
   Keep-exploring header split, the "Recommended first" course-card advisory,
   the Business ADVANCED situational line, and the emergency-fund terminology
   standardization.
7. Deferred to Phase 7: the app-wide reduced-motion sweep.

Do not begin any of this in Batch D until these are re-scoped against fresh
measurement; the inventory in section 10 is the source of truth.
