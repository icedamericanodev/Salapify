// Golden lock on the two pieces of Pan that Salapify 3 keeps.
//
// Pan the mascot and the chat screen are cut (01-vision). The TEXT layer is
// not: normalize() folds Taglish to the English tokens the app matches on, and
// extractAmount() pulls a peso figure out of a typed line. Those are the only
// two parts of a fast log parser that exist anywhere in this repository, and
// the fast log field is principle 1, so they carry over.
//
// The old pan_golden_test.dart replayed the same 63 cases and then went on to
// assert intent detection, chips, help text and recap prose, all of which
// belong to the cut chat. This file replays the same fixture and asserts only
// the two columns v3 still relies on, so the lock survives the feature that
// used to own it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/taglish.dart';

/// The fixture stores numbers as JSON, so an int 250 and a double 250.0 are
/// the same value written two ways. Compare them as doubles or the test fails
/// on notation rather than on meaning.
double? _asDouble(dynamic v) => v == null ? null : (v as num).toDouble();

void main() {
  final raw =
      jsonDecode(File('test/goldens/pan_goldens.json').readAsStringSync())
          as Map<String, dynamic>;
  final cases = (raw['cases'] as List).cast<Map<String, dynamic>>();

  test('Taglish folding matches the React Native brain on every case', () {
    expect(cases, isNotEmpty, reason: 'the fixture must actually have cases');
    for (final c in cases) {
      final message = c['message'] as String;
      expect(
        normalize(message),
        c['norm'],
        reason: 'normalize disagreed on: $message',
      );
    }
  });

  test('amount extraction matches the React Native brain on every case', () {
    for (final c in cases) {
      final message = c['message'] as String;
      expect(
        _asDouble(extractAmount(message)),
        _asDouble(c['amount']),
        reason: 'extractAmount disagreed on: $message',
      );
    }
  });
}
