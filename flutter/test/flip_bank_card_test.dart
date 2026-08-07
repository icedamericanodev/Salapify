// The flip bank card, tested the way the spec asked for: tap to flip, flip
// back, front and back content, masked by default, reveal only after device
// auth (and NOT after a failed or cancelled auth), auto-remask on a timer and
// on backgrounding, one card flipped at a time, reduced motion, large text,
// screen-reader labels, a credit card never exposing more than its last four,
// the QR shortcut appearing only when a QR exists, and a height that does not
// jump mid-flip.
//
// The reveal path mirrors AccountDetailScreen, so a fake authenticator stands
// in for the platform channel (there is none in a test), exactly as the detail
// screen's own tests do.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/bank_card.dart';
import 'package:salapify/widgets/flip_bank_card.dart';
import 'package:salapify/widgets/lock_gate.dart' show LockAuthenticator;

import 'screens_shot.dart' show loadRealFonts;

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

/// An authenticator whose result is held open until the test releases it, so a
/// flip-back can be staged WHILE the auth prompt is still pending.
class _GatedAuth implements LockAuthenticator {
  final Completer<bool> gate = Completer<bool>();
  @override
  Future<bool> canLock() async => true;
  @override
  Future<bool> authenticate() => gate.future;
}

/// Hosts one card and owns its flip state, the same contract the carousel
/// gives a card: the PARENT flips, the card only asks.
class _Host extends StatefulWidget {
  final FlipBankCard Function(bool flipped, ValueChanged<bool> onFlip) builder;
  const _Host(this.builder);
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool _flipped = false;
  @override
  Widget build(BuildContext context) =>
      widget.builder(_flipped, (v) => setState(() => _flipped = v));
}

/// Hosts two cards sharing ONE flip index, exactly as the carousel does, so
/// "only one card flipped at a time" can be observed.
class _MultiHost extends StatefulWidget {
  const _MultiHost();
  @override
  State<_MultiHost> createState() => _MultiHostState();
}

class _MultiHostState extends State<_MultiHost> {
  int? _flipped;
  void _flip(int i, bool want) => setState(() => _flipped = want ? i : null);

  FlipBankCard _card(int i, String bank, String last4) => FlipBankCard(
    key: ValueKey(bank),
    row: {'id': bank, 'name': bank, 'last4': last4, 'target': 0, 'qrRef': ''},
    bankName: bank,
    accountType: 'Savings',
    brandColor: const Color(0xFFB11116),
    last4: last4,
    balance: 1000,
    flipped: _flipped == i,
    onFlip: (want) => _flip(i, want),
    onViewFullDetails: () {},
    onEdit: () {},
    authenticator: _FakeAuth(can: false),
  );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(width: 320, child: _card(0, 'BPI Savings', '1234')),
      const SizedBox(height: 12),
      SizedBox(width: 320, child: _card(1, 'BDO Savings', '5678')),
    ],
  );
}

/// A savings card whose flip state a [_Host] owns.
FlipBankCard _savings(
  bool flipped,
  ValueChanged<bool> onFlip, {
  LockAuthenticator? auth,
  VoidCallback? onOpen,
  VoidCallback? onEdit,
  bool showHint = false,
  String qrRef = '',
}) => FlipBankCard(
  row: {
    'id': 'bpi',
    'name': 'BPI Savings',
    'last4': '1234',
    'target': 10000,
    'qrRef': qrRef,
    if (qrRef.isNotEmpty) 'qrLabel': 'My receiving QR',
    'paymentInstructions': 'Send to my BPI account.',
  },
  bankName: 'BPI Savings',
  accountType: 'Savings',
  brandColor: const Color(0xFFB11116),
  last4: '1234',
  balance: 48500.55,
  variant: BankCardVariant.savings,
  flipped: flipped,
  onFlip: onFlip,
  onViewFullDetails: onOpen ?? () {},
  onEdit: onEdit ?? () {},
  showHint: showHint,
  authenticator: auth ?? _FakeAuth(can: false),
);

/// A credit card, fixed at a given flip state (no host needed for reveal).
FlipBankCard _credit(bool flipped, {LockAuthenticator? auth}) => FlipBankCard(
  row: {
    'id': 'card',
    'name': 'BPI Card',
    'last4': '9012',
    'creditLimit': 50000,
    'dueDay': 15,
    'statementDay': 2,
    'qrRef': '',
  },
  bankName: 'BPI Card',
  accountType: 'Credit',
  brandColor: const Color(0xFFB11116),
  last4: '9012',
  balance: 42000,
  creditLimit: 50000,
  networkMark: 'VISA',
  variant: BankCardVariant.credit,
  flipped: flipped,
  onFlip: (_) {},
  onViewFullDetails: () {},
  onEdit: () {},
  authenticator: auth ?? _FakeAuth(can: false),
);

/// Pump one card on a dark surface. [reduceMotion] and [textScale] are applied
/// through a MediaQuery BELOW MaterialApp, since MaterialApp installs its own
/// from the view and would otherwise overwrite anything placed above it.
Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  bool reduceMotion = false,
  double textScale = 1.0,
  double width = 360,
}) async {
  Barako.current = Barako.currentTheme.resolve(Brightness.dark);
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (ctx) {
              var data = MediaQuery.of(ctx);
              if (reduceMotion) data = data.copyWith(disableAnimations: true);
              if (textScale != 1.0) {
                data = data.copyWith(textScaler: TextScaler.linear(textScale));
              }
              return MediaQuery(
                data: data,
                child: SizedBox(width: width, child: card),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _masked = '•••• ••••';
const _revealed = '•••• 1234';

void main() {
  testWidgets('tap flips the card to its back', (tester) async {
    await _pump(tester, _Host((f, on) => _savings(f, on)));
    // 'NUMBER' is a back-only label, so its absence is a clean "front showing".
    expect(find.text('NUMBER'), findsNothing);
    await tester.tap(find.byType(FlipBankCard));
    await tester.pumpAndSettle();
    expect(find.text('NUMBER'), findsOneWidget); // back now
  });

  testWidgets('tapping the back flips it to the front', (tester) async {
    await _pump(tester, _Host((f, on) => _savings(f, on)));
    await tester.tap(find.byType(FlipBankCard));
    await tester.pumpAndSettle();
    expect(find.text('NUMBER'), findsOneWidget);
    await tester.tap(find.byType(FlipBankCard));
    await tester.pumpAndSettle();
    expect(find.text('NUMBER'), findsNothing);
  });

  testWidgets('a tap mid-flip is ignored, the card still lands on its back', (
    tester,
  ) async {
    await _pump(tester, _Host((f, on) => _savings(f, on)));
    await tester.tap(find.byType(FlipBankCard));
    await tester.pump(const Duration(milliseconds: 120)); // mid-animation
    await tester.tap(find.byType(FlipBankCard)); // should be ignored
    await tester.pumpAndSettle();
    // If the second tap had registered it would have flipped back to the front.
    expect(find.text('NUMBER'), findsOneWidget);
  });

  testWidgets('the front shows the balance, the back shows the details', (
    tester,
  ) async {
    await _pump(tester, _Host((f, on) => _savings(f, on)));
    // Front (the reused BankCard): the bank name is shown.
    expect(find.text('BPI Savings'), findsOneWidget);
    // Back-only labels are absent on the front.
    expect(find.text('NUMBER'), findsNothing);
    expect(find.text('MAINTAINING'), findsNothing);
    await tester.tap(find.byType(FlipBankCard));
    await tester.pumpAndSettle();
    // Back: number row, balance, the maintaining target, and the exit action.
    expect(find.text('NUMBER'), findsOneWidget);
    expect(find.text('MAINTAINING'), findsOneWidget);
    expect(find.text('View full details'), findsOneWidget);
  });

  testWidgets('the number is masked by default on the back', (tester) async {
    await _pump(tester, _credit(true));
    expect(find.text(_masked), findsOneWidget);
    expect(find.text(_revealed), findsNothing);
  });

  testWidgets('a successful auth reveals only the last four', (tester) async {
    final auth = _FakeAuth(can: true, ok: true);
    await _pump(tester, _Host((f, on) => _savings(f, on, auth: auth)));
    await tester.tap(find.byType(FlipBankCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reveal the last four digits'));
    await tester.pumpAndSettle();
    expect(auth.prompts, 1);
    expect(find.text(_revealed), findsOneWidget);
    expect(find.text(_masked), findsNothing);
  });

  testWidgets('a failed or cancelled auth does NOT reveal', (tester) async {
    final auth = _FakeAuth(can: true, ok: false);
    await _pump(tester, _Host((f, on) => _savings(f, on, auth: auth)));
    await tester.tap(find.byType(FlipBankCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reveal the last four digits'));
    await tester.pumpAndSettle();
    expect(auth.prompts, 1);
    expect(find.text(_masked), findsOneWidget);
    expect(find.text(_revealed), findsNothing);
  });

  testWidgets('a revealed number re-masks itself after the timeout', (
    tester,
  ) async {
    await _pump(tester, _credit(true, auth: _FakeAuth(can: false)));
    await tester.tap(find.byTooltip('Reveal the last four digits'));
    await tester.pumpAndSettle();
    expect(find.text('•••• 9012'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(find.text('•••• 9012'), findsNothing);
    expect(find.text(_masked), findsOneWidget);
  });

  testWidgets('backgrounding the app re-masks a revealed number', (
    tester,
  ) async {
    await _pump(tester, _credit(true, auth: _FakeAuth(can: false)));
    await tester.tap(find.byTooltip('Reveal the last four digits'));
    await tester.pumpAndSettle();
    expect(find.text('•••• 9012'), findsOneWidget);
    // resumed -> inactive is the first valid step of leaving the foreground; the
    // card re-masks on any non-resumed state, so this is the moment digits go.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('•••• 9012'), findsNothing);
  });

  testWidgets('a reveal finishing after a flip-back does not reveal', (
    tester,
  ) async {
    final auth = _GatedAuth();
    await _pump(tester, _Host((f, on) => _savings(f, on, auth: auth)));
    await tester.tap(find.byType(FlipBankCard)); // flip to the back
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reveal the last four digits'));
    await tester.pump(); // canLock resolves; parked on the pending auth
    await tester.tap(find.byType(FlipBankCard)); // flip back to the front
    await tester.pumpAndSettle();
    auth.gate.complete(true); // auth now resolves, on a front-facing card
    await tester.pumpAndSettle();
    // Flip to the back again: still masked, the stale auth did not leak through.
    await tester.tap(find.byType(FlipBankCard));
    await tester.pumpAndSettle();
    expect(find.text(_revealed), findsNothing);
    expect(find.text(_masked), findsOneWidget);
  });

  testWidgets('only one card is flipped at a time', (tester) async {
    // Two cards on screen: this measures layout, so load the shipped font.
    await loadRealFonts(tester);
    await _pump(tester, const _MultiHost(), width: 360);
    // Flip the first card.
    await tester.tap(find.byType(FlipBankCard).at(0));
    await tester.pumpAndSettle();
    expect(find.text('NUMBER'), findsOneWidget);
    // Flip the second: the first must return to its front, so still one back.
    await tester.tap(find.byType(FlipBankCard).at(1));
    await tester.pumpAndSettle();
    expect(find.text('NUMBER'), findsOneWidget);
  });

  testWidgets('reduced motion still flips both ways', (tester) async {
    await _pump(
      tester,
      _Host((f, on) => _savings(f, on)),
      reduceMotion: true,
    );
    await tester.tap(find.byType(FlipBankCard));
    await tester.pumpAndSettle();
    expect(find.text('NUMBER'), findsOneWidget);
    await tester.tap(find.byType(FlipBankCard));
    await tester.pumpAndSettle();
    expect(find.text('NUMBER'), findsNothing);
  });

  testWidgets('the back survives large system text without overflowing', (
    tester,
  ) async {
    // Layout that judges overflow must use the shipped font, not the wider
    // test default, per the repo rule.
    await loadRealFonts(tester);
    await _pump(tester, _credit(true), textScale: 2.0);
    expect(tester.takeException(), isNull);
    expect(find.text('NUMBER'), findsOneWidget);
    expect(find.text('OUTSTANDING'), findsOneWidget);
  });

  testWidgets('the card carries a screen-reader label for the flip action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _Host((f, on) => _savings(f, on)));
    expect(find.bySemanticsLabel(RegExp('Tap to flip')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a credit card never renders more than its last four', (
    tester,
  ) async {
    await _pump(tester, _credit(true, auth: _FakeAuth(can: false)));
    await tester.tap(find.byTooltip('Reveal the last four digits'));
    await tester.pumpAndSettle();
    // Revealed shows exactly the last four, behind the mask prefix.
    expect(find.text('•••• 9012'), findsOneWidget);
    // And nowhere in the tree is there a run of five or more digits, so a full
    // card number can never appear, by contract and in the render.
    final runs = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => RegExp(r'\d{5,}').hasMatch(s))
        .toList();
    expect(runs, isEmpty);
  });

  testWidgets('the QR shortcut shows only when a QR is saved', (tester) async {
    // No QR saved: no QR button.
    await _pump(tester, _Host((f, on) => _savings(f, on)));
    await tester.tap(find.byType(FlipBankCard));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show the receiving QR code'), findsNothing);
  });

  testWidgets('the QR shortcut appears once a QR exists', (tester) async {
    await _pump(tester, _Host((f, on) => _savings(f, on, qrRef: 'bpi-qr.png')));
    await tester.tap(find.byType(FlipBankCard));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show the receiving QR code'), findsOneWidget);
  });

  testWidgets('the card height does not jump during the flip', (tester) async {
    await _pump(tester, _Host((f, on) => _savings(f, on)));
    final before = tester.getSize(find.byType(FlipBankCard));
    await tester.tap(find.byType(FlipBankCard));
    await tester.pump(const Duration(milliseconds: 210)); // mid-flip
    final middle = tester.getSize(find.byType(FlipBankCard));
    await tester.pumpAndSettle();
    final after = tester.getSize(find.byType(FlipBankCard));
    expect(middle.height, before.height);
    expect(after.height, before.height);
  });
}
