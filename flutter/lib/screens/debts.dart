// Debts: the whole picture of what is owed, adapted from the RN debts tab
// on top of the golden-ported write engine. Total debt with the monthly
// minimums and interest cost, a Snowball vs Avalanche strategy switch with
// the focus debt and the debt-free projection, debts grouped by term, and a
// sheet per debt to log a payment (from a chosen account or outside the
// app), mark it paid off as a REAL payment of everything owed, edit, or
// delete. Every peso that leaves a debt goes through the same engine the
// tests replay against the live RN app.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/debtmath.dart'
    show cardForecast, debtFreeProjection, monthlyInterest, splitDebtPayment;
import '../money/ledger.dart' show amountOf;
import '../theme.dart';
import 'log_sheet.dart' show parseAmount;
import 'overview.dart' show formatMoney;

const List<String> kDebtTypes = [
  'credit card',
  'bnpl',
  'personal loan',
  'mortgage',
  'auto',
  'short term',
  'long term',
  'insurance',
  'other',
];

const List<String> _shortTermTypes = [
  'credit card',
  'bnpl',
  'short term',
  'insurance',
];

bool _isShortTerm(dynamic type) => _shortTermTypes.contains(type);

String _todayISO() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

const List<String> _monthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _monthYear(String iso) {
  final p = iso.split('-');
  if (p.length < 2) return iso;
  final m = int.tryParse(p[1]);
  if (m == null || m < 1 || m > 12) return iso;
  return '${_monthsShort[m - 1]} ${p[0]}';
}

String _longDate(String iso) {
  final p = iso.split('-');
  if (p.length < 3) return iso;
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (m == null || m < 1 || m > 12 || d == null) return iso;
  return '${_monthsShort[m - 1]} $d';
}

class DebtsScreen extends StatefulWidget {
  final SalapifyStore store;
  const DebtsScreen({super.key, required this.store});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  String strategy = 'snowball';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final debts = [
          for (final d in (widget.store.data['debts'] as List? ?? const []))
            if (d is Map) d.cast<String, dynamic>(),
        ];
        final totalDebt = debts.fold(
          0.0,
          (t, d) => t + amountOf(d['remaining']),
        );
        final totalMin = debts.fold(
          0.0,
          (t, d) => t + amountOf(d['minPayment']),
        );
        final totalInterest = debts.fold(0.0, (t, d) => t + monthlyInterest(d));

        // JS sort is stable; keep the list order as the tiebreak.
        final indexed = List.generate(debts.length, (i) => (debts[i], i));
        indexed.sort((a, b) {
          final c = strategy == 'snowball'
              ? amountOf(
                  a.$1['remaining'],
                ).compareTo(amountOf(b.$1['remaining']))
              : amountOf(
                  b.$1['monthlyRate'],
                ).compareTo(amountOf(a.$1['monthlyRate']));
          return c != 0 ? c : a.$2.compareTo(b.$2);
        });
        final ordered = [for (final e in indexed) e.$1];
        Map<String, dynamic>? focus;
        for (final d in ordered) {
          if (amountOf(d['remaining']) > 0) {
            focus = d;
            break;
          }
        }
        focus ??= ordered.isNotEmpty ? ordered.first : null;

        final projection = totalDebt > 0
            ? debtFreeProjection(debts, strategy)
            : null;
        final shortTerm = debts.where((d) => _isShortTerm(d['type'])).toList();
        final longTerm = debts.where((d) => !_isShortTerm(d['type'])).toList();

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Barako.background,
            foregroundColor: Barako.text,
            title: Text(
              'Debts',
              style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
            ),
          ),
          floatingActionButton: widget.store.canWrite
              ? FloatingActionButton.extended(
                  onPressed: () => showDebtFormSheet(context, widget.store),
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Add debt',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              : null,
          body: SafeArea(
            child: debts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'No debts tracked',
                            style: TextStyle(
                              color: Barako.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Track a card, a loan, or money you owe a person, and every '
                            'payment splits into interest and principal '
                            'honestly.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Barako.muted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _kicker('TOTAL DEBT'),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  formatMoney(totalDebt),
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: Barako.text,
                                    fontSize: 30,
                                    fontFamily: Barako.displayFont,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _line('Monthly minimums', formatMoney(totalMin)),
                              _line(
                                'Interest cost per month',
                                formatMoney(totalInterest),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _kicker('PAYOFF PLAN'),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final s in const [
                                    ('snowball', 'Snowball'),
                                    ('avalanche', 'Avalanche'),
                                  ])
                                    ChoiceChip(
                                      label: Text(s.$2),
                                      selected: strategy == s.$1,
                                      onSelected: (_) =>
                                          setState(() => strategy = s.$1),
                                      selectedColor: Barako.primary,
                                      backgroundColor: Barako.background,
                                      labelStyle: TextStyle(
                                        color: strategy == s.$1
                                            ? Barako.onPrimary
                                            : Barako.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                strategy == 'snowball'
                                    ? 'Smallest balance first, for quick wins that keep you going.'
                                    : 'Highest interest first, the cheapest path in pesos.',
                                style: TextStyle(
                                  color: Barako.muted,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                              if (focus != null &&
                                  amountOf(focus['remaining']) > 0) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Focus: ${focus['name']} at ${formatMoney(amountOf(focus['remaining']))}',
                                  style: TextStyle(
                                    color: Barako.text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              if (projection != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  (projection['months'] as int) == 0
                                      ? 'Only centavos left. Log the last payments and you are debt free.'
                                      : 'Debt free around ${_monthYear(projection['date'] as String)} on the minimums, with ${formatMoney(projection['totalInterest'] as double)} interest along the way.',
                                  style: TextStyle(
                                    color: Barako.textSecondary,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ] else if (totalDebt > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'The minimums never win against the interest here. Any extra amount changes that.',
                                  style: TextStyle(
                                    color: Barako.warning,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (shortTerm.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _kicker('SHORT TERM'),
                        const SizedBox(height: 6),
                        for (final d in shortTerm) _debtCard(context, d),
                      ],
                      if (longTerm.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _kicker('LONG TERM'),
                        const SizedBox(height: 6),
                        for (final d in longTerm) _debtCard(context, d),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _kicker(String text) => Text(text, style: Barako.kickerStyle);

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Barako.textSecondary, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Barako.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );

  Widget _debtCard(BuildContext context, Map<String, dynamic> d) {
    final remaining = amountOf(d['remaining']);
    final rate = amountOf(d['monthlyRate']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () =>
              showDebtSheet(context, widget.store, (d['id'] ?? '').toString()),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (d['name'] ?? 'Debt').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Barako.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rate > 0
                            ? '${d['type']} · ${_rateText(rate)}% monthly'
                            : '${d['type']}',
                        style: TextStyle(color: Barako.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  remaining > 0 ? formatMoney(remaining) : 'Paid off',
                  style: TextStyle(
                    color: remaining > 0 ? Barako.text : Barako.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _rateText(double v) {
  // toInt() clamps beyond 2^63, which would silently rewrite a pasted huge
  // balance on a no-op edit (the prefill would save back the clamped
  // number and reset the interest clock). JS String(n) keeps the value, so
  // outside the exact-integer range keep Dart's own text, which round
  // trips through the form parser unchanged.
  if (v % 1 == 0 && v.abs() < 9.2e18) return v.toInt().toString();
  return v.toString();
}

// ---------------------------------------------------------------------------
// The per-debt sheet: pay, mark paid off, edit, delete.
// ---------------------------------------------------------------------------

Future<void> showDebtSheet(
  BuildContext context,
  SalapifyStore store,
  String debtId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Barako.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: DebtSheet(store: store, debtId: debtId),
    ),
  );
}

class DebtSheet extends StatefulWidget {
  final SalapifyStore store;
  final String debtId;
  const DebtSheet({super.key, required this.store, required this.debtId});

  @override
  State<DebtSheet> createState() => _DebtSheetState();
}

class _DebtSheetState extends State<DebtSheet> {
  final payController = TextEditingController();
  // Money must only leave an account the user explicitly picked, never
  // whichever account happens to be first; null means outside the app.
  String? payFrom;
  String? error;
  String? msg;
  bool busy = false;
  bool _seeded = false;

  @override
  void dispose() {
    payController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _find() {
    for (final d in (widget.store.data['debts'] as List? ?? const [])) {
      if (d is Map && d['id'] == widget.debtId) {
        return d.cast<String, dynamic>();
      }
    }
    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      msg = null;
    });
    try {
      await action();
      if (mounted) setState(() => busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Nothing was changed. ${e is ArgumentError ? e.message : e}';
        });
      }
    }
  }

  void _celebrate(String name) {
    // The single most rewarding moment in the app, so it wears the win tokens:
    // a celebrate-colored icon on the positive surface, not a plain snackbar.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Barako.positiveSurface,
        content: Row(
          children: [
            Icon(Icons.celebration, color: Barako.celebrate, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$name paid off! Debt free.',
                style: TextStyle(
                  color: Barako.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _logPayment(Map<String, dynamic> d) async {
    final amount = parseAmount(payController.text);
    if (amount == null) {
      setState(
        () => error = 'Enter a plain amount above zero, like 250 or 99.50.',
      );
      return;
    }
    final text = payController.text;
    final name = (d['name'] ?? 'Debt').toString();
    await _run(() async {
      final r = await widget.store.logDebtPayment(widget.debtId, text, payFrom);
      if (!mounted) return;
      payController.clear();
      setState(() => msg = r.msg);
      if (r.celebrated) {
        Navigator.of(context).pop();
        _celebrate(name);
      }
    });
  }

  Future<void> _markPaid(Map<String, dynamic> d) async {
    final remaining = amountOf(d['remaining']);
    if (remaining <= 0) {
      setState(() => msg = 'Already at zero.');
      return;
    }
    // Show the amount that will actually leave: the balance plus interest
    // accrued since the last payment, same number the engine will pay.
    final payoff =
        splitDebtPayment(
              remaining,
              amountOf(d['monthlyRate']),
              d['interestThroughISO'],
              0,
              _todayISO(),
            )['balance']
            as double;
    final name = (d['name'] ?? 'Debt').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text('Mark paid off?', style: TextStyle(color: Barako.text)),
        content: Text(
          'Log ${formatMoney(payoff)} as a real payment${payFrom != null ? ' from the chosen account' : ''} and zero out $name?',
          style: TextStyle(color: Barako.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: Barako.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Pay it off', style: TextStyle(color: Barako.primary)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final r = await widget.store.markDebtPaid(widget.debtId, payFrom);
      if (!mounted) return;
      setState(() => msg = r.msg);
      if (r.celebrated) {
        Navigator.of(context).pop();
        _celebrate(name);
      }
    });
  }

  Future<void> _delete(Map<String, dynamic> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text('Delete this debt?', style: TextStyle(color: Barako.text)),
        content: Text(
          'Logged payments and their money entries stay in History. Only the debt itself is removed.',
          style: TextStyle(color: Barako.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: Barako.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Delete', style: TextStyle(color: Barako.warning)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await widget.store.deleteDebt(widget.debtId);
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final d = _find();
        if (d == null) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'This debt no longer exists.',
              style: TextStyle(color: Barako.muted),
            ),
          );
        }
        if (!_seeded) {
          // Prefill the payment box with the minimum, like the RN screen.
          final min = amountOf(d['minPayment']);
          if (min > 0) payController.text = _rateText(min);
          _seeded = true;
        }
        final remaining = amountOf(d['remaining']);
        final rate = amountOf(d['monthlyRate']);
        final accounts = [
          for (final a in (widget.store.data['accounts'] as List? ?? const []))
            if (a is Map) a.cast<String, dynamic>(),
        ];
        final forecast =
            d['type'] == 'credit card' &&
                (amountOf(d['dueDay']) > 0 || amountOf(d['statementDay']) > 0)
            ? cardForecast(d, widget.store.data['payments'], DateTime.now())
            : null;
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (d['name'] ?? 'Debt').toString(),
                        style: TextStyle(
                          color: Barako.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (widget.store.canWrite) ...[
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: Barako.muted),
                        onPressed: busy
                            ? null
                            : () => showDebtFormSheet(
                                context,
                                widget.store,
                                debt: d,
                              ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Barako.muted),
                        onPressed: busy ? null : () => _delete(d),
                      ),
                    ],
                  ],
                ),
                Text(
                  remaining > 0
                      ? '${formatMoney(remaining)} left${rate > 0 ? ' · ${_rateText(rate)}% monthly' : ''}'
                      : 'Paid off',
                  style: TextStyle(
                    color: remaining > 0
                        ? Barako.textSecondary
                        : Barako.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (rate > 0 && remaining > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'About ${formatMoney(monthlyInterest(d))} interest gets added each month it sits.',
                      style: TextStyle(color: Barako.muted, fontSize: 12),
                    ),
                  ),
                if (forecast != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Barako.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Barako.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'THIS CYCLE',
                          style: TextStyle(
                            color: Barako.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (forecast['statement'] != null)
                          Text(
                            'Statement cuts ${_longDate(forecast['statement'] as String)}',
                            style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        if (forecast['due'] != null)
                          Text(
                            'Due ${_longDate(forecast['due'] as String)}${forecast['dueMoved'] == true ? ' (moved, ${forecast['dueMovedReason']})' : ''}',
                            style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        Text(
                          'Pay at least ${formatMoney(forecast['minDue'] as double)} to avoid late fees',
                          style: TextStyle(
                            color: Barako.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if ((forecast['pending'] as double) > 0)
                          Text(
                            'Sent but not yet posted: ${formatMoney(forecast['pending'] as double)}',
                            style: TextStyle(color: Barako.muted, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
                if (widget.store.canWrite && remaining > 0) ...[
                  const SizedBox(height: 16),
                  Text(
                    'LOG A PAYMENT',
                    style: TextStyle(
                      color: Barako.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: payController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(color: Barako.text),
                    decoration: InputDecoration(
                      hintText:
                          'Amount, like ${_rateText(amountOf(d['minPayment']) > 0 ? amountOf(d['minPayment']) : 500)}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Outside the app'),
                        selected: payFrom == null,
                        onSelected: (_) => setState(() => payFrom = null),
                        selectedColor: Barako.primary,
                        backgroundColor: Barako.background,
                        labelStyle: TextStyle(
                          color: payFrom == null
                              ? Barako.onPrimary
                              : Barako.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      for (final a in accounts)
                        ChoiceChip(
                          label: Text((a['name'] ?? 'Account').toString()),
                          selected: payFrom == a['id'],
                          onSelected: (_) => setState(
                            () => payFrom = (a['id'] ?? '').toString(),
                          ),
                          selectedColor: Barako.primary,
                          backgroundColor: Barako.background,
                          labelStyle: TextStyle(
                            color: payFrom == a['id']
                                ? Barako.onPrimary
                                : Barako.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: busy ? null : () => _logPayment(d),
                          child: const Text(
                            'Log payment',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : () => _markPaid(d),
                          child: const Text(
                            'Mark paid off',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (msg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      msg!,
                      style: TextStyle(
                        color: Barako.primaryText,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Barako.warning,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Add and edit form.
// ---------------------------------------------------------------------------

Future<void> showDebtFormSheet(
  BuildContext context,
  SalapifyStore store, {
  Map<String, dynamic>? debt,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Barako.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: DebtFormSheet(store: store, debt: debt),
    ),
  );
}

class DebtFormSheet extends StatefulWidget {
  final SalapifyStore store;
  final Map<String, dynamic>? debt;
  const DebtFormSheet({super.key, required this.store, this.debt});

  @override
  State<DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends State<DebtFormSheet> {
  late final TextEditingController name;
  late final TextEditingController remaining;
  late final TextEditingController rateCtl;
  late final TextEditingController minPay;
  late final TextEditingController dueDay;
  late final TextEditingController statementDay;
  late final TextEditingController graceDays;
  late final TextEditingController creditLimit;
  late String type;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    // The same field mapping the RN openEdit uses: zeros show as empty.
    final d = widget.debt;
    String numText(dynamic v) {
      final n = amountOf(v);
      return n != 0 ? _rateText(n) : '';
    }

    name = TextEditingController(text: (d?['name'] ?? '').toString());
    type = (d?['type'] ?? 'credit card').toString();
    remaining = TextEditingController(
      text: d != null ? _rateText(amountOf(d['remaining'])) : '',
    );
    rateCtl = TextEditingController(
      text: d != null ? _rateText(amountOf(d['monthlyRate'])) : '',
    );
    minPay = TextEditingController(
      text: d != null ? _rateText(amountOf(d['minPayment'])) : '',
    );
    dueDay = TextEditingController(text: numText(d?['dueDay']));
    statementDay = TextEditingController(text: numText(d?['statementDay']));
    graceDays = TextEditingController(text: numText(d?['graceDays']));
    creditLimit = TextEditingController(text: numText(d?['creditLimit']));
  }

  @override
  void dispose() {
    name.dispose();
    remaining.dispose();
    rateCtl.dispose();
    minPay.dispose();
    dueDay.dispose();
    statementDay.dispose();
    graceDays.dispose();
    creditLimit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.saveDebt({
        'id': widget.debt != null
            ? (widget.debt!['id'] ?? '').toString()
            : null,
        'name': name.text,
        'type': type,
        'remaining': remaining.text,
        'monthlyRate': rateCtl.text,
        'minPayment': minPay.text,
        'dueDay': dueDay.text,
        'statementDay': statementDay.text,
        'graceDays': graceDays.text,
        'creditLimit': creditLimit.text,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e is ArgumentError
              ? '${e.message}'
              : 'Nothing was changed. $e';
        });
      }
    }
  }

  Widget _field(TextEditingController c, String label, {bool number = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: TextStyle(color: Barako.text),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCard = type == 'credit card';
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.debt != null ? 'Edit debt' : 'Add a debt',
              style: TextStyle(
                color: Barako.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _field(name, 'Name, like BPI card or a family loan', number: false),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in kDebtTypes)
                  ChoiceChip(
                    label: Text(t),
                    selected: type == t,
                    onSelected: (_) => setState(() => type = t),
                    selectedColor: Barako.primary,
                    backgroundColor: Barako.background,
                    labelStyle: TextStyle(
                      color: type == t
                          ? Barako.onPrimary
                          : Barako.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _field(remaining, 'Remaining balance'),
            _field(rateCtl, 'Interest % per month (0 if none)'),
            _field(minPay, 'Minimum payment (0 if none)'),
            _field(dueDay, 'Payment due day of the month (optional)'),
            if (isCard) ...[
              _field(statementDay, 'Statement day (optional)'),
              _field(graceDays, 'Days after statement until due (optional)'),
              _field(creditLimit, 'Credit limit (optional)'),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  error!,
                  style: TextStyle(
                    color: Barako.warning,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : _save,
                child: Text(
                  widget.debt != null ? 'Save changes' : 'Add debt',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
