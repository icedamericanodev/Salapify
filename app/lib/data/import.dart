import 'dart:convert';

import '../core/money/accounts.dart';
import '../core/money/debt.dart';
import '../models/models.dart';
import 'json_codec.dart';
import 'snapshot.dart';

/// Reading a backup file, and deciding whether it may be restored.
///
/// Pure. Nothing here writes anything, and that separation is the point:
/// everything a person is shown BEFORE they confirm is computed from a file
/// decoded in memory, so picking the wrong file costs nothing at all.
///
/// ## Replace, never merge
///
/// Import replaces the whole ledger. There is no merge and no per-collection
/// option, and the reason is in the data rather than in taste.
///
/// `Account.balance` is an ABSOLUTE stored figure, moved incrementally at
/// write time by `applyToBalances`. Nothing in the app recomputes a balance
/// from the transaction list. So merging incoming transactions without
/// touching balances gives a ledger whose entries do not add up to its
/// accounts, by exactly the sum of what was merged; and replaying the entries
/// instead double counts everything already reflected in this phone's stored
/// balances. On an id collision either choice is silently wrong.
///
/// And collisions are not hypothetical: two fresh installs share `acc_bpi` and
/// every seeded id, because both start from the same SeedData.

/// What a ledger holds, for the before-and-after comparison.
class LedgerSummary {
  const LedgerSummary({
    required this.accounts,
    required this.entries,
    required this.debts,
    required this.goals,
    required this.budgets,
    required this.bills,
    required this.installments,
    required this.upcoming,
    required this.incomeStreams,
    required this.reconciliations,
    required this.assets,
    required this.liabilities,
    required this.owed,
    required this.owedToYou,
    required this.hasSampleData,
    required this.payday,
    this.savedAt,
  });

  final int accounts;
  final int entries;
  final int debts;
  final int goals;
  final int budgets;
  final int bills;
  final int installments;
  final int upcoming;
  final int incomeStreams;
  final int reconciliations;

  /// Kept APART, never summed. The sample summary learned this the hard way:
  /// adding them once announced a demo mortgage as money somebody had.
  final double assets;
  final double liabilities;

  final double owed;
  final double owedToYou;

  final bool hasSampleData;
  final PaydayCycle payday;

  /// The file's own timestamp, so the person can tell which backup this is.
  final String? savedAt;

  /// Nothing worth restoring. Said out loud on the screen, because restoring
  /// it leaves Salapify empty and that must not be a surprise.
  bool get isEmpty => accounts == 0 && entries == 0;
}

LedgerSummary summarizeSnapshot(Snapshot s, {String? savedAt}) {
  final List<Account> sampleAware = s.accounts;
  return LedgerSummary(
    accounts: s.accounts.length,
    entries: s.transactions.length,
    debts: s.debts.length,
    goals: s.goals.length,
    budgets: s.budgets.length,
    bills: s.bills.length,
    installments: s.installments.length,
    upcoming: s.upcoming.length,
    incomeStreams: s.incomeStreams.length,
    reconciliations: s.reconciliations.length,
    assets: accountsTotalPhp(assetsOf(sampleAware)),
    liabilities: accountsTotalPhp(liabilitiesOf(sampleAware)),
    owed: outstanding(s.debts, DebtDirection.iOwe),
    owedToYou: outstanding(s.debts, DebtDirection.owedToMe),
    hasSampleData:
        s.accounts.any((Account a) => a.isSample) ||
        s.transactions.any((Transaction t) => t.isSample),
    payday: s.payday,
    savedAt: savedAt,
  );
}

/// The answer to "may this file be restored".
sealed class ImportCheck {
  const ImportCheck();
}

class ImportRefused extends ImportCheck {
  const ImportRefused(this.reason);

  /// A sentence for a person, always ending with the fact that nothing has
  /// changed. The screen adds that; this carries the cause.
  final String reason;
}

class ImportReady extends ImportCheck {
  const ImportReady({
    required this.incoming,
    required this.summary,
    required this.missing,
  });

  final Snapshot incoming;
  final LedgerSummary summary;

  /// Collections this build has that the FILE does not, in user words.
  ///
  /// A prototype backup covers nine of the thirty four things Salapify stores,
  /// so plans, bills and reconciliation history come back empty. That is a
  /// legitimate import and refusing it would be wrong, but saying nothing
  /// would not: Safe to Spend moves when the bills vanish, and an unexplained
  /// move in the headline figure is the defect this whole app keeps relearning.
  final List<String> missing;
}

/// Collection key to the word a person would use for it.
const Map<String, String> _collectionWords = <String, String>{
  Snapshot.kAccounts: 'accounts',
  Snapshot.kTransactions: 'entries',
  Snapshot.kDebts: 'debts',
  Snapshot.kBudgets: 'budget limits',
  Snapshot.kGoals: 'goals',
  Snapshot.kUpcoming: 'reminders',
  Snapshot.kIncomeStreams: 'income',
  Snapshot.kInstallments: 'payment plans',
  Snapshot.kReconciliations: 'reconciliation checks',
  Snapshot.kBills: 'bills',
};

/// Decides whether [raw] may be restored, WITHOUT writing anything.
ImportCheck checkImportFile(String raw) {
  if (raw.trim().isEmpty) {
    return const ImportRefused('That file is empty.');
  }

  final Object? parsed;
  try {
    parsed = jsonDecode(raw);
  } on FormatException {
    return const ImportRefused(
      'That file is not a Salapify backup. It is not valid JSON, so it may '
      'have been cut short while it was being copied.',
    );
  }

  if (parsed is! Map) {
    return const ImportRefused('That file is not a Salapify backup.');
  }

  final Map<String, dynamic> map = Map<String, dynamic>.from(parsed);

  // THE GATE. Without it `{}` is a perfectly valid, entirely empty ledger, and
  // restoring it would report success and leave Salapify with nothing.
  if (!looksLikeSalapify(map)) {
    return const ImportRefused(
      'That file is valid, but it is not a Salapify backup. It has none of '
      'the parts one has: accounts, entries, debts, budgets, goals, '
      'reminders, income, payment plans, reconciliation checks or bills.',
    );
  }

  final Snapshot incoming;
  try {
    incoming = Snapshot.fromJson(map);
  } on SnapshotFormatException catch (e) {
    // Carries the newer-version sentence and every bad field, already written
    // for a person.
    return ImportRefused(e.message);
  }

  final List<String> missing = <String>[
    for (final MapEntry<String, String> e in _collectionWords.entries)
      if (map[e.key] is! List) e.value,
  ];

  return ImportReady(
    incoming: incoming,
    summary: summarizeSnapshot(
      incoming,
      savedAt: map['timestamp'] is String ? map['timestamp'] as String : null,
    ),
    missing: missing,
  );
}
