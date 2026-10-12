// Regression tests for the independent QA review of Pan, 2026-10-08. Each
// one guards a finding that was confirmed against the code before it was
// fixed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/design/pan_art.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/debt/debt_screen.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/pinned_app.dart';

Widget _content({bool reduce = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: const Scaffold(
      body: Center(
        child: PanEmptyContent(
          mood: PanMood.wave,
          title: Text('Nothing logged yet'),
          body: Text('Tap Log to record your first expense.'),
        ),
      ),
    ),
  ),
);

double _lean(WidgetTester tester) =>
    tester.widget<Transform>(find.byKey(panDragKey)).transform.entry(0, 3);

void main() {
  testWidgets('reduce motion switched on and off again does not crash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_content());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(_content(reduce: true));
    await tester.pump();
    await tester.pumpWidget(_content());
    await tester.pump();
    expect(tester.takeException(), isNull);
    // And the motion really came back.
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('a screen reader hears the text while it is still fading in', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(_content());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.bySemanticsLabel('Nothing logged yet'), findsOneWidget);
    handle.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('the drag lean is the same however often the finger reports', (
    WidgetTester tester,
  ) async {
    Future<double> dragIn(int steps) async {
      await tester.pumpWidget(_content());
      await tester.pumpAndSettle();
      final TestGesture g = await tester.startGesture(
        tester.getCenter(find.byType(PanArt)),
      );
      // Past the drag slop first, so every later step counts.
      await g.moveBy(const Offset(20, 0));
      await tester.pump();
      for (int i = 0; i < steps; i++) {
        await g.moveBy(Offset(60 / steps, 0));
        await tester.pump();
      }
      final double lean = _lean(tester);
      await g.up();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      return lean;
    }

    final double coarse = await dragIn(4);
    final double fine = await dragIn(60);
    expect(coarse, greaterThan(10), reason: 'the drag did not move him');
    expect(
      fine,
      closeTo(coarse, 0.5),
      reason: 'the same finger travel leaned him by a different amount',
    );
  });

  testWidgets('no calm Pan while a card balance is still owed', (
    WidgetTester tester,
  ) async {
    final FinancialState s = await pumpSalapify(tester);
    s.removeSampleData();
    Widget debts() => MaterialApp(
      home: Scaffold(
        backgroundColor: Palette.of(s.theme).background,
        body: DebtScreen(state: s),
      ),
    );
    await tester.pumpWidget(debts());
    await tester.pumpAndSettle();
    // DIRECTIONAL: an empty book does get the calm all-clear.
    expect(find.byType(PanArt), findsOneWidget);

    s.addAccount(
      const Account(
        id: 'acc_card',
        name: 'Credit card',
        kind: AccountKind.credit,
        institution: 'Bank',
        balance: Money.pesos(5000),
        monogram: 'CC',
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(debts());
    await tester.pumpAndSettle();
    expect(find.text('You owe nobody anything'), findsOneWidget);
    expect(
      find.byType(PanArt),
      findsNothing,
      reason: 'calm Pan said all clear over an unpaid card',
    );
  });
}
