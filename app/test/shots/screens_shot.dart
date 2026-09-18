import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/scroll_behavior.dart';
import 'package:salapify/design/tokens.dart';
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
  for (final ThemeMode2 mode in ThemeMode2.values) {
    final String name = mode == ThemeMode2.hapon ? 'hapon' : 'gabi';

    testWidgets('home renders in $name', (WidgetTester tester) async {
      await tester.runAsync(loadRealFonts);

      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // The palette is read during build, so the theme is set BEFORE pumping.
      final FinancialState state =
          FinancialState(clock: DateTime.utc(2026, 9, 18));
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
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'PlusJakartaSans',
            scaffoldBackgroundColor: palette.background,
          ),
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
