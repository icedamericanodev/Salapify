// Does the screen still WORK as a piece of layout, on a real phone, when the
// person has turned their system font up?
//
// Ported into app/ on 2026-09-22, on founder direction, from
// archive/salapify-2-flutter/test/screen_readability_test.dart. CLAUDE.md has
// described this guard as live for the current app and it was not: the file
// existed only in the archive, which is never built or tested, so the branch
// check had never run it once.
//
// The render harness (test/shots/screens_shot.dart) is opt-in by design. CI
// runs it with --update-goldens, which proves it does not crash and proves
// nothing about what it drew. The pictures still need a human to open them,
// and a defect survives exactly where nobody looks. Eighty-odd images per run
// is that place.
//
// So this takes the same fixture and the same screens, throws the pictures
// away, and asserts the parts of "readable" a machine can judge:
//
//   1. Nothing overflows. A RenderFlex overflow is the yellow and black
//      barber pole on a phone, and it is never intended.
//   2. The screen drew real words. A blank tab is the loudest possible
//      failure and the easiest one to render without noticing.
//   3. No sentence runs off the side of the phone.
//   4. Nothing was quietly cut off with an ellipsis. An ellipsized line fits
//      perfectly, throws nothing, and keeps its FULL string in the widget, so
//      a test asserting on the text passes while the phone shows "49% of ₱1...".
//   5. No stored machine date reached the screen.
//
// All five at the ORDINARY font size, scrolling the whole screen rather than
// only what the first frame happened to lay out.
//
// All five at 1.5x as well, since 2026-09-22. That was not true when this
// file was ported: the large-font pass asserted only checks 1 and 2, because
// a dozen things were cut off at that size and fixing them was judged a
// design decision rather than a bug fix. The founder read the list and said
// fix them, so eleven were fixed, one turned out to be a bug in check 3
// rather than in the app, and the exemption is gone. The detail is beside
// the 1.5x tests.
//
// This paragraph said "all of it at 1.0x AND 1.5x" while that was false, for
// about an hour, which is the same defect this repository keeps finding in
// its own documents. It is true now, and it is true because the code moved
// to meet it rather than because the sentence was left alone long enough to
// come good. When a comment describes what a test does, read the test.
//
// Narrow phones are NOT covered here. Everything in this file renders 390dp,
// so a truncation that only happens on a 320 is invisible to it, and one was:
// see test/widgets/nav_bar_scaling_test.dart.
//
// What this deliberately does NOT do is compare pixels. That is why
// screens_shot.dart is kept out of `flutter test` in the first place: it is
// font and platform dependent and fails on a runner for reasons that say
// nothing about the app. Layout metrics from the same TTF are deterministic,
// so measuring the layout is safe where photographing it is not.
//
// One brightness, on purpose. A palette cannot move a box, and colour is
// measured exhaustively by palette_contrast_test.dart instead.

import 'package:flutter/material.dart';
// RenderParagraph lives here, not in material.dart. The cut-off check is the
// only thing in this file that reaches past the widget layer.
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/shell/app_shell.dart';
import 'package:salapify/state/financial_state.dart';

import 'shots/screens_shot.dart' show loadRealFonts;

/// Every tab, by the label on its bottom bar item.
///
/// A TYPED LIST rather than a derived one, and the archive's own lesson says
/// why it must then be checked: "a derived set is a rule and a typed set is a
/// promise". The promise is kept by `every tab in the shell is swept` below,
/// which counts this against the shell's own enum so a sixth tab cannot be
/// added and quietly skipped.
const List<String> _tabs = <String>[
  'Home',
  'Activity',
  'Reports',
  'Plan',
  'Accounts',
];

/// Everything currently on screen, as strings.
List<String> _visibleText() {
  final List<String> out = <String>[];
  for (final Element e in find.byType(Text).evaluate()) {
    final Text w = e.widget as Text;
    final String s = (w.data ?? w.textSpan?.toPlainText() ?? '').trim();
    if (s.isNotEmpty) out.add(s);
  }
  return out;
}

/// Is this text inside something the user can scroll SIDEWAYS?
///
/// A chip row that continues past the right edge is a design, not a defect,
/// and the off-the-side check would otherwise flag every one of them. This is
/// the difference between a check that is right and one that merely fails a
/// lot.
bool _insideHorizontalScroll(Element element) {
  bool horizontal = false;
  element.visitAncestorElements((Element a) {
    final Widget w = a.widget;
    if (w is Scrollable &&
        axisDirectionToAxis(w.axisDirection) == Axis.horizontal) {
      horizontal = true;
      return false;
    }
    return true;
  });
  return horizontal;
}

/// A stored machine date that reached the screen.
///
/// This cannot be fooled by a spelling, because it reads what was actually
/// drawn rather than scanning source for a list of key names somebody thought
/// of. Salapify stores dates as `2026-09-22` and every screen is supposed to
/// format them.
final RegExp _isoDate = RegExp(r'\b\d{4}-\d{2}-\d{2}\b');

List<String> _machineDates() {
  final List<String> bad = <String>[];
  for (final String s in _visibleText()) {
    final Match? hit = _isoDate.firstMatch(s);
    if (hit != null) bad.add('"$s" shows the stored date ${hit.group(0)}');
  }
  return bad;
}

/// Every name that came out of the STORE rather than out of Salapify.
///
/// Built from the fixture, so it needs no maintenance when the seed changes.
Set<String> _storeWords(FinancialState s) {
  final Set<String> out = <String>{};
  void add(String? v) {
    final String t = (v ?? '').trim();
    if (t.length >= 4) out.add(t);
  }

  for (final Account a in s.accounts) {
    add(a.name);
    add(a.institution);
  }
  for (final Transaction t in s.transactions) {
    add(t.merchant);
    add(t.category);
    add(t.subcategory);
  }
  for (final BillItem b in s.bills) {
    add(b.name);
  }
  for (final Debt d in s.debts) {
    add(d.person);
  }
  for (final Goal g in s.goals) {
    add(g.name);
  }
  for (final UpcomingItem u in s.upcoming) {
    add(u.name);
  }
  for (final InstallmentPlan p in s.installments) {
    add(p.name);
  }
  for (final Budget b in s.budgets) {
    add(b.category);
  }
  return out;
}

/// Text the layout gave up on and cut off with an ellipsis.
///
/// Not the same thing as overflow, and invisible to every other check here:
/// an ellipsized line fits perfectly, throws nothing, and stays inside the
/// frame. It also keeps its FULL string in the widget, so a test asserting on
/// the text passes while the phone shows "49% of ₱1...". Only the render
/// knows.
///
/// A NAME OUT OF THE STORE IS EXEMPT, and getting this wrong in either
/// direction ruins the check. Ellipsizing a merchant or an account in a list
/// row is a deliberate and correct mobile pattern; there is no width at which
/// "Corporate Payroll Direct Deposit" fits a row beside a peso figure, and a
/// person can open the row to see it in full. Flagging those makes this a
/// check that fails a lot rather than a check that is right, which is the
/// archive's own warning, and on the first run here it produced sixty four
/// findings of which about fifty were exactly that.
///
/// SALAPIFY'S OWN WORDS ARE NOT EXEMPT. A label, a caption or a tab that the
/// app wrote itself has a length the app chose, so cutting it off is always
/// the layout failing rather than the data being long.
List<String> _cutOff(Set<String> storeWords) {
  final List<String> bad = <String>[];
  for (final Element e in find.byType(Text).evaluate()) {
    final RenderObject? ro = e.renderObject;
    if (ro is! RenderParagraph || !ro.attached) continue;
    if (!ro.didExceedMaxLines) continue;
    final Text w = e.widget as Text;
    final String s = (w.data ?? w.textSpan?.toPlainText() ?? '').trim();
    if (s.isEmpty) continue;
    if (storeWords.any(s.contains)) continue;
    bad.add('"$s" is cut off');
  }
  return bad;
}

/// Text painted past the left or right edge of the phone.
///
/// Vertical is not checked and must not be: a list longer than the screen is
/// the normal state of every tab in this app. Horizontal is different, because
/// there is nowhere for it to go, so a word past the edge is a word the person
/// cannot read.
List<String> _offTheSide(WidgetTester tester) {
  final List<String> bad = <String>[];
  final double screenWidth =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;

  for (final Element e in find.byType(Text).evaluate()) {
    final RenderObject? ro = e.renderObject;
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
    if (_insideHorizontalScroll(e)) continue;

    // BOTH corners go through localToGlobal, and the second one is the whole
    // point. `left + size.width` measures the text in its OWN coordinates,
    // which is the width it would have drawn at had nothing scaled it. A
    // FittedBox(scaleDown) is exactly such a scale, and Salapify puts one
    // around every large peso figure precisely so it can shrink instead of
    // running off the page. Measuring the unscaled width therefore reported
    // the figure as 28 pixels off a 390 wide phone while the phone was in
    // fact drawing it comfortably inside the card.
    //
    // Transforming the far corner instead reads what was actually painted,
    // and it is general: it covers Transform.scale and anything else that
    // puts a matrix between the paragraph and the screen, not just the one
    // case that was caught.
    final double left = ro.localToGlobal(Offset.zero).dx;
    final double right = ro.localToGlobal(Offset(ro.size.width, 0)).dx;
    // A pixel of slack, because a rounded layout can land a hair over an
    // edge it is flush against without anything being wrong.
    if (left < -1 || right > screenWidth + 1) {
      final Text w = e.widget as Text;
      final String s = (w.data ?? w.textSpan?.toPlainText() ?? '').trim();
      if (s.isEmpty) continue;
      bad.add(
        '"$s" is painted from ${left.toStringAsFixed(1)} to '
        '${right.toStringAsFixed(1)} on a ${screenWidth.toStringAsFixed(0)} '
        'wide phone',
      );
    }
  }
  return bad;
}

/// The screen's own vertical scroll view, if it has one.
ScrollableState? _mainScroller(WidgetTester tester) {
  final Iterable<Element> all = find.byType(Scrollable).evaluate();
  for (final Element e in all) {
    final ScrollableState s = (e as StatefulElement).state as ScrollableState;
    if (axisDirectionToAxis(s.axisDirection) != Axis.vertical) continue;
    if (!s.position.hasContentDimensions) continue;
    return s;
  }
  return null;
}

void main() {
  /// Pumps the shell, walks to a tab, and inspects it at one font scale,
  /// scrolling the whole way down.
  ///
  /// Returns every problem it found, rather than asserting, so one run can
  /// report all of them instead of stopping at the first.
  Future<List<String>> sweep(
    WidgetTester tester,
    String tab,
    double scale,
  ) async {
    final List<String> problems = <String>[];

    // A RenderFlex overflow is reported through FlutterError rather than
    // thrown, so it has to be collected as it happens.
    final List<String> overflows = <String>[];
    final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails d) {
      final String s = d.exceptionAsString();
      if (s.contains('overflowed by')) {
        overflows.add(s.split('\n').first);
      } else {
        previous?.call(d);
      }
    };

    try {
      await tester.runAsync(loadRealFonts);
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;

      final FinancialState state = FinancialState(
        clock: DateTime.utc(2026, 9, 18),
      );
      final Palette p = Palette.of(state.theme);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: MaterialApp(
            theme: salapifyTheme(p, state.theme),
            home: AppShell(state: state),
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (tab != 'Home') {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
      }

      final Set<String> storeWords = _storeWords(state);

      void inspect(String where) {
        for (final String s in _offTheSide(tester)) {
          problems.add('$where: $s');
        }
        for (final String s in _cutOff(storeWords)) {
          problems.add('$where: $s');
        }
        for (final String s in _machineDates()) {
          problems.add('$where: $s');
        }
      }

      // A blank tab is the loudest possible failure.
      final List<String> words = _visibleText();
      if (words.length < 3) {
        problems.add('$tab at ${scale}x drew almost nothing: $words');
      }

      inspect('$tab at ${scale}x');

      // A ListView only lays out what is near the viewport, so without this
      // the sweep only ever sees the first screenful of every tab.
      final ScrollableState? scroller = _mainScroller(tester);
      if (scroller != null) {
        final double page = scroller.position.viewportDimension * 0.8;
        double at = 0;
        for (int i = 0; i < 16 && at < scroller.position.maxScrollExtent; i++) {
          at = (at + page).clamp(0.0, scroller.position.maxScrollExtent);
          scroller.position.jumpTo(at);
          await tester.pumpAndSettle();
          inspect('$tab at ${scale}x, scrolled to ${at.round()}');
        }
      }

      for (final String o in overflows) {
        problems.add('$tab at ${scale}x: $o');
      }
    } finally {
      FlutterError.onError = previous;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }

    return problems;
  }

  // ORDINARY FONT SIZE, everything strict. This is what every phone shows
  // unless somebody has changed a system setting, so there is no argument to
  // be had about any of it.
  //
  // On its first run this found exactly one thing across all five tabs, and
  // it was real: Home's Coming Up card explained itself with "Expected bills
  // & income before next payday" in a single line that never fit, so every
  // phone has been showing that sentence cut short since the card was
  // written. Fixed by letting it wrap.
  for (final String tab in _tabs) {
    testWidgets('$tab reads at the ordinary font size', (
      WidgetTester tester,
    ) async {
      final List<String> problems = await sweep(tester, tab, 1.0);
      expect(
        problems,
        isEmpty,
        reason:
            'this is what the phone actually draws, and none of it is '
            'visible in a passing widget test:\n${problems.join('\n')}',
      );
    });
  }

  // LARGE FONT, held to the SAME bar as the ordinary one since 2026-09-22.
  //
  // This used to assert only two of the five checks here, and the comment it
  // replaces explained why at length: twelve things were cut off at 1.5x and
  // fixing them was called a design decision rather than a bug fix, so they
  // were written down and left. The founder read the list and said fix them,
  // which is what made them ordinary work.
  //
  // Eleven were real and are fixed, each in the place it belonged:
  //   the Reports and Accounts TAB LABELS      a scale cap, app_shell.dart
  //   Reports' Performance segment             two lines
  //   Income, Reserved and Remaining           two lines
  //   "Expected bills & income before..."      no line limit at all
  //   "Next Payday: Sep 15"                    two lines
  //   the Activity search hint                 hintMaxLines
  //   an account's Sample / Loan / Due line    three lines
  //
  // The twelfth was not real, and that is the more useful half of the story.
  // A six figure total was reported as painted 28 pixels off the side of the
  // phone, and the phone was drawing it correctly the whole time: the check
  // measured the paragraph's own width, which is the width it would have had
  // if nothing had scaled it, while a FittedBox was scaling it down to fit.
  // See _offTheSide, which now transforms both corners. A guard that reports
  // a defect that is not there spends exactly the attention that the next
  // real one needs.
  //
  // What is deliberately NOT here: narrow phones. This sweep renders 390dp
  // only, and the nav bar turned out to truncate at 320dp at the ORDINARY
  // font size, which no run of this file could ever have found. That is
  // measured in test/widgets/nav_bar_scaling_test.dart, across three widths
  // and three scales, and it is where the remaining known truncation is
  // named.
  for (final String tab in _tabs) {
    testWidgets('$tab does not break at 1.5x font', (
      WidgetTester tester,
    ) async {
      final List<String> problems = await sweep(tester, tab, 1.5);
      expect(
        problems,
        isEmpty,
        reason:
            'a screen came apart at a font size a person can set in Android '
            'settings:\n${problems.join('\n')}',
      );
    });
  }

  testWidgets('every tab in the shell is swept', (WidgetTester tester) async {
    // A sweep is only as good as its list. The archive's own lesson: a
    // derived set is a rule and a typed set is a promise, so the promise is
    // checked against the shell's enum rather than trusted.
    expect(
      _tabs.length,
      SalapifyTab.values.length,
      reason:
          'the shell has a tab this file does not sweep, so a screen nobody '
          'listed is a screen nobody measures',
    );
  });
}
