import '../../core/money/money.dart';
import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/loan.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../shared/sheet_scaffold.dart';
import 'amortization_table.dart';

/// Add a debt, ported from archive/prototype-google-ai-studio/src/components/AddDebtModal.tsx, with the payoff
/// schedule from BankAmortizationTable.tsx folded in.
///
/// The prototype keeps these apart: you record a debt in one modal and look at
/// an amortization table in another. Putting the schedule under the form means
/// the instalment appears while the amount is still being typed, which is when
/// somebody is actually deciding whether they can afford it.
/// What Save debt produced: the debt, and the account money moved through
/// when it moved (D31, D32.3). [accountId] null means no money moved now.
class AddDebtResult {
  const AddDebtResult(this.debt, this.accountId);

  final Debt debt;
  final String? accountId;
}

class AddDebtSheet extends StatefulWidget {
  const AddDebtSheet({
    super.key,
    required this.palette,
    this.accounts = const <Account>[],
  });

  final Palette palette;

  /// The accounts money can be lent from or borrowed into. Empty means the
  /// question is not asked, so a person with no accounts can still record
  /// who owes whom.
  final List<Account> accounts;

  static Future<AddDebtResult?> show(
    BuildContext context,
    Palette palette, {
    List<Account> accounts = const <Account>[],
  }) {
    return SheetScaffold.show<AddDebtResult>(
      context: context,
      palette: palette,
      builder: (BuildContext context) =>
          AddDebtSheet(palette: palette, accounts: accounts),
    );
  }

  @override
  State<AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends State<AddDebtSheet> {
  final TextEditingController _person = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _dueDate = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _installments = TextEditingController(text: '6');
  final TextEditingController _rate = TextEditingController(text: '0');
  final TextEditingController _minimum = TextEditingController();

  DebtDirection _direction = DebtDirection.iOwe;
  bool _scheduled = false;

  /// Where the money went or came from, or [_noMoney]. Null until chosen.
  ///
  /// ASKED, NOT DEFAULTED (D31). A default account would move money nobody
  /// chose to move, and a default of "no money moved" would quietly keep the
  /// old behaviour where lending 2,000 left GCash untouched. One tap either
  /// way, and the caption under it says what that tap will do.
  String? _money;
  static const String _noMoney = '__none__';

  List<Account> get _moneyAccounts =>
      widget.accounts.where((Account a) => a.isLiquid).toList();

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _dueDate.dispose();
    _notes.dispose();
    _installments.dispose();
    _rate.dispose();
    _minimum.dispose();
    super.dispose();
  }

  /// Whether to ask what this debt costs every month.
  ///
  /// ONLY for money you owe, and only when it has no instalment schedule.
  ///
  /// Not for a debt owed TO you, because that is not an obligation you have
  /// to find money for. Not for a scheduled debt either, because the months
  /// already answer the question: `Debt.monthlyMinimum` divides what is left
  /// by the instalments left, and asking a second time invites two answers
  /// that disagree.
  ///
  /// What is left is exactly the case the field exists for: a credit card or
  /// a revolving loan, which has a real monthly minimum and no fixed end. And
  /// family utang, which has neither, where leaving it empty is the right
  /// answer and the caption says so.
  bool get _asksMinimum => _direction == DebtDirection.iOwe && !_scheduled;

  /// Null when the box is empty, which is NOT the same as zero.
  ///
  /// Empty means nobody has said, and nothing is reserved. A typed zero means
  /// this genuinely costs nothing a month, and is respected. See
  /// `Debt.minimumPayment`.
  Money? get _minimumValue {
    if (!_asksMinimum) return null;
    final String raw = _minimum.text.replaceAll(',', '').trim();
    if (raw.isEmpty) return null;
    final double? parsed = double.tryParse(raw);
    // tryFromDouble, NOT fromDouble. The strict one throws on a figure no
    // peso balance can reach, and the throw escaped this sheet's Save button
    // with no message at all. See `moneyInput` in sheet_scaffold.dart.
    return parsed == null ? null : Money.tryFromDouble(parsed);
  }

  /// True when the box has something in it that is not a figure.
  ///
  /// SILENCE WAS THE BUG. This used to resolve to null, which means "nobody
  /// said a minimum", so a debt typed as "1.500.00" saved with no minimum at
  /// all, no error, and the caption the person had just read promising that
  /// Salapify would hold nothing back. They believe they entered 1,500 a
  /// month; Salapify reserves zero, for as long as the debt exists. Save is
  /// now refused and the reason is on the screen.
  bool get _minimumUnreadable {
    if (!_asksMinimum) return false;
    if (_minimum.text.trim().isEmpty) return false;
    return _minimumValue == null;
  }

  double get _amountValue =>
      double.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0;
  int get _termMonths => int.tryParse(_installments.text.trim()) ?? 0;
  double get _rateValue => double.tryParse(_rate.text.trim()) ?? 0;

  /// Save is refused until there is a name and a positive amount. A debt with
  /// neither is a row that can never be reconciled against anything. It is
  /// also refused while the minimum box holds something unreadable, rather
  /// than saving it as nothing: see [_minimumUnreadable].
  bool get _canSave =>
      _person.text.trim().isNotEmpty &&
      _amountValue > 0 &&
      !_minimumUnreadable &&
      (_moneyAccounts.isEmpty || _money != null);

  /// What the money question's answer will do, said before Save.
  String? get _moneyCaption {
    if (_moneyAccounts.isEmpty || _money == null) return null;
    final bool owed = _direction == DebtDirection.owedToMe;
    if (_money == _noMoney) {
      return owed
          ? 'Nothing leaves your accounts. Use this for money lent before '
                'you started using Salapify.'
          : 'Nothing arrives in your accounts. Use this for a credit card, '
                'something bought on instalments, or a loan from before '
                'Salapify.';
    }
    final String name = _moneyAccounts
        .firstWhere(
          (Account a) => a.id == _money,
          orElse: () => _moneyAccounts.first,
        )
        .name;
    final String amount = _amountValue > 0
        ? formatPeso(_amountValue)
        : 'The amount';
    return owed
        ? '$amount leaves $name now. When they pay you back it returns, and '
              'neither counts as spending or income.'
        : '$amount arrives in $name now. Paying it back moves it out again, '
              'and that is not counted as spending.';
  }

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      AddDebtResult(
        Debt(
          id: 'debt_${DateTime.now().millisecondsSinceEpoch}',
          person: _person.text.trim(),
          direction: _direction,
          totalAmount: Money.fromDouble(_amountValue),
          paidAmount: Money.pesos(0),
          isSettled: false,
          dueDate: _dueDate.text.trim().isEmpty ? null : _dueDate.text.trim(),
          // EVERYTHING THE FORM ASKS FOR IS NOW KEPT.
          //
          // This constructor used to stop at dueDate, so the note, the
          // Installments choice and the term were collected, rendered, used to
          // draw a full amortisation preview, and then thrown away on save. A
          // debt entered as a 6 month plan came back as "Flexible, pay when
          // you can" and the note never appeared, on a card that renders notes
          // whenever they exist.
          //
          // Nothing new is stored: debtToJson already writes notes,
          // scheduleType and installmentTotal, and debtKeys already declares
          // all three. The form was simply not filling them in.
          schedule: _scheduled ? DebtSchedule.scheduled : DebtSchedule.flexible,
          // The counter starts at the first payment, which is what
          // applyDebtPayment increments. Null on a flexible debt, which has no
          // instalments to count.
          installmentCurrent: _scheduled && _termMonths > 0 ? 0 : null,
          installmentTotal: _scheduled && _termMonths > 0 ? _termMonths : null,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          // Null unless the person typed one, so a debt to a relative reserves
          // nothing against Safe to Spend. See Debt.monthlyMinimum.
          minimumPayment: _minimumValue,
        ),
        _money == null || _money == _noMoney ? null : _money,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final bool owed = _direction == DebtDirection.owedToMe;

    return SheetScaffold(
      palette: p,
      icon: Icons.handshake_outlined,
      title: 'Add a debt',
      subtitle: 'Both directions: what you owe, and what is owed to you',
      footer: PrimaryButton(
        palette: p,
        label: 'Save debt',
        icon: Icons.check,
        onTap: _canSave ? _save : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Which way does it go', style: AppType.label(p)),
          const SizedBox(height: Spacing.xs),
          SegmentedChoice<DebtDirection>(
            palette: p,
            selected: _direction,
            options: const <(DebtDirection, String)>[
              (DebtDirection.iOwe, 'I owe them'),
              (DebtDirection.owedToMe, 'They owe me'),
            ],
            onSelect: (DebtDirection d) => setState(() => _direction = d),
          ),
          const SizedBox(height: Spacing.md),
          SheetField(
            palette: p,
            label: owed ? 'Who owes you' : 'Who you owe',
            controller: _person,
            hint: 'e.g. Home Credit, Mom, Kuya Mark',
            keyboardType: TextInputType.text,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.md),
          SheetField(
            palette: p,
            label: 'Amount',
            controller: _amount,
            hint: '0.00',
            prefix: '₱ ',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.md),
          if (_moneyAccounts.isNotEmpty) ...<Widget>[
            DropdownButtonFormField<String>(
              key: const Key('debt-money'),
              initialValue: _money,
              isExpanded: true,
              hint: Text('Choose one', style: AppType.body(p)),
              decoration: InputDecoration(
                labelText: owed
                    ? 'Lent from which account'
                    : 'Borrowed into which account',
                labelStyle: AppType.label(p),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
              ),
              items: <DropdownMenuItem<String>>[
                for (final Account a in _moneyAccounts)
                  DropdownMenuItem<String>(
                    value: a.id,
                    child: Text(a.name, style: AppType.body(p)),
                  ),
                DropdownMenuItem<String>(
                  value: _noMoney,
                  child: Text('No money moved now', style: AppType.body(p)),
                ),
              ],
              onChanged: (String? v) => setState(() => _money = v),
            ),
            if (_moneyCaption != null) ...<Widget>[
              const SizedBox(height: Spacing.xs),
              Text(_moneyCaption!, style: AppType.caption(p)),
            ],
            const SizedBox(height: Spacing.md),
          ],
          SheetField(
            palette: p,
            label: 'Due date (optional)',
            controller: _dueDate,
            hint: 'e.g. Sep 25',
            keyboardType: TextInputType.text,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.md),
          Text('How it gets paid', style: AppType.label(p)),
          const SizedBox(height: Spacing.xs),
          SegmentedChoice<bool>(
            palette: p,
            selected: _scheduled,
            options: const <(bool, String)>[
              (false, 'Flexible'),
              (true, 'Installments'),
            ],
            onSelect: (bool s) => setState(() => _scheduled = s),
          ),
          // WHAT IT COSTS EACH MONTH, asked only where the answer does
          // something. See `_asksMinimum`.
          if (_asksMinimum) ...<Widget>[
            const SizedBox(height: Spacing.md),
            SheetField(
              key: const Key('debt-minimum'),
              palette: p,
              label: 'What you must pay each month (optional)',
              controller: _minimum,
              hint: '0.00',
              prefix: '₱ ',
              onChanged: (_) => setState(() {}),
            ),
            // The refusal is SHOWN, not just enforced. Save greying out with
            // no reason beside it is the same silence in a different shape.
            if (_minimumUnreadable) ...<Widget>[
              const SizedBox(height: Spacing.xs),
              Text(
                'That is not an amount Salapify can read. Use digits and one '
                'dot, like 1500 or 1500.50.',
                key: const Key('debt-minimum-problem'),
                style: AppType.caption(p).copyWith(color: p.negative),
              ),
            ],
            const SizedBox(height: Spacing.xs),
            Text(
              // BOTH SENTENCES MATTER. The first tells somebody with a credit
              // card why they would fill it in. The second tells somebody
              // with family utang that empty is the right answer, which is
              // the whole point: Salapify used to hold back eight percent of
              // every debt, so money owed to a relative quietly cost them
              // spending money every cycle for an obligation that does not
              // exist.
              'For a credit card or a loan with a monthly minimum. Leave it '
              'empty for money you owe family or friends, and Salapify will '
              'hold nothing back for it.',
              style: AppType.caption(p),
            ),
          ],
          if (_scheduled) ...<Widget>[
            const SizedBox(height: Spacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: SheetField(
                    palette: p,
                    label: 'Number of months',
                    controller: _installments,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: SheetField(
                    palette: p,
                    label: 'Interest % a year',
                    controller: _rate,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            if (_amountValue > 0 && _termMonths > 0)
              AmortizationTable(
                palette: p,
                result: calculateAmortization(
                  principal: _amountValue,
                  annualInterestRate: _rateValue,
                  termMonths: _termMonths,
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: Text(
                  'Enter an amount and a number of months to see the payoff '
                  'schedule.',
                  style: AppType.caption(p),
                ),
              ),
          ],
          const SizedBox(height: Spacing.md),
          SheetField(
            palette: p,
            label: 'Note (optional)',
            controller: _notes,
            hint: 'e.g. Concert ticket split, gadget upgrade',
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: Spacing.md),
          if (_amountValue > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: owed ? p.positiveSoft : p.accentSoft,
                borderRadius: BorderRadius.circular(Radii.control),
              ),
              child: Text(
                owed
                    ? '${formatPeso(_amountValue)} will be added to what is owed to you.'
                    : '${formatPeso(_amountValue)} will be added to what you owe.',
                style: AppType.body(p).copyWith(
                  color: owed ? p.positive : p.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
