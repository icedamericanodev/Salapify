import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money/accounts.dart';
import '../../core/money/currencies.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import '../shared/sheet_scaffold.dart';

/// Add or edit an account, from the modal at the foot of
/// src/components/AccountsScreen.tsx.
///
/// THERE IS NO DELETE HERE, and that is a decision rather than an omission.
/// Deleting an account is user data deletion, which CLAUDE.md reserves for the
/// founder, and it is the one action on this screen that cannot be undone by
/// retyping. It also orphans things: transactions carry an accountId, and the
/// Activity screen resolves it to a name. The proposal waiting on the founder
/// is in docs/reviews/accounts-tab.md. Until then a mistake is fixed by
/// editing, which loses nothing.
class AccountSheet extends StatefulWidget {
  const AccountSheet({
    super.key,
    required this.palette,
    required this.state,
    this.existing,
  });

  final Palette palette;
  final FinancialState state;

  /// The account being edited, or null when adding.
  final Account? existing;

  static Future<void> show(
    BuildContext context, {
    required Palette palette,
    required FinancialState state,
    Account? existing,
  }) {
    return SheetScaffold.show<void>(
      context: context,
      palette: palette,
      builder: (BuildContext ctx) =>
          AccountSheet(palette: palette, state: state, existing: existing),
    );
  }

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late final TextEditingController _limit;
  late final TextEditingController _rate;
  late final TextEditingController _number;
  late final TextEditingController _due;
  late final TextEditingController _statement;

  late AccountKind _kind;
  late String _institution;
  late CurrencyCode _currency;
  late ProfileEntity? _profile;
  late CardNetwork _network;
  late CardTier _tier;

  /// The institution list, ported from the prototype's own dropdown.
  static const List<String> institutions = <String>[
    'BPI',
    'BDO',
    'Metrobank',
    'RCBC',
    'UnionBank',
    'Security Bank',
    'PNB',
    'EastWest',
    'AUB',
    'LandBank',
    'PSBank',
    'China Bank',
    'GCash',
    'Maya',
    'MariBank',
    'GoTyme',
    'Tonik',
    'CIMB',
    'Komo',
    'DiskarTech',
    'Netbank',
    'UNO Digital Bank',
    'OwnBank',
    'TikTok',
    'Atome',
    'Pag-IBIG',
    'SSS',
    'Cash',
    'Internal Ledger',
    'Other',
  ];

  bool get _isEditing => widget.existing != null;
  bool get _isCard => _kind == AccountKind.credit || _kind == AccountKind.debit;

  @override
  void initState() {
    super.initState();
    final Account? e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _balance = TextEditingController(text: e == null ? '' : _plain(e.balance));
    _limit = TextEditingController(
      text: e?.creditLimit == null ? '' : _plain(e!.creditLimit!),
    );
    _rate = TextEditingController(
      text: e?.interestRate == null ? '' : _plain(e!.interestRate!),
    );
    _number = TextEditingController(text: e?.accountNumber ?? '');
    _due = TextEditingController(text: e?.dueDate ?? '');
    _statement = TextEditingController(text: e?.statementDate ?? '');
    _kind = e?.kind ?? AccountKind.cash;
    _institution = institutions.contains(e?.institution)
        ? e!.institution
        : (e == null ? 'GCash' : 'Other');
    _currency = e?.currency ?? CurrencyCode.php;
    _profile = e?.profile ?? ProfileEntity.personal;
    _network = e?.cardNetwork ?? CardNetwork.none;
    _tier = e?.cardTier ?? CardTier.regular;
  }

  /// A balance in the box the way somebody would type it, without the grouping
  /// commas a formatter adds. A field pre-filled with "48,500.00" cannot be
  /// parsed back by double.tryParse, so editing would silently reset it to
  /// zero.
  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _limit.dispose();
    _rate.dispose();
    _number.dispose();
    _due.dispose();
    _statement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final bool valid = _name.text.trim().isNotEmpty;

    return SheetScaffold(
      palette: p,
      icon: Icons.account_balance_wallet_outlined,
      title: _isEditing ? 'Edit account' : 'Add an account',
      subtitle: _isEditing
          ? 'Change anything here. Nothing you have logged moves.'
          : 'A wallet, a bank, a card, a loan. Everything you own or owe.',
      footer: PrimaryButton(
        palette: p,
        label: _isEditing ? 'Save changes' : 'Add account',
        icon: Icons.check,
        onTap: valid ? _save : null,
      ),
      // A Column, not a ListView. SheetScaffold already puts its child inside
      // a SingleChildScrollView with its own padding, and a scroll view inside
      // a scroll view has no height to work with: Flutter throws "viewport was
      // given an unlimited amount of vertical space".
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Label(palette: p, text: 'What kind of account'),
          _KindPicker(
            palette: p,
            selected: _kind,
            onSelect: (AccountKind k) => setState(() => _kind = k),
          ),
          const SizedBox(height: Spacing.lg),
          SheetField(
            palette: p,
            label: 'Name it',
            controller: _name,
            hint: 'BPI Payroll, GCash Main, Pag-IBIG MP2',
            keyboardType: TextInputType.text,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.lg),
          _Label(palette: p, text: 'Where it is held'),
          _Dropdown<String>(
            palette: p,
            value: _institution,
            items: <(String, String)>[
              for (final String i in institutions) (i, i),
            ],
            onChanged: (String v) => setState(() => _institution = v),
          ),
          const SizedBox(height: Spacing.lg),
          _Label(palette: p, text: 'Whose money this is'),
          _Dropdown<ProfileEntity?>(
            palette: p,
            value: _profile,
            items: const <(ProfileEntity?, String)>[
              (ProfileEntity.personal, 'Personal'),
              (ProfileEntity.household, 'Household'),
              (ProfileEntity.business, 'Business'),
              (ProfileEntity.sideHustle, 'Side hustle'),
              (null, 'Not sure, show it everywhere'),
            ],
            onChanged: (ProfileEntity? v) => setState(() => _profile = v),
          ),
          const SizedBox(height: Spacing.lg),
          _Label(palette: p, text: 'Currency'),
          _Dropdown<CurrencyCode>(
            palette: p,
            value: _currency,
            items: <(CurrencyCode, String)>[
              for (final CurrencyCode c in CurrencyCode.values)
                (c, '${c.wire}, ${currencyShortNames[c]}'),
            ],
            onChanged: (CurrencyCode v) => setState(() => _currency = v),
          ),
          if (_currency != CurrencyCode.php) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            Text(
              // Stays on the screen, not behind a dot. Somebody who believes
              // this rate is live would make a real decision on a number that
              // has not moved since it was typed into the source code.
              'Salapify works offline, so the peso equivalent uses a fixed '
              'rate and is an estimate only.',
              style: AppType.caption(p),
            ),
          ],
          const SizedBox(height: Spacing.lg),
          SheetField(
            palette: p,
            label: _kind == AccountKind.credit
                ? 'What you currently owe on it'
                : 'What is in it now',
            controller: _balance,
            hint: '0.00',
            prefix: '${currencySymbols[_currency]} ',
          ),
          if (_isCard) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            // FOUR DIGITS, ENFORCED, not merely requested.
            //
            // This field used to say "last four digits" and accept anything at
            // all, storing it verbatim. The card draws it masked, so somebody
            // who pasted a full sixteen digit number saw "•••• 4402" and quite
            // reasonably concluded that four digits were what got kept. The
            // file held the whole card number. The masking made the deception
            // better, not worse, which is why a label was never enough here.
            //
            // Refusing the fifth digit at the keyboard is the only version of
            // this that cannot be got around by not reading the label.
            SheetField(
              palette: p,
              label: 'Last four digits, if you want them shown',
              controller: _number,
              hint: '8819',
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            _Label(palette: p, text: 'Card scheme'),
            _Dropdown<CardNetwork>(
              palette: p,
              value: _network,
              items: const <(CardNetwork, String)>[
                (CardNetwork.none, 'None or not shown'),
                (CardNetwork.visa, 'Visa'),
                (CardNetwork.mastercard, 'Mastercard'),
                (CardNetwork.amex, 'American Express'),
                (CardNetwork.jcb, 'JCB'),
              ],
              onChanged: (CardNetwork v) => setState(() => _network = v),
            ),
            const SizedBox(height: Spacing.lg),
            _Label(palette: p, text: 'How the card looks'),
            _Dropdown<CardTier>(
              palette: p,
              value: _tier,
              items: const <(CardTier, String)>[
                (CardTier.regular, 'Regular or classic'),
                (CardTier.gold, 'Gold'),
                (CardTier.platinum, 'Platinum'),
                (CardTier.black, 'Black or elite'),
                (CardTier.custom, 'Plain'),
              ],
              onChanged: (CardTier v) => setState(() => _tier = v),
            ),
          ],
          if (_kind == AccountKind.credit) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            SheetField(
              palette: p,
              label: 'Credit limit',
              controller: _limit,
              hint: '40000',
              prefix: '${currencySymbols[_currency]} ',
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'Without this, Salapify will not guess how much of your limit '
              'you are using.',
              style: AppType.caption(p),
            ),
          ],
          if (_kind == AccountKind.credit ||
              _kind == AccountKind.loan ||
              _kind == AccountKind.mortgage) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            SheetField(
              palette: p,
              label: 'When it is due',
              controller: _due,
              hint: 'Oct 3, or the 15th',
              keyboardType: TextInputType.text,
            ),
          ],
          // THE STATEMENT DATE, which until now no screen in the app could
          // set. The field has round tripped through the model, the codec and
          // the backup file since the first build, and the only record that
          // ever had one was the sample card, because the seed writes it
          // directly. A person could not.
          //
          // It is asked for only on a credit card. A loan and a mortgage have
          // a due date and no statement, so offering the box there would
          // invite somebody to fill in a cycle that does not exist.
          if (_kind == AccountKind.credit) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            SheetField(
              palette: p,
              label: 'When the bill closes each month',
              controller: _statement,
              hint: 'The 10th',
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              // Two figures, and the one line needed to read them. What the
              // cutoff MEANS is behind the "i" on the card itself.
              'Your bank closes the month on this day and works out what you '
              'owe. It is printed on your statement, usually near the due '
              'date.',
              style: AppType.caption(p),
            ),
          ],
          const SizedBox(height: Spacing.lg),
          SheetField(
            palette: p,
            label: 'Interest a year, if it earns or charges any',
            controller: _rate,
            hint: '6.0',
          ),
          // A LINE THAT USED TO BE HERE IS GONE, and its own comment is why:
          // "It is removed the day storage lands, and not a day before."
          //
          // It read "Nothing is saved to your phone yet, so this lasts until
          // you close the app." Storage landed. `main.dart` builds the app
          // with a FileSnapshotStore and every edit on this sheet is written
          // to disk, so the sentence had become false in the one direction a
          // finance app cannot afford: it tells somebody their records are
          // about to vanish when they are not, and the reasonable response
          // to reading it is to stop bothering to enter anything.
        ],
      ),
    );
  }

  void _save() {
    final String name = _name.text.trim();
    if (name.isEmpty) return;

    final Account account = Account(
      id: widget.existing?.id ?? 'acc_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      kind: _kind,
      institution: _institution,
      balance: double.tryParse(_balance.text.trim().replaceAll(',', '')) ?? 0,
      // An existing account keeps the monogram it has, because a stored one is
      // a deliberate label (the MP2 fund is MP2, not the generic INV this
      // would derive). A new one gets the derived default.
      monogram:
          widget.existing?.monogram ??
          computeMonogram(_institution, _kind, name),
      currency: _currency,
      profile: _profile,
      creditLimit: _kind == AccountKind.credit
          ? double.tryParse(_limit.text.trim().replaceAll(',', ''))
          : widget.existing?.creditLimit,
      interestRate: double.tryParse(_rate.text.trim().replaceAll(',', '')),
      // Clamped again HERE, not only at the keyboard. The formatter above
      // governs what can be typed, and this controller is also filled
      // programmatically when editing an existing account, which no formatter
      // ever sees. An account recorded in full before this rule existed would
      // otherwise be written back in full on the next save.
      accountNumber: cardTailForStorage(_number.text),
      dueDate: _due.text.trim().isEmpty ? null : _due.text.trim(),
      statementDate: _statement.text.trim().isEmpty
          ? null
          : _statement.text.trim(),
      cardNetwork: _isCard ? _network : CardNetwork.none,
      cardTier: _isCard ? _tier : CardTier.regular,
      notes: widget.existing?.notes,
    );

    if (_isEditing) {
      widget.state.updateAccount(account);
    } else {
      widget.state.addAccount(account);
    }

    Navigator.of(context).pop();
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.palette, required this.text});

  final Palette palette;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Spacing.xs),
    child: Text(text, style: AppType.label(palette)),
  );
}

/// The ten kinds, split into what you own and what you owe, so somebody adding
/// a loan is not hunting through a flat list of ten.
class _KindPicker extends StatelessWidget {
  const _KindPicker({
    required this.palette,
    required this.selected,
    required this.onSelect,
  });

  final Palette palette;
  final AccountKind selected;
  final ValueChanged<AccountKind> onSelect;

  static const List<(AccountKind, String)> _assets = <(AccountKind, String)>[
    (AccountKind.cash, 'Cash'),
    (AccountKind.bank, 'Bank'),
    (AccountKind.gcash, 'GCash'),
    (AccountKind.maya, 'Maya'),
    (AccountKind.debit, 'Debit card'),
    (AccountKind.investment, 'Investment'),
    (AccountKind.receivable, 'Owed to me'),
  ];

  static const List<(AccountKind, String)> _liabilities =
      <(AccountKind, String)>[
        (AccountKind.credit, 'Credit card'),
        (AccountKind.loan, 'Loan'),
        (AccountKind.mortgage, 'Mortgage'),
      ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Things you own', style: AppType.caption(palette)),
        const SizedBox(height: Spacing.xs),
        _row(_assets),
        const SizedBox(height: Spacing.md),
        Text('Things you owe', style: AppType.caption(palette)),
        const SizedBox(height: Spacing.xs),
        _row(_liabilities),
      ],
    );
  }

  Widget _row(List<(AccountKind, String)> options) => Wrap(
    spacing: Spacing.sm,
    runSpacing: Spacing.sm,
    children: <Widget>[
      for (final (AccountKind k, String label) in options)
        Semantics(
          button: true,
          selected: selected == k,
          child: InkWell(
            onTap: () => onSelect(k),
            borderRadius: BorderRadius.circular(Radii.pill),
            child: Container(
              // NO `alignment` here. A Container with an alignment and no
              // width expands to fill everything it is offered, so each pill
              // became a full width row and ten of them became ten rows.
              // The same trap stacked the Reports period picker once already.
              // The padding and the minHeight give the size; the text centres
              // itself inside them.
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                color: selected == k ? palette.accent : palette.surface,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(
                  color: selected == k ? palette.accent : palette.border,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected == k
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

/// A plain dropdown in Salapify's own skin.
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.palette,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final Palette palette;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: palette.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: palette.surface,
          iconEnabledColor: palette.textMuted,
          style: AppType.rowTitle(palette).copyWith(fontSize: 15),
          items: <DropdownMenuItem<T>>[
            for (final (T v, String label) in items)
              DropdownMenuItem<T>(value: v, child: Text(label)),
          ],
          onChanged: (T? v) {
            if (v != null || null is T) onChanged(v as T);
          },
        ),
      ),
    );
  }
}
