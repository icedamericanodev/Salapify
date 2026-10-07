// Content guards for the Financial Guides catalog (lib/content/financial_
// guides.dart). These are the invariants the screens rely on, proven against
// the real set so a bad edit reddens the build instead of reaching a phone.
//
// Facts inside a guide are checked for accuracy by the reviewing agents and
// against the source lessons, not here; this file guards SHAPE: ids, icons,
// categories, reading time, the popular ordering, the deep links, and the
// no em or en dash rule the whole app follows.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/financial_guides.dart';
import 'package:salapify/content/lessons.dart' show lessonById;
import 'package:salapify/widgets/salapify_icon.dart';

void main() {
  final guides = allFinancialGuides;

  // Every visible string a guide carries, in one place, so the dash and
  // emptiness checks cannot miss a field.
  Iterable<String> textsOf(dynamic g) sync* {
    yield g.title as String;
    yield g.summary as String;
    yield g.keyTakeaway as String;
    for (final s in g.sections) {
      yield s.heading as String;
      yield* (s.paragraphs as List).cast<String>();
    }
  }

  group('the catalog is a real, usable set', () {
    test('it is not empty and is a sensible size', () {
      expect(guides.length, greaterThanOrEqualTo(20));
    });

    test('every id is unique and kebab-case', () {
      final ids = guides.map((g) => g.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate guide id');
      for (final id in ids) {
        expect(
          RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(id),
          isTrue,
          reason: 'id "$id" is not kebab-case',
        );
      }
    });

    test('guideById round-trips every id and misses unknown ones', () {
      for (final g in guides) {
        expect(guideById(g.id), same(g));
      }
      expect(guideById('definitely-not-a-guide'), isNull);
    });
  });

  group('every guide is well formed', () {
    test('titles, summaries, takeaways, and sections are non-empty', () {
      for (final g in guides) {
        expect(g.title.trim(), isNotEmpty, reason: '${g.id} title');
        expect(g.summary.trim(), isNotEmpty, reason: '${g.id} summary');
        expect(g.keyTakeaway.trim(), isNotEmpty, reason: '${g.id} takeaway');
        expect(g.sections, isNotEmpty, reason: '${g.id} has no sections');
        for (final s in g.sections) {
          expect(s.heading.trim(), isNotEmpty, reason: '${g.id} blank heading');
          expect(s.paragraphs, isNotEmpty, reason: '${g.id} empty section');
          for (final p in s.paragraphs) {
            expect(p.trim(), isNotEmpty, reason: '${g.id} blank paragraph');
          }
        }
      }
    });

    test('reading time is honest, 1 to 4 minutes', () {
      for (final g in guides) {
        expect(
          g.minutes,
          inInclusiveRange(1, 4),
          reason: '${g.id} minutes ${g.minutes}',
        );
      }
    });

    test('every icon name resolves to a real glyph, never the fallback', () {
      // The same technique icon_system_test uses: a name that cannot exist
      // returns the neutral fallback marker, so a real name must differ from
      // it. This is what stops a typo reaching the silent fallback on a card.
      final fallback = salapifyIcon('definitely-not-a-real-name-xyz');
      for (final g in guides) {
        expect(
          salapifyIcon(g.icon),
          isNot(equals(fallback)),
          reason: '${g.id} icon "${g.icon}" does not resolve',
        );
        expect(
          salapifyIconNames.contains(g.icon),
          isTrue,
          reason: '${g.id} icon "${g.icon}" is not a known name',
        );
      }
    });
  });

  group('no em or en dashes, same as all Salapify copy', () {
    test('not in any visible guide string', () {
      for (final g in guides) {
        for (final t in textsOf(g)) {
          expect(t.contains('—'), isFalse, reason: '${g.id} has an em dash');
          expect(t.contains('–'), isFalse, reason: '${g.id} has an en dash');
        }
      }
    });
  });

  group('categories', () {
    test('every category holds at least one guide', () {
      for (final cat in GuideCategory.values) {
        expect(
          guidesInCategory(cat),
          isNotEmpty,
          reason: 'category ${cat.label} is empty, its grid tile would read 0',
        );
        expect(guideCountFor(cat), guidesInCategory(cat).length);
      }
    });

    test('the counts sum to the whole catalog, nothing double-filed', () {
      final total = GuideCategory.values
          .map(guideCountFor)
          .fold<int>(0, (a, b) => a + b);
      expect(total, guides.length);
    });
  });

  group('the popular row', () {
    test('is non-empty and ranked 1..n with no gaps or ties', () {
      final popular = popularGuides();
      expect(popular, isNotEmpty);
      final ranks = popular.map((g) => g.popularRank!).toList();
      expect(ranks.toSet().length, ranks.length, reason: 'duplicate rank');
      for (var i = 0; i < ranks.length; i++) {
        expect(ranks[i], i + 1, reason: 'ranks must be contiguous from 1');
      }
    });
  });

  group('deep links', () {
    test('every deepDiveLessonId that is set resolves to a real lesson', () {
      for (final g in guides) {
        final id = g.deepDiveLessonId;
        if (id == null) continue;
        expect(
          lessonById(id),
          isNotNull,
          reason: '${g.id} deep-dives to "$id", which is not a lesson',
        );
      }
    });
  });

  group('sources', () {
    test('guides carry no official-source URLs of their own for launch', () {
      // The launch decision: guides distill facts from already-verified
      // lessons and link to the fully-cited course, rather than declaring new
      // government URLs that would each need independent search verification.
      // If this ever changes, the URL verification rule in CLAUDE.md applies.
      for (final g in guides) {
        expect(g.sources, isEmpty, reason: '${g.id} declares a source URL');
      }
    });
  });
}
