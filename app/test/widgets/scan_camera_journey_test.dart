import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/log/receipt_camera.dart';
import 'package:salapify/features/log/scan_receipt_sheet.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// Photographing a receipt, and every way that can go wrong.
///
/// The camera, the photo library and the ML Kit reader cannot run in a widget
/// test, so `ScanReceiptSheet` takes a `ReceiptTextSource` and the fake below
/// stands in for all three. What is under test is everything on THIS side of
/// those plugins: the handover, the two failures, backing out, and the rule
/// that a scan fills the form in without ever writing to the ledger by
/// itself.
///
/// What is deliberately NOT under test here is what a receipt MEANS. That is
/// `parseReceiptText`, which has its own vectors, and the camera path calls
/// exactly the same function the paste box does.
class _FakeCamera implements ReceiptTextSource {
  _FakeCamera(this._answer);

  /// What the next read returns. Null means the person backed out.
  final ReceiptRead? Function(ReceiptImageSource from) _answer;

  /// Every source it was asked for, in order, so a test can prove WHICH
  /// button it was. Two buttons wired to the same source is a real mistake
  /// and one that looks completely correct on screen.
  final List<ReceiptImageSource> asked = <ReceiptImageSource>[];

  @override
  Future<ReceiptRead?> read(ReceiptImageSource from) async {
    asked.add(from);
    return _answer(from);
  }
}

void main() {
  const String jollibee = '''
JOLLIBEE
SM NORTH EDSA
CHICKENJOY 1PC      82.00
JOLLY SPAGHETTI     65.00
TOTAL              147.00
''';

  Future<Transaction?> openSheet(
    WidgetTester tester,
    FinancialState state,
    ReceiptTextSource camera,
  ) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Palette p = Palette.of(state.theme);
    Transaction? logged;

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(p, state.theme),
        home: Scaffold(
          backgroundColor: p.background,
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                logged = await ScanReceiptSheet.show(
                  context,
                  p,
                  state,
                  camera: camera,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return logged;
  }

  FinancialState fresh() => FinancialState(clock: DateTime(2026, 9, 22, 10));

  testWidgets('a photographed receipt fills the form in', (
    WidgetTester tester,
  ) async {
    final _FakeCamera camera = _FakeCamera(
      (_) => const ReceiptRead.text(jollibee),
    );
    await openSheet(tester, fresh(), camera);

    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();

    expect(camera.asked, <ReceiptImageSource>[
      ReceiptImageSource.camera,
    ], reason: 'the camera button opened the photo library');

    // The FIGURES, which is what a person came here for.
    expect(find.text('Jollibee'), findsWidgets);
    expect(find.text('147.00'), findsWidgets);

    // AND the words it read, visible and editable. A scan that fills four
    // fields from text nobody can see is a scan nobody can check.
    expect(
      find.textContaining('CHICKENJOY'),
      findsWidgets,
      reason:
          'the text the reader saw is not on screen, so there is no way to '
          'tell a good read from a lucky one',
    );
  });

  testWidgets('the other button really does open the library', (
    WidgetTester tester,
  ) async {
    // The emulator cannot photograph a receipt: its back camera renders a
    // synthetic room. Choosing an image is the only path that can be tried
    // anywhere but a real phone, so a copy-paste that wired both buttons to
    // the camera would take the testable half away and look perfect.
    final _FakeCamera camera = _FakeCamera(
      (_) => const ReceiptRead.text(jollibee),
    );
    await openSheet(tester, fresh(), camera);

    await tester.tap(find.text('Choose an image'));
    await tester.pumpAndSettle();

    expect(camera.asked, <ReceiptImageSource>[ReceiptImageSource.library]);
  });

  testWidgets('backing out of the camera says nothing at all', (
    WidgetTester tester,
  ) async {
    // Null is not a failure. A warning for somebody who changed their mind
    // is the kind of noise that teaches people to ignore warnings.
    final _FakeCamera camera = _FakeCamera((_) => null);
    await openSheet(tester, fresh(), camera);

    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();

    expect(camera.asked, hasLength(1));
    expect(find.textContaining('could not be opened'), findsNothing);
    expect(find.textContaining('No words could be read'), findsNothing);
  });

  testWidgets('a blurry photo says what to do about it', (
    WidgetTester tester,
  ) async {
    final _FakeCamera camera = _FakeCamera(
      (_) => const ReceiptRead.failed(ReceiptReadFailure.noText),
    );
    await openSheet(tester, fresh(), camera);

    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No words could be read'), findsOneWidget);
    expect(
      find.textContaining('type the amount in below'),
      findsOneWidget,
      reason: 'a failed read left the person with no way forward',
    );
  });

  testWidgets('a phone with no camera is told something different', (
    WidgetTester tester,
  ) async {
    // Two failures, two sentences, because they need two different things.
    // Telling somebody whose camera will not start to try better lighting
    // sends them round a loop that cannot end.
    final _FakeCamera camera = _FakeCamera(
      (_) => const ReceiptRead.failed(ReceiptReadFailure.unavailable),
    );
    await openSheet(tester, fresh(), camera);

    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('could not be opened'), findsOneWidget);
    expect(find.textContaining('Pasting the receipt text'), findsOneWidget);
    expect(find.textContaining('more light'), findsNothing);
  });

  testWidgets('a scan on its own writes nothing to the ledger', (
    WidgetTester tester,
  ) async {
    // THE HALF THAT MATTERS MOST. The prototype writes its guess straight in,
    // which is how a purchase ends up carrying a stranger's TIN. Reading a
    // receipt has to leave the books untouched until somebody confirms it.
    final FinancialState state = fresh();
    final int before = state.transactions.length;

    final _FakeCamera camera = _FakeCamera(
      (_) => const ReceiptRead.text(jollibee),
    );
    await openSheet(tester, state, camera);

    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();

    expect(
      state.transactions.length,
      before,
      reason:
          'reading a receipt logged it, so a photograph taken to check a '
          'figure has silently become an entry in somebody\'s books',
    );
  });

  testWidgets('the claim about the photo is on the screen taking it', (
    WidgetTester tester,
  ) async {
    // Not only in the privacy receipt two taps away. This is the moment
    // somebody decides whether to point their camera at a piece of paper
    // with their card number on it.
    final _FakeCamera camera = _FakeCamera(
      (_) => const ReceiptRead.text(jollibee),
    );
    await openSheet(tester, fresh(), camera);

    expect(find.textContaining('Read on your phone'), findsOneWidget);
    expect(find.textContaining('not saved or sent anywhere'), findsOneWidget);
  });
}
