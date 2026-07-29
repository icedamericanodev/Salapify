// Delivery A of the unified accounts feature: the data design, before any
// screen depends on it.
//
// The whole point of shipping this invisibly first is that it is the cheapest
// place to find out the design is wrong. So these tests are about the two
// things that would be expensive later: a stored value being silently
// rewritten, and a row landing on the wrong side of net worth.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/backup.dart' show sanitizeData;
import 'package:salapify/money/account_taxonomy.dart';
import 'package:salapify/money/institutions.dart';

Map<String, dynamic> _accountsBlob(List<Map<String, dynamic>> accounts) =>
    sanitizeData({'schemaVersion': 12, 'accounts': accounts});

/// The asset kinds screens/accounts.dart already writes, and what each one
/// should resolve to. Checked against the real list on disk below.
const Map<String, String> _picker = {
  'crypto': 'crypto',
  'stocks': 'stocks',
  'mp2': 'retirement',
  'real estate': 'real_estate',
  'vehicle': 'vehicle',
  'other': 'other_asset',
};

Map<String, dynamic> _account(Map<String, dynamic> a) =>
    (_accountsBlob([a])['accounts'] as List).first as Map<String, dynamic>;

void main() {
  group('the legacy kind is left alone', () {
    test('a payroll subtype does NOT become a payroll kind', () {
      // The single most important assertion in this file. `kind` is clamped to
      // four values by every load and every save, and every money engine reads
      // it. Widening it would mean a payroll account written as
      // kind:'payroll' and read back as 'cash', permanently, with no error.
      // DECISION 2 exists because of this line.
      final a = _account({
        'id': 'a1',
        'name': 'Salary',
        'kind': 'checking',
        'subtype': 'payroll_account',
        'balance': 5000,
      });
      expect(a['kind'], 'checking');
      expect(a['subtype'], 'payroll_account');
    });

    test('a subtype written INTO kind is still clamped away', () {
      // Proving the clamp is still there rather than assuming it, because if
      // somebody ever relaxes it this whole design becomes unnecessary and
      // this test is where they should find that out.
      final a = _account({
        'id': 'a1',
        'name': 'Salary',
        'kind': 'payroll',
        'balance': 5000,
      });
      expect(a['kind'], 'cash', reason: 'the clamp is gone');
    });
  });

  group('legacy rows read correctly without ever being touched', () {
    test('each legacy kind derives its subtype', () {
      const pairs = {
        'cash': 'cash_on_hand',
        'savings': 'savings_account',
        'checking': 'checking_account',
        'ewallet': 'ewallet',
      };
      pairs.forEach((kind, subtype) {
        final r = resolveKind({'kind': kind}, AccountStore.accounts);
        expect(r.subtype.id, subtype, reason: kind);
        expect(r.cls, AccountClass.asset);
        expect(r.category.id, 'cash_equivalents');
        expect(r.derived, isTrue, reason: 'this was a guess, and should say so');
      });
    });

    test('nothing is written back, so an RN backup stays byte identical', () {
      // Deriving rather than backfilling is what makes this feature need no
      // migration at all. A row with no subtype must come out of sanitizeData
      // with no subtype.
      final a = _account({
        'id': 'a1',
        'name': 'Wallet',
        'kind': 'cash',
        'balance': 100,
      });
      for (final k in const [
        'subtype',
        'category',
        'accountClass',
        'institutionId',
        'currencyCode',
        'last4',
        'includeInNetWorth',
        'isArchived',
      ]) {
        expect(a.containsKey(k), isFalse, reason: '$k was backfilled');
      }
    });

    test('a debt derives from its type, matching what the engine keys on', () {
      expect(
        resolveKind({'type': 'credit card'}, AccountStore.debts).subtype.id,
        'credit_card',
      );
      expect(
        resolveKind({'type': 'other'}, AccountStore.debts).subtype.id,
        'other_loan',
      );
      // Both are liabilities, whatever they are called.
      for (final t in ['credit card', 'other', '', null]) {
        expect(
          resolveKind({'type': t}, AccountStore.debts).cls,
          AccountClass.liability,
        );
      }
    });

    test('every asset kind the picker offers derives to a real subtype', () {
      // The picker in screens/accounts.dart already writes six values. The
      // first version of the taxonomy claimed assets "carry no type at all"
      // and derived all of them to "something else", which would have read a
      // crypto holding and a house as the same thing on the first screen that
      // grouped them. This test is the reason the claim got checked.
      //
      // Read from _assetKinds in screens/accounts.dart, so a new option there
      // without a mapping here shows up as an unclassified asset rather than
      // silently.
      _picker.forEach((kind, subtype) {
        final r = resolveKind({'kind': kind, 'value': 1}, AccountStore.assets);
        expect(r.subtype.id, subtype, reason: kind);
        expect(r.cls, AccountClass.asset);
        expect(r.derived, isTrue);
      });
    });

    test('the picker list above is really the one in the app', () {
      // The test above hardcodes six values, so adding a seventh to the picker
      // would leave it green while that asset landed in "something else". This
      // reads the real list off disk, the same trick widget_manifest_test uses
      // for the Android manifest, so the two cannot drift apart quietly.
      final src = File('lib/screens/accounts.dart').readAsStringSync();
      final block = RegExp(
        r'const _assetKinds = \[(.*?)\];',
        dotAll: true,
      ).firstMatch(src);
      expect(block, isNotNull, reason: '_assetKinds moved or was renamed');
      final kinds = RegExp(r"\('([^']+)',")
          .allMatches(block!.group(1)!)
          .map((m) => m.group(1)!)
          .toSet();
      expect(kinds, isNotEmpty, reason: 'the scan found nothing, so it would '
          'pass on any change');
      expect(
        kinds,
        _picker.keys.toSet(),
        reason: 'the Accounts screen picker and the mapping above disagree. A '
            'kind the picker offers with no mapping means every asset created '
            'that way reads as unclassified; a mapping with no picker option '
            'is dead weight.',
      );
    });

    test('an asset with no type at all is honestly "something else"', () {
      // The asset kind is a free string and nothing clamps it, so this is a
      // real shape, not a defensive hypothetical.
      for (final k in [null, '', 'invented', 42]) {
        final r = resolveKind({'kind': k, 'value': 1}, AccountStore.assets);
        expect(r.subtype.id, 'other_asset', reason: '$k');
        expect(r.cls, AccountClass.asset);
      }
    });
  });

  group('a subtype from the wrong collection is not trusted', () {
    test('a house in the accounts list is read as an account', () {
      // A corrupt or hand-edited backup. Trusting the stored string would put
      // a property row inside the spendable-cash total, which is the one place
      // a wrong classification turns into a wrong number on Home.
      final r = resolveKind({
        'kind': 'savings',
        'subtype': 'real_estate',
      }, AccountStore.accounts);
      expect(r.subtype.id, 'savings_account');
      expect(r.derived, isTrue);
    });

    test('and sanitizeData drops the impossible subtype entirely', () {
      final a = _account({
        'id': 'a1',
        'name': 'Odd',
        'kind': 'savings',
        'subtype': 'real_estate',
        'balance': 1,
      });
      expect(a.containsKey('subtype'), isFalse);
    });

    test('an unknown subtype loads, and the account still spends', () {
      final a = _account({
        'id': 'a1',
        'name': 'Odd',
        'kind': 'savings',
        'subtype': 'invented_by_a_future_version',
        'balance': 250,
      });
      expect(a.containsKey('subtype'), isFalse);
      expect(a['balance'], 250, reason: 'the money went missing');
      expect(
        resolveKind(a, AccountStore.accounts).subtype.id,
        'savings_account',
      );
    });
  });

  group('the new fields are validated, and junk is dropped not corrected', () {
    test('last4 takes exactly four digits and nothing else', () {
      for (final v in ['123', '12345', 'abcd', '12a4', '', 1234, null]) {
        final a = _account({
          'id': 'a1',
          'kind': 'savings',
          'balance': 0,
          'last4': v,
        });
        expect(a.containsKey('last4'), isFalse, reason: 'accepted $v');
      }
      final ok = _account({
        'id': 'a1',
        'kind': 'savings',
        'balance': 0,
        'last4': '4821',
      });
      expect(ok['last4'], '4821');
    });

    test('nothing longer than four digits can ever be stored', () {
      // The privacy constraint, as a test rather than a preference. A full
      // card number arriving in ANY of these fields must not survive a load.
      final a = _account({
        'id': 'a1',
        'kind': 'savings',
        'balance': 0,
        'last4': '4821567890123456',
        'cardNumber': '4821567890123456',
        'cvv': '123',
        'pin': '1234',
      });
      expect(a.containsKey('last4'), isFalse);
      // cardNumber, cvv and pin are not fields this feature knows about, so
      // they survive as unknown keys, which is how every unrecognised key
      // behaves. Nothing in Salapify ever asks for them; this asserts the one
      // field the feature DOES own cannot become a place to put them.
      expect(a['last4'], isNull);
    });

    test('a currency code is three letters, upper cased', () {
      expect(
        _account({
          'id': 'a',
          'kind': 'cash',
          'balance': 0,
          'currencyCode': 'usd',
        })['currencyCode'],
        'USD',
      );
      for (final v in ['US', 'USDD', '123', '', null, 840]) {
        expect(
          _account({
            'id': 'a',
            'kind': 'cash',
            'balance': 0,
            'currencyCode': v,
          }).containsKey('currencyCode'),
          isFalse,
          reason: 'accepted $v',
        );
      }
    });

    test('the two flags are only stored when they are NOT the default', () {
      // Absent means counts and not archived, so every row that predates this
      // feature behaves exactly as it always did, and the goldens never gain a
      // key.
      final plain = _account({'id': 'a', 'kind': 'cash', 'balance': 0});
      expect(plain.containsKey('includeInNetWorth'), isFalse);
      expect(plain.containsKey('isArchived'), isFalse);
      expect(countsInNetWorth(plain), isTrue);

      final off = _account({
        'id': 'a',
        'kind': 'cash',
        'balance': 0,
        'includeInNetWorth': false,
        'isArchived': true,
      });
      expect(off['includeInNetWorth'], isFalse);
      expect(off['isArchived'], isTrue);
      expect(countsInNetWorth(off), isFalse);

      // The redundant true is dropped, so two rows meaning the same thing are
      // stored the same way.
      final redundant = _account({
        'id': 'a',
        'kind': 'cash',
        'balance': 0,
        'includeInNetWorth': true,
        'isArchived': false,
      });
      expect(redundant.containsKey('includeInNetWorth'), isFalse);
      expect(redundant.containsKey('isArchived'), isFalse);
    });

    test('a classified account round trips through a save and a load', () {
      final once = _account({
        'id': 'a1',
        'name': 'Salary',
        'kind': 'checking',
        'subtype': 'payroll_account',
        'institutionId': 'bpi',
        'currencyCode': 'PHP',
        'last4': '4821',
        'balance': 5000,
      });
      final twice = _account(once);
      expect(twice, once, reason: 'a second load changed the row');
      expect(once['category'], 'cash_equivalents');
      expect(once['accountClass'], 'asset');
    });
  });

  group('the catalog', () {
    test('every subtype id is unique across every category', () {
      final seen = <String>{};
      for (final c in accountCategories) {
        for (final s in c.subtypes) {
          expect(seen.add(s.id), isTrue, reason: 'duplicate subtype ${s.id}');
        }
      }
      final cats = accountCategories.map((c) => c.id).toSet();
      expect(cats.length, accountCategories.length, reason: 'duplicate category');
    });

    test('every subtype stored in accounts has a legal legacy kind', () {
      // Without this, adding a subtype means an account whose `kind` gets
      // clamped to cash and quietly changes what every engine thinks it is.
      const legal = {'cash', 'savings', 'checking', 'ewallet'};
      for (final c in accountCategories) {
        if (c.store != AccountStore.accounts) continue;
        for (final s in c.subtypes) {
          expect(
            legal.contains(s.legacyKind),
            isTrue,
            reason: '${s.id} maps to "${s.legacyKind}", which is not a legal '
                'kind and would be clamped to cash on the next load',
          );
        }
      }
    });

    test('subtypes NOT in accounts carry no legacy kind at all', () {
      for (final c in accountCategories) {
        if (c.store == AccountStore.accounts) continue;
        for (final s in c.subtypes) {
          expect(s.legacyKind, isNull, reason: s.id);
        }
      }
    });

    test('every liability is stored in debts, every asset is not', () {
      for (final c in accountCategories) {
        if (c.cls == AccountClass.liability) {
          expect(c.store, AccountStore.debts, reason: c.id);
        } else {
          expect(c.store, isNot(AccountStore.debts), reason: c.id);
        }
      }
    });

    test('both sides of net worth have somewhere to go', () {
      expect(categoriesFor(AccountClass.asset), isNotEmpty);
      expect(categoriesFor(AccountClass.liability), isNotEmpty);
    });

    test('every label and hint is plain, with no dashes', () {
      for (final c in accountCategories) {
        for (final text in [c.label, ...c.subtypes.map((s) => s.label),
            ...c.subtypes.map((s) => s.hint)]) {
          expect(text.contains('—'), isFalse, reason: 'em dash in "$text"');
          expect(text.contains('–'), isFalse, reason: 'en dash in "$text"');
          expect(text.trim(), isNotEmpty);
        }
      }
    });
  });

  group('institutions', () {
    test('every id is unique', () {
      final seen = <String>{};
      for (final i in institutions) {
        expect(seen.add(i.id), isTrue, reason: 'duplicate ${i.id}');
      }
    });

    test('search finds a bank by its full name, not just its initials', () {
      final byAlias = searchInstitutions('Bank of the Philippine Islands');
      expect(byAlias.first.id, 'bpi');
      expect(searchInstitutions('banco de oro').first.id, 'bdo');
      expect(searchInstitutions('paymaya').first.id, 'maya');
    });

    test('a name typed without its punctuation still matches', () {
      // Somebody looking for their Pag-IBIG loan types "pagibig".
      expect(searchInstitutions('pagibig').map((i) => i.id), contains('pagibig'));
      expect(searchInstitutions('gotyme').first.id, 'gotyme');
    });

    test('a prefix match outranks a mere containment', () {
      final r = searchInstitutions('sea');
      expect(r.first.id, 'seabank', reason: 'ranked ${r.map((i) => i.id)}');
    });

    test('the escape hatches stay out of an empty list', () {
      final all = searchInstitutions('').map((i) => i.id).toList();
      expect(all, isNot(contains('other')));
      expect(all, isNot(contains('none')));
      // But they are findable when looked for.
      expect(searchInstitutions('something else').map((i) => i.id),
          contains('other'));
    });

    test('a search that matches nothing returns nothing, not everything', () {
      expect(searchInstitutions('zzzzz'), isEmpty);
    });

    test('initials are two letters, and never a bare question mark', () {
      expect(initialsFor('BPI'), 'BP');
      expect(initialsFor('Bank of Commerce'), 'BO');
      expect(initialsFor('Pag-IBIG'), 'PI');
      expect(initialsFor('  '), '?');
      expect(initialsFor('123'), '?');
      for (final i in institutions) {
        expect(i.initials.length, inInclusiveRange(1, 2), reason: i.id);
        expect(i.initials, isNot('?'), reason: '${i.id} has no usable initials');
      }
    });

    test('a custom institution shows the typed name, a listed one does not', () {
      expect(
        institutionLabel({'institutionId': 'other', 'institutionName': 'Ka Juan'}),
        'Ka Juan',
      );
      expect(institutionLabel({'institutionId': 'bpi'}), 'BPI');
      // A listed id with a stray custom string: the catalog wins, because the
      // catalog cannot have been mistyped.
      expect(
        institutionLabel({'institutionId': 'bpi', 'institutionName': 'typo'}),
        'BPI',
      );
      expect(institutionLabel({}), isNull);
      expect(institutionLabel(null), isNull);
    });

    test('a blank custom name falls back rather than showing nothing', () {
      expect(
        institutionLabel({'institutionId': 'other', 'institutionName': '   '}),
        'Something else',
      );
    });
  });

  test('junk never throws', () {
    for (final junk in [null, 'nope', 42, <String, dynamic>{}, []]) {
      for (final store in AccountStore.values) {
        expect(() => resolveKind(junk, store), returnsNormally, reason: '$junk');
        expect(() => taxonomyKeys(junk, store), returnsNormally, reason: '$junk');
      }
      expect(() => countsInNetWorth(junk), returnsNormally);
      expect(() => institutionLabel(junk), returnsNormally);
    }
  });
}
