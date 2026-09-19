import '../core/money/reconciliation.dart';
import '../design/tokens.dart';
import '../models/models.dart';

/// Turning Salapify's models into JSON and back, in the PROTOTYPE'S OWN
/// spelling.
///
/// Every key and every enum string here matches `src/types.ts` exactly, so a
/// file written by this app opens in the prototype and a backup exported from
/// the prototype opens here. That is the whole reason this file is a hand
/// written codec rather than a generated one: the two sides have to agree on
/// the wire, and the only way to be sure is to read the other side's types and
/// write the mapping down where somebody can check it.
///
/// Two spellings differ from the Dart field names and both are deliberate:
///   - Multi word enum values are snake_case on the wire (`side_hustle`,
///     `i_owe`, `owed_to_me`, `weekly_income`). Using `.name` would have
///     written `sideHustle`, which the prototype does not recognise, and a
///     side hustle silently reclassified as personal is money in the wrong
///     books.
///   - A debt's schedule is stored under `scheduleType`, not `schedule`.
///
/// ON FAILURE THIS THROWS, and that is the point. A required field with the
/// wrong type, or an enum value this build has never heard of, means the file
/// was written by something this build does not understand. Guessing a
/// default would load a quietly wrong ledger and then save that over the
/// original. Throwing keeps the file exactly as it was so it can still be
/// recovered. Optional fields are tolerant, because a missing optional is an
/// absence rather than a contradiction.

/// Raised when a stored record cannot be read as what it claims to be.
class SnapshotFormatException implements Exception {
  const SnapshotFormatException(this.message);
  final String message;

  @override
  String toString() => 'SnapshotFormatException: $message';
}

Never _bad(String what) => throw SnapshotFormatException(what);

// ---------------------------------------------------------------------------
// Field readers
// ---------------------------------------------------------------------------

String _reqStr(Map<String, dynamic> m, String key, String what) {
  final Object? v = m[key];
  if (v is String) return v;
  _bad('$what.$key should be a string, found ${v.runtimeType}');
}

String? _optStr(Map<String, dynamic> m, String key) {
  final Object? v = m[key];
  return v is String ? v : null;
}

double _reqNum(Map<String, dynamic> m, String key, String what) {
  final Object? v = m[key];
  if (v is num) return v.toDouble();
  _bad('$what.$key should be a number, found ${v.runtimeType}');
}

double? _optNum(Map<String, dynamic> m, String key) {
  final Object? v = m[key];
  return v is num ? v.toDouble() : null;
}

int _reqInt(Map<String, dynamic> m, String key, String what) {
  final Object? v = m[key];
  if (v is num) return v.toInt();
  _bad('$what.$key should be a whole number, found ${v.runtimeType}');
}

int? _optInt(Map<String, dynamic> m, String key) {
  final Object? v = m[key];
  return v is num ? v.toInt() : null;
}

bool _optBool(Map<String, dynamic> m, String key, {bool fallback = false}) {
  final Object? v = m[key];
  return v is bool ? v : fallback;
}

List<String> _optStrList(Map<String, dynamic> m, String key) {
  final Object? v = m[key];
  if (v is! List) return const <String>[];
  return v.whereType<String>().toList(growable: false);
}

List<Map<String, dynamic>> readList(Object? raw, String what) {
  if (raw == null) return const <Map<String, dynamic>>[];
  if (raw is! List) {
    _bad('$what should be a list, found ${raw.runtimeType}');
  }
  return raw
      .map<Map<String, dynamic>>((Object? e) {
        if (e is Map) return Map<String, dynamic>.from(e);
        return _bad('$what should hold objects, found ${e.runtimeType}');
      })
      .toList(growable: false);
}

// ---------------------------------------------------------------------------
// Enums. Explicit both ways, never `.name`.
// ---------------------------------------------------------------------------

/// One enum's two way mapping, plus the reader that refuses to guess.
class Wire<T> {
  const Wire(this.toWire, this.fromWire);
  final Map<T, String> toWire;
  final Map<String, T> fromWire;

  String encode(T value) => toWire[value]!;

  T decodeRequired(Map<String, dynamic> m, String key, String what) {
    final Object? raw = m[key];
    if (raw is! String) {
      _bad('$what.$key should be one of ${fromWire.keys.join(', ')}');
    }
    final T? found = fromWire[raw];
    if (found == null) {
      _bad(
        '$what.$key holds "$raw", which this version does not know. '
        'Known values: ${fromWire.keys.join(', ')}',
      );
    }
    return found;
  }

  /// Absent means absent. A value that IS there but unrecognised still
  /// throws: silence about a missing field is fine, silence about a field
  /// holding something unreadable is not.
  T? decodeOptional(Map<String, dynamic> m, String key, String what) {
    final Object? raw = m[key];
    if (raw == null) return null;
    return decodeRequired(m, key, what);
  }
}

Wire<T> _makeWire<T>(Map<T, String> forward) => Wire<T>(forward, <String, T>{
  for (final MapEntry<T, String> e in forward.entries) e.value: e.key,
});

final Wire<TransactionType> transactionTypeWire =
    _makeWire(<TransactionType, String>{
      TransactionType.expense: 'expense',
      TransactionType.income: 'income',
      TransactionType.transfer: 'transfer',
    });

final Wire<TransactionStatus> transactionStatusWire =
    _makeWire(<TransactionStatus, String>{
      TransactionStatus.pending: 'pending',
      TransactionStatus.confirmed: 'confirmed',
      TransactionStatus.reconciled: 'reconciled',
      TransactionStatus.duplicate: 'duplicate',
      TransactionStatus.corrected: 'corrected',
      TransactionStatus.excluded: 'excluded',
    });

final Wire<ProfileEntity> profileWire = _makeWire(<ProfileEntity, String>{
  ProfileEntity.personal: 'personal',
  ProfileEntity.household: 'household',
  ProfileEntity.business: 'business',
  // NOT `sideHustle`. See the header.
  ProfileEntity.sideHustle: 'side_hustle',
});

final Wire<AccountKind> accountKindWire = _makeWire(<AccountKind, String>{
  AccountKind.cash: 'cash',
  AccountKind.bank: 'bank',
  AccountKind.gcash: 'gcash',
  AccountKind.maya: 'maya',
  AccountKind.debit: 'debit',
  AccountKind.credit: 'credit',
  AccountKind.loan: 'loan',
  AccountKind.mortgage: 'mortgage',
  AccountKind.investment: 'investment',
  AccountKind.receivable: 'receivable',
});

final Wire<CurrencyCode> currencyWire = _makeWire(<CurrencyCode, String>{
  CurrencyCode.php: 'PHP',
  CurrencyCode.usd: 'USD',
  CurrencyCode.eur: 'EUR',
  CurrencyCode.jpy: 'JPY',
  CurrencyCode.sgd: 'SGD',
});

final Wire<CardNetwork> cardNetworkWire = _makeWire(<CardNetwork, String>{
  CardNetwork.none: 'none',
  CardNetwork.visa: 'visa',
  CardNetwork.mastercard: 'mastercard',
  CardNetwork.amex: 'amex',
  CardNetwork.jcb: 'jcb',
});

final Wire<CardTier> cardTierWire = _makeWire(<CardTier, String>{
  CardTier.regular: 'regular',
  CardTier.gold: 'gold',
  CardTier.platinum: 'platinum',
  CardTier.black: 'black',
  CardTier.custom: 'custom',
});

final Wire<DebtDirection> debtDirectionWire = _makeWire(<DebtDirection, String>{
  DebtDirection.iOwe: 'i_owe',
  DebtDirection.owedToMe: 'owed_to_me',
});

final Wire<DebtSchedule> debtScheduleWire = _makeWire(<DebtSchedule, String>{
  DebtSchedule.scheduled: 'scheduled',
  DebtSchedule.flexible: 'flexible',
});

final Wire<UpcomingItemType> upcomingTypeWire =
    _makeWire(<UpcomingItemType, String>{
      UpcomingItemType.bill: 'bill',
      UpcomingItemType.subscription: 'subscription',
      UpcomingItemType.payday: 'payday',
      UpcomingItemType.debt: 'debt',
      UpcomingItemType.remittance: 'remittance',
      UpcomingItemType.rent: 'rent',
      UpcomingItemType.insurance: 'insurance',
      UpcomingItemType.tuition: 'tuition',
      UpcomingItemType.government: 'government',
    });

final Wire<IncomeStreamType> incomeStreamTypeWire =
    _makeWire(<IncomeStreamType, String>{
      IncomeStreamType.weeklyIncome: 'weekly_income',
      IncomeStreamType.semimonthlySalary: 'semimonthly_salary',
      IncomeStreamType.monthlySalary: 'monthly_salary',
      IncomeStreamType.freelance: 'freelance',
      IncomeStreamType.irregular: 'irregular',
      IncomeStreamType.thirteenthMonth: 'thirteenth_month',
      IncomeStreamType.remittance: 'remittance',
    });

final Wire<InterestRateType> interestRateTypeWire =
    _makeWire(<InterestRateType, String>{
      InterestRateType.annual: 'annual',
      InterestRateType.monthly: 'monthly',
      InterestRateType.daily: 'daily',
      InterestRateType.fixed: 'fixed',
    });

final Wire<PaymentFrequency> paymentFrequencyWire =
    _makeWire(<PaymentFrequency, String>{
      PaymentFrequency.monthly: 'monthly',
      PaymentFrequency.semimonthly: 'semimonthly',
      PaymentFrequency.biweekly: 'biweekly',
      PaymentFrequency.weekly: 'weekly',
    });

final Wire<DecisionScenario> scenarioWire =
    _makeWire(<DecisionScenario, String>{
      DecisionScenario.conservative: 'conservative',
      DecisionScenario.optimistic: 'optimistic',
    });

/// Salapify 3's own, with no prototype counterpart to match.
final Wire<ThemeMode2> themeWire = _makeWire(<ThemeMode2, String>{
  ThemeMode2.hapon: 'hapon',
  ThemeMode2.gabi: 'gabi',
});

// ---------------------------------------------------------------------------
// Account
// ---------------------------------------------------------------------------

const Set<String> accountKeys = <String>{
  'id',
  'name',
  'kind',
  'institution',
  'balance',
  'monogram',
  'currency',
  'profile',
  'creditLimit',
  'interestRate',
  'accountNumber',
  'dueDate',
  'statementDate',
  'cardNetwork',
  'cardTier',
  'notes',
};

Map<String, dynamic> accountToJson(Account a) => <String, dynamic>{
  'id': a.id,
  'name': a.name,
  'kind': accountKindWire.encode(a.kind),
  'institution': a.institution,
  'balance': a.balance,
  'monogram': a.monogram,
  'currency': currencyWire.encode(a.currency),
  if (a.profile != null) 'profile': profileWire.encode(a.profile!),
  if (a.creditLimit != null) 'creditLimit': a.creditLimit,
  if (a.interestRate != null) 'interestRate': a.interestRate,
  if (a.accountNumber != null) 'accountNumber': a.accountNumber,
  if (a.dueDate != null) 'dueDate': a.dueDate,
  if (a.statementDate != null) 'statementDate': a.statementDate,
  'cardNetwork': cardNetworkWire.encode(a.cardNetwork),
  'cardTier': cardTierWire.encode(a.cardTier),
  if (a.notes != null) 'notes': a.notes,
};

Account accountFromJson(Map<String, dynamic> m) {
  const String what = 'account';
  return Account(
    id: _reqStr(m, 'id', what),
    name: _reqStr(m, 'name', what),
    kind: accountKindWire.decodeRequired(m, 'kind', what),
    institution: _reqStr(m, 'institution', what),
    balance: _reqNum(m, 'balance', what),
    monogram: _reqStr(m, 'monogram', what),
    // A backup written before currencies existed has no field here, and
    // every account in it was pesos. Absent means PHP; present but
    // unreadable still throws.
    currency:
        currencyWire.decodeOptional(m, 'currency', what) ?? CurrencyCode.php,
    profile: profileWire.decodeOptional(m, 'profile', what),
    creditLimit: _optNum(m, 'creditLimit'),
    interestRate: _optNum(m, 'interestRate'),
    accountNumber: _optStr(m, 'accountNumber'),
    dueDate: _optStr(m, 'dueDate'),
    statementDate: _optStr(m, 'statementDate'),
    cardNetwork:
        cardNetworkWire.decodeOptional(m, 'cardNetwork', what) ??
        CardNetwork.none,
    cardTier:
        cardTierWire.decodeOptional(m, 'cardTier', what) ?? CardTier.regular,
    notes: _optStr(m, 'notes'),
  );
}

// ---------------------------------------------------------------------------
// Transaction
// ---------------------------------------------------------------------------

const Set<String> transactionKeys = <String>{
  'id',
  'type',
  'amount',
  'category',
  'accountId',
  'date',
  'createdAt',
  'subcategory',
  'toAccountId',
  'merchant',
  'note',
  'person',
  'tags',
  'status',
  'profile',
};

Map<String, dynamic> transactionToJson(Transaction t) => <String, dynamic>{
  'id': t.id,
  'type': transactionTypeWire.encode(t.type),
  'amount': t.amount,
  'category': t.category,
  'accountId': t.accountId,
  'date': t.date,
  'createdAt': t.createdAt,
  if (t.subcategory != null) 'subcategory': t.subcategory,
  if (t.toAccountId != null) 'toAccountId': t.toAccountId,
  if (t.merchant != null) 'merchant': t.merchant,
  if (t.note != null) 'note': t.note,
  if (t.person != null) 'person': t.person,
  if (t.tags.isNotEmpty) 'tags': t.tags,
  'status': transactionStatusWire.encode(t.status),
  if (t.profile != null) 'profile': profileWire.encode(t.profile!),
};

Transaction transactionFromJson(Map<String, dynamic> m) {
  const String what = 'transaction';
  return Transaction(
    id: _reqStr(m, 'id', what),
    type: transactionTypeWire.decodeRequired(m, 'type', what),
    amount: _reqNum(m, 'amount', what),
    category: _reqStr(m, 'category', what),
    accountId: _reqStr(m, 'accountId', what),
    date: _reqStr(m, 'date', what),
    createdAt: _reqInt(m, 'createdAt', what),
    subcategory: _optStr(m, 'subcategory'),
    toAccountId: _optStr(m, 'toAccountId'),
    merchant: _optStr(m, 'merchant'),
    note: _optStr(m, 'note'),
    person: _optStr(m, 'person'),
    tags: _optStrList(m, 'tags'),
    // The prototype reads `t.status || 'confirmed'` everywhere rather than
    // storing it on every row, so absent means confirmed here too.
    status:
        transactionStatusWire.decodeOptional(m, 'status', what) ??
        TransactionStatus.confirmed,
    profile: profileWire.decodeOptional(m, 'profile', what),
  );
}

// ---------------------------------------------------------------------------
// Debt
// ---------------------------------------------------------------------------

const Set<String> debtKeys = <String>{
  'id',
  'person',
  'direction',
  'totalAmount',
  'paidAmount',
  'isSettled',
  'dueDate',
  'scheduleType',
  'installmentCurrent',
  'installmentTotal',
  'settledDate',
  'notes',
};

Map<String, dynamic> debtToJson(Debt d) => <String, dynamic>{
  'id': d.id,
  'person': d.person,
  'direction': debtDirectionWire.encode(d.direction),
  'totalAmount': d.totalAmount,
  'paidAmount': d.paidAmount,
  'isSettled': d.isSettled,
  if (d.dueDate != null) 'dueDate': d.dueDate,
  // `scheduleType` on the wire, `schedule` in Dart. See the header.
  'scheduleType': debtScheduleWire.encode(d.schedule),
  if (d.installmentCurrent != null) 'installmentCurrent': d.installmentCurrent,
  if (d.installmentTotal != null) 'installmentTotal': d.installmentTotal,
  if (d.settledDate != null) 'settledDate': d.settledDate,
  if (d.notes != null) 'notes': d.notes,
};

Debt debtFromJson(Map<String, dynamic> m) {
  const String what = 'debt';
  return Debt(
    id: _reqStr(m, 'id', what),
    person: _reqStr(m, 'person', what),
    direction: debtDirectionWire.decodeRequired(m, 'direction', what),
    totalAmount: _reqNum(m, 'totalAmount', what),
    paidAmount: _reqNum(m, 'paidAmount', what),
    isSettled: _optBool(m, 'isSettled'),
    dueDate: _optStr(m, 'dueDate'),
    schedule:
        debtScheduleWire.decodeOptional(m, 'scheduleType', what) ??
        DebtSchedule.flexible,
    installmentCurrent: _optInt(m, 'installmentCurrent'),
    installmentTotal: _optInt(m, 'installmentTotal'),
    settledDate: _optStr(m, 'settledDate'),
    notes: _optStr(m, 'notes'),
  );
}

// ---------------------------------------------------------------------------
// Budget, Goal, UpcomingItem, IncomeStream
// ---------------------------------------------------------------------------

const Set<String> budgetKeys = <String>{'category', 'limit', 'emoji'};

Map<String, dynamic> budgetToJson(Budget b) => <String, dynamic>{
  'category': b.category,
  'limit': b.limit,
  'emoji': b.emoji,
};

Budget budgetFromJson(Map<String, dynamic> m) => Budget(
  category: _reqStr(m, 'category', 'budget'),
  limit: _reqNum(m, 'limit', 'budget'),
  emoji: _optStr(m, 'emoji') ?? '',
);

const Set<String> goalKeys = <String>{
  'id',
  'name',
  'emoji',
  'targetAmount',
  'currentAmount',
  'targetDate',
  'monthlyTarget',
};

Map<String, dynamic> goalToJson(Goal g) => <String, dynamic>{
  'id': g.id,
  'name': g.name,
  'emoji': g.emoji,
  'targetAmount': g.targetAmount,
  'currentAmount': g.currentAmount,
  'targetDate': g.targetDate,
  'monthlyTarget': g.monthlyTarget,
};

Goal goalFromJson(Map<String, dynamic> m) => Goal(
  id: _reqStr(m, 'id', 'goal'),
  name: _reqStr(m, 'name', 'goal'),
  emoji: _optStr(m, 'emoji') ?? '',
  targetAmount: _reqNum(m, 'targetAmount', 'goal'),
  currentAmount: _reqNum(m, 'currentAmount', 'goal'),
  targetDate: _optStr(m, 'targetDate') ?? '',
  monthlyTarget: _optNum(m, 'monthlyTarget') ?? 0,
);

const Set<String> upcomingKeys = <String>{
  'id',
  'name',
  'amount',
  'dueDate',
  'type',
  'isIncome',
  'isPaid',
  'category',
};

Map<String, dynamic> upcomingToJson(UpcomingItem u) => <String, dynamic>{
  'id': u.id,
  'name': u.name,
  'amount': u.amount,
  'dueDate': u.dueDate,
  'type': upcomingTypeWire.encode(u.type),
  'isIncome': u.isIncome,
  'isPaid': u.isPaid,
  if (u.category != null) 'category': u.category,
};

UpcomingItem upcomingFromJson(Map<String, dynamic> m) {
  const String what = 'upcoming item';
  return UpcomingItem(
    id: _reqStr(m, 'id', what),
    name: _reqStr(m, 'name', what),
    amount: _reqNum(m, 'amount', what),
    dueDate: _optStr(m, 'dueDate') ?? '',
    type: upcomingTypeWire.decodeRequired(m, 'type', what),
    isIncome: _optBool(m, 'isIncome'),
    isPaid: _optBool(m, 'isPaid'),
    category: _optStr(m, 'category'),
  );
}

const Set<String> incomeStreamKeys = <String>{
  'id',
  'name',
  'type',
  'expectedAmount',
};

Map<String, dynamic> incomeStreamToJson(IncomeStream s) => <String, dynamic>{
  'id': s.id,
  'name': s.name,
  'type': incomeStreamTypeWire.encode(s.type),
  'expectedAmount': s.expectedAmount,
};

IncomeStream incomeStreamFromJson(Map<String, dynamic> m) {
  const String what = 'income stream';
  return IncomeStream(
    id: _reqStr(m, 'id', what),
    name: _reqStr(m, 'name', what),
    type: incomeStreamTypeWire.decodeRequired(m, 'type', what),
    expectedAmount: _reqNum(m, 'expectedAmount', what),
  );
}

// ---------------------------------------------------------------------------
// InstallmentPlan and its extra payments
// ---------------------------------------------------------------------------

Map<String, dynamic> extraPaymentToJson(ExtraPayment e) => <String, dynamic>{
  'id': e.id,
  'date': e.date,
  'amount': e.amount,
  if (e.note != null) 'note': e.note,
};

ExtraPayment extraPaymentFromJson(Map<String, dynamic> m) => ExtraPayment(
  id: _reqStr(m, 'id', 'extra payment'),
  date: _reqStr(m, 'date', 'extra payment'),
  amount: _reqNum(m, 'amount', 'extra payment'),
  note: _optStr(m, 'note'),
);

const Set<String> installmentKeys = <String>{
  'id',
  'name',
  'provider',
  'principal',
  'interestRate',
  'interestRateType',
  'totalInterest',
  'totalPayable',
  'termMonths',
  'paymentFrequency',
  'startDate',
  'maturityDate',
  'installmentAmount',
  'paidInstallments',
  'totalInstallments',
  'runningBalance',
  'principalRemaining',
  'interestRemaining',
  'extraPayments',
  'isSettled',
  'notes',
};

Map<String, dynamic> installmentToJson(InstallmentPlan p) => <String, dynamic>{
  'id': p.id,
  'name': p.name,
  'provider': p.provider,
  'principal': p.principal,
  'interestRate': p.interestRate,
  'interestRateType': interestRateTypeWire.encode(p.interestRateType),
  'totalInterest': p.totalInterest,
  'totalPayable': p.totalPayable,
  'termMonths': p.termMonths,
  'paymentFrequency': paymentFrequencyWire.encode(p.paymentFrequency),
  'startDate': p.startDate,
  'maturityDate': p.maturityDate,
  'installmentAmount': p.installmentAmount,
  'paidInstallments': p.paidInstallments,
  'totalInstallments': p.totalInstallments,
  'runningBalance': p.runningBalance,
  'principalRemaining': p.principalRemaining,
  'interestRemaining': p.interestRemaining,
  'extraPayments': p.extraPayments
      .map(extraPaymentToJson)
      .toList(growable: false),
  'isSettled': p.isSettled,
  if (p.notes != null) 'notes': p.notes,
};

InstallmentPlan installmentFromJson(Map<String, dynamic> m) {
  const String what = 'installment plan';
  return InstallmentPlan(
    id: _reqStr(m, 'id', what),
    name: _reqStr(m, 'name', what),
    provider: _optStr(m, 'provider') ?? '',
    principal: _reqNum(m, 'principal', what),
    interestRate: _optNum(m, 'interestRate') ?? 0,
    interestRateType:
        interestRateTypeWire.decodeOptional(m, 'interestRateType', what) ??
        InterestRateType.annual,
    totalInterest: _optNum(m, 'totalInterest') ?? 0,
    totalPayable: _optNum(m, 'totalPayable') ?? _reqNum(m, 'principal', what),
    termMonths: _optInt(m, 'termMonths') ?? 0,
    paymentFrequency:
        paymentFrequencyWire.decodeOptional(m, 'paymentFrequency', what) ??
        PaymentFrequency.monthly,
    startDate: _optStr(m, 'startDate') ?? '',
    maturityDate: _optStr(m, 'maturityDate') ?? '',
    installmentAmount: _reqNum(m, 'installmentAmount', what),
    paidInstallments: _optInt(m, 'paidInstallments') ?? 0,
    totalInstallments: _reqInt(m, 'totalInstallments', what),
    runningBalance: _optNum(m, 'runningBalance') ?? 0,
    principalRemaining: _optNum(m, 'principalRemaining') ?? 0,
    interestRemaining: _optNum(m, 'interestRemaining') ?? 0,
    extraPayments: readList(
      m['extraPayments'],
      '$what.extraPayments',
    ).map(extraPaymentFromJson).toList(growable: false),
    isSettled: _optBool(m, 'isSettled'),
    notes: _optStr(m, 'notes'),
  );
}

// ---------------------------------------------------------------------------
// ReconciliationRecord
// ---------------------------------------------------------------------------

const Set<String> reconciliationKeys = <String>{
  'id',
  'accountId',
  'date',
  'bookBalance',
  'actualBalance',
  'variance',
  'status',
  'createdAt',
  'notes',
  'adjustmentTxId',
};

/// A reconciliation's outcome is a BOOL in Dart and a STRING on the wire.
///
/// `src/types.ts` declares `status: 'balanced' | 'discrepancy'`. Writing a
/// `balanced: true` beside it would leave two fields meaning the same thing,
/// and the moment they disagreed the prototype would read the stale one, on
/// the single screen whose whole job is to be trustworthy about whether the
/// app and the bank agree.
const String balancedWire = 'balanced';
const String discrepancyWire = 'discrepancy';

/// Refuses an unrecognised status rather than defaulting it.
///
/// Defaulting would have exactly one safe direction and it is not obvious
/// which: calling an unreadable check "balanced" hides a real gap, and
/// calling it a discrepancy invents one. Neither is a guess worth making
/// about whether somebody's bank and their app agreed.
bool _readReconciliationStatus(Map<String, dynamic> m, String what) {
  final Object? raw = m['status'];
  if (raw == balancedWire) return true;
  if (raw == discrepancyWire) return false;
  if (raw == null) {
    // Absent means it was never recorded. The variance still says the truth,
    // and the tolerance is the same one isBalanced uses.
    return isBalanced(_reqNum(m, 'variance', what));
  }
  return _bad(
    '$what.status holds "$raw", expected "$balancedWire" or '
    '"$discrepancyWire"',
  );
}

Map<String, dynamic> reconciliationToJson(ReconciliationRecord r) =>
    <String, dynamic>{
      'id': r.id,
      'accountId': r.accountId,
      'date': r.date,
      'bookBalance': r.bookBalance,
      'actualBalance': r.actualBalance,
      'variance': r.variance,
      'status': r.balanced ? balancedWire : discrepancyWire,
      'createdAt': r.createdAt,
      if (r.notes != null) 'notes': r.notes,
      if (r.adjustmentTxId != null) 'adjustmentTxId': r.adjustmentTxId,
    };

ReconciliationRecord reconciliationFromJson(Map<String, dynamic> m) {
  const String what = 'reconciliation';
  return ReconciliationRecord(
    id: _reqStr(m, 'id', what),
    accountId: _reqStr(m, 'accountId', what),
    date: _reqStr(m, 'date', what),
    bookBalance: _reqNum(m, 'bookBalance', what),
    actualBalance: _reqNum(m, 'actualBalance', what),
    variance: _reqNum(m, 'variance', what),
    balanced: _readReconciliationStatus(m, what),
    createdAt: _reqInt(m, 'createdAt', what),
    notes: _optStr(m, 'notes'),
    adjustmentTxId: _optStr(m, 'adjustmentTxId'),
  );
}

/// Bills, which until now were read from the SEED and never from the file.
///
/// That was not a missing feature, it was a money defect with a measured cost.
/// `computeSafeToSpend` took `SeedData.bills` directly, so a brand new user
/// holding one real ₱50,000 account saw Safe to Spend of ₱0.00: ₱41,184 of
/// demo bills, times the conservative 1.1 multiplier, were reserved against
/// obligations they had never entered and which appeared on no screen in the
/// app. Making these a real stored collection is what lets them be the user's.
const Set<String> billKeys = <String>{
  'id',
  'name',
  'amount',
  'dueDate',
  'isPaid',
};

Map<String, dynamic> billToJson(BillItem b) => <String, dynamic>{
  'id': b.id,
  'name': b.name,
  'amount': b.amount,
  'dueDate': b.dueDate,
  'isPaid': b.isPaid,
};

BillItem billFromJson(Map<String, dynamic> m) => BillItem(
  id: _reqStr(m, 'id', 'bill'),
  name: _reqStr(m, 'name', 'bill'),
  amount: _reqNum(m, 'amount', 'bill'),
  dueDate: _reqStr(m, 'dueDate', 'bill'),
  isPaid: _optBool(m, 'isPaid'),
);

/// The payday cycle, which was a compile time constant read straight off the
/// seed. It said "4 days to payday, Sep 15" on a ledger with nothing in it,
/// and it would have said the same in December, because nothing ever
/// recomputed or stored it.
///
/// `daysToPayday` is the divisor for the per-day figure on Home, so this is
/// money, not a label.
const Set<String> paydayKeys = <String>{
  'cycleType',
  'lastPayday',
  'nextPayday',
  'daysToPayday',
  'expectedIncome',
};

Map<String, dynamic> paydayToJson(PaydayCycle p) => <String, dynamic>{
  'cycleType': p.cycleType,
  'lastPayday': p.lastPayday,
  'nextPayday': p.nextPayday,
  'daysToPayday': p.daysToPayday,
  'expectedIncome': p.expectedIncome,
};

PaydayCycle paydayFromJson(Map<String, dynamic> m) => PaydayCycle(
  cycleType: _optStr(m, 'cycleType') ?? '15_30',
  lastPayday: _optStr(m, 'lastPayday') ?? '',
  nextPayday: _optStr(m, 'nextPayday') ?? '',
  // EVERY field here is optional, and that is a deliberate departure from the
  // rule the rest of this file follows. A required field throws, and a throw
  // makes the whole document unreadable, which stops all saving and shows the
  // person a red banner. That is the right trade for an account balance. It is
  // the wrong trade for a payday cycle: a prototype backup carrying a partial
  // payday object would brick a ledger over a field the app can simply not
  // know. Unknown payday is a state the app already handles.
  //
  // The clamp is not cosmetic. daysToPayday is the divisor for the per-day
  // figure on Home, and a negative would read as "minus three days to payday".
  daysToPayday: (_optNum(m, 'daysToPayday') ?? 0).round().clamp(0, 400),
  expectedIncome: _optNum(m, 'expectedIncome') ?? 0,
);
