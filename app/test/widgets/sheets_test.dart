import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/format.dart';
import 'package:salapify/features/categories/category_manager_sheet.dart';
import 'package:salapify/features/debt/add_debt_sheet.dart';
import 'package:salapify/features/safe_to_spend/safe_to_spend_sheet.dart';
import 'package:salapify/features/tax/business_tax_sheet.dart';
import 'package:salapify/features/tax/tax_calculator_sheet.dart';
import 'package:salapify/features/toolkit/toolkit_sheet.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/home/debt_beam_card.dart';
import 'package:salapify/screens/home/home_screen.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// The sheets ported from src/components, tested by tapping the same controls
/// a person taps rather than by constructing them directly. A sheet that opens
/// perfectly from a test and is unreachable from Home is not a feature.
void main() {
  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();
  }

  /// Scrolls a control into view, taps it, and lets the animation finish.
  ///
  /// The ensureVisible is not decoration. The test viewport is 800x600 and the
  /// tab bar covers the bottom of it, so a control that is perfectly reachable
  /// on a real phone can sit underneath the bar here. Tapping it then reports
  /// "the sheet did not open", which is a true statement about a cause that
  /// has nothing to do with the sheet. Adding one entry to the fixture was
  /// enough to push the Debt button under the bar and fail three tests at
  /// once.
  Future<void> tapAndSettle(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// The one store the whole app reads. Taken off HomeScreen rather than off a
  /// card, because the cards below the fold are not built until something
  /// scrolls to them and a finder for one of those fails for a reason that has
  /// nothing to do with the thing under test.
  FinancialState storeOf(WidgetTester tester) =>
      tester.widget<HomeScreen>(find.byType(HomeScreen)).state;

  group('reachability', () {
    testWidgets('the header sparkle opens the Philippine Toolkit',
        (WidgetTester tester) async {
      await pumpHome(tester);

      await tapAndSettle(tester, find.byIcon(Icons.auto_awesome_outlined));

      expect(find.byType(ToolkitSheet), findsOneWidget);
      expect(find.text('Philippine Toolkit'), findsOneWidget);
    });

    // One test per tool, not a loop inside one test. The toolkit closes itself
    // on the way through, and re-opening the app inside a single test leaves
    // the previous sheet's route in the way, so a loop tests the first tool
    // and then tests the framework.
    for (final (String label, Type sheet) tool in <(String, Type)>[
      ('Tax Calculator', TaxCalculatorSheet),
      ('Business Tax Simulator', BusinessTaxSheet),
      ('Categories', CategoryManagerSheet),
    ]) {
      testWidgets('the toolkit opens ${tool.$1}', (WidgetTester tester) async {
        await pumpHome(tester);
        await tapAndSettle(tester, find.byIcon(Icons.auto_awesome_outlined));
        await tapAndSettle(tester, find.text(tool.$1));

        expect(find.byType(tool.$2), findsOneWidget);
        // The toolkit gets out of the way rather than stacking behind.
        expect(find.byType(ToolkitSheet), findsNothing);
      });
    }

    testWidgets('the hero Details button opens Safe to Spend',
        (WidgetTester tester) async {
      await pumpHome(tester);

      await tapAndSettle(tester, find.text('DETAILS'));

      expect(find.byType(SafeToSpendSheet), findsOneWidget);
      // The tab that shows the working out, which is the whole reason this
      // sheet exists rather than a tooltip.
      expect(find.text('Audit & Math'), findsOneWidget);
    });

    testWidgets('the Debt quick action opens the Add Debt sheet',
        (WidgetTester tester) async {
      await pumpHome(tester);

      await tapAndSettle(tester, find.text('Debt'));

      expect(find.byType(AddDebtSheet), findsOneWidget);
      expect(find.text('Save debt'), findsOneWidget);
    });
  });

  group('the write path', () {
    testWidgets('a saved debt is visible on Home afterwards',
        (WidgetTester tester) async {
      await pumpHome(tester);

      final FinancialState state = storeOf(tester);
      final double oweBefore = state.debtsIOwe;

      await tapAndSettle(tester, find.text('Debt'));

      // The name field is the first in the sheet and the amount the second,
      // which is the order they are read in.
      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Tita Baby');
      await tester.enterText(fields.at(1), '5000');
      await tester.pumpAndSettle();

      await tapAndSettle(tester, find.text('Save debt'));

      // Half one: the money moved, and moved by exactly the amount typed.
      // Directional, not a conservation statement: a save that silently did
      // nothing fails here rather than passing.
      expect(state.debtsIOwe, oweBefore + 5000);
      expect(
        state.debts.any((Debt d) => d.person == 'Tita Baby'),
        isTrue,
        reason: 'the debt was not written to the store at all',
      );

      // Half two, the one that gets forgotten: a person can SEE it. The Debt
      // card on Home must now print the new total. A write that is correct in
      // the store and invisible on the screen is the defect, not a polish
      // item, and that is exactly how a 1,500 payment once vanished.
      // The scrollable is named explicitly. scrollUntilVisible otherwise
      // demands there be exactly ONE Scrollable in the tree and throws "Bad
      // state: Too many elements" the moment a second one exists, which says
      // nothing about the debt and sends you looking in the wrong place.
      await tester.scrollUntilVisible(
        find.byKey(debtBeamKey),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(formatPeso(oweBefore + 5000)),
        findsOneWidget,
        reason: 'the debt saved but Home still shows the old total',
      );
      expect(
        find.text(formatPeso(oweBefore)),
        findsNothing,
        reason: 'Home is still showing the figure from before the save',
      );
    });

    testWidgets('Save debt refuses an empty form rather than writing a blank',
        (WidgetTester tester) async {
      await pumpHome(tester);

      final FinancialState state = storeOf(tester);
      final int countBefore = state.debts.length;

      await tapAndSettle(tester, find.text('Debt'));
      await tester.tap(find.text('Save debt'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Still open, nothing written. A row with no name and no amount can
      // never be reconciled against anything.
      expect(find.byType(AddDebtSheet), findsOneWidget);
      expect(state.debts.length, countBefore);
    });
  });

  group('layout', () {
    /// 320 logical pixels is the narrowest phone worth supporting. A sheet is
    /// the densest surface in the app, so this is where a Row gives out first.
    ///
    /// Real fonts, because the default test font is WIDER than Plus Jakarta
    /// Sans. Measuring layout in a face the phone never draws answers a
    /// different question from the one being asked.
    Future<void> pumpNarrow(WidgetTester tester) async {
      await tester.runAsync(loadRealFonts);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpHome(tester);
    }

    testWidgets('the toolkit and the tax calculator fit at 320dp',
        (WidgetTester tester) async {
      await pumpNarrow(tester);

      await tapAndSettle(tester, find.byIcon(Icons.auto_awesome_outlined));
      expect(tester.takeException(), isNull);

      await tapAndSettle(tester, find.text('Tax Calculator'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Safe to Spend fits at 320dp', (WidgetTester tester) async {
      await pumpNarrow(tester);

      await tapAndSettle(tester, find.text('DETAILS'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Add Debt fits at 320dp, schedule and all',
        (WidgetTester tester) async {
      await pumpNarrow(tester);

      await tapAndSettle(tester, find.text('Debt'));
      expect(tester.takeException(), isNull);

      // The amortization table only appears once there is an amount to
      // schedule, so an empty form proves nothing about the widest part of
      // this sheet.
      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Bank');
      await tester.enterText(fields.at(1), '250000');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    /// Sweeps every tappable thing in an open sheet against the 44dp floor, in
    /// BOTH dimensions. Height alone is not the test: a control 44 tall and 20
    /// wide is exactly as hard to hit, and the close button and the segmented
    /// controls are the ones sized small enough for it to matter.
    Future<void> expectTouchTargets(WidgetTester tester, Type sheet) async {
      final Finder taps = find.descendant(
        of: find.byType(sheet),
        matching: find.byType(InkWell),
      );
      expect(taps, findsWidgets, reason: 'no controls found in $sheet at all');

      for (int i = 0; i < taps.evaluate().length; i++) {
        final Size size = tester.getSize(taps.at(i));
        expect(
          size.height,
          greaterThanOrEqualTo(44),
          reason: 'a control in $sheet is only ${size.height} tall',
        );
        expect(
          size.width,
          greaterThanOrEqualTo(44),
          reason: 'a control in $sheet is only ${size.width} wide',
        );
      }
    }

    testWidgets('every control in the toolkit clears the 44dp floor',
        (WidgetTester tester) async {
      await pumpHome(tester);
      await tapAndSettle(tester, find.byIcon(Icons.auto_awesome_outlined));

      await expectTouchTargets(tester, ToolkitSheet);
    });

    testWidgets('every control in the tax calculator clears the 44dp floor',
        (WidgetTester tester) async {
      // The densest sheet: two segmented controls whose segments are sized by
      // a one word label, which is where a target shrinks below the floor
      // without anybody noticing.
      await pumpHome(tester);
      await tapAndSettle(tester, find.byIcon(Icons.auto_awesome_outlined));
      await tapAndSettle(tester, find.text('Tax Calculator'));

      await expectTouchTargets(tester, TaxCalculatorSheet);
    });
  });
}
