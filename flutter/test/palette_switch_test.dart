// A widget that reads the palette in build() must never be const at its call
// site, and this is the test that catches it.
//
// The footgun, in full: Barako.text and friends are mutable static getters,
// resolved once per app build. A widget with a const constructor is
// CANONICALIZED by Dart, so two const calls with the same arguments are the
// same instance. When the root rebuilds after a theme change or a sunset
// flip to dark, Element.updateChild compares the new child to the old one,
// sees the identical instance, and returns the existing element WITHOUT
// calling build(). The widget keeps painting the previous palette's colours.
//
// It is worse than it sounds, because it is invisible in the common case. The
// card around the widget repaints correctly, so the screen looks fine except
// for one element in the wrong accent, and only after a theme switch.
//
// theme.dart and screen_header.dart both carry written warnings about this.
// Two widgets added the same day tripped over it anyway, in seven call sites.
// A warning in a comment did not hold. This does.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/history.dart';
import 'package:salapify/screens/insights.dart';
import 'package:salapify/screens/utang.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two palettes chosen to be as far apart as this app allows: the default
/// warm light one, and a cold dark one. If a colour does not move between
/// these two, it is not following the palette at all.
final _paletteA = themeForKey('barako').light;
final _paletteB = themeForKey('tidal').dark;

Future<void> _pumpWith(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    // Scaffold, because a destination is a body now and several of them
    // contain Material widgets that assert without one above them.
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

/// Build once per palette and return the colour the finder resolves to.
Future<(Color?, Color?)> _colourAcrossPalettes(
  WidgetTester tester,
  Widget Function() build,
  Color? Function(WidgetTester) read,
) async {
  Barako.currentTheme = themeForKey('barako');
  Barako.current = _paletteA;
  await _pumpWith(tester, build());
  final first = read(tester);

  // Exactly what the app does on a theme switch or a night-mode flip: change
  // the palette, then rebuild the same tree.
  Barako.currentTheme = themeForKey('tidal');
  Barako.current = _paletteB;
  await _pumpWith(tester, build());
  final second = read(tester);
  return (first, second);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Barako.currentTheme = themeForKey('barako');
    Barako.current = _paletteA;
  });

  testWidgets('the empty state follows a palette switch on History', (
    tester,
  ) async {
    final store = SalapifyStore();
    await store.load();
    final (a, b) = await _colourAcrossPalettes(
      tester,
      () => HistoryScreen(store: store),
      (t) => t
          .widget<Text>(find.text('Your money story starts with one entry'))
          .style
          ?.color,
    );
    expect(a, isNotNull);
    expect(
      b,
      isNot(a),
      reason:
          'The empty state kept the old palette after a theme switch. That is '
          'the const canonicalization trap: drop const from the call site, '
          'and from the widget constructor so it cannot come back.',
    );
  });

  testWidgets('the empty state follows a palette switch on Utang', (
    tester,
  ) async {
    final store = SalapifyStore();
    await store.load();
    final (a, b) = await _colourAcrossPalettes(
      tester,
      () => UtangScreen(store: store),
      (t) =>
          t.widget<Text>(find.text('Nobody owes you right now')).style?.color,
    );
    expect(a, isNotNull);
    expect(b, isNot(a), reason: 'Utang empty state froze its palette');
  });

  testWidgets('a Salapify icon follows a palette switch', (tester) async {
    final store = SalapifyStore();
    await store.load();
    final (a, b) = await _colourAcrossPalettes(
      tester,
      () => InsightsScreen(store: store, onSwitchTab: (_) {}),
      (t) => t.widget<Icon>(find.byIcon(Icons.bar_chart_outlined)).color,
    );
    expect(a, isNotNull);
    expect(
      b,
      isNot(a),
      reason:
          'The icon stayed in the old accent while the card around it '
          'repainted. An icon in the wrong colour is worse than the emoji it '
          'replaced, which undercuts the whole reason for the widget.',
    );
  });
}
