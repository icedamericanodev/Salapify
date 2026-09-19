import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/settings/import_sheet.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// The screen in front of the most destructive action in the app.
void main() {
  const String realBackup =
      '{"schemaVersion":1,'
      '"accounts":[{"id":"a1","name":"Their BPI","kind":"bank",'
      '"institution":"BPI","balance":71940,"monogram":"BPI"}],'
      '"transactions":[],"debts":[],"budgets":[],"goals":[],'
      '"upcoming":[],"incomeStreams":[],"installments":[],'
      '"reconciliations":[],"bills":[],'
      '"timestamp":"2026-09-12T08:00:00.000Z"}';

  Future<FinancialState> pump(WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 2900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final MemorySnapshotStore store = MemorySnapshotStore();
    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 19),
      store: store,
    );
    await state.restore();

    final Palette p = Palette.of(state.theme);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(p, state.theme),
        home: Scaffold(
          backgroundColor: p.background,
          body: ImportSheet(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> paste(WidgetTester tester, String raw) async {
    await tester.tap(find.text('Paste a backup instead'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), raw);
    await tester.tap(find.text('Read what I pasted'));
    await tester.pumpAndSettle();
  }

  testWidgets('the confirmation names BOTH ledgers, in pesos', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    await paste(tester, realBackup);

    await tester.tap(find.text('Replace everything with this backup'));
    await tester.pumpAndSettle();

    // "Are you sure?" over a destructive action is a question nobody can
    // answer. This is what makes it answerable.
    expect(find.textContaining('Out:'), findsOneWidget);
    expect(find.textContaining('In:'), findsOneWidget);
    expect(
      find.textContaining('₱71,940.00'),
      findsWidgets,
      reason: 'the incoming ledger is not described in money',
    );
    expect(find.textContaining('This is not a merge'), findsOneWidget);
  });

  testWidgets(
    'a file that is not a backup is refused, and says nothing changed',
    (WidgetTester tester) async {
      final FinancialState state = await pump(tester);
      final int before = state.accounts.length;

      await paste(tester, '{"photo": {"width": 100}}');

      expect(find.textContaining('not a Salapify backup'), findsOneWidget);
      expect(
        find.text('Nothing on this phone has changed.'),
        findsOneWidget,
        reason:
            'the first question after a red box in a money app is whether it '
            'broke something',
      );
      expect(state.accounts.length, before);
    },
  );

  testWidgets('a prototype backup names what it does not contain', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    await paste(
      tester,
      '{"accounts":[],"transactions":[],"debts":[],"budgets":[],'
      '"goals":[],"upcoming":[],"incomeStreams":[]}',
    );

    expect(
      find.textContaining('does not contain'),
      findsOneWidget,
      reason:
          'the missing collections come back empty, which moves Safe to '
          'Spend, and an unexplained move in the headline figure is the '
          'defect this app keeps relearning',
    );
    expect(find.textContaining('payment plans'), findsOneWidget);
  });

  testWidgets('the sample data warning shows on a seeded phone', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    await paste(tester, realBackup);

    expect(
      find.textContaining('None of it is yours'),
      findsOneWidget,
      reason:
          'without it a brand new user thinks they are destroying something '
          'of their own',
    );
  });

  testWidgets('cancelling changes nothing', (WidgetTester tester) async {
    final FinancialState state = await pump(tester);
    final String beforeId = state.accounts.first.id;

    await paste(tester, realBackup);
    await tester.tap(find.text('Replace everything with this backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep what I have'));
    await tester.pumpAndSettle();

    expect(state.accounts.first.id, beforeId);
  });

  testWidgets('confirming replaces the ledger and offers the way back', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await pump(tester);

    await paste(tester, realBackup);
    await tester.tap(find.text('Replace everything with this backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace it'));
    await tester.pumpAndSettle();

    expect(state.accounts.single.id, 'a1');
    expect(
      find.text('Put the earlier ledger back'),
      findsOneWidget,
      reason: 'the undo is not on screen, so the promise made was not kept',
    );
  });
}
