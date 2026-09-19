import 'package:flutter/material.dart';

import '../../core/money/accounts.dart';
import '../../core/money/currencies.dart';
import '../../core/money/format.dart';
import '../../design/institution_brand.dart';
import '../../design/institution_mark.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/accounts/account_sheet.dart';
import '../../features/info/info_dot.dart';
import '../../features/info/info_sheet.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import 'bank_card.dart';

/// Accounts, the prototype's fifth tab, from src/components/AccountsScreen.tsx.
///
/// Every figure comes out of core/money/accounts.dart, which is tested against
/// the same accounts Reports reads, so the net worth here and the net worth on
/// Reports cannot drift apart. This file decides what the screen looks like
/// and nothing about what it says.
///
/// SCOPE, named rather than implied. The prototype's fourth filter,
/// Investments, opens a whole holdings tracker (InvestmentsView.tsx, 1,114
/// lines: units, cost basis, valuations, market data adapters). That is its
/// own batch. The filter still works here and shows the investment ACCOUNTS,
/// which is real content rather than a dead pill, and says in one line what
/// the tracker will add.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key, required this.state, this.onOpenDebt});

  final FinancialState state;
  final VoidCallback? onOpenDebt;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  AccountView _view = AccountView.all;

  /// Which groups are open. Everything starts open, the prototype's own
  /// default: a first-time visitor should see their money, not eight closed
  /// drawers they have to discover are drawers.
  final Set<String> _collapsed = <String>{};

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final ProfileEntity? profile = widget.state.activeProfile;

    final List<Account> scoped = filterAccounts(
      widget.state.accounts,
      profile: profile,
    );
    final AccountsSummary summary = summarize(scoped);
    final List<Account> shown = filterAccounts(
      widget.state.accounts,
      profile: profile,
      view: _view == AccountView.investments ? AccountView.all : _view,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Header(palette: p, onAdd: () => _openSheet(context, p, null)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.sm,
              Spacing.lg,
              Spacing.xl,
            ),
            children: <Widget>[
              _NetWorthCard(palette: p, summary: summary, profile: profile),
              const SizedBox(height: Spacing.md),
              _ViewPicker(
                palette: p,
                current: _view,
                allCount: scoped.length,
                assetCount: summary.assetCount,
                liabilityCount: summary.liabilityCount,
                onSelect: (AccountView v) => setState(() => _view = v),
              ),
              const SizedBox(height: Spacing.lg),
              if (_view == AccountView.investments)
                _InvestmentsView(palette: p, accounts: shown)
              else ...<Widget>[
                if (_view != AccountView.liabilities)
                  _GroupedSection(
                    palette: p,
                    heading: 'Assets',
                    tint: p.positive,
                    groups: groupAssets(shown),
                    emptyNote: 'No asset accounts under this entity.',
                    collapsed: _collapsed,
                    onToggle: _toggle,
                    onEdit: (Account a) => _openSheet(context, p, a),
                  ),
                if (_view == AccountView.all)
                  const SizedBox(height: Spacing.lg),
                if (_view != AccountView.assets)
                  _GroupedSection(
                    palette: p,
                    heading: 'Liabilities and obligations',
                    tint: p.negative,
                    groups: groupLiabilities(shown),
                    emptyNote: 'No liability accounts recorded.',
                    collapsed: _collapsed,
                    onToggle: _toggle,
                    onEdit: (Account a) => _openSheet(context, p, a),
                  ),
              ],
              const SizedBox(height: Spacing.lg),
              _DebtRegisterCard(
                palette: p,
                state: widget.state,
                onOpen: widget.onOpenDebt,
              ),
              const SizedBox(height: Spacing.lg),
              // Not decoration, and not behind the info dot either. Using a
              // bank's own mark to label an account is fair use; letting a
              // reader infer a relationship that does not exist is not, and
              // silence here would mislead. The prototype carries the same
              // sentence at the foot of its own Accounts screen.
              Text(brandDisclaimer, style: AppType.caption(p)),
            ],
          ),
        ),
      ],
    );
  }

  void _toggle(String id) => setState(() {
    if (!_collapsed.remove(id)) _collapsed.add(id);
  });

  Future<void> _openSheet(
    BuildContext context,
    Palette palette,
    Account? existing,
  ) async {
    await AccountSheet.show(
      context,
      palette: palette,
      state: widget.state,
      existing: existing,
    );
    if (mounted) setState(() {});
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.palette, required this.onAdd});

  final Palette palette;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.sm, 0),
      child: Row(
        children: <Widget>[
          Text('Accounts', style: AppType.title(palette)),
          InfoDot(
            color: palette.textMuted,
            semanticLabel: 'What counts as an account',
            onTap: () => InfoSheet.show(context, palette, InfoTopic.accounts),
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: 'Add an account',
            child: InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(Radii.pill),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.add, size: 16, color: palette.accent),
                    const SizedBox(width: Spacing.xs),
                    Text(
                      'Add',
                      style: AppType.button(palette, color: palette.accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The hero. Net worth from ACCOUNTS, with the two halves that make it up.
class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({
    required this.palette,
    required this.summary,
    required this.profile,
  });

  final Palette palette;
  final AccountsSummary summary;
  final ProfileEntity? profile;

  static String _entityLabel(ProfileEntity? e) => switch (e) {
    null => 'Consolidated',
    ProfileEntity.personal => 'Personal',
    ProfileEntity.household => 'Household',
    ProfileEntity.business => 'Business',
    ProfileEntity.sideHustle => 'Side hustle',
  };

  @override
  Widget build(BuildContext context) {
    final double net = summary.netWorth;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'NET WORTH, ${_entityLabel(profile).toUpperCase()}',
            style: AppType.kicker(palette),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            // The sign is drawn, never left to colour. formatPeso returns the
            // absolute value on purpose, so a debt of 217,229.50 would
            // otherwise render character for character like savings of the
            // same amount.
            net < 0 ? '-${formatPeso(net)}' : formatPeso(net),
            style: AppType.hero(palette),
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.xs,
            children: <Widget>[
              _Half(
                palette: palette,
                label: 'You own',
                amount: summary.totalAssets,
                color: palette.positive,
              ),
              _Half(
                palette: palette,
                label: 'You owe',
                amount: summary.totalLiabilities,
                color: palette.negative,
              ),
            ],
          ),
          if (net < 0) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            // Stays on the screen rather than behind the dot. Somebody seeing
            // a large negative number for the first time needs the reassurance
            // at the moment of alarm, not one tap away.
            Text(
              'A housing loan alone can do this.',
              style: AppType.caption(palette),
            ),
          ],
          const SizedBox(height: Spacing.sm),
          Text(
            'Debts you have logged are counted separately, below.',
            style: AppType.caption(palette),
          ),
        ],
      ),
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({
    required this.palette,
    required this.label,
    required this.amount,
    required this.color,
  });

  final Palette palette;
  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Text.rich, NOT RichText. RichText takes the style it is given and
    // nothing else, so a style with no fontFamily falls back to the platform
    // default instead of Plus Jakarta Sans; in the render harness, which has
    // only the app's own fonts loaded, that came out as a row of empty boxes.
    // Text.rich resolves against DefaultTextStyle first, like every other
    // Text on the screen. Caught by looking at the picture, and by nothing
    // else: fifteen assertions about this screen were green at the time.
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: '$label '),
          TextSpan(
            text: formatPeso(amount),
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
      style: AppType.caption(palette),
    );
  }
}

/// All, Assets, Liabilities, Investments.
class _ViewPicker extends StatelessWidget {
  const _ViewPicker({
    required this.palette,
    required this.current,
    required this.allCount,
    required this.assetCount,
    required this.liabilityCount,
    required this.onSelect,
  });

  final Palette palette;
  final AccountView current;
  final int allCount;
  final int assetCount;
  final int liabilityCount;
  final ValueChanged<AccountView> onSelect;

  @override
  Widget build(BuildContext context) {
    final Map<AccountView, String> labels = <AccountView, String>{
      AccountView.all: 'All $allCount',
      AccountView.assets: 'Own $assetCount',
      AccountView.liabilities: 'Owe $liabilityCount',
      AccountView.investments: 'Invested',
    };

    // Wrap, not Row. Four pills with counts in them do not fit one line at
    // 320dp with large text, and a Row would simply clip the last one off the
    // edge of the phone.
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: <Widget>[
        for (final MapEntry<AccountView, String> e in labels.entries)
          _Pill(
            palette: palette,
            label: e.value,
            selected: current == e.key,
            onTap: () => onSelect(e.key),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? palette.accent : palette.surface,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(
              color: selected ? palette.accent : palette.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? palette.onAccent : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// One half of the list: the heading with its total, then the groups.
class _GroupedSection extends StatelessWidget {
  const _GroupedSection({
    required this.palette,
    required this.heading,
    required this.tint,
    required this.groups,
    required this.emptyNote,
    required this.collapsed,
    required this.onToggle,
    required this.onEdit,
  });

  final Palette palette;
  final String heading;
  final Color tint;
  final List<AccountGroup> groups;
  final String emptyNote;
  final Set<String> collapsed;
  final ValueChanged<String> onToggle;
  final ValueChanged<Account> onEdit;

  @override
  Widget build(BuildContext context) {
    final double total = groups.fold<double>(
      0,
      (double s, AccountGroup g) => s + g.totalPhp,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                heading.toUpperCase(),
                style: AppType.kicker(palette).copyWith(color: tint),
              ),
            ),
            Text(
              formatPeso(total),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: tint,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        if (groups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              emptyNote,
              textAlign: TextAlign.center,
              style: AppType.caption(palette),
            ),
          )
        else
          for (final AccountGroup g in groups) ...<Widget>[
            _Group(
              palette: palette,
              group: g,
              open: !collapsed.contains(g.id),
              onToggle: () => onToggle(g.id),
              onEdit: onEdit,
            ),
            const SizedBox(height: Spacing.sm),
          ],
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.palette,
    required this.group,
    required this.open,
    required this.onToggle,
    required this.onEdit,
  });

  final Palette palette;
  final AccountGroup group;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<Account> onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: <Widget>[
          Semantics(
            button: true,
            expanded: open,
            label: '${group.title}, ${group.accounts.length} accounts',
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(Radii.card),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg,
                  vertical: Spacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${group.title} (${group.accounts.length})',
                        style: AppType.section(palette),
                      ),
                    ),
                    Text(
                      formatPeso(group.totalPhp),
                      style: AppType.rowMeta(palette),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Icon(
                      open ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: palette.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            for (final Account a in group.accounts)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.md,
                  0,
                  Spacing.md,
                  Spacing.md,
                ),
                child:
                    a.kind == AccountKind.debit || a.kind == AccountKind.credit
                    ? BankCard(
                        account: a,
                        palette: palette,
                        onTap: () => onEdit(a),
                      )
                    : _AccountRow(
                        palette: palette,
                        account: a,
                        onTap: () => onEdit(a),
                      ),
              ),
        ],
      ),
    );
  }
}

/// Everything that is not plastic: cash, e-wallets, savings, investments,
/// receivables, loans and mortgages.
class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.palette,
    required this.account,
    required this.onTap,
  });

  final Palette palette;
  final Account account;
  final VoidCallback onTap;

  static String _kindLabel(AccountKind k) => switch (k) {
    AccountKind.cash => 'Cash',
    AccountKind.bank => 'Bank',
    AccountKind.gcash => 'GCash',
    AccountKind.maya => 'Maya',
    AccountKind.debit => 'Debit',
    AccountKind.credit => 'Credit card',
    AccountKind.loan => 'Loan',
    AccountKind.mortgage => 'Mortgage',
    AccountKind.investment => 'Investment',
    AccountKind.receivable => 'Receivable',
  };

  @override
  Widget build(BuildContext context) {
    final bool owed = liabilitiesOf(<Account>[account]).isNotEmpty;
    final Color amountColor = owed ? palette.negative : palette.positive;

    final List<String> meta = <String>[
      _kindLabel(account.kind),
      account.institution,
      if (account.interestRate != null) '${account.interestRate}% a year',
      if (account.dueDate != null) 'Due ${account.dueDate}',
    ];

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: <Widget>[
              // The institution's own mark where Salapify ships one, and the
              // account's monogram where it does not. Both are drawn from the
              // device: see design/institution_brand.dart for why this is not
              // the prototype's remote favicon lookup.
              InstitutionMark(
                institution: account.institution,
                monogram: account.monogram,
                palette: palette,
                size: 38,
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      account.name,
                      maxLines: 2,
                      style: AppType.rowTitle(palette),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.join(' · '),
                      maxLines: 2,
                      style: AppType.rowMeta(palette),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    account.isForeign
                        ? formatCurrency(account.balance, account.currency)
                        : formatPeso(account.balance),
                    style: AppType.amountSmall(
                      palette,
                    ).copyWith(color: amountColor),
                  ),
                  if (account.isForeign)
                    Text(
                      // "About", because the rate is fixed and offline. A
                      // converted figure is an estimate and the screen has to
                      // say so wherever it shows one.
                      'about ${formatPeso(account.balanceInPhp)}',
                      style: AppType.caption(palette),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Investments filter. Shows the investment ACCOUNTS, which the app really
/// has, and says in one line what the holdings tracker will add on top.
class _InvestmentsView extends StatelessWidget {
  const _InvestmentsView({required this.palette, required this.accounts});

  final Palette palette;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final List<Account> invested = accounts
        .where((Account a) => a.kind == AccountKind.investment)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _GroupedSection(
          palette: palette,
          heading: 'What you have invested',
          tint: palette.positive,
          groups: <AccountGroup>[
            if (invested.isNotEmpty)
              AccountGroup(
                id: 'investment',
                title: 'Investments',
                accounts: invested,
              ),
          ],
          emptyNote:
              'No investment accounts yet. Add one to track MP2, WISP, '
              'a UITF or stocks alongside everything else.',
          collapsed: const <String>{},
          onToggle: (_) {},
          onEdit: (_) {},
        ),
        const SizedBox(height: Spacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Holdings come next', style: AppType.section(palette)),
              const SizedBox(height: Spacing.xs),
              Text(
                'Right now an investment is one balance you keep up to date '
                'yourself. Units, what you paid, and what it is worth today '
                'are the next step.',
                style: AppType.body(palette),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The both-ways debt register, which is a link rather than a list: debts are
/// their own screen, and this card exists so the two figures are visible from
/// the place people come to count what they have.
class _DebtRegisterCard extends StatelessWidget {
  const _DebtRegisterCard({
    required this.palette,
    required this.state,
    required this.onOpen,
  });

  final Palette palette;
  final FinancialState state;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    double outstanding(DebtDirection d) => state.debts
        .where((Debt x) => !x.isSettled && x.direction == d)
        .fold<double>(
          0,
          (double s, Debt x) =>
              s + (x.totalAmount - x.paidAmount).clamp(0, double.infinity),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'DEBT REGISTER, BOTH WAYS',
                style: AppType.kicker(palette),
              ),
            ),
            InfoDot(
              color: palette.textMuted,
              semanticLabel: 'Why debts are counted separately',
              onTap: () =>
                  InfoSheet.show(context, palette, InfoTopic.debtBothWays),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        Semantics(
          button: onOpen != null,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(Radii.card),
            child: Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                children: <Widget>[
                  _DebtRow(
                    palette: palette,
                    label: 'You owe people and lenders',
                    amount: outstanding(DebtDirection.iOwe),
                    color: palette.negative,
                  ),
                  Divider(color: palette.border, height: Spacing.xl),
                  _DebtRow(
                    palette: palette,
                    label: 'People owe you',
                    amount: outstanding(DebtDirection.owedToMe),
                    color: palette.positive,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({
    required this.palette,
    required this.label,
    required this.amount,
    required this.color,
  });

  final Palette palette;
  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: AppType.rowTitle(palette))),
        const SizedBox(width: Spacing.sm),
        Text(
          formatPeso(amount),
          style: AppType.amountSmall(palette).copyWith(color: color),
        ),
      ],
    );
  }
}
