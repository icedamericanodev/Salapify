import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/scroll_behavior.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/categories/category_manager_sheet.dart';
import 'package:salapify/features/log/log_sheet.dart';
import 'package:salapify/features/debt/add_debt_sheet.dart';
import 'package:salapify/features/safe_to_spend/safe_to_spend_sheet.dart';
import 'package:salapify/features/tax/business_tax_sheet.dart';
import 'package:salapify/features/tax/tax_calculator_sheet.dart';
import 'package:salapify/features/toolkit/toolkit_sheet.dart';
import 'package:salapify/screens/activity/activity_screen.dart';
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

    await tester.enterText(find.byType(TextField).first, '250');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('log-source-picker')),
        matching: find.text('Cash on Hand (Pitaka)'),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/log_sheet.png'),
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
}
