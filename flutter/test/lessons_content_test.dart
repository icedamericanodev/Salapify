// The money courses content contract: 22 lessons in four tracks, every lesson
// complete and professional (required fields, an action with a known route,
// no em or en dashes anywhere), PH scoping exactly where the CPA review put
// it, the coach's deep links still resolving, and the corrected tax claims
// present so a regression back to the wrong rule fails loudly.

import 'package:flutter_test/flutter_test.dart';
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
}
