import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A test rots silently when it reads the real calendar.
///
/// ## What happened
///
/// On 1 October 2026 six tests went red and not a line of app code had
/// changed. They pumped `const SalapifyApp()`, which builds its own
/// `FinancialState` and therefore reads `DateTime.now()`. The seed ledger is
/// dated September 2026 and those tests assert figures meaning "spent this
/// month", so when the calendar rolled, nothing in the seed counted as this
/// month and every budget showed its full limit unspent.
///
/// Two files were pinned by hand that day. FOURTEEN were not, so the same
/// thing was going to happen again on 1 November, and the November version
/// would have looked exactly as mysterious as the October one.
///
/// ## Why this has to be a machine
///
/// The failure is invisible at the moment it is introduced. A test written on
/// the 10th of a month passes for the rest of that month, passes review,
/// passes CI, and fails on a date nobody is looking. No amount of care at
/// writing time catches it, because at writing time there is nothing to see.
///
/// This reads the test sources, which is a shape this repository already uses
/// where the thing being checked is the CODE rather than its behaviour
/// (`main_wiring_test.dart` reads main.dart; `truthful_claims_test.dart`
/// reads what the app claims).
///
/// ## What it does NOT check
///
/// It cannot tell a clock-dependent assertion from a harmless one, so it does
/// not try. It checks the one thing that is mechanical: a widget test that
/// builds the app's store must say what day it is. Pinning a store whose test
/// never looks at a date costs nothing.
void main() {
  /// Every `.dart` file under a directory, sorted so a failure names the same
  /// file every run.
  List<File> dartFilesIn(String dir) =>
      Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));

  /// The source with its line comments removed.
  ///
  /// A guard that reads source has to tell code from prose, and this one
  /// failed on its first run for exactly that: `plan_test.dart` explains in a
  /// doc comment why it does NOT pump a bare `const SalapifyApp()`, and the
  /// check flagged the explanation. A rule that punishes writing down the
  /// reason is a rule people delete.
  ///
  /// Line comments only. Block comments are not used in this test tree, and a
  /// banned call hidden inside one would still be dead code; saying so is
  /// better than a regex that half handles it.
  String withoutComments(String source) => source
      .split('\n')
      .where((String l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  /// The text of one constructor call, from `open` to its matching bracket.
  ///
  /// Needed because almost every one of these is written across several lines
  /// with `clock:` on a line of its own, so a line-by-line grep answers the
  /// wrong question. Counting brackets is enough here: none of these calls
  /// contains a string holding an unbalanced bracket, and a false alarm would
  /// be visible immediately rather than silently passing.
  String callAt(String source, int open) {
    int depth = 0;
    for (int i = open; i < source.length; i++) {
      final String c = source[i];
      if (c == '(') depth++;
      if (c == ')') {
        depth--;
        if (depth == 0) return source.substring(open, i + 1);
      }
    }
    // Unbalanced, which means the file does not compile. Return what is left
    // rather than throwing, so the compiler reports it and this does not.
    return source.substring(open);
  }

  test('no widget test builds the app with an unpinned clock', () {
    final List<String> offenders = <String>[];

    // The WHOLE tree, not just test/widgets. The rot is not a widget
    // problem: any test that builds the store and then reads a figure meaning
    // "this month" has it. Scoping the guard to where the bug happened to
    // surface first is how the second instance gets missed.
    for (final File f in dartFilesIn('test')) {
      final String src = withoutComments(f.readAsStringSync());
      for (final Match m in RegExp(r'FinancialState\(').allMatches(src)) {
        final String call = callAt(src, m.start + 'FinancialState'.length);
        if (!call.contains('clock:')) {
          final int line =
              '\n'.allMatches(src.substring(0, m.start)).length + 1;
          offenders.add('${f.path}:$line');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These build a FinancialState with no clock, so they read the real\n'
          'calendar and will fail on some future date for no reason anyone\n'
          'will be able to see. Pass clock: testToday, or use pumpSalapify\n'
          'from test/support/pinned_app.dart.\n\n'
          '${offenders.join('\n')}',
    );
  });

  test('nothing pumps a bare const SalapifyApp', () {
    // The exact shape that rotted in October. It builds its own store, so
    // there is no clock to pin and nothing in the call says so.
    //
    // test/data/main_wiring_test.dart contains the string
    // 'runApp(const SalapifyApp())' inside an assertion ABOUT main.dart, which
    // is a different call and does not match this.
    // ASSEMBLED, not written out, because this file searches the whole test
    // tree including itself and a literal here matches itself. Skipping this
    // file by name would have worked and would also have been an exemption,
    // and an exemption list is the thing that makes a guard negotiable.
    //
    // The sibling check above gets away with a literal regex only because
    // `FinancialState\(` carries a backslash and so never equals the text it
    // looks for. That is luck, not design, and it is written down here so the
    // next person editing either check knows to look.
    final String banned = <String>[
      'pumpWidget(const ',
      'Salapify',
      'App())',
    ].join();

    final List<String> offenders = <String>[];

    for (final File f in dartFilesIn('test')) {
      final String src = withoutComments(f.readAsStringSync());
      if (src.contains(banned)) offenders.add(f.path);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A bare const SalapifyApp() builds its own store on the real clock.\n'
          'Use pumpSalapify from test/support/pinned_app.dart.\n\n'
          '${offenders.join('\n')}',
    );
  });

  test('the pinned day is inside the seed ledger, not merely fixed', () {
    // A date that is pinned and WRONG is the quieter version of the same
    // problem: every screen renders in a state nobody designed, consistently,
    // forever. The seed's own window is September 2026.
    final String src = File('test/support/pinned_app.dart').readAsStringSync();
    expect(src, contains('DateTime(2026, 9, '));
  });
}
