// Every feeling Pan can wear must have real art on disk.
//
// The enum is deliberately open: a new feeling is "a file drop under
// assets/pan/emotions plus an enum value, nothing else" (see pan_mascot.dart).
// That contract has a silent half: add the enum value, forget the file, and the
// only thing that shows is the code-drawn cup fallback on the rare
// asset-load-failure path, which nobody looks at. This test closes that gap by
// asserting the promise the enum makes: for every PanEmotion.values entry there
// is a non-trivial PNG at panEmotionAsset(e). A derived set is a rule and a
// typed set is a promise.
//
// flutter test runs with the working directory at flutter/, so the asset paths
// resolve as plain files without going through the bundle.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/widgets/pan_mascot.dart';

void main() {
  test('every PanEmotion has real art on disk', () {
    for (final e in PanEmotion.values) {
      final path = panEmotionAsset(e);
      final file = File(path);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'PanEmotion.${e.name} declares $path but no file exists there.',
      );
      // A stub or truncated PNG would load as nothing; a real rendered panda is
      // tens of KB. Guard against a placeholder sneaking in.
      expect(
        file.lengthSync(),
        greaterThan(4000),
        reason: '$path is suspiciously small for a rendered mascot.',
      );
    }
  });
}
