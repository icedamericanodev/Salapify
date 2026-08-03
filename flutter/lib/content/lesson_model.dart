// The typed shape of a money-course lesson.
//
// The content used to be bare Map<String, dynamic>, read as l['title'] as
// String at every use. That was survivable for four fields. The course upgrade
// adds nine more per lesson (objective, structured sections, example, common
// mistake, a knowledge check with three choices, takeaway, region metadata,
// fact-check date, source notes), and a typo in a key on an untyped map is a
// runtime crash on a real phone instead of a compile error here.
//
// So the content is typed at the boundary and the screens never index a map
// again. The raw maps stay as the authoring format in lessons.dart, because
// they read well as content, and lessonFromMap does the one conversion with
// every fallback in one place.

import 'lesson_blocks.dart';

/// Where a lesson's facts apply. Tax rules, contribution rates, and filing
/// deadlines are country specific, and burying that in the last paragraph is
/// how a reader in another country ends up acting on Philippine rules.
enum CourseRegion { global, philippines }

/// What a section IS, so the reader can render it as itself rather than as
/// yet another identical paragraph.
enum SectionKind { context, concept, steps, example, warning, takeaway }

/// How often a lesson's facts can realistically change. Not a measure of how
/// important a lesson is, only of how fast it can go stale: a definition is
/// evergreen, a contribution table is annual, a rate or circular a regulator
/// can revise mid year is high.
enum ContentVolatility { evergreen, annual, high }

/// Where a lesson's facts stand in their own review cycle, separate from
/// whether the lesson's prose is finished.
enum ReviewStatus { verified, reviewDue, withdrawn }

/// A subject that makes a lesson regulated, financial-product, or
/// eligibility content: the exact set the Phase 4 content policy validator
/// (money/expansion_content_policy.dart) requires an official source and a
/// risk-warning block for. One enum serves both requirements on purpose,
/// because every topic here is both regulated (needs a citation) and
/// consumer-risk bearing (needs a warning); there is no topic that needs one
/// but not the other.
///
/// The smallest additive classification the Phase 4 task allows: no existing
/// lesson sets this (defaults to empty), and it exists only so expansion
/// content can declare what it is about without a name list of specific
/// products, funds, or coins, which the same task explicitly forbids.
enum ContentTopic {
  stocks,
  bonds,

  /// UITFs, mutual funds, and ETFs: pooled investment vehicles that share the
  /// same suitability and risk-disclosure concerns.
  fundsAndEtfs,
  cryptocurrency,

  /// Insurance and variable-unit-linked (VUL) products.
  insuranceOrVul,
  loansOrCredit,

  /// Claims about what a purchased product returns or pays out.
  productReturns,
  governmentBenefitEligibility,

  /// Business registration, tax, or permit compliance (DTI/SEC/BIR/LGU).
  businessTaxOrPermitCompliance,
}

/// One excerpt of a misleading claim, quoted or paraphrased on purpose to
/// explain or debunk it, e.g. inside a [TrapBlock]'s `mostPeople` half.
///
/// This is the narrow, explicit exemption the Phase 4 policy validator
/// requires: unsafe-language scanning skips a block whose full text matches
/// [text] exactly, and nothing else. It never suppresses validation for the
/// rest of the lesson, and [reviewedBy] is required so an exemption always
/// names who reviewed it rather than being self-granted by the same edit
/// that added the risky wording.
class ReviewedMythExample {
  final String text;

  /// Who reviewed this excerpt as safe myth-busting. An initial or a role,
  /// never a full name, same convention as [LessonGovernance.reviewerId].
  final String reviewedBy;

  const ReviewedMythExample({required this.text, required this.reviewedBy});
}

/// One place a lesson's facts came from. A lesson can cite more than one
/// source (a law and the circular that implements it, for example), so this
/// is a list on [MoneyLesson] rather than a single field.
///
/// Dates stay as plain strings ('YYYY-MM' or 'YYYY-MM-DD'), the same
/// convention [MoneyLesson.factCheckedOn] already uses. The authoring lists
/// in lessons.dart are `const List<Map<String, dynamic>>` literals, and a
/// DateTime value is never a compile time constant, so a DateTime field here
/// would force every existing lesson map to give up const construction just
/// to satisfy one new field none of them set yet.
class LessonSourceInfo {
  /// The issuing body, e.g. "Bangko Sentral ng Pilipinas".
  final String agency;

  /// The document's own title, e.g. "Circular No. 1133".
  final String title;
  final String canonicalUrl;

  /// The law, circular, or issuance number, when the source has one.
  final String? issuanceOrCircularNumber;

  /// 'YYYY-MM' or 'YYYY-MM-DD'.
  final String? effectiveDate;

  /// 'YYYY-MM' or 'YYYY-MM-DD'.
  final String? lastVerifiedDate;

  const LessonSourceInfo({
    required this.agency,
    required this.title,
    required this.canonicalUrl,
    this.issuanceOrCircularNumber,
    this.effectiveDate,
    this.lastVerifiedDate,
  });
}

/// The review state of a lesson's facts, kept apart from [MoneyLesson.check]
/// and the prose. A lesson's writing can be finished while its facts are
/// still due for a periodic check, and this is what lets a reviewer see that
/// difference without rereading the lesson.
class LessonGovernance {
  final ContentVolatility volatility;
  final ReviewStatus reviewStatus;

  /// Bumped when the lesson's facts change, not when its prose is polished.
  final int contentVersion;

  /// 'YYYY-MM' or 'YYYY-MM-DD'.
  final String? lastVerifiedDate;

  /// 'YYYY-MM' or 'YYYY-MM-DD'.
  final String? reviewDueDate;

  /// Who last verified the facts. An initial or a role, never a full name in
  /// content that ships to every phone.
  final String? reviewerId;

  const LessonGovernance({
    this.volatility = ContentVolatility.evergreen,
    this.reviewStatus = ReviewStatus.verified,
    this.contentVersion = 1,
    this.lastVerifiedDate,
    this.reviewDueDate,
    this.reviewerId,
  });
}

class LessonSection {
  final SectionKind kind;

  /// Shown as the section heading. Empty means the kind's own default.
  final String heading;

  /// Paragraphs for prose kinds; ordered steps for SectionKind.steps.
  final List<String> body;

  const LessonSection({
    required this.kind,
    this.heading = '',
    required this.body,
  });
}

/// One scenario question per lesson. Not a definition quiz: the point is to
/// rehearse a decision, so a learner meets the choice here before meeting it
/// with real money.
class KnowledgeCheck {
  final String question;
  final List<String> choices;
  final int correctIndex;

  /// Why the right answer is right. Shown after answering, whichever way.
  final String explanation;

  /// Optional: why the most tempting wrong answer is wrong. Shown only when
  /// the learner picked it, so being wrong teaches something specific.
  final String? whyWrong;

  const KnowledgeCheck({
    required this.question,
    required this.choices,
    required this.correctIndex,
    required this.explanation,
    this.whyWrong,
  });

  bool get isValid =>
      choices.length == 3 &&
      correctIndex >= 0 &&
      correctIndex < choices.length &&
      question.trim().isNotEmpty &&
      explanation.trim().isNotEmpty;
}

/// The one real thing to do in the app when the reading is done.
class LessonAction {
  final String label;
  final String route;
  const LessonAction({required this.label, required this.route});
}

class MoneyLesson {
  final String id;
  final String trackId;
  final String title;

  /// Semantic icon NAME, resolved by widgets/salapify_icon.dart. Not an
  /// emoji: content names the meaning and one file decides how it is drawn,
  /// so the whole app restyles in one edit.
  final String icon;
  final int minutes;
  final String summary;

  /// One sentence starting with a verb. "Identify where your daily spending
  /// goes", not "Understand budgeting".
  final String objective;

  final CourseRegion region;

  /// True only for advice that does not apply to a salaried employee: setting
  /// aside your own tax, restarting your own SSS/PhilHealth/Pag-IBIG. A
  /// lesson about irregular income in general (drivers, sellers, commission
  /// work) is NOT this, even though freelancers are one group who has it;
  /// this flag is for content that would be actively wrong advice for
  /// someone with an employer, not merely content freelancers relate to.
  final bool forFreelancers;

  final List<LessonSection> sections;

  /// Blocks authored in the coaching shape. Empty means this lesson has not
  /// been rewritten yet, and [blocks] derives a sensible set from the older
  /// fields so every lesson keeps rendering while the content catches up.
  final List<LessonBlock> authoredBlocks;
  final String commonMistake;
  final KnowledgeCheck? check;
  final String keyTakeaway;
  final LessonAction? action;

  /// When the facts were last checked, for content that can go stale. Tax
  /// rates, thresholds, and deadlines drift; a lesson that quietly presents
  /// last year's rules as current is worse than one that says it is unsure.
  ///
  /// Superseded by [governance].lastVerifiedDate for any lesson that adopts
  /// the structured governance model below: a future content pass can move a
  /// lesson's date into an authored `governance` map and drop this field for
  /// that lesson, one lesson at a time, the same track by track discipline
  /// the block redesign used. Kept here unchanged, never removed or migrated
  /// in this phase, because none of the existing 22 lessons set it today.
  final String? factCheckedOn; // 'YYYY-MM' or 'YYYY-MM-DD'

  /// Developer-facing only, never rendered: where a factual claim came from.
  ///
  /// Superseded by [sources] for a lesson that wants its citation actually
  /// shown to the reader (an [OfficialSourceBlock] in [authoredBlocks]); this
  /// field stays for lessons that only need a developer note, not a
  /// renderable citation.
  final List<String> sourceNotes;

  /// Structured citations for this lesson's facts, renderable via
  /// [OfficialSourceBlock]. Empty by default; none of the existing 22
  /// lessons set this.
  final List<LessonSourceInfo> sources;

  /// This lesson's place in its own review cycle. Defaults to an evergreen,
  /// verified, version 1 lesson with no due date, which is exactly what every
  /// existing lesson already is by convention; authoring this explicitly is
  /// opt in.
  final LessonGovernance governance;

  /// What this lesson is about, for the Phase 4 content policy validator.
  /// Empty for every existing lesson; a non-empty set is what makes a lesson
  /// "regulated" for source and risk-warning requirements.
  final List<ContentTopic> topics;

  /// Excerpts reviewed and exempted from unsafe-language scanning, see
  /// [ReviewedMythExample]. Empty for every existing lesson.
  final List<ReviewedMythExample> reviewedMythExamples;

  const MoneyLesson({
    required this.id,
    required this.trackId,
    required this.title,
    required this.icon,
    required this.minutes,
    required this.summary,
    required this.objective,
    this.region = CourseRegion.global,
    this.forFreelancers = false,
    required this.sections,
    this.authoredBlocks = const [],
    this.commonMistake = '',
    this.check,
    this.keyTakeaway = '',
    this.action,
    this.factCheckedOn,
    this.sourceNotes = const [],
    this.sources = const [],
    this.governance = const LessonGovernance(),
    this.topics = const [],
    this.reviewedMythExamples = const [],
  });

  /// What the reader actually renders.
  ///
  /// Authored blocks win. Otherwise the older fields are mapped onto the
  /// closest block kind, so a lesson written before the redesign still reads
  /// as cards rather than as a wall of prose, and the remaining lessons can be
  /// rewritten one at a time instead of in one unreviewable change.
  List<LessonBlock> get blocks {
    if (authoredBlocks.isNotEmpty) return authoredBlocks;
    final out = <LessonBlock>[];
    for (final s in sections) {
      switch (s.kind) {
        case SectionKind.steps:
          // Ordered steps ARE a flow, so they render as the diagram rather
          // than as another paragraph list.
          out.add(DiagramBlock(steps: s.body));
        case SectionKind.example:
          out.add(StoryBlock(who: 'For example', text: s.body.join(' ')));
        case SectionKind.context:
          out.add(
            ProseBlock(
              heading: s.heading.isNotEmpty ? s.heading : 'Why it matters',
              paragraphs: s.body,
            ),
          );
        case SectionKind.warning:
          out.add(
            ProseBlock(
              heading: s.heading.isNotEmpty ? s.heading : 'Watch out for',
              paragraphs: s.body,
            ),
          );
        case SectionKind.takeaway:
        case SectionKind.concept:
          out.add(ProseBlock(heading: s.heading, paragraphs: s.body));
      }
    }
    if (commonMistake.isNotEmpty) {
      out.add(
        ProseBlock(heading: 'A common mistake', paragraphs: [commonMistake]),
      );
    }
    if (keyTakeaway.isNotEmpty) out.add(ReflectionBlock(keyTakeaway));
    return out;
  }

  bool get isPhilippines => region == CourseRegion.philippines;

  /// Time-sensitive lessons are exactly the regional ones today: every
  /// factual claim that can expire is a tax rate, a contribution rate, or a
  /// filing deadline. Kept as a rule rather than a per-lesson flag so a new
  /// PH lesson cannot forget to opt in.
  bool get isTimeSensitive => isPhilippines;
}

class CourseTrack {
  final String id;
  final String title;

  /// Semantic icon name, see MoneyLesson.icon.
  final String icon;

  /// What the learner will be able to DO at the end, not what it covers.
  final String outcome;

  const CourseTrack({
    required this.id,
    required this.title,
    required this.icon,
    required this.outcome,
  });
}

// ---------------------------------------------------------------------------
// Conversion from the authoring maps. Every fallback lives here so a lesson
// that has not been rewritten into the new shape yet still renders correctly.
// ---------------------------------------------------------------------------

List<String> _strings(dynamic raw) => [
  for (final x in (raw is List ? raw : const []))
    if (x is String && x.trim().isNotEmpty) x,
];

SectionKind _kindFrom(String? name) => switch (name) {
  'context' => SectionKind.context,
  'steps' => SectionKind.steps,
  'example' => SectionKind.example,
  'warning' => SectionKind.warning,
  'takeaway' => SectionKind.takeaway,
  _ => SectionKind.concept,
};

List<LessonSourceInfo> _sourcesFrom(dynamic raw) {
  if (raw is! List) return const [];
  final out = <LessonSourceInfo>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final agency = (entry['agency'] ?? '').toString();
    final title = (entry['title'] ?? '').toString();
    final url = (entry['canonicalUrl'] ?? '').toString();
    // A source missing its agency, title, or link is not a usable citation,
    // so it is dropped rather than shown half blank.
    if (agency.isEmpty || title.isEmpty || url.isEmpty) continue;
    out.add(
      LessonSourceInfo(
        agency: agency,
        title: title,
        canonicalUrl: url,
        issuanceOrCircularNumber: entry['issuanceOrCircularNumber'] is String
            ? entry['issuanceOrCircularNumber'] as String
            : null,
        effectiveDate: entry['effectiveDate'] is String
            ? entry['effectiveDate'] as String
            : null,
        lastVerifiedDate: entry['lastVerifiedDate'] is String
            ? entry['lastVerifiedDate'] as String
            : null,
      ),
    );
  }
  return out;
}

ContentVolatility _volatilityFrom(dynamic raw) => switch (raw) {
  'annual' => ContentVolatility.annual,
  'high' => ContentVolatility.high,
  _ => ContentVolatility.evergreen,
};

ReviewStatus _reviewStatusFrom(dynamic raw) => switch (raw) {
  'reviewDue' => ReviewStatus.reviewDue,
  'withdrawn' => ReviewStatus.withdrawn,
  _ => ReviewStatus.verified,
};

LessonGovernance _governanceFrom(dynamic raw) {
  if (raw is! Map) return const LessonGovernance();
  return LessonGovernance(
    volatility: _volatilityFrom(raw['volatility']),
    reviewStatus: _reviewStatusFrom(raw['reviewStatus']),
    contentVersion: raw['contentVersion'] is int
        ? raw['contentVersion'] as int
        : 1,
    lastVerifiedDate: raw['lastVerifiedDate'] is String
        ? raw['lastVerifiedDate'] as String
        : null,
    reviewDueDate: raw['reviewDueDate'] is String
        ? raw['reviewDueDate'] as String
        : null,
    reviewerId: raw['reviewerId'] is String
        ? raw['reviewerId'] as String
        : null,
  );
}

ContentTopic? _topicFrom(String name) => switch (name) {
  'stocks' => ContentTopic.stocks,
  'bonds' => ContentTopic.bonds,
  'fundsAndEtfs' => ContentTopic.fundsAndEtfs,
  'cryptocurrency' => ContentTopic.cryptocurrency,
  'insuranceOrVul' => ContentTopic.insuranceOrVul,
  'loansOrCredit' => ContentTopic.loansOrCredit,
  'productReturns' => ContentTopic.productReturns,
  'governmentBenefitEligibility' => ContentTopic.governmentBenefitEligibility,
  'businessTaxOrPermitCompliance' => ContentTopic.businessTaxOrPermitCompliance,
  _ => null,
};

List<ContentTopic> _topicsFrom(dynamic raw) {
  if (raw is! List) return const [];
  final out = <ContentTopic>[];
  for (final x in raw) {
    if (x is! String) continue;
    final t = _topicFrom(x);
    if (t != null) out.add(t);
  }
  return out;
}

List<ReviewedMythExample> _reviewedMythExamplesFrom(dynamic raw) {
  if (raw is! List) return const [];
  final out = <ReviewedMythExample>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final text = (entry['text'] ?? '').toString();
    final reviewedBy = (entry['reviewedBy'] ?? '').toString();
    // An exemption without a reviewer name is not a reviewed exemption.
    if (text.trim().isEmpty || reviewedBy.trim().isEmpty) continue;
    out.add(ReviewedMythExample(text: text, reviewedBy: reviewedBy));
  }
  return out;
}

KnowledgeCheck? _checkFrom(dynamic raw) {
  if (raw is! Map) return null;
  final choices = _strings(raw['choices']);
  final idx = raw['answer'];
  final c = KnowledgeCheck(
    question: (raw['question'] ?? '').toString(),
    choices: choices,
    correctIndex: idx is int ? idx : -1,
    explanation: (raw['explanation'] ?? '').toString(),
    whyWrong: raw['whyWrong'] is String ? raw['whyWrong'] as String : null,
  );
  // A malformed check is dropped rather than rendered. A quiz that marks the
  // right answer wrong would teach the opposite of the lesson.
  return c.isValid ? c : null;
}

/// Build a typed lesson from an authoring map.
///
/// Back compatible on purpose: a lesson still carrying only the old shape
/// (a flat 'body' list and no sections) converts into a single concept
/// section, so the reader renders every lesson correctly while the content is
/// rewritten track by track rather than in one unreviewable change.

/// Authored blocks, with one special marker expanded.
///
/// A block of kind 'reference' is replaced by the lesson's own body prose.
/// That exists for the Philippine tax lessons: their facts are CPA reviewed
/// and pinned by regression tests that read `body`, so restating those rates,
/// thresholds, and deadlines inside a second copy in `blocks` would create two
/// sources of truth for the one kind of content that must never drift. The
/// coaching blocks wrap the verified prose instead of paraphrasing it.
List<LessonBlock> _authoredBlocks(Map<String, dynamic> m) {
  final raw = m['blocks'];
  if (raw is! List) return const [];
  final body = _strings(m['body']);
  final out = <LessonBlock>[];
  for (final entry in raw) {
    if (entry is Map && (entry['kind'] ?? '').toString() == 'reference') {
      // 'from' drops leading paragraphs that a block above already covers.
      // The scope note and the opening habit sentence were being said twice,
      // once as coaching and again verbatim, which reads as padding.
      final from = entry['from'] is int ? entry['from'] as int : 0;
      final kept = body.length > from ? body.sublist(from) : const <String>[];
      if (kept.isNotEmpty) out.add(RulesBlock(kept));
      continue;
    }
    final b = blockFromMap(entry);
    if (b != null) out.add(b);
  }
  return out;
}

MoneyLesson lessonFromMap(Map<String, dynamic> m) {
  final rawSections = m['sections'];
  final sections = <LessonSection>[];
  if (rawSections is List && rawSections.isNotEmpty) {
    for (final s in rawSections) {
      if (s is! Map) continue;
      final body = _strings(s['body']);
      if (body.isEmpty) continue;
      sections.add(
        LessonSection(
          kind: _kindFrom(s['kind'] as String?),
          heading: (s['heading'] ?? '').toString(),
          body: body,
        ),
      );
    }
  }
  if (sections.isEmpty) {
    final body = _strings(m['body']);
    if (body.isNotEmpty) {
      sections.add(LessonSection(kind: SectionKind.concept, body: body));
    }
  }

  final rawAction = m['action'];
  return MoneyLesson(
    id: (m['id'] ?? '').toString(),
    trackId: (m['track'] ?? '').toString(),
    title: (m['title'] ?? '').toString(),
    icon: (m['icon'] ?? '').toString(),
    minutes: m['minutes'] is int ? m['minutes'] as int : 1,
    summary: (m['summary'] ?? '').toString(),
    objective: (m['objective'] ?? '').toString(),
    region: m['region'] == 'PH'
        ? CourseRegion.philippines
        : CourseRegion.global,
    forFreelancers: m['forFreelancers'] == true,
    sections: sections,
    authoredBlocks: _authoredBlocks(m),
    commonMistake: (m['commonMistake'] ?? '').toString(),
    check: _checkFrom(m['check']),
    keyTakeaway: (m['takeaway'] ?? '').toString(),
    action: rawAction is Map && rawAction['route'] is String
        ? LessonAction(
            label: (rawAction['label'] ?? '').toString(),
            route: rawAction['route'] as String,
          )
        : null,
    factCheckedOn: m['factCheckedOn'] is String
        ? m['factCheckedOn'] as String
        : null,
    sourceNotes: _strings(m['sourceNotes']),
    sources: _sourcesFrom(m['sources']),
    governance: _governanceFrom(m['governance']),
    topics: _topicsFrom(m['topics']),
    reviewedMythExamples: _reviewedMythExamplesFrom(m['reviewedMythExamples']),
  );
}

CourseTrack trackFromMap(Map<String, dynamic> m) => CourseTrack(
  id: (m['key'] ?? '').toString(),
  title: (m['title'] ?? '').toString(),
  icon: (m['icon'] ?? '').toString(),
  outcome: (m['outcome'] ?? '').toString(),
);
