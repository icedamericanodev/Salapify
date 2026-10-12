// The Health check sheet and the dot on Home that opens it give ONE answer.
//
// Found by the ledger-reconciler on 2026-10-10. The sheet ran its own copy
// of the health check with only the built-in bills, while the dot (and Pan)
// read the store's report, which since D32 also counts the bills a person
// adds. With a 150,000 tuition bill due before payday the dot was red and
// said "84,989.40 short", and the sheet it opened said "Covered for the next
// 12 days".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/health_check.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/health/health_check_sheet.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/test_clock.dart';

void main() {
  testWidgets('a large added bill makes the sheet say short, like the dot', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final FinancialState state = FinancialState(
      clock: testToday,
      store: MemorySnapshotStore(),
    );
    await state.restore();
    state.startWithExampleData();
    state.addUpcoming(
      const UpcomingItem(
        id: 'up_tuition',
        name: 'Tuition, first semester',
        amount: Money.pesos(150000),
        dueDate: '2026-09-21',
        type: UpcomingItemType.tuition,
      ),
    );

    // What the dot reads. Directional: the added bill made it short.
    final List<String> readings = state.healthReport.indicators
        .map((HealthIndicator i) => i.reading ?? '')
        .toList();
    final String short = readings.firstWhere(
      (String r) => r.contains('short'),
      orElse: () => '',
    );
    expect(short, isNotEmpty, reason: 'the store did not count the bill');

    final Palette p = Palette.of(state.theme);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(p, state.theme),
        home: Scaffold(
          body: SingleChildScrollView(
            child: HealthCheckSheet(palette: p, state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(short), findsWidgets);
    expect(
      find.textContaining('Covered for the next'),
      findsNothing,
      reason: 'the sheet answered from a different list of bills than the dot',
    );
  });
}
