import 'package:salapify/core/money/money.dart';
import 'dart:convert';
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
import 'package:salapify/features/accounts/move_money_sheet.dart';
import 'package:salapify/features/bills/bills_sheet.dart';
import 'package:salapify/features/debt/add_debt_sheet.dart';
import 'package:salapify/features/debt/split_bill_sheet.dart';
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
import 'package:salapify/screens/home/runway_row.dart';
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
import 'package:salapify/features/onboarding/first_account_screen.dart';
import 'package:salapify/features/onboarding/welcome_screen.dart';
import 'package:salapify/screens/activity/transaction_detail_sheet.dart';
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
  unreadableRecoveryShots();
  settleConfirmShot();
  takeBackShot();
  takenBackRowShot();
  debtRemovalShots();
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
        state.setPaydayRule(
          daysOfMonth: shape.days,
          expectedIncome: Money.pesos(20000),
        );
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
  // The runway explainer, reached the way a person reaches it: by tapping the
  // dot on the card itself. Opening the sheet directly would photograph a
  // sheet that renders, which is not the same as a dot that works.
  // Home on the hardest phone it has to survive: 320dp wide AND 1.5x system
  // font at once. The readability sweep already asserts nothing overflows or
  // truncates there, which is a different question from whether it reads
  // well, and only an eye answers the second one.
  testWidgets('home runway narrow large renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(960, 2400);
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
        home: MediaQuery(
          // Built fresh rather than copied off the view, which has no
          // MediaQuery ancestor this early. Same shape the readability sweep
          // uses at screen_readability_test.dart:307.
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: AppShell(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/home_runway_narrow_large.png'),
    );
  });

  testWidgets('info sheet runway renders', (WidgetTester tester) async {
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

    await tester.tap(
      find.descendant(
        of: find.byType(RunwayRow),
        matching: find.byType(InfoDot),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(InfoSheet),
      findsOneWidget,
      reason: 'the dot on the runway card did not open an explainer',
    );
    expect(find.text('Runway'), findsWidgets);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/info_sheet_runway.png'),
    );
  });

  // The capped minimum, which is the fix most likely to be costing the
  // founder real money today. A card entered with a 3,000 monthly minimum and
  // paid down until 500 is left must reserve 500, not 3,000.
  testWidgets('safe to spend capped minimum renders', (
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

    state.addDebt(
      Debt(
        id: 'debt_nearly_paid',
        person: 'BPI Rewards Card',
        direction: DebtDirection.iOwe,
        totalAmount: const Money.pesos(60000),
        paidAmount: const Money.pesos(59500),
        isSettled: false,
        minimumPayment: const Money.pesos(3000),
        dueDate: '15',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SalapifyScrollBehavior(),
        theme: salapifyTheme(palette, state.theme),
        home: AppShell(state: state),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('DETAILS'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/safe_to_spend_capped_minimum.png'),
    );
  });

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
        // The cash answer was reviewed only from a founder's phone
        // screenshot, which is how "across 11 accounts" survived: the count
        // said 11 and the figure summed 5, and no render in this harness
        // had ever shown that sentence.
        (name: 'pan_cash', openWith: 'panCash'),
        // The refusal answer, which is a licensing boundary and the longest
        // answer in the file, and a long list answer, which is where the
        // bullet rendering either holds up or does not.
        (name: 'pan_boundary', openWith: 'panBoundary'),
        (name: 'pan_due', openWith: 'panDue'),
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
        case 'panCash':
        case 'panBoundary':
        case 'panDue':
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
        'panCash': 'how much do i have',
        'panBoundary': 'should i invest in stocks',
        'panDue': 'what is due soon',
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

  // Bills, in both of the states worth reviewing: the list, and the schedule
  // form open so the kind chips and the fields can be checked.
  for (final ({String slug, bool adding}) shape
      in <({String slug, bool adding})>[
        (slug: 'bills', adding: false),
        (slug: 'bills_adding', adding: true),
      ]) {
    testWidgets('sheet ${shape.slug} renders', (WidgetTester tester) async {
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

      BillsSheet.show(
        tester.element(find.byType(AppShell)),
        palette: palette,
        state: state,
      );
      await tester.pumpAndSettle();

      if (shape.adding) {
        await tester.tap(find.text('Schedule a bill'));
        await tester.pumpAndSettle();
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/sheet_${shape.slug}.png'),
      );
    });
  }

  // Move money, in both of the states worth reviewing: as it opens, and with
  // a move filled in so the figures and the closing sentence are visible.
  for (final ({String slug, bool filled}) shape
      in <({String slug, bool filled})>[
        (slug: 'move_money', filled: false),
        (slug: 'move_money_working', filled: true),
        // THE CARD PAYMENT, which is a different sheet in everything but
        // layout: the destination label, the button, the icon, the missing
        // swap control and the closing sentence all change. None of that is
        // visible in either shot above, because until 2026-10-05 a card could
        // not be a destination at all.
        (slug: 'move_money_card', filled: true),
      ]) {
    testWidgets('sheet ${shape.slug} renders', (WidgetTester tester) async {
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

      MoveMoneySheet.show(
        tester.element(find.byType(AppShell)),
        palette: palette,
        state: state,
      );
      await tester.pumpAndSettle();

      if (shape.slug == 'move_money_card') {
        // Point the destination at the credit card. Index 1 is where money
        // arrives; the dropdowns are driven by POSITION rather than by their
        // floating labels, for the reason the move money journey records at
        // length (a filled field floats its label into a corner where the
        // decoration receives the pointer, and tap only WARNS about that).
        await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Rewards Card').last);
        await tester.pumpAndSettle();
      }

      if (shape.filled) {
        // 1,200 out of the pitaka, which it can cover. The first version of
        // this shot typed 2,500 against an 1,850 balance, so the "working"
        // picture was really a picture of the refusal panel. A shot meant to
        // show the ordinary state has to be in the ordinary state.
        await tester.enterText(find.widgetWithText(TextField, '0.00'), '1200');
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Cash in for dinner'),
          'Topping up the wallet',
        );
        await tester.pumpAndSettle();
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/sheet_${shape.slug}.png'),
      );
    });
  }

  // The onboarding screens, for founder review BEFORE they are wired up.
  //
  // Nothing in lib/main.dart routes to either of these yet, deliberately: the
  // design they implement depends on two founder-gated decisions (whether the
  // demo data survives a fresh install, and one stored field so the app can
  // remember it has introduced itself). Drawing them costs nothing and
  // changes nothing; wiring them would change what a fresh install does.
  //
  // The first-account screen renders twice. Empty is what somebody meets, so
  // it has to explain itself with nothing typed in it. Filled carries the
  // figure and the live Done button, which is the half worth arguing over.
  for (final ({String slug, bool filled}) shape
      in <({String slug, bool filled})>[
        (slug: 'onboarding_welcome', filled: false),
        (slug: 'onboarding_account', filled: false),
        (slug: 'onboarding_account_filled', filled: true),
      ]) {
    testWidgets('${shape.slug} renders', (WidgetTester tester) async {
      await tester.runAsync(loadRealFonts);

      tester.view.physicalSize = const Size(1170, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final FinancialState state = FinancialState(clock: DateTime(2026, 9, 18));
      final Palette palette = Palette.of(state.theme);
      final bool welcome = shape.slug == 'onboarding_welcome';

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: const SalapifyScrollBehavior(),
          theme: salapifyTheme(palette, state.theme),
          home: welcome
              ? WelcomeScreen(palette: palette)
              : FirstAccountScreen(palette: palette),
        ),
      );
      await tester.pumpAndSettle();

      // The brand mark is an ASSET, and an asset decodes asynchronously.
      // testWidgets runs on a fake clock, so the decode never completes and
      // the first render of this screen came out with a hole where the logo
      // is. Same gotcha as the fonts, same fix: do the real IO inside
      // runAsync, then pump.
      if (welcome) {
        await tester.runAsync(() async {
          await precacheImage(
            const AssetImage('assets/brand/salapify_logo.png'),
            tester.element(find.byType(MaterialApp)),
          );
        });
        await tester.pumpAndSettle();
      }

      if (shape.filled) {
        // The second field is the balance; the first is the name.
        await tester.enterText(find.byType(TextField).at(1), '5140');
        await tester.pumpAndSettle();
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/${shape.slug}.png'),
      );
    });
  }

  // Home with the demo data swept, which is what a stranger would meet if a
  // fresh install started empty.
  //
  // ADDED ALONGSIDE the lived-in shots, never in place of them. This file's
  // own history is the warning: every per-tab shot ran against an empty store
  // for most of the harness's life, so sixteen images were all first-run
  // screens and a crossed-out peso sign reached the founder's phone unseen.
  // One deliberate empty shot answers a design question the lived-in ones
  // cannot; replacing the lived-in ones with it would reopen that hole.
  testWidgets('home swept renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 2800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(clock: DateTime(2026, 9, 18));
    await state.restore();
    final Palette palette = Palette.of(state.theme);

    // The real sweep, not a hand-built empty store, so this is a picture of a
    // state the app can genuinely be in rather than one only a test can reach.
    state.removeSampleData();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SalapifyScrollBehavior(),
        theme: salapifyTheme(palette, state.theme),
        home: AppShell(state: state),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/home_swept.png'),
    );
  });

  // The entry detail sheet, in its two new states.
  //
  // `takeable` is an ordinary logged entry, which now carries the control.
  // `refused` is an entry Salapify wrote itself to explain a debt payment,
  // which carries the sentence saying where the real take-back lives instead.
  // Two shots because the second is the one worth arguing about: a refusal
  // that reads as a dead end is a worse screen than no control at all.
  for (final bool takeable in <bool>[true, false]) {
    testWidgets(
      'sheet entry detail ${takeable ? 'takeable' : 'refused'} renders',
      (WidgetTester tester) async {
        await tester.runAsync(loadRealFonts);

        tester.view.physicalSize = const Size(1170, 3000);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final FinancialState state = FinancialState(
          clock: DateTime(2026, 9, 18),
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

        late final Transaction subject;
        if (takeable) {
          subject = state.transactions.firstWhere(
            (Transaction t) => t.id == 'tx_jollibee',
          );
        } else {
          // A real payment through the real write path, so the refused shot
          // is of a genuine engine entry rather than a lookalike.
          final Debt d = state.debts.firstWhere(
            (Debt x) => x.direction == DebtDirection.iOwe && !x.isSettled,
          );
          state.recordDebtPayment(d.id, 500, accountId: 'acc_gcash');
          await tester.pumpAndSettle();
          subject = state.transactions.firstWhere(
            (Transaction t) => t.id.startsWith('tx_debt_'),
          );
        }

        TransactionDetailSheet.show(
          tester.element(find.byType(AppShell)),
          palette: palette,
          transaction: subject,
          state: state,
          accounts: state.accounts,
          now: state.now,
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'out/sheet_entry_detail_${takeable ? 'takeable' : 'refused'}.png',
          ),
        );
      },
    );
  }

  // The confirmation and the undo, AFTER a split has been recorded.
  //
  // Driven through the Home shortcut rather than by calling the sheet
  // directly, because the thing being photographed does not belong to the
  // sheet. The sheet hands back what it wrote; Home is what decides to say so
  // and to offer five seconds to take it back. A shot that opened the sheet
  // on its own would be a picture of the old silent behaviour.
  testWidgets('home split confirmation renders', (WidgetTester tester) async {
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

    // SCROLLED TO, not merely ensureVisible'd. Home's list builds lazily, so
    // a widget below the viewport is not built at all and `find.text` matches
    // nothing: ensureVisible then throws "Bad state: No element" rather than
    // scrolling. Adding the runway row to Home pushed Quick Actions about
    // 88dp down, which was enough. The same class of breakage once took out
    // eleven journey tests when another card landed above it.
    final Finder door = find.text('Split');
    await tester.scrollUntilVisible(
      door,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(door.first);
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '2400');
    await tester.enterText(fields.at(1), 'Barkada lunch');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Their name'),
      'Carla',
    );
    await tester.pumpAndSettle();
    final Finder add = find.bySemanticsLabel('Add this person to the split');
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();

    final Finder record = find.text('Record it');
    await tester.ensureVisible(record);
    await tester.pumpAndSettle();
    await tester.tap(record);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/home_split_confirmation.png'),
    );
  });

  // Split a bill, in both of the states worth reviewing.
  //
  // Two shots rather than one, because the empty sheet and the working sheet
  // answer different questions. The empty one is what somebody meets, so it
  // has to explain itself with nothing typed in it. The working one carries
  // the per-person figures, the running total and the reconcile line, which
  // is the part a founder can look at and say "that number is in the wrong
  // place".
  for (final ({String slug, bool filled}) shape
      in <({String slug, bool filled})>[
        (slug: 'split_bill', filled: false),
        (slug: 'split_bill_working', filled: true),
      ]) {
    testWidgets('sheet ${shape.slug} renders', (WidgetTester tester) async {
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

      SplitBillSheet.show(
        tester.element(find.byType(AppShell)),
        palette: palette,
        state: state,
      );
      await tester.pumpAndSettle();

      if (shape.filled) {
        // A 2,400 lunch three ways, which is the case the screen exists for:
        // it does not divide evenly, so the centavo has to land somewhere
        // visible rather than be quietly dropped.
        final Finder fields = find.byType(TextField);
        await tester.enterText(fields.at(0), '2400');
        await tester.enterText(fields.at(1), 'Barkada lunch');
        await tester.pumpAndSettle();

        // The add control is an icon with a semantics label, not a button
        // reading "Add", so it is found the way the journey test finds it.
        for (final String who in <String>['Carla', 'Miggy']) {
          await tester.enterText(
            find.widgetWithText(TextField, 'Their name'),
            who,
          );
          await tester.pumpAndSettle();
          final Finder add = find.bySemanticsLabel(
            'Add this person to the split',
          );
          await tester.ensureVisible(add);
          await tester.pumpAndSettle();
          await tester.tap(add);
          await tester.pumpAndSettle();
        }
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('out/sheet_${shape.slug}.png'),
      );
    });
  }

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
        balance: Money.pesos(2000),
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

  // ---------------------------------------------------------------------
  // P2.3, protected accounts. Three surfaces, none of which any existing
  // shot reaches.
  // ---------------------------------------------------------------------

  // The "what this money is for" picker. It needs its own shot because it
  // sits BELOW the balance field, and `sheet_add_account_plain` stops at
  // the balance: the one picture anybody reviews would not contain the
  // control being reviewed.
  testWidgets('sheet account purpose renders', (WidgetTester tester) async {
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

    // Opened on the account that actually carries the flag, so the picture
    // shows the control in its SET state rather than its default. A shot of
    // a control nobody has touched proves only that it renders.
    AccountSheet.show(
      tester.element(find.byType(AppShell)),
      palette: palette,
      state: state,
      existing: state.accounts.firstWhere((Account a) => a.id == 'acc_maya'),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/sheet_account_purpose.png'),
    );
  });

  // P2.4's field: what a debt costs each month. It renders only for money you
  // owe that has no instalment schedule, which is the default state of the
  // sheet, so no tapping is needed to reach it.
  testWidgets('sheet add debt minimum renders', (WidgetTester tester) async {
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

    AddDebtSheet.show(tester.element(find.byType(AppShell)), palette);
    await tester.pumpAndSettle();

    // Filled in, because the picture exists to show the field in use rather
    // than to prove an empty form renders.
    await tester.enterText(find.byType(TextField).first, 'BPI Rewards Card');
    await tester.enterText(find.byType(TextField).at(1), '18000');
    await tester.enterText(find.byKey(const Key('debt-minimum')), '1500');
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/sheet_add_debt_minimum.png'),
    );
  });

  // The same field holding something it cannot read. Worth a picture of its
  // own, because the defect it closes was invisible by definition: a figure
  // typed as "1.5.0" used to save as NO minimum at all, with no message, and
  // the only evidence was a reservation of zero on a screen two taps away.
  // The runway row in the state the seed cannot reach: actually running
  // short. The sample ledger is comfortable, so without this the founder only
  // ever sees the quiet version of a card whose whole reason to exist is the
  // loud one.
  testWidgets('home runway short renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 1150);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    final Palette palette = Palette.of(state.theme);

    // DRAINED BEFORE THE PUMP, not after. RunwayRow is stateless and reads
    // the projection once per build, so a mutation after pumping changes the
    // store and never reaches the pixels. The first version of this shot did
    // exactly that and photographed the comfortable state while claiming to
    // show the loud one, which is a screenshot that proves the opposite of
    // what it says.
    for (final Account a
        in state.accounts.where((Account a) => a.isSpendable).toList()) {
      state.updateAccount(a.copyWith(balance: const Money.pesos(500)));
    }

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SalapifyScrollBehavior(),
        theme: salapifyTheme(palette, state.theme),
        home: Scaffold(
          backgroundColor: palette.background,
          body: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: RunwayRow(
              state: state,
              onSeeDue: () {},
              onSetPayday: () {},
              onInfo: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/home_runway_short.png'),
    );
  });

  // The notice block on the hardest phone it has to survive: 320dp wide AND
  // 1.5x system font at once, with all three notices firing.
  //
  // IT EXISTS BECAUSE THE FULL-HOME SHOT AT THE SAME SETTINGS CANNOT SHOW
  // IT. `home runway narrow large renders` photographs the whole scroll view
  // and this card falls below the fold, so the one picture that claimed to
  // cover the hardest case has never contained the thing being reviewed.
  // Moving the notices to full card width was justified by a measurement at
  // exactly these settings, and a measurement nobody can look at is a
  // measurement nobody can check.
  testWidgets('runway notices narrow large render', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(960, 1900);
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
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(
            backgroundColor: palette.background,
            body: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: RunwayRow(
                state: state,
                onSeeDue: () {},
                onSetPayday: () {},
                onInfo: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/runway_notices_narrow_large.png'),
    );
  });

  testWidgets('sheet add debt minimum problem renders', (
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

    AddDebtSheet.show(tester.element(find.byType(AppShell)), palette);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'BPI Rewards Card');
    await tester.enterText(find.byType(TextField).at(1), '18000');
    await tester.enterText(find.byKey(const Key('debt-minimum')), '1.5.0');
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/sheet_add_debt_minimum_problem.png'),
    );
  });

  // The one-time review card. It needs a ledger the card would actually
  // appear on: two real liquid accounts, nothing protected yet, which is
  // exactly the shape every existing user is in on the day this ships.
  testWidgets('accounts set aside review renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 2200);
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

    await state.deleteEverything();
    await tester.pumpAndSettle();
    state.addAccount(
      const Account(
        id: 'own_gcash',
        name: 'GCash',
        kind: AccountKind.gcash,
        institution: 'GCash',
        balance: Money.pesos(4200),
        monogram: 'GC',
      ),
    );
    state.addAccount(
      const Account(
        id: 'own_gsave',
        name: 'GSave',
        kind: AccountKind.gcash,
        institution: 'GCash',
        balance: Money.pesos(60000),
        monogram: 'GS',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/accounts_set_aside_review.png'),
    );
  });

  // Step 1 of the Safe to Spend audit, which is the sentence that goes
  // FALSE the day anything is set aside. It lives behind the sheet's own
  // Audit & Math tab and below the fold, so no existing shot reaches it.
  testWidgets('sheet safe_to_spend audit renders', (WidgetTester tester) async {
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

    SafeToSpendSheet.show(tester.element(find.byType(AppShell)), state);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Audit & Math'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/sheet_safe_to_spend_audit.png'),
    );
  });

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
    balance: Money.of(12480, 50),
    monogram: 'BP',
    accountNumber: '**** 8819',
    creditLimit: Money.pesos(40000),
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
    balance: Money.pesos(6200),
    monogram: 'MB',
    accountNumber: '4127 8890 2211 4402',
    creditLimit: Money.pesos(150000),
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
    balance: Money.pesos(3150),
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

/// "Mark settled" now asks first, and the question is the whole feature.
///
/// The button fills the rest of the debt in as paid, which is a figure
/// appearing out of nothing, and all a person previously saw was a progress
/// bar reaching the end. There was no confirmation at all, and the paired
/// button, "Not settled after all", destroyed the real figure permanently.
///
/// Rendered because the thing being reviewed is whether the question actually
/// reads as a question about MONEY rather than a yes or no about a flag.
void settleConfirmShot() {
  testWidgets('the Mark settled confirmation renders', (
    WidgetTester tester,
  ) async {
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
        home: Scaffold(
          backgroundColor: palette.background,
          body: DebtScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark settled').first);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AlertDialog),
      matchesGoldenFile('out/debt_settle_confirm.png'),
    );
  });
}

/// How a TAKEN BACK payment reads in Activity.
///
/// Founder direction, 2026-10-02: the row stays rather than vanishing, because
/// a payment you took back is part of your history and a gap with no
/// explanation is worse than a line you can read. Rendered because the whole
/// point is whether it reads as deliberate rather than as a mistake.
void takenBackRowShot() {
  testWidgets('a taken back entry renders in Activity', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    await state.restore();
    // Through the real paths, so the row on screen is one the app actually
    // produces rather than a fixture somebody typed into the shape they hoped
    // for.
    state.recordDebtPayment('debt_homecredit', 1500, accountId: 'acc_gcash');
    state.takeBackDebtPayment('debt_homecredit');
    final Palette palette = Palette.of(state.theme);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SalapifyScrollBehavior(),
        theme: salapifyTheme(palette, state.theme),
        home: Scaffold(
          backgroundColor: palette.background,
          body: ActivityScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ActivityScreen),
      matchesGoldenFile('out/activity_taken_back.png'),
    );
  });
}

/// Taking a payment back, which is the one control in the app that UNDOES a
/// money write.
///
/// Rendered because the question has to name BOTH sides: a payment moved the
/// debt and the account, so a dialog naming only the amount leaves somebody to
/// do the arithmetic they came here to avoid.
void takeBackShot() {
  testWidgets('the take back confirmation renders', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    await state.restore();
    // A payment to take back, through the real write path, so the dialog is
    // reading a register row rather than a fixture somebody typed.
    state.recordDebtPayment('debt_homecredit', 1500, accountId: 'acc_gcash');
    final Palette palette = Palette.of(state.theme);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SalapifyScrollBehavior(),
        theme: salapifyTheme(palette, state.theme),
        home: Scaffold(
          backgroundColor: palette.background,
          body: DebtScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Take back the last payment').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take back the last payment').first);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AlertDialog),
      matchesGoldenFile('out/debt_take_back.png'),
    );
  });
}

/// Taking a debt off the list: the ARCHIVED section, and the one genuinely
/// irreversible dialog on this screen.
///
/// Both are new states nobody has looked at, which is the whole reason they
/// are here. The archive shot is the one that matters: a section that holds
/// the ONLY way back out of archiving is worthless if it does not read as a
/// place you can get to.
void debtRemovalShots() {
  Future<FinancialState> seeded() async {
    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    await state.restore();
    return state;
  }

  Future<void> pump(WidgetTester tester, FinancialState state) async {
    final Palette palette = Palette.of(state.theme);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scrollBehavior: const SalapifyScrollBehavior(),
        theme: salapifyTheme(palette, state.theme),
        home: Scaffold(
          backgroundColor: palette.background,
          body: DebtScreen(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the archived section renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    // TALLER than the standard phone frame on purpose. At 2532 the ARCHIVED
    // heading lands exactly on the bottom edge and its card is off screen,
    // so the render proved the section existed while showing none of the
    // thing being reviewed. A picture that cannot show the defect is the
    // fixture problem this harness has been bitten by before.
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = await seeded();
    // Through the real paths. 'Mom' is the seeded settled debt, so this is
    // the sequence a person actually walks rather than a fixture in the
    // shape somebody hoped for.
    state.archiveDebt('debt_mom_settled');
    await pump(tester, state);

    await expectLater(
      find.byType(DebtScreen),
      matchesGoldenFile('out/debt_archived.png'),
    );
  });

  testWidgets('the delete confirmation renders', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = await seeded();
    await pump(tester, state);

    // The seeded debts with NOTHING paid are both the other way round, money
    // lent rather than borrowed, so this is the only direction where a
    // delete is offered on a fresh phone. That is correct behaviour and not
    // a fixture quirk: every borrowed debt in the seed has been paid into.
    await tester.tap(find.text('Owed to you'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Delete this debt').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete this debt').first);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AlertDialog),
      matchesGoldenFile('out/debt_delete_confirm.png'),
    );
  });
}

/// The state where Salapify cannot read your data file, which is the only
/// state these two screens are rendered in anywhere.
///
/// It is a rare state and the most consequential one, and until now there was
/// no picture of it at all. Both shots exist because the thing being reviewed
/// is whether the screen reads as a WARNING: in the dark palette `accent` and
/// `negative` are the same orange, so a bordered card here can read as brand
/// chrome rather than as something wrong.
void unreadableRecoveryShots() {
  // Past the point where a double can still count every centavo, so the
  // decoder refuses it. This is the realistic route into the state: every file
  // already on a phone was written by a build with no magnitude check.
  final String unreadable = jsonEncode(<String, dynamic>{
    'schemaVersion': 1,
    'accounts': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'acc_real',
        'name': 'My real bank',
        'kind': 'bank',
        'institution': 'BPI',
        'balance': 48000,
        'monogram': 'B',
      },
    ],
    'transactions': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'tx_bad',
        'type': 'expense',
        'amount': 1e17,
        'category': 'Food',
        'accountId': 'acc_real',
        'date': '2026-09-12',
        'createdAt': 1,
      },
    ],
  });

  testWidgets('home in the unreadable state renders', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 19),
      store: MemorySnapshotStore(unreadable),
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

    await expectLater(
      find.byType(AppShell),
      matchesGoldenFile('out/home_unreadable.png'),
    );
  });

  testWidgets('settings in the unreadable state renders', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 2600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 19),
      store: MemorySnapshotStore(unreadable),
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
          body: SettingsSheet(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await settleImages(tester);

    await expectLater(
      find.byType(SettingsSheet),
      matchesGoldenFile('out/settings_unreadable.png'),
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
