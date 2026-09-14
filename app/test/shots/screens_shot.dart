// Renders every screen in both skins to real PNGs, so a person can LOOK at
// them before they are called done.
//
// Run:  flutter test test/shots/screens_shot.dart --update-goldens
// Out:  test/shots/out/*.png   (gitignored; the reviewed ones are copied into
//                               docs/revamp/mockups/hapon/ and embedded in its
//                               README, which is the surface GitHub renders)
//
// NAMED WITHOUT the `_test` suffix, deliberately and for two reasons.
// `flutter test` only collects `*_test.dart`, so this can never join an
// ordinary run and fail there on a missing font, and it lives under test/
// rather than tool/ because the analyzer only permits test-only APIs here.
// CI runs it as its own step, with --update-goldens so the step can only fail
// if the harness genuinely stopped rendering.
//
// Three gotchas are handled below and each one cost a round of founder
// screenshots when it was not:
//
//   1. Fonts MUST load inside tester.runAsync. testWidgets uses a fake clock,
//      so a real file read never completes inside it and the run hangs with no
//      output at all.
//   2. The Material icon font ships with the SDK, not with the app. Without
//      loading it separately every Icon draws as an empty box, and a
//      screenshot of boxes proves nothing about a screen full of icons.
//   3. pumpWidget with the same instance is a NO-OP. The first version of a
//      helper like this produced four identical PNGs and every later drag
//      silently did nothing. Hence the UniqueKey.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/design/type.dart';

import '../support/memory_store.dart';

/// Loads the real shipped faces. Exported because any test that MEASURES
/// layout has to use it too: Flutter's default test font is wider than Plus
/// Jakarta Sans, so a wrap-or-not decision comes out one way in the test font
/// and the other way on the phone.
Future<void> loadRealFonts() async {
  final loader = FontLoader('Jakarta');
  for (final f in const [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  ]) {
    final bytes = File('assets/fonts/$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();

  final iconPath = _materialIconFont();
  if (iconPath == null) {
    throw StateError(
      'Material icon font not found. Looked under FLUTTER_ROOT and walked up '
      'from ${Platform.resolvedExecutable}.',
    );
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(ByteData.sublistView(File(iconPath).readAsBytesSync())),
    );
  await icons.load();
}

/// Where the Material icon font is, on this machine.
///
/// The first version of this hardcoded /opt/flutter, which is where the SDK
/// sits in a dev sandbox and nowhere near where the CI runner installs it. The
/// shipped app's harness already solved this properly and this is its
/// solution: ask the tool, then fall back to walking up from the running Dart
/// binary, because the exact shape of the SDK layout is not something to
/// hardcode.
String? _materialIconFont() {
  final roots = <String>{
    ?Platform.environment['FLUTTER_ROOT'],
    _walkUpToFlutterRoot(Platform.resolvedExecutable) ?? '',
  }..remove('');
  for (final root in roots) {
    final f = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (f.existsSync()) return f.path;
  }
  return null;
}

/// `.../<root>/bin/cache/dart-sdk/bin/dart`, walked back up to the root.
String? _walkUpToFlutterRoot(String exe) {
  var dir = File(exe).parent;
  for (var i = 0; i < 8; i++) {
    if (Directory('${dir.path}/bin/cache/artifacts').existsSync()) {
      return dir.path;
    }
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  return null;
}

/// The real app, both themes wired exactly as main.dart wires them, forced to
/// one skin. Rendering the actual router rather than a stand-in is the whole
/// point: a picture of a hand-built copy of the shell proves nothing about the
/// shell.
/// The render's "now", pinned.
///
/// Friday 11 September 2026, chosen rather than picked at random: the fixture's
/// payday schedule is the 15th and the 30th, so from here the next payday is
/// four days out and both recurring bills fall inside the cycle. Home then
/// renders with a rail part filled and a "Coming up" section that has
/// something in it, which is the state worth reviewing.
///
/// Pinned at all because Home is the first screen whose content depends on the
/// date. Read the system clock and the committed renders churn every midnight,
/// so a review picture is never the same twice and a real change hides in the
/// noise.
final _renderNow = DateTime(2026, 9, 11, 9, 30);

Widget _app(Skin s, LedgerStore store) => AppClock(
  now: _renderNow,
  child: LedgerScope(
    store: store,
    child: MaterialApp.router(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: salapifyTheme(hapon),
      darkTheme: salapifyTheme(gabi),
      themeMode: s.dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: buildRouter(),
    ),
  ),
);

Future<void> _shoot(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

void main() {
  // Light and dark render from identical layout code, so the pictures differ
  // only in colour. Anything else that differs across a pair is a bug.
  for (final s in allSkins) {
    testWidgets('screens ${s.key}', (tester) async {
      await tester.runAsync(loadRealFonts);

      tester.view.physicalSize = const Size(412 * 2, 915 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      // A LIVED-IN store, and that is the whole point of this line. The
      // shipped app's harness spent most of its life shooting an EMPTY one, so
      // sixteen images across two brightnesses were all first-run welcome
      // screens and not one of them ever contained a peso figure. A
      // crossed-out peso sign sat on Home through dozens of renders and
      // reached the founder's phone. Never shrink this fixture for a tidier
      // picture: a tidy shot of an empty screen is exactly what it replaced.
      await tester.pumpWidget(_app(s, await memoryStore(livedIn())));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-home');

      // Walk the bar the way a person does, rather than pushing routes, so
      // the shot proves navigation works as well as showing the screen.
      for (var i = 1; i < NavBar.tabs.length; i++) {
        await tester.tap(find.text(NavBar.tabs[i].$1));
        await tester.pumpAndSettle();
        await _shoot(tester, '${s.key}-${NavBar.tabs[i].$1.toLowerCase()}');
      }

      // Back to Home, then the Log sheet OVER it, scrim and all, because that
      // is how it is actually seen and the dimmed screen behind is part of the
      // design rather than a detail of the screenshot.
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      // Scoped to the NAV BAR, because Home now has a "Log" quick action too
      // and a bare find.text would match both. 04-screens.md asks for both on
      // purpose: the bar's button is always there, the quick action is one of
      // the four on the screen.
      await tester.tap(
        find.descendant(of: find.byType(NavBar), matching: find.text('Log')),
      );
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-log');

      // And the sheet MID-TYPE, which is the state the whole feature exists
      // for. An empty sheet cannot show whether the "Got it" line reads well,
      // and that line is the app's promise about what it is going to save.
      await tester.enterText(find.byType(TextField), 'jollibee 250');
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-log-typed');

      // And one screen that is NOT a tab: account detail, reached by tapping a
      // row rather than by pushing the route. Tapping is the point. A pushed
      // route renders the same picture whether or not the row is actually
      // wired to it, so the shot would look right with the tap broken.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accounts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BPI'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-account-detail');
    });

    testWidgets('component sheet ${s.key}', (tester) async {
      await tester.runAsync(loadRealFonts);

      // Taller than a phone on purpose: the whole vocabulary in one picture is
      // the thing worth reviewing, and four screenshots of a scroll is not.
      tester.view.physicalSize = const Size(412 * 2, 1400 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          debugShowCheckedModeBanner: false,
          theme: salapifyTheme(hapon),
          darkTheme: salapifyTheme(gabi),
          themeMode: s.dark ? ThemeMode.dark : ThemeMode.light,
          home: const _ComponentSheet(),
        ),
      );
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-components');
    });
  }
}

/// Every component in the kit, once, in the states it actually ships in.
///
/// Test-only on purpose: it is a review surface, not a screen, and putting it
/// in lib/ would mean shipping a page nobody can reach.
class _ComponentSheet extends StatelessWidget {
  const _ComponentSheet();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Scaffold(
      backgroundColor: skin.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(gutter, 10, gutter, 10),
          children: [
            const TopBar(date: 'Saturday, Sep 13'),
            const SizedBox(height: 16),
            const ScreenTitle(
              title: 'Component sheet',
              action: 'Edit',
              sub: 'Every piece the app is built from, in both skins.',
            ),
            const SizedBox(height: 22),

            const Head(title: 'Rows', action: 'See all'),
            const SizedBox(height: 10),
            // The three tones, an icon row, a two-line row, and a struck
            // through row: everything a list can be.
            const Group(
              children: [
                ItemRow(
                  icon: Icons.restaurant_outlined,
                  title: 'Jollibee',
                  sub: 'Food, GCash',
                  amount: '-₱250.00',
                ),
                ItemRow(
                  icon: Icons.payments_outlined,
                  title: 'Sweldo',
                  sub: 'Income, BPI',
                  amount: '+₱18,500.00',
                  amountSub: '15th',
                  tone: Tone.good,
                ),
                ItemRow(
                  icon: Icons.handshake_outlined,
                  title: 'Owed to Ate Rina',
                  sub: 'Due in 4 days',
                  amount: '₱3,000.00',
                  tone: Tone.owe,
                ),
                ItemRow(
                  icon: Icons.check_circle_outline,
                  title: 'Settled with Kuya Ben',
                  sub: 'Paid 11 Sep',
                  amount: '₱0.00',
                  strike: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // inset 0, for a group whose rows carry no icon disc: the rule
            // runs the full width instead of starting nowhere.
            const Group(
              inset: 0,
              children: [
                ItemRow(title: 'No icon here', amount: '₱120.00'),
                ItemRow(title: 'Nor here', amount: '₱80.00'),
              ],
            ),

            const SizedBox(height: 26),
            const Head(title: 'Surfaces and bars'),
            const SizedBox(height: 10),
            // Each bar carries the RIGHT-HAND FIGURE and the caption it has on
            // the real screen, and that is a correction rather than a detail.
            //
            // The first version stacked two bare bars 14dp apart with generic
            // labels, which is the only place in the whole product where those
            // two colours sit adjacent with the words stripped out. The
            // founder looked at it and reasonably asked whether over budget
            // was distinguishable. A review surface that hides the cues
            // carrying the meaning cannot tell anyone whether the meaning
            // arrives. See D16.
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Groceries',
                          style: TypeScale.rowTitle(skin.text),
                        ),
                      ),
                      Text(
                        '₱3,600.00 left',
                        style: TypeScale.rowAmount(skin.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const ThinBar(fraction: 0.4),
                  const SizedBox(height: 6),
                  Text(
                    '₱2,400.00 of ₱6,000.00 spent',
                    style: TypeScale.caption(skin.text3),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Food',
                          style: TypeScale.rowTitle(skin.text),
                        ),
                      ),
                      // The words flip, not just the colour. "over" is doing
                      // the work here; the colour only agrees with it.
                      Text(
                        '₱740.00 over',
                        style: TypeScale.rowAmount(skin.bad),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ThinBar(fraction: 1.0, fill: skin.bad),
                  const SizedBox(height: 6),
                  Text(
                    '₱5,740.00 of ₱5,000.00 spent',
                    style: TypeScale.caption(skin.text3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),
            const Head(title: 'Controls'),
            const SizedBox(height: 10),
            const Segmented(
              options: ['Expense', 'Income', 'Transfer'],
              index: 0,
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PickChip(label: 'Food', on: true),
                PickChip(label: 'Transport'),
                PickChip(label: 'Bills'),
                PickChip(label: 'Groceries'),
              ],
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(
                  child: Field(value: 'Today', leading: Icons.event_outlined),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Field(
                    value: 'Note',
                    hint: true,
                    leading: Icons.notes_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const PillButton(label: 'Save entry', icon: Icons.check_rounded),
            const SizedBox(height: 10),
            const PillButton(label: 'Cancel', secondary: true),

            const SizedBox(height: 26),
            const Head(title: 'Nothing here yet'),
            const SizedBox(height: 10),
            const EmptyState(
              icon: Icons.pie_chart_outline_rounded,
              title: 'Nothing logged yet',
              body:
                  'Tap Log to record your first expense. This is what a fresh '
                  'install actually sees.',
            ),
          ],
        ),
      ),
    );
  }
}
