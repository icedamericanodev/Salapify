// Every screen must be RENDERED before it can ship.
//
// CLAUDE.md has said "look at the screen before shipping a screen" for months,
// and on 2026-09-15 the Settings screen shipped without being looked at once.
// It crashed while building and drew nothing at all. The founder opened it and
// reported "I do not see a Save button" and "no Restore button as well", and
// both were true. 524 tests were green at the time, because not one of them had
// built that widget.
//
// The render harness caught it on its FIRST run. The tool was there, the rule
// was there, and the step was skipped to look fast, which cost two rounds of
// the founder's time instead. Their words: "these errors can be caught when you
// check it thoroughly. We are being inefficient."
//
// A promise to be more careful is exactly what already failed, so this is a
// machine instead. Add a screen without adding it to the shot harness and the
// suite goes red, whether or not anybody remembered the rule.
//
// WHY IT CHECKS THE HARNESS SOURCE AND NOT THE PNG FILES. `test/shots/out/` is
// gitignored, so on a fresh checkout or a CI runner the images do not exist
// until the harness has run, and a guard that depends on another test having
// run first passes or fails for reasons unrelated to the code. The harness
// SOURCE is always there and always says what it renders.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/kit.dart' show NavBar;

/// `settings_screen.dart` renders as `<theme>-settings`, and
/// `account_detail_screen.dart` as `<theme>-account-detail`.
String _shotNameFor(String fileName) =>
    fileName.replaceAll('_screen.dart', '').replaceAll('_', '-');

void main() {
  test('every screen in lib/features is rendered by the shot harness', () {
    final harness = File('test/shots/screens_shot.dart').readAsStringSync();

    final screens = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_screen.dart'))
        .map((f) => f.path.split(Platform.pathSeparator).last)
        .toList()
      ..sort();

    // Did anything happen. A glob that matched nothing would satisfy every
    // assertion below while checking precisely nothing, which is the failure
    // mode this whole file exists to stop.
    expect(
      screens.length,
      greaterThanOrEqualTo(8),
      reason:
          'found ${screens.length} screens, which means the scan is broken '
          'rather than that the app shrank',
    );

    // THE TAB SCREENS ARE RENDERED WITHOUT BEING NAMED. The harness shoots
    // every tab in a loop, `'${s.key}-${NavBar.tabs[i].$1.toLowerCase()}'`, so
    // Accounts, Ledger and Plan have shots and no literal to grep for. The
    // first version of this guard flagged all three, which was the guard being
    // wrong rather than the app: those PNGs were sitting in the output folder
    // while it reported them unrendered.
    //
    // Derived from `NavBar.tabs` rather than typed out here, so adding a tab
    // cannot silently widen the exemption. A hardcoded list would have been a
    // second place to keep true.
    final tabShots = {
      for (final t in NavBar.tabs) t.$1.toLowerCase(),
    };
    final rendersTabs = harness.contains('NavBar.tabs[i]');

    final missing = <String>[];
    for (final file in screens) {
      final shot = _shotNameFor(file);
      if (rendersTabs && tabShots.contains(shot)) continue;
      // The harness writes shots as `${s.key}-<name>`, so the quoted literal
      // is what is looked for.
      if (!harness.contains("-$shot'")) missing.add('$file  (expected -$shot)');
    }

    expect(
      missing,
      isEmpty,
      reason:
          'These screens are never rendered, so nobody has ever looked at '
          'them and a screen that fails to build would ship silently, exactly '
          'as Settings did:\n  ${missing.join('\n  ')}\n\n'
          'Add a _shoot(tester, \'\${s.key}-<name>\') for each in '
          'test/shots/screens_shot.dart, then run:\n'
          '  flutter test test/shots/screens_shot.dart --update-goldens\n'
          'and actually open the PNG.',
    );
  });
}
