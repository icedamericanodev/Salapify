import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/shell/app_shell.dart';
import 'package:salapify/state/financial_state.dart';
import 'package:salapify/design/scroll_behavior.dart';

import 'screens_shot.dart' show loadRealFonts;

/// What a BRAND NEW install looks like on a day that is not the seed's own.
///
/// Not part of the regular shot set, which pins to the anchor on purpose so
/// the committed renders stay comparable. This one exists to show the founder
/// the thing the fix was for.
void main() {
  testWidgets('home on a future date', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 6000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final FinancialState state = FinancialState(clock: DateTime(2027, 3, 20));
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
      find.byType(MaterialApp),
      matchesGoldenFile('out/home_future_date.png'),
    );
  });
}
