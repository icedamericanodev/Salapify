import '../../core/money/money.dart';
import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/loan.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../shared/sheet_scaffold.dart';
import 'amortization_table.dart';

/// Add a debt, ported from src/components/AddDebtModal.tsx, with the payoff
/// schedule from BankAmortizationTable.tsx folded in.
///
/// The prototype keeps these apart: you record a debt in one modal and look at
/// an amortization table in another. Putting the schedule under the form means
/// the instalment appears while the amount is still being typed, which is when
/// somebody is actually deciding whether they can afford it.
class AddDebtSheet extends StatefulWidget {
  const AddDebtSheet({super.key, required this.palette, this.onSave});

  final Palette palette;
  final ValueChanged<Debt>? onSave;

  static Future<Debt?> show(BuildContext context, Palette palette) {
    return SheetScaffold.show<Debt>(
      context: context,
      palette: palette,
      builder: (BuildContext context) => AddDebtSheet(palette: palette),
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

  DebtDirection _direction = DebtDirection.iOwe;
  bool _scheduled = false;

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _dueDate.dispose();
    _notes.dispose();
    _installments.dispose();
    _rate.dispose();
    super.dispose();
  }

  double get _amountValue =>
      double.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0;
  int get _termMonths => int.tryParse(_installments.text.trim()) ?? 0;
  double get _rateValue => double.tryParse(_rate.text.trim()) ?? 0;

  /// Save is refused until there is a name and a positive amount. A debt with
  /// neither is a row that can never be reconciled against anything.
  bool get _canSave => _person.text.trim().isNotEmpty && _amountValue > 0;

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(
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
