// The blocks a lesson is made of.
//
// The previous model had one LessonSection with a heading and a list of
// paragraphs, which produced a well-organised DOCUMENT. That was the wrong
// target. A lesson should read like a short conversation with a coach: one
// idea per card, a question before an answer, a real person's story, a thing
// to try. Those are different KINDS of moment, and a single prose type cannot
// express them, so the renderer had no choice but to draw everything the same.
//
// So a lesson is now a list of typed blocks. Each block knows what it is, each
// has its own widget, and the reader assembles any lesson by walking the list.
// Adding a lesson never requires new UI, which is the whole point: 22 lessons
// today and any number later, all composed from the same parts.
//
// Sealed on purpose: a new block type becomes a compile error at the renderer
// until it is given a widget, rather than silently rendering as nothing.

sealed class LessonBlock {
  const LessonBlock();
}

/// Plain explanation. Still needed, but no longer the default shape of
/// everything: it carries the connective prose between the livelier blocks.
class ProseBlock extends LessonBlock {
  final String heading;
  final List<String> paragraphs;
  const ProseBlock({this.heading = '', required this.paragraphs});
}

/// One idea per card, readable in about three seconds. The unit of a money
/// nugget is a single sentence a person could repeat back.
class NuggetsBlock extends LessonBlock {
  final List<String> items;
  const NuggetsBlock(this.items);
}

/// Curiosity before instruction: ask, let them think, then reveal. The answer
/// stays hidden until tapped, which is the entire mechanism. Being wrong costs
/// nothing because nothing is graded.
class DiscoveryBlock extends LessonBlock {
  final String question;
  final String reveal;
  const DiscoveryBlock({required this.question, required this.reveal});
}

/// One realistic person, briefly. Kept short by contract, because a story that
/// runs long becomes an article again.
class StoryBlock extends LessonBlock {
  final String who;
  final String text;
  const StoryBlock({required this.who, required this.text});
}

/// A flow drawn as steps, built from widgets rather than an image, so it scales
/// with the system font and reads correctly to a screen reader.
class DiagramBlock extends LessonBlock {
  final List<String> steps;
  final String caption;
  const DiagramBlock({required this.steps, this.caption = ''});
}

/// What most people do, then what usually works better. Never phrased as a
/// failure: the common move is common because it is reasonable in the moment.
class TrapBlock extends LessonBlock {
  final String mostPeople;
  final String worksBetter;
  const TrapBlock({required this.mostPeople, required this.worksBetter});
}

/// A one-minute thing to try, ideally a guess the learner can check against
/// their own Salapify data. Guessing first is what makes the real number land.
class ChallengeBlock extends LessonBlock {
  final String prompt;

  /// What to compare the guess against, in the app.
  final String compare;
  const ChallengeBlock({required this.prompt, required this.compare});
}

/// Verbatim reference passages, one card each.
///
/// This exists for the Philippine tax lessons. Their wording is CPA reviewed
/// and cannot be paraphrased, but rendering five long paragraphs as one prose
/// run turned the middle of the lesson into exactly the article the redesign
/// was meant to replace. Same words, one card per paragraph, so the eye has
/// somewhere to rest and the reader can stop between rules.
class RulesBlock extends LessonBlock {
  final List<String> passages;
  const RulesBlock(this.passages);
}

/// The single sentence worth remembering. Exactly one, always last.
class ReflectionBlock extends LessonBlock {
  final String line;
  const ReflectionBlock(this.line);
}

/// A regulator or government agency's own published source, shown as a
/// citation card rather than folded into the lesson's own prose, so a reader
/// can tell Salapify's coaching apart from the regulator's own words and
/// check a claim against where it came from.
class OfficialSourceBlock extends LessonBlock {
  final String agency;
  final String sourceTitle;
  final String canonicalUrl;

  /// 'YYYY-MM' or 'YYYY-MM-DD'.
  final String? lastVerifiedDate;

  /// 'YYYY-MM' or 'YYYY-MM-DD'.
  final String? effectiveDate;
  final String? issuanceOrCircularNumber;

  const OfficialSourceBlock({
    required this.agency,
    required this.sourceTitle,
    required this.canonicalUrl,
    this.lastVerifiedDate,
    this.effectiveDate,
    this.issuanceOrCircularNumber,
  });
}

/// How much presentation weight a caution deserves. Two levels, not a full
/// severity scale: the block stays a calm, factual note either way, and
/// `caution` only asks for a slightly stronger visual signal, never for the
/// destructive-error styling a lost or overdue peso already owns elsewhere in
/// the app.
enum RiskSeverity { notice, caution }

/// A financial or regulatory warning, decoupled from [CourseRegion] on
/// purpose so it can sit on any lesson, not only a Philippine scoped one.
class RiskWarningBlock extends LessonBlock {
  final String title;
  final String text;
  final RiskSeverity severity;

  const RiskWarningBlock({
    required this.title,
    required this.text,
    this.severity = RiskSeverity.notice,
  });
}

/// The educational-boundary statement Phase 4 regulated lessons must carry:
/// this is education, not personalized advice, and product terms and rules
/// can change since the lesson was written.
///
/// A marker, not a paragraph field, on purpose: the fixed sentences are
/// always the same (see EducationalBoundaryView), so authoring this block is
/// a single opt-in rather than several sentences retyped, and slightly
/// wrong, in every regulated lesson. `sourceLabel` lets the verify sentence
/// point at a specific regulator ("verify current information through BSP")
/// instead of the generic "the cited official source" when one is known.
///
/// `examplesAreFictional`, when true, adds ONE more fixed sentence stating
/// every company, person, and figure used as an example in the lesson is
/// invented for teaching. This is the single disclaimer a lesson needs for
/// that: it replaces retyping "fictional" on every individual example
/// throughout the lesson body, which reads as noise at that density. A
/// lesson still names "fictional" once, close to any specific invented name
/// a reader could otherwise search for (see lessons_stocks_bonds_content_test
/// .dart's and lessons_deposits_pooled_funds_content_test.dart's own nearby-
/// window checks), but the blanket disclaimer here is what covers everything
/// else.
class EducationalBoundaryBlock extends LessonBlock {
  final String? sourceLabel;
  final bool examplesAreFictional;
  const EducationalBoundaryBlock({
    this.sourceLabel,
    this.examplesAreFictional = false,
  });
}

// ---------------------------------------------------------------------------
// Authoring conversion. Blocks are authored as maps in lessons.dart, because
// content reads better as data than as constructors.
// ---------------------------------------------------------------------------

List<String> _strings(dynamic raw) => [
  for (final x in (raw is List ? raw : const []))
    if (x is String && x.trim().isNotEmpty) x.trim(),
];

String _str(dynamic raw) => (raw ?? '').toString().trim();

/// Build one block, or null when the data cannot make a sensible one. A
/// half-built block is dropped rather than rendered as an empty card.
LessonBlock? blockFromMap(dynamic raw) {
  if (raw is! Map) return null;
  switch (_str(raw['kind'])) {
    case 'nuggets':
      final items = _strings(raw['items']);
      return items.isEmpty ? null : NuggetsBlock(items);
    case 'discovery':
      final q = _str(raw['question']);
      final r = _str(raw['reveal']);
      return (q.isEmpty || r.isEmpty)
          ? null
          : DiscoveryBlock(question: q, reveal: r);
    case 'story':
      final t = _str(raw['text']);
      return t.isEmpty ? null : StoryBlock(who: _str(raw['who']), text: t);
    case 'diagram':
      final steps = _strings(raw['steps']);
      return steps.length < 2
          ? null
          : DiagramBlock(steps: steps, caption: _str(raw['caption']));
    case 'trap':
      final m = _str(raw['mostPeople']);
      final b = _str(raw['worksBetter']);
      return (m.isEmpty || b.isEmpty)
          ? null
          : TrapBlock(mostPeople: m, worksBetter: b);
    case 'challenge':
      final p = _str(raw['prompt']);
      return p.isEmpty
          ? null
          : ChallengeBlock(prompt: p, compare: _str(raw['compare']));
    case 'reflection':
      final l = _str(raw['line']);
      return l.isEmpty ? null : ReflectionBlock(l);
    case 'officialSource':
      final agency = _str(raw['agency']);
      final title = _str(raw['sourceTitle']);
      final url = _str(raw['canonicalUrl']);
      return (agency.isEmpty || title.isEmpty || url.isEmpty)
          ? null
          : OfficialSourceBlock(
              agency: agency,
              sourceTitle: title,
              canonicalUrl: url,
              lastVerifiedDate: raw['lastVerifiedDate'] is String
                  ? raw['lastVerifiedDate'] as String
                  : null,
              effectiveDate: raw['effectiveDate'] is String
                  ? raw['effectiveDate'] as String
                  : null,
              issuanceOrCircularNumber:
                  raw['issuanceOrCircularNumber'] is String
                  ? raw['issuanceOrCircularNumber'] as String
                  : null,
            );
    case 'riskWarning':
      final title = _str(raw['title']);
      final text = _str(raw['text']);
      return (title.isEmpty || text.isEmpty)
          ? null
          : RiskWarningBlock(
              title: title,
              text: text,
              severity: raw['severity'] == 'caution'
                  ? RiskSeverity.caution
                  : RiskSeverity.notice,
            );
    case 'educationalBoundary':
      final label = _str(raw['sourceLabel']);
      return EducationalBoundaryBlock(
        sourceLabel: label.isEmpty ? null : label,
        examplesAreFictional: raw['examplesAreFictional'] == true,
      );
    default:
      final paras = _strings(raw['body']);
      return paras.isEmpty
          ? null
          : ProseBlock(heading: _str(raw['heading']), paragraphs: paras);
  }
}

List<LessonBlock> blocksFromList(dynamic raw) => [
  for (final b in (raw is List ? raw : const [])) ?blockFromMap(b),
];
