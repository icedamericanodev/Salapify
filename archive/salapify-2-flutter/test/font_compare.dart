// A specimen sheet, so a font decision is made by LOOKING rather than arguing.
//
// Named without the `_test` suffix for the same reason screens_shot.dart is:
// `flutter test` only collects `*_test.dart`, so this can never join a CI run
// and fail there.
//
// Run deliberately, from flutter/:
//   flutter test test/font_compare.dart --update-goldens
//
// It draws the figures that actually appear on Salapify's screens in each
// candidate face, at the sizes they are really used, on the real dark
// background. Roboto is included because that is what the React Native app
// uses: it loads no custom font at all, so every screen there is the Android
// system face, and the Roboto files ship inside the Flutter SDK so the
// comparison here is honest rather than a lookalike.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';

const _candidates = <String, List<String>>{
  'Fraunces': ['assets/fonts/Fraunces-Bold.ttf'],
  'Jakarta': [
    'assets/fonts/PlusJakartaSans-Regular.ttf',
    'assets/fonts/PlusJakartaSans-Bold.ttf',
    'assets/fonts/PlusJakartaSans-ExtraBold.ttf',
  ],
};

/// Where the SDK keeps Roboto, resolved rather than hardcoded.
///
/// This used to be a literal `/opt/flutter/...` path, which quietly became the
/// WRONG SDK the day a session ran a Flutter newer than the pin at that
/// location: it kept resolving, kept loading a Roboto, and compared the app's
/// faces against a version nothing ships on. It would break outright on any
/// future SDK that moves the directory. `screens_shot.dart` already solved this
/// properly, so this borrows its approach: ask the tool where the SDK is, and
/// fall back to walking up from the running Dart binary.
String? _sdkFontDir() {
  final roots = <String>{
    ?Platform.environment['FLUTTER_ROOT'],
    _walkUpToFlutterRoot(Platform.resolvedExecutable) ?? '',
  }..remove('');
  for (final root in roots) {
    final d = Directory('$root/engine/src/flutter/txt/third_party/fonts');
    if (d.existsSync()) return d.path;
  }
  return null;
}

/// `.../<root>/bin/cache/dart-sdk/bin/dart`, walked back up to the root.
String? _walkUpToFlutterRoot(String exe) {
  var dir = File(exe).parent;
  for (var i = 0; i < 8; i++) {
    if (Directory('${dir.path}/bin/cache/artifacts').existsSync()) {
      return dir.path;
    }
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  return null;
}

Future<void> _load(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final e in _candidates.entries) {
      final loader = FontLoader(e.key);
      for (final p in e.value) {
        final bytes = await File(p).readAsBytes();
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
      await loader.load();
    }
    // Roboto, the Android system face, straight out of the SDK.
    final sdkFonts = _sdkFontDir();
    final roboto = FontLoader('Roboto');
    for (final n in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf']) {
      if (sdkFonts == null) break;
      final f = File('$sdkFonts/$n');
      if (!f.existsSync()) continue;
      final bytes = await f.readAsBytes();
      roboto.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await roboto.load();
  });
}

/// One candidate. [big] is the face used for THE ONE NUMBER; [body] is the
/// face used for headings and row amounts. Two parameters, not one, because
/// the app today already mixes them and a comparison that ignored that would
/// be comparing something nobody ships.
Widget _row(String label, String big, String body) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Jakarta',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: Barako.muted,
          ),
        ),
        const SizedBox(height: 10),
        // The one big figure, at the size Home uses for THIS MONTH.
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '-₱720',
              style: TextStyle(
                fontFamily: big,
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: Barako.warningStrong,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '₱12,480.50',
              style: TextStyle(
                fontFamily: big,
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: Barako.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Nothing here yet, and that is okay.',
          style: TextStyle(
            fontFamily: body,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Barako.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Groceries   ₱1,111.11',
          style: TextStyle(fontFamily: body, fontSize: 15, color: Barako.muted),
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('the peso figure in each candidate face', (tester) async {
    await _load(tester);
    tester.view.physicalSize = const Size(1170, 1800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: Scaffold(
          backgroundColor: Barako.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(
                  'A. TODAY. FRAUNCES NUMBERS, JAKARTA TEXT',
                  'Fraunces',
                  'Jakarta',
                ),
                _row('B. JAKARTA EVERYWHERE', 'Jakarta', 'Jakarta'),
                _row(
                  'C. SYSTEM FONT, WHAT THE OLD APP USES',
                  'Roboto',
                  'Roboto',
                ),
                _row('D. SYSTEM NUMBERS, JAKARTA TEXT', 'Roboto', 'Jakarta'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/font-compare-dark.png'),
    );
  });
}
