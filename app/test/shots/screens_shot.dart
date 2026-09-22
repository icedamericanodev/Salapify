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
import 'package:salapify/features/pan/pan_sheet.dart';
import 'package:salapify/features/reminders/reminders_sheet.dart';
import 'package:salapify/features/safe_to_spend/safe_to_spend_sheet.dart';
import 'package:salapify/features/tax/business_tax_sheet.dart';
import 'package:salapify/features/tax/tax_calculator_sheet.dart';
import 'package:salapify/features/toolkit/toolkit_sheet.dart';
import 'package:salapify/features/accounts/account_sheet.dart';
import 'package:salapify/core/money/health_check.dart';
import 'package:salapify/features/health/health_check_sheet.dart';
import 'package:salapify/features/log/scan_receipt_sheet.dart';
import 'package:salapify/features/payday/payday_sheet.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/accounts/accounts_screen.dart';
import 'package:salapify/screens/accounts/bank_card.dart';
import 'package:salapify/features/debt/payment_sheet.dart';
import 'package:salapify/screens/activity/activity_screen.dart';
import 'package:salapify/features/debt/installment_sheet.dart';
import 'package:salapify/screens/debt/debt_calculators.dart';
import 'package:salapify/screens/debt/installments_view.dart';
import 'package:salapify/screens/debt/debt_screen.dart';
import 'package:salapify/screens/home/debt_beam_card.dart';
import 'package:salapify/screens/plan/plan_screen.dart';
import 'package:salapify/screens/reports/reports_screen.dart';
import 'package:salapify/screens/home/home_screen.dart';
import 'package:salapify/shell/app_shell.dart';
import 'package:salapify/data/fx_service.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/features/fx/fx_sheet.dart';
import 'package:salapify/features/settings/import_sheet.dart';
import 'package:salapify/features/settings/privacy_sheet.dart';
import 'package:salapify/features/settings/settings_sheet.dart';
import 'package:salapify/screens/plan/business_guide_screen.dart';
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

/// Finishes decoding every Image on screen, then repaints.
///
/// WITHOUT THIS THE LOGOS RENDER BLANK, and the first version of the brand
/// work shipped a review render that proved nothing about them. Image.asset
/// resolves asynchronously, and testWidgets runs on a fake clock where that
/// never completes, so the plate draws empty. The dark renders happened to
/// show the marks only because the light ones ran first and warmed the global
/// image cache, which is the worst kind of pass: correct by accident, and
/// silently wrong whenever the order changes.
Future<void> settleImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final Element e in find.byType(Image).evaluate()) {
      final Image image = e.widget as Image;
      await precacheImage(image.image, e);
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  _cardFaceShots();
  largeTextShots();
  businessChecklistShots();
  businessGuideViewShots();
  importShots();
  toolkitShots();
  settingsShots();
  realMoneyHomeShot();
  planCalculatorShots();
  fxShot();
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
      'Check',
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

  // The 13th month split, which lives behind a TAB.
  //
  // `sheet tax_calculator` opens on Take-home Pay and never reaches it, so
  // the allocation copy was rendered zero times in the life of this harness
  // while carrying a named product and a return claim on screen. A shot that
  // stops at the first tab of a three tab sheet is a shot of one third of it.
  testWidgets('sheet tax 13th month renders', (WidgetTester tester) async {
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

    TaxCalculatorSheet.show(tester.element(find.byType(AppShell)), palette);
    await tester.pumpAndSettle();

    await tester.tap(find.text('13th Month'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/sheet_tax_13th_month.png'),
    );
  });

  // Health Check, in BOTH the states it has.
  //
  // The lived-in one is what most people see. The empty one is the whole
  // design argument, because it is the person D19 names and the state the
  // prototype answers with invented figures, so a picture of only the first
  // would prove the least interesting half.
  for (final ({String slug, bool sweep}) shape in <({String slug, bool sweep})>[
    (slug: 'health_check', sweep: false),
    (slug: 'health_check_empty', sweep: true),
  ]) {
    testWidgets('sheet ${shape.slug} renders', (WidgetTester tester) async {
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

      if (shape.sweep) {
        state.removeSampleData();
        await tester.pumpAndSettle();
      }

      HealthCheckSheet.show(
        tester.element(find.byType(AppShell)),
        palette,
        state,
        onAct: (HealthNeed _) {},
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/sheet_${shape.slug}.png'),
      );
    });
  }

  // The receipt scanner, with a sample read into it.
  //
  // Empty it is a paste box and six chips, which proves nothing. The whole
  // feature is the form it fills and the caution it puts above it, so the
  // shot taps a sample the way a person would.
  // The payday editor, on the phone that needed it: swept, so there is no
  // cycle recorded and the sheet is doing the job it was built for.
  //
  // Both states, because they are different screens. Empty opens on 15 and
  // 30 as a starting point with no caution line and no way back out. Set
  // shows the founder's other example, the 10th and the 25th, with the
  // preview counting real days and the remove control present.
  for (final ({String slug, List<int> days}) shape
      in <({String slug, List<int> days})>[
        (slug: 'payday', days: <int>[]),
        (slug: 'payday_set', days: <int>[10, 25]),
      ]) {
    testWidgets('sheet ${shape.slug} renders', (WidgetTester tester) async {
      await tester.runAsync(loadRealFonts);

      tester.view.physicalSize = const Size(1170, 3000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final FinancialState state = FinancialState(
        clock: DateTime.utc(2026, 9, 18),
      );
      final Palette palette = Palette.of(state.theme);
      state.removeSampleData();
      if (shape.days.isNotEmpty) {
        state.setPaydayRule(daysOfMonth: shape.days, expectedIncome: 20000);
      }

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: const SalapifyScrollBehavior(),
          theme: salapifyTheme(palette, state.theme),
          home: AppShell(state: state),
        ),
      );
      await tester.pumpAndSettle();

      PaydaySheet.show(tester.element(find.byType(AppShell)), state);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/sheet_${shape.slug}.png'),
      );
    });
  }

  testWidgets('sheet scan receipt renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 4200);
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

    ScanReceiptSheet.show(
      tester.element(find.byType(AppShell)),
      palette,
      state,
    );
    await tester.pumpAndSettle();

    // Jollibee, because it is the official receipt: it is the one sample
    // that fills the TIN, ticks the claimable toggle and lists items, so a
    // smaller one would render a picture with the careful half missing.
    await tester.tap(find.text('Jollibee'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/sheet_scan_receipt.png'),
    );
  });

  // The bonus allocator WITH A FIGURE IN IT.
  //
  // The hub shot above shows it empty, which is the right first impression
  // and proves nothing about the feature: the split, the tax line and the
  // allowance bar only exist once an amount is entered. A picture of the
  // state nobody is reviewing is the same mistake as rendering every tab
  // against an empty store, which put a crossed-out peso sign on Home
  // through dozens of renders.
  testWidgets('plan bonus allocator filled renders', (
    WidgetTester tester,
  ) async {
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

    // 120,000, deliberately, because it is the one quick amount that goes
    // OVER the 90,000 ceiling. The tax rows and the "rough 20%" caution only
    // draw in that case, so any smaller figure would render a picture with
    // the careful half of the feature missing from it.
    await tester.tap(find.text('₱120,000.00'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppShell),
      matchesGoldenFile('out/plan_bonus_filled.png'),
    );
  });

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
        (name: 'reminders', openWith: 'reminders'),
        (name: 'reminders_rules', openWith: 'remindersRules'),
        (name: 'privacy', openWith: 'privacy'),
        (name: 'pan', openWith: 'pan'),
        (name: 'pan_lesson', openWith: 'panLesson'),
        (name: 'pan_afford', openWith: 'panAfford'),
        (name: 'pan_health', openWith: 'panHealth'),
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
        case 'reminders':
        case 'remindersRules':
          RemindersSheet.show(context, state);
        case 'privacy':
          PrivacySheet.show(context, palette);
        case 'pan':
        case 'panLesson':
        case 'panAfford':
        case 'panHealth':
          PanSheet.show(context, state, onAction: (String _) {});
      }
      await tester.pumpAndSettle();

      // The Rules tab is a second shot rather than a second sheet: it is the
      // half a founder reviews for whether the controls read right, and the
      // tray above it is the half they review for whether the words do.
      if (sheet.openWith == 'remindersRules') {
        await tester.tap(find.text('Rules'));
        await tester.pumpAndSettle();
      }

      // Pan renders with a question ALREADY ASKED. An empty chat is a picture
      // of an opening paragraph and proves nothing about the thing being
      // reviewed, which is whether an answer about somebody's own money reads
      // well.
      if (sheet.openWith == 'pan') {
        // .last, because the Home card behind the sheet now offers the same
        // question as a chip. Without it this finds two and throws, which is
        // the render harness catching a real ambiguity rather than a flake.
        await tester.tap(find.text('What is safe to spend?').last);
        await tester.pumpAndSettle();
      }

      // The SECOND Pan shot is a curriculum answer, and it is here because a
      // picture of Pan answering a balance question proved nothing about the
      // thing the founder actually reported: that asking what MP2 is came
      // back with "Pan did not recognise that one" while the course shipped
      // in the same build.
      const Map<String, String> panTyped = <String, String>{
        'panLesson': 'what is MP2',
        // The two answers that carry a badge, stat rows AND buttons, which is
        // the whole of the new bubble in one picture.
        'panAfford': 'can i afford 2,500',
        'panHealth': 'how am i doing',
      };
      if (panTyped.containsKey(sheet.openWith)) {
        await tester.enterText(
          find.byType(TextField),
          panTyped[sheet.openWith]!,
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
      }

      // MaterialApp, not AppShell: a modal sheet lives in the Overlay ABOVE
      // the shell, so a render of the shell alone would be a picture of Home
      // with nothing on it.
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/sheet_${sheet.name}.png'),
      );
    });
  }

  // Safe to Spend on a SWEPT phone, which is the second reader of the cash
  // runway figure. The hero card stopped stating a runway it worked out from
  // an invented burn rate, and this sheet is where the same figure is shown
  // WITH the caption that says which burn rate it used. That caption is the
  // whole reason the number is allowed here and not there, so it needs a
  // picture somebody can check rather than a comment claiming it.
  testWidgets('sheet safe_to_spend_empty renders', (WidgetTester tester) async {
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

    state.removeSampleData();
    await tester.pumpAndSettle();

    SafeToSpendSheet.show(tester.element(find.byType(AppShell)), state);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/sheet_safe_to_spend_empty.png'),
    );
  });

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

        await settleImages(tester);

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

        // SCROLLED TO THE BOTTOM for the card shape, because that is where
        // the fields this shot exists to show now live. The picture used to
        // stop at the currency dropdown, which meant the credit limit, the
        // due date and the closing day, every field that only a card has,
        // were outside the only render anybody reviews. A shot of a sheet
        // that never reaches the part the sheet is being shot FOR proves
        // nothing.
        await tester.drag(
          find.byType(SingleChildScrollView).last,
          const Offset(0, -1800),
        );
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
      await tester.tap(find.text('Amortization'));
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

  // Reconciliation with a GAP on it, which is the state worth reviewing: the
  // default shot shows an untouched form, and the whole point of the screen is
  // what it says when the two numbers disagree.
  testWidgets('reports check with a gap renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 5200);
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
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '1600');
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppShell),
      matchesGoldenFile('out/reports_check_gap.png'),
    );
  });

  // The Check tab with NO accounts on the phone.
  //
  // Worth its own shot because until storage landed it was unreachable, and
  // because what it used to do was crash in initState and take the whole
  // Reports tab white. It is a real state now: a ledger restored from a file
  // somebody cleared has no accounts in it, and neither will a new install
  // once the sample data question is settled.
  testWidgets('reports check with no accounts renders', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
      store: MemorySnapshotStore(emptyLedgerFile),
    );
    await state.restore();
    expect(
      state.accounts,
      isEmpty,
      reason:
          'the fixture has to actually be empty, or this shot proves '
          'nothing about the empty state',
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
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'the empty Check crashed');

    await expectLater(
      find.byType(AppShell),
      matchesGoldenFile('out/reports_check_empty.png'),
    );
  });

  // The instalment plans, at both brightnesses, and the two sheets.
  for (final ThemeMode2 mode in ThemeMode2.values) {
    final String theme = mode == ThemeMode2.hapon ? 'hapon' : 'gabi';

    testWidgets('installments renders in $theme', (WidgetTester tester) async {
      await tester.runAsync(loadRealFonts);

      tester.view.physicalSize = const Size(1170, 5200);
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
      await tester.tap(find.text('Plans'));
      await tester.pumpAndSettle();

      expect(find.byType(InstallmentsView), findsOneWidget);

      await expectLater(
        find.byType(DebtScreen),
        matchesGoldenFile('out/installments_$theme.png'),
      );
    });
  }

  for (final ({bool extra, String slug}) shape in <({bool extra, String slug})>[
    (extra: false, slug: 'scheduled'),
    (extra: true, slug: 'extra'),
  ]) {
    testWidgets('sheet installment ${shape.slug} renders', (
      WidgetTester tester,
    ) async {
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

      InstallmentSheet.show(
        tester.element(find.byType(AppShell)),
        palette: palette,
        state: state,
        plan: state.installments.first,
        extra: shape.extra,
      );
      await tester.pumpAndSettle();

      if (shape.extra) {
        await tester.enterText(find.byType(TextField).first, '5000');
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('GCash Wallet'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/sheet_installment_${shape.slug}.png'),
      );
    });
  }
}

/// A saved ledger with nothing in it, for the empty-state shots.
///
/// Written as a file rather than by clearing the lists, because that is how
/// an empty ledger really arrives: off the disk, through the same decoder
/// everything else goes through.
const String emptyLedgerFile = '''
{
  "schemaVersion": 1,
  "accounts": [],
  "transactions": [],
  "debts": [],
  "budgets": [],
  "goals": [],
  "upcoming": [],
  "incomeStreams": [],
  "installments": [],
  "reconciliations": []
}
''';

/// The Plan library, and the register the Debt and loan tile now opens.
///
/// Rendered because the founder reported the three debt sections missing and
/// they were not missing, the TILE was wired to the add-a-debt form. A picture
/// of the door is the only way to show that the door now works.
void planCalculatorShots() {
  testWidgets('plan calculators library renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 2532);
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
    await tester.tap(find.text('Calculators'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AppShell),
      matchesGoldenFile('out/plan_calculators.png'),
    );
  });

  testWidgets('the debt register reached from Plan renders', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 8800);
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
    await tester.tap(find.text('Calculators'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Debt and loan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amortization'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DebtScreen),
      matchesGoldenFile('out/plan_to_debt_calculators.png'),
    );
  });
}

/// The FX converter, on the built-in rates so the shot needs no network.
void fxShot() {
  testWidgets('fx converter renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Palette palette = Palette.of(ThemeMode2.gabi);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SalapifyScrollBehavior(),
        theme: salapifyTheme(palette, ThemeMode2.gabi),
        home: Scaffold(
          backgroundColor: palette.background,
          // An endpoint that resolves to nothing, so the shot exercises the
          // OFFLINE path: built-in rates on screen, no spinner, no error.
          body: FxSheet(
            palette: palette,
            service: FxService(endpoint: 'https://127.0.0.1:1/none'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(FxSheet),
      matchesGoldenFile('out/fx_converter.png'),
    );
  });
}

// The two faces of the plastic, which is the whole point of the flip and the
// one thing no other shot can show. Every other accounts render draws the
// FRONT, because that is what a card is at rest, so a back that came out
// mirror-imaged, clipped or the wrong shape would render perfectly in all of
// them and be wrong on the phone.
//
// Three cards, because the finish is the thing most likely to break: a plain
// issuer skin, a gold one with the sheen, and a bare debit with nothing
// recorded so the empty back is looked at too and not just asserted.
void _cardFaceShots() {
  const Account rewards = Account(
    id: 'shot_card_visa',
    name: 'BPI Rewards Card',
    kind: AccountKind.credit,
    institution: 'BPI',
    balance: 12480.5,
    monogram: 'BP',
    accountNumber: '**** 8819',
    creditLimit: 40000,
    dueDate: 'Oct 3',
    statementDate: 'Sep 18',
    interestRate: 3.5,
    cardNetwork: CardNetwork.visa,
    profile: ProfileEntity.personal,
  );

  const Account gold = Account(
    id: 'shot_card_gold',
    name: 'Metrobank Gold',
    kind: AccountKind.credit,
    institution: 'Metrobank',
    balance: 6200,
    monogram: 'MB',
    accountNumber: '4127 8890 2211 4402',
    creditLimit: 150000,
    dueDate: 'Oct 12',
    statementDate: 'Sep 26',
    interestRate: 2.0,
    cardNetwork: CardNetwork.mastercard,
    cardTier: CardTier.gold,
    profile: ProfileEntity.personal,
  );

  const Account bare = Account(
    id: 'shot_card_bare',
    name: 'GoTyme Debit',
    kind: AccountKind.debit,
    institution: 'GoTyme',
    balance: 3150,
    monogram: 'GT',
  );

  for (final ({String slug, bool flipped}) face
      in <({String slug, bool flipped})>[
        (slug: 'front', flipped: false),
        (slug: 'back', flipped: true),
      ]) {
    testWidgets('card ${face.slug} renders', (WidgetTester tester) async {
      await tester.runAsync(loadRealFonts);

      // TALLER than it was, because each credit card now carries a billing
      // cycle strip under its utilisation bar and three of them stopped
      // fitting. The Column here is fixed height on purpose, so it reddens
      // loudly rather than clipping a card out of a picture somebody is
      // reviewing; this is that alarm being answered, not silenced.
      tester.view.physicalSize = const Size(1170, 3200);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final Palette palette = Palette.of(ThemeMode2.gabi);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: const SalapifyScrollBehavior(),
          theme: salapifyTheme(palette, ThemeMode2.gabi),
          home: Scaffold(
            backgroundColor: palette.background,
            body: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (final Account a in <Account>[rewards, gold, bare])
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.lg),
                      child: BankCard(
                        account: a,
                        palette: palette,
                        onTap: () {},
                        // A FIXED CLOCK, so the cycle strip says the same
                        // thing tomorrow. Without it every rerun of this
                        // shot differs from the last by a day in two places
                        // and nobody can tell a real change from the
                        // calendar moving.
                        now: DateTime(2026, 9, 20, 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await settleImages(tester);

      if (face.flipped) {
        for (final Element e in find.byType(BankCard).evaluate()) {
          await tester.tap(find.byWidget(e.widget));
        }
        await tester.pumpAndSettle();

        expect(
          find.text('Tap to turn back'),
          findsNWidgets(3),
          reason: 'a card did not turn, so this shot is not of the back',
        );
      }

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('out/card_${face.slug}.png'),
      );
    });
  }
}

/// Home on a ledger that holds ONLY real money, with no payday set.
///
/// This is what every install looks like the moment the sample data is
/// cleared, and it is the shot that proves two money defects are gone. Before
/// the fix this screen said Safe to Spend ₱0.00, because ₱41,184 of demo bills
/// and ₱6,348 of demo instalment plans were reserved against obligations the
/// person had never entered and could find on no screen; and the line beneath
/// it offered a per-day figure equal to the whole fortnight, because the
/// engine divides by max(1, daysToPayday) and nobody had set a payday.
void realMoneyHomeShot() {
  testWidgets('home with only real money renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 2900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final MemorySnapshotStore store = MemorySnapshotStore();
    await store.write('''
{
  "schemaVersion": 1,
  "accounts": [
    {"id": "real_1", "name": "My GCash", "kind": "gcash",
     "institution": "GCash", "balance": 50000, "monogram": "GC"}
  ],
  "transactions": [], "debts": [], "budgets": [], "goals": [],
  "upcoming": [], "incomeStreams": [], "installments": [],
  "reconciliations": [], "bills": []
}
''');

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 19),
      store: store,
    );
    await state.restore();

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
    await settleImages(tester);

    await expectLater(
      find.byType(AppShell),
      matchesGoldenFile('out/home_real_money_only.png'),
    );
  });
}

/// Settings, and the compact storage strip that now points at it.
void settingsShots() {
  testWidgets('settings renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 2600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 19),
    );
    // RESTORED, so the panel shows the healthy state. A store that has never
    // been restored is neither saving nor failing, and the first version of
    // this shot rendered that in-between state as an alarm, which is how the
    // three-way fix in settings_sheet.dart got found.
    await state.restore();
    final Palette palette = Palette.of(state.theme);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SalapifyScrollBehavior(),
        theme: salapifyTheme(palette, state.theme),
        home: Scaffold(
          backgroundColor: palette.background,
          body: SettingsSheet(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await settleImages(tester);

    await expectLater(
      find.byType(SettingsSheet),
      matchesGoldenFile('out/settings.png'),
    );
  });
}

/// The toolkit's four tabs, which the founder asked to match the prototype.
void toolkitShots() {
  for (final ({int index, String slug}) tab in <({int index, String slug})>[
    (index: 0, slug: 'notes'),
    (index: 1, slug: 'mindset'),
    (index: 2, slug: 'treats'),
  ]) {
    testWidgets('toolkit ${tab.slug} renders', (WidgetTester tester) async {
      await tester.runAsync(loadRealFonts);

      tester.view.physicalSize = const Size(1170, 2900);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final FinancialState state = FinancialState(
        clock: DateTime.utc(2026, 9, 19),
      );
      final Palette palette = Palette.of(state.theme);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: const SalapifyScrollBehavior(),
          theme: salapifyTheme(palette, state.theme),
          home: Scaffold(
            backgroundColor: palette.background,
            body: ToolkitSheet(state: state),
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (tab.index > 0) {
        await tester.tap(
          find.text(<String>['Notes Calc', 'Mindset', 'Treats'][tab.index]),
        );
        await tester.pumpAndSettle();
      }

      // The mindset tab only shows its verdict after it is asked, and the
      // verdict is the whole feature, so the shot asks.
      if (tab.index == 1) {
        await tester.ensureVisible(find.text('Should I buy it?'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Should I buy it?'));
        await tester.pumpAndSettle();
      }

      await expectLater(
        find.byType(ToolkitSheet),
        matchesGoldenFile('out/toolkit_${tab.slug}.png'),
      );
    });
  }
}

/// The restore screen, and the confirmation in front of the most destructive
/// action in the app.
void importShots() {
  const String backup =
      '{"schemaVersion":1,'
      '"accounts":[{"id":"a1","name":"Their BPI","kind":"bank",'
      '"institution":"BPI","balance":71940,"monogram":"BPI"},'
      '{"id":"m1","name":"Housing loan","kind":"mortgage",'
      '"institution":"Pag-IBIG","balance":200300,"monogram":"MTG"}],'
      '"transactions":[],"debts":[],"budgets":[],"goals":[],'
      '"upcoming":[],"incomeStreams":[],"installments":[],'
      '"reconciliations":[],"bills":[],'
      '"timestamp":"2026-09-12T08:00:00.000Z"}';

  for (final ({String slug, bool confirm}) shot
      in <({String slug, bool confirm})>[
        (slug: 'preview', confirm: false),
        (slug: 'confirm', confirm: true),
      ]) {
    testWidgets('import ${shot.slug} renders', (WidgetTester tester) async {
      await tester.runAsync(loadRealFonts);

      tester.view.physicalSize = const Size(1170, 3000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final FinancialState state = FinancialState(
        clock: DateTime.utc(2026, 9, 19),
        store: MemorySnapshotStore(),
      );
      await state.restore();
      final Palette palette = Palette.of(state.theme);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: const SalapifyScrollBehavior(),
          theme: salapifyTheme(palette, state.theme),
          home: Scaffold(
            backgroundColor: palette.background,
            body: ImportSheet(state: state),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Paste a backup instead'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), backup);
      await tester.tap(find.text('Read what I pasted'));
      await tester.pumpAndSettle();

      if (shot.confirm) {
        await tester.tap(find.text('Replace everything with this backup'));
        await tester.pumpAndSettle();
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/import_${shot.slug}.png'),
      );
    });
  }
}

/// THE SAME SCREENS WITH LARGE TEXT ON.
///
/// Added 2026-09-22, and the reason it did not exist before is the reason it
/// exists now. Every other shot in this file renders at the default font
/// size, so a defect that only appears when somebody turns text up was
/// invisible to the whole harness. `screen_readability_test.dart` found a
/// dozen of them by measurement, and measurement is the right gate, but a
/// measurement cannot answer the question the founder actually asks of a
/// picture: does it still look like the app.
///
/// 1.5x is the middle of Android's own Font size slider, not an extreme.
/// Dark first, because that is what the founder uses.
void largeTextShots() {
  for (final ({String slug, IconData? icon}) tab
      in <({String slug, IconData? icon})>[
        (slug: 'home', icon: null),
        (slug: 'reports', icon: Icons.insert_chart_outlined),
        (slug: 'accounts', icon: Icons.account_balance_wallet_outlined),
      ]) {
    testWidgets('${tab.slug} renders at 1.5x text', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(loadRealFonts);

      // Taller than the phone, because large text makes every screen longer
      // and a render that cuts the last card off is worse than one with a
      // margin.
      tester.view.physicalSize = const Size(1170, 5400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final FinancialState state = FinancialState(
        clock: DateTime.utc(2026, 9, 18),
      );
      // Gabi is the dark theme and the default, so nothing is toggled here.
      final Palette palette = Palette.of(state.theme);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            scrollBehavior: const SalapifyScrollBehavior(),
            theme: salapifyTheme(palette, state.theme),
            home: AppShell(state: state),
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (tab.icon != null) {
        await tester.tap(find.byIcon(tab.icon!));
        await tester.pumpAndSettle();
      }

      await expectLater(
        find.byType(AppShell),
        matchesGoldenFile('out/large_text_${tab.slug}.png'),
      );
    });
  }
}

/// The Philippine business registration checklist, ported 2026-09-22.
///
/// Both brightnesses, and a second dark shot with some steps already ticked,
/// because a checklist nobody has touched cannot show what a ticked row looks
/// like next to an unticked one, which is the only thing worth looking at.
///
/// It renders the screen inside a Scaffold rather than through the shell, and
/// that is the one compromise here: reaching it for real means tapping Plan,
/// then Academy, then scrolling to a card, and a render harness that has to
/// drive three taps before it can draw anything is a harness that breaks
/// whenever any of the three moves. The JOURNEY test does the tapping and
/// asserts the door is reachable; this only has to show the room.
void businessChecklistShots() {
  for (final ThemeMode2 mode in ThemeMode2.values) {
    final String theme = mode == ThemeMode2.hapon ? 'hapon' : 'gabi';
    for (final bool ticked in <bool>[false, true]) {
      // Only one ticked variant, in dark, which is what the founder uses.
      if (ticked && mode == ThemeMode2.hapon) continue;
      final String name = ticked ? '${theme}_ticked' : theme;

      testWidgets('business checklist renders in $name', (
        WidgetTester tester,
      ) async {
        await tester.runAsync(loadRealFonts);
        tester.view.physicalSize = const Size(1170, 4600);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final FinancialState state = FinancialState(
          clock: DateTime.utc(2026, 9, 22),
        );
        if (state.theme != mode) state.toggleTheme();
        if (ticked) {
          for (final String id in <String>[
            'chk_dti_sec',
            'chk_trademark',
            'chk_brgy',
            'chk_locational',
          ]) {
            state.toggleGuideStep(id);
          }
        }
        final Palette palette = Palette.of(state.theme);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            scrollBehavior: const SalapifyScrollBehavior(),
            theme: salapifyTheme(palette, state.theme),
            home: Scaffold(
              backgroundColor: palette.background,
              body: SafeArea(
                bottom: false,
                child: BusinessGuideScreen(state: state, onBack: () {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(BusinessGuideScreen),
          matchesGoldenFile('out/business_checklist_$name.png'),
        );
      });
    }
  }
}

/// The roadmap and the structure matcher, added 2026-09-22.
///
/// Dark only, which is what the founder reviews. The checklist shots above
/// already cover both brightnesses for this screen's chrome, and what is
/// being looked at here is layout: six collapsible phases and a three
/// question matcher are the two things in this guide most likely to come out
/// as a wall.
void businessGuideViewShots() {
  for (final ({String slug, String segment, bool answer}) shot
      in <({String slug, String segment, bool answer})>[
        (slug: 'roadmap', segment: 'Order', answer: false),
        (slug: 'structure', segment: 'Structure', answer: false),
        (slug: 'structure_matched', segment: 'Structure', answer: true),
        (slug: 'traps', segment: 'Traps', answer: false),
      ]) {
    testWidgets('business guide ${shot.slug} renders', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(loadRealFonts);
      tester.view.physicalSize = const Size(1170, 5200);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final FinancialState state = FinancialState(
        clock: DateTime.utc(2026, 9, 22),
      );
      final Palette palette = Palette.of(state.theme);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: const SalapifyScrollBehavior(),
          theme: salapifyTheme(palette, state.theme),
          home: Scaffold(
            backgroundColor: palette.background,
            body: SafeArea(
              bottom: false,
              child: BusinessGuideScreen(state: state, onBack: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(shot.segment));
      await tester.pumpAndSettle();

      if (shot.answer) {
        // One tap is enough to produce a recommendation, which is the
        // behaviour worth looking at: the card appears from a single answer.
        await tester.tap(find.text('Just me'));
        await tester.pumpAndSettle();
      }

      await expectLater(
        find.byType(BusinessGuideScreen),
        matchesGoldenFile('out/business_guide_${shot.slug}.png'),
      );
    });
  }
}
