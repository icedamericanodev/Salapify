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

/// The lived-in ledger with one account declared not the user's.
///
/// Staged rather than tapped, and deliberately so: the tapped route is
/// rendered two shots earlier for the OTHER flag, and what this picture is for
/// is the hero sentence, not the switch that produced it.
Map<String, dynamic> _withNotMine(Map<String, dynamic> data, String id) {
  for (final a in (data['accounts'] as List)) {
    if (a is Map && a['id'] == id) a['includeInNetWorth'] = false;
  }
  return data;
}

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

      // And a word no vocabulary will ever hold, which is the case the sheet
      // has to handle WELL rather than rarely. No word list covers how
      // everybody writes, so "the app does not know this one" is a permanent
      // state of the feature and not an edge of it.
      await tester.enterText(find.byType(TextField), 'zorbtronic 450');
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-log-unknown');

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

    testWidgets('entry detail ${s.key}', (tester) async {
      await tester.runAsync(loadRealFonts);
      tester.view.physicalSize = const Size(412 * 2, 915 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      // Reached by TAPPING a Ledger row, not by pushing the route. A pushed
      // route renders the same picture whether or not the row is wired to it,
      // so the shot would look right with the tap broken, and an unwired row
      // is exactly the defect this screen exists to fix.
      await tester.pumpWidget(_app(s, await memoryStore(livedIn())));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(NavBar), matching: find.text('Ledger')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jollibee').first);
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-entry-detail');
    });

    // The two sheets that WRITE the things the app could previously only read.
    // Neither existed until now: an account could arrive only through a
    // restored backup, and a monthly limit could not be set at all. Both are
    // rendered by opening them the way a person does, because a sheet pushed
    // straight onto the navigator looks identical whether or not the button
    // that is supposed to open it works.
    testWidgets('editors ${s.key}', (tester) async {
      await tester.runAsync(loadRealFonts);
      tester.view.physicalSize = const Size(412 * 2, 915 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(s, await memoryStore(livedIn())));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavBar),
          matching: find.text('Accounts'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add an account'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-account-editor');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(NavBar), matching: find.text('Plan')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-budget-editor');

      // The help behind the "i". It exists because the founder said the form
      // was too wordy, so the thing worth looking at is whether the FORM got
      // quieter, which means rendering both halves and not just this one.
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-budget-help');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // And the state the founder actually hit: one cap larger than the whole
      // month. The app used to take it in silence. Rendering it is the only
      // way to judge whether the note reads as an explanation or as a scold,
      // which is a thing no test can check.
      await tester.enterText(find.byType(TextField).first, '20000');
      await tester.enterText(find.byType(TextField).at(1), '50000');
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-budget-over');

      // Upcoming, reached by tapping its segment. The fixture puts a sweldo on
      // the 15th and leaves the 30th a bare payday, so one render carries both
      // shapes: a payday the app can price, and one it cannot.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-upcoming');

      // The projection's own help, which is where the founder's "i" question
      // landed after both expert passes said not to put one on the hero. It
      // carries the three rules a hero sentence cannot: where the window ends,
      // what the low point is a minimum of, and why a debt already paid can
      // still be counted. Rendered because a sheet of teaching copy is exactly
      // the surface that goes wordy again when nobody looks at it.
      final help = find.text('How this projection works');
      await tester.scrollUntilVisible(help, 200);
      await tester.pumpAndSettle();
      await tester.tap(help);
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-upcoming-help');
    });

    testWidgets('move money ${s.key}', (tester) async {
      await tester.runAsync(loadRealFonts);
      tester.view.physicalSize = const Size(412 * 2, 915 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(s, await memoryStore(livedIn())));
      await tester.pumpAndSettle();

      // Reached from Home's Move action, the way the founder reaches it, and
      // the way they reached the greyed out version that did nothing. The
      // sheet, then the refusal it gives on an overdraft, because a refusal is
      // a sentence a person reads at the worst moment and it has to be looked
      // at rather than trusted.
      await tester.tap(find.text('Move'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2500');
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-move');

      await tester.enterText(find.byType(TextField), '999999');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PillButton, 'Move it'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-move-refused');
    });

    testWidgets('debt ${s.key}', (tester) async {
      await tester.runAsync(loadRealFonts);
      tester.view.physicalSize = const Size(412 * 2, 915 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(s, await memoryStore(livedIn())));
      await tester.pumpAndSettle();

      // Reached the way the founder reaches it: the Debt action on Home, which
      // pointed at nothing until step 7. Tapping rather than pushing the route
      // means this render also proves the button is wired.
      await tester.tap(find.text('Debt'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-debt');

      // The other direction. A segment that is never rendered is a segment
      // nobody has looked at, and the two sides use different tones.
      await tester.tap(find.text('Owed to me'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-debt-owed');

      // One debt in full, with its payment history and the two buttons.
      await tester.tap(find.text('Marco'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-debt-detail');
    });

    testWidgets('debt payment sheet ${s.key}', (tester) async {
      await tester.runAsync(loadRealFonts);
      tester.view.physicalSize = const Size(412 * 2, 915 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(s, await memoryStore(livedIn())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Debt'));
      await tester.pumpAndSettle();

      // A LOAN, because that is the sheet with the account picker in it, and
      // the picker is the control that stops a payment being recorded with no
      // money leaving anywhere. Rendering the receivable sheet instead would
      // photograph the one case that does not have it.
      await tester.tap(find.text('Lola'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record a payment'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-debt-payment');

      // AND THE ACCOUNT AFTERWARDS. The founder paid a loan, opened the
      // account it came out of, and found nothing: the balance had moved and
      // its history did not say why. Nothing had ever rendered that screen
      // after a payment, so nobody had looked at the one place the defect
      // lived. This walks the whole path and photographs the end of it.
      await tester.enterText(find.byType(TextField), '1500');
      await tester.pumpAndSettle();
      await tester.tap(find.text('BPI').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      var guard = 0;
      while (find.byIcon(Icons.arrow_back_rounded).evaluate().isNotEmpty) {
        await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
        await tester.pumpAndSettle();
        if (++guard > 4) break;
      }
      await tester.tap(
        find.descendant(
          of: find.byType(NavBar),
          matching: find.byIcon(Icons.account_balance_wallet_outlined),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('BPI').first);
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-account-after-debt-payment');
    });

    // Hiding an account, walked rather than staged.
    //
    // Every screen here is reached by tapping, for the reason the debt pass
    // above gives: a staged ledger with the flag pre-set renders the same
    // picture whether or not the switch that is supposed to write it works,
    // and the whole feature is the switch.
    testWidgets('hidden accounts ${s.key}', (tester) async {
      await tester.runAsync(loadRealFonts);
      tester.view.physicalSize = const Size(412 * 2, 915 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(s, await memoryStore(livedIn())));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavBar),
          matching: find.byIcon(Icons.account_balance_wallet_outlined),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('GCash'));
      await tester.pumpAndSettle();

      // The sheet, with both switches off. This is the picture that has to
      // answer whether two toggles and a warning read as a considered choice
      // or as a settings screen leaking onto an account.
      await tester.tap(find.text('Options'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-account-options');

      // Hidden, ON, so the sheet can be judged in the state it will actually
      // be read in: somebody opening it to undo what they did last week.
      await tester.tap(find.byKey(const ValueKey('Hide from my lists')));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-account-options-hidden');

      Navigator.of(
        tester.element(find.text('Hide from my lists')),
        rootNavigator: true,
      ).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pumpAndSettle();

      // The bottom of Accounts, where the hidden row now lives. The thing to
      // look at is whether the section reads as a place an account went, or as
      // a second list somebody has to maintain.
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-accounts-hidden-section');

      // And the HERO, on a ledger where money has been declared not the
      // user's. This is the only screen in the app where the big number is
      // smaller than the rows under it add up to, so the sentence that
      // explains the gap is the whole point of the picture.
      await tester.pumpWidget(
        _app(s, await memoryStore(_withNotMine(livedIn(), 'a_gcash'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavBar),
          matching: find.byIcon(Icons.account_balance_wallet_outlined),
        ),
      );
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-accounts-not-mine');

      // AND HOME, which is the screen that silently lost the money. Safe to
      // spend falls by the hidden account's whole balance, and until this line
      // existed the only sentence on the screen blamed the bills. The picture
      // is here so the sentence gets read, not assumed.
      await tester.tap(
        find.descendant(of: find.byType(NavBar), matching: find.text('Home')),
      );
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-home-not-mine');
    });

    // Goals, roadmap step 8, and the two sheets that write them.
    testWidgets('goals ${s.key}', (tester) async {
      await tester.runAsync(loadRealFonts);
      tester.view.physicalSize = const Size(412 * 2, 915 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(s, await memoryStore(livedIn())));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(NavBar), matching: find.text('Plan')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Goals'));
      await tester.pumpAndSettle();

      // Three goals in three different STATES: one mid-flight, one nearly
      // there, one reached. A shot of three healthy goals photographs one row
      // three times and says nothing about the state the screen has to get
      // right, which is the finished one.
      await _shoot(tester, '${s.key}-goals');

      await tester.tap(find.text('Emergency fund'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-goal-actions');

      // The funding sheet, where the sentence about NOT moving money lives.
      // That sentence is the most important copy on the feature: everybody
      // who has used an envelope app expects this to debit an account.
      await tester.tap(find.widgetWithText(PillButton, 'Add money'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-goal-funding');
    });

    // What repeats, and the sheet that records it. Until this existed there
    // was no way to tell Salapify about the rent, so safe to spend counted it
    // as money the user could spend.
    testWidgets('recurring ${s.key}', (tester) async {
      await tester.runAsync(loadRealFonts);
      tester.view.physicalSize = const Size(412 * 2, 915 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(s, await memoryStore(livedIn())));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(NavBar), matching: find.text('Plan')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();

      // The section lives at the BOTTOM of Upcoming, under the day rows, so
      // the shot has to scroll to it. A picture of the first viewport would
      // photograph the part that already worked.
      await tester.scrollUntilVisible(
        find.text('What repeats'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-recurring');

      await tester.tap(find.widgetWithText(PillButton, 'Add another'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-recurring-editor');
    });

    // Insights, roadmap step 9. Reached by TAPPING Home's closing sentence,
    // which 04-screens.md makes the way in ("One insight sentence with a
    // number, no card. Tap for Insights."). Tapping rather than pushing the
    // route, for the reason the debt pass gives: a pushed route renders the
    // same picture whether or not the thing that opens it works, and this
    // sentence was a bare Text for as long as there was no screen to reach.
    testWidgets('insights ${s.key}', (tester) async {
      await tester.runAsync(loadRealFonts);
      tester.view.physicalSize = const Size(412 * 2, 915 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(s, await memoryStore(livedIn())));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('See your insights'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('See your insights'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-insights');

      // AND THE SEGMENT, which is D23 and the discoverable route. The pushed
      // screen above is for deep links; this is the one a person finds by
      // tapping a tab. Reached by tapping the segment, because a screenshot of
      // a state set in code proves nothing about the control that sets it.
      await tester.tap(
        find.descendant(
          of: find.byType(BackBar),
          matching: find.byIcon(Icons.arrow_back_rounded),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavBar),
          matching: find.byIcon(Icons.article_outlined),
        ),
      );
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-ledger-entries');
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-ledger-insights');

      // AND THE BOTTOM OF IT, because the net worth chart is the one with a
      // custom painter in it and the one most likely to draw nothing at all.
      // A shot of the first viewport would photograph two charts and miss the
      // only one that can fail silently.
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-insights-bottom');
    });

    testWidgets('settings ${s.key}', (tester) async {
      await tester.runAsync(loadRealFonts);
      tester.view.physicalSize = const Size(412 * 2, 915 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(s, await memoryStore(livedIn())));
      await tester.pumpAndSettle();

      // Reached the way a person reaches it, from the bottom of Accounts, so
      // this render also proves the way IN exists. The founder could not find
      // Save or Restore, and a screenshot of the screen alone would not have
      // told me whether the screen was wrong or the door was.
      await tester.tap(
        find.descendant(
          of: find.byType(NavBar),
          matching: find.byIcon(Icons.account_balance_wallet_outlined),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Backup and settings'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Backup and settings'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-settings');

      // Categories, reached from the row Settings now carries, so this render
      // proves the door as well as the room. The list, then the editor, then
      // the hide confirmation, because the confirmation is the only screen in
      // this feature that describes a consequence and it is therefore the one
      // whose wording has to be looked at rather than trusted.
      await tester.scrollUntilVisible(
        find.text('Categories'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-categories');

      // Bills already groups Electricity and Water in the fixture, so its
      // editor is the one shot that proves the two-level rule reads as
      // English rather than only being silently enforced: a category that
      // groups others cannot also become someone else's child.
      await tester.tap(find.text('Bills'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-category-editor-parent');

      // And the one tap route OFF that sheet: a new category that arrives
      // already under Bills, which is the shortcut the founder asked for
      // after the picker shipped ("what if i want to make a parent/main
      // category then its subcategory?").
      await tester.ensureVisible(find.text('Add a sub-category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a sub-category'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-category-new-sub');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // A category with money through it AND a cap set, which is the state the
      // confirmation has the most to say about. Groceries carries a 2,500 cap
      // in the fixture and real spending this month.
      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-category-editor');

      await tester.tap(find.text('Hide it'));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-category-hide');
    });

    testWidgets('first run ${s.key}', (tester) async {
      await tester.runAsync(loadRealFonts);
      tester.view.physicalSize = const Size(412 * 2, 915 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      // An EMPTY store, which is the one thing the lived-in fixture above can
      // never show, and the first thing every new user sees. It went unrendered
      // until the founder ran the app on an emulator and hit it, at which point
      // it was telling people to set their payday on a screen that could not
      // set a payday. Every test passed and every screenshot looked right,
      // because all of them ran against data that already had one.
      await tester.pumpWidget(_app(s, await memoryStore()));
      await tester.pumpAndSettle();
      await _shoot(tester, '${s.key}-first-run');
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
            // `onAction` is now required alongside `action`, and this sheet is
            // where that rule was first broken: it demoed an accent "Edit"
            // wired to nothing, which is exactly the dead control the assertion
            // exists to stop. A component SHEET showing a dead control teaches
            // every screen that copies from it to ship one.
            ScreenTitle(
              title: 'Component sheet',
              action: 'Edit',
              onAction: () {},
              sub: 'Every piece the app is built from, in both skins.',
            ),
            const SizedBox(height: 22),

            Head(title: 'Rows', action: 'See all', onAction: () {}),
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
