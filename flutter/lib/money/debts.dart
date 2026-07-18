// The debts WRITE engine, ported 1:1 from the money logic in
// mobile/app/(tabs)/debts.js (save lines 132-222, del 223-230, applyPayment
// 238-322, logPayment 323-326, markPaid 330-350) wired to the same reducer
// semantics as mobile/context/AppData.js. Pure: every function takes the
// whole data map and returns a new one; ids and the date are injected so
// tests replay the RN goldens byte for byte.
//
// The accounting shape, straight from the RN comments: one shared payment
// path, so every peso that leaves a debt also leaves the chosen account,
// lands in the payments list, and writes record rows into the transaction
// stream. The record rows carry NO accountId on purpose: the balance move
// happens in the payment itself, and a record deleted later from History
// must never shift a balance again. Principal is a type 'debt' row (a
// balance sheet move the income and expense filters skip); interest is a
// real expense tagged source 'interest'.

import 'debtmath.dart' show splitDebtPayment, formatMoneyText;
import 'ledger.dart' as ledger;

typedef GenId = String Function(String prefix);

List<Map<String, dynamic>> _list(Map<String, dynamic> data, String key) =>
    (data[key] as List? ?? []).cast<Map<String, dynamic>>();

/// JS Number(string): empty and whitespace-only are 0, junk is NaN. Dart
/// double.tryParse already accepts surrounding whitespace, exponents,
/// Infinity, and NaN literals like JS does. (JS also reads hex prefixes,
/// which no money field ever legitimately carries.)
double _jsNumber(String s) {
  final t = s.trim();
  if (t.isEmpty) return 0;
  return double.tryParse(t) ?? double.nan;
}

/// debts.js numIn: strip commas and spaces, then Number(). "50,000" is
/// fifty thousand here like in every other money input in the app. A
/// missing field is JS String(undefined), the word "undefined", which is
/// NaN and fails validation, never a silent zero.
double _numIn(dynamic t) => t == null
    ? double.nan
    : _jsNumber(t.toString().replaceAll(RegExp(r'[, ]'), ''));

/// JS Number(x) preserving NaN, for the !== comparison in the edit path:
/// a missing remaining is undefined in JS, Number(undefined) is NaN, and
/// NaN !== anything, so the interest clock resets.
double _jsNumberOf(dynamic v) {
  if (v == null) return double.nan;
  if (v is bool) return v ? 1 : 0;
  if (v is num) return v.toDouble();
  if (v is String) return _jsNumber(v);
  return double.nan;
}

bool _isInteger(double n) => n.isFinite && n.truncateToDouble() == n;

String _formText(dynamic v) => v == null ? '' : v.toString();

bool _hasId(dynamic id) => id is String && id.isNotEmpty;

Map<String, dynamic> _updateItem(Map<String, dynamic> data, String collection,
    String id, Map<String, dynamic> patch) {
  return {
    ...data,
    collection: [
      for (final it in _list(data, collection))
        it['id'] == id ? {...it, ...patch} : it,
    ],
  };
}

Map<String, dynamic>? _findDebt(Map<String, dynamic> data, dynamic id) {
  for (final d in _list(data, 'debts')) {
    if (d['id'] == id) return d;
  }
  return null;
}

/// The outcome of saveDebt: the exact RN error sentence ('' means saved)
/// and the new state. The saved debt's id rides along for the screen.
class DebtSaveResult {
  final Map<String, dynamic> data;
  final String error;
  final String? id;
  const DebtSaveResult(this.data, this.error, this.id);
}

/// debts.js save(): validate the form the way the RN screen does (same
/// checks, same order, same sentences), then create the debt with the
/// interest clock started today, or patch the existing one, resetting the
/// clock ONLY when the remaining balance was edited, because a typed-in
/// balance is current as of today.
DebtSaveResult saveDebt(Map<String, dynamic> data, Map<String, dynamic> form,
    {required String today, required GenId genId}) {
  if (_formText(form['name']).trim().isEmpty) {
    return DebtSaveResult(data, 'Please enter a name.', null);
  }
  final rem = _numIn(form['remaining']);
  final rate = _numIn(form['monthlyRate']);
  final min = _numIn(form['minPayment']);
  if (form['remaining'] == '' || !rem.isFinite || rem < 0) {
    return DebtSaveResult(data, 'Enter a valid remaining balance.', null);
  }
  if (!rate.isFinite || rate < 0) {
    return DebtSaveResult(data, 'Enter a valid interest %.', null);
  }
  if (!min.isFinite || min < 0) {
    return DebtSaveResult(data, 'Enter a valid minimum payment.', null);
  }
  // Day-of-month fields are optional, but when present must be 1 to 31.
  (String?, int) dayField(dynamic text, String label) {
    final t = _formText(text).trim();
    if (t.isEmpty) return (null, 0);
    final n = _jsNumber(t);
    if (!_isInteger(n) || n < 1 || n > 31) {
      return ('$label should be a day from 1 to 31.', 0);
    }
    return (null, n.toInt());
  }

  final (dueErr, dueDay) = dayField(form['dueDay'], 'Payment due day');
  if (dueErr != null) return DebtSaveResult(data, dueErr, null);
  // The card only fields are validated and saved ONLY for credit cards.
  // Switching a card to another type clears them.
  final isCard = form['type'] == 'credit card';
  final (stmtErr, stmtDay) = isCard
      ? dayField(form['statementDay'], 'Statement day')
      : (null, 0);
  if (stmtErr != null) return DebtSaveResult(data, stmtErr, null);
  var grace = 0;
  var limit = 0.0;
  if (isCard) {
    final graceText = _formText(form['graceDays']).trim();
    final graceNum = graceText.isEmpty ? 0.0 : _jsNumber(graceText);
    if (graceText.isNotEmpty &&
        (!_isInteger(graceNum) || graceNum < 1 || graceNum > 60)) {
      return DebtSaveResult(
          data, 'Days before due should be from 1 to 60.', null);
    }
    grace = graceText.isEmpty ? 0 : graceNum.toInt();
    final limitText =
        _formText(form['creditLimit']).trim().replaceAll(RegExp(r'[, ]'), '');
    limit = limitText.isEmpty ? 0.0 : _jsNumber(limitText);
    if (limitText.isNotEmpty && (!limit.isFinite || limit < 0)) {
      return DebtSaveResult(
          data, 'Enter a valid credit limit, or leave it empty.', null);
    }
    // A statement day alone gives no due date, so reminders would stay
    // silent while the user believes they are covered.
    if (stmtDay != 0 && dueDay == 0 && grace == 0) {
      return DebtSaveResult(
          data,
          'Add the days after statement until due (check your SOA, usually about 20), or a fixed due day, so reminders know when payment is due.',
          null);
    }
  }
  final payload = <String, dynamic>{
    'name': _formText(form['name']).trim(),
    'type': form['type'],
    'remaining': rem,
    'monthlyRate': rate,
    'minPayment': min,
    'dueDay': dueDay,
    'statementDay': isCard ? stmtDay : 0,
    'graceDays': grace,
    'creditLimit': limit,
  };
  if (_hasId(form['id'])) {
    final id = form['id'] as String;
    // A typed in balance is current as of today, so reset the interest
    // clock when the remaining balance was edited.
    final existing = _findDebt(data, id);
    if (existing == null || _jsNumberOf(existing['remaining']) != rem) {
      payload['interestThroughISO'] = today;
    }
    return DebtSaveResult(_updateItem(data, 'debts', id, payload), '', id);
  }
  // New debt: start the interest clock now, so a first payment does not
  // back accrue interest for time before the debt existed in the app.
  final id = genId('debts');
  return DebtSaveResult({
    ...data,
    'debts': [
      ..._list(data, 'debts'),
      {...payload, 'interestThroughISO': today, 'id': id},
    ],
  }, '', id);
}

/// debts.js del(): remove the debt only. Payments and transaction records
/// stay on purpose; history already happened.
Map<String, dynamic> deleteDebt(Map<String, dynamic> data, dynamic id) {
  if (!_hasId(id)) return data;
  return {
    ...data,
    'debts': [
      for (final d in _list(data, 'debts'))
        if (d['id'] != id) d,
    ],
  };
}

/// What applyDebtPayment did, with the same logged message the RN screen
/// shows and the celebration flag for a debt cleared to zero.
class DebtPayResult {
  final Map<String, dynamic> data;
  final String msg;
  final bool celebrated;
  final double? newRemaining;
  const DebtPayResult(this.data, this.msg,
      {this.celebrated = false, this.newRemaining});
}

/// debts.js applyPayment(): the one shared payment path. Splits the amount
/// into interest and principal by day-count accrual, lowers the debt,
/// debits the chosen account for what was actually applied (an overpayment
/// is never taken), records the payment row (pending for credit cards,
/// posted otherwise), and writes the principal and interest record rows.
DebtPayResult applyDebtPayment(Map<String, dynamic> data,
    Map<String, dynamic> form, String? payFrom, double amt,
    {required String today, required GenId genId}) {
  if (!_hasId(form['id']) || amt <= 0) return DebtPayResult(data, '');
  final debtId = form['id'] as String;
  // Read the balance from the store, never from the edit field: a cleared
  // or half-typed Remaining box must not zero out a real debt.
  final debt = _findDebt(data, debtId);
  final cur = debt != null
      ? ledger.amountOf(debt['remaining'])
      : ledger.amountOf(form['remaining']);
  final rate = debt != null
      ? ledger.amountOf(debt['monthlyRate'])
      : ledger.amountOf(form['monthlyRate']);
  final stamp = today;
  final split = splitDebtPayment(
      cur, rate, debt != null ? debt['interestThroughISO'] : null, amt, stamp);
  final accrued = split['accrued'] as double;
  final applied = split['applied'] as double;
  final interestPortion = split['interest'] as double;
  final principalPortion = split['principal'] as double;
  final newRem = split['newRemaining'] as double;
  final overpay = split['overpay'] as double;
  var next = _updateItem(
      data, 'debts', debtId, {'remaining': newRem, 'interestThroughISO': stamp});
  // Cash leaves only for what was actually applied.
  Map<String, dynamic>? acct;
  for (final a in _list(next, 'accounts')) {
    if (a['id'] == payFrom) {
      acct = a;
      break;
    }
  }
  if (acct != null && applied > 0) {
    next = _updateItem(next, 'accounts', acct['id'] as String,
        {'balance': ledger.amountOf(acct['balance']) - applied});
  }
  // Credit card payments start as pending, because banks take a day or
  // three to post them. Other debts post right away.
  final isCard = (debt != null ? debt['type'] : form['type']) == 'credit card';
  next = {
    ...next,
    'payments': [
      ..._list(next, 'payments'),
      {
        'debtId': debtId,
        'amount': applied,
        'interest': interestPortion,
        'principal': principalPortion,
        'date': today,
        'account': acct != null ? acct['id'] : '',
        'status': isCard ? 'pending' : 'posted',
        'id': genId('payments'),
      },
    ],
  };
  final debtName = debt != null ? debt['name'] : null;
  final formName = form['name'];
  final name = (debtName is String && debtName.isNotEmpty)
      ? debtName
      : (formName is String && formName.isNotEmpty)
          ? formName
          : 'Debt';
  if (principalPortion > 0) {
    next = ledger.addTransaction(next, {
      'type': 'debt',
      'label': 'Debt payment: $name',
      'amount': principalPortion,
      'date': today,
      'debtId': debtId,
      'id': genId('transactions'),
    });
  }
  if (interestPortion > 0) {
    next = ledger.addTransaction(next, {
      'type': 'expense',
      'label': 'Interest: $name',
      'amount': interestPortion,
      'date': today,
      'debtId': debtId,
      'source': 'interest',
      'id': genId('transactions'),
    });
  }
  var msg =
      'Logged ${formatMoneyText(applied)}${acct != null ? ' from ${acct['name']}' : ''}.';
  if (interestPortion > 0) {
    msg += ' ${formatMoneyText(interestPortion)} of it was interest.';
  }
  // Balance only grows when the payment falls short of the interest that
  // accrued. Paying exactly the interest holds it flat.
  if (applied < accrued) {
    msg += ' That did not cover the interest, so the balance grew.';
  }
  if (overpay > 0) {
    msg +=
        ' ${formatMoneyText(overpay)} was more than you owed and was not taken.';
  }
  msg += ' New balance ${formatMoneyText(newRem)}.';
  return DebtPayResult(next, msg,
      celebrated: newRem == 0 && cur > 0, newRemaining: newRem);
}

/// debts.js logPayment(): parse the typed amount ("2,500" is twenty five
/// hundred) and pay. Junk parses to 0 and records nothing.
DebtPayResult logDebtPayment(Map<String, dynamic> data,
    Map<String, dynamic> form, String? payFrom, dynamic payAmount,
    {required String today, required GenId genId}) {
  final cleaned = (payAmount ?? '').toString().replaceAll(RegExp(r'[, ]'), '');
  return applyDebtPayment(data, form, payFrom, ledger.amountOf(cleaned),
      today: today, genId: genId);
}

/// debts.js markPaid(): a real payment of everything still owed including
/// the interest accrued since the last payment, never a silent zeroing.
DebtPayResult markDebtPaid(Map<String, dynamic> data,
    Map<String, dynamic> form, String? payFrom,
    {required String today, required GenId genId}) {
  if (!_hasId(form['id'])) return DebtPayResult(data, '');
  final debt = _findDebt(data, form['id']);
  final remaining = debt != null ? ledger.amountOf(debt['remaining']) : 0.0;
  if (remaining <= 0) return DebtPayResult(data, 'Already at zero.');
  final rate = debt != null ? ledger.amountOf(debt['monthlyRate']) : 0.0;
  final balance = splitDebtPayment(remaining, rate,
      debt != null ? debt['interestThroughISO'] : null, 0, today)['balance']
      as double;
  return applyDebtPayment(
      data, form, payFrom, balance > 0 ? balance : remaining,
      today: today, genId: genId);
}
