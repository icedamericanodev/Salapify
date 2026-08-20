// The floating 3D card: tap unmasks the last four and taps again to hide, a
// null number never reveals, the skin seed reaches the face, and reduced motion
// simply turns the tilt off without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/bank_card.dart';
import 'package:salapify/widgets/floating_pan_card.dart';
import 'package:salapify/widgets/lock_gate.dart' show LockAuthenticator;

// A phone that cannot lock, so reveal proceeds without a biometric prompt (the
// real channel does not exist in a test). The auth path itself is covered by
// the flip card's tests, which share the same LockAuthenticator contract.
class _NoLockAuth implements LockAuthenticator {
  @override
  Future<bool> canLock() async => false;
  @override
  Future<bool> authenticate() async => true;
}

// A phone that CAN lock and refuses the prompt, to prove reveal is gated.
class _DenyAuth implements LockAuthenticator {
  int prompts = 0;
  @override
  Future<bool> canLock() async => true;
  @override
  Future<bool> authenticate() async {
    prompts++;
    return false;
  }
}

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 320,
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: child,
        ),
      ),
    ),
  ),
);

void main() {
  setUp(() {
    Barako.currentTheme = barakoThemes.first;
    Barako.current = barakoThemes.first.dark;
  });

  testWidgets('tap reveals the last four, tap again hides them', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FloatingPanCard(
          bankName: 'BPI Credit',
          accountType: 'Credit',
          balance: 42000,
          last4: '4821',
          variant: BankCardVariant.credit,
          authenticator: _NoLockAuth(),
        ),
      ),
    );
    // Masked to begin with.
    expect(find.text('4821'), findsNothing);

    await tester.tap(find.byType(FloatingPanCard));
    await tester.pump();
    expect(find.text('4821'), findsOneWidget);

    await tester.tap(find.byType(FloatingPanCard));
    await tester.pump();
    expect(find.text('4821'), findsNothing);
  });

  testWidgets('a refused device auth does not reveal the last four', (
    tester,
  ) async {
    final auth = _DenyAuth();
    await tester.pumpWidget(
      _host(
        FloatingPanCard(
          bankName: 'BPI Credit',
          accountType: 'Credit',
          balance: 42000,
          last4: '4821',
          variant: BankCardVariant.credit,
          authenticator: auth,
        ),
      ),
    );
    await tester.tap(find.byType(FloatingPanCard));
    await tester.pumpAndSettle();
    // It asked, was refused, and stayed masked: parity with the flip card.
    expect(auth.prompts, 1);
    expect(find.text('4821'), findsNothing);
  });

  testWidgets('a card with no stored number never reveals digits', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FloatingPanCard(
          bankName: 'Cash',
          accountType: 'Cash',
          balance: 2000,
          last4: null,
          authenticator: _NoLockAuth(),
        ),
      ),
    );
    await tester.tap(find.byType(FloatingPanCard));
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text && w.data != null && RegExp(r'^\d{4}$').hasMatch(w.data!),
      ),
      findsNothing,
    );
  });

  testWidgets('the skin seed overrides the brand colour on the face', (
    tester,
  ) async {
    const seed = Color(0xFF0E7C5A);
    await tester.pumpWidget(
      _host(
        const FloatingPanCard(
          bankName: 'BPI Credit',
          accountType: 'Credit',
          balance: 1000,
          brandColor: Color(0xFFAB0033),
          skinSeed: seed,
          variant: BankCardVariant.credit,
        ),
      ),
    );
    final card = tester.widget<BankCard>(find.byType(BankCard));
    expect(card.brandColor, seed);
  });

  testWidgets('reduced motion disables the tilt without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FloatingPanCard(
          bankName: 'BPI Credit',
          accountType: 'Credit',
          balance: 1000,
          last4: '4821',
          variant: BankCardVariant.credit,
          authenticator: _NoLockAuth(),
        ),
        reduceMotion: true,
      ),
    );
    // A drag does nothing under reduced motion, and tap-to-unmask still works.
    await tester.drag(find.byType(FloatingPanCard), const Offset(60, 20));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(FloatingPanCard));
    await tester.pump();
    expect(find.text('4821'), findsOneWidget);
  });
}
