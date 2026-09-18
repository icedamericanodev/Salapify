// Remind and Statement must name the SAME amount to the same friend.
//
// Two messages, two code paths. Remind takes the number the person sheet
// shows, which sums each utang's own remainder with a floor of zero.
// Statement computed total lent minus total paid, one global subtraction. The
// two agree on every shape the app itself can create, and disagree the moment
// a single utang has been paid more than it was for, which an imported backup
// can carry because logPartial clamps a payment to the remaining and an old
// file need not have.
//
// The gap is not academic and it is not symmetric: the netted figure is the
// SMALLER one, so the document sent to the person understates what they owe,
// while the app's own screen shows the larger number to the person who sent
// it. Both people then have a piece of paper and they do not match.
//
// This was a named DEFERRED finding on f2.73.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/receivables.dart' show remainingOf;
import 'package:salapify/money/statement.dart';

void main() {
  final asOf = DateTime(2026, 7, 10);

  /// Everything the person sheet counts as still owed, which is what the
  /// Remind button is handed.
  double sheetTotal(List<Map<String, dynamic>> rows) =>
      rows.fold(0.0, (t, r) => t + remainingOf(r));

  /// The STILL OPEN figure out of the rendered document.
  double statementStillOpen(List<Map<String, dynamic>> rows) {
    final text = buildPersonStatement(
      {'name': 'Ana'},
      rows,
      asOf: asOf,
      money: (n) => n.toStringAsFixed(2),
    );
    final line = text
        .split('\n')
        .firstWhere((l) => l.startsWith('STILL OPEN:'), orElse: () => '');
    if (line.isEmpty) return 0;
    return double.parse(line.split(':').last.trim());
  }

  test('an overpaid utang does not quietly pay off a different one', () {
    // 500 lent with 700 logged against it, plus 300 lent with nothing.
    // Netted: 800 - 700 = 100. Per utang: 0 + 300 = 300. The friend owes 300;
    // the 200 extra they paid on the first utang is not a credit against the
    // second one unless the two of them say it is.
    final rows = <Map<String, dynamic>>[
      {
        'id': 'r1',
        'amount': 500,
        'dueDate': '2026-07-01',
        'payments': [
          {'id': 'p1', 'amount': 700, 'date': '2026-07-02'},
        ],
      },
      {'id': 'r2', 'amount': 300, 'dueDate': '2026-07-03'},
    ];
    expect(sheetTotal(rows), 300);
    expect(
      statementStillOpen(rows),
      sheetTotal(rows),
      reason:
          'the Statement and the Remind message name two different amounts '
          'to the same person, and the document names the smaller one',
    );
  });

  test('ordinary data is untouched, so the RN goldens still hold', () {
    // The half that proves the change is a floor and not a new rule. Every
    // shape the app can produce goes down the same arithmetic it always did.
    final rows = <Map<String, dynamic>>[
      {
        'id': 'r1',
        'amount': 500,
        'dueDate': '2026-07-01',
        'payments': [
          {'id': 'p1', 'amount': 200, 'date': '2026-07-02'},
        ],
      },
      {'id': 'r2', 'amount': 300, 'dueDate': '2026-07-03'},
    ];
    expect(sheetTotal(rows), 600);
    expect(statementStillOpen(rows), 600);
  });

  test('a marked-paid utang closes at zero however the payments add up', () {
    // Marking paid settles the utang. It must not become an overpayment that
    // then inflates the person's total.
    final rows = <Map<String, dynamic>>[
      {
        'id': 'r1',
        'amount': 500,
        'paid': true,
        'payments': [
          {'id': 'p1', 'amount': 900, 'date': '2026-07-02'},
        ],
      },
      {'id': 'r2', 'amount': 300, 'dueDate': '2026-07-03'},
    ];
    expect(sheetTotal(rows), 300);
    expect(statementStillOpen(rows), 300);
  });

  test('everything genuinely settled still reads FULLY PAID', () {
    final rows = <Map<String, dynamic>>[
      {
        'id': 'r1',
        'amount': 500,
        'payments': [
          {'id': 'p1', 'amount': 500, 'date': '2026-07-02'},
        ],
      },
    ];
    expect(sheetTotal(rows), 0);
    final text = buildPersonStatement({'name': 'Ana'}, rows, asOf: asOf);
    expect(text, contains('FULLY PAID'));
    expect(text, isNot(contains('STILL OPEN')));
  });

  test('an overpaid utang ALONE still reads FULLY PAID, not a negative', () {
    final rows = <Map<String, dynamic>>[
      {
        'id': 'r1',
        'amount': 500,
        'payments': [
          {'id': 'p1', 'amount': 700, 'date': '2026-07-02'},
        ],
      },
    ];
    expect(sheetTotal(rows), 0);
    final text = buildPersonStatement({'name': 'Ana'}, rows, asOf: asOf);
    expect(text, contains('FULLY PAID'));
  });
}
