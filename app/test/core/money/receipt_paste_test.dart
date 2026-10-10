import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/fast_log.dart';
import 'package:salapify/core/money/receipt_paste.dart';
import 'package:salapify/models/models.dart';

/// Reading a bank or e-wallet receipt somebody pasted in.
///
/// Every message below is in the shape the prototype's own documentation
/// quotes, because that is what these actually look like and inventing
/// tidier ones would test a parser nobody will use.
void main() {
  const String gcash =
      'You have sent PHP 450.00 of GCash to JOLLIBEE 09171234567 on '
      '09-20-26 12:30. Ref. No. 100234567891. Your new balance is PHP '
      '2,150.75.';
  const String maya =
      'You paid PHP 350.00 to Grab Philippines using your Maya card ending '
      'in 1234 on Sep 20. Ref: 987654.';
  const String bpi =
      'Thank you for using your BPI Card ending in 5678 for PHP 850.00 at '
      'STARBUCKS BGC on 20-Sep-26.';
  const String bdo =
      'Your BDO Debit Card ending 4321 was used at MC DONALDS for PHP '
      '220.00 on 20/09/2026. Ref 55512345.';
  const String incoming =
      'You have received PHP 5,000.00 from JUAN DELA CRUZ via GCash on '
      '09-20-26. Ref. No. 900112233445. Your new balance is PHP 7,150.75.';

  group('it reads the amount, and not the other numbers', () {
    // These messages are full of numbers that are not the amount: card
    // digits, dates, reference numbers, the closing balance. The prototype's
    // regex has no anchor and takes the first run of digits it finds.
    void reads(String label, String message, double amount) {
      test(label, () {
        final FastLogResult r = parsePastedReceipt(message);
        expect(r.isValid, isTrue);
        expect(r.amount, amount);
      });
    }

    reads('a GCash send', gcash, 450);
    reads('a Maya card payment', maya, 350);
    reads('a BPI card swipe', bpi, 850);
    reads('a BDO debit swipe', bdo, 220);
    reads('an amount with a thousands comma', incoming, 5000);

    test('the CLOSING balance is not mistaken for the amount', () {
      // Both messages end with "Your new balance is PHP ...", which is a
      // bigger number sitting after the real one.
      expect(parsePastedReceipt(gcash).amount, 450);
      expect(parsePastedReceipt(incoming).amount, 5000);
    });
  });

  group('money coming IN is not filed as spending', () {
    test('a received amount is income', () {
      // The prototype treats every message as an expense, so this logs as
      // money leaving. That is wrong twice at once: the balance falls
      // instead of rising, and the month's spending is overstated by 5,000.
      final FastLogResult r = parsePastedReceipt(incoming);
      expect(r.type, TransactionType.income);
      expect(r.amount, 5000);
    });

    test('and a sent amount is still an expense', () {
      // The other half of the alarm. A rule that called everything income
      // would be just as wrong and would pass the test above.
      expect(parsePastedReceipt(gcash).type, TransactionType.expense);
      expect(parsePastedReceipt(bpi).type, TransactionType.expense);
    });
  });

  group('the merchant and the category', () {
    test('a known merchant brings its category', () {
      final FastLogResult r = parsePastedReceipt(gcash);
      expect(r.merchant, 'Jollibee');
      expect(r.category, 'Food & Dining');
      expect(r.categoryMatched, isTrue);
    });

    test('an unknown merchant is read, with NO category', () {
      // The founder's own "Electricity" report, in a new place. The parser's
      // fallback category is Food & Dining, so a merchant it does not know
      // would otherwise produce a confident wrong answer, and the Log sheet
      // would overwrite a correct selection with it.
      final FastLogResult r = parsePastedReceipt(
        'You paid PHP 1,240.00 to ACME HARDWARE SUPPLY using your BPI '
        'account on Sep 20. Ref: 445566.',
      );
      expect(r.merchant.toLowerCase(), contains('acme hardware'));
      expect(
        r.categoryMatched,
        isFalse,
        reason: 'an unknown merchant was given a category anyway',
      );
    });

    test('a card number is never read as the merchant', () {
      final FastLogResult r = parsePastedReceipt(bdo);
      expect(r.merchant, "McDonald's");
    });
  });

  group('the account is a HINT, never a default', () {
    test('a wallet message suggests that kind of account', () {
      expect(parsePastedReceipt(gcash).accountKind, AccountKind.gcash);
      expect(parsePastedReceipt(maya).accountKind, AccountKind.maya);
      expect(parsePastedReceipt(bpi).accountKind, AccountKind.bank);
    });

    test('an unrecognised sender suggests NOTHING', () {
      // The real defect in the prototype: when nothing matched it fell back
      // to accounts[0].id, so a mis-parse wrote a real expense against
      // whichever account happened to be first, with no signal at all.
      //
      // It cannot happen here by construction, because the parser is never
      // given the account list. This asserts the absence stays an absence
      // rather than becoming a helpful default later.
      final FastLogResult r = parsePastedReceipt(
        'Your payment of PHP 640.00 has been posted. Reference 7781234509.',
      );
      expect(r.isValid, isTrue);
      expect(
        r.accountKind,
        isNull,
        reason: 'it guessed an account from a message that named none',
      );
    });
  });

  group('telling a pasted receipt from a typed line', () {
    test('a real receipt is recognised', () {
      for (final String m in <String>[gcash, maya, bpi, bdo, incoming]) {
        expect(looksLikePastedReceipt(m), isTrue, reason: m);
      }
    });

    test('a quick line is NOT, so it still goes to the typed parser', () {
      // The shapes the Log sheet's own box has always taken. If these were
      // routed to the receipt parser they would come back as nothing.
      for (final String line in <String>[
        '250 jollibee gcash',
        'grab 180',
        '1200 groceries bpi',
        'sahod 32500',
        'utang kay ana 500',
      ]) {
        expect(looksLikePastedReceipt(line), isFalse, reason: line);
      }
    });

    test('a message with no amount is not valid, rather than zero', () {
      final FastLogResult r = parsePastedReceipt(
        'Your GCash account was accessed from a new device on 09-20-26. If '
        'this was not you, please contact support immediately.',
      );
      expect(
        r.isValid,
        isFalse,
        reason: 'a security alert was read as a transaction',
      );
    });
  });
}
