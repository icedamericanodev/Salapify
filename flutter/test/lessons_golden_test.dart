// Replays flutter/test/goldens/lessons_goldens.json, generated from the REAL RN
// mobile/lib/lessons.js. The ported Learn content must match the live app word
// for word (id, title, emoji, minutes, summary, every body paragraph), and
// lessonOfTheDay must pick the same lesson for a given date.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lessons.dart';

void main() {
  final g = jsonDecode(
      File('test/goldens/lessons_goldens.json').readAsStringSync())
      as Map<String, dynamic>;

  test('the ported lessons match the RN content exactly', () {
    final want = (g['lessons'] as List).cast<Map<String, dynamic>>();
    expect(lessons.length, want.length);
    for (var i = 0; i < want.length; i++) {
      final a = lessons[i];
      final b = want[i];
      expect(a['id'], b['id'], reason: 'id at $i');
      expect(a['title'], b['title'], reason: 'title ${b['id']}');
      expect(a['emoji'], b['emoji'], reason: 'emoji ${b['id']}');
      expect(a['minutes'], b['minutes'], reason: 'minutes ${b['id']}');
      expect(a['summary'], b['summary'], reason: 'summary ${b['id']}');
      expect((a['body'] as List).cast<String>(),
          (b['body'] as List).cast<String>(),
          reason: 'body ${b['id']}');
    }
  });

  test('lessonOfTheDay picks the same lesson as the RN app', () {
    for (final c in (g['ofDay'] as List).cast<Map<String, dynamic>>()) {
      final p = (c['date'] as String).split('-').map(int.parse).toList();
      final ref = DateTime(p[0], p[1], p[2], 12);
      expect(lessonOfTheDay(ref)['id'], c['id'], reason: c['date'] as String);
    }
  });

  test('lessonById finds a lesson or returns null', () {
    expect(lessonById('emergency-fund')?['title'],
        'Your first shield: the emergency fund');
    expect(lessonById('nope'), isNull);
  });
}
