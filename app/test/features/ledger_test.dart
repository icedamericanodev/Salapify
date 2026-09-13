// The Ledger's day totals, which are the one place this screen does arithmetic
// rather than just drawing what the engine already computed.
//
// Both rules below were found by LOOKING at a render, not by a test, and both
// were invisible to a green suite. They are written down here so they cannot
// come back quietly.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/data/backup.dart';
import 'package:salapify/features/ledger/ledger_screen.dart';

Map<String, dynamic> _state(List<Map<String, dynamic>> txs) =>
    sanitizeData({'schemaVersion': 12, 'transactions': txs});

void main() {
  test('a transfer between your own accounts is not money gone', () {
    // The defect, exactly as it rendered: one hundred pesos of load and a five
    // thousand peso move from BPI to GCash, and the heading said the day cost
    // five thousand one hundred. That is a screen telling somebody they are
    // fifty times worse off than they are.
    final days = groupByDay(
      _state([
        {
          'id': 't1',
          'type': 'expense',
          'amount': 100.0,
          'label': 'Load',
          'date': '2026-09-13',
        },
        {
          'id': 't2',
          'type': 'transfer',
          'amount': 5000.0,
          'label': 'To GCash',
          'date': '2026-09-13',
          'flow': 'out',
        },
      ]),
    );

    expect(days, hasLength(1));
    expect(
      days.single.total,
      -100.0,
      reason: 'the transfer was counted as spending',
    );
    // The transfer is still THERE. Excluded from the total, not hidden from
    // the list: that account really did fall by five thousand.
    expect(days.single.rows, hasLength(2));
  });

  test('a day of nothing but transfers shows no total at all', () {
    // Not a zero. Printing a zero would claim the day was neutral, when what
    // is true is that nothing countable happened on it.
    final days = groupByDay(
      _state([
        {
          'id': 't1',
          'type': 'transfer',
          'amount': 5000.0,
          'label': 'To GCash',
          'date': '2026-09-13',
          'flow': 'out',
        },
      ]),
    );

    expect(days.single.counts, isFalse);
    expect(days.single.rows, hasLength(1));
  });

  test('income and spending on the same day net out', () {
    final days = groupByDay(
      _state([
        {
          'id': 't1',
          'type': 'income',
          'amount': 18500.0,
          'label': 'Sweldo',
          'date': '2026-09-11',
        },
        {
          'id': 't2',
          'type': 'expense',
          'amount': 3200.0,
          'label': 'Meralco',
          'date': '2026-09-11',
        },
      ]),
    );

    expect(days.single.total, 15300.0);
    expect(days.single.counts, isTrue);
  });

  test('days come back newest first', () {
    final days = groupByDay(
      _state([
        {
          'id': 't1',
          'type': 'expense',
          'amount': 10.0,
          'label': 'A',
          'date': '2026-09-11',
        },
        {
          'id': 't2',
          'type': 'expense',
          'amount': 10.0,
          'label': 'B',
          'date': '2026-09-13',
        },
        {
          'id': 't3',
          'type': 'expense',
          'amount': 10.0,
          'label': 'C',
          'date': '2026-09-12',
        },
      ]),
    );

    expect(days.map((d) => d.date), ['2026-09-13', '2026-09-12', '2026-09-11']);
  });
}
