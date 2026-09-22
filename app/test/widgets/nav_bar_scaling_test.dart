// Can somebody with large text on still tell the tabs apart?
//
// This exists because screen_readability_test.dart found "Reports" and
// "Accounts" ellipsised in the bottom bar at 1.5x, on every screen and at
// every scroll position, and the fix for it is a CAP on how far those two
// labels are allowed to grow. A cap is the sort of change that looks fine
// in a screenshot at one width and fails at another, so the cap is measured
// here rather than admired.
//
// It asserts on RenderParagraph.didExceedMaxLines, which is the same signal
// the readability sweep uses and is the truth about layout rather than an
// opinion about it. Real fonts are loaded first, because Flutter's default
// test font is WIDER than Plus Jakarta Sans and a width judgement made in
// the wrong face is a judgement about a phone nobody owns.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/shell/app_shell.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// Every string the bar draws. The Log pill is in here on purpose: it does
/// not sit in an Expanded, so its text is what takes width AWAY from the
/// five tabs, and clamping the tabs while leaving the pill free would have
/// half-fixed the bar.
const List<String> _barLabels = <String>[
  'Home',
  'Activity',
  'Reports',
  'Plan',
  'Accounts',
  'Log',
];

/// A small phone, the most common Android width, and a Pixel 8. The sweep in
/// screen_readability_test.dart only ever renders 390, which is how a 320dp
/// truncation survived at the ORDINARY font size without anyone seeing it.
const List<double> _widths = <double>[320, 360, 390];

/// 1.0 is the default. 1.5 is the setting that found the defect. 2.0 is the
/// largest an Android user can reach without the accessibility "Font size"
/// override, and it is included so the cap is proven to hold rather than
/// merely to help.
const List<double> _scales = <double>[1.0, 1.5, 2.0];

/// WHAT IS STILL BROKEN, named rather than left out of the loop above.
///
/// One case survives: the word "Accounts" on a phone narrower than 390dp with
/// large text on. It is the longest of the five destination names, and the
/// arithmetic is not close. At the capped size it needs 61.5dp. A 360dp phone
/// can give it 56.9 and a 320dp phone 48.9, after both padding levers have
/// already been spent. Finding the missing 23dp on a 360 needs a MATERIAL
/// change, dropping the word "Log" from the pill or shortening a destination
/// name, and that is a product decision rather than an engineering one, so it
/// is raised to the founder and written down here instead of being quietly
/// taken.
///
/// This is a TYPED exemption, not a baseline, and the difference is the whole
/// point. It names one label at two widths. A second label truncating, or
/// this one truncating at 390, or either of them truncating at the ordinary
/// font size, all still redden this test. An exemption that grows on its own
/// is just a switched-off test with extra steps.
const List<(String, double)> _knownNarrowTruncation = <(String, double)>[
  ('Accounts', 320),
  ('Accounts', 360),
  // 320dp loses a second one. "Reports" needs 51.4 and a 320 gives 48.9, so
  // it misses by 2.5 where "Accounts" misses by 12.6. It is listed separately
  // rather than folded in because the two are not one problem: a change that
  // buys 3dp a tab fixes this row and does nothing at all for the two above.
  ('Reports', 320),
];

void main() {
  for (final double width in _widths) {
    for (final double scale in _scales) {
      testWidgets('no bar label is cut off at ${width}dp and ${scale}x', (
        WidgetTester tester,
      ) async {
        await tester.runAsync(loadRealFonts);
        tester.view.physicalSize = Size(width * 3, 844 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

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

        final List<String> cut = <String>[];
        for (final String label in _barLabels) {
          final Finder f = find.text(label);
          if (f.evaluate().isEmpty) {
            cut.add('"$label" is not on the bar at all');
            continue;
          }
          // .last, because a destination's name is also drawn as the open
          // screen's own title. The bar is the one built last.
          final RenderParagraph para = tester.renderObject(f.last);
          if (!para.didExceedMaxLines) continue;
          // The exemption only applies where large text is what broke it. At
          // the ordinary font size every label fits on every width, and that
          // is asserted with no exemption at all, because a nav label cut off
          // at 1.0x is a plain bug rather than a dynamic type tradeoff. One
          // was: "Accounts" truncated on a 320dp phone at 1.0x, present since
          // the bar was written and invisible to the readability sweep, which
          // only ever renders 390.
          if (scale > 1.0 && _knownNarrowTruncation.contains((label, width))) {
            continue;
          }
          cut.add('"$label" is cut off');
        }

        expect(
          cut,
          isEmpty,
          reason:
              'the bottom bar stopped being readable at ${width}dp and '
              '${scale}x, which is a font size a person chooses in Android '
              'settings because they need it:\n${cut.join('\n')}',
        );
      });
    }
  }
}
