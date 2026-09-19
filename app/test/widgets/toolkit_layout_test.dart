import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/toolkit/toolkit_sheet.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// A pill must be the width of its LABEL, not the width of the screen.
///
/// This repository has shipped the same defect three times: a Container given
/// an `alignment` and no width expands to every pixel it is offered, so a row
/// of choices becomes a stack of full width bars. It was caught twice by
/// looking at a render and once here. Reading the code does not catch it,
/// because the code looks exactly like code that works.
void main() {
  Future<void> pumpToolkit(WidgetTester tester, {double width = 390}) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = Size(width * 3, 2900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 19),
    );
    final Palette p = Palette.of(state.theme);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(p, state.theme),
        home: Scaffold(
          backgroundColor: p.background,
          body: ToolkitSheet(state: state),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mindset'));
    await tester.pumpAndSettle();
  }

  testWidgets('a choice pill hugs its label instead of filling the row', (
    WidgetTester tester,
  ) async {
    await pumpToolkit(tester);

    final double screen = tester.view.physicalSize.width / 3;
    for (final String label in <String>[
      'Need',
      'Want',
      'Daily',
      'Weekly',
      'Rarely',
      'Yes',
      'No',
    ]) {
      // The PILL, not the Text inside it. Measuring the Text is a hollow
      // assertion: a Text hugs its content even when the Container around it
      // has expanded to fill the row, so this passed with the defect
      // deliberately restored and only the side by side test caught it.
      final Size size = tester.getSize(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      expect(
        size.width,
        lessThan(screen * 0.5),
        reason:
            '"$label" is ${size.width.toStringAsFixed(0)}dp wide on a '
            '${screen.toStringAsFixed(0)}dp screen. A Container with an '
            'alignment and no width fills everything it is offered, which '
            'turns these pills into stacked bars.',
      );
    }
  });

  testWidgets('two pills of the same group sit side by side', (
    WidgetTester tester,
  ) async {
    // The property the width check is really about, stated directly: if Need
    // and Want share a row, nothing expanded. A width assertion alone could
    // be satisfied by two narrow pills that still stacked.
    await pumpToolkit(tester);

    final Offset need = tester.getCenter(find.text('Need'));
    final Offset want = tester.getCenter(find.text('Want'));
    expect(
      need.dy,
      closeTo(want.dy, 1),
      reason: 'Need and Want are on different rows, so a pill expanded',
    );
    expect(want.dx, greaterThan(need.dx));
  });

  testWidgets('every pill still clears the 44dp touch floor', (
    WidgetTester tester,
  ) async {
    await pumpToolkit(tester);

    for (final String label in <String>['Need', 'Daily', 'Yes']) {
      final Size box = tester.getSize(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      expect(
        box.height,
        greaterThanOrEqualTo(44),
        reason: '"$label" is only ${box.height}dp tall',
      );
    }
  });

  testWidgets('the choices still fit at 320dp', (WidgetTester tester) async {
    // The narrowest phone Salapify supports. Three labels in a row is where
    // this overflows if it is going to.
    await pumpToolkit(tester, width: 320);
    expect(tester.takeException(), isNull);
  });
}
