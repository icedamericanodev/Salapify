// Store-level vectors for Financial Guides progress
// (settings.guideProgress, driven by money/guide_progress.dart). Proves the
// fraction climbs and never falls, classifies into read / in progress
// correctly, survives a simulated restart, round-trips through backup export
// and import, and never touches the Money Courses lesson progress or the
// core 22's "X of 22" figure.
//
// Guide ids here are synthetic on purpose: this file tests the STORE
// mechanism, which does not validate ids against the catalog, so it stays
// green no matter how the real catalog changes. Catalog shape is guarded
// separately in financial_guides_content_test.dart.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/guide_progress.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SalapifyStore> _freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  return store;
}

void main() {
  group('a guide fraction climbs and never falls', () {
    test('a higher fraction wins, a lower one is ignored', () async {
      final store = await _freshStore();
      await store.setGuideProgress('guide-a', 0.4);
      expect(store.guideProgress['guide-a'], closeTo(0.4, 1e-9));

      await store.setGuideProgress('guide-a', 0.7);
      expect(store.guideProgress['guide-a'], closeTo(0.7, 1e-9));

      // Scrolling back up, or reopening, must never lower it.
      await store.setGuideProgress('guide-a', 0.2);
      expect(
        store.guideProgress['guide-a'],
        closeTo(0.7, 1e-9),
        reason: 'progress can only climb',
      );
    });

    test('markGuideRead pins it to done and never demotes', () async {
      final store = await _freshStore();
      await store.markGuideRead('guide-a');
      expect(isGuideRead(store.guideProgress['guide-a']!), isTrue);
      // A later partial read of the same guide cannot un-read it.
      await store.setGuideProgress('guide-a', 0.3);
      expect(isGuideRead(store.guideProgress['guide-a']!), isTrue);
    });

    test(
      'out-of-range and junk fractions are clamped, not stored raw',
      () async {
        final store = await _freshStore();
        await store.setGuideProgress('guide-a', 1.9);
        expect(store.guideProgress['guide-a'], 1.0);
        // A zero or negative write records nothing (the map only holds touched
        // guides), so it does not create a phantom Continue Reading row.
        await store.setGuideProgress('guide-b', 0.0);
        expect(store.guideProgress.containsKey('guide-b'), isFalse);
      },
    );
  });

  group('classification for the Continue Reading row', () {
    test('in progress is > 0 and not yet read', () async {
      final store = await _freshStore();
      await store.setGuideProgress('guide-a', 0.5);
      await store.markGuideRead('guide-b');
      final p = store.guideProgress;
      expect(isGuideInProgress(p['guide-a']!), isTrue);
      expect(isGuideInProgress(p['guide-b']!), isFalse);
      expect(isGuideRead(p['guide-b']!), isTrue);
    });
  });

  group('the lessons are never touched by guide progress', () {
    test('progressing guides leaves core lessonProgress empty', () async {
      final store = await _freshStore();
      await store.setGuideProgress('guide-a', 0.6);
      await store.markGuideRead('guide-b');
      expect(store.lessonProgress, isEmpty);
      expect(
        (store.data['settings'] as Map).containsKey('lessonsRead'),
        isFalse,
      );
      expect(
        (store.data['settings'] as Map).containsKey('lessonProgress'),
        isFalse,
      );
    });

    test('a lesson write leaves guide progress empty', () async {
      final store = await _freshStore();
      await store.setLessonState('see-it-first', LessonState.completed);
      expect(store.guideProgress, isEmpty);
      expect(
        (store.data['settings'] as Map).containsKey('guideProgress'),
        isFalse,
      );
    });
  });

  group('persistence across a simulated restart', () {
    test(
      'guide progress survives a fresh store reading the same disk',
      () async {
        final store = await _freshStore();
        await store.setGuideProgress('guide-a', 0.55);
        await store.markGuideRead('guide-b');

        final second = SalapifyStore();
        await second.load();
        expect(second.guideProgress['guide-a'], closeTo(0.55, 1e-9));
        expect(isGuideRead(second.guideProgress['guide-b']!), isTrue);
      },
    );
  });

  group('backup export and restore', () {
    test('guide progress round-trips through export and import', () async {
      final store = await _freshStore();
      await store.setGuideProgress('guide-a', 0.6);
      await store.markGuideRead('guide-c');
      final text = store.exportBackupText();

      SharedPreferences.setMockInitialValues({});
      final restored = SalapifyStore();
      await restored.load();
      await restored.importBackupText(text);

      expect(restored.guideProgress['guide-a'], closeTo(0.6, 1e-9));
      expect(isGuideRead(restored.guideProgress['guide-c']!), isTrue);
      // A guide never touched stays unrecorded, never a false in-progress.
      expect(restored.guideProgress.containsKey('guide-z'), isFalse);
    });

    test(
      'a backup with no guide progress omits the guideProgress key',
      () async {
        final store = await _freshStore();
        final text = store.exportBackupText();
        final decoded = jsonDecode(text) as Map<String, dynamic>;
        final settings = (decoded['data'] as Map)['settings'] as Map;
        expect(settings.containsKey('guideProgress'), isFalse);
      },
    );
  });
}
