// The Financial Guides content model.
//
// A guide is a SHORT explainer, one to four minutes, that answers a single
// plain-English money question ("What is withholding tax?", "How does 13th
// month pay work?"). Guides are the browsable layer of the Financial Guides
// hub; they are deliberately lighter than Money Courses lessons (lesson_model
// .dart), which are longer, carry a knowledge check, and end in a real in-app
// action. A guide teaches one idea and, where it helps, points to the fuller
// course.
//
// This is Salapify-authored content, so every icon is a semantic NAME resolved
// through widgets/salapify_icon.dart (an orange Material glyph), never an emoji
// (see the icons rule in CLAUDE.md). Facts are drawn from the already-verified
// Money Courses lessons; where a guide states an official rule it carries the
// same citation the source lesson already verified.

import 'package:flutter/foundation.dart';

/// The six browsable topics. The chip row and the Browse by Topic grid both
/// read this list, so a new category is one enum value with its label, blurb,
/// and icon, and both surfaces pick it up. The declaration order IS the
/// display order of the chips and the grid.
enum GuideCategory {
  moneyBasics(
    label: 'Money Basics',
    blurb: 'Budgeting, saving, credit and more',
    icon: 'wallet',
  ),
  government(
    label: 'Government',
    blurb: 'SSS, Pag-IBIG, PhilHealth and more',
    icon: 'foundation',
  ),
  tax(
    label: 'Tax',
    blurb: 'Tax types, filing, and deductions',
    icon: 'percent',
  ),
  investing(
    label: 'Investing',
    blurb: 'Start investing, grow your money',
    icon: 'growth',
  ),
  debtCredit(
    label: 'Debt and Credit',
    blurb: 'Loans, credit cards, and payoff',
    icon: 'card',
  ),
  business(
    label: 'Business',
    blurb: 'Start and grow your business',
    icon: 'work',
  );

  const GuideCategory({
    required this.label,
    required this.blurb,
    required this.icon,
  });

  /// Shown on the chip and as the Browse by Topic card title.
  final String label;

  /// One short line under the category name on the Browse by Topic grid.
  final String blurb;

  /// Semantic icon name, resolved through widgets/salapify_icon.dart.
  final String icon;
}

/// One section of a guide's body: a short heading and a few plain sentences.
/// The reader walks these in order, exactly like the lesson reader walks its
/// blocks, so a new guide needs content and no new UI.
@immutable
class GuideSection {
  final String heading;

  /// The prose, one entry per paragraph. Kept as a list so the reader spaces
  /// paragraphs itself rather than depending on embedded newlines.
  final List<String> paragraphs;

  const GuideSection({required this.heading, required this.paragraphs});
}

/// An official source a guide cites, the same shape the lessons use. Rendered
/// as a quiet footer in the reader so a claim about a government rule can be
/// checked. A government-domain url must be independently searched and
/// confirmed before it ships, per the Money Courses source rule in CLAUDE.md.
@immutable
class GuideSource {
  final String agency;
  final String title;
  final String url;

  /// ISO date the url was last confirmed live, for the reader's footer.
  final String? lastVerified;

  const GuideSource({
    required this.agency,
    required this.title,
    required this.url,
    this.lastVerified,
  });
}

/// One Financial Guide. Immutable and safe to share as a `const`, the same
/// convention MoneyLesson and LearningPath follow.
@immutable
class FinancialGuide {
  /// Stable, kebab-case, unique. Never reused for a different guide once a
  /// reader has progress recorded against it (progress lives under this id in
  /// settings.guideProgress).
  final String id;

  final GuideCategory category;

  /// Usually a plain question, e.g. "What is withholding tax?".
  final String title;

  /// The card subtitle: one short sentence on what the guide answers.
  final String summary;

  /// Honest reading time in minutes, 1 to 4.
  final int minutes;

  /// Semantic icon name, resolved through widgets/salapify_icon.dart.
  final String icon;

  /// The body, in reading order.
  final List<GuideSection> sections;

  /// One sentence worth keeping, shown at the end of the reader.
  final String keyTakeaway;

  /// Rank on the Popular Guides row, 1-based and ascending (1 shows first).
  /// Null for a guide that is not featured there.
  final int? popularRank;

  /// A Money Courses lesson id this guide's "Go deeper" link should focus,
  /// when a fuller course exists. Null when the guide stands alone; the reader
  /// then offers the general "Explore Money Courses" link instead.
  final String? deepDiveLessonId;

  /// Optional official citations, shown as a footer in the reader.
  final List<GuideSource> sources;

  const FinancialGuide({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    required this.minutes,
    required this.icon,
    required this.sections,
    required this.keyTakeaway,
    this.popularRank,
    this.deepDiveLessonId,
    this.sources = const [],
  });

  bool get isPopular => popularRank != null;
}
