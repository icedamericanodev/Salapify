// Phase 4 batch 4, Accounts says own vs owe:
//  1. The flip card's FRONT never shows the stored digits; the same four sit
//     behind device auth on the back, and a front saying them out loud made
//     that auth theater.
//  2. An e-wallet card carries no payment-card furniture: no contactless
//     mark, no fabricated masked number.
//  3. The Accounts list carries the WHAT YOU OWN / WHAT YOU OWE
//     superstructure, so the class boundary is words, not tint.
//  4. The credit card face says YOU OWE, not banker jargon, and the
//     utilization bar says "Getting full" in words when it warns, and stays
//     quiet when it should (both halves of the alarm).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:salapify/widgets/bank_card.dart';
import 'package:salapify/widgets/flip_bank_card.dart';
import 'package:salapify/widgets/salapify_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The card face is a fixed-aspect layout, so these tests judge it in the
// shipped font: Flutter's default test font is taller and wider than
// Jakarta, and the credit face overflows by 9px in a font the phone never
// draws (the CLAUDE.md font rule).
import 'screens_shot.dart' show loadRealFonts;

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 390, height: 280, child: child)),
  ),
);

void main() {
  testWidgets('the card front never shows the stored digits', (tester) async {
    await loadRealFonts(tester);
    await tester.pumpWidget(
      _host(
        FlipBankCard(
          row: const {'id': 'c1'},
          vault: null,
          bankName: 'BPI Savings',
          accountType: 'Savings',
          last4: '4821',
          balance: 48500,
          flipped: false,
          showHint: false,
          onFlip: (_) {},
          onViewFullDetails: () {},
          onEdit: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('4821'),
      findsNothing,
      reason:
          'the digits live behind the reveal; the front shows dots only, '
          'or the biometric gate is theater',
    );
  });

  testWidgets('a wallet card carries no payment-card furniture', (
    tester,
  ) async {
    await loadRealFonts(tester);
    await tester.pumpWidget(
      _host(
        BankCard(
          bankName: 'GCash',
          accountType: 'E-wallet',
          balance: 1785,
          isWallet: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(salapifyIcon('contactless')), findsNothing);
    expect(
      find.textContaining('••••'),
      findsNothing,
      reason: 'a wallet has no PAN, so sixteen fabricated dots lied a little',
    );
    // The same card as a bank keeps the furniture, so the suppression is the
    // wallet flag and not a broken card face.
    await tester.pumpWidget(
      _host(BankCard(bankName: 'BPI', accountType: 'Savings', balance: 48500)),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(salapifyIcon('contactless')), findsOneWidget);
  });

  testWidgets('each category group carries its own asset-or-owed class cue', (
    tester,
  ) async {
    // The own/owe superstructure survived the move from category tabs to the
    // expandable groups: a liability group states its owed class both by a minus
    // sign on its total (never colour alone) and by living behind the
    // Liabilities filter, so the asset-liability boundary is legible without
    // colour, and the class filter narrows the accordion to one side at a time.
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 3000},
        ],
        'debts': [
          {
            'id': 'd1',
            'name': 'BPI card',
            'type': 'credit card',
            'remaining': 12000,
            'monthlyRate': 3,
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await store.load();
    // A tall surface so the whole screen builds and the filter chips (which sit
    // above the ACCOUNTS OVERVIEW kicker) are on-screen and tappable without
    // fragile scrolling.
    tester.view.physicalSize = const Size(1170, 6000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: AccountsScreen(store: store)));
    await tester.pumpAndSettle();
    // Both a cash (asset) group and a credit (liability) group exist. The
    // liability group's total carries a minus sign, the colour-independent owed
    // cue.
    expect(find.text('Cash & Bank'), findsOneWidget);
    expect(find.text('Credit Cards'), findsOneWidget);
    expect(find.text('-₱12,000'), findsOneWidget);
    // Filter to Liabilities: the asset group drops out, the liability group
    // stays. The chip text repeats the hero's "Liabilities" label, so target the
    // keyed filter chip, not the text.
    await tester.ensureVisible(
      find.byKey(const ValueKey('accounts-filter-liabilities')),
    );
    await tester.tap(find.byKey(const ValueKey('accounts-filter-liabilities')));
    await tester.pumpAndSettle();
    expect(find.text('Cash & Bank'), findsNothing);
    expect(find.text('Credit Cards'), findsOneWidget);
    // Expanding it reveals the debt, drawn as its credit card.
    await tester.tap(find.text('Credit Cards'));
    await tester.pumpAndSettle();
    expect(find.text('BPI card'), findsWidgets);
  });

  testWidgets('the credit face says YOU OWE and warns in words only when '
      'the card is getting full', (tester) async {
    await tester.pumpWidget(
      _host(
        BankCard(
          bankName: 'BPI',
          accountType: 'Credit',
          balance: 8000,
          creditLimit: 10000,
          variant: BankCardVariant.credit,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('YOU OWE'), findsOneWidget);
    expect(find.text('OUTSTANDING'), findsNothing);
    expect(find.text('Getting full'), findsOneWidget, reason: '80 percent');

    await tester.pumpWidget(
      _host(
        BankCard(
          bankName: 'BPI',
          accountType: 'Credit',
          balance: 3000,
          creditLimit: 10000,
          variant: BankCardVariant.credit,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Getting full'),
      findsNothing,
      reason:
          'an alarm that cries wolf at 30 percent gets its battery taken '
          'out; the quiet half matters as much as the loud one',
    );
  });
}
