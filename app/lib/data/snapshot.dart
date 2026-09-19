import 'dart:convert';

import '../core/money/reconciliation.dart';
import '../design/tokens.dart';
import '../models/models.dart';
import 'json_codec.dart';

/// The whole of a person's Salapify, as one JSON document.
///
/// The top level keys are the prototype's own (`src/components/SettingsModal.tsx`,
/// `handleExportData`), so a file written here opens in the prototype and a
/// backup exported from the prototype opens here.
///
/// It is deliberately a SUPERSET of that export. The prototype's backup covers
/// nine of the thirty four things it actually stores, leaving out instalment
/// plans, reconciliation history, bills, income streams, investments and the
/// collaboration data. Somebody who exports, wipes their phone and imports
/// loses all of it and is never told. That defect is not ported: this file
/// carries everything Salapify 3 holds, under the same names where a name
/// already exists.
///
/// ## Keys this build does not model are KEPT
///
/// The prototype's `Transaction` carries `changeHistory`, `comments`,
/// `approval`, `splitId`, `spaceId` and more, none of which Salapify 3 models
/// yet. Reading a prototype backup, dropping those, and saving would destroy
/// them permanently, on a device with no second copy. So every record's
/// unread keys are stashed in [Extras] on load and written back on save. The
/// models themselves stay clean; nothing in `models.dart` had to change.
class Snapshot {
  const Snapshot({
    required this.accounts,
    required this.transactions,
    required this.debts,
    required this.budgets,
    required this.goals,
    required this.upcoming,
    required this.incomeStreams,
    required this.installments,
    required this.reconciliations,
    required this.theme,
    required this.scenario,
    this.activeProfile,
    this.extras = const Extras.empty(),
  });

  final List<Account> accounts;
  final List<Transaction> transactions;
  final List<Debt> debts;
  final List<Budget> budgets;
  final List<Goal> goals;
  final List<UpcomingItem> upcoming;
  final List<IncomeStream> incomeStreams;
  final List<InstallmentPlan> installments;
  final List<ReconciliationRecord> reconciliations;

  final ThemeMode2 theme;
  final DecisionScenario scenario;
  final ProfileEntity? activeProfile;

  /// Everything in the file this build did not understand, kept verbatim.
  final Extras extras;

  /// Bumped only when the shape changes in a way a reader has to know about.
  /// A file from the FUTURE is refused rather than guessed at, so an older
  /// build cannot quietly drop what a newer one wrote.
  static const int currentSchemaVersion = 1;

  /// Collection names, used as the keys of both the document and [Extras].
  static const String kAccounts = 'accounts';
  static const String kTransactions = 'transactions';
  static const String kDebts = 'debts';
  static const String kBudgets = 'budgets';
  static const String kGoals = 'goals';
  static const String kUpcoming = 'upcoming';
  static const String kIncomeStreams = 'incomeStreams';
  static const String kInstallments = 'installments';
  static const String kReconciliations = 'reconciliations';

  /// Top level keys this build writes itself. Anything else in a loaded file
  /// is somebody else's and is preserved rather than dropped.
  static const Set<String> _ownTopKeys = <String>{
    'schemaVersion',
    'timestamp',
    'themeMode',
    'scenario',
    'activeProfile',
    kAccounts,
    kTransactions,
    kDebts,
    kBudgets,
    kGoals,
    kUpcoming,
    kIncomeStreams,
    kInstallments,
    kReconciliations,
  };

  String encode({required DateTime at}) =>
      const JsonEncoder.withIndent('  ').convert(toJson(at: at));

  Map<String, dynamic> toJson({required DateTime at}) {
    Map<String, dynamic> merged(
      String collection,
      String id,
      Map<String, dynamic> own,
    ) {
      final Map<String, dynamic>? kept = extras.forRecord(collection, id);
      if (kept == null || kept.isEmpty) return own;
      // Own values win: this build's understanding of a field it models is
      // newer than whatever was on disk.
      return <String, dynamic>{...kept, ...own};
    }

    return <String, dynamic>{
      // The unknown top level keys go FIRST so our own always win a clash.
      ...extras.top,
      'schemaVersion': currentSchemaVersion,
      'timestamp': at.toUtc().toIso8601String(),
      'themeMode': themeWire.encode(theme),
      'scenario': scenarioWire.encode(scenario),
      if (activeProfile != null)
        'activeProfile': profileWire.encode(activeProfile!),
      kAccounts: <Map<String, dynamic>>[
        for (final Account a in accounts)
          merged(kAccounts, a.id, accountToJson(a)),
      ],
      kTransactions: <Map<String, dynamic>>[
        for (final Transaction t in transactions)
          merged(kTransactions, t.id, transactionToJson(t)),
      ],
      kDebts: <Map<String, dynamic>>[
        for (final Debt d in debts) merged(kDebts, d.id, debtToJson(d)),
      ],
      kBudgets: <Map<String, dynamic>>[
        // A budget has no id. Its identity IS its category, which is also
        // what every screen looks it up by.
        for (final Budget b in budgets)
          merged(kBudgets, b.category, budgetToJson(b)),
      ],
      kGoals: <Map<String, dynamic>>[
        for (final Goal g in goals) merged(kGoals, g.id, goalToJson(g)),
      ],
      kUpcoming: <Map<String, dynamic>>[
        for (final UpcomingItem u in upcoming)
          merged(kUpcoming, u.id, upcomingToJson(u)),
      ],
      kIncomeStreams: <Map<String, dynamic>>[
        for (final IncomeStream s in incomeStreams)
          merged(kIncomeStreams, s.id, incomeStreamToJson(s)),
      ],
      kInstallments: <Map<String, dynamic>>[
        for (final InstallmentPlan p in installments)
          merged(kInstallments, p.id, installmentToJson(p)),
      ],
      kReconciliations: <Map<String, dynamic>>[
        for (final ReconciliationRecord r in reconciliations)
          merged(kReconciliations, r.id, reconciliationToJson(r)),
      ],
    };
  }

  /// Reads a document, or throws [SnapshotFormatException].
  ///
  /// Throwing is the design. Nothing here guesses a value it could not read,
  /// because the caller's response to a throw is to leave the file untouched,
  /// and a file left untouched can still be recovered.
  static Snapshot decode(String raw) {
    final Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } on FormatException catch (e) {
      throw SnapshotFormatException('The file is not valid JSON. ${e.message}');
    }
    if (parsed is! Map) {
      throw const SnapshotFormatException(
        'The file should hold one object, and does not.',
      );
    }
    return fromJson(Map<String, dynamic>.from(parsed));
  }

  static Snapshot fromJson(Map<String, dynamic> m) {
    final Object? version = m['schemaVersion'];
    if (version is num && version > currentSchemaVersion) {
      throw SnapshotFormatException(
        'This file was written by a newer version of Salapify '
        '(format $version, this build reads $currentSchemaVersion). '
        'Update the app rather than opening it here.',
      );
    }

    final ExtrasBuilder extras = ExtrasBuilder();
    for (final MapEntry<String, dynamic> e in m.entries) {
      if (!_ownTopKeys.contains(e.key)) extras.top[e.key] = e.value;
    }

    List<T> read<T>(
      String collection,
      Set<String> known,
      T Function(Map<String, dynamic>) decode,
      String Function(T) idOf,
    ) {
      final List<Map<String, dynamic>> rows = readList(
        m[collection],
        collection,
      );
      final List<T> out = <T>[];
      for (final Map<String, dynamic> row in rows) {
        final T value = decode(row);
        final Map<String, dynamic> leftover = <String, dynamic>{
          for (final MapEntry<String, dynamic> e in row.entries)
            if (!known.contains(e.key)) e.key: e.value,
        };
        if (leftover.isNotEmpty) {
          extras.put(collection, idOf(value), leftover);
        }
        out.add(value);
      }
      return out;
    }

    return Snapshot(
      accounts: read<Account>(
        kAccounts,
        accountKeys,
        accountFromJson,
        (Account a) => a.id,
      ),
      transactions: read<Transaction>(
        kTransactions,
        transactionKeys,
        transactionFromJson,
        (Transaction t) => t.id,
      ),
      debts: read<Debt>(kDebts, debtKeys, debtFromJson, (Debt d) => d.id),
      budgets: read<Budget>(
        kBudgets,
        budgetKeys,
        budgetFromJson,
        (Budget b) => b.category,
      ),
      goals: read<Goal>(kGoals, goalKeys, goalFromJson, (Goal g) => g.id),
      upcoming: read<UpcomingItem>(
        kUpcoming,
        upcomingKeys,
        upcomingFromJson,
        (UpcomingItem u) => u.id,
      ),
      incomeStreams: read<IncomeStream>(
        kIncomeStreams,
        incomeStreamKeys,
        incomeStreamFromJson,
        (IncomeStream s) => s.id,
      ),
      installments: read<InstallmentPlan>(
        kInstallments,
        installmentKeys,
        installmentFromJson,
        (InstallmentPlan p) => p.id,
      ),
      reconciliations: read<ReconciliationRecord>(
        kReconciliations,
        reconciliationKeys,
        reconciliationFromJson,
        (ReconciliationRecord r) => r.id,
      ),
      theme:
          themeWire.decodeOptional(m, 'themeMode', 'snapshot') ??
          ThemeMode2.gabi,
      scenario:
          scenarioWire.decodeOptional(m, 'scenario', 'snapshot') ??
          DecisionScenario.conservative,
      activeProfile: profileWire.decodeOptional(m, 'activeProfile', 'snapshot'),
      extras: extras.build(),
    );
  }
}

/// Keys read from the file that this build does not model, kept so that
/// saving cannot destroy them.
class Extras {
  const Extras(this.top, this._records);

  const Extras.empty()
    : top = const <String, dynamic>{},
      _records = const <String, Map<String, Map<String, dynamic>>>{};

  /// Top level keys, such as the prototype's `payday` and `categories`, which
  /// Salapify 3 still reads from its seed rather than storing.
  final Map<String, dynamic> top;

  final Map<String, Map<String, Map<String, dynamic>>> _records;

  Map<String, dynamic>? forRecord(String collection, String id) =>
      _records[collection]?[id];

  bool get isEmpty => top.isEmpty && _records.isEmpty;

  /// How many records carry kept keys, for the diagnostics line.
  int get recordCount => _records.values.fold(
    0,
    (int sum, Map<String, Map<String, dynamic>> m) => sum + m.length,
  );
}

class ExtrasBuilder {
  final Map<String, dynamic> top = <String, dynamic>{};
  final Map<String, Map<String, Map<String, dynamic>>> _records =
      <String, Map<String, Map<String, dynamic>>>{};

  void put(String collection, String id, Map<String, dynamic> leftover) {
    (_records[collection] ??= <String, Map<String, dynamic>>{})[id] = leftover;
  }

  Extras build() => Extras(top, _records);
}
