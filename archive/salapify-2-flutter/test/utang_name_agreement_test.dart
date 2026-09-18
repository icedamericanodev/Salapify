// Two rules for "whose utang is this", and they have to agree.
//
// utangAging decides which person row you see and how much that row says they
// owe. openUtangFor decides which utangs land in that person's sheet, and the
// sheet is what the statement and the reminder are built from. They resolve
// the name by two different pieces of code, so any disagreement shows up as a
// row saying ₱500 that opens onto nothing, or a document quietly leaving out
// money somebody actually owes.
//
// This was a named DEFERRED finding on f2.73 and it turned out to be real:
// a receivable whose person field is whitespace grouped under "Someone" in
// the total and matched nobody in the sheet.
//
// The rule is not "nameOf should be nicer". It is "nameOf must resolve the
// SAME name utangAging resolves", whatever that name is.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/receivables.dart' show nameOf, remainingOf;
import 'package:salapify/money/utang.dart';
import 'package:salapify/screens/utang.dart' show openUtangFor;

void main() {
  final ref = DateTime(2026, 7, 10);

  /// Every peso utangAging shows on a person row must be reachable from that
  /// person's own sheet. This is the property that matters; the individual
  /// cases below just feed it the shapes that used to break it.
  void agrees(Map<String, dynamic> data, {required String why}) {
    final aging = utangAging(data, ref);
    for (final p in (aging['people'] as List).cast<Map<String, dynamic>>()) {
      final rows = openUtangFor(
        data,
        p['name'] as String,
        personId: p['personId'] as String,
      );
      final inSheet = rows.fold<double>(
        0,
        (t, r) => t + remainingOf(r.cast<String, dynamic>()),
      );
      expect(
        inSheet,
        closeTo(p['outstanding'] as double, 0.005),
        reason:
            '$why: the row for "${p['name']}" says ${p['outstanding']} and '
            'their sheet adds up to $inSheet, so the difference is money the '
            'statement and the reminder will never mention',
      );
    }
  }

  test('a whitespace-only name is the same person to both rules', () {
    // The one QA found. utangAging trims before deciding the name is empty,
    // so it falls through to "Someone". nameOf checked isNotEmpty on the raw
    // string, and "   " is not empty, so it returned the spaces. The row was
    // in the total and in no sheet at all.
    final data = <String, dynamic>{
      'people': <dynamic>[],
      'receivables': [
        {'id': 'r1', 'person': '   ', 'amount': 500, 'dueDate': '2026-07-01'},
        {'id': 'r2', 'person': 'Ana', 'amount': 200, 'dueDate': '2026-07-02'},
      ],
    };
    agrees(data, why: 'whitespace-only person');
  });

  test('a padded name is the same person to both rules', () {
    // utangAging groups on the TRIMMED name, so " Ana " and "Ana" are one
    // person with one total. The sheet has to gather both.
    final data = <String, dynamic>{
      'people': <dynamic>[],
      'receivables': [
        {'id': 'r1', 'person': ' Ana ', 'amount': 500, 'dueDate': '2026-07-01'},
        {'id': 'r2', 'person': 'Ana', 'amount': 200, 'dueDate': '2026-07-02'},
      ],
    };
    agrees(data, why: 'padded name');
    expect(utangAging(data, ref)['people'], hasLength(1));
  });

  test('a person record whose name is blank falls through the same way', () {
    final data = <String, dynamic>{
      'people': [
        {'id': 'p1', 'name': '   '},
      ],
      'receivables': [
        {
          'id': 'r1',
          'personId': 'p1',
          'person': 'Ana',
          'amount': 500,
          'dueDate': '2026-07-01',
        },
      ],
    };
    agrees(data, why: 'blank person record');
    expect(nameOf(data, {'personId': 'p1', 'person': 'Ana'}), 'Ana');
  });

  test('two person records sharing an id resolve to the same one', () {
    // A backup can carry duplicates. utangAging builds a Map, so the LAST
    // entry wins; nameOf used firstWhere, so the FIRST did. One renamed
    // person and the sheet is empty.
    final data = <String, dynamic>{
      'people': [
        {'id': 'p1', 'name': 'Old name'},
        {'id': 'p1', 'name': 'New name'},
      ],
      'receivables': [
        {'id': 'r1', 'personId': 'p1', 'amount': 500, 'dueDate': '2026-07-01'},
      ],
    };
    agrees(data, why: 'duplicate person id');
    expect(
      nameOf(data, {'personId': 'p1'}),
      'New name',
      reason: 'utangAging shows the last one, so this must too',
    );
  });

  test('the ordinary cases still work', () {
    // The half that proves the four above are agreements and not just both
    // rules returning nothing.
    final data = <String, dynamic>{
      'people': [
        {'id': 'p1', 'name': 'Ana'},
      ],
      'receivables': [
        {'id': 'r1', 'personId': 'p1', 'amount': 500, 'dueDate': '2026-07-01'},
        {'id': 'r2', 'person': 'Ben', 'amount': 200, 'dueDate': '2026-07-02'},
        {
          'id': 'r3',
          'personId': 'p1',
          'amount': 300,
          'dueDate': '2026-07-03',
          'payments': [
            {'id': 'x', 'amount': 100},
          ],
        },
      ],
    };
    agrees(data, why: 'ordinary data');
    final aging = utangAging(data, ref);
    expect(aging['totalOutstanding'], 900);
    expect((aging['people'] as List), hasLength(2));
  });
}
