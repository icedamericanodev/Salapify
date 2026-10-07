// Testing scaffolding must be behind a flag, and the flag must be reachable.
//
// The founder asked for sample data to poke at, and in the same breath asked for
// it to be gone before the app reaches the store. Those two are months apart,
// and the gap is exactly where a promise in a chat log dies.
//
// So this file guards the MECHANISM rather than the outcome, and the difference
// matters. A test cannot check what a future store build will contain: this run
// compiles with kPreviewBuild true, because that is the default and there is no
// way to flip a compile-time constant from inside a running test. What it CAN
// check is that the scaffolding is gated at all, that the gate is spelled the
// way the release command expects, and that a launch audit has one place to
// look. A gate nobody wired is the failure this catches.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/build_flags.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/menu.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every feature that exists only for testing, by the text a person would see.
///
/// Add to this list when you add scaffolding. The list is the thing the launch
/// audit reads, so an entry here with no gate around it is a red build.
/// Deliberately NOT including 'Remove sample data'. That string is also the
/// Home banner's way out, which is pre-existing, is reachable whenever sample
/// rows exist for any reason, and must survive into a store build: somebody who
/// chose "explore the sample data" during onboarding needs the exit whether or
/// not this scaffolding shipped. The first version of this list included it and
/// flagged two innocent files, which is the wrong-check shape this project keeps
/// relearning.
const _testingAidLabels = <String>[
  'TRY IT WITH SAMPLE DATA',
  'SAMPLE DATA IS LOADED',
  'Load sample data',
];

void main() {
  test('the flag defaults to preview, and says so in one place', () {
    // The direction is a decision, not an accident: a forgotten --dart-define
    // must not silently strip a feature from the founder's preview, because that
    // reads as the app losing something and costs a round to diagnose. The cost
    // of this direction is that a forgotten flag ships scaffolding, which is
    // what the rest of this file and the launch audit exist to catch.
    expect(kPreviewBuild, isTrue);
    expect(kTestingAids, isTrue);
  });

  test('the flag is read from the environment, not hardcoded', () {
    // The whole mechanism. If somebody replaces bool.fromEnvironment with a
    // plain `true`, the release command silently stops working and nothing else
    // would notice: the app would look identical in every test and every
    // preview, and the store build would carry the scaffolding.
    final src = File('lib/build_flags.dart').readAsStringSync();
    expect(
      src,
      contains("bool.fromEnvironment("),
      reason: 'kPreviewBuild is no longer settable at build time',
    );
    expect(
      src,
      contains("'SALAPIFY_PREVIEW'"),
      reason:
          'the environment key changed. The release command passes '
          '--dart-define=SALAPIFY_PREVIEW=false, so renaming this without '
          'changing that ships the scaffolding.',
    );
  });

  test('every testing aid sits behind the gate in the source', () {
    // A source scan, because the alternative is a test that can only ever see
    // the preview build. It asserts each label appears in a file that also
    // imports the gate, which is coarse and catches the failure that actually
    // happens: somebody adds a second scaffolding card and forgets to wrap it.
    // Comment lines are stripped, and the gate must appear as the CODE form
    // `if (kTestingAids)`, not merely as the word somewhere in the file.
    //
    // The first version just asked whether "kTestingAids" appeared anywhere, and
    // it passed with the gate deleted, because the word was still sitting in a
    // comment two lines up explaining the gate. A check that a comment can
    // satisfy is the exact shape this project keeps relearning: narrower than
    // its own name, and green for the wrong reason.
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final code = f
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      final hits = _testingAidLabels.where(code.contains).toList();
      if (hits.isEmpty) continue;
      if (!code.contains('if (kTestingAids)')) {
        offenders.add('${f.path} shows $hits with no kTestingAids gate');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'testing scaffolding with no gate reaches the store the day somebody '
          'forgets it exists:\n${offenders.join('\n')}',
    );
  });

  testWidgets('the card IS present in a preview build', (tester) async {
    // The other half, and the one that keeps this file honest. A gate that hides
    // the feature from the founder too would be worse than no gate: they asked
    // for it, and they are the only person who can test the app by hand.
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
        'accounts': <Map<String, dynamic>>[],
      }),
    });
    final store = SalapifyStore();
    await store.load();
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        home: MenuScreen(store: store, onSwitchTab: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Load sample data'),
      findsOneWidget,
      reason:
          'the gate hid the sample data from the preview as well, which is the '
          'one person it exists for',
    );
  });
}
