// Replays flutter/test/goldens/recurring_goldens.json. The vectors were
// generated from a 1:1 twin of the RN AppData posting effect and its
// restore-time guard, so postDueRecurring and stampRecurringOnRestore must
// match the live app exactly: which items post, the transaction they create,
// the account balance they move, and the lastPosted marker. Transaction ids are
// deterministic (tx_0, tx_1, ...) in both sides. See
// scratchpad/gen-recurring-goldens.js.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/recurring.dart';

dynamic normalize(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is Map) return v.map((k, x) => MapEntry(k.toString(), normalize(x)));
  if (v is List) return v.map(normalize).toList();
  return v;
}

DateTime _ref(List ref) =>
    DateTime((ref[0] as num).toInt(), (ref[1] as num).toInt() + 1,
        (ref[2] as num).toInt(), 12);

void main() {
  final raw = jsonDecode(
          File('test/goldens/recurring_goldens.json').readAsStringSync())
      as Map<String, dynamic>;

  final postCases = raw['postCases'] as Map<String, dynamic>;
  final postResults = raw['postResults'] as Map<String, dynamic>;
  for (final name in postResults.keys) {
    test('postDueRecurring matches RN: $name', () {
      final c = postCases[name] as Map;
      final data = (c['data'] as Map).cast<String, dynamic>();
      var seq = 0;
      final got = postDueRecurring(
          Map<String, dynamic>.from(data), _ref(c['ref'] as List),
          () => 'tx_${seq++}');
      expect(normalize(got), normalize(postResults[name]), reason: name);
    });
  }

  final restoreCases = raw['restoreCases'] as Map<String, dynamic>;
  final restoreResults = raw['restoreResults'] as Map<String, dynamic>;
  for (final name in restoreResults.keys) {
    test('stampRecurringOnRestore matches RN: $name', () {
      final c = restoreCases[name] as Map;
      final got = stampRecurringOnRestore(c['recurring'], _ref(c['ref'] as List));
      expect(normalize(got), normalize(restoreResults[name]), reason: name);
    });
  }

  final saveCases = raw['saveCases'] as Map<String, dynamic>;
  final saveResults = raw['saveResults'] as Map<String, dynamic>;
  for (final name in saveResults.keys) {
    test('recurringSaveLastPosted matches RN: $name', () {
      final c = saveCases[name] as Map;
      final got = recurringSaveLastPosted(
        dayOfMonth: (c['day'] as num),
        existingLastPosted: c['existing'] as String,
        now: _ref(c['ref'] as List),
        isEdit: c['isEdit'] as bool,
      );
      expect(got, saveResults[name], reason: name);
    });
  }
}
