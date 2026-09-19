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
/// not a safety mechanism, it is a variable. These tests are what make the
/// warning a mechanism.
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

  testWidgets('a file that cannot be read is announced on the screen', (
    WidgetTester tester,
  ) async {
    await pump(tester, MemorySnapshotStore('{ not json'));

    expect(
      find.text('Your entries are NOT being saved'),
      findsOneWidget,
      reason:
          'THE test. Saving was off, the state knew it, and the app said '
          'nothing for a whole batch.',
    );
    expect(
      find.textContaining('Nothing already on this phone'),
      findsOneWidget,
    );
  });

  testWidgets('the warning follows you to every tab', (
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
        find.text('Your entries are NOT being saved'),
        findsOneWidget,
        reason:
            'somebody who saw it once at launch is typing real figures ten '
            'minutes later and needs it still there',
      );
    }
  });

  testWidgets('a working app says nothing at all', (WidgetTester tester) async {
    await pump(tester, MemorySnapshotStore());

    // The directional companion. A banner that is always there would satisfy
    // every assertion above and be worthless.
    expect(find.text('Your entries are NOT being saved'), findsNothing);
    expect(
      find.textContaining('being saved'),
      findsNothing,
      reason:
          'a permanent "your data is safe" strip stops being read by the '
          'second day, and then it is not read on the day it matters',
    );
  });

  testWidgets('a save that fails is announced too, not just a bad load', (
    WidgetTester tester,
  ) async {
    final MemorySnapshotStore store = MemorySnapshotStore();
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 18, 12),
      store: store,
    );
    await state.restore();
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('Your entries are NOT being saved'), findsNothing);

    // The disk fills, or the plugin is missing, on the very first write.
    store.failWriteWith = Exception('No space left on device');
    state.toggleTheme();
    await state.flushWrites();
    await tester.pumpAndSettle();

    expect(find.text('Your entries are NOT being saved'), findsOneWidget);
    expect(find.textContaining('not stored yet'), findsOneWidget);
  });

  testWidgets('recovering the previous copy reads as recovery, not disaster', (
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

    expect(find.text('We opened your last saved copy'), findsOneWidget);
    expect(
      find.text('Your entries are NOT being saved'),
      findsNothing,
      reason:
          'losing the last change is a bad minute. Reporting it in the words '
          'used for losing everything is how a beginner stops trusting the '
          'app over something it handled correctly.',
    );
  });
}
