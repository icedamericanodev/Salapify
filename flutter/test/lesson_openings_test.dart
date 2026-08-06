// How an expansion lesson is allowed to OPEN.
//
// Every one of the 29 lessons in the Grow Your Money path used to begin the
// same way: a block headed 'Why it matters' whose first sentence was a
// definition. The experience audit found that is exactly where readers quit,
// and the simulated user panel proved it, with two of three testers stopping
// at the first sentence of the crypto lesson and never reaching the good
// interactive parts below it.
//
// Prose quality cannot be tested. The SHAPE of an opening can, and these are
// the two mechanical properties that separate "starts with your life" from
// "starts with a dictionary":
//
//   1. The first sentence speaks to the reader (contains you or your).
//   2. The heading above it says something specific to that lesson, rather
//      than the same three words 29 times.
//
// A lesson can satisfy both and still be badly written, so this is a floor
// and not a promise of quality. It exists so the fix cannot silently rot
// back the moment someone adds a lesson by copying the old shape.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/learning_paths.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lesson_model.dart';

/// The paths whose openings have been rewritten and are therefore held to
/// this standard.
///
/// A LIST rather than "every published path", deliberately and visibly.
/// Protect Your Future and Build Your Business still open the old way and
/// are the next content batch; pretending otherwise here would be the kind
/// of claim that makes a test suite harder to trust. The assertion below
/// that this set is exactly what is expected is what forces a later batch to
/// update this line on purpose rather than quietly widen it.
const _coveredPathIds = {'grow_your_money'};

List<MoneyLesson> get _covered => [
  for (final p in publishedLearningPaths)
    if (_coveredPathIds.contains(p.id)) ...lessonsForPath(p.id),
];

/// Sentences, split on real terminators.
///
/// Splitting on '. ' alone silently glued a question to whatever followed
/// it, which made three openings measure as one 35 to 73 word sentence that
/// nobody had written. A checker that reports a fault that is not there
/// wastes exactly as much time as one that misses a real fault.
List<String> _sentences(String p) => p
    .split(RegExp(r'(?<=[.?!])\s+'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

String _firstSentence(String p) {
  final s = _sentences(p);
  return s.isEmpty ? p : s.first;
}

ProseBlock? _openingProse(MoneyLesson l) {
  for (final b in l.blocks) {
    if (b is ProseBlock && b.paragraphs.isNotEmpty) return b;
  }
  return null;
}

final _second = RegExp(r'\b(you|your)\b', caseSensitive: false);

void main() {
  test('the covered set is exactly what it claims', () {
    // Guards the honesty of this file's own scope, so widening it is a
    // deliberate edit rather than a side effect.
    expect(_coveredPathIds, {'grow_your_money'});
    expect(_covered.length, 29);
  });

  group('every covered lesson opens on the reader', () {
    test('the first sentence speaks to them', () {
      final offenders = <String>[];
      for (final l in _covered) {
        final prose = _openingProse(l);
        if (prose == null) {
          offenders.add('${l.id}: no opening prose block at all');
          continue;
        }
        final first = _firstSentence(prose.paragraphs.first);
        if (!_second.hasMatch(first)) {
          offenders.add('${l.id}: "$first"');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'these lessons open with a definition instead of the reader:\n'
            '${offenders.join('\n')}',
      );
    });

    test('no opening sentence is a wall', () {
      // A hook that runs 40 words is not a hook. Generous on purpose: this
      // catches the paragraph-shaped opener, not tight prose.
      final offenders = <String>[];
      for (final l in _covered) {
        final prose = _openingProse(l);
        if (prose == null) continue;
        for (final s in _sentences(prose.paragraphs.first)) {
          final words = s.split(RegExp(r'\s+')).length;
          if (words > 30) offenders.add('${l.id}: $words words, "$s"');
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('every covered lesson names its own opening', () {
    test('no lesson still uses the generic heading', () {
      final offenders = [
        for (final l in _covered)
          if ((_openingProse(l)?.heading ?? '').toLowerCase() ==
              'why it matters')
            l.id,
      ];
      expect(
        offenders,
        isEmpty,
        reason:
            'the one heading inside these lessons says nothing:\n'
            '${offenders.join('\n')}',
      );
    });

    test('the headings are distinct from each other', () {
      final headings = [
        for (final l in _covered) (_openingProse(l)?.heading ?? '').trim(),
      ];
      expect(headings.any((h) => h.isEmpty), isFalse);
      expect(
        headings.toSet().length,
        headings.length,
        reason: 'two lessons share an opening heading',
      );
    });
  });

  test('no opening carries an em or en dash', () {
    // House rule, and the openings are new prose, which is where it slips.
    for (final l in _covered) {
      final p = _openingProse(l)?.paragraphs.first ?? '';
      final h = _openingProse(l)?.heading ?? '';
      expect(p.contains('—') || p.contains('–'), isFalse, reason: l.id);
      expect(h.contains('—') || h.contains('–'), isFalse, reason: l.id);
    }
  });
}
