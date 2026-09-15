// One debt, its history, and the two things you can do to it.
//
// The list says what is owed. This says how it got there and lets the founder
// move it. Pushed over the shell, like account detail, so it carries a
// BackBar.
//
// EVERY WRITE GOES THROUGH THE GOLDEN LOCKED ENGINE. Not one peso is computed
// here. `applyDebtPayment` splits a payment into interest and principal from
// the rate and the days since the last payment, moves the cash out of the
// account the founder picked, and writes the transaction. `logPartial` does
// the receivable side, where collecting a tracked utang is a TRANSFER back
// into the account the money originally left rather than income, so the round
// trip leaves net worth where it started. Reimplementing either of those here
// would be a second definition of a payment, and the one in core/money is the
// one with the test vectors behind it.
import 'package:flutter/material.dart';

import '../../app/clock.dart';
import '../../app/ledger_scope.dart';
import '../../core/money/debts.dart' as debts_engine;
import '../../core/money/format.dart';
import '../../core/money/institutions.dart' show initialsFor;
import '../../core/money/ledger.dart' show amountOf;
import '../../core/money/receivables.dart' as receivables_engine;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../home/home_screen.dart' show shortDate;
import '../shared/editor_safety.dart';
import 'debt_rows.dart';

class DebtDetailScreen extends StatefulWidget {
  const DebtDetailScreen({super.key, required this.id, required this.source});

  /// The stored row's id, never the row itself. The row has to come from the
  /// LIVE store or the screen keeps showing the balance as it was when it was
  /// opened, which is wrong the moment a payment lands behind it.
  final String id;
  final DebtSource source;

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final data = context.ledger.data;
    final board = debtBoardFrom(data, context.now);

    DebtRow? row;
    for (final side in [board.iOwe, board.owedToMe]) {
      for (final r in [...side.open, ...side.settled]) {
        if (r.id == widget.id && r.source == widget.source) row = r;
      }
    }

    if (row == null) {
      // Reachable for real: the row can be deleted from another surface while
      // this screen sits on the stack, and a crash here would be a crash on
      // coming back to an open screen.
      return const _Page(
        children: [
          BackBar(),
          SizedBox(height: 20),
          EmptyState(
            icon: Icons.help_outline_rounded,
            title: 'This debt is gone',
            body: 'It may have been deleted since this screen was opened.',
          ),
        ],
      );
    }

    final r = row;
    final payments = _paymentsOf(data, r);

    return _Page(
      children: [
        const BackBar(),
        const SizedBox(height: 14),
        ScreenTitle(title: r.name, sub: _headline(r)),
        const SizedBox(height: 18),
        _Balance(row: r),
        const SizedBox(height: 18),
        if (!r.settled && r.writable) ...[
          _Actions(
            row: r,
            onRecord: () => _recordPayment(context, r),
            onSettle: () => _settle(context, r),
          ),
          const SizedBox(height: 22),
        ],
        if (!r.writable) ...[_ReadOnlyNote(), const SizedBox(height: 22)],
        const Head(title: 'Payments'),
        const SizedBox(height: 10),
        if (payments.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No payments yet',
            body: 'Every payment you record shows here, newest first.',
          )
        else
          Group(
            children: [
              for (final p in payments)
                ItemRow(
                  icon: Icons.check_rounded,
                  title: _paymentDateLabel(p['date']),
                  sub: _paymentSub(p),
                  amount: formatMoney(amountOf(p['amount'])),
                  tone: Tone.good,
                ),
            ],
          ),
      ],
    );
  }

  /// The one sentence under the name.
  String _headline(DebtRow r) {
    if (r.settled) return 'Settled, all paid.';
    if (r.source == DebtSource.receivables) {
      return 'What this person still owes you.';
    }
    return 'What you still owe.';
  }

  /// The payment list, newest first.
  ///
  /// The two sides keep their history in DIFFERENT places, which is the stored
  /// schema and not a choice made here. A receivable carries its own
  /// `payments` array on the row. A LOAN does not: `applyDebtPayment` appends
  /// to a TOP LEVEL `payments` collection tagged with `debtId`, and also
  /// writes the ledger entries for the principal and the interest separately.
  ///
  /// The first version of this screen returned an empty list for a loan and
  /// showed "No payments yet. Every payment you record shows here, newest
  /// first." That sentence would have stayed on screen after ten payments,
  /// which is a promise the screen could never keep. Caught by rendering it
  /// and reading the engine rather than by any test.
  List<Map<String, dynamic>> _paymentsOf(Map<String, dynamic> data, DebtRow r) {
    if (r.source == DebtSource.debts) {
      final mine = [
        for (final p
            in (data['payments'] is List ? data['payments'] as List : const []))
          if (p is Map && (p['debtId'] ?? '').toString() == r.id)
            p.cast<String, dynamic>(),
      ];
      return _newestFirst(mine);
    }
    final key = r.source == DebtSource.receivables ? 'receivables' : 'payables';
    for (final raw in (data[key] is List ? data[key] as List : const [])) {
      if (raw is! Map) continue;
      if ((raw['id'] ?? '').toString() != r.id) continue;
      final list = [
        for (final p
            in (raw['payments'] is List ? raw['payments'] as List : const []))
          if (p is Map) p.cast<String, dynamic>(),
      ];
      return _newestFirst(list);
    }
    return const [];
  }

  /// Newest first, with ties broken on STORED POSITION.
  ///
  /// A stored date carries no time, so every payment made on one day ties, and
  /// `List.sort` is not stable: without the tiebreak the order of same-day
  /// payments is arbitrary and changes between builds. That exact defect put
  /// the five OLDEST entries of the day under a "Latest" heading on Home.
  List<Map<String, dynamic>> _newestFirst(List<Map<String, dynamic>> list) {
    final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])]
      ..sort((a, b) {
        final c = (b.$2['date'] ?? '').toString().compareTo(
          (a.$2['date'] ?? '').toString(),
        );
        return c != 0 ? c : b.$1.compareTo(a.$1);
      });
    return [for (final e in indexed) e.$2];
  }

  /// What a payment row says under its date.
  ///
  /// The interest split is the most useful fact about a loan payment and the
  /// engine already computed it, so it is shown rather than left in the store.
  /// A card payment that the bank has not posted yet says so: `applyDebtPayment`
  /// marks credit card payments `pending` on purpose, because banks take a day
  /// or three, and a row claiming a payment landed when it has not is the kind
  /// of small lie that costs a late fee.
  String _paymentSub(Map<String, dynamic> p) {
    if ((p['status'] ?? '').toString() == 'pending') {
      return 'Sent, not posted yet';
    }
    final interest = amountOf(p['interest']);
    if (interest > 0) return '${formatMoney(interest)} of it was interest';
    return 'Payment';
  }

  String _paymentDateLabel(dynamic iso) {
    final d = DateTime.tryParse((iso ?? '').toString());
    return d == null ? 'Payment' : shortDate(d);
  }

  /// Ask for an amount and, for a loan, which account pays it, then hand both
  /// to the engine.
  Future<void> _recordPayment(BuildContext context, DebtRow r) async {
    final result = await showModalBottomSheet<_PaymentInput>(
      context: context,
      isScrollControlled: true,
      // The shell draws the nav bar in a Stack OVER the tab, so a sheet opened
      // without this lands in the tab's own Navigator and renders UNDERNEATH
      // the bar, with its bottom controls unreachable.
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _PaymentSheet(row: r, accounts: _payFromAccounts(context)),
    );
    if (result == null || !context.mounted) return;
    await _applyPayment(context, r, result.amount, result.accountId);
  }

  /// The accounts a debt payment can come out of.
  ///
  /// Only the `accounts` collection: money is paid out of cash and bank, never
  /// out of an asset holding or another debt.
  List<Map<String, dynamic>> _payFromAccounts(BuildContext context) => [
    for (final a
        in (context.ledger.data['accounts'] is List
            ? context.ledger.data['accounts'] as List
            : const []))
      if (a is Map && (a['id'] ?? '').toString().isNotEmpty)
        a.cast<String, dynamic>(),
  ];

  /// Settle the whole thing.
  ///
  /// A LOAN goes through the payment sheet prefilled with what is left, not
  /// through a bare confirm. `markDebtPaid` debits the account named in
  /// `payFrom` and debits nothing at all when that is null, so a one tap
  /// settle with no account would clear the debt without any money leaving and
  /// hand the founder a net worth rise they did not earn. Routing it through
  /// the sheet means there is no path to settling a loan that does not say
  /// where the money came from.
  ///
  /// A RECEIVABLE does not need one: `markPaid` posts its own cash leg from
  /// the account the money originally left, so collecting is a transfer back
  /// and the round trip is net worth neutral by construction.
  Future<void> _settle(BuildContext context, DebtRow r) async {
    if (r.source == DebtSource.debts) {
      final result = await showModalBottomSheet<_PaymentInput>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _PaymentSheet(
          row: r,
          accounts: _payFromAccounts(context),
          prefillFull: true,
        ),
      );
      if (result == null || !context.mounted) return;
      await _applyPayment(context, r, result.amount, result.accountId);
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.skin.card,
        title: Text(
          'Settle this debt?',
          style: TypeScale.sheetTitle(context.skin.text),
        ),
        content: Text(
          r.source == DebtSource.receivables
              ? 'This records the remaining ${formatMoney(r.remaining)} as '
                    'collected in full.'
              : 'This records the remaining ${formatMoney(r.remaining)} as '
                    'paid in full, including any interest since your last '
                    'payment.',
          style: TypeScale.subtitle(context.skin.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Settle'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final store = context.ledger;
    final today = isoOf(context.now);
    try {
      if (r.source == DebtSource.receivables) {
        await store.apply(
          (s) =>
              receivables_engine.markPaid(s, r.id, today: today, genId: _genId),
        );
      } else {
        await store.apply(
          (s) => debts_engine
              .markDebtPaid(s, {'id': r.id}, null, today: today, genId: _genId)
              .data,
        );
      }
    } catch (e) {
      if (context.mounted) _say(context, 'Could not save that. $e');
      return;
    }
    if (context.mounted) _say(context, 'Settled.');
  }

  Future<void> _applyPayment(
    BuildContext context,
    DebtRow r,
    String amount,
    String? payFrom,
  ) async {
    final store = context.ledger;
    final today = isoOf(context.now);
    // Replaced by the engine's own wording on the loan path, which explains
    // the interest split. The receivable path has no such message to offer.
    var message = 'Payment recorded.';
    try {
      if (r.source == DebtSource.receivables) {
        // No account argument, and that is not an omission. `logPartial` posts
        // the cash leg itself, reading the account the money originally left
        // off the receivable row, so collecting a tracked utang is a TRANSFER
        // back into that account rather than income and the round trip leaves
        // net worth exactly where it started.
        await store.apply(
          (s) => receivables_engine.logPartial(
            s,
            r.id,
            amount,
            today: today,
            genId: _genId,
          ),
        );
      } else {
        // PAY FROM AN ACCOUNT, ALWAYS. `applyDebtPayment` debits the account
        // whose id matches `payFrom` and silently debits NOTHING when no id
        // matches, so a null here would drop the debt while no money left
        // anywhere: net worth would rise by the size of the payment. The sheet
        // cannot return without an account for exactly this reason.
        //
        // The engine's own message is kept and shown. It is the only place
        // that says how much of the payment went to INTEREST, whether the
        // payment failed to cover the interest so the balance grew, and how
        // much of an overpayment was refused. A generic "Payment recorded"
        // throws all of that away, and on a loan the interest split is the
        // most useful sentence the app can say.
        await store.apply((s) {
          final result = debts_engine.logDebtPayment(
            s,
            {'id': r.id},
            payFrom,
            amount,
            today: today,
            genId: _genId,
          );
          message = result.msg;
          return result.data;
        });
      }
    } catch (e) {
      if (context.mounted) _say(context, 'Could not save that. $e');
      return;
    }
    if (context.mounted) _say(context, message);
  }

  void _say(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Ids for new payment records. Prefixed like every other id the engine makes,
/// and unique because a payment recorded twice in one millisecond would
/// otherwise collide.
int _idSeq = 0;
String _genId(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_idSeq++}';

/// The engine takes an ISO date string, so the clock is converted once here
/// rather than at four call sites.
String isoOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class _Balance extends StatelessWidget {
  const _Balance({required this.row});
  final DebtRow row;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Panel(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.settled ? 'Settled' : 'Still owed',
              style: TypeScale.caption(skin.text2),
            ),
            const SizedBox(height: 4),
            Text(
              formatMoney(row.remaining),
              style: TypeScale.sheetTitle(
                row.settled
                    ? skin.good
                    : (row.source == DebtSource.receivables
                          ? skin.good
                          : skin.accent),
              ),
            ),
            if (row.hasProgress && !row.settled) ...[
              const SizedBox(height: 12),
              ThinBar(fraction: row.progress),
              const SizedBox(height: 8),
              Text(
                '${formatMoney(row.paidSoFar)} of '
                '${formatMoney(row.original)} paid',
                style: TypeScale.caption(skin.text3),
              ),
            ],
            if (row.nextDueIso != null && !row.settled) ...[
              const SizedBox(height: 10),
              Text(() {
                final d = DateTime.tryParse(row.nextDueIso!);
                return d == null
                    ? 'Next payment due soon'
                    : 'Next payment due ${shortDate(d)}';
              }(), style: TypeScale.caption(skin.text2)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.row,
    required this.onRecord,
    required this.onSettle,
  });

  final DebtRow row;
  final VoidCallback onRecord;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: PillButton(label: 'Record a payment', onTap: onRecord),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: PillButton(
          label: row.source == DebtSource.receivables
              ? 'Mark collected'
              : 'Mark settled',
          secondary: true,
          onTap: onSettle,
        ),
      ),
    ],
  );
}

/// Why a payable has no buttons.
///
/// A dead control is worse than an explained absence. `payables` has no write
/// engine in this app or in either frozen one, so a Record payment button over
/// one would do nothing on tap, which is the exact defect Home's quick actions
/// had to be fixed for.
class _ReadOnlyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Panel(
    child: Text(
      'This one came from an older backup and Salapify cannot change it yet. '
      'It still counts towards what you owe.',
      style: TypeScale.caption(context.skin.text2),
    ),
  );
}

/// What the sheet hands back: how much, and out of which account.
///
/// A record rather than a bare string, because the account is not optional for
/// a loan and a String return had no room to carry it. That shape is what let
/// the first version pass null and invent money.
class _PaymentInput {
  const _PaymentInput(this.amount, this.accountId);
  final String amount;
  final String? accountId;
}

/// Type an amount, pick the account, tap Save.
class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({
    required this.row,
    required this.accounts,
    this.prefillFull = false,
  });

  final DebtRow row;
  final List<Map<String, dynamic>> accounts;

  /// Start with the whole remaining balance typed in, for the settle path.
  final bool prefillFull;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late final TextEditingController _controller;
  String? _accountId;
  String? _error;

  /// A loan payment must name the account it came from. A receivable must not:
  /// its engine reads the account off the stored row.
  bool get _needsAccount => widget.row.source == DebtSource.debts;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      // `moneyField`, not toStringAsFixed(0), which rounded 20,000.50 to 20001
      // and saved it. That was a real defect in the budget editor.
      text: widget.prefillFull ? moneyField(widget.row.remaining) : '',
    );
    // Preselect when there is only one place the money could come from, so the
    // common case is one tap. Never guess between two.
    if (widget.accounts.length == 1) {
      _accountId = (widget.accounts.first['id'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Live feedback as the founder types.
  ///
  /// Not a check on Save. A message set in the same frame as a pop is never
  /// seen, which is the defect the budget editor had to be fixed for (D21): a
  /// sheet that explains has to explain BEFORE the button is pressed.
  void _check(String text) {
    // `readMoney` returns a null value for anything unparseable, and rejects
    // NaN and Infinity, which `double.tryParse` happily accepts and
    // `sanitizeData` would then coerce to zero: a sheet reporting a saved
    // payment that wiped a real balance.
    final v = readMoney(text).value;
    setState(() {
      if (text.trim().isEmpty) {
        _error = null;
      } else if (v == null || v <= 0) {
        _error = 'Enter an amount greater than zero.';
      } else if (v > widget.row.remaining) {
        // Not refused. The engine already caps a payment at what is left, so
        // this says what WILL happen rather than blocking a real overpayment
        // the founder is describing correctly.
        _error =
            'That is more than the ${formatMoney(widget.row.remaining)} left. '
            'Salapify will record ${formatMoney(widget.row.remaining)} and '
            'settle it.';
      } else {
        _error = null;
      }
    });
  }

  bool get _canSave {
    final v = readMoney(_controller.text).value;
    if (v == null || v <= 0) return false;
    // The guard that stops money being invented. Without an account the engine
    // debits nothing and the debt still falls.
    if (_needsAccount && (_accountId == null || _accountId!.isEmpty)) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: skin.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Record a payment',
                  style: TypeScale.sheetTitle(skin.text),
                ),
                const Spacer(),
                Text(
                  initialsFor(widget.row.name),
                  style: TypeScale.caption(skin.text3),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${formatMoney(widget.row.remaining)} left on '
              '${widget.row.name}.',
              style: TypeScale.caption(skin.text2),
            ),
            const SizedBox(height: 16),
            Text('Amount', style: TypeScale.fieldLabel(skin.text3)),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              style: TypeScale.input(skin.text),
              onChanged: _check,
              decoration: InputDecoration(
                hintText: formatMoney(widget.row.remaining),
                hintStyle: TypeScale.input(skin.text3),
                filled: true,
                fillColor: skin.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              // Accent, never red. Typing more than is left is not an error,
              // it is a thing the engine handles, and the note says what will
              // happen rather than scolding.
              Text(_error!, style: TypeScale.caption(skin.accent)),
            ],
            if (_needsAccount) ...[
              const SizedBox(height: 18),
              Text('Paid from', style: TypeScale.fieldLabel(skin.text3)),
              const SizedBox(height: 10),
              if (widget.accounts.isEmpty)
                Text(
                  'Add a cash or bank account first, so Salapify knows where '
                  'this payment came from.',
                  style: TypeScale.caption(skin.accent),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in widget.accounts)
                      PickChip(
                        label: (a['name'] ?? '').toString(),
                        on: (a['id'] ?? '').toString() == _accountId,
                        onTap: () => setState(
                          () => _accountId = (a['id'] ?? '').toString(),
                        ),
                      ),
                  ],
                ),
            ],
            const SizedBox(height: 18),
            PillButton(
              label: 'Save',
              onTap: _canSave
                  ? () => Navigator.of(
                      context,
                    ).pop(_PaymentInput(_controller.text, _accountId))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.skin.bg,
    body: Screen(children: children),
  );
}
