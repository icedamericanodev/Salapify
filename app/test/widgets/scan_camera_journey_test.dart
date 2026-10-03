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

  /// What a lost-data recovery returns. Nothing lost, by default.
  ReceiptRead? lost;

  /// How many times recovery was asked for, so a test can prove the sheet
  /// checks at all. Android throws a photo away only under memory pressure,
  /// so a missing check looks perfect until the day it does not.
  int recoverCalls = 0;

  @override
  Future<ReceiptRead?> read(ReceiptImageSource from) async {
    asked.add(from);
    return _answer(from);
  }

  @override
  Future<ReceiptRead?> recoverLost() async {
    recoverCalls++;
    return lost;
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
    expect(
      find.textContaining('Choose an image instead'),
      findsOneWidget,
      reason:
          'the message does not name the button directly above it, which '
          'needs no camera and reads the same way. On an emulator this is '
          'the ordinary case, so it steers people away from the one path '
          'that would have worked.',
    );
    expect(find.textContaining('paste the receipt text below'), findsOneWidget);
    expect(find.textContaining('more light'), findsNothing);
  });

  testWidgets('a library failure never blames the camera', (
    WidgetTester tester,
  ) async {
    // STRAIGHT FROM A FOUNDER SCREENSHOT, 2026-09-22. Tapping Choose an
    // image produced "The camera could not be opened on this phone. Choose
    // an image instead." Two falsehoods in one card: it blamed a control
    // they had never touched, then offered them the one that had just
    // failed, which is a loop with no way out.
    //
    // Somebody told their camera is broken when they never opened it learns
    // that this app's messages are not worth reading, and that is spent on
    // every message after it.
    final _FakeCamera camera = _FakeCamera(
      (_) => const ReceiptRead.failed(ReceiptReadFailure.unavailable),
    );
    await openSheet(tester, fresh(), camera);

    await tester.tap(find.text('Choose an image'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('camera'),
      findsNothing,
      reason:
          'a photo library failure is blaming the camera, which the person '
          'never touched',
    );
    expect(
      find.textContaining('Choose an image instead'),
      findsNothing,
      reason:
          'the message offers the button that just failed, so the only way '
          'it suggests is the one that cannot work',
    );

    // And it still leaves somewhere to go.
    expect(find.textContaining('Paste the receipt text below'), findsOneWidget);
  });

  testWidgets('a build without the plugins says so, and blames no phone', (
    WidgetTester tester,
  ) async {
    // THE HOUR THIS COST, 2026-09-22. Both buttons failed on the founder's
    // emulator, and the message told them the camera could not be opened,
    // so they went and checked their emulator. It had Play Store, a Camera
    // app and Photos, all working.
    //
    // The real cause was a hot restart putting new Dart code on top of an
    // older native build. The buttons are Dart and appeared; the plugins
    // behind them were not in the installed binary, so every call threw
    // MissingPluginException, which was being swallowed into "the camera
    // could not be opened". tools/dev-sync.sh documents this exact trap,
    // having been caught by it once already with path_provider.
    //
    // A message that names the phone's hardware sends somebody to check the
    // one thing that is definitely fine.
    final _FakeCamera camera = _FakeCamera(
      (_) => const ReceiptRead.failed(ReceiptReadFailure.notInThisBuild),
    );
    await openSheet(tester, fresh(), camera);

    await tester.tap(find.text('Choose an image'));
    await tester.pumpAndSettle();

    expect(find.textContaining('reinstalling the app'), findsOneWidget);
    expect(
      find.textContaining('could not be opened'),
      findsNothing,
      reason:
          'a missing plugin is being reported as a broken camera or photo '
          'library, which sends the person to check hardware that works',
    );
    expect(find.textContaining('camera'), findsNothing);

    // And there is still something they can do this minute.
    expect(find.textContaining('Pasting the receipt text below'), findsWidgets);
  });

  testWidgets('an unreadable image is not told to stand somewhere else', (
    WidgetTester tester,
  ) async {
    // Advice about the angle and the light belongs to somebody holding a
    // camera. To somebody who picked a screenshot out of their gallery it is
    // nonsense, and nonsense advice is how a person concludes the app does
    // not know what it is talking about.
    final _FakeCamera camera = _FakeCamera(
      (_) => const ReceiptRead.failed(ReceiptReadFailure.noText),
    );
    await openSheet(tester, fresh(), camera);

    await tester.tap(find.text('Choose an image'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No words could be read'), findsOneWidget);
    expect(find.textContaining('more light'), findsNothing);
    expect(find.textContaining('type the amount in below'), findsOneWidget);
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

  testWidgets('a photo Android threw away is picked back up', (
    WidgetTester tester,
  ) async {
    // THE FAILURE THAT LOOKS LIKE NOTHING HAPPENING. The picker's intent
    // backgrounds Salapify, which is exactly when a memory-constrained
    // device may kill it. The await in the scan then never completes, so
    // somebody photographs a receipt and comes back to an app showing no
    // result and no error at all. image_picker documents the recovery and
    // says the check should always run at startup; it was missing.
    final _FakeCamera camera = _FakeCamera((_) => null)
      ..lost = const ReceiptRead.text(jollibee);

    await openSheet(tester, fresh(), camera);

    expect(
      camera.recoverCalls,
      1,
      reason:
          'the sheet never asks whether a photo was lost, so one taken just '
          'before Android killed the app is gone with no trace',
    );
    expect(find.text('147.00'), findsWidgets);
    expect(find.textContaining('CHICKENJOY'), findsWidgets);
  });

  testWidgets('nothing lost means nothing is said', (
    WidgetTester tester,
  ) async {
    // The ordinary case, every single time the sheet opens. A recovery that
    // announced itself when there was nothing to recover would put a warning
    // in front of somebody who had done nothing at all.
    final _FakeCamera camera = _FakeCamera((_) => null);
    await openSheet(tester, fresh(), camera);

    expect(camera.recoverCalls, 1);
    expect(find.textContaining('could not be opened'), findsNothing);
    expect(find.textContaining('No words could be read'), findsNothing);
    expect(find.text('147.00'), findsNothing);
  });
}
