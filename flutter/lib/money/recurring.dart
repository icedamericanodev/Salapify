// Recurring bills and income, ported 1:1 from the RN AppData posting effect and
// its restore-time guard (mobile/context/AppData.js). Each recurring item posts
// exactly one transaction per month, on or after its day, into its chosen
// account (moving that balance), stamped with a lastPosted month marker that
// makes double posting impossible. Pure functions over the same data shape the
// backup carries, golden-verified against the RN twin (scratchpad/
// gen-recurring-goldens.js). No dashes.

import 'ledger.dart' show amountOf;

String _monthKey(DateTime now) =>
    '${now.year}-${now.month.toString().padLeft(2, '0')}';

// Days in the reference month. DateTime(year, month + 1, 0) is the last day of
// `month`, the same trick as JS new Date(y, m + 1, 0).
int _daysInMonth(DateTime now) => DateTime(now.year, now.month + 1, 0).day;

// JS `Number(x) || 1`: 0, NaN, and unparseable all fall back to 1.
num _dayOr1(dynamic x) {
  final n = amountOf(x);
  return n == 0 ? 1 : n;
}

bool _postedThisMonthOrLater(dynamic lastPosted, String monthKey) =>
    lastPosted is String && lastPosted.compareTo(monthKey) >= 0;

List<Map<String, dynamic>> _list(dynamic v) => [
      for (final x in (v is List ? v : const []))
        if (x is Map) x.cast<String, dynamic>(),
    ];

/// Post every recurring item that has come due this month, returning a NEW data
/// map (transactions, accounts, recurring updated). `nextId` mints transaction
/// ids; at runtime the store passes its real genId, tests pass a deterministic
/// stub. Returns the input unchanged when nothing is due.
Map<String, dynamic> postDueRecurring(
    Map<String, dynamic> data, DateTime now, String Function() nextId) {
  final monthKey = _monthKey(now);
  final daysInMonth = _daysInMonth(now);
  final recurringIn = _list(data['recurring']);

  bool isDue(Map<String, dynamic> r) {
    final day = _dayOr1(r['dayOfMonth']);
    final cappedDay = day < daysInMonth ? day : daysInMonth;
    return !_postedThisMonthOrLater(r['lastPosted'], monthKey) &&
        now.day >= cappedDay;
  }

  if (!recurringIn.any(isDue)) return data;

  var transactions = _list(data['transactions']);
  var accounts = _list(data['accounts']);

  final recurring = recurringIn.map((r) {
    final day = _dayOr1(r['dayOfMonth']);
    final cappedDay = day < daysInMonth ? day : daysInMonth;
    if (_postedThisMonthOrLater(r['lastPosted'], monthKey) ||
        now.day < cappedDay) {
      return r;
    }
    final dayInt = cappedDay.toInt();
    final date = '$monthKey-${dayInt.toString().padLeft(2, '0')}';
    final amount = amountOf(r['amount']);
    final type = r['type'] == 'income' ? 'income' : 'expense';
    final label = (r['label'] is String && (r['label'] as String).isNotEmpty)
        ? r['label']
        : 'Recurring';
    final tx = <String, dynamic>{
      'id': nextId(),
      'type': type,
      'label': label,
      'amount': amount,
      'date': date,
      'recurringId': r['id'],
    };
    final acctId = r['accountId'];
    Map<String, dynamic>? acct;
    if (acctId is String && acctId.isNotEmpty) {
      for (final a in accounts) {
        if (a['id'] == acctId) {
          acct = a;
          break;
        }
      }
    }
    if (acct != null) {
      tx['accountId'] = acct['id'];
      final delta = (type == 'income' ? 1 : -1) * amount;
      accounts = [
        for (final a in accounts)
          if (a['id'] == acct['id'])
            {...a, 'balance': amountOf(a['balance']) + delta}
          else
            a,
      ];
    }
    transactions = [...transactions, tx];
    return {...r, 'lastPosted': monthKey};
  }).toList();

  return {
    ...data,
    'transactions': transactions,
    'accounts': accounts,
    'recurring': recurring,
  };
}

/// The save-time lastPosted stamp for a recurring item. A day on or before
/// today does NOT post retroactively on add or edit (the user has usually paid
/// that one already), so it is stamped as posted for this month. On edit a
/// marker already in this month or the future is never rolled back. Mirrors the
/// RN recurring screen save().
String recurringSaveLastPosted({
  required num dayOfMonth,
  required String existingLastPosted,
  required DateTime now,
  required bool isEdit,
}) {
  final monthKey = _monthKey(now);
  final daysInMonth = _daysInMonth(now);
  final effectiveDay = dayOfMonth < daysInMonth ? dayOfMonth : daysInMonth;
  final skipThisMonth = effectiveDay <= now.day;
  if (isEdit) {
    return skipThisMonth && existingLastPosted.compareTo(monthKey) < 0
        ? monthKey
        : existingLastPosted;
  }
  return skipThisMonth ? monthKey : '';
}

/// The restore-time guard: a recurring item whose day this month has ALREADY
/// passed gets stamped as posted, because the real posting may have happened
/// after the backup was made and re-posting here would double the bill. An item
/// whose day has not arrived keeps its own lastPosted (so restoring early never
/// skips a bill still to come). Never stamp backwards past a future marker.
List<Map<String, dynamic>> stampRecurringOnRestore(
    dynamic recurringList, DateTime now) {
  final monthKey = _monthKey(now);
  final daysInMonth = _daysInMonth(now);
  return _list(recurringList).map((r) {
    final day = _dayOr1(r['dayOfMonth']);
    final cappedDay = day < daysInMonth ? day : daysInMonth;
    final lp = r['lastPosted'];
    final keep = lp is String && lp.compareTo(monthKey) > 0;
    if (cappedDay <= now.day) {
      return keep ? r : {...r, 'lastPosted': monthKey};
    }
    return r;
  }).toList();
}
