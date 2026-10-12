import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/debt_ratio.dart';

/// P1.7 / F8: the app states ONE debt to income rule.
///
/// ## What it stated before
///
/// The October expert review counted four answers to the same question:
///
///   - the health check: 25% comfortable, 40% tight, on take-home
///   - `calculateDsr`: under 30% healthy and over 40% stretched, while
///     separately recommending a ceiling of 35% of GROSS
///   - the debt calculator screen: its own 30 and 40 in prose
///   - the Academy, twice: stay under 15% of take-home
///
/// Each was defensible alone, which is why nothing looked wrong enough to
/// notice. A person who read two of them learned that Salapify does not know.
///
/// ## Why this reads the source
///
/// The "done when" for this task is that grep finds one constant, and a
/// behaviour test cannot check that: four constants that happen to agree today
/// pass every behaviour test and drift apart next month. This is the shape
/// `main_wiring_test.dart` and `clock_discipline_test.dart` already use, where
/// the thing being checked is the code rather than its output.
void main() {
  List<File> dartFilesIn(String dir) =>
      Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));

  /// Source with line comments stripped, so the file that EXPLAINS the old
  /// numbers is not reported for mentioning them. A guard that punishes
  /// writing down the reason is a rule people delete.
  String code(File f) => f
      .readAsStringSync()
      .split('\n')
      .where((String l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  test('the rule is 30 and 40, in one place', () {
    expect(debtShareComfortable, 30);
    expect(debtShareStretched, 40);
    expect(
      debtShareComfortableFraction,
      0.30,
      reason:
          'the fraction must be derived from the percent, never typed '
          'again, or the two drift into disagreeing',
    );
  });

  test('no other file declares its own debt share threshold', () {
    // Matches a CONSTANT declaration of a bare number named for a debt share,
    // not every mention of 30. Narrow on purpose: a guard that fires on
    // unrelated code gets switched off and is then absent for the real thing.
    final RegExp decl = RegExp(r'const\s+(int|double)\s+debtShare\w*\s*=');
    final List<String> offenders = <String>[];

    for (final File f in dartFilesIn('lib')) {
      if (f.path.endsWith('core/money/debt_ratio.dart')) continue;
      if (decl.hasMatch(code(f))) offenders.add(f.path);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'a second debt share constant is how the app came to state four '
          'different rules.\n\n${offenders.join('\n')}',
    );
  });

  test('the Academy no longer teaches a different rule', () {
    // It said 15% twice, which is half the rule the rest of the app applies.
    // Somebody who read the lesson and then opened the health check saw their
    // own debts called comfortable by one screen and not the other.
    final String academy = File(
      'lib/data/academy_data.dart',
    ).readAsStringSync();

    expect(
      academy,
      isNot(contains('15% of your')),
      reason: 'the Academy still teaches the old 15% rule',
    );
    expect(academy, contains('30% of your take-home pay'));
  });
}
