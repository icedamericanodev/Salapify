// QA probe for f3.90, deleted after the QA pass. Not part of the suite.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/insight_feed.dart';

void main() {
  final early = DateTime(2026, 7, 2); // day 2 of 31
  final mid = DateTime(2026, 7, 20);

  test('PROBE early-month vs-last-month pulse fires with no pacing gate', () {
    final d = {
      'transactions': [
        {'type': 'income', 'amount': 20000, 'date': '2026-06-01'},
        {'type': 'expense', 'amount': 16000, 'date': '2026-06-15', 'label': 'Food'},
        {'type': 'income', 'amount': 20000, 'date': '2026-07-01'},
        {'type': 'expense', 'amount': 1000, 'date': '2026-07-02', 'label': 'Food'},
      ],
      'payments': const [],
    };
    final p = monthPulse(d, early);
    print('EARLY PULSE: ${p?.headline} | ${p?.detail} | tone=${p?.tone} conf=${p?.confidence}');
  });

  test('PROBE junk shapes never crash', () {
    for (final txs in [
      'garbage', 42, null, {'a': 1},
      ['not-a-map', 7, null, {'type': 'expense', 'amount': 'abc', 'date': 12345, 'label': 9, 'note': 3}],
      [{'type': 'expense', 'amount': 1e308, 'date': '2026-07-05', 'label': 'X'},
       {'type': 'expense', 'amount': 1e308, 'date': '2026-07-05', 'label': 'X'},
       {'type': 'expense', 'amount': 2000, 'date': '2026-06-10', 'label': 'X'}],
    ]) {
      final d = {'transactions': txs, 'payments': 'junk'};
      expect(() => monthPulse(d, mid), returnsNormally, reason: '$txs');
      expect(() => whatChanged(d, mid), returnsNormally, reason: '$txs');
      expect(() => weekdayLine(d, mid), returnsNormally, reason: '$txs');
      expect(() => changeDriver(txs, 'X', mid), returnsNormally, reason: '$txs');
    }
    expect(() => trendConclusion([{}, {'income': 'x'}]), returnsNormally);
  });

  test('PROBE best-month claim wording with sparse income months', () {
    final d = {
      'transactions': [
        // income in only 3 of the 6 prior months (Jan, Mar, May 2026)
        for (final m in ['01', '03', '05']) ...[
          {'type': 'income', 'amount': 20000, 'date': '2026-$m-01'},
          {'type': 'expense', 'amount': 17000, 'date': '2026-$m-10', 'label': 'Food'},
        ],
        {'type': 'income', 'amount': 20000, 'date': '2026-07-01'},
        {'type': 'expense', 'amount': 5000, 'date': '2026-07-10', 'label': 'Food'},
      ],
      'payments': const [],
    };
    final p = monthPulse(d, mid);
    print('BEST-MONTH: ${p?.headline}');
  });

  test('PROBE multiline monster note rides into the driver sentence', () {
    final note = 'line one\nline two that is quite long and pasted from a chat app, '
        'with lots of words that will wrap forever and ever and ever';
    final d = [
      {'type': 'expense', 'amount': 900, 'date': '2026-07-02', 'label': 'Food', 'note': note},
      {'type': 'expense', 'amount': 800, 'date': '2026-07-09', 'label': 'Food', 'note': note},
    ];
    print('DRIVER: ${changeDriver(d, 'Food', mid)}');
  });

  test('PROBE negative-amount rows: shift number vs driver claim', () {
    final d = {
      'transactions': [
        {'type': 'expense', 'amount': 100, 'date': '2026-06-10', 'label': 'X'},
        {'type': 'expense', 'amount': 600, 'date': '2026-07-05', 'label': 'X'},
        {'type': 'expense', 'amount': 5000, 'date': '2026-07-06', 'label': 'X'},
        {'type': 'expense', 'amount': -3000, 'date': '2026-07-07', 'label': 'X'},
      ],
      'payments': const [],
    };
    final w = whatChanged(d, mid);
    for (final s in w.shifts) {
      print('SHIFT ${s.label}: now=${s.now} change=${s.change} driver=${s.driver}');
    }
  });

  test('PROBE whatChanged when last month was income-only', () {
    final d = {
      'transactions': [
        {'type': 'income', 'amount': 20000, 'date': '2026-06-01'},
        {'type': 'expense', 'amount': 9000, 'date': '2026-07-05', 'label': 'Food'},
        {'type': 'expense', 'amount': 9000, 'date': '2026-05-05', 'label': 'Food'},
      ],
      'payments': const [],
    };
    final w = whatChanged(d, mid);
    print('INCOME-ONLY PREV: comparable=${w.comparable} note=${w.note}');
  });
}
