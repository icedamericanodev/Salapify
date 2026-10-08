// Activity rows wear their category's emoji, so a day of entries can be
// scanned by eye instead of reading every line.
//
// Found by the UI review of 2026-10-07: every spending row carried the same
// arrow tile. The emoji is the user's own category icon, so it stays an
// emoji. A transfer keeps its swap arrow, because it has no category worth
// showing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/activity/day_group.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/pinned_app.dart';

Finder _row(String merchant) => find.ancestor(
  of: find.text(merchant),
  matching: find.byType(TransactionRow),
);

void main() {
  testWidgets('a spending row shows its category emoji, a transfer does not', (
    WidgetTester tester,
  ) async {
    final FinancialState s = await pumpSalapify(tester);
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();

    final Transaction food = s.transactions.firstWhere(
      (Transaction t) =>
          t.type == TransactionType.expense && t.merchant == 'Jollibee',
    );
    final String emoji = s.categories
        .firstWhere((CategoryInfo c) => c.name == food.category)
        .emoji;

    await tester.scrollUntilVisible(
      _row('Jollibee'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(of: _row('Jollibee'), matching: find.text(emoji)),
      findsOneWidget,
      reason: 'the Food & Dining row did not show its emoji',
    );
    // DIRECTIONAL: the old arrow is gone from that row, not merely joined.
    expect(
      find.descendant(
        of: _row('Jollibee'),
        matching: find.byIcon(Icons.north_east),
      ),
      findsNothing,
    );

    await tester.scrollUntilVisible(
      _row('Top up GCash'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(
        of: _row('Top up GCash'),
        matching: find.byIcon(Icons.swap_horiz),
      ),
      findsOneWidget,
      reason: 'a transfer lost its swap arrow',
    );
  });
}
