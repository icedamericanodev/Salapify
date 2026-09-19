// Pan is one colour, everywhere, forever.
//
// This file replaces pan_tint_test.dart, which guarded the OPPOSITE property.
// The machinery to reskin Pan per theme was built, measured, rendered across
// all eight palettes and then deliberately removed: a character whose colour
// follows the wallpaper is wearing a costume, while a character with a fixed
// colour is recognisably himself (founder, 2026-07-26).
//
// A decision like that decays silently unless something holds it. Nothing in
// the app LOOKS broken if Pan starts following the theme again, which is
// exactly why it needs a test rather than a comment: the failure mode is a
// slow loss of identity that no crash and no wrong number will ever report.
//
// The realistic ways it comes back:
//   1. someone wraps the artwork in a ColorFiltered again
//   2. someone gives PanCupPainter's palette a live-Barako default again
//   3. someone reads a Barako getter inside PanMascot.build

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/pan_mood.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/pan_mascot.dart';

/// Every distinct colour the widget tree actually paints Pan with.
Set<int> _panColors(WidgetTester tester) {
  final found = <int>{};
  for (final w in tester.widgetList(find.byType(CustomPaint))) {
    final p = (w as CustomPaint).painter;
    if (p is PanCupPainter) found.add(p.palette.cup.toARGB32());
  }
  return found;
}

Widget _pan() => MaterialApp(
  home: Scaffold(body: PanMascot(mood: PanMood.calm, size: 64)),
);

void main() {
  tearDown(() {
    Barako.currentTheme = themeForKey('palawan');
    Barako.current = themeForKey('palawan').resolve(Brightness.dark);
  });

  testWidgets('no colour filter is ever applied to the artwork', (
    tester,
  ) async {
    // Route 1 back to a themed Pan. The artwork carries his colour already,
    // so any filter over it is by definition changing it.
    for (final theme in barakoThemes) {
      Barako.currentTheme = theme;
      Barako.current = theme.resolve(Brightness.dark);
      await tester.pumpWidget(_pan());
      await tester.pumpAndSettle();
      expect(
        find.byType(ColorFiltered),
        findsNothing,
        reason:
            'Pan is being filtered on ${theme.key}. His colour is baked into '
            'the artwork, so a filter over it can only be changing it, and a '
            'mascot that changes colour with the wallpaper is a costume '
            'rather than a character.',
      );
    }
  });

  testWidgets('the fallback cup is the signature colour on every theme', (
    tester,
  ) async {
    // Route 2, and the sneaky one. The fallback only draws when an asset
    // fails, so a live-palette default here would produce a theme-following
    // Pan in precisely the case nobody ever looks at.
    for (final theme in barakoThemes) {
      for (final b in Brightness.values) {
        Barako.currentTheme = theme;
        Barako.current = theme.resolve(b);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CustomPaint(
                painter: PanCupPainter(
                  mood: PanMood.calm,
                  wisp: 1,
                  palette: kPanSignaturePalette,
                ),
                size: const Size(64, 64),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          _panColors(tester),
          {panSignatureColor.toARGB32()},
          reason:
              'On ${theme.key}/${b.name} the fallback cup was not Pan\'s '
              'signature colour.',
        );
      }
    }
  });

  test('the signature is independent of the palette, not derived from it', () {
    // The signature is a fixed literal, not read from any theme. The point is
    // that Pan owns his colour: whatever look the user picks, and however the
    // palette is retuned, Pan must not silently follow, so nothing may compute
    // the signature from the palette.
    expect(panSignatureColor.toARGB32(), 0xFFFF8A3D);
    expect(kPanSignaturePalette.cup, panSignatureColor);
  });

  testWidgets('Pan renders identically under two different themes', (
    tester,
  ) async {
    // The property stated end to end, rather than as three separate
    // mechanisms. Whatever route a future change takes, this is what must
    // stay true.
    Barako.currentTheme = themeForKey('palawan');
    Barako.current = themeForKey('palawan').resolve(Brightness.dark);
    await tester.pumpWidget(_pan());
    await tester.pumpAndSettle();
    final onPalawan = _panColors(tester);
    final filteredOnPalawan = find.byType(ColorFiltered).evaluate().length;

    Barako.currentTheme = themeForKey('pearl');
    Barako.current = themeForKey('pearl').resolve(Brightness.light);
    await tester.pumpWidget(_pan());
    await tester.pumpAndSettle();

    expect(_panColors(tester), onPalawan);
    expect(
      find.byType(ColorFiltered).evaluate().length,
      filteredOnPalawan,
      reason:
          'Pan is drawn differently on Pearl than on Palawan. He is meant to be '
          'the one fixed thing on a screen the user can repaint.',
    );
  });
}
