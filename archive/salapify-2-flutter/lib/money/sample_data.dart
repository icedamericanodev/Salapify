// The sample data a new user can choose to explore, adapted from the RN
// seed (mobile/lib/sampleData.js). Two deliberate differences from RN:
//
// 1. RN seeds this on first run and offers a destructive wipe to start
//    clean. Flutter starts EMPTY and seeds this only when the user asks,
//    so there is nothing to wipe, no confirm dialog, and no way to lose
//    real data through onboarding.
// 2. Every row id carries the sample_ prefix, so unlike RN (where only the
//    five transactions were tagged and the sample accounts became
//    indistinguishable from real ones forever), the whole set can be
//    removed in one tap, exactly, later.
//
// The transaction ids keep the RN t1..t5 tail for the one contract that
// matters: sample rows must never feed a habit feature. chain.dart excludes
// exactly this set, the same three-place rule RN keeps.

/// The transaction ids the habit features must ignore.
const Set<String> sampleTxIds = {
  'sample_t1',
  'sample_t2',
  'sample_t3',
  'sample_t4',
  'sample_t5',
};

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// A day-of-current-month date that is never in the future, the RN _day
/// rule, so the sample month always reads as "so far this month".
String _day(DateTime ref, int n) =>
    _iso(DateTime(ref.year, ref.month, n > ref.day ? ref.day : n));

/// The collections to merge into an empty store when the user picks
/// "Explore the sample data first". Additive by design; the caller only
/// offers it when the store is empty.
Map<String, dynamic> sampleData(DateTime ref) => {
  'accounts': [
    {
      'id': 'sample_cash',
      'name': 'Cash on hand',
      'icon': '💵',
      'kind': 'cash',
      'balance': 3200,
    },
    {
      'id': 'sample_bpi',
      'name': 'BPI Savings',
      'icon': '🏦',
      'brand': 'BPI',
      'kind': 'savings',
      'balance': 48500,
    },
    {
      'id': 'sample_gcash',
      'name': 'GCash',
      'icon': '📱',
      'brand': 'GCash',
      'kind': 'ewallet',
      'balance': 1750,
    },
  ],
  'debts': [
    {
      'id': 'sample_d1',
      'name': 'Credit Card',
      'type': 'credit card',
      'remaining': 18500,
      'monthlyRate': 3.5,
      'minPayment': 1500,
    },
    {
      'id': 'sample_d2',
      'name': 'Personal Loan',
      'type': 'personal loan',
      'remaining': 42000,
      'monthlyRate': 1.2,
      'minPayment': 3500,
    },
    {
      'id': 'sample_d3',
      'name': 'Phone (BNPL)',
      'type': 'bnpl',
      'remaining': 6000,
      'monthlyRate': 0,
      'minPayment': 1000,
    },
  ],
  'transactions': [
    {
      'id': 'sample_t1',
      'type': 'income',
      'label': 'Salary',
      'amount': 15000,
      'date': _day(ref, 1),
      'accountId': 'sample_bpi',
    },
    {
      'id': 'sample_t2',
      'type': 'income',
      'label': 'Freelance',
      'amount': 4000,
      'date': _day(ref, 3),
      'accountId': 'sample_gcash',
    },
    {
      'id': 'sample_t3',
      'type': 'expense',
      'label': 'Groceries',
      'amount': 2300,
      'date': _day(ref, 5),
      'accountId': 'sample_cash',
    },
    {
      'id': 'sample_t4',
      'type': 'expense',
      'label': 'Transport',
      'amount': 850,
      'date': _day(ref, 8),
      'accountId': 'sample_gcash',
    },
    {
      'id': 'sample_t5',
      'type': 'expense',
      'label': 'Bills',
      'amount': 3200,
      'date': _day(ref, 10),
      'accountId': 'sample_bpi',
    },
  ],
  'people': [
    {'id': 'sample_p1', 'name': 'Juan'},
  ],
  // One friendly receivable, future-dated on purpose so no fake overdue
  // utang greets a new user. Payables stay empty, the RN rule: never seed
  // a fake debt the user owes.
  'receivables': [
    {
      'id': 'sample_r1',
      'personId': 'sample_p1',
      'person': 'Juan',
      'amount': 500,
      'note': 'Lunch',
      'dueDate': _iso(ref.add(const Duration(days: 14))),
      'payments': <Map<String, dynamic>>[],
      'paid': false,
    },
  ],
};

/// True when a row's id marks it as part of the sample set.
bool isSampleId(dynamic id) => id is String && id.startsWith('sample_');

/// Whether any sample rows are present in the store's data.
bool hasSampleData(Map<String, dynamic> data) {
  for (final key in [
    'accounts',
    'debts',
    'transactions',
    'receivables',
    'people',
  ]) {
    final list = data[key];
    if (list is List) {
      for (final row in list) {
        if (row is Map && isSampleId(row['id'])) return true;
      }
    }
  }
  return false;
}
