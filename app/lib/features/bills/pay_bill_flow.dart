import 'package:flutter/material.dart';

import '../../core/money/bills.dart';
import '../../core/money/format.dart';
import '../../core/money/reports.dart' show settlementKinds;
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';

/// Paying a scheduled bill, from wherever somebody taps the tick.
///
/// ONE FLOW, TWO DOORS, and that is the whole reason this is a file rather
/// than a method on a screen. The tick exists on Home's Coming Up card and in
/// the Bills sheet, both labelled `Mark <name> as paid`. Before this they did
/// different things: Coming Up flipped a flag and left the ledger alone, by a
/// deliberate decision recorded in its own comment, and the Bills screen did
/// not exist. Founder direction on 2026-10-01 settled it for both: ticking a
/// bill paid moves the money, and asks which account it came from.
///
/// Two controls that look identical and do different things to money is worse
/// than either behaviour on its own, so neither screen owns this.
/// Returns the ledger entry it wrote, or null if nothing was paid (cancelled,
/// or an income row, which never writes one).
///
/// [confirmWithSnackBar] exists because a SnackBar is drawn BELOW a modal
/// bottom sheet. Opened from the Bills sheet, which stands at 92% of the
/// screen, the undo action was on screen and physically unreachable: a test
/// tapping it moved nothing, and a person tapping it would have had the same
/// silence. The sheet therefore turns this off and offers its own undo on the
/// row, where nothing can cover it. Home's Coming Up card has no sheet over
/// it, so it keeps the snack bar.
Future<Transaction?> payBillFlow(
  BuildContext context,
  Palette palette,
  FinancialState state,
  UpcomingItem item, {
  bool confirmWithSnackBar = true,
}) async {
  // Income rows never write an expense, so there is nothing to ask about.
  // Ticking a payday marks it arrived; the real deposit is logged when it
  // lands and inventing one here would double count it.
  if (item.countsAsIncome) {
    state.markUpcomingPaid(item.id);
    return null;
  }

  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final _PayChoice? choice = await showDialog<_PayChoice>(
    context: context,
    builder: (BuildContext context) =>
        _PayBillDialog(palette: palette, state: state, item: item),
  );
  if (choice == null) return null;

  final Transaction? written = state.markUpcomingPaid(
    item.id,
    accountId: choice.accountId,
    category: choice.category,
  );

  if (!confirmWithSnackBar) return written;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          '${formatPeso(item.amount.pesos)} left '
          '${state.accounts.firstWhere((Account a) => a.id == choice.accountId).name}.',
        ),
        // The way back from a mis-tap. A tick that moves real money sits on a
        // screen full of small round targets, and without this the only
        // recovery is finding the entry in Activity and knowing the bill put
        // it there.
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => state.undoUpcomingPaid(item.id, written),
        ),
      ),
    );
  return written;
}

class _PayChoice {
  const _PayChoice({required this.accountId, required this.category});

  final String accountId;
  final String category;
}

class _PayBillDialog extends StatefulWidget {
  const _PayBillDialog({
    required this.palette,
    required this.state,
    required this.item,
  });

  final Palette palette;
  final FinancialState state;
  final UpcomingItem item;

  @override
  State<_PayBillDialog> createState() => _PayBillDialogState();
}

class _PayBillDialogState extends State<_PayBillDialog> {
  String? _accountId;
  late String _category;

  /// Accounts money can actually leave.
  ///
  /// Liabilities are excluded for the same reason they are excluded from the
  /// Move sheet: on a card, a loan or a mortgage, `balance` is what is OWED,
  /// so paying a bill "from" one would reduce the debt rather than increase
  /// it. Paying a card with a card is a real thing people do and it is a debt
  /// transfer, not a bill payment, so it belongs on the Debt screen.
  List<Account> get _payable => widget.state.accounts
      .where((Account a) => settlementKinds.contains(a.kind))
      .toList();

  List<String> get _categories => widget.state.categories
      .where((CategoryInfo c) => c.kind == CategoryKind.expense)
      .map((CategoryInfo c) => c.name)
      .toList();

  @override
  void initState() {
    super.initState();
    final List<Account> accounts = _payable;
    // DELIBERATELY NOT PRE-SELECTED when there is a choice to make. The
    // prototype falls back to accounts[0] with no prompt, which writes a real
    // expense against whichever account happens to be first and says nothing.
    // With one account there is no choice and no question worth asking.
    _accountId = accounts.length == 1 ? accounts.first.id : null;
    _category = defaultCategoryFor(widget.item);
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final List<Account> accounts = _payable;
    final List<String> categories = _categories;

    return AlertDialog(
      backgroundColor: p.surface,
      title: Text('Pay ${widget.item.name}', style: AppType.title(p)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '${formatPeso(widget.item.amount.pesos)} will leave the account you '
              'pick, and the payment will show up in Activity.',
              style: AppType.body(p),
            ),
            const SizedBox(height: Spacing.lg),
            if (accounts.isEmpty)
              Text(
                'There are no accounts to pay from. Add one on the Accounts '
                'tab first.',
                style: AppType.body(p),
              )
            else ...<Widget>[
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Paid from',
                  labelStyle: AppType.label(p),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                ),
                items: <DropdownMenuItem<String>>[
                  for (final Account a in accounts)
                    DropdownMenuItem<String>(
                      value: a.id,
                      child: Text(
                        '${a.name}  ${formatPeso(a.balance.pesos)}',
                        style: AppType.body(p),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (String? v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: Spacing.md),
              // The category is a GUESS until somebody confirms it. The map in
              // bills.dart gets Spotify to Entertainment and Meralco to Bills,
              // and it cannot know that a software subscription is a business
              // cost. One tap fixes that, and the alternative is a number
              // quietly filed in the wrong report.
              DropdownButtonFormField<String>(
                initialValue: categories.contains(_category)
                    ? _category
                    : (categories.isNotEmpty ? categories.first : null),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: AppType.label(p),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                ),
                items: <DropdownMenuItem<String>>[
                  for (final String c in categories)
                    DropdownMenuItem<String>(
                      value: c,
                      child: Text(c, style: AppType.body(p)),
                    ),
                ],
                onChanged: (String? v) {
                  if (v != null) setState(() => _category = v);
                },
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: AppType.body(p)),
        ),
        TextButton(
          onPressed: _accountId == null
              ? null
              : () => Navigator.of(
                  context,
                ).pop(_PayChoice(accountId: _accountId!, category: _category)),
          child: Text(
            'Mark it paid',
            style: AppType.body(p).copyWith(
              color: _accountId == null ? p.textMuted : p.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
