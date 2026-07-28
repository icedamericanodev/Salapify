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

    testWidgets('the 8% choice keeps last year\'s quarter and sticks', (
      tester,
    ) async {
      // A tax professional's MUST FIX. The 8% election is per taxable year,
      // so someone on graduated rates last year still files the October to
      // December 2551Q on January 25. Telling them it is "not yours to file"
      // costs a 25% surcharge plus 12% interest.
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

      await tester.tap(find.text('8% option'));
      await tester.pumpAndSettle();
      expect(
        find.text('Percentage tax'),
        findsOneWidget,
        reason: 'the January row survives the election',
      );
      expect(find.textContaining('LAST year'), findsOneWidget);
      // Remembered WITH the year, because the election expires.
      expect((store.data['settings'] as Map)['taxBasis'], 'eight');
      expect((store.data['settings'] as Map)['taxBasisYear'], 2026);
    });

    testWidgets('a remembered choice is honoured, and expires with the year', (
      tester,
    ) async {
      final store = await _store(
        settings: {'taxBasis': 'eight', 'taxBasisYear': 2026},
      );
      _tall(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: TaxDeadlinesScreen(
            store: store,
            clock: () => DateTime(2026, 6, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Mid year, on 8%: no April, July or October percentage tax rows.
      expect(find.text('Percentage tax'), findsNothing);

      // Next year the same stored answer must NOT be trusted, because the
      // election covers one year at a time.
      await tester.pumpWidget(
        MaterialApp(
          home: TaxDeadlinesScreen(
            store: store,
            clock: () => DateTime(2027, 6, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Percentage tax'), findsWidgets);
      expect(find.textContaining('covers one year at a time'), findsOneWidget);
    });

    testWidgets('a VAT filer is never told to file a percentage tax', (
      tester,
    ) async {
      // Section 116 applies only to persons who are NOT VAT registered.
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
      await tester.tap(find.text('VAT registered'));
      await tester.pumpAndSettle();
      expect(find.text('Percentage tax'), findsNothing);
      expect(find.text('VAT return'), findsWidgets);
      expect(
        find.textContaining('does not compute the 12% VAT'),
        findsOneWidget,
      );
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

    testWidgets('no verdict until the withheld figure is entered', (
      tester,
    ) async {
      // A tax professional's MUST FIX, and the state most users would have
      // seen first: typing only a salary produced "LIKELY STILL OWED" and a
      // peso figure, because withheld defaulted to zero. That is a false
      // statement of a tax position, shown by default, to everyone.
      final store = await _store();
      _tall(tester);
      await tester.pumpWidget(
        MaterialApp(home: YearEndTaxScreen(store: store)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '25000');
      await tester.pumpAndSettle();
      expect(find.textContaining('LIKELY'), findsNothing);
      expect(find.textContaining('Enter the tax withheld'), findsOneWidget);
      // The breakdown is still allowed: it states what the year asks for,
      // which is true without knowing what was withheld. It sits below the
      // fields, so it has to be scrolled to before it exists.
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.text('HOW THAT ADDS UP'), findsOneWidget);
    });

    testWidgets('an exactly square year says so, rather than owing zero', (
      tester,
    ) async {
      final store = await _store();
      _tall(tester);
      await tester.pumpWidget(
        MaterialApp(home: YearEndTaxScreen(store: store)),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '25000');
      await tester.enterText(fields.at(4), '3765');
      await tester.pumpAndSettle();
      expect(find.text('YOU ARE SQUARE'), findsOneWidget);
      expect(find.textContaining('LIKELY'), findsNothing);
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

    testWidgets('a number it cannot read is said out loud, not guessed', (
      tester,
    ) async {
      // A tax professional's MUST FIX, twice over. Pasting "₱12,500" from a
      // payslip used to read as zero and announce "LIKELY STILL OWED" to
      // somebody who had overpaid; typing "6 months" became one month and
      // overstated a refund twelvefold. Both were silent.
      final store = await _store();
      _tall(tester);
      await tester.pumpWidget(
        MaterialApp(home: YearEndTaxScreen(store: store)),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '25000');
      await tester.enterText(fields.at(4), '₱12,500');
      await tester.pumpAndSettle();
      expect(find.textContaining('not a number I can read'), findsOneWidget);
      expect(find.textContaining('tax withheld'), findsWidgets);
      expect(
        find.textContaining('LIKELY'),
        findsNothing,
        reason: 'no verdict may be built on a figure the app misread',
      );

      // And the months field, which is where the twelvefold error lived.
      await tester.enterText(fields.at(4), '30000');
      await tester.enterText(fields.at(2), '6 months');
      await tester.pumpAndSettle();
      expect(find.textContaining('months worked'), findsWidgets);
      expect(find.textContaining('LIKELY'), findsNothing);

      // Corrected, the estimate comes back.
      await tester.enterText(fields.at(2), '6');
      await tester.pumpAndSettle();
      expect(find.textContaining('not a number I can read'), findsNothing);
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
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      // Junk in three fields now produces one honest sentence rather than a
      // confident wrong answer. It is still the case that nothing crashes,
      // which is what this test is named for.
      expect(find.textContaining('not numbers I can read'), findsOneWidget);
      expect(find.textContaining('LIKELY'), findsNothing);
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
