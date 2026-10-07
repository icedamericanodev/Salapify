// Every logo path the institutions catalog declares must point at a real
// bundled file. A typo in localAssetPath or symbolAssetPath does NOT crash the
// app: InstitutionAvatar and the card BrandChip both fall back to initials or
// the bank name through an errorBuilder, so a wrong path fails SILENTLY, on the
// phone, looking exactly like an institution we chose not to give a logo. This
// test is the thing that turns that silent fallback into a red build.
//
// Tests run with the working directory at flutter/, the same place
// account_taxonomy_test.dart reads lib/screens/accounts.dart from, so the
// 'assets/institutions/...' paths resolve directly on disk here.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/institutions.dart';

void main() {
  test('every declared institution logo asset exists on disk', () {
    var checked = 0;
    for (final inst in institutions) {
      for (final path in [inst.localAssetPath, inst.symbolAssetPath]) {
        if (path == null) continue;
        checked++;
        expect(
          File(path).existsSync(),
          isTrue,
          reason:
              'Institution "${inst.id}" declares "$path" but no such file is '
              'bundled. A missing asset falls back to initials silently on the '
              'phone. Add the file or drop the path.',
        );
      }
    }
    // Did-anything-happen guard: if the catalog ever stops declaring logo
    // paths (a bad refactor, an accidental wipe), the loop above passes
    // vacuously. This asserts the test actually exercised real paths.
    expect(checked, greaterThan(20),
        reason: 'Expected the catalog to declare many logo assets; it did '
            'not, so the existence check ran on almost nothing.');
  });
}
