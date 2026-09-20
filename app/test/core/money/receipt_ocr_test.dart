import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/receipt_ocr.dart';
import 'package:salapify/core/money/receipt_samples.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

/// Reading a Philippine receipt out of recognised text.
///
/// The hard part of a receipt is not finding a number, it is finding the
/// RIGHT number. A thermal slip prints the change, the cash tendered, the
/// subtotal and the VAT, and on a 213 peso purchase paid with a 500 the two
/// largest figures on the paper are both wrong.
void main() {
  ReceiptOcrResult sample(String label) => parseReceiptText(
    receiptSamples.firstWhere((ReceiptSample s) => s.label == label).text,
  );

  group('the amount, and not the other numbers', () {
    test('the total wins over cash tendered and sukli', () {
      // The Jollibee slip shows TOTAL 213.00, CASH TENDERED 500.00 and SUKLI
      // 287.00. Both distractors are larger, so a "take the biggest" reader
      // gets this wrong twice over.
      expect(sample('Jollibee').amount, 213.00);
    });

    test('a grocery total wins over CHANGE and matching SUBTOTAL', () {
      expect(sample('Puregold').amount, 1153.50);
    });

    test('"AMOUNT DUE" counts as a total', () {
      expect(sample('7-Eleven').amount, 145.00);
    });

    test('a thousands comma is read, not truncated', () {
      expect(sample('GCash send').amount, 2500.00);
    });

    test('a total wins over the fare lines that sum to it', () {
      expect(sample('GrabCar').amount, 280.00);
    });

    // THE TWO BELOW EXIST BECAUSE THE SIX ABOVE WERE HOLLOW.
    //
    // Deleting the disqualifier check from the parser left every one of them
    // green. The reason is that none of them ever reached it: "subtotal" does
    // not match `\btotal\b` (no word boundary inside the word), and "CASH
    // 2000.00" does not match the labelled pattern at all, so the real total
    // was found by the first branch every time and the guard was never asked
    // a question. Its LINE was covered the whole time; the condition coming
    // out true never was, and coverage counts lines.
    //
    // These two put a disqualified line where it will be matched FIRST.

    test('"SUB TOTAL" spelled as two words is not the total', () {
      // The one spelling that genuinely reaches the first branch's guard.
      // "subtotal" as one word cannot match `\btotal\b` at all, so the
      // Puregold sample never exercised it; "SUB TOTAL" does match, and
      // arrives first, so without the guard the reader returns the figure
      // from before the discount and the person logs 100 pesos too much.
      final ReceiptOcrResult r = parseReceiptText(
        'PUREGOLD\n'
        'SUB TOTAL          1153.50\n'
        'Senior discount     100.00\n'
        'TOTAL              1053.50\n'
        '2026-09-20',
      );
      expect(r.amount, 1053.50);
    });

    test('with no total label at all, cash tendered is still ignored', () {
      // This reaches the SECOND branch, the largest-amount fallback, which
      // the prototype uses unguarded. 500 is the biggest number on the paper
      // and it is what the customer handed over, not what they spent.
      final ReceiptOcrResult r = parseReceiptText(
        'SARI SARI STORE\n'
        'Item one           PHP 120.00\n'
        'Item two            PHP 93.00\n'
        'PHP 213.00\n'
        'CASH TENDERED      PHP 500.00\n'
        'SUKLI              PHP 287.00',
      );
      expect(
        r.amount,
        213.00,
        reason: 'the fallback took the cash handed over, or the change',
      );
    });

    test('the fallback never invents a total by adding the items up', () {
      // Where the paper carries no total at all, the largest real amount on
      // it is the answer and it may well be one item. Summing the lines
      // would be a figure that appears nowhere on the receipt, and on a slip
      // where the reader missed a line it would be confidently short.
      final ReceiptOcrResult r = parseReceiptText(
        'SARI SARI STORE\n'
        'Item one           PHP 120.00\n'
        'Item two            PHP 93.00',
      );
      expect(r.amount, 120.00);
      expect(
        r.confidence,
        lessThan(0.7),
        reason: 'a reading this thin must not present itself as certain',
      );
    });

    test('text with no amount at all is not valid, rather than zero', () {
      final ReceiptOcrResult r = parseReceiptText(
        'JOLLIBEE\nThank you for visiting\nPlease come again',
      );
      expect(r.isValid, isFalse);
      expect(r.amount, 0);
    });
  });

  group('the merchant, and the category it brings', () {
    test('a known merchant brings a category the app actually has', () {
      final ReceiptOcrResult r = sample('Jollibee');
      expect(r.merchant, 'Jollibee');
      expect(r.category, 'Food & Dining');
      expect(r.subcategory, 'Fast Food & Karinderya');
      expect(r.categoryMatched, isTrue);
    });

    test('a ride is transport, not food, despite the word grab', () {
      // "grabfood" contains "grab". A delivery filed as a taxi, or a taxi as
      // a delivery, is wrong in the one field somebody would search on.
      final ReceiptOcrResult r = sample('GrabCar');
      expect(r.category, 'Transport & Commute');
      expect(r.subcategory, 'Ride Hailing (Grab/Angkas/Joyride)');
    });

    test('and a GrabFood receipt is food', () {
      final ReceiptOcrResult r = parseReceiptText(
        'GrabFood Order\nTOTAL PHP 480.00\n2026-09-20',
      );
      expect(r.category, 'Food & Dining');
      expect(r.subcategory, 'Food Delivery (Grab/Foodpanda)');
    });

    test('EVERY category and subcategory emitted really exists', () {
      // The defect this exists to stop is already documented in this repo:
      // the prototype files instalment payments under a subcategory missing
      // from its own list, so the money sits perfectly in the ledger and
      // vanishes from every summary that reads it. The spec for this feature
      // names "Transportation", "Healthcare" and "Shopping", none of which
      // Salapify has.
      final Map<String, List<String>> known = <String, List<String>>{
        for (final CategoryInfo c in SeedData.categories)
          c.name: c.subcategories,
      };
      for (final ReceiptSample s in receiptSamples) {
        final ReceiptOcrResult r = parseReceiptText(s.text);
        expect(
          known.containsKey(r.category),
          isTrue,
          reason: '${s.label} produced category "${r.category}"',
        );
        expect(
          known[r.category]!.contains(r.subcategory),
          isTrue,
          reason:
              '${s.label} produced subcategory "${r.subcategory}" which is '
              'not under "${r.category}"',
        );
      }
    });

    test('an unknown merchant takes the first real line, capped', () {
      final ReceiptOcrResult r = parseReceiptText(
        'ACME HARDWARE AND CONSTRUCTION SUPPLY INCORPORATED\n'
        'TOTAL PHP 1,240.00\n2026-09-20',
      );
      expect(r.merchant.length, lessThanOrEqualTo(30));
      expect(r.merchant, startsWith('ACME HARDWARE'));
      expect(
        r.categoryMatched,
        isFalse,
        reason: 'an unknown merchant was given a category anyway',
      );
    });

    test('a separator line is never read as the merchant', () {
      final ReceiptOcrResult r = parseReceiptText(
        '====================\n'
        '2026-09-20\n'
        'SUKI STORE\n'
        'TOTAL PHP 90.00',
      );
      expect(r.merchant, 'SUKI STORE');
    });
  });

  group('BIR fields', () {
    test('a TIN is read and the row is suggested as deductible', () {
      final ReceiptOcrResult r = sample('Jollibee');
      expect(r.taxTinOrRef, '000-408-495-000');
      expect(r.isTaxDeductible, isTrue);
      expect(r.kind, ReceiptKind.officialReceipt);
    });

    test('a TIN spaced instead of hyphenated is still read', () {
      final ReceiptOcrResult r = parseReceiptText(
        'SOME STORE\nVAT REG TIN 201 233 000 00000\nTOTAL PHP 100.00',
      );
      expect(r.taxTinOrRef, isNotNull);
      expect(r.isTaxDeductible, isTrue);
    });

    test('a receipt with NO tax markings is not marked deductible', () {
      // The other half of the alarm, and the one that matters: a reader that
      // ticked everything would pass both tests above and would quietly
      // suggest claiming a milk tea.
      final ReceiptOcrResult r = sample('GCash send');
      expect(r.isTaxDeductible, isFalse);
      expect(r.kind, ReceiptKind.ewalletScreenshot);
    });

    test('an e-wallet reference is kept as a reference, not as a TIN', () {
      final ReceiptOcrResult r = sample('GCash send');
      expect(r.taxTinOrRef, '1029384756123');
      expect(r.isTaxDeductible, isFalse);
    });
  });

  group('VAT is read, never derived', () {
    test('the printed VAT line is taken', () {
      expect(sample('Jollibee').vatAmount, 22.82);
    });

    test('a receipt that prints no VAT reports NONE, not 12 percent', () {
      // Twelve percent of the total is not the VAT on a slip that mixes
      // vatable, zero rated and exempt lines, which a grocery run routinely
      // does. A wrong VAT figure on a row somebody claims is worse than no
      // figure at all.
      expect(sample('GCash send').vatAmount, isNull);
      expect(sample('GrabCar').vatAmount, isNull);
    });
  });

  group('the date', () {
    test('an ISO date is read', () {
      final ReceiptOcrResult r = sample('7-Eleven');
      expect(r.dateFound, isTrue);
      expect(r.date, DateTime(2026, 9, 20));
    });

    test('"20 Sep 2026" is read', () {
      expect(sample('Jollibee').date, DateTime(2026, 9, 20));
    });

    test('"Sep 20, 2026" is read', () {
      expect(sample('Mercury Drug').date, DateTime(2026, 9, 20));
    });

    test('a slashed date is read DAY first, the local way', () {
      // 20/09/2026 is unambiguous. The one that matters is that the reader
      // does not silently apply the US order to a Philippine receipt.
      expect(sample('GrabCar').date, DateTime(2026, 9, 20));
    });

    test('an ambiguous slashed date takes the local reading', () {
      final ReceiptOcrResult r = parseReceiptText(
        'STORE\nTOTAL PHP 10.00\n05/09/2026',
      );
      expect(
        r.date,
        DateTime(2026, 9, 5),
        reason: '5 September here, not 9 May',
      );
    });

    test('an impossible date is refused rather than rolled forward', () {
      // DateTime(2026, 2, 31) is quietly the 3rd of March, so one misread
      // digit becomes a confident wrong date.
      final ReceiptOcrResult r = parseReceiptText(
        'STORE\nTOTAL PHP 10.00\n2026-02-31',
      );
      expect(r.dateFound, isFalse);
    });

    test('no date at all says so, rather than printing today as a reading', () {
      final ReceiptOcrResult r = parseReceiptText('STORE\nTOTAL PHP 10.00');
      expect(r.dateFound, isFalse);
      final DateTime now = DateTime.now();
      expect(r.date, DateTime(now.year, now.month, now.day));
    });
  });

  group('the account is a KIND, never an id', () {
    test('a wallet named on the paper suggests that kind', () {
      expect(sample('GCash send').accountKind, AccountKind.gcash);
      expect(sample('GrabCar').accountKind, AccountKind.maya);
    });

    test('a receipt naming no wallet suggests NOTHING', () {
      // The prototype asks for a suggestedAccountId and falls back to
      // accounts[0].id, so a mis-parse writes a real expense against
      // whichever account happens to be first with no signal at all. It
      // cannot happen here by construction: the parser never sees the
      // accounts. This asserts the absence stays an absence.
      expect(sample('Puregold').accountKind, isNull);
    });
  });

  group('line items', () {
    test('the itemised lines are read with their quantities', () {
      final List<ReceiptLineItem> items = sample('Jollibee').lineItems;
      expect(items.length, 3);
      expect(items.first.qty, 1);
      expect(items.first.desc, contains('Chickenjoy'));
      expect(items.first.price, 99.00);
    });

    test('a total or a VAT line is never read as an item', () {
      for (final ReceiptLineItem i in sample('Puregold').lineItems) {
        expect(i.desc.toLowerCase(), isNot(contains('total')));
        expect(i.desc.toLowerCase(), isNot(contains('cash')));
        expect(i.desc.toLowerCase(), isNot(contains('change')));
      }
    });

    test('items never sum to more than the total they came from', () {
      // A cheap sanity check that catches a distractor line sneaking in.
      for (final ReceiptSample s in receiptSamples) {
        final ReceiptOcrResult r = parseReceiptText(s.text);
        if (r.lineItems.isEmpty) continue;
        final double sum = r.lineItems.fold<double>(
          0,
          (double a, ReceiptLineItem i) => a + i.price,
        );
        expect(
          sum,
          lessThanOrEqualTo(r.amount + 0.01),
          reason: '${s.label} items sum to $sum against a total of ${r.amount}',
        );
      }
    });
  });

  group('confidence is earned, never asserted', () {
    test('a rich official receipt scores higher than a bare one', () {
      final double rich = sample('Jollibee').confidence;
      final double bare = parseReceiptText(
        'SOMETHING\nTOTAL PHP 50.00',
      ).confidence;
      expect(rich, greaterThan(bare));
    });

    test('unreadable text scores near zero, not a flattering default', () {
      // The mistake this field exists not to repeat is the prototype health
      // check shipping "89% Accuracy" as a string literal.
      final ReceiptOcrResult r = parseReceiptText('#### ~~~~ ????');
      expect(r.confidence, lessThan(0.1));
      expect(r.isValid, isFalse);
    });

    test('it never leaves the 0 to 1 range', () {
      for (final ReceiptSample s in receiptSamples) {
        final double c = parseReceiptText(s.text).confidence;
        expect(c, inInclusiveRange(0.0, 1.0), reason: s.label);
      }
    });
  });

  group('every built-in sample actually parses', () {
    test('all six produce a usable reading', () {
      for (final ReceiptSample s in receiptSamples) {
        final ReceiptOcrResult r = parseReceiptText(s.text);
        expect(r.isValid, isTrue, reason: '${s.label} produced no amount');
        expect(r.merchant, isNotEmpty, reason: '${s.label} produced no name');
      }
    });

    test('and each one is labelled as a sample', () {
      // Nothing here may ever be reachable except by choosing it. The
      // prototype falls back to its Jollibee sample when a file name matches
      // nothing, so a photograph of any other receipt becomes a Jollibee
      // purchase carrying a stranger's TIN.
      for (final ReceiptSample s in receiptSamples) {
        expect(s.label, isNotEmpty);
        expect(s.note, isNotEmpty);
      }
    });
  });
}
