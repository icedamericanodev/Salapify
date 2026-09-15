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
import 'package:salapify/features/debt/debt_rows.dart';
import 'package:salapify/features/home/home_screen.dart' show shortDate;

import '../shots/screens_shot.dart' show loadRealFonts;

/// A debt row with only the fields the caption reads, so a case is one line.
DebtRow _row({
  String? nextDueIso,
  double paidSoFar = 0,
  double original = 0,
  bool settled = false,
  bool countsInTotal = true,
}) => DebtRow(
  id: 'x',
  name: 'Joy',
  remaining: original - paidSoFar,
  original: original,
  paidSoFar: paidSoFar,
  paymentCount: 0,
  nextDueIso: nextDueIso,
  settled: settled,
  source: DebtSource.receivables,
  countsInTotal: countsInTotal,
);

/// The narrowest screen Salapify supports, minus what the page and the card
/// already take: `Screen`'s gutter each side and `Group`'s 16.
///
/// 22, not 20. `tokens.dart` defines `gutter = 22` and the first version of
/// this file assumed 20, which made the guard four points MORE generous than
/// the phone it is guarding. A width test that measures a wider screen than
/// exists passes for a reason unrelated to what the founder sees.
const _narrowest = 320.0 - (gutter * 2) - 32;

/// Renders one row at the standard card width. See [_overflowOf].
Future<double> _overflow(
  WidgetTester tester,
  ItemRow row, {
  double textScale = 1.0,
}) => _overflowOf(tester, row, width: _narrowest, textScale: textScale);

/// Renders any widget at a fixed width and returns how far it overflowed.
///
/// The width is a parameter because not everything sits inside a card. A row
/// lives in a `Group` and loses its 16s; a `Head` sits on the page and only
/// loses the gutters.
Future<double> _overflowOf(
  WidgetTester tester,
  Widget child, {
  required double width,
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
            child: SizedBox(width: width, child: child),
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

  testWidgets('a long section head fits, and at 1.5x too', (tester) async {
    // `Head` put its title in a bare Text inside a Row, which cannot shrink.
    // Every head in the app was short enough to hide that until Upcoming grew
    // "Between now and Sep 30", which overflowed by 10 points at 320dp and
    // 1.5x and by 107 at 2.0x. Clipped with stripes in debug, silently cut off
    // in release.
    //
    // A head sits on the PAGE, not inside a card, so it only loses the gutters.
    for (final scale in [1.0, 1.3, 1.5]) {
      final over = await _overflowOf(
        tester,
        const Head(title: 'Between now and Sep 30'),
        width: 320.0 - (gutter * 2),
        textScale: scale,
      );
      expect(
        over,
        0,
        reason: 'the section head was clipped at ${scale}x on a 320dp phone',
      );
    }
  });

  testWidgets('and one with an action beside it', (tester) async {
    expect(
      await _overflowOf(
        tester,
        Head(title: 'Between now and Sep 30', action: 'Edit', onAction: () {}),
        width: 320.0 - (gutter * 2),
        textScale: 1.3,
      ),
      0,
      reason: 'the title and its action could not share the width',
    );
  });

  testWidgets('a debt row caption fits on ONE line on a real phone', (
    tester,
  ) async {
    // Not an overflow test, which is why it measures text rather than calling
    // `_overflow`. `ItemRow.sub` has no maxLines, so a caption that is too long
    // WRAPS instead of overflowing: nothing throws, nothing is clipped, and the
    // row silently grows a second line with an orphaned word on it.
    //
    // The Debt screen hit this. "₱1,800 of ₱3,000 paid · due Sep 25" wrapped on
    // a 412dp phone and left "25" alone on line two. The caption now carries
    // the due date and at most one other part, and this measures that rather
    // than trusting the eye that caught it.
    //
    // TWO earlier versions of this test were wrong, and BOTH passed. Written
    // down because the shape of each mistake is the useful part.
    //
    // The first did the arithmetic by hand: it rebuilt the caption's available
    // width out of the padding constants, guessed 92 points for the amount
    // column, and named the font 'PlusJakartaSans' when the app ships it as
    // 'Jakarta'. It measured a fallback font against an invented width.
    //
    // The second rendered the real row and read `getSize` off the ItemRow,
    // which returns the 600 point test VIEWPORT and not the row, so every
    // caption measured 600 and the test compared 600 against 600. It passed
    // with the known-broken caption fed straight into it, which is the result
    // CLAUDE.md says to read as proof that the TEST is wrong.
    //
    // This one measures the caption Text itself, where one line is 18 points,
    // so the number it reports IS the line count.
    //
    // AT A REAL PHONE WIDTH, not at 320dp, and that is a correction rather
    // than a concession. Measured at 320dp the account row's own shipped
    // caption "BPI, Savings account" is 36 points, so captions wrap there
    // throughout the app already. Demanding one line at 320dp would hold this
    // one screen to a rule no other list obeys, and the defect that prompted
    // this guard was on a 412dp phone anyway: that is what the render harness
    // draws and what the founder's emulator is.
    const phone = 412.0 - (gutter * 2) - 32;

    Future<double> heightOf(String sub) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(gabi),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: phone,
                child: ItemRow(
                  monogram: 'JO',
                  title: 'Joy',
                  sub: sub,
                  amount: '₱1,200.00',
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      return tester.getSize(find.text(sub)).height;
    }

    final oneLine = await heightOf('paid');
    expect(oneLine, 18.0, reason: 'the caption line height moved');

    // Captions built by the REAL function from REAL rows, not a hand-copied
    // list. `debtRowCaption` was extracted out of the widget for exactly this:
    // strings typed out beside the test stay green when somebody rewords the
    // screen, which is what makes a width guard decorative.
    final captions = [
      for (final row in [
        _row(nextDueIso: '2026-09-25', paidSoFar: 1800, original: 3000),
        _row(),
        _row(paidSoFar: 1800, original: 3000),
        _row(settled: true),
        // The longest a real row gets: untracked, with a date.
        _row(nextDueIso: '2026-12-31', countsInTotal: false),
      ])
        debtRowCaption(row, shortDate),
    ];

    // Did anything happen. An empty list fits perfectly and proves nothing.
    expect(captions, hasLength(5));
    expect(captions, everyElement(isNotEmpty));

    for (final caption in captions) {
      expect(
        await heightOf(caption),
        oneLine,
        reason:
            '"$caption" wrapped onto a second line on a 412dp phone, so the '
            'end of it sits alone under the row above',
      );
    }

    // The wording that actually shipped wrong, kept so this guard is provably
    // able to go red rather than passing on everything handed to it.
    expect(
      await heightOf('₱1,800 of ₱3,000 paid · due Sep 25'),
      greaterThan(oneLine),
      reason:
          'the caption that demonstrably wrapped on a 412dp phone now fits, so '
          'the loop above can no longer tell a caption that fits from one that '
          'does not',
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
