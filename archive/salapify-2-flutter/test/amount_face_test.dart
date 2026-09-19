// Phase 3 batch 4: one face for money on Home.
//
// amountRow's contract is STRICT: never resized, never reweighted, tint is
// the only permitted modifier. Roughly twenty call sites across lib/ still
// break it (they convert with their screens, later phases); this test pins
// the files batch 4 actually cleaned so the forks it removed cannot creep
// back while the wider cleanup is still queued. Grow the list as screens
// convert; never shrink it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const cleanFiles = [
  'lib/screens/overview.dart',
  'lib/screens/history.dart',
  'lib/widgets/bills_before_payday.dart',
  // Phase 6: the calculator ledgers used to resize and reweight amountRow per
  // line; they now tint the one row face and let the label carry emphasis.
  'lib/screens/salary_calculator.dart',
  'lib/screens/tax_calculator.dart',
  // Phase 2B: the quick-add template amount moved off amountRow.w4 to
  // AmountRole.reference, so the fork this guard watches for is gone here.
  'lib/screens/quick_add_editor.dart',
];

void main() {
  test('cleaned files never resize or reweight amountRow again', () {
    final offenders = <String>[];
    // Dot-modifier chains can break across lines under the formatter, so the
    // scan joins whitespace before matching (`amountRow\n  .w6` is the same
    // fork as `amountRow.w6`).
    final fork = RegExp(r'amountRow\s*\.\s*(w\d|copyWith)');
    for (final path in cleanFiles) {
      final src = File(path).readAsStringSync();
      if (fork.hasMatch(src)) {
        offenders.add(
          '$path modifies amountRow beyond .tint; use AmountText '
          '(role: row) or the bare face instead',
        );
      }
      expect(
        File(path).existsSync(),
        isTrue,
        reason: 'the guarded file moved; update cleanFiles',
      );
    }
    expect(offenders, isEmpty);
  });
}
