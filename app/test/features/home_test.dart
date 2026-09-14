// What Home decides, tested without pumping a widget.
//
// Home is the first screen whose content depends on the DATE as well as the
// ledger, so every case here fixes "now" rather than reading the clock. A test
// that passes only on the days somebody happened to run it is not a test.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/commitments.dart' show safeToSpend;
import 'package:salapify/features/home/home_screen.dart';
import 'package:salapify/features/ledger/entry_presentation.dart';

import '../support/memory_store.dart';

/// The same moment the render harness pins. Four days before payday, with both
/// recurring bills inside the cycle.
final _now = DateTime(2026, 9, 11, 9, 30);

void main() {
  group('safe to spend, as the screen reads it', () {
    test('savings are protected, so they are not in the figure', () {
      final s = safeToSpend(livedIn(), _now);

      // GCash 8,410.50 plus Cash 1,250. BPI is a SAVINGS account and the
      // engine's liquidKinds is cash, ewallet, checking on purpose: "the whole
      // point of safe to spend is to protect them". A screen that added the
      // 42,300 here would be telling somebody to spend their savings.
      expect(s['liquid'], 9660.50);

      // Meralco 3,200 plus Spotify 194, both due before payday.
      expect(s['committed'], 3394.00);
      expect(s['available'], 6266.50);
      expect(s['daysLeft'], 4);
    });

    test('the pesos and the centavos are split from the formatter, not maths', () {
      // Both halves come from formatMoney, so the grouping and rounding match
      // every other screen. Computing the pesos separately would be a second
      // money rule living on one screen.
      expect(wholePesos(6266.50), '6,266');
      expect(centsOf(6266.50), '.50');

      // A whole figure has no cents part at all rather than a bare ".00".
      expect(wholePesos(6000), '6,000');
      expect(centsOf(6000), '');
    });

    test('a negative figure keeps its minus, for the panel to place', () {
      // The panel draws the peso sign separately from the digits, so the whole
      // part arrives carrying the minus and the panel has to put it BEFORE the
      // sign. Drawn naively this read "₱-2,394", which is not how money is
      // written anywhere, on the one figure the screen exists to show.
      expect(wholePesos(-2394), '-2,394');
      expect(centsOf(-2394.50), '.50');
    });
  });

  group('what is coming', () {
    test('bills before payday, and nothing after it', () {
      final bills = upcomingBills(livedIn(), _now);
      expect(bills.map((b) => b['name']), ['Meralco', 'Spotify']);

      // Lola is due the 18th and the card the 3rd of next month, both AFTER
      // payday on the 15th. They are real debts and they are correctly absent:
      // this cycle's money does not have to cover them.
      expect(bills.map((b) => b['name']), isNot(contains('Lola')));
    });

    test('the next debt payment looks PAST payday, which the bill list does not', () {
      // The debt card's job is to name the next payment even when it lands
      // after payday. A card that goes quiet because the bill is a week out is
      // a card that goes quiet exactly when somebody is planning.
      final next = nextDebtPayment(livedIn(), _now);
      expect(next, isNotNull);
      expect(next!['name'], 'Lola');
      expect(next['when'], 'Sep 18');

      // The MINIMUM, never the balance. Lola's remaining is 6,000.
      expect(next['amount'], 1500.00);
    });

    test('no debts scheduled means no line rather than an empty one', () {
      expect(nextDebtPayment(const {}, _now), isNull);
    });
  });

  group('dates a person can read', () {
    test('a due date is today, tomorrow, a weekday, or a date', () {
      // A date the reader has to subtract from today is a date they do not
      // read.
      expect(dueWhen('2026-09-11', _now), 'today');
      expect(dueWhen('2026-09-12', _now), 'tomorrow');
      expect(dueWhen('2026-09-13', _now), 'Sunday');
      expect(dueWhen('2026-09-30', _now), 'Sep 30');
    });

    test('a missing or malformed date says nothing rather than crashing', () {
      expect(dueWhen(null, _now), '');
      expect(dueWhen('not a date', _now), '');
      expect(dueWhen('2026-09', _now), '');
    });

    test('a payday past this week is a DATE, never a weekday name', () {
      // A weekday name is only unambiguous inside a week. The hero sentence
      // used one for any payday at all, so a monthly schedule produced "payday
      // on Friday" for a payday twenty nine days out, four lines above a rail
      // truthfully saying "29 days to payday".
      expect(paydayWhen(DateTime(2026, 10, 30), DateTime(2026, 10, 1)), 'on Oct 30');

      // Inside the week the name is the friendlier form, and it is exactly the
      // rule dueWhen already used one function away.
      expect(paydayWhen(DateTime(2026, 9, 15), DateTime(2026, 9, 11)), 'on Tuesday');
      expect(paydayWhen(DateTime(2026, 9, 12), DateTime(2026, 9, 11)), 'tomorrow');
      expect(paydayWhen(DateTime(2026, 9, 11), DateTime(2026, 9, 11)), 'today');

      // Seven days out is the same weekday as today, so it has to be a date.
      expect(paydayWhen(DateTime(2026, 9, 18), DateTime(2026, 9, 11)), 'on Sep 18');
    });

    test('the top line names the day', () {
      expect(longDay(_now), 'Friday, Sep 11');
      expect(shortDay(DateTime(2026, 9, 15)), 'Tuesday');
      expect(shortDate(DateTime(2026, 8, 30)), 'Aug 30');
    });
  });

  group('latest', () {
    test('newest first, and capped', () {
      final rows = latestEntries(livedIn());
      expect(rows.length, latestCount);

      // Stored dates are yyyy-mm-dd, so a string sort IS a date sort.
      final dates = rows.map((t) => t['date'] as String).toList();
      final sorted = [...dates]..sort((a, b) => b.compareTo(a));
      expect(dates, sorted);
    });

    test('an empty ledger is empty, not an error', () {
      expect(latestEntries(const {}), isEmpty);
    });

    test('entries logged on the SAME day come back newest first', () {
      // The defect this guards shipped past eleven tests. A stored date has no
      // time in it, so everything logged today ties, List.sort is not stable,
      // and sorting on the date alone returned the five OLDEST entries of the
      // day under a heading that says "Latest". The entry somebody had just
      // saved was the one guaranteed to be missing.
      //
      // Twelve rows, deliberately past the eight where Dart's sort stops being
      // an insertion sort and the tie order goes arbitrary.
      final data = {
        'transactions': [
          for (var i = 1; i <= 12; i++)
            {'id': 't$i', 'label': 'Entry $i', 'amount': i, 'date': '2026-09-11'},
        ],
      };

      final rows = latestEntries(data);
      expect(rows.map((t) => t['label']), [
        'Entry 12',
        'Entry 11',
        'Entry 10',
        'Entry 9',
        'Entry 8',
      ]);
    });

    test('the caption never just repeats the title', () {
      // The render showed a row titled "Load" captioned "Load, GCash". A
      // caption is there to add what the title does not carry, and PH money
      // labels collide with category names constantly, so this is the common
      // case: Load, Groceries, Rent, Sweldo.
      final data = livedIn();
      final load = latestEntries(data).firstWhere((t) => t['label'] == 'Load');
      expect(entrySubtitle(data, load), 'GCash');

      // A category that says something the title does not still shows: the
      // rule drops a REPEAT, never the category itself.
      final jollibee = (data['transactions'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((t) => t['label'] == 'Jollibee');
      expect(entrySubtitle(data, jollibee), 'Food, GCash');
    });
  });
}
