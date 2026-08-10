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
import '../money/account_taxonomy.dart' show AccountSubtype, kCardNetworks;
import '../money/card_products.dart' show networksForIssuer;
import '../money/debtmath.dart'
    show cardForecast, debtFreeProjection, monthlyInterest, splitDebtPayment;
import '../money/institutions.dart' show institutionById;
import '../money/ledger.dart' show amountOf;
import 'add_account_flow.dart' show InstitutionAvatar, showInstitutionPicker;
import '../money/milestones.dart' show milestoneFor;
import '../theme.dart';
import '../typography.dart';
import '../widgets/celebration.dart';
import 'milestone_share.dart' show showMilestoneCelebration;
import '../widgets/section.dart';
import '../widgets/salapify_icon.dart';
import '../widgets/amount_text.dart';
import 'log_sheet.dart' show parseAmount;
import 'overview.dart' show formatMoney, formatMoneyAbout;

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

/// The stored type as words a person reads: the stored values are lowercase
/// machine strings, and "bnpl · 3.5% monthly" broke sentence case and taught
/// nothing about what BNPL is. Unknown types capitalize and pass through.
String _typeLabel(dynamic type) {
  final t = (type ?? '').toString();
  const map = {
    'credit card': 'Credit card',
    'bnpl': 'BNPL (pay later)',
    'personal loan': 'Personal loan',
    'mortgage': 'Mortgage',
    'auto': 'Auto loan',
    'short term': 'Short-term loan',
    'long term': 'Long-term loan',
    'insurance': 'Insurance',
    'other': 'Other',
  };
  if (map.containsKey(t)) return map[t]!;
  return t.isEmpty ? 'Debt' : '${t[0].toUpperCase()}${t.substring(1)}';
}

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

/// The pushed shape: Scaffold, AppBar, its own Add debt button.
///
/// Six places push this screen (Menu, Search, Ask Pan, a lesson, and two Home
/// cards), and they keep pushing it: a push preserves the back stack the user
/// expects, and redirecting to the tab would lose their place. The tab shape
/// is [DebtsView] inside the Money tab, and both wrap the same body, so the
/// two can never drift apart.
class DebtsScreen extends StatelessWidget {
  final SalapifyStore store;
  const DebtsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Debts')),
      floatingActionButton: store.canWrite
          ? FloatingActionButton.extended(
              onPressed: () => showDebtFormSheet(context, store),
              icon: Icon(salapifyIcon('add')),
              label: const Text(
                'Add debt',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: SafeArea(child: DebtsView(store: store)),
    );
  }
}

/// The whole picture of what is owed, as a plain body.
///
/// Everything the old DebtsScreen rendered, minus the Scaffold chrome, so it
/// can live inside the Money tab's segment as well as inside the pushed
/// wrapper above. The strategy switch is State here, which is what lets it
/// survive both segment switches and tab switches when mounted in the shell's
/// IndexedStack.
class DebtsView extends StatefulWidget {
  final SalapifyStore store;

  /// Set by the Money tab, which owns one controller per segment because its
  /// inner IndexedStack mounts two scrollables at once and the ambient
  /// PrimaryScrollController cannot be attached to both.
  final ScrollController? controller;

  /// The tab shape clears the shell's Log button with 96; the pushed shape
  /// clears its own FAB with 90, as before.
  final EdgeInsets padding;
  const DebtsView({
    super.key,
    required this.store,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 90),
  });

  @override
  State<DebtsView> createState() => _DebtsViewState();
}

class _DebtsViewState extends State<DebtsView> {
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

        return debts.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('No debts tracked', style: AppText.bodyLg.w7),
                      const SizedBox(height: 6),
                      Text(
                        'Track a card, a loan, or money you owe a person, and every '
                        'payment splits into interest and principal '
                        'honestly.',
                        textAlign: TextAlign.center,
                        style: AppText.small
                            .tint(Barako.muted)
                            .copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                controller: widget.controller,
                padding: widget.padding,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Kicker('TOTAL DEBT'),
                          const SizedBox(height: 4),
                          AmountText(totalDebt, role: AmountRole.lg),
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
                          Kicker('PAYOFF PLAN'),
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
                            style: AppText.caption.copyWith(height: 1.4),
                          ),
                          if (focus != null &&
                              amountOf(focus['remaining']) > 0) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Focus: ${focus['name']} at ${formatMoney(amountOf(focus['remaining']))}',
                              style: AppText.smallStrong,
                            ),
                          ],
                          if (projection != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              (projection['months'] as int) == 0
                                  ? 'Only centavos left. Log the last payments and you are debt free.'
                                  : 'Debt free around ${_monthYear(projection['date'] as String)} on the minimums, with ${formatMoney(projection['totalInterest'] as double)} interest along the way.',
                              style: AppText.caption
                                  .tint(Barako.textSecondary)
                                  .copyWith(height: 1.4),
                            ),
                          ] else if (totalDebt > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'The minimums never win against the interest here. Any extra amount changes that.',
                              style: AppText.caption
                                  .tint(Barako.warning)
                                  .copyWith(height: 1.4),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (shortTerm.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Kicker('SHORT TERM'),
                    const SizedBox(height: 6),
                    for (final d in shortTerm) _debtCard(context, d),
                  ],
                  if (longTerm.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Kicker('LONG TERM'),
                    const SizedBox(height: 6),
                    for (final d in longTerm) _debtCard(context, d),
                  ],
                ],
              );
      },
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label, style: AppText.small)),
        Text(value, style: AppText.small.w6.tabular),
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
                        style: AppText.body.w6,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rate > 0
                            ? '${_typeLabel(d['type'])} · ${_rateText(rate)}% monthly'
                            : _typeLabel(d['type']),
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                remaining > 0
                    ? AmountText(remaining, role: AmountRole.row)
                    : Text(
                        'Paid off',
                        style: AppText.label.w7.tint(Barako.primary),
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
    // The single most rewarding moment in the app finally looks like one:
    // confetti, then the branded card offered to share right there, so the
    // moment people already screenshot becomes a one-tap post.
    //
    // milestoneFor returns null for a debt cleared to zero with no logged
    // payment pesos (the engine excludes hand-zeroing); that is not a shareable
    // milestone, but the payoff still earns the confetti, so fall back to it.
    final win = milestoneFor(widget.store.data, widget.debtId);
    if (win != null) {
      showMilestoneCelebration(context, win);
    } else {
      showCelebration(context, '$name paid off! Debt free.');
    }
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
                        style: AppText.heading.w8,
                      ),
                    ),
                    if (widget.store.canWrite) ...[
                      IconButton(
                        tooltip: 'Edit debt',
                        icon: Icon(salapifyIcon('edit'), color: Barako.muted),
                        onPressed: busy
                            ? null
                            : () => showDebtFormSheet(
                                context,
                                widget.store,
                                debt: d,
                              ),
                      ),
                      IconButton(
                        tooltip: 'Delete debt',
                        icon: Icon(salapifyIcon('delete'), color: Barako.muted),
                        onPressed: busy ? null : () => _delete(d),
                      ),
                    ],
                  ],
                ),
                Text(
                  remaining > 0
                      ? '${formatMoney(remaining)} left${rate > 0 ? ' · ${_rateText(rate)}% monthly' : ''}'
                      : 'Paid off',
                  style: AppText.label.tint(
                    remaining > 0 ? Barako.textSecondary : Barako.primary,
                  ),
                ),
                if (rate > 0 && remaining > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'About ${formatMoneyAbout(monthlyInterest(d))} interest gets added each month it sits.',
                      style: AppText.caption,
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
                            style: AppText.caption.tint(Barako.textSecondary),
                          ),
                        if (forecast['due'] != null)
                          Text(
                            'Due ${_longDate(forecast['due'] as String)}${forecast['dueMoved'] == true ? ' (moved, ${forecast['dueMovedReason']})' : ''}',
                            style: AppText.caption.tint(Barako.textSecondary),
                          ),
                        Text(
                          'Pay at least ${formatMoney(forecast['minDue'] as double)} to avoid late fees',
                          style: AppText.caption.tint(Barako.textSecondary),
                        ),
                        if ((forecast['pending'] as double) > 0)
                          Text(
                            'Sent but not yet posted: ${formatMoney(forecast['pending'] as double)}',
                            style: AppText.caption,
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
                // liveRegion on both: a blind user who taps Log payment
                // hears whether money moved, the same fix the transfer
                // sheet already carries for its refusals.
                if (msg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        msg!,
                        style: AppText.caption
                            .tint(Barako.primaryText)
                            .copyWith(height: 1.4),
                      ),
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        style: AppText.caption
                            .tint(Barako.warning)
                            .copyWith(height: 1.4),
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

/// [seed] is what the person said they were adding in the unified Add flow.
///
/// It pre-selects the debt type and is stored as the row's subtype, and it is
/// deliberately NOT a `debt` map: this form decides add against edit by
/// whether it was handed a row with an id, so seeding through `debt` would
/// turn every add into an edit of a row that does not exist.
Future<void> showDebtFormSheet(
  BuildContext context,
  SalapifyStore store, {
  Map<String, dynamic>? debt,
  AccountSubtype? seed,
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
      child: DebtFormSheet(store: store, debt: debt, seed: seed),
    ),
  );
}

class DebtFormSheet extends StatefulWidget {
  final SalapifyStore store;
  final Map<String, dynamic>? debt;

  /// See [showDebtFormSheet]. Null when editing, or when this sheet is opened
  /// from a path that never asked what kind of debt it is.
  final AccountSubtype? seed;
  const DebtFormSheet({super.key, required this.store, this.debt, this.seed});

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
  late final TextEditingController last4;
  late final TextEditingController annualFee;
  late String type;
  late String institutionId;
  late String network;
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
    // An existing row's own type always wins. Then the seed: a credit card
    // subtype maps to the one string the payment engine branches on
    // (money/debts.dart keys on exactly 'credit card'), everything else to
    // 'other'. Only then the default.
    type =
        (d?['type'] ??
                (widget.seed == null
                    ? 'credit card'
                    : (widget.seed!.id == 'credit_card'
                          ? 'credit card'
                          : 'other')))
            .toString();
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
    last4 = TextEditingController(text: (d?['last4'] ?? '').toString());
    annualFee = TextEditingController(text: numText(d?['annualFee']));
    institutionId = (d?['institutionId'] ?? '').toString();
    network = (d?['cardNetwork'] ?? '').toString();
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
    last4.dispose();
    annualFee.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (busy) return;
    final last4Text = last4.text.trim();
    if (last4Text.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(last4Text)) {
      setState(
        () => error =
            'The last four digits are exactly four numbers, '
            'or leave it blank.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final savedId = await widget.store.saveDebt(
        {
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
        },
        // Only on create, and only when the person actually answered. Writing it
        // on an edit would let opening and saving an untouched row reclassify
        // it. sanitizeData drops it if it does not belong to debts.
        meta: widget.debt == null && widget.seed != null
            ? {'subtype': widget.seed!.id}
            : const {},
      );
      // The card metadata rides on a separate patch, for both add and edit:
      // saveDebt owns the money fields, patchDebtMeta owns the bank, network,
      // last four and annual fee. Empty values CLEAR, because sanitizeData drops
      // an institution id, a network or a last four that is blank on the next
      // load. Only ever the LAST FOUR digits, never a full number.
      final id = savedId ?? (widget.debt?['id']?.toString());
      if (id != null && id.isNotEmpty) {
        final meta = <String, dynamic>{
          'institutionId': institutionId,
          if (type == 'credit card') ...{
            'cardNetwork': kCardNetworks.contains(network) ? network : '',
            'last4': last4Text,
            if (last4Text.isNotEmpty) 'sensitiveDataProtectionVersion': 1,
            if (double.tryParse(annualFee.text.trim()) != null)
              'annualFee': double.parse(annualFee.text.trim()),
          },
        };
        await widget.store.patchDebtMeta(id, meta);
      }
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

  Widget _field(
    TextEditingController c,
    String label, {
    bool number = true,
    int? maxLen,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        maxLength: maxLen,
        style: TextStyle(color: Barako.text),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  /// Which bank or lender this debt is with, the same picker the account flow
  /// uses. Optional: a debt with no institution is a real answer (money owed to
  /// a person, an unlisted lender), so the row can be left as "Choose".
  Widget _institutionRow() {
    final label = institutionId.isEmpty
        ? 'Choose bank or lender (optional)'
        : (institutionById(institutionId)?.displayName ?? 'Choose');
    return Material(
      color: Barako.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picked = await showInstitutionPicker(
            context,
            current: institutionId,
          );
          if (picked == null || !mounted) return;
          setState(() {
            institutionId = picked;
            // A network the newly chosen issuer is not known to use is cleared,
            // so the chips below never show a selected chip the issuer list no
            // longer contains.
            if (network.isNotEmpty &&
                !networksForIssuer(institutionId).any((n) => n.id == network)) {
              network = '';
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              InstitutionAvatar(id: institutionId, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: institutionId.isEmpty ? Barako.muted : Barako.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(salapifyIcon('forward'), color: Barako.faint, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// The card network, as chips adapted to the chosen issuer: an issuer known to
  /// use only Mastercard shows only that, an unlisted issuer shows all five.
  /// Tapping a selected chip clears it, because "I do not know" is a valid
  /// answer this catalog never forces past.
  Widget _networkPicker() {
    final networks = networksForIssuer(
      institutionId.isEmpty ? null : institutionId,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Card network (optional)',
            style: AppText.small.tint(Barako.muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in networks)
                ChoiceChip(
                  label: Text(n.displayName),
                  selected: network == n.id,
                  onSelected: (_) =>
                      setState(() => network = network == n.id ? '' : n.id),
                  selectedColor: Barako.primary,
                  backgroundColor: Barako.background,
                  labelStyle: TextStyle(
                    color: network == n.id
                        ? Barako.onPrimary
                        : Barako.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
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
              style: AppText.heading.w8,
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
            _institutionRow(),
            const SizedBox(height: 12),
            _field(remaining, 'Remaining balance'),
            _field(rateCtl, 'Interest % per month, on the remaining balance'),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              // The single most damaging ambiguity a lending screen can
              // carry: PH lenders overwhelmingly quote ADD-ON rates on the
              // original amount, whose true diminishing-balance rate is
              // roughly double. A borrower typing the quoted 2.5% would see
              // about half their real interest cost, with full confidence.
              child: Text(
                'If your lender quoted a rate on the original loan amount '
                '(add-on), the real rate here is roughly double what they '
                'said. 0 if none.',
                style: AppText.caption.copyWith(height: 1.35),
              ),
            ),
            _field(minPay, 'Minimum payment (0 if none)'),
            _field(dueDay, 'Payment due day of the month (optional)'),
            if (isCard) ...[
              _field(statementDay, 'Statement day (optional)'),
              _field(graceDays, 'Days after statement until due (optional)'),
              _field(creditLimit, 'Credit limit (optional)'),
              const SizedBox(height: 4),
              _networkPicker(),
              _field(
                last4,
                'Card number, last 4 only (optional)',
                number: true,
                maxLen: 4,
              ),
              _field(annualFee, 'Annual fee (optional)'),
              const SizedBox(height: 4),
              Text(
                'For your safety, save only the last four digits. Never store '
                'your PIN, CVV, password, or OTP.',
                style: AppText.caption.tint(Barako.muted),
              ),
              const SizedBox(height: 12),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  error!,
                  style: AppText.caption
                      .tint(Barako.warning)
                      .copyWith(height: 1.4),
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
