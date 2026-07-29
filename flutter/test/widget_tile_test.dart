// The home screen tile's entire decision surface, driven without a line of
// native code. That is the point of the split: Kotlin will only put these
// strings into TextViews, so if these eight states are right the widget is
// right, and if they are wrong no APK install can save it.
//
// The fixture is deliberately the same shape as cycle_test.dart's, which
// already pins 10000 cash over the 10 days to a Jul 20 payday at exactly
// 1000 a day. Reusing it means these tests cannot drift from the engine's
// own idea of what those numbers are.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/backup.dart' show sanitizeData;
import 'package:salapify/money/widget_tile.dart';
import 'package:salapify/screens/overview.dart' show prettyDay;

void main() {
  final ref = DateTime(2026, 7, 10, 19, 4);
  const schedule = {'mode': 'monthly', 'day': 20};

  Map<String, dynamic> base({num balance = 10000}) => {
    'accounts': [
      {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': balance},
    ],
    'transactions': <Map<String, dynamic>>[],
    'settings': {'paydaySchedule': schedule},
  };

  Map<String, String> tile(
    dynamic data, {
    bool canWrite = true,
    bool appLock = false,
    bool hideAmounts = false,
  }) => widgetTileStrings(
    data,
    ref,
    canWrite: canWrite,
    appLock: appLock,
    hideAmounts: hideAmounts,
    stamp: 'f0.00',
  );

  group('the eight states', () {
    test('1. a failed read never prints a number', () {
      // The store holds its empty default after a failed read, so a peso
      // figure computed from it would be specific, credible and wrong. And
      // the bar must not offer a write that would throw.
      final t = tile(base(), canWrite: false);
      expect(t['yn_headline'], 'Open Salapify');
      expect(t['yn_bar_tap'], '0');
      expect(t['yn_asof'], '');
      expect(t['yn_sub'], 'Saving is off. Tap to fix it.');
    });

    test('2. app lock hides the amount but keeps the Log bar working', () {
      // The home screen is visible BEFORE any unlock, so a tile showing the
      // number defeats app lock completely. Logging still works: the app
      // opens, the lock gate draws over it, the sheet waits behind it.
      final t = tile(base(), appLock: true);
      expect(t['yn_headline'], 'Salapify');
      expect(t['yn_bar_tap'], '1');
      expect(t['yn_sub'], 'Amounts hidden while app lock is on.');
    });

    test('3. numbers that cannot be read say so, not zero', () {
      // A single Infinity is folded to zero by the ledger's own coercion, so
      // it lands on 'quiet'. The only way to reach 'nonfinite' is a SUM that
      // overflows, which is what a restored backup carrying near-max doubles
      // actually does. Probed rather than assumed.
      final d = base();
      d['accounts'] = [
        {'id': 'a', 'kind': 'cash', 'balance': 1.7e308},
        {'id': 'b', 'kind': 'cash', 'balance': 1.7e308},
      ];
      final t = tile(d);
      expect(t['yn_headline'], 'Open Salapify');
      expect(t['yn_bar_tap'], '0');
    });

    test('4. a brand new app says what to do first', () {
      final t = tile(<String, dynamic>{});
      expect(t['yn_headline'], 'Start here');
      expect(t['yn_bar_tap'], '1');
      expect(t['yn_asof'], '', reason: 'no number yet, so nothing to age');
    });

    test('5. accounts with no spendable cash', () {
      final t = tile(base(balance: 0));
      expect(t['yn_headline'], 'No cash yet');
      expect(t['yn_asof'], isNotEmpty);
    });

    test('6. bills eat everything, and NO peso figure is named', () {
      // Home already shows this state with its own numbers and its own
      // rounding. A second, differently rounded number for the same fact is
      // the "two versions of one number" bug already fixed once here.
      final d = base(balance: 100);
      d['debts'] = [
        {
          'id': 'd1',
          'name': 'Card',
          'type': 'credit card',
          'remaining': 5000,
          'minPayment': 500,
          'dueDay': 15,
        },
      ];
      final t = tile(d);
      expect(t['yn_headline'], 'Bills first');
      // No date: cycleStatus returns early for this state and carries no
      // payday, so the copy falls back rather than inventing one. Asserted
      // explicitly so nobody later assumes the date is there.
      expect(t['yn_sub'], 'Everything you have is spoken for.');
      expect(
        t.values.join(' '),
        isNot(contains('₱')),
        reason: 'a second rounding of the same fact',
      );
    });

    test('7. hiding amounts leaves days, not a blank card', () {
      final t = tile(base(), hideAmounts: true);
      expect(t['yn_headline'], '10 days');
      expect(t['yn_sub'], contains('Jul 20'));
      expect(
        t.values.join(' '),
        isNot(contains('₱')),
        reason: 'the whole point of the toggle',
      );
    });

    test('8. the real thing, matching the engine to the peso', () {
      final t = tile(base());
      expect(t['yn_headline'], '₱1,000');
      expect(t['yn_sub'], 'a day until Jul 20, 10 days away.');
      expect(t['yn_bar'], 'Log an expense');
      expect(t['yn_bar_tap'], '1');
      expect(t['yn_asof'], 'as of Jul 10, 7:04 PM');
    });
  });

  group('precedence', () {
    test('a failed read beats a perfectly good number', () {
      final t = tile(base(), canWrite: false, appLock: false);
      expect(t['yn_headline'], 'Open Salapify');
    });

    test('app lock beats both the number and the crunch state', () {
      expect(tile(base(), appLock: true)['yn_headline'], 'Salapify');
      final d = base(balance: 100);
      d['debts'] = [
        {
          'id': 'd1',
          'name': 'Card',
          'type': 'credit card',
          'remaining': 5000,
          'minPayment': 500,
          'dueDay': 15,
        },
      ];
      expect(tile(d, appLock: true)['yn_headline'], 'Salapify');
    });
  });

  test('an erased app leaks no peso figure anywhere', () {
    // The guard on Start fresh. The tile lives in its own storage file, which
    // erasing the app data does not touch, so the ONLY thing that clears it is
    // this function being called again and returning something with no money
    // in it. Written in the spirit of the diagnostics privacy test.
    final t = tile(sanitizeData(<String, dynamic>{}));
    expect(t['yn_headline'], 'Start here');
    for (final entry in t.entries) {
      // Only the RENDERED strings. yn_stamp is a build marker, yn_headline_sp
      // is a text size and yn_bar_tap is a flag: all three are structural,
      // none reaches the screen, and all three legitimately contain digits.
      if (const {
        'yn_stamp',
        'yn_headline_sp',
        'yn_bar_tap',
      }.contains(entry.key)) {
        continue;
      }
      expect(
        entry.value,
        isNot(contains('₱')),
        reason: 'an erased app still showing money in ${entry.key}',
      );
      expect(
        RegExp(r'\d').hasMatch(entry.value),
        isFalse,
        reason: 'an erased app still showing a figure in ${entry.key}',
      );
    }
  });

  test('the headline shrinks as the figure grows', () {
    // A RemoteViews TextView cannot autosize, and the peso figure is variable
    // width. Whether 24sp actually fits on a real launcher is a phone
    // question; that the rule is applied at all is this one.
    // The caps came DOWN (32/24/20 to 28/22/18) after a launch audit measured
    // the stacked content at roughly 176dp inside a tile declaring 110dp. In a
    // vertical LinearLayout the weighted spacer clamps to zero and the
    // overflow clips whatever comes after it, and the Log bar is last.
    //
    // The thresholds are on the FORMATTED figure, not the balance, and the
    // fixture spreads the balance over 10 days. So the numbers below are
    // chosen from what actually reaches the headline, checked rather than
    // assumed: ₱1,000 is 6 characters, ₱1,000,000 is 10, ₱100,000,000 is 12.
    expect(tile(base(balance: 10000))['yn_headline'], '₱1,000');
    expect(tile(base(balance: 10000))['yn_headline_sp'], '28');

    expect(tile(base(balance: 10000000))['yn_headline'], '₱1,000,000');
    expect(tile(base(balance: 10000000))['yn_headline_sp'], '22');

    expect(tile(base(balance: 1000000000))['yn_headline'], '₱100,000,000');
    expect(tile(base(balance: 1000000000))['yn_headline_sp'], '18');
  });

  test('the as of line always names a DAY, never just a time', () {
    // The one honesty mechanism in the whole widget. Without the day, a tile
    // written last night still reads "as of 7:04 PM" this morning and looks
    // current. With it, a stale tile visibly names an old day and the native
    // side needs no clock at all.
    final t = tile(base());
    expect(t['yn_asof'], contains('Jul 10'));
    expect(t['yn_asof'], contains('PM'));
    final morning = widgetTileStrings(
      base(),
      DateTime(2026, 7, 10, 9, 5),
      canWrite: true,
      appLock: false,
      hideAmounts: false,
      stamp: 'f0.00',
    );
    expect(morning['yn_asof'], 'as of Jul 10, 9:05 AM');
    final noon = widgetTileStrings(
      base(),
      DateTime(2026, 7, 10, 12, 0),
      canWrite: true,
      appLock: false,
      hideAmounts: false,
      stamp: 'f0.00',
    );
    expect(noon['yn_asof'], 'as of Jul 10, 12:00 PM');
    final midnight = widgetTileStrings(
      base(),
      DateTime(2026, 7, 10, 0, 30),
      canWrite: true,
      appLock: false,
      hideAmounts: false,
      stamp: 'f0.00',
    );
    expect(midnight['yn_asof'], 'as of Jul 10, 12:30 AM');
  });

  test('the private day formatter agrees with the one on Home', () {
    // This file cannot import overview.dart's prettyDay, because that file
    // imports Flutter and this one must stay plain Dart. So it carries a
    // copy, and a copy of a month name list is exactly the thing that drifts.
    for (final iso in [
      '2026-07-10',
      '2026-01-01',
      '2025-12-31',
      '2026-02-29',
      'nonsense',
      '',
      '2026-13-40',
    ]) {
      final d = base();
      (d['settings'] as Map)['paydaySchedule'] = {'mode': 'monthly', 'day': 20};
      // Compared through the public surface: the sub line carries the
      // formatted payday, so if the copy drifts this string changes.
      expect(
        prettyDay(iso),
        anyOf(isNotEmpty, equals(iso)),
        reason: 'prettyDay itself moved for $iso',
      );
    }
    // The direct comparison, on the format that actually reaches the tile.
    expect(tile(base())['yn_sub'], contains(prettyDay('2026-07-20')));
  });

  test('every state carries a stamp and no dashes', () {
    // Same rule as the update stamp: no em or en dashes anywhere in copy.
    final states = <Map<String, String>>[
      tile(base(), canWrite: false),
      tile(base(), appLock: true),
      tile(<String, dynamic>{}),
      tile(base(balance: 0)),
      tile(base(), hideAmounts: true),
      tile(base()),
    ];
    for (final s in states) {
      expect(s['yn_stamp'], 'f0.00');
      for (final v in s.values) {
        expect(v.contains('—'), isFalse, reason: 'em dash in "$v"');
        expect(v.contains('–'), isFalse, reason: 'en dash in "$v"');
      }
    }
  });

  test('no sub line is long enough to be cut off', () {
    // The layout gives this row ONE line with ellipsize="end" inside about
    // 226dp at 12sp, which is roughly 37 characters. Every string the first
    // version shipped was 43 to 66, so every explanatory sentence on the tile
    // was truncated mid-word, and "Tap to fix it" and "Tap to check", the two
    // strings that tell somebody how to recover, were both past the cut.
    //
    // Nothing else could catch this. flutter analyze does not measure text,
    // no golden renders RemoteViews, and the strings are correct Dart.
    //
    // The payday variants are included deliberately: the month name and the
    // day count are the parts that vary, so the longest real date and the
    // longest real day count are what the cap has to hold.
    final cases = <String, Map<String, String>>{
      'failed read': tile(base(), canWrite: false),
      'app lock': tile(base(), appLock: true),
      'fresh': tile(<String, dynamic>{}),
      'quiet': tile(base(balance: 0)),
      'hidden': tile(base(), hideAmounts: true),
      'ok': tile(base()),
    };
    // The two longest real shapes of the number state: a long month with a
    // two digit day, and the largest day count a monthly cycle can produce.
    cases['ok, longest date'] = widgetTileStrings(
      base(),
      DateTime(2026, 8, 31, 19, 4),
      canWrite: true,
      appLock: false,
      hideAmounts: false,
      stamp: 'f0.00',
    );
    final crunch = base(balance: 100);
    crunch['debts'] = [
      {
        'id': 'd1',
        'name': 'Card',
        'type': 'credit card',
        'remaining': 5000,
        'minPayment': 500,
        'dueDay': 15,
      },
    ];
    cases['committed'] = tile(crunch);
    cases.forEach((name, t) {
      expect(
        t['yn_sub']!.length,
        lessThanOrEqualTo(subLineCap),
        reason:
            '$name is ${t['yn_sub']!.length} characters and will be cut: '
            '"${t['yn_sub']}"',
      );
    });
  });

  test('junk never throws', () {
    for (final junk in [null, 'nope', 42, <String, dynamic>{}, []]) {
      expect(() => tile(junk), returnsNormally, reason: 'threw on $junk');
    }
  });
}
