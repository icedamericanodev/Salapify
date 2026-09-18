import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/reconciliation.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/info/info_dot.dart';
import '../../features/info/info_sheet.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';

/// Reconciliation, the fourth Reports tab and the only one that WRITES.
///
/// Every other report reads. This one puts the app's own number next to the
/// bank's and asks what to do when they differ, and its answer is always the
/// same: post a traceable entry, never edit the balance.
class ReconciliationView extends StatefulWidget {
  const ReconciliationView({super.key, required this.state});

  final FinancialState state;

  @override
  State<ReconciliationView> createState() => _ReconciliationViewState();
}

class _ReconciliationViewState extends State<ReconciliationView> {
  final TextEditingController _actual = TextEditingController();
  final TextEditingController _note = TextEditingController();
  late String _accountId;

  @override
  void initState() {
    super.initState();
    _accountId = widget.state.accounts.first.id;
  }

  @override
  void dispose() {
    _actual.dispose();
    _note.dispose();
    super.dispose();
  }

  Account get _account =>
      widget.state.accounts.firstWhere((Account a) => a.id == _accountId);

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final double book = bookBalanceOf(_account);
    final double? typed = double.tryParse(
      _actual.text.trim().replaceAll(',', ''),
    );
    final bool entered = typed != null;
    final double variance = entered ? varianceOf(book, typed) : 0;
    final bool balanced = isBalanced(variance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text('CHECK AN ACCOUNT', style: AppType.kicker(p))),
            InfoDot(
              color: p.textMuted,
              semanticLabel: 'What reconciliation does',
              onTap: () => InfoSheet.show(context, p, InfoTopic.reconciliation),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        _AccountPicker(
          palette: p,
          accounts: widget.state.accounts,
          selected: _accountId,
          onSelect: (String id) => setState(() {
            _accountId = id;
            _actual.clear();
          }),
        ),
        const SizedBox(height: Spacing.lg),
        _Comparator(
          palette: p,
          book: book,
          controller: _actual,
          entered: entered,
          variance: variance,
          balanced: balanced,
          onChanged: (_) => setState(() {}),
        ),
        if (entered) ...<Widget>[
          const SizedBox(height: Spacing.lg),
          if (balanced)
            _Balanced(palette: p, onConfirm: () => _confirm(book, typed))
          else
            _Fix(
              palette: p,
              variance: variance,
              note: _note,
              accountName: _account.name,
              onPost: () => _post(typed),
            ),
        ],
        const SizedBox(height: Spacing.lg),
        _Duplicates(
          palette: p,
          state: widget.state,
          onChanged: () => setState(() {}),
        ),
        if (widget.state.reconciliations.isNotEmpty) ...<Widget>[
          const SizedBox(height: Spacing.lg),
          _History(palette: p, state: widget.state),
        ],
      ],
    );
  }

  void _confirm(double book, double actual) {
    widget.state.recordReconciliation(
      accountId: _accountId,
      bookBalance: book,
      actualBalance: actual,
      notes: 'Checked against the statement and it matched.',
    );
    _actual.clear();
    setState(() {});
    _say('Recorded. ${_account.name} matched the statement.');
  }

  void _post(double actual) {
    widget.state.postReconciliationAdjustment(
      accountId: _accountId,
      actualBalance: actual,
      note: _note.text,
    );
    _actual.clear();
    _note.clear();
    setState(() {});
    _say('Adjustment posted. It is in your Activity.');
  }

  void _say(String message) {
    final Palette p = Palette.of(widget.state.theme);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: p.onAccent)),
          backgroundColor: p.accent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.palette,
    required this.accounts,
    required this.selected,
    required this.onSelect,
  });

  final Palette palette;
  final List<Account> accounts;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: <Widget>[
        for (final Account a in accounts)
          Semantics(
            button: true,
            selected: selected == a.id,
            child: InkWell(
              onTap: () => onSelect(a.id),
              borderRadius: BorderRadius.circular(Radii.pill),
              child: Container(
                constraints: const BoxConstraints(minHeight: 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.sm,
                ),
                decoration: BoxDecoration(
                  color: selected == a.id ? palette.accent : palette.surface,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(
                    color: selected == a.id ? palette.accent : palette.border,
                  ),
                ),
                child: Text(
                  a.name,
                  style: TextStyle(
                    fontFamily: AppType.family,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected == a.id
                        ? palette.onAccent
                        : palette.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The app's number, the bank's number, and the gap.
class _Comparator extends StatelessWidget {
  const _Comparator({
    required this.palette,
    required this.book,
    required this.controller,
    required this.entered,
    required this.variance,
    required this.balanced,
    required this.onChanged,
  });

  final Palette palette;
  final double book;
  final TextEditingController controller;
  final bool entered;
  final double variance;
  final bool balanced;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('SALAPIFY SAYS', style: AppType.kicker(palette)),
          Text(formatPeso(book), style: AppType.amount(palette)),
          const SizedBox(height: Spacing.lg),
          Text('What your statement says', style: AppType.label(palette)),
          const SizedBox(height: Spacing.xs),
          TextField(
            controller: controller,
            onChanged: onChanged,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppType.rowTitle(palette).copyWith(fontSize: 15),
            decoration: InputDecoration(
              hintText: book.toStringAsFixed(2),
              hintStyle: AppType.body(
                palette,
              ).copyWith(color: palette.textMuted),
              prefixText: '₱ ',
              prefixStyle: AppType.rowTitle(palette).copyWith(fontSize: 15),
              filled: true,
              fillColor: palette.card,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.control),
                borderSide: BorderSide(color: palette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.control),
                borderSide: BorderSide(color: palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.control),
                borderSide: BorderSide(color: palette.accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          if (!entered)
            Text(
              'Open your bank or e-wallet app and type what it shows.',
              style: AppType.caption(palette),
            )
          else ...<Widget>[
            Text(
              balanced
                  ? 'They match.'
                  : variance > 0
                  ? 'There is ${formatPeso(variance)} MORE in the account '
                        'than Salapify knew about.'
                  : 'There is ${formatPeso(variance)} LESS in the account '
                        'than Salapify expected.',
              style: AppType.rowTitle(
                palette,
              ).copyWith(color: balanced ? palette.positive : palette.negative),
            ),
            if (!balanced) ...<Widget>[
              const SizedBox(height: Spacing.xs),
              Text(
                // On the screen, not behind the dot. Without it, a gap reads
                // as an accusation, and the commonest causes are perfectly
                // ordinary.
                'Usually this is a fee, interest, or something you paid for '
                'and have not logged yet.',
                style: AppType.caption(palette),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Balanced extends StatelessWidget {
  const _Balanced({required this.palette, required this.onConfirm});

  final Palette palette;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: palette.positiveSoft,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Nothing to fix. Record that you checked?',
            style: AppType.rowTitle(palette),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Worth keeping. "We checked on the 18th and it matched" is exactly '
            'what you want to find when the figures stop matching later.',
            style: AppType.caption(palette),
          ),
          const SizedBox(height: Spacing.md),
          _Button(
            palette: palette,
            label: 'Record the check',
            onTap: onConfirm,
          ),
        ],
      ),
    );
  }
}

/// The only thing this screen does to money, and it says exactly what that is.
class _Fix extends StatelessWidget {
  const _Fix({
    required this.palette,
    required this.variance,
    required this.note,
    required this.accountName,
    required this.onPost,
  });

  final Palette palette;
  final double variance;
  final TextEditingController note;
  final String accountName;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final bool found = variance > 0;

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Close the gap', style: AppType.section(palette)),
          const SizedBox(height: Spacing.xs),
          Text(
            'Salapify will NOT quietly change the balance. It writes an entry '
            'for ${formatPeso(variance)}, so the account moves for a reason '
            'you can find again.',
            style: AppType.body(palette),
          ),
          const SizedBox(height: Spacing.md),
          Text('What was it, if you know', style: AppType.label(palette)),
          const SizedBox(height: Spacing.xs),
          TextField(
            controller: note,
            keyboardType: TextInputType.text,
            style: AppType.rowTitle(palette).copyWith(fontSize: 15),
            decoration: InputDecoration(
              hintText: found
                  ? 'Interest, a refund, cash I forgot to log'
                  : 'A fee, something I paid and did not log',
              hintStyle: AppType.body(
                palette,
              ).copyWith(color: palette.textMuted),
              filled: true,
              fillColor: palette.card,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.control),
                borderSide: BorderSide(color: palette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.control),
                borderSide: BorderSide(color: palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.control),
                borderSide: BorderSide(color: palette.accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Text(
              found
                  ? '$accountName goes UP by ${formatPeso(variance)}, filed as '
                        'found cash, and an entry in your Activity will say so.'
                  : '$accountName goes DOWN by ${formatPeso(variance)}, filed '
                        'as a write-off, and an entry in your Activity will '
                        'say so.',
              style: AppType.caption(palette),
            ),
          ),
          const SizedBox(height: Spacing.md),
          _Button(
            palette: palette,
            label: 'Post the adjustment',
            onTap: onPost,
          ),
        ],
      ),
    );
  }
}

/// Entries that look like the same thing logged twice. A suggestion only.
class _Duplicates extends StatelessWidget {
  const _Duplicates({
    required this.palette,
    required this.state,
    required this.onChanged,
  });

  final Palette palette;
  final FinancialState state;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final List<DuplicatePair> pairs = findDuplicates(state.transactions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('POSSIBLE DOUBLE ENTRIES', style: AppType.kicker(palette)),
        const SizedBox(height: Spacing.sm),
        Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: palette.border),
          ),
          child: pairs.isEmpty
              ? Text('Nothing looks doubled up.', style: AppType.body(palette))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      // Said first, because the list is a guess. Two identical
                      // jeepney fares on one day are two jeepney fares.
                      'Salapify only spotted these, it has not changed '
                      'anything. Two identical fares on the same day are two '
                      'real fares, and only you know which.',
                      style: AppType.caption(palette),
                    ),
                    const SizedBox(height: Spacing.md),
                    for (final DuplicatePair pair in pairs) ...<Widget>[
                      _PairRow(
                        palette: palette,
                        pair: pair,
                        onMark: () {
                          state.setTransactionStatus(
                            pair.second.id,
                            TransactionStatus.duplicate,
                          );
                          onChanged();
                        },
                      ),
                      const SizedBox(height: Spacing.sm),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _PairRow extends StatelessWidget {
  const _PairRow({
    required this.palette,
    required this.pair,
    required this.onMark,
  });

  final Palette palette;
  final DuplicatePair pair;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${pair.first.merchant ?? pair.first.category}, '
            '${formatPeso(pair.first.amount)}',
            style: AppType.rowTitle(palette),
          ),
          Text(pair.reason, style: AppType.caption(palette)),
          const SizedBox(height: Spacing.sm),
          _Button(
            palette: palette,
            label: 'Mark the second one a duplicate',
            filled: false,
            onTap: onMark,
          ),
        ],
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.palette, required this.state});

  final Palette palette;
  final FinancialState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('CHECKS YOU HAVE DONE', style: AppType.kicker(palette)),
        const SizedBox(height: Spacing.sm),
        Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final ReconciliationRecord r in state.reconciliations) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${r.date}, '
                        '${state.accounts.firstWhere((Account a) => a.id == r.accountId, orElse: () => state.accounts.first).name}',
                        style: AppType.rowTitle(palette),
                      ),
                      Text(
                        r.notes ?? (r.balanced ? 'Matched.' : 'Gap recorded.'),
                        style: AppType.caption(palette),
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
}

class _Button extends StatelessWidget {
  const _Button({
    required this.palette,
    required this.label,
    required this.onTap,
    this.filled = true,
  });

  final Palette palette;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          decoration: BoxDecoration(
            color: filled ? palette.accent : palette.surface,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(color: filled ? palette.accent : palette.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppType.family,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: filled ? palette.onAccent : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
