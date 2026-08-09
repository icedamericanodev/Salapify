# Phase 6B, Batch C4: Advanced to Business content quality and compliance review

Scope: the four Business courses only. C5, Batch D, Phase 7, and Phase 8 were
NOT started. This is a review-and-return deliverable; the correctness fixes it
describes are applied on this branch but gated on founder approval before any
merge, because they touch regulated tax content.

Courses in scope (course id, file):

1. Start Your Business Legally (`start_a_business_legally`,
   `lessons_business_registration.dart`)
2. BIR Registration and Local Permits (`bir_registration_and_local_permits`,
   `lessons_bir_local_permits.dart`)
3. BIR Setup for New Businesses (`bir_registration_tax_setup`,
   `lessons_bir_tax_setup.dart`)
4. Permits, People, and Compliance (`business_permits_and_compliance`,
   `lessons_business_permits_compliance.dart`)

The C1 architecture is preserved: these stay ADVANCED to BUSINESS, discoverable
but not competing with core financial-literacy content. No path, course, group,
lesson, or progress id was changed.

---

## 0. Headline

The measurement said what C2 and C3 already taught: source length is not the
problem here. These four courses are journey-oriented, decision-first, heavily
interactive, careful about geographic variability, disciplined about volatile
figures, and clean on the education-versus-advice boundary. They do NOT read
like a government manual. So this was a precision-and-accuracy pass, not a
shortening pass, and the word count was deliberately not reduced for its own
sake.

The real finds were three correctness defects, all ID-safe, all fixed:

1. The two lessons that teach the BIR-versus-local-permit ORDER contradicted
   each other, in one path a learner takes back to back.
2. One BIR invoicing claim misstated the actual Ease of Paying Taxes reform.
3. One procedural window ("about 30 days from the COR") could not be verified.

Plus one structural recommendation held for founder approval: the two BIR
courses have confusingly similar names.

---

## 1. Business Before vs After

Before: four shipped courses (Phases 13 to 15), 24 lessons, high quality, with
two latent correctness defects (an ordering contradiction between C2 and C4, and
a misstated BIR invoicing reform) and one unverifiable procedural figure.

After: same 24 lessons, same ids, same interactions, same structure. Three
ID-safe correctness fixes applied to C2 (two lessons) and C4 (one lesson). Every
verified figure left exactly as it was. No lesson shortened for a metric.

---

## 2. All 24 Lesson Classifications

Legend: KEEP (correct and well-shaped, no change), ENHANCE (kept, with a
targeted correctness or clarity fix this batch).

Course 1, Start Your Business Legally:
- Before You Register: KEEP
- Compare Business Structures: KEEP
- Match the Structure to the Agency: KEEP
- Business Name Is Not the Whole Brand: KEEP
- Registration Is Not Permission to Operate: KEEP
- Build Your Registration Roadmap: KEEP

Course 2, BIR Registration and Local Permits:
- The Order That Actually Matters: ENHANCE (ordering claim corrected)
- Get Your TIN and Certificate of Registration: KEEP (figures verified correct)
- Books, Receipts, and Invoices: ENHANCE (ATP claim + 30-day window corrected)
- Barangay Clearance and the Mayor's Permit: KEEP
- Micro, Small, or Something Else: KEEP
- Build Your Compliance Calendar: KEEP

Course 3, BIR Setup for New Businesses:
- Start With Your BIR Profile: KEEP
- Primary and Secondary Registration: KEEP
- Know What You Registered For: KEEP
- Invoices, Books, and Proof: KEEP
- Build a Filing Routine: KEEP
- Create Your Tax Money System: KEEP

Course 4, Permits, People, and Compliance:
- Your Location Changes the Checklist: KEEP
- Map the Local Permit Flow: ENHANCE (ordering claim corrected to match C2)
- Renewals and Ongoing Local Compliance: KEEP
- When You Hire People: KEEP
- Check for Industry-Specific Regulators: KEEP
- Build Your Compliance Map: KEEP

No lesson was classified SIMPLIFY, RESTRUCTURE, MERGE, or REMOVE on its own
merits. The only MERGE/RESTRUCTURE candidate is the course-level architecture
question in section 4, held for approval.

---

## 3. Content Metrics

Measured with a typed-block harness against the real source
(`scratchpad/measure.py`). Words are approximate; the point is shape, not a
precise count.

Per-lesson prose / interaction / reference split (words), interactions,
time-sensitive figure markers:

Course 1 (Start Your Business Legally):
- Before You Register: prose ~289, interaction ~214, 3 interactions, 0 markers
- Compare Business Structures: prose ~325, interaction ~1078, 5 interactions, 0
  markers (the densest lesson, driven by a 5-structure x 8-criterion comparison
  table, i.e. interaction density, not prose)
- Match the Structure to the Agency: prose ~303, interaction ~378, 0 markers
- Business Name Is Not the Whole Brand: prose ~342, interaction ~227, 0 markers
- Registration Is Not Permission to Operate: prose ~381, interaction ~240, 2
- Build Your Registration Roadmap: prose ~302, interaction ~423, 0 markers

Course 2 (BIR Registration and Local Permits):
- The Order That Actually Matters: prose ~390, interaction ~197, 0 markers
- Get Your TIN and COR: prose ~435, interaction ~420, 34 markers (the figure
  lesson)
- Books, Receipts, and Invoices: prose ~412, interaction ~243, 14 markers
- Barangay Clearance and the Mayor's Permit: prose ~409, interaction ~253, 0
- Micro, Small, or Something Else: prose ~314, interaction ~239, 5 markers
- Build Your Compliance Calendar: prose ~302, interaction ~372, 3 markers

Course 3 (BIR Setup for New Businesses): prose ~296 to 390 per lesson,
interaction ~174 to 397, time-sensitive markers 0 on four of six lessons (this
course deliberately states no figure and points at the source).

Course 4 (Permits, People, and Compliance): prose ~297 to 405 per lesson,
interaction ~203 to 383, time-sensitive markers 0 on every lesson (this course
deliberately states no figure at all).

Reference layer: reference here is the inline OfficialSourceBlock citations and
the EducationalBoundaryBlock, which are short (an agency, a title, a URL, a
verified date), NOT a separate dense table layer. That is the correct C1
treatment: reference stays within the course as progressive disclosure, never a
new top-level category.

Longest single uninterrupted paragraph, per course: C1 75 words, C2 81, C3 72,
C4 91. Nothing approaches a wall of text; every prose block is broken by a
nuggets list, a diagram, or a risk warning before the interactions begin.

Reading time: every lesson declares 3 or 4 minutes, consistent with the prose
measured.

Interpretation: interaction words meet or exceed prose words in most lessons.
These are exercise-led lessons, not prose dumps. Reducing prose would regress
test-guarded, verified content against the founder's standing "enhance, never
regress" rule.

---

## 4. Four-Course Architecture Review (especially the two BIR courses)

Each course has a genuinely distinct learner outcome:

- C1: decide what legal structure to form and which agency registers it, before
  filing anything.
- C2: walk the concrete post-name steps (TIN, Certificate of Registration, books
  and invoices, barangay clearance, Mayor's Permit), with current national
  figures stated plainly.
- C3: understand what ongoing tax obligations a BIR registration carries, and
  build a filing and tax-money routine, with no figures stated.
- C4: handle the location-, employer-, and industry-specific compliance the
  earlier courses deliberately left open.

Are the two BIR courses meaningfully distinct? YES. C2 is "get registered"
(concrete, figure-bearing, includes local permits). C3 is "run your taxes"
(conceptual obligations plus an ongoing routine, deliberately figure-free). They
are not duplicates and should not be merged.

The problem is packaging, not outcomes:
- Both course titles lead with "BIR", so a beginner cannot tell which comes
  first or what each delivers. Worse, "BIR **Setup** for New Businesses" (C3)
  describes what C2 actually does; C3 is really about obligations and filing, not
  setup. The label points the learner at the wrong course.
- The registration mechanics (BIR is separate from DTI/SEC/CDA, one TIN, the COR,
  ORUS) are taught fresh in both C2 (concretely) and C3 (as an abstract map),
  rather than C3 recapping C2.

Recommendation (held for founder approval, NOT applied, per the preserve-ids
rule): rename C3 so it stops colliding with C2 and names its real job, for
example "Run Your BIR Taxes" or "BIR Taxes and Filing Routine." The group id
`bir_registration_tax_setup` stays; only display title strings change. This is
the single highest clarity-per-hour move. Do NOT merge the two courses.

---

## 5. Business Structure

C1 Lesson 2 (Compare Business Structures) covers sole proprietorship,
partnership, One Person Corporation, corporation with multiple owners, and
cooperative, across ownership, legal personality, liability, governance,
continuity, recordkeeping, funding, and registration agency. It is
decision-oriented (a comparison table plus two scenario exercises and a myth
buster), explicitly never names one structure as best/cheapest/safest/easiest,
and repeatedly points to professional advice. This is the correct treatment:
practical differences for a beginner, not legal advice, no universal winner.
KEEP as-is.

---

## 6. Registration Journey

The path teaches the journey, not the agency org chart: clarify the idea →
compare structures → match structure to agency → name vs trademark →
registration is not permission → roadmap (C1), then order → TIN/COR → books →
local permits → taxpayer size → compliance calendar (C2), then obligations and
a filing routine (C3), then location/employer/industry compliance (C4). The
learner is told WHY each step exists before the detail. This matches the target
journey in the brief and is preserved.

One journey defect was found and fixed: the BIR-versus-local-permit ordering was
taught two opposite ways (see sections 7 and 13).

---

## 7. BIR

Every BIR statement was audited (tax-professional SME plus my own WebSearches).
Classification of each as stable concept vs volatile figure, and the verdict:

Stable concepts (correct, KEEP): BIR is a separate registration from
DTI/SEC/CDA; one TIN per person; the Certificate of Registration (Form 2303);
books of accounts come in manual, loose-leaf, computerized; primary vs secondary
registration; filing and paying are separate actions; a return can be due even
when no payment is; obligation categories (income tax, VAT or other business
tax, withholding, employer). All correct.

Volatile figures STATED (only in C2, verified CORRECT, left untouched):
- 500 Annual Registration Fee abolished, effective 2024-01-22 (RA 11976).
- Documentary Stamp Tax ~30 on the COR (Sec 188 NIRC).
- Invoice/receipt issuance threshold raised 100 to 500 (RR 7-2024), VAT sellers
  issue for every sale regardless.
- Forms 1901 (self-employed/professional/mixed), 1902 (employee TIN/compensation),
  1903 (corporation/partnership), COR = 2303.
- Taxpayer classification micro/small/medium/large by gross sales (RR 8-2024);
  the lesson deliberately does not state the peso thresholds, which is correct.

Volatile figures DELIBERATELY NOT STATED (correct discipline): income tax rates,
the 8% option, the Section 116 percentage tax, the 12% VAT rate, and specific
deadlines. Not stating these is the safe choice, and notably avoids the common
stale trap of quoting the temporary 1% percentage tax that expired mid-2023.

Two BIR claims were WRONG or unverifiable and were CORRECTED:
- "Authority to Print used to carry its own fee" (C2 L3): the ATP application
  was already free; the actual EOPT reform was the shift to the invoice as the
  single primary document and the removal of the old five-year validity on
  printed receipts and invoices (RR 7-2024). Corrected to the real reform.
- "About 30 days from the COR to have invoices ready" (C2 L3): no clean national
  rule anchors that specific window; the real obligation is that a business must
  be able to issue an invoice before it starts selling. Softened to that.

---

## 8. Local Permits

C2 Lesson 4 and all of C4 handle local permits carefully and correctly: they
teach that barangay clearance and the Business Permit carry NO nationwide fee
because each of the country's cities and municipalities sets its own, they never
state a peso figure for either, and they route the learner to check directly
with the local BPLO and barangay. C4 Lesson 1 explicitly teaches that the
checklist changes with location, activity, setup, and hiring. This is the "typical
process versus verify with your LGU" split the brief asks for, done well. KEEP.

---

## 9. Employer / Compliance

C4 Lesson 4 (When You Hire People) correctly separates "starting a business"
from "becoming an employer," names SSS, PhilHealth, Pag-IBIG, employee reporting,
payroll records, labor standards, and workplace safety, never calculates a
contribution, and never classifies a real worker (employee/contractor/intern/
partner). It uses progressive disclosure: the employer complexity appears only in
C4, not forced into the C1 startup journey. C4 Lesson 5 handles industry
regulators with three verified examples (FDA, PCAB, DOT) and a neutral fallback
for everything else. Both KEEP.

---

## 10. Risk of Geographic Variability

Where LGU-specific differences matter, the content already flags them well:
- Barangay clearance and Business Permit fees: set locally, no nationwide figure
  (C2 L4, C4 L1 to L3). Handled correctly, never presented as universal.
- The local-permit checklist: varies by city, activity, setup, hiring (C4 L1).
- The BIR-versus-local-permit ORDER: genuinely varies by LGU and Revenue District
  Office. This was the one place the content over-asserted a fixed order (and
  did so two opposite ways). Now corrected to the varies-by-LGU-and-RDO framing
  in both C2 L1 and C4 L2.

No single LGU's process is presented as universal anywhere.

---

## 11. Claims Verification Register

For each changed or time-sensitive claim: authority, applicable date,
verification date (2026-08), result. All confirmed via independent WebSearch.

| Claim | Authority | Effective | Verified | Result |
|---|---|---|---|---|
| 500 Annual Registration Fee abolished | RA 11976 (EOPT), amending Sec 236 NIRC | 2024-01-22 | 2026-08 | CORRECT, kept |
| Invoice/receipt threshold 100 to 500 (VAT sellers every sale) | RR 7-2024 under RA 11976, Sec 237 NIRC | 2024 | 2026-08 | CORRECT, kept |
| Documentary Stamp Tax ~30 on the COR | Sec 188 NIRC (as amended by TRAIN RA 10963) | current | 2026-08 | CORRECT, kept |
| Forms 1901 / 1902 / 1903, COR = 2303 | BIR forms directory | current | 2026-08 | CORRECT, kept |
| Taxpayer classes micro/small/medium/large by gross sales | RA 11976 Sec 21, RR 8-2024 | 2024 | 2026-08 | CORRECT, kept (thresholds deliberately not stated) |
| COR is now a permanent document, no annual renewal | RA 11976 / RMC 60-2024 | 2024 | 2026-08 | CORRECT, consistent with lessons |
| Printed receipts/invoices no longer carry the old 5-year validity | RR 7-2024 (and RR 6-2022) | 2024 | 2026-08 | CORRECT, this is the NEW wording that replaced the wrong ATP claim |
| Invoice is now the single primary document for most sales | RA 11976 / RR 7-2024 | 2024 | 2026-08 | CORRECT, added to C2 L3 |
| eBOSS mandate (ARTA-DTI-DILG-DICT JMC 01 s.2021) | ARTA MC 2021-02 | 2021 | 2026-08 | CORRECT, source URL confirmed |
| "Authority to Print used to carry its own fee" | none | n/a | 2026-08 | WRONG, REMOVED |
| "About 30 days from the COR to have invoices ready" | none clean | n/a | 2026-08 | UNVERIFIABLE, SOFTENED to "before the first sale" |

Official-source URLs: all 24 distinct government canonicalUrls across the four
files were independently WebSearched (gov.ph WebFetch returns a uniform 403 in
this environment, so search is the only channel that can tell a real URL from a
fabricated one). All 24 CONFIRMED as real, topically correct official pages.
None unconfirmed, none contradicted, including the ARTA eBOSS PDF, the SEC
eSPARC selection page, the BIR NewBizReg and ORUS portals, and the SSS,
PhilHealth, FDA, PCAB, and DOT pages.

---

## 12. Unverified / Ambiguous Claims

Not silently retained. The only two ambiguous items were the ATP-fee claim and
the 30-day window; both were corrected rather than kept (section 7). One minor
cosmetic note left as-is: the ORUS portal is cited as `orus.bir.gov.ph/` in C2
and `orus.bir.gov.ph/home` in C3; both resolve to the same official portal, so
this is a tidiness note, not a defect.

---

## 13. Redundancy Findings

| Topic | Where taught | Verdict |
|---|---|---|
| Structure choice | C1 L2, L3 | Single home, good |
| Agency matching (DTI/SEC/CDA) | C1 L3; light echoes C1 L4, C2 L1, C4 L2 | Reinforcement |
| Name vs trademark | C1 L4 | Single home, good |
| Registration is not permission to operate | C1 L5; C4 L2 restates | Mild duplication |
| Full step-order sequence diagram | C1 L5, C2 L1, C4 L2 | Triple overlap, and the C2/C4 CONTRADICTION (now fixed) |
| BIR registration / TIN / COR | C2 L2 (concrete); C3 L1, L2 (abstract map) | Genuine duplication, different depth |
| BIR separate from DTI/SEC/CDA | C2 L1, C3 L1 | Duplication |
| ORUS / registration channels | C2 L2; C3 L2 (adds NewBizReg, anti-scam) | Duplication, C3 adds value |
| Books + invoices | C2 L3 (setup, figures); C3 L4 (record discipline) | Reinforcement, different angle |
| Taxpayer size classification | C2 L5 | Single home, good |
| Tax obligation categories | C3 L3 | Single home, good |
| Filing routine, file vs pay | C3 L5 | Single home, good |
| Barangay + Business Permit | C2 L4; C4 L1 to L3 | Genuine duplication (belongs in C4) |
| "No nationwide permit fee" | C2 L4; C4 L1/L2/L3 | Same point repeated |
| Renewals / ongoing local compliance | C2 L6; C4 L3, L6 | Duplication |
| Employer registration | C4 L4 deep; named-only C1 L5, C3 L1, C3 L3 | Single deep home, good |
| Industry regulators | C4 L5 deep; named C1 L5/L6 | Single deep home, good |
| Compliance capstone + SalapifyActions | C1 L6, C2 L6, C3 L6, C4 L6 | Four near-identical, acceptable deliberate pattern |

The four capstone lessons are a deliberate per-course pattern; do NOT dedupe
them (near-zero payoff, real risk of regressing four shipped SalapifyActions
flows). The books/invoices pair is legitimate reinforcement (setup vs
discipline), not duplication. The genuine duplication (registration mechanics in
both BIR courses, local permits in both C2 and C4) is a structural item held for
approval in section 15.

---

## 14. Reference Treatment

C1 principle preserved: reference is within the course, not a new top-level
category. Citations render as a collapsed OfficialSourceBlock at the end of each
lesson; the educational boundary and risk warnings are short blocks, not walls.
Nothing necessary for the learner's immediate decision was hidden. No change.

---

## 15. Batch D Candidates (recorded, NOT built)

- C2 L1 / C4 L2: the two step-order sorting exercises still teach one fixed order
  each while the prose now says the order varies; a future interaction redesign
  could make the sorting itself express the LGU variance (or fold the two
  diagrams into one canonical order).
- Procedural checklist exercises that read like paperwork (the several readiness
  ChecklistBlocks) are candidates for conversion to decision scenarios.
- A "which agency does what" quick-reference and a compliance-cost mini-calculator
  are deep-link/interaction opportunities.
- STRUCTURAL, needs founder approval: rename C3 to stop the "BIR Setup" collision
  with C2; consider moving local-permit lessons out of C2 into C4 so C2 = BIR
  only and C4 = all local/permit/employer/industry; add explicit recap
  cross-references from C3 L1/L2 back to C2, and a forward pointer from C2 L4 to
  C4. None of these were performed (they change course membership or labeling).

---

## 16. Progress Compatibility

No path id, course/group id, lesson id, interaction blockId, progress key,
completion semantic, backup contract, or deep-link contract was changed. The
`authority-to-print-costs-myth` blockId is preserved even though its text was
corrected. The `thirty-day-window` checklist item id is preserved. The C2 and C4
content tests (including the ordering test, the ₱500/₱100 pins, and the isolation
checks) all pass. Existing learner progress is unaffected.

---

## 17. Fable / Accessibility / Offline

Rendered the three edited reading pages (C2 "The Order That Actually Matters",
C2 "Books, Receipts, and Invoices", C4 "Map the Local Permit Flow") in Fable,
dark and light, on the lived-in fixture, and looked at them (dark first). All
three read clean: no overflow, no clipping, the ₱100/₱500 figures render
correctly, and the reworded prose flows naturally. Screenshots surfaced to the
founder in chat, dark first.

Accessibility and offline: unchanged. The lessons remain readable offline;
external official sources require internet only for the optional deep link, and
the lesson itself teaches the concept without it. Large-text behavior is covered
by the existing readiness and readability suites, which stayed green.

---

## 18. Tests (exact results)

- `flutter analyze` on the changed files: No issues found.
- `lessons_bir_local_permits_content_test.dart`,
  `lessons_business_permits_compliance_content_test.dart`,
  `update_stamp_test.dart`, `lesson_governance_test.dart`: all pass (119 tests).
- Full suite: 2,849 passing; the only red before the qa row was added was
  `qa_record_test.dart` (the intended pre-row gate), now satisfied.
- Fable render harness (`screens_shot.dart --update-goldens`): all pass, three
  new reading-page shots produced.
- Break-then-prove: not claimed. No new alarm or guard was added this batch; the
  changes are content corrections proven by the existing content tests staying
  green (the ordering test still locks C4's BIR-after order) and by the render.

---

## 19. C5 Handoff (cross-course issues, NOT started)

- The two BIR courses' naming collision and the local-permit duplication between
  C2 and C4 are cross-course structural issues that a C5 or a founder-approved
  restructure should resolve; recommendations are in sections 4 and 15.
- The step-order interaction redesign (sorting exercises that express LGU
  variance) is a cross-course Batch D item.
- The capstone SalapifyActions pattern is shared across all four courses and any
  future change to it should be made once, consistently, across all four.

C5 was NOT started.
