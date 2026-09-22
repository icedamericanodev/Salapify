import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Does the app that SHIPS actually save to the device?
///
/// `FinancialState` defaults its store to memory, because that is the safe
/// default everywhere a store is forgotten: a test that forgets writes no
/// files, a preview that forgets touches no disk. The one place forgetting
/// would be a disaster is `main`, where memory would mean an app that looks
/// like it saves, says it saves, and loses everything on close.
///
/// No runtime test can catch that: every widget test deliberately runs on the
/// memory store, so a `main` wired to memory would leave all 508 of them
/// green. So this reads the source, which is the only place the answer is
/// written down. It is the same shape as font_inheritance_test.dart, and it
/// exists for the same reason: some promises are only checkable by looking at
/// the code that makes them.
void main() {
  test('main gives the app a real file store, not the memory default', () {
    final String source = File('lib/main.dart').readAsStringSync();

    expect(
      source,
      contains('FileSnapshotStore()'),
      reason:
          'main must construct the store that writes to the device. Without '
          'this the app runs on the memory default and silently loses every '
          'entry when it closes, with every test still passing.',
    );
    expect(
      source,
      contains('await state.restore()'),
      reason:
          'main must READ the file before the first frame. Skipping this '
          'shows the seed and then saves it over whatever was there.',
    );
    expect(
      source,
      isNot(contains('runApp(const SalapifyApp())')),
      reason:
          'the no-argument form builds its own state on the memory store, '
          'which is the test wiring, not the shipping one',
    );
  });

  test('the restore happens BEFORE runApp, not after', () {
    final String source = File('lib/main.dart').readAsStringSync();
    final int restoreAt = source.indexOf('await state.restore()');
    final int runAppAt = source.indexOf('runApp(');

    expect(restoreAt, greaterThan(-1));
    expect(runAppAt, greaterThan(-1));
    expect(
      restoreAt,
      lessThan(runAppAt),
      reason:
          'loading after the first frame shows the seed\'s demo accounts for '
          'a moment and then swaps them for the person\'s real money, which '
          'reads like the app lost their data and found it again',
    );
  });
}
