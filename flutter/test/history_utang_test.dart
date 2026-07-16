// The history and utang screens plus the removeEntry write path: delete with
// undo restores balances exactly, record rows can never be swiped, and the
// utang tab shows the aged ledger from the golden-verified engine.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/history.dart' show isDeletable, dateHeader;
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> blob() => {
      'schemaVersion': 12,
      'accounts': [
        {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 1000},
      ],
      'transactions': [
        {
          'id': 't1',
          'type': 'expense',
          'label': 'Groceries',
          'amount': 250,
          'date': '2026-07-16',
          'accountId': 'cash',
        },
        {
          'id': 't2',
          'type': 'transfer',
          'label': 'To savings',
          'amount': 100,
          'date': '2026-07-15',
          'flow': 'out',
          'accountId': 'cash',
        },
      ],
      'people': [
        {'id': 'p1', 'name': 'Migs'},
      ],
      'receivables': [
        {
          'id': 'r1',
          'personId': 'p1',
          'amount': 2000,
          'payments': [
            {'id': 'pay1', 'amount': 500},
          ],
          'dueDate': '2026-07-04',
        },
      ],
    };

void main() {
  test('removeEntry reverses the balance and undo restores it exactly', () async {
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob())});
    final store = SalapifyStore();
    await store.load();
    // t1 was an expense of 250 already reflected? No: the seed balance is the
    // stored truth (1000). Removing t1 gives the account its money back.
    final removed = await store.removeEntry('t1');
    expect(removed, isNotNull);
    double cash() => ((store.data['accounts'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((a) => a['id'] == 'cash')['balance'] as num)
        .toDouble();
    expect(cash(), 1250);
    // Undo: re-adding the exact same map applies the expense again.
    await store.addEntry(removed!);
    expect(cash(), 1000);
    final fresh = SalapifyStore();
    await fresh.load();
    expect((fresh.data['transactions'] as List).length, 2);
  });

  test('only plain income and expense rows are deletable', () {
    expect(isDeletable({'type': 'expense'}), isTrue);
    expect(isDeletable({'type': 'income'}), isTrue);
    expect(isDeletable({'type': 'transfer'}), isFalse);
    expect(isDeletable({'type': 'expense', 'flow': 'out'}), isFalse);
    expect(isDeletable({'type': 'income', 'source': 'receivable'}), isFalse);
    expect(isDeletable({'type': 'adjustment'}), isFalse);
  });

  test('date headers read Today and Yesterday', () {
    final now = DateTime(2026, 7, 16);
    expect(dateHeader('2026-07-16', now), 'Today');
    expect(dateHeader('2026-07-15', now), 'Yesterday');
    expect(dateHeader('2026-07-01', now), '2026-07-01');
  });

  testWidgets('history filters and utang aging render from real data',
      (tester) async {
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob())});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    // History tab: both rows under their date headers.
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('To savings'), findsOneWidget);
    // Filter to income: nothing matches, and the empty state offers a reset.
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(find.text('No entries match'), findsOneWidget);
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);

    // Utang tab: Migs owes 1,500 after the partial payment, overdue.
    await tester.tap(find.text('Utang'));
    await tester.pumpAndSettle();
    expect(find.text('Migs'), findsOneWidget);
    expect(find.text('₱1,500'), findsWidgets);
    expect(find.textContaining('Overdue'), findsWidgets);
  });
}
