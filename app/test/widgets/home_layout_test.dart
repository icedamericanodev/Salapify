import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/format.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/screens/home/debt_beam_card.dart';
import 'package:salapify/shell/app_shell.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

import '../support/pinned_app.dart';

/// Layout guards for Home.
///
/// These exist because two separate widgets rendered at ZERO height while the
/// screen around them looked finished, and no assertion about text could see
/// it. Both had the same cause: a box with no intrinsic size handed loose
/// constraints by its parent.
void main() {
  Future<void> pumpHome(WidgetTester tester) async {
    await pumpSalapify(tester);
    await tester.pumpAndSettle();
  }

  testWidgets('the debt beam is actually drawn, not collapsed to nothing', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    await tester.scrollUntilVisible(find.byKey(debtBeamKey), 200);
    await tester.pumpAndSettle();

    final Size beam = tester.getSize(find.byKey(debtBeamKey));
    expect(
      beam.height,
      greaterThanOrEqualTo(4),
      reason: 'the debt beam collapsed, so the card shows no bar at all',
    );
    expect(beam.width, greaterThan(100));

    // Both halves must have real width, or the split is a lie: one side
    // filling the whole bar looks exactly like a correct bar for the other.
    final Finder halves = find.descendant(
      of: find.byKey(debtBeamKey),
      matching: find.byType(ColoredBox),
    );
    expect(halves, findsNWidgets(2), reason: 'the beam should have two halves');

    for (int i = 0; i < 2; i++) {
      final Size half = tester.getSize(halves.at(i));
      expect(half.height, greaterThanOrEqualTo(4));
      expect(half.width, greaterThan(0));
    }
  });

  testWidgets('the tab bar leaves the body real height', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    final Size listView = tester.getSize(find.byType(ListView).first);
    expect(
      listView.height,
      greaterThan(200),
      reason: 'the bottom bar swallowed the screen again',
    );
  });

  testWidgets('nothing on Home overflows its width at 320dp', (
    WidgetTester tester,
  ) async {
    // 320 logical pixels is the narrowest phone worth supporting.
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHome(tester);

    // A RenderFlex overflow reports through the exception channel, so a clean
    // pump is the assertion.
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Reminders card never truncates its own name', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    final Finder title = find.text('Reminders');
    await tester.scrollUntilVisible(title, 200);
    await tester.pumpAndSettle();

    // Present in full. When it was a Row, the title lost the fight with the
    // tag beside it and the card read "Reminders & ..." instead.
    expect(title, findsOneWidget);
    final Text widget = tester.widget<Text>(title);
    expect(widget.overflow, isNot(TextOverflow.ellipsis));
  });

  testWidgets('the headline money figure is never cut off, however narrow '
      'and however large the font', (WidgetTester tester) async {
    // FOUND BY LOOKING, not by any guard, and the guards could not have found
    // it: screen_readability_test runs 1.5x at 390dp wide, and this file runs
    // 320dp at the ordinary font size. The two conditions were never combined,
    // so the one phone where they meet was unmeasured.
    //
    // At 320dp and 1.5x the hero rendered Safe to Spend as "P24,33...". For a
    // money figure a truncation is worse than small text, because it is
    // AMBIGUOUS: that could be 24,330 or 24,339.99, and the one number the
    // whole screen exists to state becomes a number nobody can state. The
    // figure is shrunk to fit now and never ellipsised.
    //
    // The nav bar also truncates at this width. That one is known and is
    // measured in nav_bar_scaling_test.dart, so it is deliberately not
    // asserted here.
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(960, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 18),
    );
    final Palette p = Palette.of(state.theme);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: MaterialApp(
          theme: salapifyTheme(p, state.theme),
          home: AppShell(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final String expected = formatPeso(state.safeToSpend.pesos);
    final Finder figure = find.text(expected);
    expect(figure, findsOneWidget);

    // ASKED OF THE RENDER, not of the finder, and the first version of this
    // test got that wrong and therefore proved nothing. `find.text` matches
    // the widget's `data`, which keeps the FULL string whether or not the
    // layout painted it truncated, so the test passed with the ellipsis put
    // straight back. Only `didExceedMaxLines` knows. This is the same
    // detection screen_readability_test uses, for the same reason.
    final RenderParagraph para = tester.renderObject<RenderParagraph>(figure);
    expect(
      para.didExceedMaxLines,
      isFalse,
      reason:
          'the headline figure must be on screen WHOLE. An ellipsised peso '
          'amount cannot be recovered by squinting: "P24,33..." could be '
          '24,330 or 24,339.99',
    );

    // DIRECTIONAL companion: "the text exists" also holds on a build that
    // draws it at an unreadable size, so the figure must still be rendered
    // large. Half of its designed 36pt is the floor.
    final Size drawn = tester.getSize(find.text(expected));
    expect(
      drawn.height,
      greaterThan(18),
      reason: 'shrink to fit became shrink to nothing',
    );
  });

  testWidgets('and it no longer calls itself a simulator', (
    WidgetTester tester,
  ) async {
    // The tag was honest while nothing behind the card worked. Something does
    // now, so the tag would be the lie instead. This asserts the swap
    // happened rather than the label merely being restyled.
    await pumpHome(tester);

    expect(find.text('SIMULATOR'), findsNothing);
    expect(find.text('Test Alerts'), findsNothing);
  });
}
