// The new account metadata: card network and product, the non-secret notes, the
// QR reference, and the sensitive-data protection version. Every one is a
// CONDITIONAL key, validated on the way in and dropped when it is junk, so the
// backup goldens stay green (an RN row carries none of these and comes out
// unchanged) and a hand-edited blob can never smuggle a bad value onto disk.
//
// The one rule these guard together: the ONLY digits this feature ever stores
// are the four of `last4`. There is no field here that accepts a full account
// number, a card number, a CVV, a PIN, an OTP, or a password, and these tests
// assert the shapes that ARE accepted so a later change cannot widen them by
// accident.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/backup.dart';
import 'package:salapify/data/qr_vault.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/account_taxonomy.dart';
import 'package:salapify/money/card_products.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('taxonomyKeys, card metadata (debts only)', () {
    test('a valid network, product and fee are kept and normalised', () {
      final out = taxonomyKeys({
        'cardNetwork': 'VISA',
        'cardProductId': 'platinum',
        'annualFee': 2500,
      }, AccountStore.debts);
      expect(out['cardNetwork'], 'visa', reason: 'lowercased');
      expect(out['cardProductId'], 'platinum');
      expect(out['annualFee'], 2500.0);
    });

    test('an unknown network is dropped, not corrected', () {
      final out = taxonomyKeys(
        {'cardNetwork': 'discover'},
        AccountStore.debts,
      );
      expect(out.containsKey('cardNetwork'), isFalse);
    });

    test('a negative annual fee is dropped', () {
      final out = taxonomyKeys({'annualFee': -1}, AccountStore.debts);
      expect(out.containsKey('annualFee'), isFalse);
    });

    test('a product id with illegal characters is dropped', () {
      final out = taxonomyKeys(
        {'cardProductId': 'Gold Rewards!'},
        AccountStore.debts,
      );
      expect(out.containsKey('cardProductId'), isFalse);
    });

    test('card metadata never lands on a non-debt row', () {
      final out = taxonomyKeys(
        {'cardNetwork': 'visa', 'cardProductId': 'gold', 'annualFee': 100},
        AccountStore.accounts,
      );
      expect(out.containsKey('cardNetwork'), isFalse);
      expect(out.containsKey('cardProductId'), isFalse);
      expect(out.containsKey('annualFee'), isFalse);
    });
  });

  group('taxonomyKeys, notes and QR (any collection)', () {
    test('notes are trimmed and empty ones are dropped', () {
      final out = taxonomyKeys({
        'accountHolderName': '  Carla D  ',
        'paymentInstructions': '   ',
        'branchDetails': 'Makati',
        'qrLabel': 'My GCash QR',
      }, AccountStore.accounts);
      expect(out['accountHolderName'], 'Carla D');
      expect(out.containsKey('paymentInstructions'), isFalse);
      expect(out['branchDetails'], 'Makati');
      expect(out['qrLabel'], 'My GCash QR');
    });

    test('a very long note is capped, never rejected outright', () {
      final long = 'x' * 500;
      final out = taxonomyKeys(
        {'paymentInstructions': long},
        AccountStore.accounts,
      );
      expect((out['paymentInstructions'] as String).length, 280);
    });

    test('a valid QR reference is kept', () {
      final out = taxonomyKeys(
        {'qrRef': 'qr_abc123.png'},
        AccountStore.accounts,
      );
      expect(out['qrRef'], 'qr_abc123.png');
    });

    test('a QR reference with a path or traversal is refused', () {
      for (final bad in const [
        '../secrets.png',
        '/etc/passwd',
        'qr_../x.png',
        'qr_a/b.png',
        'photo.png',
        'qr_a.exe',
      ]) {
        final out = taxonomyKeys({'qrRef': bad}, AccountStore.accounts);
        expect(
          out.containsKey('qrRef'),
          isFalse,
          reason: '$bad must never be stored as a QR reference',
        );
      }
    });

    test('a card number typed into a note is redacted, a reference is kept', () {
      // 4111 1111 1111 1111 is the canonical Luhn-valid test PAN.
      final out = taxonomyKeys({
        'paymentInstructions': 'Card 4111 1111 1111 1111 pay by the 15th',
        'branchDetails': 'Ref 123456789012',
      }, AccountStore.accounts);
      expect(out['paymentInstructions'], contains('[removed for safety]'));
      expect(out['paymentInstructions'], contains('pay by the 15th'));
      expect(out['paymentInstructions'], isNot(contains('4111')));
      // An ordinary 12-digit reference does not pass Luhn, so it is kept.
      expect(out['branchDetails'], 'Ref 123456789012');
    });

    test('the protection version accepts a positive int only', () {
      expect(
        taxonomyKeys({'sensitiveDataProtectionVersion': 1}, AccountStore.debts)[
            'sensitiveDataProtectionVersion'],
        1,
      );
      expect(
        taxonomyKeys(
          {'sensitiveDataProtectionVersion': 0},
          AccountStore.debts,
        ).containsKey('sensitiveDataProtectionVersion'),
        isFalse,
      );
      expect(
        taxonomyKeys(
          {'sensitiveDataProtectionVersion': '1'},
          AccountStore.debts,
        ).containsKey('sensitiveDataProtectionVersion'),
        isFalse,
      );
    });
  });

  group('backup round trip', () {
    test('a debt carrying every new field survives sanitize unchanged', () {
      final data = sanitizeData({
        'schemaVersion': 12,
        'debts': [
          {
            'id': 'c1',
            'name': 'BPI card',
            'type': 'credit card',
            'remaining': 12480.40,
            'creditLimit': 50000,
            'institutionId': 'bpi',
            'subtype': 'credit_card',
            'cardNetwork': 'mastercard',
            'cardProductId': 'platinum',
            'annualFee': 2500,
            'last4': '4821',
            'accountHolderName': 'Carla D',
            'qrRef': 'qr_bpi01.png',
            'qrLabel': 'Pay my card',
            'sensitiveDataProtectionVersion': 1,
          },
        ],
      });
      final d = (data['debts'] as List).first as Map;
      expect(d['cardNetwork'], 'mastercard');
      expect(d['cardProductId'], 'platinum');
      expect(d['annualFee'], 2500.0);
      expect(d['last4'], '4821');
      expect(d['accountHolderName'], 'Carla D');
      expect(d['qrRef'], 'qr_bpi01.png');
      expect(d['sensitiveDataProtectionVersion'], 1);
    });

    test('an RN-plain account gains none of the new keys', () {
      final data = sanitizeData({
        'schemaVersion': 12,
        'accounts': [
          {'id': 'a1', 'name': 'GCash', 'kind': 'ewallet', 'balance': 100},
        ],
      });
      final a = (data['accounts'] as List).first as Map;
      for (final k in const [
        'accountHolderName',
        'paymentInstructions',
        'branchDetails',
        'qrLabel',
        'qrRef',
        'cardNetwork',
        'sensitiveDataProtectionVersion',
      ]) {
        expect(a.containsKey(k), isFalse, reason: 'RN account must not carry $k');
      }
    });

    test('an RN-plain debt gains none of the new keys', () {
      final data = sanitizeData({
        'schemaVersion': 12,
        'debts': [
          {'id': 'c2', 'name': 'Loan', 'type': 'personal loan', 'remaining': 5000},
        ],
      });
      final d = (data['debts'] as List).first as Map;
      for (final k in const [
        'cardNetwork',
        'cardProductId',
        'annualFee',
        'accountHolderName',
        'paymentInstructions',
        'branchDetails',
        'qrLabel',
        'qrRef',
        'sensitiveDataProtectionVersion',
      ]) {
        expect(
          d.containsKey(k),
          isFalse,
          reason: 'an untouched RN debt must not carry $k',
        );
      }
    });
  });

  group('store.patchDebtMeta', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({
          'schemaVersion': 12,
          'accounts': [
            {'id': 'a1', 'name': 'BPI', 'kind': 'savings', 'balance': 9000},
          ],
          'transactions': [],
          'debts': [
            {
              'id': 'c1',
              'name': 'BPI card',
              'type': 'credit card',
              'remaining': 12480.40,
              'creditLimit': 50000,
            },
          ],
          'payments': [],
        }),
      });
    });

    test('patchAccountMeta ignores money, identity and reclassification', () async {
      final store = SalapifyStore();
      await store.load();
      await store.patchAccountMeta('a1', {
        'accountHolderName': 'Carla',
        'last4': '4821',
        'balance': 0,
        'kind': 'cash',
        'subtype': 'credit_card',
        'name': 'hacked',
      });
      final a = (store.data['accounts'] as List).first as Map;
      expect(a['accountHolderName'], 'Carla');
      expect(a['last4'], '4821');
      expect(a['balance'], 9000, reason: 'balance is not patchable');
      expect(a['kind'], 'savings', reason: 'kind is not patchable');
      expect(a['name'], 'BPI', reason: 'name is not patchable');
      expect(a.containsKey('subtype'), isFalse, reason: 'subtype is not patchable');
    });

    test('applies allowlisted meta but never touches money or identity', () async {
      final store = SalapifyStore();
      await store.load();
      await store.patchDebtMeta('c1', {
        'cardNetwork': 'visa',
        'last4': '1234',
        'accountHolderName': 'Carla',
        // These must be ignored: a patch is not a way to move money or rename.
        'remaining': 0,
        'id': 'hacked',
        'name': 'not this',
      });
      final d = (store.data['debts'] as List).first as Map;
      expect(d['cardNetwork'], 'visa');
      expect(d['last4'], '1234');
      expect(d['accountHolderName'], 'Carla');
      expect(d['remaining'], 12480.40, reason: 'remaining is not patchable');
      expect(d['id'], 'c1', reason: 'id is not patchable');
      expect(d['name'], 'BPI card', reason: 'name is not patchable');
    });
  });

  group('card_products catalogue', () {
    test('every issuer network id resolves to a known network', () {
      for (final p in cardIssuers) {
        for (final n in p.networks) {
          expect(
            cardNetworkById(n),
            isNotNull,
            reason: '${p.institutionId} lists unknown network $n',
          );
        }
      }
    });

    test('every issuer product id is storable (^[a-z0-9_]+)', () {
      final re = RegExp(r'^[a-z0-9_]{1,64}$');
      for (final p in cardIssuers) {
        for (final prod in p.products) {
          expect(
            re.hasMatch(prod.id),
            isTrue,
            reason: '${p.institutionId}/${prod.id} is not a storable id',
          );
        }
      }
    });

    test('an unlisted issuer still offers every network and no tier', () {
      expect(networksForIssuer('gcash').length, cardNetworks.length);
      expect(tiersForIssuer('gcash'), isEmpty);
      expect(issuerOffersCreditCards('gcash'), isFalse);
    });

    test('a listed issuer resolves its product labels', () {
      expect(cardProductLabel('bpi', 'gold'), 'Gold Rewards');
      expect(cardProductLabel('bpi', 'nope'), isNull);
    });

    test('QR receiving is a known hint for wallets and banks, off for SeaBank', () {
      expect(institutionSupportsQrReceiving('gcash'), isTrue);
      expect(institutionSupportsQrReceiving('bpi'), isTrue);
      expect(institutionSupportsQrReceiving('seabank'), isFalse);
      expect(institutionSupportsQrReceiving('sss'), isFalse);
    });
  });

  group('QrVault', () {
    late Directory dir;
    late QrVault vault;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('qr_vault_test');
      vault = QrVault(dir.path);
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    Uint8List bytes(int n) => Uint8List.fromList(List.filled(n, 7));

    test('save writes a file with a legal reference', () async {
      final ref = await vault.save(bytes(64), ext: 'png', nonce: 'bpi-01');
      expect(isQrRef(ref), isTrue);
      expect(await vault.exists(ref), isTrue);
      expect(await vault.readBytes(ref), hasLength(64));
    });

    test('a hostile nonce cannot escape the vault folder', () async {
      final ref = await vault.save(bytes(8), ext: 'png', nonce: '../../etc/x');
      expect(isQrRef(ref), isTrue);
      expect(ref.contains('/'), isFalse);
      expect(ref.contains('..'), isFalse);
      // The file is inside the vault directory, nowhere else.
      expect(File('${dir.path}/$ref').existsSync(), isTrue);
    });

    test('empty, oversized, and wrong-type images are refused', () async {
      expect(
        () => vault.save(bytes(0), ext: 'png', nonce: 'a'),
        throwsA(isA<QrSaveException>()),
      );
      expect(
        () => vault.save(bytes(kQrMaxBytes + 1), ext: 'png', nonce: 'a'),
        throwsA(isA<QrSaveException>()),
      );
      expect(
        () => vault.save(bytes(8), ext: 'gif', nonce: 'a'),
        throwsA(isA<QrSaveException>()),
      );
    });

    test('remove deletes the file and is a no-op when already gone', () async {
      final ref = await vault.save(bytes(8), ext: 'png', nonce: 'a');
      await vault.remove(ref);
      expect(await vault.exists(ref), isFalse);
      await vault.remove(ref); // no throw
    });

    test('cleanupOrphans removes unreferenced files and keeps referenced ones',
        () async {
      final kept = await vault.save(bytes(8), ext: 'png', nonce: 'keep');
      final orphan = await vault.save(bytes(8), ext: 'png', nonce: 'orphan');
      final removed = await vault.cleanupOrphans({kept});
      expect(removed, 1);
      expect(await vault.exists(kept), isTrue);
      expect(await vault.exists(orphan), isFalse);
    });

    test('qrRefsInData collects references across collections', () {
      final refs = qrRefsInData({
        'accounts': [
          {'id': 'a', 'qrRef': 'qr_a.png'},
          {'id': 'b'},
        ],
        'debts': [
          {'id': 'c', 'qrRef': 'qr_c.jpg'},
          {'id': 'd', 'qrRef': 'not a ref'},
        ],
      });
      expect(refs, {'qr_a.png', 'qr_c.jpg'});
    });

    test('pathFor refuses a reference that is not a legal filename', () {
      expect(vault.pathFor('../x.png'), isNull);
      expect(vault.pathFor('qr_ok.png'), '${dir.path}/qr_ok.png');
    });
  });
}
