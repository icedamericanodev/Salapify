import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/features/pan/pan_history.dart';
import 'package:salapify/features/pan/pan_sheet.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// Pan remembering a conversation, and the four things that has to be true of.
///
/// Founder direction, 2026-09-20: keep the chat across app opens so an audit
/// is not lost, with a control to clear it. The spec said to put it in "the
/// local encrypted ledger store", and both halves of that needed correcting:
/// there is no encrypted store, and it must not live in the ledger, because
/// one bad row there stops every save in the app.
void main() {
  Future<FinancialState> ready() async {
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 19, 12),
      store: MemorySnapshotStore(),
    );
    await state.restore();
    return state;
  }

  Future<void> pumpPan(
    WidgetTester tester,
    FinancialState state,
    PanHistoryStore history,
  ) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(loadRealFonts);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // A FRESH KEY every time, and without it this test is hollow.
          // pumpWidget on the same tester reuses a State whose widget type
          // and position match, so initState never runs again, the old
          // _messages list is still in memory, and the assertion that the
          // conversation came back from the store passes against a
          // conversation that never left.
          body: PanSheet(
            key: UniqueKey(),
            state: state,
            history: history,
            onAction: (String _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('what was asked is there the next time Pan opens', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await ready();
    final MemoryPanHistoryStore history = MemoryPanHistoryStore();

    await pumpPan(tester, state, history);
    await tester.enterText(find.byType(TextField), 'who owes me money');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // A second opening, the way a restarted app does it.
    await pumpPan(tester, state, history);

    expect(find.text('who owes me money'), findsOneWidget);
    expect(
      find.text('Earlier conversation, kept on this phone'),
      findsOneWidget,
      reason:
          'the old messages came back with nothing saying what they are, so '
          'they read as the app answering something nobody just asked',
    );
  });

  testWidgets('Start fresh empties it, on screen AND on disk', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await ready();
    final MemoryPanHistoryStore history = MemoryPanHistoryStore();

    await pumpPan(tester, state, history);
    await tester.enterText(find.byType(TextField), 'how much do i have');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await pumpPan(tester, state, history);
    await tester.tap(find.text('Start fresh'));
    await tester.pumpAndSettle();

    expect(find.text('how much do i have'), findsNothing);
    expect(
      await history.load(),
      isEmpty,
      reason:
          'the screen cleared and the file did not, so it all came back on '
          'the next open',
    );
  });

  testWidgets('with no store, nothing is kept and nothing breaks', (
    WidgetTester tester,
  ) async {
    // The default everywhere except Home. A render harness or a test must not
    // write a chat file into somebody's documents directory as a side effect
    // of drawing a screen.
    final FinancialState state = await ready();
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(loadRealFonts);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PanSheet(state: state, onAction: (String _) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'who owes me money');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Earlier conversation, kept on this phone'), findsNothing);
  });

  group('the file itself', () {
    test('it is NOT the ledger, and cannot break it', () async {
      // The reason this is a separate file rather than a key in
      // salapify_data.json. One malformed row inside the ledger makes the
      // whole thing unreadable, which stops every save in the app; that
      // exact failure was found on the notifications row in this same batch.
      final Directory dir = await Directory.systemTemp.createTemp('panchat');
      addTearDown(() => dir.delete(recursive: true));

      final FilePanHistoryStore history = FilePanHistoryStore(directory: dir);
      await history.save(<PanStoredMessage>[
        const PanStoredMessage(fromPan: false, text: 'hello'),
      ]);

      expect(File('${dir.path}/$panHistoryFileName').existsSync(), isTrue);
      expect(
        File('${dir.path}/salapify_data.json').existsSync(),
        isFalse,
        reason: 'the chat was written into the ledger file',
      );
    });

    test('a corrupt chat file is an empty chat, not an error', () async {
      final Directory dir = await Directory.systemTemp.createTemp('panchat');
      addTearDown(() => dir.delete(recursive: true));
      File(
        '${dir.path}/$panHistoryFileName',
      ).writeAsStringSync('{ not json at all');

      expect(
        await FilePanHistoryStore(directory: dir).load(),
        isEmpty,
        reason:
            'a broken chat file threw, and there is nothing in it worth '
            'interrupting somebody over',
      );
    });

    test('it is capped, so it cannot grow on a phone forever', () async {
      final MemoryPanHistoryStore history = MemoryPanHistoryStore();
      await history.save(<PanStoredMessage>[
        for (int i = 0; i < 200; i++)
          PanStoredMessage(fromPan: i.isEven, text: 'message $i'),
      ]);

      final List<PanStoredMessage> kept = await history.load();
      expect(kept.length, panHistoryLimit);
      expect(
        kept.last.text,
        'message 199',
        reason: 'the cap dropped the NEWEST messages instead of the oldest',
      );
    });

    test('a stored message carries no figures to go stale', () async {
      // Deliberate. A peso amount computed yesterday, restored today beside a
      // live one, is the worst kind of wrong number: it looks exactly like a
      // current one. Text and a label only, and anything computed is
      // computed again when it is asked again.
      const PanStoredMessage m = PanStoredMessage(
        fromPan: true,
        text: 'It fits.',
        badge: 'It fits',
      );
      final Map<String, Object?> json = m.toJson();
      expect(json.keys.toSet(), <String>{'fromPan', 'text', 'badge'});
      expect(jsonEncode(json), isNot(contains('figures')));
    });
  });

  test(
    'the wipe deletes the chat, or Delete everything is a false promise',
    () async {
      final Directory dir = await Directory.systemTemp.createTemp('panwipe');
      addTearDown(() => dir.delete(recursive: true));

      final FileSnapshotStore store = FileSnapshotStore(directory: dir);
      await store.write('{"schemaVersion":12}');
      await FilePanHistoryStore(directory: dir).save(<PanStoredMessage>[
        const PanStoredMessage(fromPan: false, text: 'my inheritance'),
      ]);

      final File chat = File('${dir.path}/$panHistoryFileName');
      expect(chat.existsSync(), isTrue);

      await store.deleteEverything();

      expect(
        chat.existsSync(),
        isFalse,
        reason:
            'a file Salapify wrote survived "Delete everything on this phone", '
            'and it is the one holding sentences somebody typed themselves',
      );
    },
  );
}
