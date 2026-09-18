import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/scroll_behavior.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/categories/category_manager_sheet.dart';
import 'package:salapify/features/info/info_dot.dart';
import 'package:salapify/features/info/info_sheet.dart';
import 'package:salapify/features/log/log_sheet.dart';
import 'package:salapify/features/debt/add_debt_sheet.dart';
import 'package:salapify/features/safe_to_spend/safe_to_spend_sheet.dart';
import 'package:salapify/features/tax/business_tax_sheet.dart';
import 'package:salapify/features/tax/tax_calculator_sheet.dart';
import 'package:salapify/features/toolkit/toolkit_sheet.dart';
import 'package:salapify/features/accounts/account_sheet.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/accounts/accounts_screen.dart';
import 'package:salapify/features/debt/payment_sheet.dart';
import 'package:salapify/screens/activity/activity_screen.dart';
import 'package:salapify/screens/debt/debt_calculators.dart';
import 'package:salapify/screens/debt/debt_screen.dart';
import 'package:salapify/screens/home/debt_beam_card.dart';
import 'package:salapify/screens/plan/plan_screen.dart';
import 'package:salapify/screens/reports/reports_screen.dart';
import 'package:salapify/screens/home/home_screen.dart';
import 'package:salapify/shell/app_shell.dart';
import 'package:salapify/state/financial_state.dart';

/// The screenshot harness.
///
/// Deliberately NOT named *_test.dart: `flutter test` only collects files with
/// that suffix, so this can never join a normal run and fail there on fonts.
/// CI runs it explicitly with --update-goldens, which makes it write-only, so
/// the only way it can fail is if the app genuinely stopped rendering.
///
///   flutter test test/shots/screens_shot.dart --update-goldens
///
/// Output lands in test/shots/out, which is gitignored. Reviewed renders get
/// copied into docs/ so the founder can open them on GitHub.

/// Loads the real shipped fonts. This MUST happen inside tester.runAsync:
/// testWidgets runs on a fake clock, so a real file read never completes
/// inside it and the run hangs with no output at all.
Future<void> loadRealFonts() async {
  final FontLoader loader = FontLoader('PlusJakartaSans')
    ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
  await loader.load();

  // The Material icon font, so Salapify's own icons draw as glyphs rather
  // than as empty boxes in the render.
  final String sdk = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final File icons = File(
    '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final FontLoader iconLoader = FontLoader('MaterialIcons')
      ..addFont(
        Future<ByteData>.value(ByteData.sublistView(icons.readAsBytesSync())),
      );
    await iconLoader.load();
  }
}

void main() {
  // Two surfaces per theme, and both earn their place.
  //
  // The PHONE size is the honest one: it is what the founder holds, and it is
  // the only one that can show a card being cut off or a control sitting under
  // the tab bar.
  //
  // The FULL one is tall enough to fit the whole scroll in a single image. Home
  // is now several screens long, so reviewing it phone-sized means sending
  // three pictures and hoping they are read in order. This is the surface the
  // founder actually compares against the prototype.
  const List<({String suffix, Size size})> surfaces =
      <({String suffix, Size size})>[
        (suffix: '', size: Size(1170, 2532)),
        // Tall enough for the whole scroll with very little dead space below
        // it. Raise it when Home grows; a render that cuts the last card off
        // is worse than one with a margin.
        (suffix: '_full', size: Size(1170, 6000)),
      ];

  for (final ThemeMode2 mode in ThemeMode2.values) {
    final String theme = mode == ThemeMode2.hapon ? 'hapon' : 'gabi';

    for (final ({String suffix, Size size}) surface in surfaces) {
      final String name = '$theme${surface.suffix}';

      testWidgets('home renders in $name', (WidgetTester tester) async {
        await tester.runAsync(loadRealFonts);

        tester.view.physicalSize = surface.size;
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // The palette is read during build, so the theme is set BEFORE pumping.
        final FinancialState state = FinancialState(
          clock: DateTime.utc(2026, 9, 18),
        );
        if (state.theme != mode) state.toggleTheme();
        final Palette palette = Palette.of(state.theme);

        // The FULL shell, tab bar and all, not a bare screen.
        //
        // This harness used to render HomeScreen on its own, and that is exactly
        // how it missed a bug that made the app unusable: the tab bar's Column
        // grew to the whole window, the body was laid out at zero height, and
        // Home showed nothing at all on a real device. The render looked perfect
        // the entire time, because the thing at fault was the part it left out.
        // A harness that renders something the user never sees proves nothing.
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            // Same scrolling feel as the shipped app, so the harness renders
            // what ships rather than a near miss.
            scrollBehavior: const SalapifyScrollBehavior(),
            theme: salapifyTheme(palette, state.theme),
            home: AppShell(state: state),
          ),
        );
        await tester.pumpAndSettle();

        // Guard the same defect directly: the body must have real height.
        expect(
          tester.getSize(find.byType(HomeScreen)).height,
          greaterThan(200),
          reason: 'the shell collapsed the body, so this render shows nothing',
        );

        await expectLater(
          find.byType(AppShell),
          matchesGoldenFile('out/home_$name.png'),
        );
      });
    }
  }

  // Activity, the second tab, at both brightnesses. It is reached by TAPPING
  // the tab rather than by building the screen alone, because the tab bar
  // collapsing the body to zero height is a defect this harness has already
  // had to catch once.
  for (final ThemeMode2 mode in ThemeMode2.values) {
    final String theme = mode == ThemeMode2.hapon ? 'hapon' : 'gabi';

    testWidgets('activity renders in $theme', (WidgetTester tester) async {
      await tester.runAsync(loadRealFonts);

      tester.view.physicalSize = const Size(1170, 4200);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final FinancialState state = FinancialState(
        clock: DateTime.utc(2026, 9, 18),
      );
      if (state.theme != mode) state.toggleTheme();
      final Palette palette = Palette.of(state.theme);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: const SalapifyScrollBehavior(),
          theme: salapifyTheme(palette, state.theme),
          home: AppShell(state: state),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await tester.pumpAndSettle();

      expect(
        find.byType(ActivityScreen),
        findsOneWidget,
        reason: 'the Activity tab did not open',
      );

      await expectLater(
        find.byType(AppShell),
        matchesGoldenFile('out/activity_$theme.png'),
      );
    });
  }

  // Reports, the third tab. ALL THREE sub-tabs at both brightnesses, because
  // a sub-tab nobody renders is a screen nobody has looked at: the Position
  // tab is what opens by default and the other two are one tap away, so
  // shooting only the default would leave two thirds of the feature unseen.
  for (final ThemeMode2 mode in ThemeMode2.values) {
    final String theme = mode == ThemeMode2.hapon ? 'hapon' : 'gabi';

    for (final String subTab in <String>[
      'Position',
      'Performance',
      'Cash flow',
    ]) {
      final String slug = subTab.toLowerCase().replaceAll(' ', '_');

      testWidgets('reports $slug renders in $theme', (
        WidgetTester tester,
      ) async {
        await tester.runAsync(loadRealFonts);

        // Taller than the other tabs on purpose: Performance carries the
        // category breakdown, which is the longest thing in the app.
        tester.view.physicalSize = const Size(1170, 6000);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final FinancialState state = FinancialState(
          clock: DateTime.utc(2026, 9, 18),
        );
        if (state.theme != mode) state.toggleTheme();
        final Palette palette = Palette.of(state.theme);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            scrollBehavior: const SalapifyScrollBehavior(),
            theme: salapifyTheme(palette, state.theme),
            home: AppShell(state: state),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.insert_chart_outlined));
        await tester.pumpAndSettle();

        expect(
          find.byType(ReportsScreen),
          findsOneWidget,
          reason: 'the Reports tab did not open',
        );

        await tester.tap(find.text(subTab));
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(AppShell),
          matchesGoldenFile('out/reports_${slug}_$theme.png'),
        );
      });
    }
  }

  // Plan, the fourth tab. The hub plus the four segments with money on them,
  // in dark. The other three (Calculators, Learn, Trackers) are covered by
  // the widget tests; these are the ones where a wrong figure would show.
  for (final ({String label, String slug}) seg
      in <({String label, String slug})>[
        (label: '', slug: 'hub'),
        (label: 'Budgets', slug: 'budgets'),
        (label: 'Bills and payables', slug: 'bills'),
        (label: 'Goals', slug: 'goals'),
        (label: 'Trackers', slug: 'trackers'),
        (label: 'Academy', slug: 'academy'),
      ]) {
    testWidgets('plan ${seg.slug} renders', (WidgetTester tester) async {
      await tester.runAsync(loadRealFonts);

      tester.view.physicalSize = const Size(1170, 3400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final FinancialState state = FinancialState(
        clock: DateTime.utc(2026, 9, 18),
      );
      final Palette palette = Palette.of(state.theme);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: const SalapifyScrollBehavior(),
          theme: salapifyTheme(palette, state.theme),
          home: AppShell(state: state),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.track_changes_outlined));
      await tester.pumpAndSettle();

      expect(
        find.byType(PlanScreen),
        findsOneWidget,
        reason: 'the Plan tab did not open',
      );

      if (seg.label.isNotEmpty) {
        await tester.tap(find.text(seg.label).first);
        await tester.pumpAndSettle();
      }

      await expectLater(
        find.byType(AppShell),
        matchesGoldenFile('out/plan_${seg.slug}.png'),
      );
    });
  }

  // An explainer, opened by TAPPING its dot on Reports rather than built on
  // its own. Founder direction moved the teaching off the screens and behind
  // these dots, and a picture of the emptied screen without a picture of
  // where the words went only shows half the trade.
  testWidgets('info sheet renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 2600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    final Palette palette = Palette.of(state.theme);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SalapifyScrollBehavior(),
        theme: salapifyTheme(palette, state.theme),
        home: AppShell(state: state),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.insert_chart_outlined));
    await tester.pumpAndSettle();

    // The net worth dot, which is the first on the Position tab and opens the
    // longest explainer.
    await tester.tap(find.byType(InfoDot).first);
    await tester.pumpAndSettle();

    expect(
      find.byType(InfoSheet),
      findsOneWidget,
      reason: 'the dot did not open an explainer',
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/info_sheet.png'),
    );
  });

  // The Log sheet, mid-entry rather than blank, because an empty form shows
  // none of the parts that can go wrong: the confirmation sentence, the
  // selected account pill, and the Save button becoming live.
  testWidgets('log sheet renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    final Palette palette = Palette.of(state.theme);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SalapifyScrollBehavior(),
        theme: salapifyTheme(palette, state.theme),
        home: AppShell(state: state),
      ),
    );
    await tester.pumpAndSettle();

    LogSheet.show(tester.element(find.byType(AppShell)), state);
    await tester.pumpAndSettle();

    // The founder's own example, typed into the quick-parse line, so the
    // render shows the read-back sentence AND the form it fills.
    await tester.enterText(
      find.byKey(const Key('log-quick-parse')),
      'Jollibee 500 gcash',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fill the form with this'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/log_sheet.png'),
    );
  });

  // The read-back when the parser does NOT know the word. This is the state
  // the founder hit on the emulator: they typed "Electricity" and the sheet
  // silently selected Food & Dining, because that is the parser's fallback.
  // The sentence is the whole fix, so it gets looked at rather than assumed.
  testWidgets('log sheet unknown category renders', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 2000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    final Palette palette = Palette.of(state.theme);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SalapifyScrollBehavior(),
        theme: salapifyTheme(palette, state.theme),
        home: AppShell(state: state),
      ),
    );
    await tester.pumpAndSettle();

    LogSheet.show(tester.element(find.byType(AppShell)), state);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('log-quick-parse')),
      'Xylophone lessons 1500',
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/log_sheet_unknown_category.png'),
    );
  });

  // The Log sheet BACKDATED, which is the state worth looking at rather than
  // the picker dialog (that one is stock Material and only inherits the
  // theme). Two things have to read clearly here: the When row showing a day
  // that is not today, and the extra sentence warning that the balance still
  // moves now. Somebody logging last week's groceries needs to know the money
  // comes out today, or the account will not match what they expect.
  testWidgets('log sheet backdated renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    final Palette palette = Palette.of(state.theme);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SalapifyScrollBehavior(),
        theme: salapifyTheme(palette, state.theme),
        home: AppShell(state: state),
      ),
    );
    await tester.pumpAndSettle();

    LogSheet.show(tester.element(find.byType(AppShell)), state);
    await tester.pumpAndSettle();

    // The keys sit on the SheetField wrapper, not the TextField inside it, so
    // enterText has to descend to the editable or it has nothing to type into.
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('log-amount')),
        matching: find.byType(TextField),
      ),
      '820',
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('log-merchant')),
        matching: find.byType(TextField),
      ),
      'Puregold groceries',
    );
    await tester.pumpAndSettle();

    // Drive the real picker rather than setting the field, so the render shows
    // what a person actually gets after using it. The When row sits below the
    // fold of this viewport, so scroll to it first.
    await tester.ensureVisible(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('15'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Scroll on to the confirmation itself. ensureVisible stops the moment its
    // target is on screen, so stopping at the When row leaves the sentence
    // underneath it half hidden behind the Save bar, and the render would then
    // show a clipped warning that the real screen does not have.
    await tester.ensureVisible(find.textContaining('The balance changes now'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/log_sheet_backdated.png'),
    );
  });

  // The picker dialog itself. It is stock Material, which is exactly why it
  // gets looked at: a dialog Salapify did not draw is the easiest place for a
  // white panel to appear in the middle of a dark app.
  testWidgets('date picker renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    final Palette palette = Palette.of(state.theme);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SalapifyScrollBehavior(),
        theme: salapifyTheme(palette, state.theme),
        home: AppShell(state: state),
      ),
    );
    await tester.pumpAndSettle();

    LogSheet.show(tester.element(find.byType(AppShell)), state);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/date_picker.png'),
    );
  });

  // The transaction detail, opened on the EXCLUDED row, dark only. That row
  // is chosen deliberately: it is the one carrying the struck-through amount
  // and the sentence explaining why it is not in the totals, so the render
  // shows the state most likely to confuse somebody reconciling.
  testWidgets('transaction detail renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    final Palette palette = Palette.of(state.theme);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SalapifyScrollBehavior(),
        theme: salapifyTheme(palette, state.theme),
        home: AppShell(state: state),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('EXCLUDED'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('EXCLUDED'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/transaction_detail.png'),
    );
  });

  // The sheets, dark only, which is what the founder uses. Each one is opened
  // through its REAL route rather than pumped on its own, so what gets
  // rendered is the modal as it actually appears over the app: the same grab
  // handle, the same 92% height, the same dimmed Home behind it.
  const List<({String name, String openWith})> sheets =
      <({String name, String openWith})>[
        (name: 'toolkit', openWith: 'toolkit'),
        (name: 'safe_to_spend', openWith: 'safeToSpend'),
        (name: 'add_debt', openWith: 'addDebt'),
        (name: 'tax_calculator', openWith: 'tax'),
        (name: 'business_tax', openWith: 'business'),
        (name: 'categories', openWith: 'categories'),
      ];

  for (final ({String name, String openWith}) sheet in sheets) {
    testWidgets('sheet ${sheet.name} renders', (WidgetTester tester) async {
      await tester.runAsync(loadRealFonts);

      // Taller than a phone on purpose: a sheet opens to 92% of the screen and
      // a phone-height render would cut off the part worth reviewing.
      tester.view.physicalSize = const Size(1170, 3400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final FinancialState state = FinancialState(
        clock: DateTime.utc(2026, 9, 18),
      );
      final Palette palette = Palette.of(state.theme);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: const SalapifyScrollBehavior(),
          theme: salapifyTheme(palette, state.theme),
          home: AppShell(state: state),
        ),
      );
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(AppShell));
      switch (sheet.openWith) {
        case 'toolkit':
          ToolkitSheet.show(context, state);
        case 'safeToSpend':
          SafeToSpendSheet.show(context, state);
        case 'addDebt':
          AddDebtSheet.show(context, palette);
        case 'tax':
          TaxCalculatorSheet.show(context, palette);
        case 'business':
          BusinessTaxSheet.show(context, palette);
        case 'categories':
          CategoryManagerSheet.show(context, state);
      }
      await tester.pumpAndSettle();

      // MaterialApp, not AppShell: a modal sheet lives in the Overlay ABOVE
      // the shell, so a render of the shell alone would be a picture of Home
      // with nothing on it.
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/sheet_${sheet.name}.png'),
      );
    });
  }

  // Add Debt with the form FILLED IN, because the amortization table only
  // exists once there is something to amortise. An empty form is a picture of
  // the half of this sheet that was already easy to get right.
  testWidgets('sheet add_debt_schedule renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 4600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    final Palette palette = Palette.of(state.theme);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SalapifyScrollBehavior(),
        theme: salapifyTheme(palette, state.theme),
        home: AppShell(state: state),
      ),
    );
    await tester.pumpAndSettle();

    AddDebtSheet.show(tester.element(find.byType(AppShell)), palette);
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Home Credit');
    await tester.enterText(fields.at(1), '85000');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Installments'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/sheet_add_debt_schedule.png'),
    );
  });

  // Accounts, the fifth tab. All four views at both brightnesses, because a
  // view nobody renders is a screen nobody has looked at.
  for (final ThemeMode2 mode in ThemeMode2.values) {
    final String theme = mode == ThemeMode2.hapon ? 'hapon' : 'gabi';

    for (final ({String label, String slug}) view
        in <({String label, String slug})>[
          (label: '', slug: 'all'),
          (label: 'Own 8', slug: 'assets'),
          (label: 'Owe 3', slug: 'liabilities'),
          (label: 'Invested', slug: 'invested'),
        ]) {
      testWidgets('accounts ${view.slug} renders in $theme', (
        WidgetTester tester,
      ) async {
        await tester.runAsync(loadRealFonts);

        // Tall: the All view is the whole wallet, eleven accounts in eight
        // groups plus the debt register, and it is the one worth seeing whole.
        tester.view.physicalSize = const Size(1170, 6400);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final FinancialState state = FinancialState(
          clock: DateTime.utc(2026, 9, 18),
        );
        if (state.theme != mode) state.toggleTheme();
        final Palette palette = Palette.of(state.theme);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            scrollBehavior: const SalapifyScrollBehavior(),
            theme: salapifyTheme(palette, state.theme),
            home: AppShell(state: state),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byIcon(Icons.account_balance_wallet_outlined).last,
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(AccountsScreen),
          findsOneWidget,
          reason: 'the Accounts tab did not open',
        );

        if (view.label.isNotEmpty) {
          await tester.tap(find.text(view.label));
          await tester.pumpAndSettle();
        }

        await expectLater(
          find.byType(AppShell),
          matchesGoldenFile('out/accounts_${view.slug}_$theme.png'),
        );
      });
    }
  }

  // A FOREIGN balance, which no seeded account has. Without this shot the
  // conversion path ships having been tested and never once looked at, and
  // "about ₱88,400.00" under a Singapore dollar figure is exactly the kind of
  // line that reads wrong at a glance and fine in an assertion.
  testWidgets('accounts with a foreign balance renders', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    state.addAccount(
      const Account(
        id: 'acc_sg_shot',
        name: 'Singapore payroll',
        kind: AccountKind.bank,
        institution: 'Other',
        balance: 2000,
        monogram: 'SG',
        currency: CurrencyCode.sgd,
        profile: ProfileEntity.personal,
      ),
    );
    final Palette palette = Palette.of(state.theme);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SalapifyScrollBehavior(),
        theme: salapifyTheme(palette, state.theme),
        home: AppShell(state: state),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Own 9'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppShell),
      matchesGoldenFile('out/accounts_foreign.png'),
    );
  });

  // The add sheet, in both of its shapes: the plain one somebody sees first,
  // and the card one with the limit, the scheme and the due date on it.
  for (final ({String kind, String slug}) shape
      in <({String kind, String slug})>[
        (kind: '', slug: 'plain'),
        (kind: 'Credit card', slug: 'card'),
      ]) {
    testWidgets('sheet add account ${shape.slug} renders', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(loadRealFonts);

      tester.view.physicalSize = const Size(1170, 2600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final FinancialState state = FinancialState(
        clock: DateTime.utc(2026, 9, 18),
      );
      final Palette palette = Palette.of(state.theme);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: const SalapifyScrollBehavior(),
          theme: salapifyTheme(palette, state.theme),
          home: AppShell(state: state),
        ),
      );
      await tester.pumpAndSettle();

      AccountSheet.show(
        tester.element(find.byType(AppShell)),
        palette: palette,
        state: state,
      );
      await tester.pumpAndSettle();

      if (shape.kind.isNotEmpty) {
        await tester.tap(find.text(shape.kind));
        await tester.pumpAndSettle();
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/sheet_add_account_${shape.slug}.png'),
      );
    });
  }

  // The debt register, both directions, at both brightnesses. It is a pushed
  // screen rather than a tab, so the harness reaches it the way a person does:
  // through the beam on Home.
  for (final ThemeMode2 mode in ThemeMode2.values) {
    final String theme = mode == ThemeMode2.hapon ? 'hapon' : 'gabi';

    for (final ({String label, String slug}) side
        in <({String label, String slug})>[
          (label: '', slug: 'owe'),
          (label: 'Owed to you', slug: 'owed'),
        ]) {
      testWidgets('debt ${side.slug} renders in $theme', (
        WidgetTester tester,
      ) async {
        await tester.runAsync(loadRealFonts);

        tester.view.physicalSize = const Size(1170, 4200);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final FinancialState state = FinancialState(
          clock: DateTime.utc(2026, 9, 18),
        );
        if (state.theme != mode) state.toggleTheme();
        final Palette palette = Palette.of(state.theme);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            scrollBehavior: const SalapifyScrollBehavior(),
            theme: salapifyTheme(palette, state.theme),
            home: AppShell(state: state),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byType(DebtBeamCard),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(DebtBeamCard),
            matching: find.text('See all'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(DebtScreen),
          findsOneWidget,
          reason: 'the debt beam did not open the register',
        );

        if (side.label.isNotEmpty) {
          await tester.tap(find.text(side.label));
          await tester.pumpAndSettle();
        }

        await expectLater(
          find.byType(DebtScreen),
          matchesGoldenFile('out/debt_${side.slug}_$theme.png'),
        );
      });
    }
  }

  // The payment sheet, which is where the money actually moves and therefore
  // the one screen in this batch most worth looking at. Rendered with an
  // amount typed and an account chosen, so the consequence lines are on it.
  testWidgets('sheet debt payment renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    final Palette palette = Palette.of(state.theme);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SalapifyScrollBehavior(),
        theme: salapifyTheme(palette, state.theme),
        home: AppShell(state: state),
      ),
    );
    await tester.pumpAndSettle();

    PaymentSheet.show(
      tester.element(find.byType(AppShell)),
      palette: palette,
      state: state,
      debt: state.debts.firstWhere((Debt d) => d.id == 'debt_homecredit'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '2450');
    await tester.pumpAndSettle();
    await tester.tap(find.text('GCash Wallet'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/sheet_debt_payment.png'),
    );
  });

  // Four of the nine calculators, chosen because each shows a different SHAPE
  // of answer: a plain amortisation, a rate-type comparison, a trap, and a
  // ratio with words rather than pesos.
  for (final ({String label, String slug}) calc
      in <({String label, String slug})>[
        (label: '', slug: 'pagibig'),
        (label: 'Car loan', slug: 'car'),
        (label: 'Credit card trap', slug: 'card'),
        (label: 'Snowball or avalanche', slug: 'strategy'),
      ]) {
    testWidgets('calculator ${calc.slug} renders', (WidgetTester tester) async {
      await tester.runAsync(loadRealFonts);

      tester.view.physicalSize = const Size(1170, 4000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final FinancialState state = FinancialState(
        clock: DateTime.utc(2026, 9, 18),
      );
      final Palette palette = Palette.of(state.theme);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: const SalapifyScrollBehavior(),
          theme: salapifyTheme(palette, state.theme),
          home: AppShell(state: state),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byType(DebtBeamCard),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DebtBeamCard),
          matching: find.text('See all'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work it out'));
      await tester.pumpAndSettle();

      expect(
        find.byType(DebtCalculators),
        findsOneWidget,
        reason: 'the calculators tab did not open',
      );

      if (calc.label.isNotEmpty) {
        await tester.ensureVisible(find.text(calc.label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(calc.label));
        await tester.pumpAndSettle();
      }

      await expectLater(
        find.byType(DebtScreen),
        matchesGoldenFile('out/calculator_${calc.slug}.png'),
      );
    });
  }
}
