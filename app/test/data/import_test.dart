import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/import.dart';

/// Which files may be restored, decided without writing anything.
void main() {
  group('refusals', () {
    test('a valid JSON file that is not a Salapify backup is REFUSED', () {
      // THE test. `{}` decodes into a complete, entirely empty ledger, so
      // without the gate this would report success and leave Salapify with
      // nothing, over the top of everything the person had.
      for (final String raw in <String>[
        '{}',
        '{"foo": 1}',
        '{"version": 3, "notes": ["hi"]}',
      ]) {
        final ImportCheck c = checkImportFile(raw);
        expect(
          c,
          isA<ImportRefused>(),
          reason: '$raw was accepted, and restoring it would empty the app',
        );
      }
    });

    test('an empty file is refused', () {
      expect(checkImportFile(''), isA<ImportRefused>());
      expect(checkImportFile('   \n '), isA<ImportRefused>());
    });

    test(
      'a truncated file is refused, and says it may have been cut short',
      () {
        final ImportCheck c = checkImportFile('{"accounts":[{"id":"a"');
        expect(c, isA<ImportRefused>());
        expect((c as ImportRefused).reason, contains('cut short'));
      },
    );

    test('a file from a newer Salapify is refused with its own sentence', () {
      final ImportCheck c = checkImportFile(
        '{"schemaVersion": 99, "accounts": []}',
      );
      expect(c, isA<ImportRefused>());
      expect((c as ImportRefused).reason.toLowerCase(), contains('newer'));
    });

    test('a file whose account cannot be read is refused, not half loaded', () {
      final ImportCheck c = checkImportFile('{"accounts":[{"id":1}]}');
      expect(c, isA<ImportRefused>());
    });

    test('a list rather than an object is refused', () {
      expect(checkImportFile('[1,2,3]'), isA<ImportRefused>());
    });
  });

  group('accepted', () {
    const String real =
        '{"schemaVersion":1,'
        '"accounts":[{"id":"a1","name":"My GCash","kind":"gcash",'
        '"institution":"GCash","balance":50000,"monogram":"GC"}],'
        '"transactions":[],"debts":[],"budgets":[],"goals":[],'
        '"upcoming":[],"incomeStreams":[],"installments":[],'
        '"reconciliations":[],"bills":[],'
        '"timestamp":"2026-09-12T08:00:00.000Z"}';

    test('a real backup is ready, and summarised', () {
      final ImportCheck c = checkImportFile(real);
      expect(c, isA<ImportReady>());
      final ImportReady r = c as ImportReady;
      expect(r.summary.accounts, 1);
      expect(r.summary.assets, 50000);
      expect(r.summary.liabilities, 0);
      expect(r.summary.savedAt, '2026-09-12T08:00:00.000Z');
      expect(r.missing, isEmpty);
    });

    test('a genuinely empty backup is importable, and says it is empty', () {
      // Somebody who cleared everything and exported. Refusing their own file
      // would be wrong; letting them restore it in silence would be worse.
      final ImportCheck c = checkImportFile('{"schemaVersion":1}');
      expect(c, isA<ImportReady>());
      expect((c as ImportReady).summary.isEmpty, isTrue);
    });

    test('a prototype backup imports, and NAMES what it does not contain', () {
      // Nine of thirty four keys. The collections it lacks come back empty,
      // which moves Safe to Spend, so silence here would be an unexplained
      // change in the headline figure.
      final ImportCheck c = checkImportFile(
        '{"accounts":[],"transactions":[],"debts":[],"budgets":[],'
        '"goals":[],"upcoming":[],"incomeStreams":[]}',
      );
      expect(c, isA<ImportReady>());
      final List<String> missing = (c as ImportReady).missing;
      expect(missing, contains('payment plans'));
      expect(missing, contains('bills'));
      expect(missing, contains('reconciliation checks'));
      expect(missing, isNot(contains('accounts')));
    });

    test('assets and debts are counted apart, never summed', () {
      final ImportCheck c = checkImportFile(
        '{"schemaVersion":1,"accounts":['
        '{"id":"a","name":"Cash","kind":"cash","institution":"Cash",'
        '"balance":5000,"monogram":"C"},'
        '{"id":"m","name":"Mortgage","kind":"mortgage","institution":"Pag-IBIG",'
        '"balance":385000,"monogram":"M"}]}',
      );
      final LedgerSummary s = (c as ImportReady).summary;
      expect(s.assets, 5000);
      expect(
        s.liabilities,
        385000,
        reason:
            'adding these together announces a 385,000 mortgage as money '
            'somebody has, which the sample summary already learned once',
      );
    });
  });
}
