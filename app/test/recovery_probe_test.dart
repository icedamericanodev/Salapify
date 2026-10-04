import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/data/import.dart';
import 'package:salapify/state/financial_state.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reconciliation.dart';
import 'package:salapify/design/tokens.dart';

void main() {
  test('A: rescue import from unreadable leaves loadStatus stuck', () async {
    final MemorySnapshotStore store = MemorySnapshotStore('{"accounts": "not a list"}');
    final FinancialState s = FinancialState(store: store);
    await s.restore();
    expect(s.loadStatus, LoadStatus.unreadable);

    final String good = Snapshot(
      accounts: <Account>[
        Account(id: 'a1', name: 'BPI', kind: AccountKind.bank,
            institution: 'BPI', balance: Money.fromDouble(5000), monogram: 'B'),
      ],
      transactions: const <Transaction>[],
      debts: const <Debt>[], budgets: const <Budget>[], goals: const <Goal>[],
      upcoming: const <UpcomingItem>[], incomeStreams: const <IncomeStream>[],
      installments: const <InstallmentPlan>[],
      reconciliations: const <ReconciliationRecord>[],
      bills: const <BillItem>[],
      payday: PaydayCycle.unset, theme: ThemeMode2.gabi,
      scenario: DecisionScenario.conservative,
    ).encode(at: DateTime.utc(2026, 10, 4));

    final ImportCheck c = checkImportFile(good);
    expect(c, isA<ImportReady>());
    final bool ok = await s.importSnapshot((c as ImportReady).incoming);
    expect(ok, isTrue);
    await s.flushWrites();

    print('AFTER RESCUE IMPORT:');
    print('  accounts on screen: ${s.accounts.length} ${s.accounts.map((a)=>a.name).toList()}');
    print('  isSaving: ${s.isSaving}');
    print('  loadStatus: ${s.loadStatus}');
    print('  loadProblem: ${s.loadProblem}');
    print('  refreshReminders(): ${s.refreshReminders()}');
  });

  test('B: nested unknown sub-keys inside debt.payments survive a save?', () {
    final Map<String, dynamic> doc = <String, dynamic>{
      'schemaVersion': 1,
      'accounts': <dynamic>[],
      'debts': <dynamic>[
        <String, dynamic>{
          'id': 'd1', 'person': 'Ana', 'direction': 'i_owe',
          'totalAmount': 1000.0, 'paidAmount': 200.0,
          'futureDebtField': 'KEEP ME TOP LEVEL',
          'payments': <dynamic>[
            <String, dynamic>{
              'id': 'p1', 'date': '2026-01-01', 'amount': 200.0,
              'paidBefore': 0.0, 'settledBefore': false,
              'fxRateUsed': 'KEEP ME NESTED',
            },
          ],
        },
      ],
    };
    final Snapshot s = Snapshot.fromJson(doc);
    final Map<String, dynamic> out = s.toJson(at: DateTime.utc(2026, 10, 4));
    final Map<String, dynamic> debt = (out['debts'] as List<dynamic>).first as Map<String, dynamic>;
    print('debt top-level keys back out: ${debt.keys.toList()}');
    print('futureDebtField survived: ${debt.containsKey('futureDebtField')}');
    final Map<String, dynamic> pay = (debt['payments'] as List<dynamic>).first as Map<String, dynamic>;
    print('payment keys back out: ${pay.keys.toList()}');
    print('fxRateUsed survived: ${pay.containsKey('fxRateUsed')}');
  });

  test('C: top-level unknown key survives, and a record unknown key survives', () {
    final Map<String, dynamic> doc = <String, dynamic>{
      'schemaVersion': 1,
      'categories': <dynamic>['food'],
      'accounts': <dynamic>[
        <String, dynamic>{
          'id': 'a1', 'name': 'BPI', 'kind': 'bank', 'institution': 'BPI',
          'balance': 500.0, 'monogram': 'B', 'purpose': 'protected',
          'vaultLockedUntil': '2027-01-01',
        },
      ],
    };
    final Snapshot s = Snapshot.fromJson(doc);
    final Map<String, dynamic> out = s.toJson(at: DateTime.utc(2026, 10, 4));
    print('top keys: ${out.keys.toList()}');
    final Map<String, dynamic> acc = (out['accounts'] as List<dynamic>).first as Map<String, dynamic>;
    print('account keys: ${acc.keys.toList()}');
    print('purpose: ${acc['purpose']}  vaultLockedUntil: ${acc['vaultLockedUntil']}');
  });

  test('D: duplicate ids in one collection, sidecar keyed by id', () {
    final Map<String, dynamic> doc = <String, dynamic>{
      'schemaVersion': 1,
      'accounts': <dynamic>[
        <String, dynamic>{'id': 'a1', 'name': 'One', 'kind': 'cash',
          'institution': 'x', 'balance': 1.0, 'monogram': 'O', 'mystery': 'FIRST'},
        <String, dynamic>{'id': 'a1', 'name': 'Two', 'kind': 'cash',
          'institution': 'x', 'balance': 2.0, 'monogram': 'T'},
      ],
    };
    final Snapshot s = Snapshot.fromJson(doc);
    final Map<String, dynamic> out = s.toJson(at: DateTime.utc(2026, 10, 4));
    for (final dynamic a in out['accounts'] as List<dynamic>) {
      print('acct: ${(a as Map<String, dynamic>)}');
    }
  });

  test('E: schemaVersion absent / string / null', () {
    print('absent -> ${Snapshot.readSchemaVersion(<String, dynamic>{})}');
    try {
      Snapshot.readSchemaVersion(<String, dynamic>{'schemaVersion': '2'});
      print('string "2" -> NO THROW');
    } on SnapshotFormatException catch (e) { print('string "2" -> throws: ${e.message.substring(0,40)}...'); }
    try {
      Snapshot.readSchemaVersion(<String, dynamic>{'schemaVersion': null});
      print('null -> NO THROW');
    } on SnapshotFormatException { print('null -> throws'); }
    print('looksLikeSalapify with string version: '
        '${looksLikeSalapify(<String, dynamic>{'schemaVersion': '2'})}');
    try {
      Snapshot.fromJson(<String, dynamic>{'receivables': <dynamic>[], 'people': <dynamic>[]});
    } on SnapshotFormatException catch (e) { print('old family: ${e.message}'); }
  });
}
