// Scoped golden configuration for test/golden/ ONLY.
//
// flutter_test_config.dart is picked up automatically for every test in its
// own directory subtree, so this affects the deterministic golden suite here
// and nothing else in the repo.
//
// It installs a comparator with a SMALL, explicit pixel tolerance. The default
// comparator is exact to the byte, which is right for a machine that generates
// and checks on the identical setup, but the baselines here are generated on a
// developer/sandbox Linux box and compared on the CI Linux runner. Both run the
// same pinned Flutter (3.44.6) and load the same committed fonts, so any
// difference is at most sub-pixel anti-aliasing at a few glyph edges. A 0.5%
// tolerance absorbs exactly that and nothing more: a real regression (a moved
// box, a wrong colour, changed copy) moves far more than half a percent of the
// pixels, so it still fails loudly. The tolerance is documented and deliberately
// low; do NOT raise it to hush a failure.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fraction of pixels allowed to differ before a golden is considered changed.
const double _tolerance = 0.005; // 0.5%

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final previous = goldenFileComparator;
  if (previous is LocalFileComparator) {
    goldenFileComparator = _TolerantComparator(previous.basedir, _tolerance);
  }
  await testMain();
}

class _TolerantComparator extends LocalFileComparator {
  final double tolerance;

  // LocalFileComparator resolves golden paths relative to a test file URI; the
  // previous comparator's basedir already points at this directory, so hand it
  // a dummy file inside basedir to keep that resolution.
  _TolerantComparator(Uri basedir, this.tolerance)
    : super(Uri.parse('$basedir/ui_golden.dart'));

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) return true;
    // Writes the failure_*.png (masked, isolated, diff) next to the baseline so
    // the run points at exactly what moved, and by how much.
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}
