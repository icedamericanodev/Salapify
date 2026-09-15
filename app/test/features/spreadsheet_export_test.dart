// The spreadsheet export, and the one commercial-grade trap in writing CSV.
//
// A CSV is not a backup and never claims to be, so there is no round trip to
// verify. What there IS to get wrong is escaping, and getting it wrong does not
// look like a bug: it looks like the app reported the wrong number.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/features/settings/spreadsheet_export.dart';

import '../support/memory_store.dart';

void main() {
  test('every entry is a row, newest first, with a header', () {
    final data = livedIn();
    final lines = transactionsCsv(data).trim().split('\n');

    expect(lines.first, 'Date,Type,Label,Amount,Account,Note');

    final entries = (data['transactions'] as List).length;
    expect(
      entries,
      greaterThan(0),
      reason: 'the fixture has no entries, so this test cannot see anything',
    );
    expect(lines.length, entries + 1, reason: 'a row went missing, or doubled');

    // Newest first, so the dates descend.
    final dates = [for (final l in lines.skip(1)) l.split(',').first];
    final sorted = [...dates]..sort((a, b) => b.compareTo(a));
    expect(dates, sorted, reason: 'the rows came out in an arbitrary order');
  });

  test('a comma in a label cannot shift every column after it', () {
    // THE TRAP, and it is not cosmetic. Filipino money labels carry commas
    // constantly. An unquoted one silently moves the amount into the account
    // column and the account into the note, so a spreadsheet shows the wrong
    // figure against the wrong account, and it reads as the APP having got the
    // number wrong rather than as a formatting fault.
    final data = livedIn();
    data['transactions'] = [
      {
        'id': 't_comma',
        'type': 'expense',
        'label': 'Lola, paid back',
        'amount': 1250.0,
        'date': '2026-09-11',
        'accountId': 'a_bpi',
      },
    ];

    final row = transactionsCsv(data).trim().split('\n')[1];
    expect(row, contains('"Lola, paid back"'));

    // And the column count is still right, which is what the quoting is FOR.
    // Counting on a naive split would not prove it, so the quoted field is
    // removed first and the rest counted.
    final rest = row.replaceAll('"Lola, paid back"', 'LABEL');
    expect(
      rest.split(',').length,
      6,
      reason:
          'the row has the wrong number of columns, so every value after the '
          'label landed under the wrong heading',
    );
  });

  test('a quote and a newline survive too', () {
    final data = livedIn();
    data['transactions'] = [
      {
        'id': 't_q',
        'type': 'expense',
        'label': 'Said "yes"',
        'amount': 10.0,
        'date': '2026-09-11',
        'note': 'line one\nline two',
      },
    ];
    final csv = transactionsCsv(data);
    // RFC 4180 doubles an embedded quote.
    expect(csv, contains('"Said ""yes"""'));
    expect(csv, contains('"line one\nline two"'));
  });

  test('the amount is a NUMBER, so a spreadsheet can add it up', () {
    // "PHP1,250.00" is text. A column of text sums to zero, which makes the
    // export useless for the one thing somebody opens a spreadsheet to do.
    final data = livedIn();
    data['transactions'] = [
      {
        'id': 't1',
        'type': 'expense',
        'label': 'Groceries',
        'amount': 1250.5,
        'date': '2026-09-11',
      },
    ];
    final row = transactionsCsv(data).trim().split('\n')[1];
    expect(row.split(',')[3], '1250.5');
    expect(row, isNot(contains('₱')));
  });

  test('the file is named entries, never backup', () {
    // The name is the last thing somebody sees months later when deciding
    // which file to trust. A CSV called "backup" would be a lie told at
    // exactly the wrong moment.
    final name = csvFileName(DateTime(2026, 9, 15));
    expect(name, 'salapify-entries-2026-09-15.csv');
    expect(name, isNot(contains('backup')));
  });
}
