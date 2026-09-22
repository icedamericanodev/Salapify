import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/bir_claims.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

/// What a person could put in front of the BIR, out of what they logged.
void main() {
  int seq = 0;
  Transaction tx({
    double amount = 1000,
    String category = 'Food & Dining',
    bool deductible = false,
    String? ref,
    String? attachment,
    List<String> tags = const <String>[],
    TransactionType type = TransactionType.expense,
    TransactionStatus status = TransactionStatus.confirmed,
  }) => Transaction(
    id: 'tx${seq++}',
    type: type,
    amount: amount,
    category: category,
    accountId: 'acc',
    date: '2026-09-20',
    createdAt: 1758326400000,
    status: status,
    tags: tags,
    isTaxDeductible: deductible,
    taxTinOrRef: ref,
    attachmentPath: attachment,
  );

  group('what counts as claimable', () {
    test('a row the person ticked', () {
      expect(isClaimable(tx(deductible: true)), isTrue);
    });

    test('a row filed under the business category', () {
      expect(isClaimable(tx(category: businessCategory)), isTrue);
    });

    test('and the business category is the one the app ACTUALLY has', () {
      // The spec tests `t.category == 'Business'`. Salapify's category is
      // 'Business & Freelance Ops', so the spec's test matches nothing and
      // the entire business half of this feature would be silently empty
      // with no error anywhere. Third time the spec's category vocabulary
      // has differed from the app's.
      expect(
        SeedData.categories.map((CategoryInfo c) => c.name),
        contains(businessCategory),
        reason: 'the claimable filter points at a category that does not exist',
      );
    });

    test('a row carrying the tag', () {
      expect(isClaimable(tx(tags: <String>[claimableTag])), isTrue);
    });

    test('an ordinary expense is NOT', () {
      // The other half. A filter that returned everything would pass all
      // three tests above and would put somebody's groceries in a BIR claim.
      expect(isClaimable(tx()), isFalse);
    });

    test('income is never claimable, however it is marked', () {
      expect(
        isClaimable(tx(type: TransactionType.income, deductible: true)),
        isFalse,
        reason: 'money coming IN was offered as a deduction',
      );
    });

    test('an excluded or duplicate row is not claimable', () {
      // These are already out of every total on every other screen. A
      // duplicate counted here would be a claim made twice.
      expect(
        isClaimable(tx(deductible: true, status: TransactionStatus.duplicate)),
        isFalse,
      );
      expect(
        isClaimable(tx(deductible: true, status: TransactionStatus.excluded)),
        isFalse,
      );
    });
  });

  group('substantiated means there is something behind it', () {
    test('a reference number counts', () {
      expect(isSubstantiated(tx(deductible: true, ref: 'OR-00184')), isTrue);
    });

    test('an attached receipt image counts', () {
      expect(
        isSubstantiated(tx(deductible: true, attachment: 'attachments/a.jpg')),
        isTrue,
      );
    });

    test('a tick on its own does NOT', () {
      // The spec's own metric is called "Substantiated Receipts Count" and
      // computes deductibleTransactions.length, which counts this row. The
      // number exists to tell somebody how much of their claim they could
      // defend, so counting an unsupported claim is the worst possible
      // direction to be wrong in.
      expect(isSubstantiated(tx(deductible: true)), isFalse);
    });

    test('an empty reference is not a reference', () {
      expect(isSubstantiated(tx(deductible: true, ref: '   ')), isFalse);
    });
  });

  group('the totals', () {
    final List<Transaction> ledger = <Transaction>[
      tx(amount: 1200, deductible: true, ref: 'OR-1'),
      tx(amount: 800, category: businessCategory, attachment: 'a/b.jpg'),
      tx(amount: 500, deductible: true),
      tx(amount: 300, tags: <String>[claimableTag]),
      tx(amount: 9999),
      tx(amount: 4000, type: TransactionType.income, deductible: true),
    ];
    final BirClaimSummary s = summariseClaims(ledger);

    test('only the claimable rows are counted', () {
      expect(s.count, 4);
      expect(s.totalClaimable, 2800);
    });

    test('the split between supported and unsupported is exact', () {
      expect(s.substantiated, 2);
      expect(s.substantiatedAmount, 2000);
      expect(s.unsupported, 2);
      expect(s.unsupportedAmount, 800);
      expect(
        s.substantiatedAmount + s.unsupportedAmount,
        s.totalClaimable,
        reason: 'the two halves must add back to the whole',
      );
      expect(s.substantiated + s.unsupported, s.count);
    });

    test('an empty ledger is empty, not zero-ish', () {
      final BirClaimSummary e = summariseClaims(const <Transaction>[]);
      expect(e.any, isFalse);
      expect(e.count, 0);
      expect(e.totalClaimable, 0);
    });
  });

  group('the tax shield', () {
    final BirClaimSummary s = summariseClaims(<Transaction>[
      tx(amount: 10000, deductible: true, ref: 'OR-1'),
      tx(amount: 5000, deductible: true),
    ]);

    test('it is computed on what could be DEFENDED, not on the total', () {
      // Quoting a saving on claims with no receipt behind them is quoting a
      // saving that gets disallowed.
      expect(s.totalClaimable, 15000);
      expect(s.taxShieldAt(0.20), 2000, reason: '20% of the supported 10,000');
    });

    test('a zero bracket shields nothing', () {
      // Somebody under the 250,000 exemption saves nothing at all. Telling
      // them a quarter of their receipts is coming back is telling them
      // money is arriving that is not.
      expect(s.taxShieldAt(0), 0);
    });

    test('a negative rate cannot produce a negative shield', () {
      expect(s.taxShieldAt(-0.2), 0);
    });

    test('there is NO default rate', () {
      // The spec asks for a flat 25 percent. Under the 8 percent election
      // there are no itemised deductions at all and the shield is zero;
      // under the OSD it is 40 percent of gross whatever the receipts say.
      // A default is how a made-up rate reaches a screen with a peso sign
      // in front of it, so the caller has to name one.
      //
      // This is a COMPILE-TIME promise and the test states it so a later
      // change that adds a default has to delete this test on purpose.
      expect(
        () => s.taxShieldAt(0.25),
        returnsNormally,
        reason: 'the rate is an argument, never an assumption',
      );
    });
  });

  group('the brackets match the app\'s own tax engine', () {
    test('six graduated rates, and they are the TRAIN table', () {
      expect(
        graduatedBrackets.map((({String label, double rate}) b) => b.rate),
        <double>[0.0, 0.15, 0.20, 0.25, 0.30, 0.35],
      );
    });

    test('every bracket names its band, so no rate is offered bare', () {
      for (final ({String label, double rate}) b in graduatedBrackets) {
        expect(b.label, isNotEmpty);
        expect(
          b.label.contains('₱'),
          isTrue,
          reason:
              'a rate with no band beside it is a rate somebody applies to '
              'themselves without knowing whether it is theirs',
        );
      }
    });
  });
}
