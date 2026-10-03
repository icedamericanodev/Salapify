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
  exportGuardTests();

  Future<void> pump(WidgetTester tester, MemorySnapshotStore store) async {
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 18, 12),
      store: store,
    );
    await state.restore();
    // The app opens on the welcome when nothing has been onboarded, and these
    // tests are about what a storage problem looks like TO SOMEBODY ALREADY
    // USING the app. An unreadable file never reaches the welcome anyway, by
    // design: a cheerful first run over a ledger that merely could not be
    // parsed is the worst screen this app could show.
    state.startWithExampleData();
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
      state.startWithExampleData();
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

/// Export must never hand somebody Salapify's demo accounts as their backup.
///
/// When the data file cannot be read, restore() never applies it, so the state
/// still holds the seed. Exporting a SNAPSHOT would encode eleven demo accounts
/// under a row promising "everything on this phone". The person in front of the
/// red panel is exactly the person who taps Export to rescue their data.
///
/// This used to assert a REFUSAL, and the refusal was right about the danger
/// and wrong about the remedy: it left the one state that needs an export with
/// no route out at all, on a phone where the data file sits in app-private
/// storage a stock file manager cannot open. So the row now sends the RAW
/// BYTES, which are the only copy worth having, and this test holds the row to
/// saying so rather than to going quiet.
void exportGuardTests() {
  testWidgets('export sends the RAW FILE while the data file is unreadable', (
    WidgetTester tester,
  ) async {
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 18, 12),
      store: MemorySnapshotStore('{ not json'),
    );
    await state.restore();
    // The app opens on the welcome when nothing has been onboarded, and these
    // tests are about what a storage problem looks like TO SOMEBODY ALREADY
    // USING the app. An unreadable file never reaches the welcome anyway, by
    // design: a cheerful first run over a ledger that merely could not be
    // parsed is the worst screen this app could show.
    state.startWithExampleData();
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();

    // The row names what it will actually send, so nobody keeps a file of
    // Salapify's samples believing it holds their salary.
    expect(
      find.text('Export the file Salapify cannot read'),
      findsOneWidget,
      reason:
          'the export row went quiet or kept its ordinary title, so the one '
          'person who needs the raw bytes has no route to them',
    );
    expect(
      find.textContaining('This sends the file exactly as it is'),
      findsOneWidget,
    );
    // And it is reachable. A disabled row with honest copy is still a dead end.
    final Finder row = find.ancestor(
      of: find.text('Export the file Salapify cannot read'),
      matching: find.byType(InkWell),
    );
    expect(row, findsWidgets);
    expect(
      tester.widget<InkWell>(row.first).onTap,
      isNotNull,
      reason: 'the export row was offered and then did nothing when tapped',
    );
  });

  testWidgets('a healthy app still offers the export', (
    WidgetTester tester,
  ) async {
    // The other half. A guard that disabled export permanently would pass the
    // test above and remove the feature.
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 18, 12),
      store: MemorySnapshotStore(),
    );
    await state.restore();
    // The app opens on the welcome when nothing has been onboarded, and these
    // tests are about what a storage problem looks like TO SOMEBODY ALREADY
    // USING the app. An unreadable file never reaches the welcome anyway, by
    // design: a cheerful first run over a ledger that merely could not be
    // parsed is the worst screen this app could show.
    state.startWithExampleData();
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('One file holding everything on this phone'),
      findsOneWidget,
    );
  });
}
