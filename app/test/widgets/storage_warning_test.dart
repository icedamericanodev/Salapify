import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/state/financial_state.dart';

/// Does the app SAY when it is not keeping what you type?
///
/// It did not. `FinancialState` recorded `loadProblem`, `saveProblem` and
/// `isSaving` from the day storage landed, and nothing in `lib/` read a single
/// one of them. So when the founder's emulator could not reach path_provider,
/// every save failed in silence: the figures went on screen, the file was
/// never written, and the app said nothing at all. The CSV export threw a
/// visible error and that is the ONLY reason anybody found out.
///
/// The lesson, and the reason this file exists: a state field nothing reads is
/// not a safety mechanism, it is a variable.
///
/// ## Where the warning lives now
///
/// NOT on the tab screens. Founder direction, 2026-09-19, after seeing two
/// banners stacked above the header: "remove the 2 banners in the headers and
/// put it inside the settings. So i will not see them in the tab screen
/// because they are distracting."
///
/// So these tests changed shape rather than being deleted, and that
/// distinction is the point of the file. What is still asserted is that the
/// app is not SILENT: the gear carries a mark, and Settings says what is wrong
/// in full. What is no longer asserted is a banner, because the founder
/// removed it and it is their app.
void main() {
  Future<void> pump(WidgetTester tester, MemorySnapshotStore store) async {
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 18, 12),
      store: store,
    );
    await state.restore();
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();
  }

  group('the tab screens stay clear', () {
    testWidgets('no banner on any tab, even when saving has failed', (
      WidgetTester tester,
    ) async {
      await pump(tester, MemorySnapshotStore('{ not json'));

      for (final IconData tab in <IconData>[
        Icons.menu_book_outlined,
        Icons.insert_chart_outlined,
        Icons.track_changes_outlined,
        Icons.account_balance_wallet_outlined,
      ]) {
        await tester.tap(find.byIcon(tab));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('NOT being saved'),
          findsNothing,
          reason: 'a banner is back on a tab screen',
        );
        expect(
          find.textContaining('sample money'),
          findsNothing,
          reason: 'the sample notice is back on a tab screen',
        );
      }
    });
  });

  group('but the app is not silent', () {
    testWidgets('the gear is marked when saving has failed', (
      WidgetTester tester,
    ) async {
      await pump(tester, MemorySnapshotStore('{ not json'));

      // THE replacement for the banner. Without something here, an app that
      // has quietly stopped saving looks exactly like an app that is fine,
      // and there is no server holding a copy of what gets lost.
      expect(
        find.text('!'),
        findsOneWidget,
        reason:
            'the gear carries no mark, so nothing on any screen suggests that '
            'what the person is typing is being thrown away',
      );
    });

    testWidgets('a healthy app marks nothing at all', (
      WidgetTester tester,
    ) async {
      // The other half of the alarm, and the half that gets skipped. A mark
      // that is always on is a mark nobody reads.
      await pump(tester, MemorySnapshotStore());

      expect(find.text('!'), findsNothing);
    });

    testWidgets('Settings says what is wrong, in full', (
      WidgetTester tester,
    ) async {
      await pump(tester, MemorySnapshotStore('{ not json'));

      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Your entries are NOT being saved'), findsOneWidget);
      expect(
        find.textContaining('could not make sense of its data file'),
        findsOneWidget,
        reason: 'the plain explanation went missing on the way to Settings',
      );
      expect(
        find.textContaining('has not overwritten anything'),
        findsOneWidget,
        reason:
            'the sentence that answers "is my money gone" is the one that '
            'must survive every move',
      );
    });

    testWidgets('a save that fails is reported too, not just a bad load', (
      WidgetTester tester,
    ) async {
      // A load can succeed and every write after it still fail. This is the
      // path a full disk takes.
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState state = FinancialState(
        clock: DateTime(2026, 9, 18, 12),
        store: store,
      );
      await state.restore();
      await tester.pumpWidget(SalapifyApp(state: state));
      await tester.pumpAndSettle();

      expect(find.text('!'), findsNothing);

      store.failWriteWith = Exception('No space left on device');
      state.toggleTheme();
      await state.flushWrites();
      await tester.pumpAndSettle();

      expect(
        find.text('!'),
        findsOneWidget,
        reason: 'the write failed and nothing on screen changed',
      );
    });

    testWidgets('recovering the previous copy is not marked as disaster', (
      WidgetTester tester,
    ) async {
      final MemorySnapshotStore store = MemorySnapshotStore();
      final FinancialState first = FinancialState(
        clock: DateTime(2026, 9, 18, 12),
        store: store,
      );
      await first.restore();
      first.toggleTheme();
      await first.flushWrites();
      first.toggleTheme();
      await first.flushWrites();

      // The most recent save was interrupted partway through.
      store.contents = '{"accounts": [{"id": "acc_1", "name": "Half';

      await pump(tester, store);
      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await tester.pumpAndSettle();

      expect(
        find.text('Your entries are NOT being saved'),
        findsNothing,
        reason:
            'losing the last change is a bad minute. Reporting it in the '
            'words used for losing everything is how a beginner stops '
            'trusting the app over something it handled correctly.',
      );
    });
  });
}
