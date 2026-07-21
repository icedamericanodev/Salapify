// Replays flutter/test/goldens/accounts_goldens.json, generated from the exact
// RN accounts.js money expressions: centavo rounding and the balance-adjust
// delta. Locks the one subtle bit (JS Math.round on negative halves) to the
// live app.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/accounts_calc.dart';

void main() {
  final g = jsonDecode(
          File('test/goldens/accounts_goldens.json').readAsStringSync())
      as Map<String, dynamic>;

  test('round2 matches RN Math.round(x*100)/100', () {
    for (final c in (g['round2'] as List).cast<Map<String, dynamic>>()) {
      expect(round2((c['x'] as num).toDouble()), (c['out'] as num).toDouble(),
          reason: 'round2(${c['x']})');
    }
  });

  test('balanceAdjustDelta matches the RN balance edit math', () {
    for (final c in (g['delta'] as List).cast<Map<String, dynamic>>()) {
      expect(
          balanceAdjustDelta((c['newAmount'] as num).toDouble(),
              (c['oldBalance'] as num).toDouble()),
          (c['out'] as num).toDouble(),
          reason: 'delta(${c['newAmount']}, ${c['oldBalance']})');
    }
  });
}
