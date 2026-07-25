// The money courses content contract: 22 lessons in four tracks, every lesson
// complete and professional (required fields, an action with a known route,
// no em or en dashes anywhere), PH scoping exactly where the CPA review put
// it, the coach's deep links still resolving, and the corrected tax claims
// present so a regression back to the wrong rule fails loudly.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons.dart';

// Every route the Learn action resolver knows how to run.
const _knownRoutes = {
  'log',
  'mindset',
  'budget-tab',
  'recurring',
  'goals',
  'debts',
  'utang-tab',
  'insights-tab',
  'cashflow',
  'notes',
  'paluwagan',
  'tools-bnpl',
  'tools-tax',
  'tools-contrib',
  'tools-thirteenth',
  'tools-salary',
};

void main() {
  test('22 lessons, unique ids, four tracks with the designed sizes', () {
    expect(lessons.length, 22);
    final ids = lessons.map((l) => l['id']).toSet();
    expect(ids.length, 22, reason: 'ids must be unique');
    expect(courseTracks.length, 4);
    expect(lessonsForTrack('cushion').length, 6);
    expect(lessonsForTrack('debt').length, 6);
    expect(lessonsForTrack('swing').length, 5);
    expect(lessonsForTrack('moments').length, 5);
    // Every lesson belongs to a real track.
    final trackKeys = courseTracks.map((t) => t['key']).toSet();
    for (final l in lessons) {
      expect(
        trackKeys.contains(l['track']),
        isTrue,
        reason: '${l['id']} has an unknown track',
      );
    }
  });

  test('every lesson is complete and its action route is runnable', () {
    for (final l in lessons) {
      for (final field in [
        'id',
        'title',
        'emoji',
        'minutes',
        'summary',
        'body',
      ]) {
        expect(l[field], isNotNull, reason: '${l['id']} missing $field');
      }
      expect((l['minutes'] as int) > 0, isTrue);
      expect((l['body'] as List).isNotEmpty, isTrue);
      final action = l['action'] as Map?;
      expect(
        action,
        isNotNull,
        reason: '${l['id']} must end in one in-app action',
      );
      expect(
        _knownRoutes.contains(action!['route']),
        isTrue,
        reason: '${l['id']} action route ${action['route']} is unknown',
      );
      expect((action['label'] as String).isNotEmpty, isTrue);
    }
  });

  test('no em or en dashes anywhere in the content', () {
    for (final l in lessons) {
      final all = [
        l['title'],
        l['summary'],
        ...(l['body'] as List),
        (l['action'] as Map)['label'],
      ].join(' ');
      expect(all.contains('—'), isFalse, reason: '${l['id']} em dash');
      expect(all.contains('–'), isFalse, reason: '${l['id']} en dash');
    }
  });

  test('PH scoping sits exactly where the CPA review put it', () {
    final ph = lessons.where((l) => l['region'] == 'PH').map((l) => l['id']);
    expect(ph.toSet(), {
      'tax-forms',
      'year-end-refund',
      'freelancer-setaside',
      'thirteenth-month',
      'own-your-benefits',
    });
    // Each PH lesson opens by scoping itself so a global reader is never
    // misled into thinking the rules apply to them.
    for (final l in lessons.where((l) => l['region'] == 'PH')) {
      final opener = ((l['body'] as List).first as String).toLowerCase();
      expect(
        opener.contains('philippine'),
        isTrue,
        reason: '${l['id']} must scope itself in its first paragraph',
      );
    }
  });

  test('the coach deep links still resolve', () {
    for (final id in [
      'thirteenth-month',
      'card-interest',
      'bnpl',
      'utang-friends',
    ]) {
      expect(lessonById(id), isNotNull, reason: 'coach links to $id');
    }
  });

  test('the corrected tax rules are present (CPA regression pins)', () {
    final freelancer = lessonById('freelancer-setaside')!;
    final text = (freelancer['body'] as List).join(' ');
    expect(
      text,
      contains('if freelancing is your ONLY income'),
      reason: 'the 250k exemption must stay scoped to pure self-employment',
    );
    expect(
      text,
      contains('not VAT registered'),
      reason: 'the 8 percent option requires no VAT registration',
    );
    final forms = lessonById('tax-forms')!;
    expect(
      (forms['body'] as List).join(' '),
      contains('any 12 month period'),
      reason: 'the VAT threshold is any 12 months, not a calendar year',
    );
    // The lending rule stays at its honest strength.
    final utang = lessonById('utang-friends')!;
    expect(
      (utang['body'] as List).join(' '),
      contains('okay never getting back'),
    );
  });

  test('lessonOfTheDay is stable within a day and in range', () {
    final a = lessonOfTheDay(DateTime(2026, 7, 24, 1));
    final b = lessonOfTheDay(DateTime(2026, 7, 24, 23));
    expect(a['id'], b['id']);
    expect(lessons.contains(a), isTrue);
  });

  test('every lesson is authored in the coaching shape', () {
    // The redesign is only real if it reaches all 22. A lesson without
    // authored blocks silently falls back to the derived prose rendering,
    // which looks fine and is exactly the half-done state this pins against.
    for (final raw in lessons) {
      final l = lessonFromMap(raw);
      expect(
        l.authoredBlocks,
        isNotEmpty,
        reason: '${l.id} is still rendering from the old fields',
      );
      expect(
        l.blocks.last,
        isA<ReflectionBlock>(),
        reason: '${l.id} must end on one sentence worth keeping',
      );
    }
  });

  test('no em or en dashes in the block content either', () {
    // The older check only scanned body. Blocks are user-facing copy too, and
    // the house rule has no exceptions.
    for (final raw in lessons) {
      final l = lessonFromMap(raw);
      final buf = StringBuffer();
      for (final b in l.blocks) {
        switch (b) {
          case ProseBlock(:final heading, :final paragraphs):
            buf.writeAll([heading, ...paragraphs], ' ');
          case RulesBlock(:final passages):
            buf.writeAll(passages, ' ');
          case NuggetsBlock(:final items):
            buf.writeAll(items, ' ');
          case DiscoveryBlock(:final question, :final reveal):
            buf.writeAll([question, reveal], ' ');
          case StoryBlock(:final who, :final text):
            buf.writeAll([who, text], ' ');
          case DiagramBlock(:final steps, :final caption):
            buf.writeAll([...steps, caption], ' ');
          case TrapBlock(:final mostPeople, :final worksBetter):
            buf.writeAll([mostPeople, worksBetter], ' ');
          case ChallengeBlock(:final prompt, :final compare):
            buf.writeAll([prompt, compare], ' ');
          case ReflectionBlock(:final line):
            buf.write(line);
        }
      }
      final all = buf.toString();
      expect(all.contains('\u2014'), isFalse, reason: '${l.id} em dash');
      expect(all.contains('\u2013'), isFalse, reason: '${l.id} en dash');
    }
  });

  test('no lesson says the same sentence twice', () {
    // Half of a real bug the founder found by screenshot. The tax lessons
    // printed three sentences a second time, a paragraph or two later,
    // because a coaching line and the reference prose were written from the
    // same source and nothing compared them.
    //
    // This is the half a machine CAN check. The other half, whether a block
    // reads as a wall of text, needs eyes, and that is what
    // test/screens_shot.dart is for.
    for (final raw in lessons) {
      final l = lessonFromMap(raw);
      final seen = <String, int>{};
      for (final s in _allSentences(l)) {
        // Short fragments repeat legitimately: a heading, a label, a nudge
        // like "Try it now". Only meaningful sentences are worth flagging.
        if (s.length < 40) continue;
        seen[s] = (seen[s] ?? 0) + 1;
      }
      final twice = seen.entries.where((e) => e.value > 1).toList();
      expect(
        twice,
        isEmpty,
        reason:
            '${l.id} repeats a sentence, which reads as padding: '
            '${twice.map((e) => e.key).join(' | ')}',
      );
    }
  });
}

/// Every user-facing sentence of a lesson, normalized enough that the same
/// sentence written with different spacing or casing still counts as the same
/// sentence. Splitting on sentence enders rather than on blocks is the point:
/// the duplicate that reached the phone was one sentence lifted out of a
/// paragraph, not a whole repeated block.
Iterable<String> _allSentences(MoneyLesson l) {
  final buf = StringBuffer();
  for (final b in l.blocks) {
    switch (b) {
      case ProseBlock(:final heading, :final paragraphs):
        buf.writeAll([heading, ...paragraphs], ' ');
      case RulesBlock(:final passages):
        buf.writeAll(passages, ' ');
      case NuggetsBlock(:final items):
        buf.writeAll(items, ' ');
      case DiscoveryBlock(:final question, :final reveal):
        buf.writeAll([question, reveal], ' ');
      case StoryBlock(:final who, :final text):
        buf.writeAll([who, text], ' ');
      case DiagramBlock(:final steps, :final caption):
        buf.writeAll([...steps, caption], ' ');
      case TrapBlock(:final mostPeople, :final worksBetter):
        buf.writeAll([mostPeople, worksBetter], ' ');
      case ChallengeBlock(:final prompt, :final compare):
        buf.writeAll([prompt, compare], ' ');
      case ReflectionBlock(:final line):
        buf.write(line);
    }
    buf.write(' ');
  }
  return buf
      .toString()
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '))
      .where((s) => s.isNotEmpty);
}
