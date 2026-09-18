// Phase 5 hardening: the month pulse leads as a raised hero, shows its
// confidence, and the attention read carries its number.
//  1. The engine's overspend pulse states the magnitude (not "running
//     ahead"), and its confidence is a fact.
//  2. On screen, the pulse hero renders the fact/trend confidence cue that
//     was computed-and-discarded in the draft.
//  3. The pulse leads the screen: it sits above DO NEXT.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/insight_feed.dart' as feed;
import 'package:salapify/screens/insights.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A month where spending has clearly passed income, past mid-month so the
/// read is honest: the attention pulse.
Map<String, Object> _overspendStore() {
  final now = DateTime.now();
  final mid = DateTime(now.year, now.month, 16);
  return {
    storageKey: jsonEncode({
      'schemaVersion': 12,
      'settings': {'onboarded': true},
      'accounts': [
        {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 4000},
      ],
      'transactions': [
        {
          'id': 'inc',
          'type': 'income',
          'label': 'Sweldo',
          'amount': 5000,
          'date': _iso(DateTime(mid.year, mid.month, 1)),
          'accountId': 'cash',
        },
        {
          'id': 'exp',
          'type': 'expense',
          'label': 'Rent',
          'amount': 7500,
          'date': _iso(DateTime(mid.year, mid.month, 3)),
          'accountId': 'cash',
        },
      ],
    }),
  };
}

void main() {
  test('the overspend pulse names its magnitude and states it as a fact', () {
    final now = DateTime.now();
    final data = jsonDecode((_overspendStore()[storageKey]) as String);
    final pulse = feed.monthPulse(
      (data as Map).cast<String, dynamic>(),
      DateTime(now.year, now.month, 16),
    );
    expect(pulse, isNotNull);
    expect(pulse!.tone, 'attention');
    expect(pulse.confidence, 'fact');
    // 7500 out on 5000 in is 50% more out than in: the number must be in the
    // words, not "running ahead of income".
    expect(pulse.detail, contains('50%'));
    expect(pulse.detail.toLowerCase(), isNot(contains('running ahead')));
  });

  testWidgets('the pulse leads the screen as a raised hero with its '
      'confidence cue', (tester) async {
    SharedPreferences.setMockInitialValues(_overspendStore());
    final store = SalapifyStore();
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        home: InsightsScreen(store: store, onSwitchTab: (_) {}, onMenu: () {}),
      ),
    );
    await tester.pumpAndSettle();

    // The confidence cue is shown, not discarded.
    expect(find.text('This month so far'), findsOneWidget);
    // The attention headline and its number are on screen.
    expect(
      find.text('You have spent more than you earned this month.'),
      findsOneWidget,
    );

    // The pulse leads: its headline sits ABOVE the DO NEXT kicker.
    final heroY = tester
        .getTopLeft(
          find.text('You have spent more than you earned this month.'),
        )
        .dy;
    final doNextY = tester.getTopLeft(find.text('DO NEXT')).dy;
    expect(
      heroY,
      lessThan(doNextY),
      reason: 'the financial pulse is the first thing seen, above DO NEXT',
    );
  });
}
