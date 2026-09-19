import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/format.dart';
import 'package:salapify/features/categories/category_manager_sheet.dart';
import 'package:salapify/features/debt/add_debt_sheet.dart';
import 'package:salapify/features/safe_to_spend/safe_to_spend_sheet.dart';
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

  /// Opens the tax calculator the way a person now reaches it: Plan, then the
  /// calculator library, then Income tax.
  ///
  /// It used to be one tap from the toolkit. The founder had that entry point
  /// removed on 2026-09-19 as a duplicate of this one, so the tests that ask
  /// layout questions about the sheet come through the door that still exists.
  Future<void> openTaxFromPlan(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.track_changes_outlined).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Calculators').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calculators').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Income tax'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Income tax'));
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
    testWidgets('the header sparkle opens the Philippine Toolkit', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      await tapAndSettle(tester, find.byIcon(Icons.auto_awesome_outlined));

      expect(find.byType(ToolkitSheet), findsOneWidget);
      expect(find.text('Philippine Toolkit'), findsOneWidget);
    });

    // One test per tool, not a loop inside one test. The toolkit closes itself
    // on the way through, and re-opening the app inside a single test leaves
    // the previous sheet's route in the way, so a loop tests the first tool
    // and then tests the framework.
    // The Tax Calculator and the Business Tax Simulator are NOT here any more.
    // Founder direction, 2026-09-19: they duplicated the Plan tab's calculator
    // library, and the prototype's own toolkit carries neither. What matters
    // is that they are still REACHABLE, which the test below this loop proves
    // from Plan, because removing a second door is only safe while the first
    // one opens.
    testWidgets('the toolkit carries the four prototype tabs', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);
      await tapAndSettle(tester, find.byIcon(Icons.auto_awesome_outlined));

      for (final String tab in <String>[
        'Notes Calc',
        'Mindset',
        'Treats',
        'FX Rates',
      ]) {
        expect(find.text(tab), findsOneWidget, reason: '$tab is missing');
      }
    });

    testWidgets('the notes calculator adds up what is typed', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);
      await tapAndSettle(tester, find.byIcon(Icons.auto_awesome_outlined));

      // The default notepad, whose total is locked to a vector generated by
      // running the prototype's own parser.
      expect(find.text('₱4,248.00'), findsOneWidget);
    });

    testWidgets('Categories moved to Settings, and is still reachable', (
      WidgetTester tester,
    ) async {
      // It used to be a toolkit tile. The prototype's overhauled toolkit has
      // four tabs and Categories is not one of them, so it lives in Settings
      // now. This asserts it is REACHABLE rather than merely gone, because a
      // test that only checked the tile had disappeared would pass just as
      // happily if the feature had been dropped.
      await pumpHome(tester);
      await tapAndSettle(tester, find.byIcon(Icons.settings_outlined).first);
      await tapAndSettle(tester, find.text('Categories'));

      expect(find.byType(CategoryManagerSheet), findsOneWidget);
    });

    testWidgets('the hero Details button opens Safe to Spend', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      await tapAndSettle(tester, find.text('DETAILS'));

      expect(find.byType(SafeToSpendSheet), findsOneWidget);
      // The tab that shows the working out, which is the whole reason this
      // sheet exists rather than a tooltip.
      expect(find.text('Audit & Math'), findsOneWidget);
    });

    testWidgets('the Debt quick action opens the Add Debt sheet', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      await tapAndSettle(tester, find.text('Debt'));

      expect(find.byType(AddDebtSheet), findsOneWidget);
      expect(find.text('Save debt'), findsOneWidget);
    });
  });

  group('the write path', () {
    testWidgets('a saved debt is visible on Home afterwards', (
      WidgetTester tester,
    ) async {
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

    testWidgets('Save debt refuses an empty form rather than writing a blank', (
      WidgetTester tester,
    ) async {
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

    testWidgets('the toolkit and the tax calculator fit at 320dp', (
      WidgetTester tester,
    ) async {
      await pumpNarrow(tester);

      await tapAndSettle(tester, find.byIcon(Icons.auto_awesome_outlined));
      expect(tester.takeException(), isNull);

      // Close the toolkit before going anywhere else: it is a modal sheet and
      // it covers the tab bar underneath.
      await tapAndSettle(tester, find.byIcon(Icons.close).last);

      // Reached through PLAN now, not the toolkit. Same sheet, same layout
      // question; only the door changed.
      await openTaxFromPlan(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Safe to Spend fits at 320dp', (WidgetTester tester) async {
      await pumpNarrow(tester);

      await tapAndSettle(tester, find.text('DETAILS'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Add Debt fits at 320dp, schedule and all', (
      WidgetTester tester,
    ) async {
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

    testWidgets('every control in the toolkit clears the 44dp floor', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);
      await tapAndSettle(tester, find.byIcon(Icons.auto_awesome_outlined));

      await expectTouchTargets(tester, ToolkitSheet);
    });

    testWidgets('every control in the tax calculator clears the 44dp floor', (
      WidgetTester tester,
    ) async {
      // The densest sheet: two segmented controls whose segments are sized by
      // a one word label, which is where a target shrinks below the floor
      // without anybody noticing.
      await pumpHome(tester);
      await openTaxFromPlan(tester);

      await expectTouchTargets(tester, TaxCalculatorSheet);
    });
  });
}
