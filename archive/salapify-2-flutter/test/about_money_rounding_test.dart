// A sentence that says "about" must not then print centavos.
//
// "About ₱26,525.25 a day" is a sentence arguing with itself: the word
// promises a rounded figure and the number gives two decimal places. On the
// Insights safe-to-spend card that string sat a few centimetres above another
// card reading "about ₱26,525 free to move". One number, one screen, two
// spellings, and the second one was already correct.
//
// The convention was never missing. Steady Pay rounds, the Home pace line
// rounds. It was applied at some call sites and not others, which is the kind
// of defect no test catches and no reader notices until the day they are
// looking at their own money. This is that test.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/currencies.dart' show baseCurrencySymbol;
import 'package:salapify/money/format.dart';

/// `about ${formatMoney(...)}` in a user-facing string.
///
/// Matches the centavo formatter only. formatMoneyAbout and formatMoneyText
/// both end in whole pesos, so both are fine after "about" and neither may
/// match here, or the guard flags its own fix.
final _hedgedWithCentavos = RegExp(
  r'\babout \$\{formatMoney\(',
  caseSensitive: false,
);

void main() {
  group('the helper', () {
    test('drops centavos', () {
      expect(formatMoneyAbout(26525.25), '${baseCurrencySymbol}26,525');
      expect(formatMoneyAbout(26525.75), '${baseCurrencySymbol}26,526');
    });

    test('rounds to NEAREST, not up', () {
      // The distinction matters and is the reason this is not formatMoneyText,
      // which rounds up. Rounding a spending figure up tells somebody they
      // have more room than they do, every single time, in the one direction
      // that costs them money.
      expect(formatMoneyAbout(100.4), '${baseCurrencySymbol}100');
      expect(formatMoneyAbout(100.5), '${baseCurrencySymbol}101');
    });

    test('leaves a whole peso alone', () {
      expect(formatMoneyAbout(1200), formatMoney(1200));
    });

    test('keeps the sign', () {
      expect(formatMoneyAbout(-99.6), '-${baseCurrencySymbol}100');
    });

    test('survives the junk a restored backup can carry', () {
      // roundToDouble() THROWS on infinity, so the order of the guards inside
      // the helper is load-bearing. A backup with a non-finite sum would
      // otherwise take down whichever screen printed it, and every screen in
      // this app prints money.
      expect(() => formatMoneyAbout(double.infinity), returnsNormally);
      expect(() => formatMoneyAbout(double.nan), returnsNormally);
      expect(() => formatMoneyAbout(double.maxFinite), returnsNormally);
    });
  });

  group('formatMoney never prints a negative zero', () {
    test('a hair below zero rounds to a plain zero, no minus', () {
      // A balance nudged just under zero by float drift used to read "-₱0", a
      // struck minus on nothing, and disagreed with formatMoneyText, which
      // takes its sign from the rounded integer and so never did this.
      expect(formatMoney(-0.004), '${baseCurrencySymbol}0');
      expect(formatMoney(-0.0001), '${baseCurrencySymbol}0');
    });

    test('a real negative still keeps its sign', () {
      // The filter-not-off-switch half: a genuine negative is untouched.
      expect(formatMoney(-0.01), '-${baseCurrencySymbol}0.01');
      expect(formatMoney(-720), '-${baseCurrencySymbol}720');
      expect(formatMoney(-99.6), '-${baseCurrencySymbol}99.60');
    });
  });

  test('no screen says "about" and then prints centavos', () {
    final offenders = <String>[];
    for (final dir in ['lib/screens', 'lib/money', 'lib/widgets']) {
      for (final f in Directory(dir).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (!_hedgedWithCentavos.hasMatch(line)) continue;
          offenders.add('${f.path}:${i + 1}  ${line.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'these hedge a figure with "about" and then print it to the centavo, '
          'which reads as a bug to the person holding the phone. Use '
          'formatMoneyAbout:\n${offenders.join('\n')}',
    );
  });

  test('the scan would actually find one', () {
    // A scanner that matches nothing passes on an empty directory and on a
    // typo in its own pattern, and reads exactly like a clean bill of health.
    expect(
      _hedgedWithCentavos.hasMatch(r"'about ${formatMoney(perDay)} a day'"),
      isTrue,
      reason: 'the shape the bug had',
    );
    expect(
      _hedgedWithCentavos.hasMatch(r"'About ${formatMoney(saved)} more'"),
      isTrue,
      reason: 'capitalised at the start of a sentence is the same bug',
    );
    expect(
      _hedgedWithCentavos.hasMatch(
        r"'about ${formatMoneyAbout(perDay)} a day'",
      ),
      isFalse,
      reason: 'the fix must not be flagged, or the guard is unusable',
    );
    // An exact figure with no hedge is not the bug. Balances, totals and
    // logged amounts are exact on purpose and the golden vectors pin them to
    // the centavo; a guard that reached them would be demanding a wrong
    // number.
    expect(
      _hedgedWithCentavos.hasMatch(r"'${formatMoney(balance)} in the bank'"),
      isFalse,
    );
  });
}
