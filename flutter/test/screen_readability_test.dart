// Does the screen still WORK as a piece of layout, on a real phone, when the
// person has turned their system font up?
//
// Open lesson 2 from the 2026-07-29 retrospective, closed with a machine.
//
// The render harness (screens_shot.dart) is opt-in by design. CI runs it with
// --update-goldens, which proves it does not crash and proves nothing about
// what it drew. The pictures still need a human to open them, and the whole
// point of that retrospective was that a defect survives when it lives where
// nobody looks. Twenty-odd images per run is exactly that place.
//
// So this file takes the same fixture and the same screens, throws the
// pictures away, and asserts the parts of "readable" a machine can actually
// judge:
//
//   1. Nothing overflows. A RenderFlex overflow is the yellow-and-black
//      barber pole on a phone, and it is never intended.
//   2. The screen drew real words. A blank tab is the loudest possible
//      failure and the easiest one to render without noticing.
//   3. No sentence runs off the side of the phone.
//
// And it does all three at 1.0x AND at 1.5x system font, because dynamic type
// is where layout actually breaks. That is not hypothetical here: the one
// screen ever rendered at a large font caught a real defect on its first run
// (a theme name truncated to "Orchid G..."), and it caught it because somebody
// thought to render that one screen. This asks every screen, every run.
//
// What this deliberately does NOT do is compare pixels. Golden comparison is
// why screens_shot.dart is kept out of `flutter test` in the first place: it
// is font- and platform-dependent and fails on a runner for reasons that say
// nothing about the app. Layout metrics from the same TTF are deterministic,
// so measuring the layout is safe where photographing it is not.
//
// One brightness, on purpose. A palette cannot change where a box lands, and
// colour is already measured exhaustively by palette_contrast_test.dart over
// all sixteen palettes. Rendering both here would double the runtime to
// re-prove something arithmetic already proves better.

import 'package:flutter/material.dart';
// RenderParagraph lives here, not in material.dart. The ellipsis check below
// is the only thing in this file that needs to reach past the widget layer.
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:salapify/screens/appearance.dart';
import 'package:salapify/screens/budget.dart';
import 'package:salapify/screens/categories.dart';
import 'package:salapify/screens/debts.dart';
import 'package:salapify/screens/reports.dart';
import 'package:salapify/screens/goals.dart';
import 'package:salapify/screens/recurring.dart';
import 'package:salapify/screens/search.dart';
import 'package:salapify/screens/cashflow.dart';
import 'package:salapify/screens/paluwagan.dart';
import 'package:salapify/screens/tools.dart';
import 'package:salapify/screens/treats.dart';
import 'package:salapify/screens/pan.dart';
import 'package:salapify/screens/payday.dart';
import 'package:salapify/screens/notes.dart';
import 'package:salapify/screens/mindset.dart';
import 'package:salapify/screens/privacy_receipt.dart';
import 'package:salapify/screens/history.dart';
import 'package:salapify/screens/insights.dart';
import 'package:salapify/screens/learn.dart';
import 'package:salapify/screens/menu.dart';
import 'package:salapify/screens/money.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert' show jsonEncode;
import 'dart:io';

import 'screens_shot.dart' show livedInBlob, loadRealFonts;

/// A mid-range Android phone in logical pixels: 1170x2532 at 3x, the same
/// frame the render harness shoots, so a failure here can be looked at there
/// without wondering whether the two agree.
const Size _phone = Size(390, 844);

/// The system font sizes checked. 1.0 is the baseline; 1.5 is inside what
/// Android's Display size and text size sliders reach, and it is where a Row
/// of two fixed-width children stops fitting.
const List<double> _scales = [1.0, 1.5];

/// Every text this frame actually drew, as plain strings.
List<String> _words(WidgetTester tester) {
  final out = <String>[];
  for (final e in find.byType(Text).evaluate()) {
    final w = e.widget as Text;
    final s = w.data ?? w.textSpan?.toPlainText() ?? '';
    if (s.trim().isNotEmpty) out.add(s.trim());
  }
  return out;
}

/// Is this text inside something the user can scroll SIDEWAYS?
///
/// A chip row that continues past the right edge is a design, not a defect,
/// and the off-the-side check below would otherwise flag every one of them.
/// This is the difference between a check that is right and a check that
/// merely fails a lot.
bool _insideHorizontalScroll(Element element) {
  var horizontal = false;
  element.visitAncestorElements((a) {
    final w = a.widget;
    if (w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.horizontal) {
      horizontal = true;
      return false;
    }
    return true;
  });
  return horizontal;
}

/// A stored machine date that reached the screen.
///
/// There is already a static scan for this (no_iso_dates_in_copy_test.dart)
/// and it is worth keeping, because it names the offending line at the moment
/// somebody writes it. But it can only ever guess: it matches a map subscript
/// of four hardcoded key names, so "Due ${person['oldestDue']}" walked straight
/// past a guard whose whole title is that dates must not appear raw in copy. A
/// test that reads as a rule and implements a list will keep doing that,
/// because the next offender is by definition the spelling nobody thought of.
///
/// This one cannot be fooled by a spelling. It reads what was actually drawn.
final _isoDate = RegExp(r'\b\d{4}-\d{2}-\d{2}\b');

List<String> _machineDates(WidgetTester tester) {
  final bad = <String>[];
  for (final e in find.byType(Text).evaluate()) {
    final w = e.widget as Text;
    final s = (w.data ?? w.textSpan?.toPlainText() ?? '').trim();
    final hit = _isoDate.firstMatch(s);
    if (hit == null) continue;
    bad.add('"$s" shows the stored date ${hit.group(0)}');
  }
  return bad;
}

/// Text the layout gave up on and cut off with an ellipsis.
///
/// Not the same thing as overflow, and invisible to every check above: an
/// ellipsized line fits perfectly, throws nothing, and stays inside the frame.
/// It also keeps its FULL string in the widget, so a test asserting on the
/// text passes while the phone shows "49% of ₱1...". Only the render knows.
///
/// This is a real defect class here rather than a style rule: the Accounts row
/// cut a savings target down to "₱1..." with the code comment directly above
/// it saying a third clause would not fit.
///
/// Truncating a long name a person typed is legitimate and always will be, so
/// this leans on the fixture: every name in the lived-in store is an ordinary
/// length, and on ordinary data nothing should need cutting. If a future
/// fixture adds a deliberately enormous name, this is the check that has to
/// learn about it, and that is the right trade: it fails loudly rather than
/// letting real truncation hide among expected truncation.
List<String> _cutOff(WidgetTester tester) {
  final bad = <String>[];
  for (final e in find.byType(Text).evaluate()) {
    final ro = e.renderObject;
    if (ro is! RenderParagraph || !ro.attached) continue;
    if (!ro.didExceedMaxLines) continue;
    final w = e.widget as Text;
    final s = (w.data ?? w.textSpan?.toPlainText() ?? '').trim();
    if (s.isEmpty) continue;
    bad.add('"$s" is cut off');
  }
  return bad;
}

/// Text painted past the left or right edge of the phone.
///
/// Vertical is not checked and must not be: a list longer than the screen is
/// the normal state of every tab in this app. Horizontal is different. There
/// is nowhere for it to go, so a word past the edge is a word the person
/// cannot read.
List<String> _runsOffTheSide(WidgetTester tester) {
  final bad = <String>[];
  for (final e in find.byType(Text).evaluate()) {
    final ro = e.renderObject;
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
    if (ro.size.isEmpty) continue;
    if (_insideHorizontalScroll(e)) continue;
    final Offset topLeft;
    try {
      topLeft = ro.localToGlobal(Offset.zero);
    } catch (_) {
      // Not currently painted (offstage, or inside a layer that has no
      // transform yet). Nothing to measure, and guessing would be worse.
      continue;
    }
    final right = topLeft.dx + ro.size.width;
    // Half a pixel of slack, so sub-pixel rounding in the text layout is not
    // reported as a defect.
    if (topLeft.dx < -0.5 || right > _phone.width + 0.5) {
      final w = e.widget as Text;
      final s = (w.data ?? w.textSpan?.toPlainText() ?? '').trim();
      bad.add(
        '"${s.length > 40 ? '${s.substring(0, 40)}...' : s}" spans '
        '${topLeft.dx.toStringAsFixed(1)} to ${right.toStringAsFixed(1)} '
        'on a ${_phone.width.toStringAsFixed(0)} wide phone',
      );
    }
  }
  return bad;
}

/// Pump one screen at one text scale and return everything wrong with it.
Future<List<String>> _inspect(
  WidgetTester tester,
  String name,
  Widget Function(SalapifyStore) build,
  double scale, {
  Map<String, dynamic>? blob,

  /// Text to tap once the screen has settled, for a state that is a tab away.
  ///
  /// A screen has more than one face and this file was only ever looking at the
  /// first one. The Owed to me half of Utang carried a raw stored date in its
  /// copy and no check here could see it, because nothing had ever pressed the
  /// button that shows it.
  String? thenTap,
}) async {
  await loadRealFonts(tester);
  SharedPreferences.setMockInitialValues({
    storageKey: jsonEncode(blob ?? livedInBlob),
  });
  final store = SalapifyStore();
  await store.load();

  tester.view.physicalSize = _phone * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  // Palette before build, the order main.dart uses.
  Barako.current = Barako.currentTheme.resolve(Brightness.dark);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: Scaffold(body: build(store)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (thenTap != null) {
    await tester.tap(find.text(thenTap));
    await tester.pumpAndSettle();
  }

  final problems = <String>[];

  void inspectFrame(String where, {bool checkBlank = false}) {
    // takeException, not expect: this collects EVERY problem on the screen so
    // one run names them all. A bare expect would stop at the first and turn a
    // three-line fix into three rounds.
    final thrown = tester.takeException();
    if (thrown != null) {
      // The overflow message is enormous and the useful part is its first line.
      problems.add(
        '$where threw during layout: ${thrown.toString().split('\n').first}',
      );
    }
    if (checkBlank) {
      final words = _words(tester);
      if (words.length < 4) {
        problems.add(
          '$where drew ${words.length} pieces of text, which is a blank '
          'screen: $words',
        );
      }
    }
    for (final off in _runsOffTheSide(tester)) {
      problems.add('$where has text off the side: $off');
    }
    for (final iso in _machineDates(tester)) {
      problems.add('$where shows a machine date: $iso');
    }
    // Cut-off text is judged at DEFAULT font size only, and the line is
    // principled rather than convenient. An ellipsis at 1.5x is the layout
    // degrading gracefully, which is exactly what an ellipsis is for; the
    // first run of this check at 1.5x flagged a search hint and two account
    // names, and demanding zero ellipsis there would push every fixed-width
    // piece of chrome in the app into wrapping. An ellipsis at 1.0x is
    // different in kind: it is the layout failing to fit its own ordinary
    // content, on ordinary data, for everybody.
    if (scale == 1.0) {
      for (final cut in _cutOff(tester)) {
        problems.add('$where has text cut off: $cut');
      }
    }
  }

  inspectFrame('$name at ${scale}x', checkBlank: true);

  // Then the rest of the screen.
  //
  // This half is not a refinement, it is most of the value. A ListView only
  // lays out what is near the viewport, so without scrolling this whole file
  // would be checking the top of ten screens and calling it ten screens. The
  // founder's own report of the crossed-out peso came from a card well below
  // the fold, and Menu is sixteen destinations long.
  //
  // Blank is checked only on the first frame: the bottom of a list legitimately
  // has little on it, and flagging that would be a wrong check.
  final scroller = _mainScroller(tester);
  if (scroller != null) {
    final page = _phone.height * 0.8;
    var at = 0.0;
    // Capped so a screen that somehow grows without bound cannot hang the
    // suite. Sixteen pages of a 844 tall phone is far taller than anything
    // here, and if a screen ever exceeds it the cap is the right thing to
    // notice rather than to raise.
    for (var i = 0; i < 16 && at < scroller.position.maxScrollExtent; i++) {
      at = (at + page).clamp(0.0, scroller.position.maxScrollExtent);
      scroller.position.jumpTo(at);
      await tester.pumpAndSettle();
      inspectFrame('$name at ${scale}x, scrolled to ${at.round()}');
    }
  }
  return problems;
}

/// The screen's own vertical scroll view.
///
/// First vertical one with somewhere to go. Screens here have exactly one; a
/// screen that grew a second would still get its main one checked, which is
/// better than skipping the sweep because the choice was ambiguous.
ScrollableState? _mainScroller(WidgetTester tester) {
  for (final s in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
    if (!s.position.hasContentDimensions) continue;
    if (s.position.axis != Axis.vertical) continue;
    if (s.position.maxScrollExtent <= 0) continue;
    return s;
  }
  return null;
}

void main() {
  // The same destinations the render harness shoots, built the same way the
  // shell builds them (onMenu wired, because a tab without its header chrome
  // is not the tab).
  final screens = <String, Widget Function(SalapifyStore)>{
    'Home': (s) => OverviewScreen(store: s, onSwitchTab: (_) {}, onMenu: () {}),
    'Budget': (s) => BudgetScreen(store: s, onMenu: () {}),
    'Activity': (s) => HistoryScreen(store: s, onMenu: () {}),
    'Utang': (s) => MoneyScreen(store: s, onMenu: () {}),
    'Insights': (s) =>
        InsightsScreen(store: s, onSwitchTab: (_) {}, onMenu: () {}),
    'Menu': (s) => MenuScreen(store: s, onSwitchTab: (_) {}),
    'Courses': (s) => LearnScreen(store: s),
    'Appearance': (s) => AppearanceScreen(store: s),
    'Accounts': (s) => AccountsScreen(store: s),
    'Categories': (s) => CategoriesScreen(store: s),
    // Reports and Debts were missing for this file's whole life, and both
    // carry f2.88's rounding fix, so two of the four screens that change
    // touched had never been drawn OR measured. They are here because the
    // retrospective counted lib/screens against this map instead of trusting
    // it, which is the difference between a rule and a list.
    'Reports': (s) => ReportsScreen(store: s),
    'Debts': (s) => DebtsScreen(store: s),
    // Everything else a person can actually open, added when the coverage
    // assertion below stopped this map being a promise and started making it
    // account for the fifty files in lib/screens one by one.
    'Goals': (s) => GoalsScreen(store: s),
    'Recurring': (s) => RecurringScreen(store: s),
    'Search': (s) => SearchScreen(store: s),
    'Cash flow': (s) => CashFlowScreen(store: s),
    'Paluwagan': (s) => PaluwaganScreen(store: s),
    'Tools': (s) => ToolsScreen(store: s),
    'Treats': (s) => TreatsScreen(store: s),
    'Ask Pan': (s) => PanScreen(store: s),
    'Payday': (s) => PaydayScreen(store: s),
    'Notes': (s) => NotesScreen(store: s),
    'Mindset': (s) => MindsetScreen(store: s),
    // No store: this screen reads the live privacy log rather than the store,
    // which is the one thing it exists to prove about itself.
    'Privacy receipt': (s) => PrivacyReceiptScreen(),
  };

  // A second face of a screen, reached the way a person reaches it. Keyed by
  // the label to press once the screen has settled.
  const secondFace = <String, String>{'Utang': 'Owed to me'};

  for (final entry in screens.entries) {
    for (final scale in _scales) {
      testWidgets('${entry.key} lays out at ${scale}x system font', (
        tester,
      ) async {
        final problems = await _inspect(tester, entry.key, entry.value, scale);
        if (secondFace[entry.key] case final tap?) {
          problems.addAll(
            await _inspect(
              tester,
              '${entry.key} (${tap.toLowerCase()})',
              entry.value,
              scale,
              thenTap: tap,
            ),
          );
        }
        expect(
          problems,
          isEmpty,
          reason:
              'this screen is broken on a phone, and no screenshot would say '
              'so unless somebody opened it:\n${problems.join('\n')}',
        );
      });
    }
  }

  // The set above is DERIVED against lib/screens, not trusted.
  //
  // This is the one line that turns this file from a promise into a rule, and
  // the model is test/palette_contrast_test.dart, which iterates the theme
  // registry and then asserts it saw all of it, so a ninth theme reddens the
  // build. That trick was written in this repo the same week and not reused
  // here, and the cost was exact: the set said ten screens while lib/screens
  // held fifty, CLAUDE.md claimed it covered "every screen", and Goals sat
  // outside it printing "by 2026-12-31" through three separate rounds of fixing
  // that precise defect elsewhere.
  //
  // Everything not swept must be named below WITH A REASON. An exemption list is
  // not a weaker version of coverage, it is the thing that makes a gap visible:
  // a new file in lib/screens now fails this test until somebody decides which
  // side it belongs on, and that decision is exactly what nobody was being
  // asked to make.
  test('every screen file is either swept or exempted for a stated reason', () {
    // Keyed by filename, value is why it is not in the sweep. Short, honest,
    // and specific enough that a reader can disagree with it.
    const exempt = <String, String>{
      // Not screens at all: cards and widgets that live inside a swept screen,
      // so they are already pumped as part of it.
      'afford_card.dart': 'a card inside Insights',
      'windfall_card.dart': 'a card inside Insights',
      'update_card.dart': 'a card inside Menu',
      // Platform plumbing with no UI.
      'app_exit_io.dart': 'no widgets, platform plumbing',
      'app_exit_stub.dart': 'no widgets, platform plumbing',
      // Not a screen: the typed registry mapping Pan CTA routes to
      // destinations. It builds no widgets of its own.
      'pan_routes.dart': 'no widgets, the Pan CTA destination registry',
      // The container the swept tabs are mounted in. Sweeping it would pump
      // Home a second time and measure the same pixels twice.
      'shell.dart': 'mounts the swept tabs; covered through them',
      // Bodies whose owning tab IS swept, under the name a person sees.
      'utang.dart': 'the body of the swept Utang tab',
      // Modal sheets. Reachable only mid-flow, each with its own widget test
      // that drives the flow rather than pumping the sheet cold. Worth doing
      // properly one day, and named here so the gap is visible rather than
      // implied. This is the biggest remaining hole in this file.
      'add_account_flow.dart': 'modal sheet, opened mid-flow',
      'edit_sheet.dart': 'modal sheet, opened mid-flow',
      'log_sheet.dart': 'modal sheet, opened mid-flow',
      'split_expense.dart': 'modal sheet, opened mid-flow',
      'quick_add_editor.dart': 'modal sheet, opened mid-flow',
      // First-run only, and correctly rendered against an EMPTY store, which is
      // the opposite fixture from the one this file uses.
      'onboarding.dart': 'first-run, needs an empty store',
      // Screens that need an argument this sweep has no sensible value for: a
      // chosen person, a chosen month, a generated image.
      'milestone_share.dart': 'needs a specific milestone to share',
      'recap_share.dart': 'needs a specific month to share',
      'csv_import.dart': 'needs a picked file',
      'new_phone_day.dart': 'a guided handoff driven by its own test',
      // Calculators. Every one is a full screen with money in it and every one
      // SHOULD be here; they are pure-input screens whose interesting states all
      // require typing, so a cold pump measures an empty form. That is a reason
      // to drive them, not to skip them, and it is the next thing this file
      // should grow.
      'bnpl_calculator.dart': 'input-driven; cold pump shows an empty form',
      'contribution_calculator.dart': 'input-driven; cold pump shows an empty form',
      'currency_converter.dart': 'input-driven; cold pump shows an empty form',
      'loan_calculator.dart': 'input-driven; cold pump shows an empty form',
      'salary_calculator.dart': 'input-driven; cold pump shows an empty form',
      'tax_calculator.dart': 'input-driven; cold pump shows an empty form',
      'thirteenth_calculator.dart': 'input-driven; cold pump shows an empty form',
      'tax_deadlines.dart': 'rendered by screens_shot; add here when it grows',
      'year_end_tax.dart': 'rendered by screens_shot; add here when it grows',
    };
    // The files the swept set covers, by the screen each entry builds.
    const sweptFiles = <String>{
      'overview.dart', 'budget.dart', 'history.dart', 'money.dart',
      'insights.dart', 'menu.dart', 'learn.dart', 'appearance.dart',
      'accounts.dart', 'categories.dart', 'reports.dart', 'debts.dart',
      'goals.dart', 'recurring.dart', 'search.dart', 'cashflow.dart',
      'paluwagan.dart', 'tools.dart', 'treats.dart', 'pan.dart',
      'payday.dart', 'notes.dart', 'mindset.dart', 'privacy_receipt.dart',
    };
    final onDisk = Directory('lib/screens')
        .listSync()
        .whereType<File>()
        .map((f) => f.path.split('/').last)
        .where((n) => n.endsWith('.dart'))
        .toSet();

    final unaccounted = onDisk
        .where((n) => !sweptFiles.contains(n) && !exempt.containsKey(n))
        .toList()
      ..sort();
    expect(
      unaccounted,
      isEmpty,
      reason:
          'these screens are neither swept nor exempted, so nothing measures '
          'them and nobody decided that. Add each to the sweep, or to the '
          'exemption map with a reason somebody could argue with:\n'
          '${unaccounted.join('\n')}',
    );

    // And the accounting cannot drift the other way either: a swept or exempted
    // name that no longer exists means somebody renamed a screen and this map
    // is now describing a file that is gone.
    final ghosts = [...sweptFiles, ...exempt.keys]
        .where((n) => !onDisk.contains(n))
        .toList()
      ..sort();
    expect(
      ghosts,
      isEmpty,
      reason: 'named here but not on disk, so this map is stale:\n${ghosts.join('\n')}',
    );

    // Every entry in the swept set is actually built by the map above. Without
    // this, sweptFiles is just a second list that can agree with nothing.
    expect(
      screens.length,
      sweptFiles.length,
      reason:
          'the swept file list and the screens actually pumped have drifted '
          'apart: ${screens.length} pumped, ${sweptFiles.length} claimed',
    );
  });

  // Proving the three checks can fail. Written after breaking each one on a
  // real screen and watching it report, then kept as the permanent version so
  // the guard cannot rot into a loop that measures nothing.
  group('the checks would actually catch it', () {
    testWidgets('an overflowing row is reported', (tester) async {
      final problems = await _inspect(
        tester,
        'broken',
        (_) => const Row(
          children: [
            Text('A sentence long enough to need the whole width of a phone.'),
            Text('And a second one beside it, with no Flexible in sight.'),
          ],
        ),
        1.0,
      );
      expect(problems.join('\n'), contains('threw during layout'));
    });

    testWidgets('a blank screen is reported', (tester) async {
      final problems = await _inspect(
        tester,
        'blank',
        (_) => const SizedBox.expand(),
        1.0,
      );
      expect(problems.join('\n'), contains('blank screen'));
    });

    testWidgets('text pushed off the side is reported', (tester) async {
      final problems = await _inspect(
        tester,
        'wide',
        // Positioned, not a wide SizedBox. The first version of this proof
        // used SingleChildScrollView(child: SizedBox(width: 900)) and the
        // check correctly said nothing, because a vertical scroll view hands
        // its child the viewport width and the 900 was quietly clamped to 390.
        // Nothing was ever off the side. Writing a proof that fails is how you
        // find out your proof was measuring air.
        (_) => const Stack(
          children: [
            Positioned(top: 0, left: 0, width: 200, child: Text('one')),
            Positioned(top: 40, left: 0, width: 200, child: Text('two')),
            Positioned(top: 80, left: 0, width: 200, child: Text('three')),
            Positioned(top: 120, left: 0, width: 200, child: Text('four')),
            Positioned(
              top: 160,
              left: 300,
              width: 300,
              child: Text('A label pinned where the phone does not reach.'),
            ),
          ],
        ),
        1.0,
      );
      expect(problems.join('\n'), contains('off the side'));
    });

    testWidgets('a defect BELOW the fold is reported', (tester) async {
      // The guard on the scroll sweep. Without this, `_mainScroller` returning
      // null on every screen would look exactly like a clean bill of health:
      // twenty green tests that only ever saw the top of ten screens. The
      // defect here sits about three phone-heights down, so it is reachable
      // only by scrolling.
      final problems = await _inspect(
        tester,
        'deep',
        (_) => ListView(
          children: [
            for (var i = 0; i < 30; i++) SizedBox(height: 80, child: Text('row $i')),
            const Row(
              children: [
                Text('A sentence long enough to need the whole width.'),
                Text('And a second one beside it, with no Flexible in sight.'),
              ],
            ),
          ],
        ),
        1.0,
      );
      expect(problems.join('\n'), contains('scrolled to'));
      expect(problems.join('\n'), contains('threw during layout'));
    });

    testWidgets('a sideways chip row is NOT reported', (tester) async {
      // The other half, and the half that matters more. A guard that flags
      // every horizontal list gets switched off, and then it is not there for
      // the real defect. This is the same lesson the delivery watchdog taught:
      // prove the silence, not only the noise.
      final problems = await _inspect(
        tester,
        'chips',
        (_) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < 12; i++)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Chip number $i'),
                ),
            ],
          ),
        ),
        1.0,
      );
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });
}
