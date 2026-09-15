// Everything the Log sheet knows, and nothing the rest of the app needs.
//
// 02-architecture.md's one rule between the layers: a feature owns a view
// model that reads from LedgerStore and writes back through it, and no screen
// imports another screen's view model. That rule is the whole reason the old
// app's 3,196 line store is not being rebuilt one convenience at a time.
//
// This holds a DRAFT. Nothing here touches the real ledger until [save].
import 'package:flutter/foundation.dart';

import '../../core/data/ledger_store.dart';
import '../categories/category_rows.dart' show pickableCategories;
import '../../core/money/fastlog.dart';
import '../../core/money/ledger.dart';
import '../../core/money/quickadd.dart';

class LogViewModel extends ChangeNotifier {
  LogViewModel(this._store, {DateTime? now})
    : _date = _isoDay(now ?? DateTime.now()) {
    // Preselect the account they last logged from, so a repeat entry is one
    // less tap. Already ported, already careful to skip sample accounts.
    _accountId = lastUsedAccountId(_store.data['transactions'], _accountIds);
  }

  final LedgerStore _store;

  String _line = '';
  String _date;
  String? _accountId;

  /// Set only when the person TAPS a chip. While it is null the parser's guess
  /// is what gets saved, and the moment they overrule it their choice sticks
  /// even if they keep typing. An app that keeps re-guessing over a person's
  /// explicit tap is an app that argues with them.
  String? _pickedCategoryId;
  String? _pickedType;

  /// What they typed.
  String get line => _line;

  /// The reading of it. Recomputed rather than cached: it is a pure function
  /// over a short string and caching it is how the reading and the field drift
  /// apart.
  ParsedLine get parsed =>
      parseLogLine(_line, categories: _store.data['categories']);

  String get type => _pickedType ?? parsed.type;
  String? get categoryId =>
      _pickedCategoryId ?? (type == 'expense' ? parsed.categoryId : null);
  String get date => _date;
  String? get accountId => _accountId;

  /// What the chips offer, which is every category NOT retired.
  ///
  /// Archive reaches money by narrowing what you can pick, never by touching
  /// what already happened: `budgetRows` and the Insights breakdown read the
  /// full list on purpose, so a hidden category that had money through it this
  /// month keeps its row and its slice.
  List<Map<String, dynamic>> get categories => pickableCategories(_store.data);

  List<Map<String, dynamic>> get accounts =>
      (_store.data['accounts'] as List? ?? const [])
          .whereType<Map>()
          .map((a) => a.cast<String, dynamic>())
          .toList();

  Set<String> get _accountIds => {
    for (final a in accounts)
      if (a['id'] is String) a['id'] as String,
  };

  /// Names they have actually typed before, newest first, as one-tap chips.
  List<String> get recent => recentLabels(
    _store.data['transactions'],
    type == 'income' ? 'income' : 'expense',
  );

  /// A TRANSFER CANNOT BE WRITTEN FROM THIS SHEET, and removing the Transfer
  /// segment was not enough to stop it.
  ///
  /// [type] falls back to `parsed.type`, and `fastlog` still infers 'transfer'
  /// from a word like "transfer" or "transferred". That file is golden locked
  /// and byte identical to the shipped app, so the guard has to live here.
  ///
  /// Why it matters: this sheet has ONE account picker and a transfer needs
  /// two, so the row went out with a single accountId and no `flow`.
  /// `balanceSign` reads that as -1, the money left the picked account and
  /// arrived nowhere, and `sanitizeData` then stripped the accountId so even
  /// deleting the entry could not give it back. Measured at 5,000 in and 0
  /// out in test/features/transfer_loss_test.dart.
  ///
  /// It is REFUSED rather than quietly saved as an expense. An expense would
  /// land in budgets and spending totals, and a transfer is deliberately
  /// neither. Refusing costs the user nothing, because the alternative on
  /// offer was destroying the money.
  bool get isTransfer => type == 'transfer';

  /// Can this be saved? An entry with no amount is not an entry.
  bool get canSave => (parsed.amount ?? 0) > 0 && !isTransfer;

  void setLine(String value) {
    _line = value;
    notifyListeners();
  }

  void pickType(String value) {
    _pickedType = value;
    // A category belongs to an expense. Switching away from expense drops any
    // category rather than carrying a stale one into a type that cannot use it.
    if (value != 'expense') _pickedCategoryId = null;
    notifyListeners();
  }

  void pickCategory(String? id) {
    // Tapping the selected chip again clears it, so a wrong guess can be
    // removed rather than only replaced.
    _pickedCategoryId = (id == categoryId) ? null : id;
    notifyListeners();
  }

  /// Accounts SELECT. They do not toggle, and the difference from
  /// [pickCategory] is deliberate rather than an inconsistency.
  ///
  /// A category is a GUESS the parser made, so tapping the highlighted chip to
  /// clear it is how a person overrules a wrong guess. An account is REMEMBERED
  /// from the last entry they logged, so the highlighted chip is their own
  /// previous choice, and tapping it to mean "actually, no account at all" is
  /// nobody's intent.
  ///
  /// The journey test found this the hard way. Tapping "GCash" to be sure it
  /// was selected turned it OFF, the entry saved with no account, and no
  /// balance moved: the save looked like it worked and the money did not
  /// budge. A person double-checking their own entry is the most likely user
  /// of that tap.
  void pickAccount(String? id) {
    if (id == null) return;
    _accountId = id;
    notifyListeners();
  }

  void setDate(DateTime value) {
    _date = _isoDay(value);
    notifyListeners();
  }

  /// Write it.
  ///
  /// The money is one line: [addTransaction] appends the row AND moves the
  /// linked account's balance by the signed amount, and it is golden locked to
  /// the centavo. This method's job is to build an honest transaction map and
  /// then get out of the way. It never computes a balance.
  Future<void> save() async {
    if (!canSave) return;
    final p = parsed;
    final tx = <String, dynamic>{
      'id': 'tx_${DateTime.now().microsecondsSinceEpoch}',
      'type': type,
      'amount': p.amount,
      // sanitizeData falls back to 'Entry' for a blank label. The generic word
      // matching the type is friendlier and is what recentLabels already knows
      // to skip when offering chips.
      'label': p.label.isNotEmpty
          ? p.label
          : (type == 'income' ? 'Income' : 'Expense'),
      'date': _date,
      if (categoryId != null) 'categoryId': categoryId,
      if (_accountId != null) 'accountId': _accountId,
    };
    await _store.apply((s) => addTransaction(s, tx));
  }
}

/// yyyy-mm-dd, the shape every date in the v12 ledger already uses.
String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
