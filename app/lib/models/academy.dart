// The Academy curriculum's shape, from src/data/academyData.ts.
//
// Separate from models.dart because the curriculum is CONTENT rather than
// money: nothing here is summed, compared or reconciled, and mixing it in
// with Transaction and Account would invite a screen to treat a lesson like
// a ledger row.

/// One readable chunk of a lesson.
class LessonSection {
  const LessonSection({
    required this.id,
    required this.title,
    required this.content,
  });

  final String id;
  final String title;
  final String content;
}

/// The one question at the end of a lesson.
///
/// The prototype calls it a knowledge check rather than a test, and the
/// wording matters: it exists so somebody notices what they did not absorb,
/// not so they can fail. [explanation] is shown either way.
class KnowledgeCheck {
  const KnowledgeCheck({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
}

class CourseModule {
  const CourseModule({
    required this.id,
    required this.title,
    required this.category,
    required this.icon,
    required this.description,
    required this.durationMinutes,
    required this.objectives,
    required this.sections,
    required this.keyTakeaways,
    this.knowledgeCheck,
    this.reflectionPrompt,
  });

  final String id;
  final String title;
  final String category;

  /// A MEANING, not a glyph: 'shield', 'mind', 'card'. Salapify's own icons
  /// resolve through one file, so restyling every one is a single edit, and
  /// emoji stay reserved for data the user chose.
  final String icon;

  final String description;
  final int durationMinutes;
  final List<String> objectives;
  final List<LessonSection> sections;
  final List<String> keyTakeaways;

  /// Not every course has one. 24 of the 32 do.
  final KnowledgeCheck? knowledgeCheck;

  /// A question to sit with rather than answer in the app. 14 courses have one.
  final String? reflectionPrompt;
}
