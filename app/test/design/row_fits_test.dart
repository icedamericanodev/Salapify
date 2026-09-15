// A row of money must FIT the narrowest phone we support.
//
// This exists because adding a chevron to `ItemRow` cost 20 logical pixels of
// width, and a QA pass measured an account row that fit before the change and
// overflowed after it at 320dp with an ordinary savings balance. In debug that
// is the striped banner nobody ships; in RELEASE the overflow is silent and the
// amount is simply clipped, which puts a wrong peso figure on screen. A finance
// app cannot do that, so this measures rather than trusts.
//
// Real fonts are loaded first, deliberately. Flutter's default test font is
// wider than Plus Jakarta Sans, the face the app actually ships, so a width
// judgement made without them is a judgement about a font the founder never
// sees. That is a rule in CLAUDE.md and it is exactly the class of test it was
// written for.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// The narrowest screen Salapify supports, minus what the page and the card
/// already take: `Screen`'s gutter each side and `Group`'s 16.
///
/// 22, not 20. `tokens.dart` defines `gutter = 22` and the first version of
/// this file assumed 20, which made the guard four points MORE generous than
/// the phone it is guarding. A width test that measures a wider screen than
/// exists passes for a reason unrelated to what the founder sees.
const _narrowest = 320.0 - (gutter * 2) - 32;

/// Renders one row at a fixed width and returns how far it overflowed, or zero.
Future<double> _overflow(
  WidgetTester tester,
  ItemRow row, {
  double textScale = 1.0,
}) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;

  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(gabi),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Center(
            child: SizedBox(width: _narrowest, child: row),
          ),
        ),
      ),
    ),
  );

  FlutterError.onError = previous;

  // Flutter reports an overflow as an exception carrying the pixel count in
  // its message, which is the only place the number is exposed.
  for (final e in errors) {
    final text = e.exception.toString();
    final m = RegExp(r'overflowed by ([\d.]+) pixels').firstMatch(text);
    if (m != null) return double.parse(m.group(1)!);
  }
  return 0;
}

void main() {
  setUpAll(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.runAsync(loadRealFonts);
  });

  testWidgets('an ordinary bank balance fits a 320dp phone', (tester) async {
    // 142,300 is not an extreme figure. It is a savings balance, and it is the
    // exact case the chevron broke.
    expect(
      await _overflow(
        tester,
        const ItemRow(
          monogram: 'UB',
          title: 'Payroll',
          sub: 'BPI, Savings account',
          amount: '₱142,300.00',
        ),
      ),
      0,
      reason: 'a plain savings balance no longer fits the narrowest phone',
    );
  });

  testWidgets('and it still fits once the row is TAPPABLE', (tester) async {
    // The regression, in one test. Same row, same width, plus the chevron.
    expect(
      await _overflow(
        tester,
        ItemRow(
          monogram: 'UB',
          title: 'Payroll',
          sub: 'BPI, Savings account',
          amount: '₱142,300.00',
          onTap: () {},
        ),
      ),
      0,
      reason:
          'the chevron pushed the amount past the edge of the screen, so a '
          'release build would clip the money rather than show it',
    );
  });

  testWidgets('a millionaire and a long name still fit', (tester) async {
    expect(
      await _overflow(
        tester,
        ItemRow(
          monogram: 'BP',
          title: 'BPI Family Savings Account',
          sub: 'Savings account',
          amount: '₱1,142,300.00',
          amountSub: 'as of today',
          onTap: () {},
        ),
      ),
      0,
      reason: 'a seven figure balance is clipped on a narrow phone',
    );
  });

  testWidgets('and at 1.3x system text, which many people run', (tester) async {
    expect(
      await _overflow(
        tester,
        ItemRow(
          icon: Icons.receipt_long_outlined,
          title: 'Groceries',
          sub: 'GCash',
          amount: '-₱4,120.00',
          onTap: () {},
        ),
        textScale: 1.3,
      ),
      0,
      reason:
          'larger system text clipped the amount, and the people who turn it '
          'up are the people who most need to read the number',
    );
  });
}
