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

/// Where a lesson's facts apply. Tax rules, contribution rates, and filing
/// deadlines are country specific, and burying that in the last paragraph is
/// how a reader in another country ends up acting on Philippine rules.
enum CourseRegion { global, philippines }

/// What a section IS, so the reader can render it as itself rather than as
/// yet another identical paragraph.
enum SectionKind { context, concept, steps, example, warning, takeaway }

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
  final String emoji;
  final int minutes;
  final String summary;

  /// One sentence starting with a verb. "Identify where your daily spending
  /// goes", not "Understand budgeting".
  final String objective;

  final CourseRegion region;
  final List<LessonSection> sections;
  final String commonMistake;
  final KnowledgeCheck? check;
  final String keyTakeaway;
  final LessonAction? action;

  /// When the facts were last checked, for content that can go stale. Tax
  /// rates, thresholds, and deadlines drift; a lesson that quietly presents
  /// last year's rules as current is worse than one that says it is unsure.
  final String? factCheckedOn; // 'YYYY-MM' or 'YYYY-MM-DD'

  /// Developer-facing only, never rendered: where a factual claim came from.
  final List<String> sourceNotes;

  const MoneyLesson({
    required this.id,
    required this.trackId,
    required this.title,
    required this.emoji,
    required this.minutes,
    required this.summary,
    required this.objective,
    this.region = CourseRegion.global,
    required this.sections,
    this.commonMistake = '',
    this.check,
    this.keyTakeaway = '',
    this.action,
    this.factCheckedOn,
    this.sourceNotes = const [],
  });

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
  final String emoji;

  /// What the learner will be able to DO at the end, not what it covers.
  final String outcome;

  const CourseTrack({
    required this.id,
    required this.title,
    required this.emoji,
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
    emoji: (m['emoji'] ?? '').toString(),
    minutes: m['minutes'] is int ? m['minutes'] as int : 1,
    summary: (m['summary'] ?? '').toString(),
    objective: (m['objective'] ?? '').toString(),
    region: m['region'] == 'PH'
        ? CourseRegion.philippines
        : CourseRegion.global,
    sections: sections,
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
  );
}

CourseTrack trackFromMap(Map<String, dynamic> m) => CourseTrack(
  id: (m['key'] ?? '').toString(),
  title: (m['title'] ?? '').toString(),
  emoji: (m['emoji'] ?? '').toString(),
  outcome: (m['outcome'] ?? '').toString(),
);
