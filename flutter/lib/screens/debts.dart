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
import '../money/card_products.dart' show cardNetworkById, networksForIssuer;
import '../money/commitments.dart'
    show bankDueDate, daysUntil, daysUntilWords, shortDueDate;
import '../money/debtmath.dart'
    show cardForecast, debtFreeProjection, monthlyInterest, splitDebtPayment;
import '../money/institutions.dart' show institutionById;
import '../money/ledger.dart' show amountOf;
import '../services/notifications.dart' show Reminders;
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

  /// Which wizard step is showing (0-based). The sheet is a short guided flow
  /// (basics, what you owe, schedule, review) instead of one long wall of
  /// fields; every field still writes the same debt, this only paces the entry.
  int _step = 0;

  /// Whether the interest field is being entered as a PER-YEAR rate. The stored
  /// value is ALWAYS the monthly rate (the one the golden-locked engine reads),
  /// so this is a display-and-input unit only: annual in, divided by twelve to
  /// store; monthly out, multiplied by twelve to show. Defaults to per-month for
  /// a credit card (PH card statements quote monthly) and per-year otherwise.
  late bool _rateAnnual;

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
    // Per-month for a card, per-year otherwise. The stored monthlyRate is shown
    // in that unit: annual shows monthly times twelve.
    _rateAnnual = type != 'credit card';
    final storedMonthly = amountOf(d?['monthlyRate']);
    rateCtl = TextEditingController(
      text: d != null && storedMonthly != 0
          ? _rateText(_rateAnnual ? storedMonthly * 12 : storedMonthly)
          : '',
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
          // ALWAYS the monthly rate the engine reads. A per-month entry is
          // stored verbatim (no parse-and-reformat drift); a per-year entry is
          // divided by twelve. The display unit never reaches storage.
          'monthlyRate': _rateAnnual
              ? _effectiveMonthlyRate.toString()
              : rateCtl.text,
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
            // Always written, and comma-tolerant, so clearing the field on an
            // edit actually removes the fee (a blank saves 0) and "1,500" is not
            // silently dropped the way a bare double.parse dropped it.
            'annualFee': parseAmount(annualFee.text) ?? 0,
          },
        };
        await widget.store.patchDebtMeta(id, meta);
      }
      // Offer the reminder ONLY when there is something to remind about (a
      // resolvable schedule), only when it is not already on, only on a
      // device that can actually show one (Reminders.supported is false on
      // web/desktop/tests, the same gate onboarding's own nudge step already
      // uses), and only ONCE EVER: without the settings flag this asked again
      // on every single save of every debt with a schedule, which for someone
      // editing a card's balance weekly reads as nagging, not the "ask
      // cleanly, once" pattern the rest of the app follows. "Not now" still
      // counts as asked; a person who wants the reminder later can still turn
      // it on from Notifications and security, the same door this always had.
      if (mounted &&
          Reminders.supported &&
          _previewDue != null &&
          !widget.store.notifOn('bills') &&
          (widget.store.data['settings'] as Map?)?['billReminderOffered'] !=
              true) {
        await _offerReminderOptIn(context);
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

  /// Offered once, right after a successful save, never as a background
  /// auto-enable: the person taps Enable or Not now, exactly the "ask
  /// cleanly, once, in context" pattern onboarding's nudge step already uses.
  /// Enabling routes through the SAME two calls the Notifications and
  /// security screen's own toggle uses (store.setNotifPref then
  /// Reminders.reschedule), and a refusal shows the EXACT same guidance
  /// sentence that screen already shows, so there is one permission story
  /// across the app, not two. Nothing here invents a new reminder: it turns
  /// on the existing, already-tested `bills` reminder in money/reminders.dart.
  Future<void> _offerReminderOptIn(BuildContext context) async {
    // Recorded the moment the sheet opens, not after a choice, so "Not now"
    // is remembered exactly like "Enable": both mean the person has been
    // asked, and the whole point is to never ask a second time uninvited.
    await widget.store.setSetting('billReminderOffered', true);
    if (!context.mounted) return;
    final enable = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Barako.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Gap.gutter,
            Gap.gutter,
            Gap.gutter,
            Gap.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SalapifyGlyph('calendar', size: IconSizes.inline),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      'Want a reminder before this is due?',
                      style: AppText.subtitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              Text(
                'Salapify will remind you a few days before, and check '
                'weekends and Philippine holidays automatically so the '
                'reminder still lands on a day you can actually pay.',
                style: AppText.body
                    .tint(Barako.textSecondary)
                    .copyWith(height: 1.4),
              ),
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Not now'),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Enable'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (enable != true || !context.mounted) return;
    final granted = await Reminders.requestPermission();
    if (!context.mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Allow notifications for Salapify in your phone settings, '
              'then try again.',
            ),
          ),
        );
      return;
    }
    await widget.store.setNotifPref('bills', true);
    if (mounted) {
      await Reminders.reschedule(widget.store.data, DateTime.now());
    }
  }

  /// A form field with its label ABOVE the box, a short hint inside, and an
  /// optional wrapping helper below. Replaces the old in-field labelText, which
  /// clipped long labels; a label above a field can never truncate.
  Widget _labeledField(
    TextEditingController c,
    String label, {
    String? hint,
    String? helper,
    bool number = true,
    int? maxLen,
    bool optional = false,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: AppText.small.w6.tint(Barako.textSecondary),
                ),
              ),
              if (optional) ...[
                const SizedBox(width: Gap.xs),
                Text('optional', style: AppText.micro.tint(Barako.faint)),
              ],
            ],
          ),
          const SizedBox(height: Gap.xs),
          TextField(
            controller: c,
            keyboardType: number
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            maxLength: maxLen,
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            onChanged: onChanged,
            style: AppText.body.tint(Barako.text),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Barako.faint),
              helperText: helper,
              helperStyle: AppText.caption.tint(Barako.muted),
              helperMaxLines: 3,
              filled: true,
              fillColor: Barako.card,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.field),
                borderSide: BorderSide(color: Barako.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.field),
                borderSide: BorderSide(color: Barako.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.field),
                borderSide: BorderSide(color: Barako.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The monthly rate the engine reads, derived from the field and the unit
  /// toggle. Annual entries divide by twelve. Zero when the field is blank.
  double get _effectiveMonthlyRate {
    final v = double.tryParse(rateCtl.text.trim()) ?? 0;
    return _rateAnnual ? v / 12 : v;
  }

  /// The estimated interest for one month, the SAME golden-locked function every
  /// other screen uses (balance times the monthly rate, rounded like the RN
  /// engine), so the figure on the form can never disagree with the rest of the
  /// app. No new money math is invented here.
  double get _estimatedMonthly => monthlyInterest({
    'remaining': (parseAmount(remaining.text) ?? 0),
    'monthlyRate': _effectiveMonthlyRate,
  });

  /// Switch the interest unit, converting the value in the field so the number
  /// keeps its meaning (1.5 per month becomes 18 per year, and back).
  void _setRateUnit(bool annual) {
    if (annual == _rateAnnual) return;
    final v = double.tryParse(rateCtl.text.trim());
    setState(() {
      _rateAnnual = annual;
      if (v != null && v != 0) {
        rateCtl.text = _rateText(annual ? v * 12 : v / 12);
      }
    });
  }

  String _iconForType(String t) => switch (t) {
    'credit card' => 'card',
    'bnpl' => 'quick',
    'personal loan' => 'cash',
    'mortgage' => 'house',
    'auto' => 'cash',
    'short term' => 'quick',
    'long term' => 'calendar',
    'insurance' => 'protected',
    _ => 'wallet',
  };

  String _typeGloss(String t) => switch (t) {
    'credit card' => 'A card you pay off monthly.',
    'bnpl' => 'Installments like Home Credit or a pay-later plan.',
    'personal loan' => 'A cash loan from a bank or lender.',
    'mortgage' => 'A home or property loan.',
    'auto' => 'A car or motorcycle loan.',
    'short term' => 'Due soon, within about a year.',
    'long term' => 'Paid over several years.',
    'insurance' => 'Premiums you owe on a policy.',
    _ => 'Anything else you owe.',
  };

  /// The type as a single selectable row (a glyph, the plain-English label, a
  /// one-line gloss, a chevron) that opens a compact picker, instead of a wall
  /// of nine equal chips printing raw machine strings.
  Widget _typeRow() {
    return Material(
      color: Barako.card,
      borderRadius: BorderRadius.circular(Radii.field),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.field),
        onTap: _showTypePicker,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.field),
            border: Border.all(color: Barako.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              SalapifyGlyph(_iconForType(type), size: IconSizes.inline),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _typeLabel(type),
                      style: AppText.label.w6.tint(Barako.text),
                    ),
                    Text(
                      _typeGloss(type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.micro.tint(Barako.muted),
                    ),
                  ],
                ),
              ),
              Icon(
                salapifyIcon('expand'),
                color: Barako.faint,
                size: IconSizes.inline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTypePicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Barako.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.gutter,
                  Gap.gutter,
                  Gap.gutter,
                  Gap.sm,
                ),
                child: Text('What kind of debt?', style: AppText.subtitle),
              ),
              for (final t in kDebtTypes)
                ListTile(
                  leading: SalapifyGlyph(_iconForType(t), size: IconSizes.inline),
                  title: Text(_typeLabel(t), style: AppText.bodyLg.w6),
                  subtitle: Text(
                    _typeGloss(t),
                    style: AppText.small.tint(Barako.muted),
                  ),
                  trailing: t == type
                      ? Icon(salapifyIcon('selected'), color: Barako.primary)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(t),
                ),
              const SizedBox(height: Gap.sm),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => type = picked);
  }

  /// The live card preview, code-drawn (no asset, ships over the air), filling
  /// in as the person types. Only shown for a credit card; other debts get a
  /// slim summary strip instead, so a family loan is not dressed as plastic.
  Widget _cardPreview() {
    final nm = name.text.trim();
    final l4 = last4.text.trim();
    final netName = cardNetworkById(network)?.displayName;
    return AspectRatio(
      aspectRatio: 1.7,
      child: Container(
        decoration: BoxDecoration(
          gradient: Barako.heroWash,
          borderRadius: BorderRadius.circular(Radii.hero),
          border: Border.all(color: Barako.border),
        ),
        padding: Insets.hero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InstitutionAvatar(id: institutionId, size: 34),
                const Spacer(),
                Icon(
                  salapifyIcon('contactless'),
                  color: Barako.faint,
                  size: IconSizes.inline,
                ),
              ],
            ),
            const Spacer(),
            Text(
              nm.isEmpty ? 'Your card' : nm,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.subtitle.tint(Barako.text),
            ),
            const SizedBox(height: Gap.xs),
            Row(
              children: [
                Text(
                  l4.isEmpty ? '••••  ••••  ••••  ••••' : '••••  $l4',
                  style: AppText.body.w6.tint(Barako.textSecondary),
                ),
                const Spacer(),
                if (netName != null)
                  Text(netName, style: AppText.small.w7.tint(Barako.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _debtPreview() {
    final nm = name.text.trim();
    final amt = (parseAmount(remaining.text) ?? 0);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: Barako.heroWash,
        borderRadius: BorderRadius.circular(Radii.hero),
        border: Border.all(color: Barako.border),
      ),
      padding: Insets.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SalapifyGlyph(_iconForType(type), size: IconSizes.inline),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  nm.isEmpty ? _typeLabel(type) : nm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.subtitle.tint(Barako.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amt > 0 ? formatMoney(amt) : 'Amount owed',
              maxLines: 1,
              style: amt > 0
                  ? AppText.amountLg.w8.tint(Barako.warning)
                  : AppText.amountLg.w8.tint(Barako.faint),
            ),
          ),
        ],
      ),
    );
  }

  /// The interest field with a per-month / per-year toggle, the live estimated
  /// monthly cost, the honest caveat, and the load-bearing add-on warning. The
  /// stored value is always monthly; the toggle is display only.
  Widget _rateSection() {
    final est = _estimatedMonthly;
    final hasRate = (double.tryParse(rateCtl.text.trim()) ?? 0) > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Interest rate',
                style: AppText.small.w6.tint(Barako.textSecondary),
              ),
            ),
            _RateUnitToggle(annual: _rateAnnual, onChanged: _setRateUnit),
          ],
        ),
        const SizedBox(height: Gap.xs),
        _labeledField(
          rateCtl,
          _rateAnnual ? 'Percent per year' : 'Percent per month',
          hint: _rateAnnual ? 'e.g. 18' : 'e.g. 1.5',
          helper: 'On the remaining balance. Enter 0 if none.',
          onChanged: (_) => setState(() {}),
        ),
        if (hasRate) _estimateCallout(est),
        _rateWarning(),
      ],
    );
  }

  Widget _estimateCallout(double est) {
    return Container(
      margin: const EdgeInsets.only(bottom: Gap.md),
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Barako.primary.withValues(alpha: BarakoAlpha.tint),
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(salapifyIcon('growth'), size: IconSizes.dense, color: Barako.primaryText),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About ${formatMoneyAbout(est)} interest a month',
                  style: AppText.small.w7.tint(Barako.primaryText),
                ),
                const SizedBox(height: 2),
                Text(
                  'Estimate on today’s balance. Your bank charges on your '
                  'average daily balance and may add fees, so the real figure '
                  'can differ.',
                  style: AppText.caption.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rateWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: Gap.md),
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Barako.positiveSurface,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: Barako.positiveBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(salapifyIcon('help'), size: IconSizes.dense, color: Barako.caramel),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              'If your lender quoted a rate on the original loan amount (add-on), '
              'the real rate here is roughly double what they said.',
              style: AppText.small.copyWith(height: 1.35).tint(Barako.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _safetyNote() {
    return Padding(
      padding: const EdgeInsets.only(top: Gap.xs, bottom: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(salapifyIcon('lock'), size: IconSizes.dense, color: Barako.muted),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              'For your safety, save only the last four digits. Never store your '
              'PIN, CVV, password, or OTP. Everything you type stays on this phone.',
              style: AppText.caption.tint(Barako.muted).copyWith(height: 1.4),
            ),
          ),
        ],
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

  static const _stepTitles = [
    'The basics',
    'What you owe',
    'Payment schedule',
    'Review',
  ];

  /// The header line the sheet opens on: "Add credit card" reads truer than
  /// "Add a debt" when the type is already a card, and "Edit" when editing.
  String get _sheetTitle {
    if (widget.debt != null) return 'Edit ${_typeLabel(type).toLowerCase()}';
    return 'Add ${_typeLabel(type).toLowerCase()}';
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step -= 1);
    }
  }

  void _next() {
    // Only the first step gates: a debt needs a name to be worth saving. The
    // rest are optional or default to zero, so nothing else blocks the flow.
    if (_step == 0 && name.text.trim().isEmpty) {
      setState(() => error = 'Give this a name first, like "BPI card".');
      return;
    }
    setState(() {
      error = null;
      _step += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.92;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        children: [
          // Drag handle.
          Padding(
            padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.sm),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Barako.border,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
          ),
          _wizardHeader(),
          const SizedBox(height: Gap.md),
          Expanded(
            child: IndexedStack(
              index: _step,
              sizing: StackFit.expand,
              children: [
                _stepScroll(_basicsStep()),
                _stepScroll(_owedStep()),
                _stepScroll(_scheduleStep()),
                _stepScroll(_reviewStep()),
              ],
            ),
          ),
          _wizardFooter(),
        ],
      ),
    );
  }

  /// The header: a back or close control, the title, and the step progress.
  Widget _wizardHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.sm, 0, Gap.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _back,
                icon: Icon(
                  salapifyIcon(_step == 0 ? 'close' : 'back'),
                  color: Barako.muted,
                ),
                tooltip: _step == 0 ? 'Close' : 'Back',
              ),
              Expanded(
                child: Text(
                  _sheetTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title,
                ),
              ),
              Text(
                '${_step + 1} of ${_stepTitles.length}',
                style: AppText.small.tint(Barako.muted),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
            child: Row(
              children: [
                for (var i = 0; i < _stepTitles.length; i++) ...[
                  Expanded(
                    // Tappable so a person editing an existing debt can jump
                    // straight to the field or the review, instead of stepping
                    // through every screen to save one change.
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() {
                        error = null;
                        _step = i;
                      }),
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: i <= _step ? Barako.primary : Barako.border,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                      ),
                    ),
                  ),
                  if (i < _stepTitles.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: Gap.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
            child: Text(
              _stepTitles[_step],
              style: Barako.kickerStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepScroll(Widget child) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(Gap.gutter, Gap.sm, Gap.gutter, Gap.lg),
    child: child,
  );

  Widget _basicsStep() {
    final isCard = type == 'credit card';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isCard) _cardPreview() else _debtPreview(),
        const SizedBox(height: Gap.lg),
        _labeledField(
          name,
          'Name',
          hint: 'BPI card, or a family loan',
          number: false,
          onChanged: (_) => setState(() {}),
        ),
        Text(
          'Type',
          style: AppText.small.w6.tint(Barako.textSecondary),
        ),
        const SizedBox(height: Gap.xs),
        _typeRow(),
        const SizedBox(height: Gap.md),
        Text(
          'Bank or lender',
          style: AppText.small.w6.tint(Barako.textSecondary),
        ),
        const SizedBox(height: Gap.xs),
        _institutionRow(),
        if (isCard) ...[
          const SizedBox(height: Gap.md),
          _networkPicker(),
          _labeledField(
            last4,
            'Card number, last 4 only',
            hint: '1234',
            number: true,
            maxLen: 4,
            optional: true,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ],
    );
  }

  Widget _owedStep() {
    final isCard = type == 'credit card';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labeledField(
          remaining,
          isCard ? 'Current balance' : 'Remaining balance',
          hint: '0',
          onChanged: (_) => setState(() {}),
        ),
        _rateSection(),
        _labeledField(
          minPay,
          'Minimum payment',
          hint: '0',
          helper: 'Enter 0 if none.',
        ),
        if (isCard) ...[
          _labeledField(
            creditLimit,
            'Credit limit',
            hint: '0',
            optional: true,
          ),
          _labeledField(annualFee, 'Annual fee', hint: '0', optional: true),
        ],
      ],
    );
  }

  /// The bank-adjusted next due date for the SCHEDULE AS TYPED SO FAR, using
  /// the same golden-locked `bankDueDate` the Debts screen forecast and the
  /// `bills` reminder already read (`money/commitments.dart`). Nothing here is
  /// new money or date logic: it is a live preview of what the person is about
  /// to save, so the promise on screen and the reminder that actually fires
  /// can never disagree. Null while there is no schedule to resolve yet (an
  /// empty due day, and for a card, no statement day plus grace days either).
  ({DateTime date, DateTime raw, bool moved, String reason})? get _previewDue {
    return bankDueDate({
      'dueDay': dueDay.text.trim(),
      'statementDay': statementDay.text.trim(),
      'graceDays': graceDays.text.trim(),
    }, DateTime.now());
  }

  Widget _scheduleStep() {
    final isCard = type == 'credit card';
    final preview = _previewDue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labeledField(
          dueDay,
          'Payment due day',
          hint: 'e.g. 15',
          optional: true,
          helper: 'Day of the month the payment is due.',
          onChanged: (_) => setState(() {}),
        ),
        if (isCard) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _labeledField(
                  statementDay,
                  'Statement day',
                  hint: 'e.g. 5',
                  optional: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: _labeledField(
                  graceDays,
                  'Grace days',
                  hint: 'e.g. 21',
                  optional: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: Gap.xs, bottom: Gap.md),
            child: Text(
              'A due day lets Salapify remind you before a payment is due. '
              'You can leave it blank.',
              style: AppText.caption.tint(Barako.muted).copyWith(height: 1.4),
            ),
          ),
        if (preview != null) _dueDatePreview(preview),
        if (isCard) _safetyNote(),
      ],
    );
  }

  /// "Next payment: Jun 15 · in 12 days", adjusted the moment the due date
  /// would otherwise land on a weekend or a Philippine holiday, the exact
  /// same wording the Debts screen forecast already uses ("moved, a
  /// Saturday"), so a person sees one vocabulary for this idea everywhere in
  /// the app. Always-on reassurance, never a claim about a specific holiday
  /// list: the engine already fails safe (an unlisted date is simply not
  /// adjusted, never adjusted wrongly), so the copy promises the CHECK, not a
  /// guarantee no PH holiday was ever missed.
  Widget _dueDatePreview(
    ({DateTime date, DateTime raw, bool moved, String reason}) due,
  ) {
    final days = daysUntil(due.date, DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: Gap.md),
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Barako.primary.withValues(alpha: BarakoAlpha.tint),
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            salapifyIcon('calendar'),
            size: IconSizes.dense,
            color: Barako.primaryText,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next payment: ${shortDueDate(due.date)} · ${daysUntilWords(days)}',
                  style: AppText.small.w7.tint(Barako.primaryText),
                ),
                const SizedBox(height: 2),
                Text(
                  due.moved
                      ? 'Moved from ${shortDueDate(due.raw)} because it falls '
                            'on ${due.reason}. We check weekends and Philippine '
                            'holidays automatically.'
                      : 'We check weekends and Philippine holidays '
                            'automatically, and move the reminder earlier when '
                            'one falls on your due date.',
                  style: AppText.caption.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewStep() {
    final isCard = type == 'credit card';
    final rows = <(String, String)>[
      ('Name', name.text.trim().isEmpty ? 'Not set' : name.text.trim()),
      ('Type', _typeLabel(type)),
      if (institutionId.isNotEmpty)
        (
          'Bank or lender',
          institutionById(institutionId)?.displayName ?? 'Not set',
        ),
      (
        isCard ? 'Current balance' : 'Remaining balance',
        formatMoney((parseAmount(remaining.text) ?? 0)),
      ),
      if ((double.tryParse(rateCtl.text.trim()) ?? 0) > 0) ...[
        (
          'Interest rate',
          '${rateCtl.text.trim()}% ${_rateAnnual ? 'per year' : 'per month'}',
        ),
        ('Est. interest / month', 'About ${formatMoneyAbout(_estimatedMonthly)}'),
      ],
      if ((parseAmount(minPay.text) ?? 0) > 0)
        ('Minimum payment', formatMoney((parseAmount(minPay.text) ?? 0))),
      if (dueDay.text.trim().isNotEmpty) ('Payment due day', dueDay.text.trim()),
      if (isCard) ...[
        if (creditLimit.text.trim().isNotEmpty)
          ('Credit limit', formatMoney((parseAmount(creditLimit.text) ?? 0))),
        if (statementDay.text.trim().isNotEmpty)
          ('Statement day', statementDay.text.trim()),
        if (network.isNotEmpty)
          ('Card network', cardNetworkById(network)?.displayName ?? network),
        if (last4.text.trim().isNotEmpty) ('Card number', '•••• ${last4.text.trim()}'),
        if (annualFee.text.trim().isNotEmpty)
          ('Annual fee', formatMoney((parseAmount(annualFee.text) ?? 0))),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isCard) _cardPreview() else _debtPreview(),
        const SizedBox(height: Gap.lg),
        Container(
          decoration: BoxDecoration(
            color: Barako.card,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: Barako.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, color: Barako.border),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          rows[i].$1,
                          style: AppText.small.tint(Barako.muted),
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Flexible(
                        child: Text(
                          rows[i].$2,
                          textAlign: TextAlign.right,
                          style: AppText.small.w6.tint(Barako.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _wizardFooter() {
    final last = _step == _stepTitles.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.gutter, Gap.md, Gap.gutter, Gap.lg),
      decoration: BoxDecoration(
        color: Barako.card,
        border: Border(top: BorderSide(color: Barako.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null) _errorBanner(error!),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : (last ? _save : _next),
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      last
                          ? (widget.debt != null ? 'Save changes' : 'Add debt')
                          : 'Continue',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: Gap.md),
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Barako.warning.withValues(alpha: BarakoAlpha.wash),
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: Barako.warning.withValues(alpha: BarakoAlpha.hint)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(salapifyIcon('error'), size: IconSizes.dense, color: Barako.warning),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              msg,
              style: AppText.small.copyWith(height: 1.4).tint(Barako.warning),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact per-month / per-year segmented toggle for the interest unit.
class _RateUnitToggle extends StatelessWidget {
  final bool annual;
  final ValueChanged<bool> onChanged;

  // ignore: prefer_const_constructors_in_immutables
  _RateUnitToggle({required this.annual, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool isAnnual) {
      final on = annual == isAnnual;
      return GestureDetector(
        onTap: () => onChanged(isAnnual),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? Barako.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Text(
            label,
            style: on
                ? AppText.micro.w7.tint(Barako.onPrimary)
                : AppText.micro.w6.tint(Barako.muted),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Barako.background,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: Barako.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg('Per month', false), seg('Per year', true)],
      ),
    );
  }
}
