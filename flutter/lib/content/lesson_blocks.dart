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

/// The single sentence worth remembering. Exactly one, always last.
class ReflectionBlock extends LessonBlock {
  final String line;
  const ReflectionBlock(this.line);
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
