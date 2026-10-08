// Pan's empty states are DOORS, and they appear only when there is nothing
// to show (D30).
//
// Two halves, and the second is the one that matters most. A Pan that shows
// on an empty book is the feature; a Pan that ALSO shows over somebody's
// real money would push their figures down the screen to make room for a
// greeting they no longer need.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/pan_art.dart';
import 'package:salapify/features/log/log_sheet.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/pinned_app.dart';

void main() {
  testWidgets('an empty Home greets with Pan, and his button opens Log', (
    WidgetTester tester,
  ) async {
    final FinancialState s = await pumpSalapify(tester);
    s.removeSampleData();
    await tester.pumpAndSettle();
    expect(s.transactions, isEmpty);

    expect(find.byType(PanArt), findsOneWidget);
    final Finder door = find.text('Log your first entry');
    await tester.ensureVisible(door);
    await tester.pumpAndSettle();
    await tester.tap(door);
    await tester.pumpAndSettle();
    expect(
      find.byType(LogSheet),
      findsOneWidget,
      reason: 'the first-entry button did not open Log',
    );
  });

  testWidgets('a Home with entries shows no Pan at all', (
    WidgetTester tester,
  ) async {
    final FinancialState s = await pumpSalapify(tester);
    await tester.pumpAndSettle();
    expect(s.transactions, isNotEmpty);
    expect(find.byType(PanArt), findsNothing);
    expect(find.text('Log your first entry'), findsNothing);
  });
}
