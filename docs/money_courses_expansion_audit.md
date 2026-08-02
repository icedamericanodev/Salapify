# Money Courses expansion audit

Audit only. No Flutter code or course content was changed. Written before
adding the three new paths (Grow Your Money, Protect Your Future, Build Your
Business) so the work lands on what exists instead of beside it.

## 1. Current architecture

Four course tracks, 22 lessons, defined as plain `const` maps in
`lib/content/lessons.dart` (cushion 6, debt 6, swing 5, moments 5). A track is
`{'key', 'icon', 'title', 'outcome'}`; a lesson is a big authoring map (id,
track, title, icon, minutes, summary, objective, region, action, blocks,
body, check, takeaway, factCheckedOn, sourceNotes). `lessonFromMap` in
`lib/content/lesson_model.dart` converts one map into a typed `MoneyLesson`
at the point of use; the raw maps are never typed at rest.

The reader screen is `LearnScreen` in `lib/screens/learn.dart` (also called
"Money courses" in the UI). It builds four collapsible track cards from
`courseTracks`, each showing a progress bar folded from
`lib/money/course_plan.dart:trackProgress`, and opens lessons in a private
`_LessonReader` that walks `MoneyLesson.blocks` and renders one widget per
block via `lib/widgets/lesson_block_views.dart:viewForBlock`. A second entry
point, `MindsetScreen` (`lib/screens/mindset.dart`), shows "Today's lesson"
(`lessonOfTheDay`, a day-of-year rotation over the full flat `lessons` list)
and links into `LearnScreen`.

Progress is a three-file, pure/tested stack: `lib/money/lesson_progress.dart`
holds the five-state enum (`notStarted → viewed → understood → completed →
applied`, never-demote, `isDone` = completed or applied), `course_plan.dart`
folds per-track stats and picks ONE recommended track from real transaction
and debt data, and `lib/money/lesson_insight.dart` writes the personalized
opening line. All three are pure Dart with no Flutter import, keyed only by
opaque lesson id strings and a `trackId` string, not by any fixed list of 22
ids. `lib/data/store.dart` (~1640-1710) is the only place that touches
storage: `settings.lessonProgress` (`{id: {'state': ...}}`) is the current
model, `settings.lessonsRead` (a flat id list) is the pre-existing legacy key
kept alive and merged in (never demoting a legacy `completed`).

## 2. IDs, ordering, progress calculation

- Lesson `id` and track `key` are free-form strings, unique by convention
  only; nothing enforces uniqueness except that a duplicate id would silently
  merge two lessons' progress.
- Order is array order. `courseTracks` fixes the four card order (cushion,
  debt, swing, moments); `lessonsForTrack(key)` filters `lessons` by
  `track == key` in file order. There is no numeric `order` field.
- `LearnScreen`'s header stat ("X of 22 lessons", the top progress bar) is
  computed as `lessons.where(isDone).length` over `total = lessons.length`,
  i.e. every lesson in the ONE flat `lessons` const, not scoped per track.
  **This is the load-bearing fact for the expansion**: any new lesson added
  to that same list changes "22" and the top bar, whatever track it is filed
  under.
- `recommendedTrack()` (`course_plan.dart`) only ever returns one of
  `'debt' | 'moments' | 'swing' | 'cushion'`; it is specific to the core four
  and is not a generic "pick a track" function.

## 3. Lesson block types available today

Sealed in `lib/content/lesson_blocks.dart`, one Dart class + one Flutter view
each (`lib/widgets/lesson_block_views.dart`), dispatched by an exhaustive
`switch` in `viewForBlock` (new kind = compile error until it has a view):

| Block | Shape | Renders as |
|---|---|---|
| `ProseBlock` | heading + paragraphs | connective prose |
| `NuggetsBlock` | list of one-liners | one idea per card |
| `DiscoveryBlock` | question + reveal | tap-to-reveal, marks "understood" |
| `StoryBlock` | who + text | one short persona anecdote |
| `DiagramBlock` | ordered steps + caption | a flow, not an image |
| `TrapBlock` | mostPeople + worksBetter | common mistake, non-judgmental |
| `ChallengeBlock` | prompt + compare | a one-minute in-app thing to try |
| `RulesBlock` | list of passages | verbatim CPA-reviewed text, one card each |
| `ReflectionBlock` | one line | always last, the takeaway |

Outside the block list, at the `MoneyLesson` level: one `KnowledgeCheck`
(question, exactly 3 choices, single correct index, explanation, optional
`whyWrong`) and one `LessonAction` (label + route string). Both are
singular, at most one per lesson.

## 4. Quiz and interaction support

- Single-choice only, exactly 3 options, one per lesson, rendered after all
  blocks and before the action button. No per-lesson pass/fail threshold, no
  scoring, no multi-question quiz.
- No multiple-choice, sorting/matching, or "quick assessment" support at all.
- `DiscoveryBlock` is the only other graded-feeling interaction (tap to
  reveal), and it is what currently earns the `understood` progress rung
  along with answering the check.
- `LessonAction` is a closed set: `_resolveAction`'s switch in `learn.dart`
  hardcodes every valid route string (`log`, `mindset`, `recurring`,
  `goals`, `debts`, `paluwagan`, `cashflow`, `notes`, `tools-bnpl`,
  `tools-tax`, `tools-contrib`, `tools-thirteenth`, `tools-salary`, plus
  three tab jumps). A route not in that switch silently renders no button
  (fails safe, but silently).

## 5. Offline progress storage format

`settings.lessonProgress = {'<lessonId>': {'state': 'completed'}}` plus the
legacy `settings.lessonsRead = ['<lessonId>', ...]`. Both are read together
by `parseLessonProgress` (legacy first, new overrides, never the lower of
the two), and both are written together by `store.setLessonState` (~line
1647). Fully on-device, `AsyncStorage`-equivalent (Flutter's own local store
under the app's existing single-blob-per-save model), no network.

## 6. Backup compatibility

`lib/data/backup.dart` (`schemaVersion = 12`) builds the exported `settings`
object as `{...settings, <overrides>}` (line ~490): almost every settings key,
including `lessonProgress` and `lessonsRead`, passes through **unmodified by
generic spread**, not by an explicit allowlist entry. Neither key is
special-cased anywhere in backup.dart today (confirmed by search: zero
matches). That is convenient (a new key needs no code change to survive a
backup) and also a small existing gap: unlike every other listed field,
lesson progress is never validated or clamped on restore, it is trusted
verbatim.

Two committed backup goldens (`test/backup_golden_test.dart`,
`test/backup_export_golden_test.dart`, comparing against
`test/goldens/backup_goldens.json` / `backup_export_goldens.json`) assert an
exact key set for RN-generated fixtures. `backup.dart`'s own comments call
this "the golden key-set contract" and describe the pattern already used to
protect it: several Flutter-only keys (`paluwagans`, `steadyPay`,
`displayName`, `quickAddsEdited`, `manualRates`) are emitted **conditionally**
(only when real data exists) specifically so old RN fixtures never gain a key
they never had. Any new top-level settings key for expansion-path progress
must follow the same conditional-emit pattern or the goldens need a
deliberate, reviewed regeneration.

## 7. Deep-link / action handling today

There is no URL-scheme or platform deep link into a lesson. Two internal
mechanisms exist:

- `LearnScreen(focusId: ...)` opens a specific lesson on push via
  `lessonById(id)` + a post-frame callback. Currently wired from exactly one
  caller pattern (`search.dart`'s generic `focusId` convenience for other
  screens); the doc comment says "e.g. from a coach nudge" but the coach
  layer (`lib/money/coach.dart`, kind `'lesson'`) is not actually wired to
  pass a `focusId` anywhere in `overview.dart` today
  (`overview.dart:533`: "`/learn` is simply not tappable from here"). Treat
  `focusId` as a real, tested mechanism with one live caller, not as an
  unused one.
- `LessonAction.route` is the closed-switch mechanism in section 4 above,
  one action per lesson, resolved only inside `learn.dart`.

`lessonById` and `lessonsForTrack` both search the single flat `lessons`
list; there is no per-catalog lookup today because there is only one
catalog.

## 8. Relevant existing agents and model assignments

None of the 29 agents in `.claude/agents` declare a `model:` field in
frontmatter, so every one inherits the session's model; there is no existing
per-agent model routing to preserve or break.

Closest fits for the three requested review roles:

- **Course Experience Reviewer** -> `flutter-ux-craftsman`. Already scoped to
  "review Flutter screens for usability, visual polish, spacing and
  hierarchy, motion, and accessibility" and explicitly "reads the actual
  screen code in flutter/lib." `learn.dart` and `lesson_block_views.dart` are
  exactly its territory. No new agent needed.
- **Philippine Policy Reviewer** -> closest is `legal-compliance-counsel`
  (data privacy, consumer protection, **app store policy**, advertising law,
  "keeps Salapify out of the loan app crackdown"), with `tax-professional`
  already owning PH tax-specific accuracy. Neither is scoped to SEC
  investment-suitability rules or DTI/SEC/BIR business-registration accuracy,
  which "Grow Your Money" and "Build Your Business" will need. Gap, but
  narrow: see section 11.
- **Investment Content Reviewer** -> no existing agent covers investment
  products/securities specifically. `financial-coach` is the nearest
  (general Filipino personal-finance soundness, "whether advice or formulas
  in the app are sound") but is explicitly general, not
  investment/securities-regulatory. Real gap: see section 11.

## 9. Smallest safe extension points

1. **Do not touch `lessons`, `courseTracks`, or anything that reads
   `lessons.length`.** Add each new path as its own const list in its own
   content file (e.g. `lib/content/lessons_grow.dart`, `..._protect.dart`,
   `..._business.dart`), each with its own `List<Map>` tracks and lessons,
   reusing the existing `lessonFromMap` / `trackFromMap` / `LessonBlock`
   machinery unchanged (it is already generic over any map).
2. **Give each new path its own progress key** under `settings`, e.g.
   `settings.expansionProgress = {'<catalogId>': {'<lessonId>': {'state':
   ...}}}` (or one flat key per catalog). Reuse `LessonState`,
   `parseLessonProgress`, `withLessonState`, `trackProgress`,
   `learnedCount`, `nextLessonId` as-is; they are already generic over any
   id-keyed map and any track-id string. This satisfies "new paths need
   separate progress" at the storage layer, not just the UI layer, so a bug
   in the new paths' write path can never corrupt the core 22's numbers.
3. **`_LessonReader` needs to stop being private.** It is currently a
   `_`-prefixed `State` class local to `learn.dart`. Either promote it to a
   public, reusable widget parameterized by its progress-write callback (it
   already takes `onState` and `onAction` as callbacks, so this is close to
   free), or accept one small duplicated reader per new screen. Promoting it
   once is cheaper than duplicating the ~300-line reader three times.
4. **`recommendedTrack()` stays untouched**; it is core-specific by design
   (urgency ordering over debt/lump-sum/irregular-income/default) and the
   new paths do not need a recommendation engine to launch.
5. **`lessonInsight()` falls through safely** for an unrecognized `trackId`
   (grow/protect/business) straight to its generic, data-driven lines; no
   change required to ship, though track-specific insight lines are a
   reasonable Phase 2 follow-up.
6. **New `LessonAction` routes** need new `case` arms in
   `_resolveAction`'s switch (or its promoted equivalent). No structural
   change, just enumeration.
7. **New track icons** (whatever "Grow Your Money" etc. use) need entries in
   `lib/widgets/salapify_icon.dart`'s `_icons` map; the existing content test
   that every icon name resolves already catches a typo before it reaches a
   phone.

## 10. Tests that protect current behavior

| File | Protects |
|---|---|
| `test/lesson_progress_test.dart` | state ranking, never-demote, legacy merge |
| `test/course_plan_test.dart` | per-track fold, recommendation urgency order |
| `test/lesson_insight_test.dart` | personalized line selection, no invented facts |
| `test/lessons_content_test.dart` | house rules: no em/en dash (blocks included), presumably PH region scoping |
| `test/lessons_golden_test.dart` | lessons content regenerates deterministically from `lessons.dart` |
| `test/learn_screen_test.dart` | the Learn screen itself |
| `test/screen_readability_test.dart` | overflow/blank/ellipsis sweep, includes Learn |
| `test/backup_golden_test.dart`, `test/backup_export_golden_test.dart` | exact settings key set on restore/export |
| `test/palette_contrast_test.dart` | WCAG AA per palette (any new lesson-only color needs to clear this too) |

None of these currently assert the "no product, investment, loan, or stock
recommendations" house rule stated in `lessons.dart`'s own header comment; it
is enforced by review only, not by a test. This matters more once
"Grow Your Money" exists.

## 11. Gaps

- **No renderable source/citation block.** `MoneyLesson.sourceNotes` exists
  today but is explicitly documented as "Developer-facing only, never
  rendered." The task's required regulated-lesson metadata (source agency,
  source title, canonical URL, effective date, last verified date,
  review-due date, stable/time-sensitive classification, content version,
  review status) does not exist anywhere on the model. Only a loose
  `factCheckedOn` string and a binary `region` (global/PH) exist, and
  `isTimeSensitive` is *derived* from region (`== isPhilippines`), not an
  independent field — it cannot express "this Grow Your Money lesson is
  time-sensitive but not PH-only."
- **No risk-warning block.** The one warning-shaped UI today
  (`_scopeNote`/`_phTag` in `learn.dart`) is a hardcoded fixed string gated
  purely on `region == philippines`. It is not authorable content and not
  reusable for an investment-risk disclaimer that isn't a PH-tax scope note.
- **No multi-question, multiple-choice, or sorting/matching interaction.**
  `KnowledgeCheck` is singular, single-choice, three options only.
- **No calculator/simulator block.** The app already has five standalone
  calculator screens reachable only via `LessonAction` (a full-screen jump,
  not an inline block); there is no lighter-weight inline calculator/preview
  block type.
- **No checklist block.** `NuggetsBlock` is display-only, not checkable.
- **No comparison-cards block.** Nothing currently lays out two or more
  options side by side; `TrapBlock` is a fixed two-slot "most people /
  works better" shape, not a general comparison.
- **Investment-content house rule is unenforced by tooling** (see section 10).
- **No agent owns investment-suitability or securities-regulatory review**
  (section 8).
- **`focusId` deep-link is a thin, single-caller mechanism**, not a general
  deep-link system; fine to extend per-catalog but do not assume it is more
  battle-tested than it is.

## 12. Recommended data-model changes (not yet implemented)

All additive, none change the 22 core lessons' shape:

1. On `MoneyLesson` (or a small `SourceInfo` value object attached to it):
   `sourceAgency`, `sourceTitle`, `sourceUrl`, `effectiveDate`,
   `lastVerifiedDate`, `reviewDueDate`, `contentVersion`, `reviewStatus`
   (enum: draft/reviewed/needsUpdate, or similar), and a `classification`
   enum (`stable | timeSensitive`) independent of `region`. Keep
   `factCheckedOn` as a display-string alias or fold it into
   `lastVerifiedDate` during the port, do not carry two overlapping fields.
2. A new renderable `SourceBlock` (or promote `sourceNotes` from
   developer-only to an optional renderable "Official source" card) for the
   "official source information" requirement.
3. A new `RiskWarningBlock`, decoupled from `region`, so it can be authored
   on any lesson regardless of PH scope.
4. New block types for scenario, myth/fact, comparison cards, checklist,
   calculator/simulator preview, and single/multiple-choice/sorting
   assessment, added to the sealed `LessonBlock` hierarchy exactly the way
   the existing nine were: one class, one view, one `switch` arm each (the
   compiler enforces nothing is forgotten).
5. A per-catalog `settings.expansionProgress` (or equivalent) storage key,
   additive and separate from `lessonProgress`/`lessonsRead` (section 9.2).

## 13. Migration and backup risks

- Adding fields to `MoneyLesson`/`LessonBlock` is source-only (const maps in
  Dart), not a stored-data migration; `schemaVersion` does not need to bump
  for new lesson content or new block types, only if the **stored progress
  shape** changes.
- The new progress key is additive to `settings`; existing restores are
  unaffected either way (an old backup simply lacks the new key, which reads
  as "no expansion progress," same pattern `lessonProgress` itself already
  handles for pre-progress-model backups).
- The real risk is the **backup goldens** (`backup_golden_test.dart`,
  `backup_export_golden_test.dart`): a new unconditional `settings` key
  breaks the RN-fixture-derived exact key-set assertion. Follow the existing
  conditional-emit pattern (`paluwagans`, `steadyPay`) — emit the expansion
  progress key only when non-empty — and expect to touch the goldens
  deliberately once, with review, not as a side effect.
- Restoring expansion progress should get the same "trust but do not
  validate beyond shape" treatment `lessonProgress` gets today (section 6);
  do not scope-creep into building new validation the core path never had,
  but do not skip the conditional-key discipline the founder already
  standardized on.

## 14. Suggested agent mapping

| Role | Recommendation |
|---|---|
| Course Experience Reviewer | Use `flutter-ux-craftsman` as-is. |
| Philippine Policy Reviewer | Use `legal-compliance-counsel` for app-store/consumer-protection/advertising framing and `tax-professional` for anything tax-adjacent; both as-is. Neither covers SEC investment-suitability rules or DTI/SEC/BIR business-registration accuracy well; flag specific lessons that need a subject-matter check to the founder rather than rely on either agent for that narrow slice, until Grow/Business content is actually drafted and the real gap size is known. |
| Investment Content Reviewer | No suitable existing agent. Recommend creating one only once "Grow Your Money" lesson drafts exist to review against, per this task's own instruction not to create agents in this phase. |

## 15. Exact implementation phases

1. **Data model.** Add the additive fields and new block types from section
   12 to `lesson_model.dart`/`lesson_blocks.dart`/`lesson_block_views.dart`.
   Zero behavior change to the 22 existing lessons (every new field
   optional/defaulted). Port `porting-money-logic`-style discipline: nothing
   here touches money math, but the golden-content regeneration discipline
   in `lessons.dart`'s own header comment (`tool/regen_copy_goldens.dart`)
   still applies.
2. **Storage.** Add the per-catalog progress key to `store.dart`, reusing
   `lesson_progress.dart` unchanged. Add the conditional-emit entry to
   `backup.dart` and regenerate the two backup goldens deliberately.
3. **Reader promotion.** Promote `_LessonReader` out of `learn.dart` into a
   shared, public widget so three new screens do not fork it.
4. **Content and screens**, one path at a time (Grow Your Money first,
   ordering per founder priority): new content file, new track/catalog
   constants, new screen (or a generalized catalog screen parameterized by
   catalog, if that turns out cheaper than three near-identical screens),
   wired from wherever the founder wants an entry point (Menu/Tools is the
   existing pattern for "Money courses").
5. **Agent review pass** per section 14, using `flutter-ux-craftsman` and
   `legal-compliance-counsel`/`tax-professional` on the first real content
   drafts; decide then whether an Investment Content Reviewer agent is
   actually needed.
6. **Test coverage** per section 16, plus the standard render-and-look
   requirement (`flutter test test/screens_shot.dart --update-goldens`,
   dark first) and a QA log row before any merge, per this repo's existing
   merge rules.

## 16. Targeted test plan

- Unit: new block types get the same "malformed input drops the block
  rather than rendering empty" tests `blockFromMap` already has for the
  existing nine (see `lesson_blocks_test.dart`-equivalent coverage inside
  `lessons_content_test.dart` today).
- Unit: a new test asserting `lessons.length == 22` and
  `courseTracks.length == 4` stays true after the expansion lands, i.e. a
  regression guard that a future edit cannot accidentally append expansion
  lessons into the core list. Prove it can fail: temporarily append a
  lesson to `lessons`, watch it fail, then revert, per this repo's
  "prove a new test can fail" rule.
- Unit: progress isolation, a test that writing expansion-path progress
  never changes `store.lessonProgress`/`learnedCount` for the core 22, and
  vice versa.
- Golden: extend `lessons_golden_test.dart`'s pattern to each new content
  file once it exists.
- Golden: regenerate `backup_golden_test.dart` / `backup_export_golden_test.dart`
  fixtures once the new settings key ships, reviewed, not automatic.
- Widget: `screen_readability_test.dart` sweep extended to include each new
  catalog screen once built, against the LIVED-IN fixture (not an empty
  store), per this repo's existing rule about that fixture.
- Widget: `palette_contrast_test.dart` already covers any new color pairs
  automatically since it iterates the full theme registry; no new test
  needed there, just confirm new UI only uses existing `Barako.*` tokens.
- Content house rule: add the currently-missing automated check for "no
  product, investment, loan, or stock recommendations" (section 10/11) as
  part of this expansion, since it is the first time content that could
  plausibly violate it (investment lessons) is being written. A keyword/
  pattern-based test cannot catch everything, but it can catch the obvious
  slip (a named fund, a named brokerage, "buy X") the same way the existing
  em-dash test catches a mechanical slip, and it is exactly the kind of
  guard this repo's own rules ask for after a near-miss.
- Journey: once a new path has at least one write-affecting `LessonAction`
  (a route that writes data), add it to `journeys_test.dart` per the
  journey-tester agent's existing discipline; a pure-reading course path
  with no state-changing action does not need one.
