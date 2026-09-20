import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/card_cycle.dart';
import 'package:salapify/core/money/reminders.dart' show daysUntil;
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

/// Where a credit card sits in its billing cycle.
///
/// The dates are read by the reminder tray's own parser, so most of what
/// could go wrong with reading a date is already pinned in
/// reminders_test.dart. What is pinned HERE is the two things this module
/// adds: which statement a due date belongs to, and the calendar arithmetic
/// the prototype does on 30 day months.
void main() {
  // A Saturday in a 30 day month, chosen so that the 31st does not exist and
  // the clamping rule has something to bite on.
  final DateTime now = DateTime(2026, 9, 19, 12, 0);

  Account card({String? cutoff, String? due, double balance = 4200}) => Account(
    id: 'c1',
    name: 'BPI Rewards',
    kind: AccountKind.credit,
    institution: 'BPI',
    balance: balance,
    monogram: 'BPI',
    dueDate: due,
    statementDate: cutoff,
  );

  group('reading the two dates', () {
    test('a card with both dates knows both counts', () {
      final CardCycle c = cardCycleFor(
        card(cutoff: '23', due: '2026-10-07'),
        now,
      );
      expect(c.daysToCutoff, 4);
      expect(c.daysToDue, 18);
      expect(c.isKnown, isTrue);
    });

    test('a date nothing can read is NULL, never a guess', () {
      // The field is free text on purpose, so "last working day" is a thing
      // somebody will type. A guess here would be drawn next to a real
      // balance and read as this card's actual cutoff.
      final CardCycle c = cardCycleFor(
        card(cutoff: 'last working day', due: 'when I get paid'),
        now,
      );
      expect(c.daysToCutoff, isNull);
      expect(c.daysToDue, isNull);
      expect(c.isKnown, isFalse);
    });

    test('one readable date is still worth something', () {
      final CardCycle c = cardCycleFor(card(due: '23'), now);
      expect(c.knowsCutoff, isFalse);
      expect(c.knowsDue, isTrue);
      expect(c.isKnown, isTrue);
    });

    test('anything that is not a credit card has no cycle at all', () {
      // A savings account has no statement and a loan instalment is not a
      // cycle. Giving either one this strip would imply a float that does
      // not exist.
      for (final AccountKind k in <AccountKind>[
        AccountKind.bank,
        AccountKind.loan,
        AccountKind.mortgage,
        AccountKind.gcash,
      ]) {
        final CardCycle c = cardCycleFor(
          Account(
            id: 'x',
            name: 'x',
            kind: k,
            institution: 'BPI',
            balance: 1000,
            monogram: 'X',
            dueDate: '23',
            statementDate: '10',
          ),
          now,
        );
        expect(c.isKnown, isFalse, reason: '$k was given a billing cycle');
      }
    });
  });

  group('which statement the coming payment belongs to', () {
    test(
      'a due date AFTER the cutoff is the statement still being written',
      () {
        // Cutoff in 4 days, due in 18. The bill closing on the 23rd is the one
        // payable on the 7th, so today's spending is on it.
        final CardCycle c = cardCycleFor(
          card(cutoff: '23', due: '2026-10-07'),
          now,
        );
        expect(c.paymentOutstanding, isFalse);
      },
    );

    test('a due date BEFORE the cutoff is a bill already closed', () {
      // Due in 2 days, cutoff in 11. A bill cannot fall due before the month
      // it bills for has been closed, so the payment coming up belongs to
      // last month and today's spending is not on it.
      final CardCycle c = cardCycleFor(
        card(cutoff: '30', due: '2026-09-21'),
        now,
      );
      expect(c.daysToDue, 2);
      expect(c.daysToCutoff, 11);
      expect(c.paymentOutstanding, isTrue);
    });

    test('a cutoff that has ALREADY passed means the bill is closed', () {
      // The case a render caught and no test had. The free text field takes
      // a one-off date as happily as a repeating day, so "Sep 18" read on
      // the 20th is a cutoff two days behind us. The rule used to compare
      // the two counts only, so minus two against thirteen came out as
      // "still open" and the card told somebody today's spending was on a
      // bill the bank had already closed.
      final CardCycle c = cardCycleFor(
        card(cutoff: '2026-09-18', due: '2026-10-03'),
        now,
      );
      expect(c.daysToCutoff, -1);
      expect(c.daysToDue, 14);
      expect(
        c.paymentOutstanding,
        isTrue,
        reason: 'a bill that closed yesterday was called still open',
      );
    });

    test('the same day is treated as NOT outstanding', () {
      // Genuinely ambiguous from two day numbers alone, and the screen
      // resolves an ambiguity by saying less rather than by picking.
      final CardCycle c = cardCycleFor(card(cutoff: '23', due: '23'), now);
      expect(c.daysToCutoff, c.daysToDue);
      expect(c.paymentOutstanding, isFalse);
    });

    test('one date missing means the question cannot be answered', () {
      expect(cardCycleFor(card(due: '23'), now).paymentOutstanding, isFalse);
      expect(cardCycleFor(card(cutoff: '23'), now).paymentOutstanding, isFalse);
    });
  });

  group('late', () {
    test('a due date that has passed reads as late', () {
      final CardCycle c = cardCycleFor(card(due: '2026-09-16'), now);
      expect(c.daysToDue, -3);
      expect(c.isLate, isTrue);
    });

    test('and one still ahead does not', () {
      // The other half. A rule that called everything late would pass the
      // test above and be useless.
      expect(cardCycleFor(card(due: '2026-09-22'), now).isLate, isFalse);
      expect(cardCycleFor(card(due: '2026-09-19'), now).isLate, isFalse);
    });

    test('an unreadable date is not late, it is unknown', () {
      expect(cardCycleFor(card(due: 'whenever'), now).isLate, isFalse);
    });
  });

  group('real months, not 30 day ones', () {
    test('a cutoff on the 31st falls on the 30th in September', () {
      // The prototype does `if (days < 0) days += 30` in three places, and
      // Dart is no safer by default: DateTime(2026, 9, 31) is quietly the
      // 1st of October. A bank closes the month on the last day it HAS,
      // because nothing bills on a day that does not exist.
      final CardCycle c = cardCycleFor(card(cutoff: '31'), now);
      expect(
        c.daysToCutoff,
        11,
        reason: 'the 30th of September is 11 days after the 19th',
      );
    });

    test('and on the 28th in February', () {
      final CardCycle c = cardCycleFor(
        card(cutoff: '31'),
        DateTime(2026, 2, 10, 12),
      );
      expect(
        c.daysToCutoff,
        18,
        reason: '28 February is 18 days after the 10th',
      );
    });

    test('a leap February has a 29th', () {
      final CardCycle c = cardCycleFor(
        card(cutoff: '31'),
        DateTime(2028, 2, 10, 12),
      );
      expect(c.daysToCutoff, 19);
    });

    test('the roll into next month clamps too', () {
      // The 31st of November does not exist either, so a cutoff already past
      // in October must land on the 30th of November, not the 1st of
      // December.
      final CardCycle c = cardCycleFor(
        card(cutoff: '31'),
        DateTime(2026, 11, 30, 12),
      );
      expect(c.daysToCutoff, 0, reason: 'today IS the clamped 30th');
    });

    test('December rolls into January without losing a year', () {
      final CardCycle c = cardCycleFor(
        card(cutoff: '5'),
        DateTime(2026, 12, 20, 12),
      );
      expect(c.daysToCutoff, 16, reason: '5 January 2027');
    });
  });

  group('the phrasings people actually write a cutoff in', () {
    // A cutoff IS a repeating day of the month, so these are the natural
    // ways to record one. Every one of them returned null before, which
    // meant no strip and no reminder, silently.
    void reads(String written, int expected) {
      test('"$written"', () {
        expect(daysUntil(written, now), expected);
      });
    }

    reads('10', 21);
    reads('10th', 21);
    reads('the 10th', 21);
    reads('every 10th', 21);
    reads('10th of the month', 21);
    reads('the 10th of each month', 21);
    reads('10 of every month', 21);

    test('a sentence that is not a day is still unreadable', () {
      // The other half of the alarm. Widening a regex until everything
      // matches is how a parser starts inventing dates.
      for (final String s in <String>[
        'end of the month',
        'the month',
        'every payday',
        '10th of the quarter',
        'month',
      ]) {
        expect(daysUntil(s, now), isNull, reason: s);
      }
    });
  });

  group('the sample card the app actually ships', () {
    test('its stored cutoff is readable, and its due date too', () {
      // "10th of the month" is what seed_data.dart writes, and nothing in
      // the app could read it: Salapify shipped a fixture its own parser
      // returned null for, so the one card on a new phone was the one card
      // that could never show this.
      final Account seeded = SeedData.accounts.firstWhere(
        (Account a) => a.kind == AccountKind.credit,
      );
      final CardCycle c = cardCycleFor(seeded, now);
      expect(c.knowsCutoff, isTrue, reason: seeded.statementDate ?? 'null');
      expect(c.knowsDue, isTrue, reason: seeded.dueDate ?? 'null');
      expect(c.daysToCutoff, 21, reason: '10 October');
      expect(c.daysToDue, 14, reason: 'Oct 3');
      expect(
        c.paymentOutstanding,
        isTrue,
        reason: 'the 3rd is paid before the 10th closes the next bill',
      );
    });
  });

  group('how a count reads in a sentence', () {
    test('the near days get words, not numbers', () {
      expect(inDaysPhrase(0), 'today');
      expect(inDaysPhrase(1), 'tomorrow');
      expect(inDaysPhrase(-1), 'yesterday');
    });

    test('and the rest get numbers', () {
      expect(inDaysPhrase(4), 'in 4 days');
      expect(inDaysPhrase(-3), '3 days ago');
    });
  });
}
