import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/models/models.dart';

/// The three fields the founder asked for on 2026-09-20: a tax deductible
/// marking, a BIR reference, and a receipt image.
///
/// Every test here is about the same worry in a different place. A ledger
/// field is only as good as its round trip, and a field that is accepted on
/// screen and dropped on save looks identical to one that works.
void main() {
  Transaction base({
    bool deductible = false,
    String? ref,
    String? path,
    String? name,
  }) => Transaction(
    id: 'tx1',
    type: TransactionType.expense,
    amount: 1240,
    category: 'Bills & Utilities',
    accountId: 'acc_bpi',
    date: '2026-09-20',
    createdAt: 1758326400000,
    isTaxDeductible: deductible,
    taxTinOrRef: ref,
    attachmentPath: path,
    attachmentName: name,
  );

  Transaction roundTrip(Transaction t) =>
      transactionFromJson(transactionToJson(t));

  group('the fields survive a save and a load', () {
    test('all three come back exactly as they went in', () {
      final Transaction t = roundTrip(
        base(
          deductible: true,
          ref: 'OR-2026-00184',
          path: 'attachments/tx1.jpg',
          name: 'meralco-sept.jpg',
        ),
      );
      expect(t.isTaxDeductible, isTrue);
      expect(t.taxTinOrRef, 'OR-2026-00184');
      expect(t.attachmentPath, 'attachments/tx1.jpg');
      expect(t.attachmentName, 'meralco-sept.jpg');
      expect(t.hasAttachment, isTrue);
    });

    test('and an untouched entry stays untouched', () {
      // The other half. A codec that filled these in with something would
      // pass the test above and would quietly mark every row deductible.
      final Transaction t = roundTrip(base());
      expect(t.isTaxDeductible, isFalse);
      expect(t.taxTinOrRef, isNull);
      expect(t.attachmentPath, isNull);
      expect(t.hasAttachment, isFalse);
    });

    test('an untouched entry writes NO new keys at all', () {
      // A ledger where nobody has used this feature has to be byte for byte
      // what it was, or every existing phone rewrites its whole file on the
      // first save after an update for no reason.
      final Map<String, dynamic> m = transactionToJson(base());
      expect(m.containsKey('isTaxDeductible'), isFalse);
      expect(m.containsKey('taxTinOrRef'), isFalse);
      expect(m.containsKey('attachmentUrl'), isFalse);
      expect(m.containsKey('attachmentName'), isFalse);
    });

    test('a backup written before these fields existed still loads', () {
      final Transaction t = transactionFromJson(<String, dynamic>{
        'id': 'old1',
        'type': 'expense',
        'amount': 250,
        'category': 'Food & Dining',
        'accountId': 'acc_cash',
        'date': '2026-08-01',
        'createdAt': 1754006400000,
      });
      expect(t.isTaxDeductible, isFalse);
      expect(t.taxTinOrRef, isNull);
      expect(t.attachmentPath, isNull);
    });
  });

  group('the receipt is a path on this phone, never a URL', () {
    // Salapify's header badge says "On this phone" and its privacy receipt
    // names the ONE outbound request the app makes. The prototype's field is
    // typed as a URL and its own seed data fills it with three
    // images.unsplash.com links, so a backup exported from it genuinely
    // carries them. Loading one at face value would put the app on the
    // network the first time such a row was drawn.
    void dropped(String label, String stored) {
      test(label, () {
        final Transaction t = transactionFromJson(<String, dynamic>{
          'id': 'x',
          'type': 'expense',
          'amount': 1,
          'category': 'Food & Dining',
          'accountId': 'a',
          'date': '2026-09-20',
          'createdAt': 1758326400000,
          'attachmentUrl': stored,
        });
        expect(
          t.attachmentPath,
          isNull,
          reason: 'Salapify would have gone looking for $stored',
        );
      });
    }

    dropped(
      'the prototype seed URL, which is the real one in the wild',
      'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c',
    );
    dropped('plain http', 'http://example.com/receipt.jpg');
    dropped('an inline base64 image', 'data:image/png;base64,iVBORw0KGgo=');
    dropped(
      'a file scheme pointing anywhere on the device',
      'file:///etc/passwd',
    );
    dropped(
      'an absolute path, which this app never writes',
      '/sdcard/DCIM/a.jpg',
    );
    dropped(
      'a path climbing out of the attachments folder',
      'attachments/../../a.jpg',
    );
    dropped('an empty string, which is not a location', '   ');

    test('and a real relative path is KEPT', () {
      // The half that matters most. A rule that dropped everything would
      // pass all seven tests above and would delete every receipt anybody
      // ever attached.
      final Transaction t = transactionFromJson(<String, dynamic>{
        'id': 'x',
        'type': 'expense',
        'amount': 1,
        'category': 'Food & Dining',
        'accountId': 'a',
        'date': '2026-09-20',
        'createdAt': 1758326400000,
        'attachmentUrl': 'attachments/tx_1758326400000.jpg',
      });
      expect(t.attachmentPath, 'attachments/tx_1758326400000.jpg');
    });

    test('the rest of the row survives a dropped receipt', () {
      // An import that threw away somebody's whole ledger to save them one
      // image would be a far worse failure than the one it prevented.
      final Transaction t = transactionFromJson(<String, dynamic>{
        'id': 'x',
        'type': 'expense',
        'amount': 1240,
        'category': 'Bills & Utilities',
        'accountId': 'acc_bpi',
        'date': '2026-09-20',
        'createdAt': 1758326400000,
        'attachmentUrl': 'https://images.unsplash.com/photo-1554224155',
        'isTaxDeductible': true,
        'taxTinOrRef': 'OR-2026-00184',
      });
      expect(t.amount, 1240);
      expect(t.isTaxDeductible, isTrue);
      expect(t.taxTinOrRef, 'OR-2026-00184');
    });
  });

  group('editing them is narrow, the way withStatus already is', () {
    test('withTaxDetails changes only what it was given', () {
      final Transaction t = base(
        ref: 'OR-1',
      ).withTaxDetails(isTaxDeductible: true);
      expect(t.isTaxDeductible, isTrue);
      expect(t.taxTinOrRef, 'OR-1', reason: 'an untouched field moved');
      expect(t.amount, 1240);
      expect(t.category, 'Bills & Utilities');
    });

    test('removing a receipt keeps the tax marking', () {
      // Somebody who deletes a blurry photo has not stopped claiming the
      // expense. Clearing the tick would lose a decision they made on
      // purpose, and they would have no way to know it happened.
      final Transaction t = base(
        deductible: true,
        ref: 'OR-1',
        path: 'attachments/a.jpg',
        name: 'a.jpg',
      ).withoutAttachment();
      expect(t.attachmentPath, isNull);
      expect(t.attachmentName, isNull);
      expect(t.isTaxDeductible, isTrue);
      expect(t.taxTinOrRef, 'OR-1');
    });

    test('withStatus carries the new fields through', () {
      // withStatus rebuilds the whole record by hand, so a field added to
      // the class and not to that method is silently erased by an ordinary
      // correction. Nothing about the class makes that impossible.
      final Transaction t = base(
        deductible: true,
        ref: 'OR-1',
        path: 'attachments/a.jpg',
        name: 'a.jpg',
      ).withStatus(TransactionStatus.excluded);
      expect(t.status, TransactionStatus.excluded);
      expect(t.isTaxDeductible, isTrue);
      expect(t.taxTinOrRef, 'OR-1');
      expect(t.attachmentPath, 'attachments/a.jpg');
      expect(t.attachmentName, 'a.jpg');
    });
  });

  group('the marking is a label and changes no arithmetic', () {
    test('it does not move the amount or the totals flag', () {
      final Transaction plain = base();
      final Transaction marked = base(deductible: true, ref: 'OR-1');
      expect(marked.amount, plain.amount);
      expect(marked.countsTowardTotals, plain.countsTowardTotals);
    });

    test('nothing in lib/ reads it to compute a figure', () {
      // The rule this feature ships under, enforced rather than promised.
      // Whether a peso is deductible turns on the taxpayer's regime and on
      // substantiation this app does not model. Under the 8 percent election
      // there are no itemised deductions at all, so every row marked here
      // would be deductible in Salapify and not at the BIR.
      //
      // If a later change genuinely should read it, this test is the place
      // that decision gets made on purpose instead of by accident.
      const List<String> allowed = <String>[
        'lib/models/models.dart',
        'lib/data/json_codec.dart',
        // Added 2026-09-20, deliberately, when this test caught it.
        //
        // The receipt reader SUGGESTS the flag from what is printed on the
        // paper: a TIN, or the words that make a document an official
        // receipt. That is reading, not arithmetic. It proposes a value for
        // a field on a new entry and the person can untick it before saving,
        // which is the opposite of a figure computed behind their back.
        'lib/core/money/receipt_ocr.dart',
        // Added the same day, when this test caught feature 4 too.
        //
        // The claims hub is the one place the flag is MEANT to be read. It
        // filters and it totals, which is arithmetic on the person's own
        // amounts and says nothing about tax. The dangerous step, turning a
        // total into a tax saving, cannot happen without a rate the caller
        // names, and `bir_claims_no_default_rate_test.dart` is what holds
        // that line now. This list was the wrong instrument for it: it
        // banned reading the field at all, which stops the feature rather
        // than the defect.
        'lib/core/money/bir_claims.dart',
        'lib/screens/reports/bir_claims_card.dart',
      ];
      final List<String> offenders = <String>[];
      final List<FileSystemEntity> files = Directory('lib')
          .listSync(recursive: true)
          .where((FileSystemEntity f) => f.path.endsWith('.dart'))
          .toList();
      for (final FileSystemEntity f in files) {
        if (allowed.contains(f.path)) continue;
        if (File(f.path).readAsStringSync().contains('isTaxDeductible')) {
          offenders.add(f.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'the deductible flag reached code outside the model and the '
            'codec. If that is deliberate, add the file to `allowed` and '
            'say why in the commit.',
      );
    });
  });
}
