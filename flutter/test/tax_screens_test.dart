// The two tax screens: BIR dates and the year-end check.
//
// The math for both is golden locked elsewhere (taxdeadlines_golden_test.dart
// and phtax_golden_test.dart), so what is proven here is the half a golden
// file cannot see: that the screens read the engine rather than doing their
// own arithmetic, that the 8% choice actually changes the list AND survives,
// and that neither screen ever claims to be more than an estimate.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/tax_deadlines.dart';
import 'package:salapify/screens/year_end_tax.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tall surface, because both screens are longer than the 800x600 default
/// and a ListView never builds what is off screen. Without this the tests
/// were asserting on widgets that had simply not been created yet, which
/// looks exactly like missing copy.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 3400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<SalapifyStore> _store({Map<String, dynamic>? settings}) async {
  SharedPreferences.setMockInitialValues({
    storageKey: jsonEncode({
      'schemaVersion': 12,
      'settings': {'onboarded': true, ...?settings},
    }),
  });
  final s = SalapifyStore();
  await s.load();
  return s;
}

void main() {
  group('BIR dates', () {
    testWidgets('shows what is next, counted from today', (tester) async {
      // Pinned to the morning of April 15, when the annual return is due
      // TODAY. A screen that called that "missed" would be both wrong and
      // frightening, which is why the engine counts from local midnight.
      final store = await _store();
      _tall(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: TaxDeadlinesScreen(
            store: store,
            clock: () => DateTime(2026, 4, 15, 9, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Annual income tax'), findsOneWidget);
      expect(find.text('Due today'), findsOneWidget);
      expect(find.textContaining('Apr 15, 2026'), findsOneWidget);
    });

    testWidgets('the 8% choice drops the percentage tax rows and sticks', (
      tester,
    ) async {
      final store = await _store();
      _tall(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: TaxDeadlinesScreen(
            store: store,
            clock: () => DateTime(2026, 1, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Percentage tax'), findsWidgets);

      await tester.tap(find.text('Yes, 8%'));
      await tester.pumpAndSettle();
      expect(find.text('Percentage tax'), findsNothing);
      // Remembered, so the same person is not asked again next month.
      expect((store.data['settings'] as Map)['taxOnEightPercent'], true);
    });

    testWidgets('a remembered 8% choice is honoured on open', (tester) async {
      final store = await _store(settings: {'taxOnEightPercent': true});
      _tall(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: TaxDeadlinesScreen(
            store: store,
            clock: () => DateTime(2026, 1, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Percentage tax'), findsNothing);
    });

    testWidgets('it never claims to file anything', (tester) async {
      // The legal line, asserted rather than assumed. Salapify is awareness,
      // and a tax screen that reads like a filing service is the kind of
      // claim that ends a finance app on Google Play.
      final store = await _store();
      _tall(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: TaxDeadlinesScreen(
            store: store,
            clock: () => DateTime(2026, 4, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('does not file anything for you'),
        findsOneWidget,
      );
      // The second disclosure sits under six deadline cards, so it has to be
      // scrolled to. A ListView never builds what is off screen, and asserting
      // on an unbuilt widget looks exactly like missing copy.
      await tester.drag(find.byType(ListView), const Offset(0, -2400));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('moves to the next working day'),
        findsOneWidget,
      );
    });
  });

  group('year-end tax check', () {
    testWidgets('asks for a number before guessing at one', (tester) async {
      final store = await _store();
      _tall(tester);
      await tester.pumpWidget(
        MaterialApp(home: YearEndTaxScreen(store: store)),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Enter your monthly basic pay'),
        findsOneWidget,
      );
      expect(find.text('LIKELY REFUND'), findsNothing);
      expect(find.text('LIKELY STILL OWED'), findsNothing);
    });

    testWidgets('over-withholding reads as a refund', (tester) async {
      // 25,000 a month for the full year with a 13th month, and far more tax
      // withheld than the year actually asks for.
      final store = await _store();
      _tall(tester);
      await tester.pumpWidget(
        MaterialApp(home: YearEndTaxScreen(store: store)),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '25000');
      await tester.enterText(fields.at(4), '50000');
      await tester.pumpAndSettle();

      expect(find.text('LIKELY REFUND'), findsOneWidget);
      expect(find.text('LIKELY STILL OWED'), findsNothing);
    });

    testWidgets('under-withholding reads as still owed', (tester) async {
      final store = await _store();
      _tall(tester);
      await tester.pumpWidget(
        MaterialApp(home: YearEndTaxScreen(store: store)),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '80000');
      await tester.enterText(fields.at(4), '0');
      await tester.pumpAndSettle();

      expect(find.text('LIKELY STILL OWED'), findsOneWidget);
      expect(find.text('LIKELY REFUND'), findsNothing);
    });

    testWidgets('junk in the fields never crashes the screen', (tester) async {
      final store = await _store();
      _tall(tester);
      await tester.pumpWidget(
        MaterialApp(home: YearEndTaxScreen(store: store)),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '25,000');
      await tester.enterText(fields.at(1), 'abc');
      await tester.enterText(fields.at(2), '-4');
      await tester.enterText(fields.at(3), '');
      await tester.enterText(fields.at(4), '1e309');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // A comma-typed 25,000 is still 25,000, so the estimate still shows.
      expect(
        find.textContaining('LIKELY'),
        findsOneWidget,
        reason: 'a readable basic pay must still produce an answer',
      );
    });

    testWidgets('it says plainly that it is not a Form 2316', (tester) async {
      final store = await _store();
      _tall(tester);
      await tester.pumpWidget(
        MaterialApp(home: YearEndTaxScreen(store: store)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '25000');
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -2400));
      await tester.pumpAndSettle();
      expect(find.textContaining('not your Form 2316'), findsOneWidget);
    });
  });
}
