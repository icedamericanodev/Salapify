import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/debt.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

/// Golden vectors for the debt payment port.
///
/// Every figure below was PRINTED by running the prototype's own reducers
/// over the prototype's own seeded debts, via app/tool/gen_debt_vectors.ts
/// under bun. None of it was worked out by hand.
///
/// ONE DIVERGENCE is asserted rather than hidden, and it is marked where it
/// occurs: see "an already settled debt keeps the day it was settled".
void main() {
  final DateTime today = DateTime(2026, 9, 18);

  Debt of(List<Debt> list, String id) =>
      list.firstWhere((Debt d) => d.id == id);

  List<Debt> pay(String id, double amount) =>
      applyDebtPayment(SeedData.debts, id, amount, today: today);

  group('applyDebtPayment matches the prototype', () {
    test('a part payment on an instalment debt advances the counter', () {
      final Debt d = of(pay('debt_homecredit', 2450), 'debt_homecredit');
      expect(d.paidAmount, 9800);
      expect(d.isSettled, isFalse);
      expect(d.settledDate, isNull);
      expect(
        d.installmentCurrent,
        4,
        reason: 'it was 3 of 6, and a payment is a payment',
      );
    });

    test('paying exactly what is left settles it and stamps the day', () {
      final Debt d = of(pay('debt_homecredit', 7350), 'debt_homecredit');
      expect(d.paidAmount, 14700);
      expect(d.isSettled, isTrue);
      expect(d.settledDate, '2026-09-18');
    });

    test('an overpayment is NOT capped, so it stays visible', () {
      final Debt d = of(pay('debt_homecredit', 10000), 'debt_homecredit');
      expect(
        d.paidAmount,
        17350,
        reason:
            'The prototype does not clamp this, and neither do we. '
            'Swallowing 2,650 to make the row look tidy hides a real '
            'overpayment from the only person who could correct it.',
      );
      expect(d.isSettled, isTrue);
      // But the PROGRESS bar is clamped, or it would draw past its own track.
      expect(d.progress, 1.0);
    });

    test('a flexible receivable has no counter to advance', () {
      final Debt d = of(pay('debt_kuya_mark', 1500), 'debt_kuya_mark');
      expect(d.paidAmount, 1500);
      expect(d.isSettled, isFalse);
      expect(
        d.installmentCurrent,
        isNull,
        reason:
            'null must stay null. The prototype only increments a counter '
            'that already exists, and inventing "1 of 12" for a pahiram from '
            'a friend would put a schedule on a favour.',
      );
    });

    test('collecting a receivable in full settles it', () {
      final Debt d = of(pay('debt_sarah', 1250), 'debt_sarah');
      expect(d.paidAmount, 1250);
      expect(d.isSettled, isTrue);
      expect(d.settledDate, '2026-09-18');
    });

    test('the instalment counter never passes its total', () {
      final Debt d = of(pay('debt_bpi_loan', 10000), 'debt_bpi_loan');
      expect(d.installmentCurrent, 3);
      expect(d.installmentTotal, 6);
      expect(d.installmentCurrent!, lessThanOrEqualTo(d.installmentTotal!));
    });

    test('a zero or negative payment changes nothing at all', () {
      expect(identical(pay('debt_homecredit', 0), SeedData.debts), isTrue);
      expect(identical(pay('debt_homecredit', -500), SeedData.debts), isTrue);
    });

    test('no other debt is touched', () {
      final List<Debt> after = pay('debt_homecredit', 2450);
      for (final Debt d in SeedData.debts) {
        if (d.id == 'debt_homecredit') continue;
        final Debt now = of(after, d.id);
        expect(now.paidAmount, d.paidAmount, reason: '${d.id} moved');
        expect(now.isSettled, d.isSettled, reason: '${d.id} changed status');
      }
    });

    // THE ONE DIVERGENCE FROM THE PROTOTYPE, asserted here so it is a measured
    // difference rather than an accident.
    //
    // The prototype writes `settledDate: isSettled ? TODAY : d.settledDate`.
    // On a debt that is ALREADY settled, isSettled stays true, so a stray
    // payment restamps the date: the generator printed 2026-09-18 for a debt
    // the seed says was settled on Sep 3.
    //
    // That is a loss of history on a row whose entire job is to record when
    // something was cleared. Salapify keeps the original date. No live figure
    // moves either way, and the debt's money behaviour is identical; only the
    // date differs, and only on a debt that was already at zero.
    test('an already settled debt keeps the day it was settled', () {
      final Debt d = of(pay('debt_mom_settled', 500), 'debt_mom_settled');
      expect(d.paidAmount, 2500, reason: 'the money still moves, as it must');
      expect(d.isSettled, isTrue);
      expect(
        d.settledDate,
        'Sep 3',
        reason:
            'The prototype would rewrite this to 2026-09-18. A debt '
            'cleared in September did not become cleared today because a '
            'stray payment landed on it.',
      );
    });
  });

  group('toggleDebtSettled matches the prototype', () {
    test('settling fills the paid amount to the total', () {
      final Debt d = of(
        toggleDebtSettled(SeedData.debts, 'debt_homecredit', today: today),
        'debt_homecredit',
      );
      expect(
        d.paidAmount,
        14700,
        reason:
            'otherwise the row reads "settled" and "still owes 7,350" at '
            'the same time, and one of them is a lie',
      );
      expect(d.isSettled, isTrue);
      expect(d.settledDate, '2026-09-18');
    });

    test('un-settling clears the flag and the date', () {
      final Debt d = of(
        toggleDebtSettled(SeedData.debts, 'debt_mom_settled', today: today),
        'debt_mom_settled',
      );
      expect(d.isSettled, isFalse);
      expect(d.settledDate, isNull);
      expect(d.paidAmount, 2000);
    });

    test('settling then un-settling leaves the money paid, not wound back', () {
      final List<Debt> once = toggleDebtSettled(
        SeedData.debts,
        'debt_homecredit',
        today: today,
      );
      final Debt d = of(
        toggleDebtSettled(once, 'debt_homecredit', today: today),
        'debt_homecredit',
      );
      expect(d.isSettled, isFalse);
      expect(d.settledDate, isNull);
      expect(
        d.paidAmount,
        14700,
        reason:
            'The prototype leaves it at the total and so do we. Winding '
            'it back to 7,350 would invent a figure nobody paid; the wrong '
            'flag is the smaller error and the one the user can see.',
      );
    });
  });

  group('the ledger entry a payment writes', () {
    test('paying somebody is an expense, filed where Budgets can see it', () {
      final Transaction? t = paymentEntry(
        debt: of(SeedData.debts, 'debt_homecredit'),
        amount: 2450,
        accountId: 'acc_gcash',
        today: today,
        id: 'tx_test',
      );

      expect(t, isNotNull);
      expect(t!.type, TransactionType.expense);
      expect(t.amount, 2450);
      expect(t.category, 'Debt & Loan Servicing');
      expect(t.subcategory, 'Personal Loan Installment');
      expect(t.accountId, 'acc_gcash');
      expect(t.date, '2026-09-18');
      expect(t.merchant, 'Repayment to Home Credit (Phone)');
      expect(t.tags, contains('#debt-payment'));

      // The category has to EXIST, or the entry files itself under a name
      // Budgets and Reports do not recognise and the money vanishes from
      // every summary while sitting perfectly in the ledger.
      expect(
        SeedData.categories.map((CategoryInfo c) => c.name),
        contains(t.category),
      );
    });

    test('being repaid is income, with its own category', () {
      final Transaction? t = paymentEntry(
        debt: of(SeedData.debts, 'debt_kuya_mark'),
        amount: 1500,
        accountId: 'acc_gcash',
        today: today,
        id: 'tx_test',
      );

      expect(t!.type, TransactionType.income);
      expect(t.category, 'Receivables & Repayments');
      expect(t.subcategory, 'Pahiram Repayment Collected');
      expect(t.merchant, 'Repayment from Kuya Mark');
      expect(
        SeedData.categories.map((CategoryInfo c) => c.name),
        contains(t.category),
      );
    });

    test('no account means no entry, rather than an entry from nowhere', () {
      expect(
        paymentEntry(
          debt: of(SeedData.debts, 'debt_kuya_mark'),
          amount: 1500,
          accountId: null,
          today: today,
          id: 'tx_test',
        ),
        isNull,
        reason:
            'An entry with no account cannot move a balance and cannot be '
            'reconciled. Recording the debt alone is the honest outcome.',
      );
    });
  });

  group('the register totals', () {
    test('outstanding counts only open debts, in one direction', () {
      expect(outstanding(SeedData.debts, DebtDirection.iOwe), 17350);
      expect(outstanding(SeedData.debts, DebtDirection.owedToMe), 6250);
    });

    test('the settled Mom debt is excluded from what you owe', () {
      // 14,700 - 7,350 plus 15,000 - 5,000 is 17,350. Mom's 2,000 is settled
      // and must not be in there.
      expect(outstanding(SeedData.debts, DebtDirection.iOwe), isNot(19350));
    });

    test('the beam splits the way the prototype splits it', () {
      final ({double owedToMe, double youOwe}) b = beamSplit(SeedData.debts);
      expect(b.owedToMe, closeTo(26.48305084745763, 1e-9));
      expect(b.youOwe, closeTo(73.51694915254237, 1e-9));
    });

    test('the beam never lets either side vanish', () {
      final List<Debt> lopsided = <Debt>[
        const Debt(
          id: 'a',
          person: 'Bank',
          direction: DebtDirection.iOwe,
          totalAmount: 1000000,
          paidAmount: 0,
          isSettled: false,
        ),
        const Debt(
          id: 'b',
          person: 'Friend',
          direction: DebtDirection.owedToMe,
          totalAmount: 50,
          paidAmount: 0,
          isSettled: false,
        ),
      ];
      final ({double owedToMe, double youOwe}) b = beamSplit(lopsided);
      expect(b.owedToMe, 10);
      expect(
        b.youOwe,
        90,
        reason:
            'Clamped at 10 and 90, the prototype\'s own rule, so the beam '
            'is an illustration and the figures beside it are the truth.',
      );
    });

    test('an empty register splits evenly rather than dividing by zero', () {
      final ({double owedToMe, double youOwe}) b = beamSplit(<Debt>[]);
      expect(b.owedToMe, 50);
      expect(b.youOwe, 50);
    });
  });

  group('splitting by status', () {
    test('open first, settled kept rather than hidden', () {
      final ({List<Debt> open, List<Debt> settled}) s = splitByStatus(
        SeedData.debts,
        DebtDirection.iOwe,
      );
      expect(s.open.map((Debt d) => d.id), <String>[
        'debt_homecredit',
        'debt_bpi_loan',
      ]);
      expect(
        s.settled.map((Debt d) => d.id),
        <String>['debt_mom_settled'],
        reason:
            'A cleared debt is the only evidence a person has that they '
            'cleared it. A register that forgets is one nobody trusts.',
      );
    });
  });

  group('reading an amount', () {
    test('accepts what a person actually types', () {
      expect(parseDebtAmount('1,500'), 1500);
      expect(parseDebtAmount(' 250.75 '), 250.75);
    });

    test('refuses nothing, zero and negatives', () {
      expect(parseDebtAmount(''), isNull);
      expect(parseDebtAmount('0'), isNull);
      expect(parseDebtAmount('-100'), isNull);
      expect(parseDebtAmount('abc'), isNull);
    });
  });
}
