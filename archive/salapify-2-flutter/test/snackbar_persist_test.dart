// The receipt has to go away.
//
// Flutter's SnackBar defaults `persist` to `action != null`. Every snackbar in
// this app that offers Undo therefore stayed on screen forever, ignoring the
// duration written right above it. The founder found it on the most used write
// path there is: log an expense, and "Starbucks ₱220 logged. Undo" sat over
// the cards, on every tab, until it was swiped away.
//
// It is the worst kind of bug to catch by reading: the code says
// `duration: const Duration(seconds: 4)` directly above the action, so the
// intent is stated plainly and is simply not what happens. Nothing in the app
// was wrong. A default changed underneath it.
//
// Two guards, because one is not enough. The first drives the real screen and
// watches the receipt leave. The second reads every SnackBar in lib/ and
// insists that one carrying an action says out loud which behaviour it wants,
// so the next person to add an Undo has to make the decision rather than
// inherit it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart' show SalapifyApp;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the log receipt leaves on its own', (tester) async {
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
      }),
    });
    await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '0.00'), '220');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(
      find.byType(SnackBar),
      findsOneWidget,
      reason: 'the receipt never appeared, so this test proves nothing',
    );
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(
      bar.persist,
      isFalse,
      reason:
          'persist defaults to true whenever a SnackBar has an action, so the '
          'duration below it is decoration and the receipt never leaves',
    );

    // Past the stated duration, then let the exit animation run.
    await tester.pump(bar.duration + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      find.byType(SnackBar),
      findsNothing,
      reason:
          'the receipt outlived its own duration and is now covering the '
          'cards on whatever tab the person moves to',
    );
  });

  test('every SnackBar with an action says whether it persists', () {
    // A source scan, in the spirit of widget_manifest_test. It cannot be done
    // as a widget test, because reaching all seven of them means driving seven
    // screens through seven different write paths, and the one that gets
    // skipped is the one that breaks.
    //
    // The rule is NOT "persist must be false". notes.dart deliberately sets it
    // true: that snackbar reports a note that did not save and offers the only
    // way out of the editor, and a message like that timing out is how
    // somebody loses a note. The rule is that the file has to SAY.
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      var from = 0;
      while (true) {
        final at = src.indexOf('SnackBarAction', from);
        if (at == -1) break;
        from = at + 1;
        // The enclosing SnackBar( starts before the action. Scanning back to
        // the nearest one and forward to the action is enough to see the
        // arguments written alongside it.
        final open = src.lastIndexOf('SnackBar(', at);
        if (open == -1) continue;
        final block = src.substring(open, at);
        if (!block.contains('persist:')) {
          final line = '\n'.allMatches(src.substring(0, at)).length + 1;
          offenders.add('${f.path}:$line');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'these SnackBars carry an action and never say whether they should '
          'stay on screen, so Flutter decides for them and the answer is '
          'forever:\n${offenders.join('\n')}',
    );
  });

  test('the scan would actually find one', () {
    // The guard on the guard. A scanner that matched nothing would pass on an
    // empty lib/ directory and on a typo in the marker it looks for, and would
    // read exactly like a clean bill of health. Proven here against a string
    // instead of the filesystem, which is the same substring logic.
    const bad = "SnackBar(content: Text('x'), action: SnackBarAction()";
    const good =
        "SnackBar(content: Text('x'), persist: false, action: SnackBarAction()";
    for (final (src, shouldFlag) in [(bad, true), (good, false)]) {
      final at = src.indexOf('SnackBarAction');
      final open = src.lastIndexOf('SnackBar(', at);
      final flagged = !src.substring(open, at).contains('persist:');
      expect(flagged, shouldFlag, reason: src);
    }
  });
}
