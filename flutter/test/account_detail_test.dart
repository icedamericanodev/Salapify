// The account detail screen, with the two behaviours that only a test can hold
// honest: the last four digits stay HIDDEN until the person authenticates, and
// they reveal once they do. An alarm that never sounds and one that always
// sounds are both broken, so both halves are asserted here.
//
// The authenticator is injected (LockAuthenticator), the same seam App Lock
// uses, because the real biometric channel does not exist in a widget test. The
// QR vault is injected at a temp folder for the same reason path_provider does
// not exist here.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/qr_vault.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/account_taxonomy.dart' show AccountStore;
import 'package:salapify/screens/account_detail.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/lock_gate.dart' show LockAuthenticator;
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth implements LockAuthenticator {
  bool can;
  bool ok;
  int prompts = 0;
  _FakeAuth({this.can = true, this.ok = true});

  @override
  Future<bool> canLock() async => can;

  @override
  Future<bool> authenticate() async {
    prompts++;
    return ok;
  }
}

Map<String, dynamic> _blob({String? last4, String? qrRef}) => {
  'schemaVersion': 12,
  'accounts': [
    {
      'id': 'bpi',
      'name': 'Payroll Account',
      'kind': 'savings',
      'balance': 50000,
      'institutionId': 'bpi',
      'subtype': 'savings_account',
      'last4': ?last4,
      'qrRef': ?qrRef,
      if (qrRef != null) 'qrLabel': 'My BPI receiving QR',
    },
  ],
  'transactions': [
    {
      'id': 't1',
      'type': 'income',
      'accountId': 'bpi',
      'amount': 25000,
      'label': 'Salary',
      'date': '2026-08-01',
    },
  ],
  'debts': [],
  'payments': [],
};

Future<SalapifyStore> _load(Map<String, dynamic> blob) async {
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
  final s = SalapifyStore();
  await s.load();
  return s;
}

Future<void> _pump(
  WidgetTester tester,
  SalapifyStore store, {
  required Directory dir,
  required LockAuthenticator auth,
  bool settle = true,
}) async {
  // A tall surface so the whole ListView (secure section, QR, history) is built
  // and findable; the default 800x600 leaves the lower sections below the fold
  // and unbuilt, which is not the same as absent.
  tester.view.physicalSize = const Size(1200, 3400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  Barako.current = Barako.currentTheme.resolve(Brightness.dark);
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      home: AccountDetailScreen(
        store: store,
        id: 'bpi',
        accountStore: AccountStore.accounts,
        vault: QrVault(dir.path),
        authenticator: auth,
      ),
    ),
  );
  // A real image decodes on the platform thread, which pumpAndSettle's fake
  // clock never advances, so a screen carrying a decodable QR must pump plain
  // frames instead of settling or it waits for the ten-minute timeout.
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('acct_detail_test');
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  testWidgets('the last four are masked until the person authenticates', (
    tester,
  ) async {
    final store = await _load(_blob(last4: '4821'));
    final auth = _FakeAuth(can: true, ok: true);
    await _pump(tester, store, dir: dir, auth: auth);

    // Masked by default: the digits are nowhere on screen, not on the hero card
    // and not in the secure section.
    expect(find.textContaining('4821'), findsNothing);
    expect(find.text('Reveal'), findsOneWidget);

    await tester.tap(find.text('Reveal'));
    await tester.pumpAndSettle();

    expect(auth.prompts, 1, reason: 'a reveal must ask the phone to authenticate');
    // Revealed: the digits show in the secure row AND on the hero card.
    expect(find.textContaining('4821'), findsWidgets);
    expect(find.text('Hide'), findsOneWidget);

    // Hide re-masks and cancels the auto-hide timer (a test flags any timer
    // still pending at teardown), and proves the toggle closes as well as opens.
    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();
    expect(find.textContaining('4821'), findsNothing);
  });

  testWidgets('a denied authentication keeps the digits hidden', (tester) async {
    final store = await _load(_blob(last4: '4821'));
    final auth = _FakeAuth(can: true, ok: false);
    await _pump(tester, store, dir: dir, auth: auth);

    await tester.tap(find.text('Reveal'));
    await tester.pumpAndSettle();

    expect(auth.prompts, 1);
    expect(find.textContaining('4821'), findsNothing,
        reason: 'the reveal must stay silent when auth is refused');
    expect(find.text('Reveal'), findsOneWidget);
  });

  testWidgets('a phone with no lock still lets its owner see their own digits', (
    tester,
  ) async {
    final store = await _load(_blob(last4: '4821'));
    final auth = _FakeAuth(can: false, ok: false);
    await _pump(tester, store, dir: dir, auth: auth);

    await tester.tap(find.text('Reveal'));
    await tester.pumpAndSettle();

    expect(auth.prompts, 0, reason: 'no biometrics means nothing to prompt');
    expect(find.textContaining('4821'), findsWidgets);

    // Cancel the auto-hide timer before teardown.
    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();
  });

  testWidgets('with no digits saved, the secure section says so and cannot reveal',
      (tester) async {
    final store = await _load(_blob());
    await _pump(tester, store, dir: dir, auth: _FakeAuth());
    expect(find.text('Reveal'), findsNothing);
    expect(find.textContaining('No digits saved'), findsOneWidget);
  });

  testWidgets('the QR section offers to add one when empty', (tester) async {
    final store = await _load(_blob());
    await _pump(tester, store, dir: dir, auth: _FakeAuth());
    expect(find.text('Add a QR image'), findsOneWidget);
    // The privacy line is present exactly where the control is.
    expect(
      find.textContaining('stays on your device'),
      findsOneWidget,
    );
  });

  testWidgets('a saved QR shows View, Replace and Remove', (tester) async {
    // A real, decodable 1x1 PNG so the thumbnail's Image.memory does not error.
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    final vault = QrVault(dir.path);
    final ref = await vault.save(png, ext: 'png', nonce: 'bpi');
    final store = await _load(_blob(qrRef: ref));
    // settle:false, because the thumbnail decodes a real image (see _pump).
    await _pump(tester, store, dir: dir, auth: _FakeAuth(), settle: false);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('My BPI receiving QR'), findsOneWidget);
  });

  testWidgets('archive from the menu flags the row and shows the banner', (
    tester,
  ) async {
    final store = await _load(_blob(last4: '4821'));
    await _pump(tester, store, dir: dir, auth: _FakeAuth());

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    final acct = (store.data['accounts'] as List).first as Map;
    expect(acct['isArchived'], true);
    expect(find.textContaining('Archived'), findsOneWidget);
  });
}
