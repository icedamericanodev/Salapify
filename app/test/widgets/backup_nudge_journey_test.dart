// The backup reminder, by tapping (D38.3).
//
// The rule and the store are test/data/backup_nudge_test.dart. This is the
// half a person sees: Home asks, "Back up now" hands the file over, the card
// goes, and Settings then says when the last backup was. Then "Not now".

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

void main() {
  const MethodChannel paths = MethodChannel('plugins.flutter.io/path_provider');
  const MethodChannel share = MethodChannel('dev.fluttercommunity.plus/share');
  late Directory temp;
  int shares = 0;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('salapify_nudge_j_');
    shares = 0;
    final TestDefaultBinaryMessenger m =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(paths, (MethodCall call) async => temp.path);
    m.setMockMethodCallHandler(share, (MethodCall call) async {
      shares++;
      return 'com.google.android.apps.docs';
    });
  });

  tearDown(() {
    final TestDefaultBinaryMessenger m =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(paths, null);
    m.setMockMethodCallHandler(share, null);
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<FinancialState> openHome(WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final FinancialState state = FinancialState(
      clock: DateTime(2026, 10, 12, 9),
    );
    await state.restore();
    state.startWithExampleData();
    for (int i = 0; i < 32; i++) {
      state.logTransaction(
        Transaction(
          id: 'tx_mine_$i',
          type: TransactionType.expense,
          amount: const Money.pesos(75),
          category: 'Food & Dining',
          accountId: 'acc_cash',
          date: '2026-10-11',
          createdAt: 1000 + i,
        ),
      );
    }
    addTearDown(state.dispose);
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();
    return state;
  }

  // Home is a lazy list, so a card below the fold is not built until it is
  // scrolled to. The card sits low on purpose (housekeeping, not money).
  Future<void> reach(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  testWidgets('Home asks, Back up now hands the file over, the card goes, '
      'and Settings says when', (WidgetTester tester) async {
    final FinancialState state = await openHome(tester);

    await reach(tester, find.byKey(const Key('backup-card')));
    expect(find.byKey(const Key('backup-card')), findsOneWidget);
    // The example entries are not the person's, so only their 32 count.
    expect(
      find.text(
        '32 entries live only on this phone. A backup file keeps them safe '
        'if the phone is lost.',
      ),
      findsOneWidget,
    );

    // runAsync: the export writes a REAL file before it shares, and real
    // file writes never finish on the test's fake clock.
    await tester.ensureVisible(find.text('Back up now'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Back up now'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    expect(shares, 1, reason: 'nothing reached the share sheet');
    expect(state.lastBackupAt, isNotNull);
    expect(find.byKey(const Key('backup-card')), findsNothing);
    expect(
      find.textContaining('Keep the file somewhere off this phone'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byIcon(Icons.settings_outlined),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tapIt(tester, find.byIcon(Icons.settings_outlined));
    expect(find.textContaining('Last backup: today.'), findsOneWidget);
  });

  testWidgets('Not now hides it for 14 days, and Settings still says no '
      'backup yet', (WidgetTester tester) async {
    final FinancialState state = await openHome(tester);

    await reach(tester, find.text('Not now'));
    await tapIt(tester, find.text('Not now'));
    expect(find.byKey(const Key('backup-card')), findsNothing);
    expect(state.backupNudge, isNull);
    expect(shares, 0);

    await tester.scrollUntilVisible(
      find.byIcon(Icons.settings_outlined),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tapIt(tester, find.byIcon(Icons.settings_outlined));
    expect(find.textContaining('No backup yet.'), findsOneWidget);
  });
}
