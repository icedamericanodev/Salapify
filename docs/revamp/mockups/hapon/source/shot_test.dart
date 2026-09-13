// Renders the chosen skin to real PNGs.
// Run: flutter test test/shot_test.dart --update-goldens
// Fonts MUST be loaded inside tester.runAsync, because testWidgets uses a fake
// clock and real file reads never complete inside it.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify_preview/main.dart';

Future<void> loadRealFonts() async {
  final loader = FontLoader('Jakarta');
  for (final f in const [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  ]) {
    final bytes = File('assets/fonts/$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();

  // The Material icon font ships with the SDK, not with the app. Without this
  // every Icon draws as an empty box and a screenshot proves nothing.
  final iconPath =
      Platform.environment['MATERIAL_ICONS'] ??
      '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final iconFile = File(iconPath);
  if (!iconFile.existsSync()) {
    throw StateError('Material icon font not found at $iconPath');
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(iconFile.readAsBytesSync())));
  await icons.load();
}

Future<void> _shoot(WidgetTester tester, String name, {double drag = 0}) async {
  // A UNIQUE KEY, deliberately. pumpWidget with the same const instance is a
  // no op, so the first version of this helper produced four identical PNGs
  // and every later drag and the dense fixture silently did nothing.
  await tester.pumpWidget(PreviewApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  if (drag != 0) {
    await tester.drag(find.byType(ListView), Offset(0, -drag));
    await tester.pumpAndSettle();
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  // Light and dark render from identical layout code, so the pictures differ
  // only in colour. Anything else that differs is a bug.
  for (final s in allSkins) {
    testWidgets('home ${s.key}', (tester) async {
      await tester.runAsync(loadRealFonts);
      skin = s;
      addTearDown(() {
        skin = allSkins.first;
        dense = false;
      });

      tester.view.physicalSize = const Size(412 * 2, 915 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await _shoot(tester, s.key);
      await _shoot(tester, '${s.key}-scrolled', drag: 560);

      // The real daily state. A list of three is a brochure; this is what the
      // screen looks like once the founder has actually been logging.
      dense = true;
      await _shoot(tester, '${s.key}-dense', drag: 900);
      await _shoot(tester, '${s.key}-dense-bottom', drag: 2400);
    });
  }
}
