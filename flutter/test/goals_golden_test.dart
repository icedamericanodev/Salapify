// Replays flutter/test/goldens/goals_goldens.json, generated from the exact RN
// goals.js screen math: the comma-tolerant money parse (toNum + the save-time
// Math.max(0, ...)) and the percent display. The per-month pace is not here; it
// reuses analytics.goalPace, which is locked in analytics_golden_test.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/screens/goals.dart';

void main() {
  final g = jsonDecode(
          File('test/goldens/goals_goldens.json').readAsStringSync())
      as Map<String, dynamic>;

  test('goalNum parses money the same as the RN toNum', () {
    for (final c in (g['goalNum'] as List).cast<Map<String, dynamic>>()) {
      expect(goalNum(c['in'] as String), (c['out'] as num).toDouble(),
          reason: 'goalNum("${c['in']}")');
    }
  });

  test('goalPercent matches the RN percent display', () {
    for (final c in (g['goalPercent'] as List).cast<Map<String, dynamic>>()) {
      expect(
          goalPercent(
              (c['saved'] as num).toDouble(), (c['target'] as num).toDouble()),
          c['out'] as int,
          reason: 'goalPercent(${c['saved']}, ${c['target']})');
    }
  });
}
