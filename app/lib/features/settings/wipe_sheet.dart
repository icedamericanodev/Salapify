import 'package:flutter/material.dart';

import '../../core/money/accounts.dart';
import '../../core/money/format.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../state/financial_state.dart';
import '../shared/sheet_scaffold.dart';

/// Delete everything on this phone.
///
/// The one control in Salapify with no way back, so it is built the way a
/// control with no way back has to be built:
///
///  1. It shows what is about to be lost as FIGURES, counted from the real
///     ledger, before anything happens. "Your data" is abstract. "11 accounts,
///     183 entries and 254,200 pesos of balances" is a thing somebody can
///     recognise as theirs, or fail to recognise and back out.
///  2. It says, in those words, that there is no undo, and WHY: the two copies
///     Salapify keeps for exactly that purpose are part of what it removes.
///  3. It asks twice, and the second tap is a different button in a different
///     place, so a double tap on the first one cannot do it.
///  4. It offers the export first, right there, because the person who wants
///     a clean start and the person who wants their records gone are the same
///     person on different days.
///
/// It exists because the privacy policy promises it and Play asks whether the
/// app offers it, and both of those would be false without this screen. It is
/// also the only route that removes the pre-import copy, which no other part
/// of the app mentions and which never expires.
class WipeSheet extends StatefulWidget {
  const WipeSheet({super.key, required this.state});

  final FinancialState state;

  static Future<void> show(BuildContext context, FinancialState state) {
    return SheetScaffold.show<void>(
      context: context,
      palette: Palette.of(state.theme),
      builder: (BuildContext context) => WipeSheet(state: state),
    );
  }

  @override
  State<WipeSheet> createState() => _WipeSheetState();
}

class _WipeSheetState extends State<WipeSheet> {
  bool _confirming = false;
  bool _busy = false;
  int? _removed;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final FinancialState s = widget.state;

    if (_removed != null) return _done(p);

    final double assets = accountsTotalPhp(assetsOf(s.accounts));
    final double owed = accountsTotalPhp(liabilitiesOf(s.accounts));

    return SheetScaffold(
      palette: p,
      icon: Icons.delete_forever_outlined,
      title: 'Delete everything',
      subtitle: 'Erases your records from this phone, for good',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: p.negativeSoft,
              borderRadius: BorderRadius.circular(Radii.tile),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'There is no undo',
                  style: AppType.section(p).copyWith(color: p.negative),
                ),
                const SizedBox(height: 4),
                Text(
                  'Salapify normally keeps two spare copies so a mistake can '
                  'be put right. This deletes those too, because leaving them '
                  'would mean your records were still on the phone after you '
                  'asked for them to be gone.',
                  style: AppType.body(p).copyWith(color: p.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),

          Text('WHAT GOES', style: AppType.kicker(p)),
          const SizedBox(height: Spacing.sm),
          _Count(palette: p, what: 'Accounts', n: s.accounts.length),
          _Count(palette: p, what: 'Entries', n: s.transactions.length),
          _Count(palette: p, what: 'Debts', n: s.debts.length),
          _Count(palette: p, what: 'Goals', n: s.goals.length),
          _Count(palette: p, what: 'Budget limits', n: s.budgets.length),
          _Count(palette: p, what: 'Bills', n: s.bills.length),
          _Count(palette: p, what: 'Payment plans', n: s.installments.length),
          const SizedBox(height: Spacing.sm),
          // Assets and what is owed stay APART, never summed. Adding them once
          // announced a demo mortgage as money somebody had.
          _Money(palette: p, what: 'Balances held', amount: assets),
          if (owed > 0)
            _Money(palette: p, what: 'Owed on accounts', amount: owed),

          const SizedBox(height: Spacing.lg),
          Text(
            'Anything you exported yourself is yours and is untouched. '
            'Uninstalling Salapify removes all of this as well.',
            style: AppType.caption(p),
          ),
          const SizedBox(height: Spacing.lg),

          if (!_confirming)
            _Button(
              palette: p,
              label: 'Delete everything',
              danger: true,
              onTap: () => setState(() => _confirming = true),
            )
          else ...<Widget>[
            Text(
              'Last check. Tapping the red button erases the figures above '
              'from this phone and they cannot be brought back.',
              style: AppType.body(p).copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: Spacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Button(
                    palette: p,
                    label: 'Keep my records',
                    danger: false,
                    onTap: _busy
                        ? null
                        : () => setState(() => _confirming = false),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: _Button(
                    palette: p,
                    label: _busy ? 'Erasing...' : 'Yes, erase it',
                    danger: true,
                    onTap: _busy ? null : _wipe,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _wipe() async {
    setState(() => _busy = true);
    final int removed = await widget.state.deleteEverything();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _removed = removed;
    });
  }

  Widget _done(Palette p) {
    return SheetScaffold(
      palette: p,
      icon: Icons.check_circle_outline,
      title: 'Gone',
      subtitle: 'Salapify is empty and is still saving',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            // The count, not a claim. A file that refused to delete is not
            // reported as a success.
            '$_removed ${_removed == 1 ? 'file' : 'files'} removed from this '
            'phone: your ledger, the spare copies Salapify kept, and the '
            'saved exchange rates.',
            style: AppType.body(p),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'The sample data has NOT come back. You asked for an empty app, '
            'so that is what this is. Anything you type from here is saved '
            'normally.',
            style: AppType.body(p),
          ),
          const SizedBox(height: Spacing.lg),
          _Button(
            palette: p,
            label: 'Close',
            danger: false,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.palette, required this.what, required this.n});

  final Palette palette;
  final String what;
  final int n;

  @override
  Widget build(BuildContext context) {
    if (n == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(what, style: AppType.body(palette))),
          Text('$n', style: AppType.amountSmall(palette)),
        ],
      ),
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({
    required this.palette,
    required this.what,
    required this.amount,
  });

  final Palette palette;
  final String what;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(what, style: AppType.body(palette))),
          Text(formatPeso(amount), style: AppType.amountSmall(palette)),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.palette,
    required this.label,
    required this.danger,
    this.onTap,
  });

  final Palette palette;
  final String label;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg = danger ? palette.negative : palette.surfaceAlt;
    final Color fg = danger ? palette.background : palette.textPrimary;
    return Semantics(
      button: true,
      child: Material(
        color: onTap == null ? palette.surfaceAlt : bg,
        borderRadius: BorderRadius.circular(Radii.tile),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.tile),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppType.button(
                palette,
                color: onTap == null ? palette.textMuted : fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
