// Falsy-typed names from hand-edited backups, the two QA divergences: a
// numeric 0 or false category name or label must fold into Other exactly
// like RN String(x || ''), and a falsy goal name must never match a zero in
// the message. Expected values come from executing the real RN modules.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/pan/ask.dart';
import 'package:salapify/money/recap.dart';

void main() {
  final now = DateTime(2026, 7, 18, 12);

  test('falsy category names and labels fold into Other like RN', () {
    final recap = monthRecap({
      'categories': [
        {'id': 'c1', 'name': 0},
      ],
      'transactions': [
        {'type': 'expense', 'categoryId': 'c1', 'label': 'FallbackLabel', 'amount': 100, 'date': '2026-07-10'},
        {'type': 'expense', 'label': 0, 'amount': 120, 'date': '2026-07-11'},
        {'type': 'expense', 'label': false, 'amount': 80, 'date': '2026-07-12'},
      ],
    }, now);
    final topCats = (recap['topCats'] as List).cast<Map<String, dynamic>>();
    expect(topCats.length, 2);
    expect(topCats[0]['label'], 'Other');
    expect(topCats[0]['amount'], 200.0);
    expect((topCats[0]['pct'] as num).toDouble(), 67.0);
    expect(topCats[1]['label'], 'FallbackLabel');
    expect((topCats[1]['pct'] as num).toDouble(), 33.0);
  });

  test('a falsy goal name never matches a zero in the message', () {
    final reply = ask({
      'goals': [
        {'name': 'Vacation', 'target': 1000, 'saved': 100, 'targetDate': '2026-01'},
        {'name': 0, 'target': 2000, 'saved': 1900},
      ],
    }, 'is my 0 goal on track', now: now);
    // RN coaches the behind Vacation goal, never the junk-named one.
    expect(reply['mood'], 'worried');
    expect(reply['text'],
        'Vacation is 10%, and the target date has passed with ₱900 still to go. Set a fresh date and I will give you a new weekly pace.');
  });
}
