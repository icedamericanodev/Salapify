// Year-end tax check for employees: am I getting a refund, or do I still owe?
//
// Every December an employer trues up the whole year's tax, and steady monthly
// withholding rarely matches the real annual tax once a 13th month, a bonus,
// or a mid-year start are counted. This estimates the annual tax due
// and compares it against what was already withheld.
//
// Every peso comes from money/phtax.dart, which is golden locked to the RN
// engine. This screen collects five numbers and reads the answer back. It is
// an estimate, not a Form 2316, and it says so where it cannot be missed
// rather than in fine print at the bottom.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/debtmath.dart' show formatMoneyText;
import '../money/phtax.dart';
import '../theme.dart';
import '../typography.dart';
import '../widgets/section.dart';

class YearEndTaxScreen extends StatefulWidget {
  final SalapifyStore store;
  const YearEndTaxScreen({super.key, required this.store});

  @override
  State<YearEndTaxScreen> createState() => _YearEndTaxScreenState();
}

class _YearEndTaxScreenState extends State<YearEndTaxScreen> {
  final _basic = TextEditingController();
  final _allowance = TextEditingController();
  final _months = TextEditingController();
  final _bonuses = TextEditingController();
  final _withheld = TextEditingController();

  @override
  void dispose() {
    for (final c in [_basic, _allowance, _months, _bonuses, _withheld]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Typed text to a number, NaN when it cannot be read, null when empty.
  ///
  /// The distinction is the whole point. This used to map anything unreadable
  /// to zero silently, so pasting "₱12,500" from a payslip made the screen
  /// announce "LIKELY STILL OWED" to somebody who had actually overpaid, and
  /// typing "6 months" in the months field became one month and overstated a
  /// refund twelvefold. A number the app cannot read has to be said out loud,
  /// never guessed at.
  num? _read(TextEditingController c) {
    final raw = c.text.replaceAll(RegExp(r'[, ]'), '').trim();
    if (raw.isEmpty) return null;
    final v = num.tryParse(raw);
    if (v == null || !v.isFinite || v < 0) return double.nan;
    return v;
  }

  bool _unreadable(TextEditingController c) => _read(c)?.isNaN ?? false;

  /// The value handed to the engine. Unreadable contributes zero, which is
  /// only ever reached after the screen has said the field is unreadable and
  /// withheld the verdict.
  num _num(TextEditingController c) {
    final v = _read(c);
    return (v == null || v.isNaN) ? 0 : v;
  }

  @override
  Widget build(BuildContext context) {
    final basic = _num(_basic);
    final monthsRaw = _months.text.trim();
    final result = annualizeCompensation(
      basic,
      taxableAllowance: _num(_allowance),
      monthsWorked: monthsRaw.isEmpty ? null : _num(_months),
      bonuses: _num(_bonuses),
      taxWithheld: _num(_withheld),
    );
    // The verdict waits for the number it is a verdict ABOUT.
    //
    // It used to appear the moment a salary was typed, with withheld
    // defaulting to zero, so every user's first sight of this screen was
    // "LIKELY STILL OWED" and a peso figure: a false statement of a tax
    // position, shown by default, to everyone. The breakdown can show early.
    // The verdict cannot.
    final withheldEntered =
        _withheld.text.trim().isNotEmpty && !_unreadable(_withheld);
    final badFields = [
      if (_unreadable(_basic)) 'monthly basic pay',
      if (_unreadable(_allowance)) 'allowance',
      if (_unreadable(_months)) 'months worked',
      if (_unreadable(_bonuses)) 'bonuses and benefits',
      if (_unreadable(_withheld)) 'tax withheld',
    ];
    final showResult = basic > 0;
    final difference = result['difference'] as double;
    final isRefund = result['isRefund'] as bool;

    return Scaffold(
      appBar: AppBar(title: Text('Year-end tax check')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Every December your employer works out the whole year at once. '
              'Steady monthly tax rarely matches that once a 13th month, a '
              'bonus, or a mid-year start are counted, so most people are '
              'owed a little back or owe a little more. There is one pay '
              'field here, so if you had a raise, use your average monthly '
              'pay for the year.',
              style: AppText.label.w4
                  .tint(Barako.textSecondary)
                  .copyWith(height: 1.5),
            ),
            const SizedBox(height: Gap.lg),
            _label('Monthly basic pay'),
            _field(_basic, hint: 'e.g. 25000'),
            _label('Monthly taxable allowance'),
            _field(_allowance, hint: 'Leave empty if none'),
            _label('Months worked this year'),
            _field(_months, hint: '12 if you worked the whole year'),
            _label('13th month, bonuses and other benefits, for the year'),
            _field(_bonuses, hint: 'Including de minimis above its own cap'),
            _label('Tax already withheld, for the year'),
            _field(_withheld, hint: 'From your payslips'),
            const SizedBox(height: Gap.xl),
            if (badFields.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Barako.card,
                  borderRadius: BorderRadius.circular(Radii.card),
                  border: Border.all(color: Barako.warningStrong),
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    badFields.length == 1
                        ? 'That ${badFields.first} is not a number I can '
                              'read, so there is no estimate yet. Use digits '
                              'only, like 25000.'
                        : 'These are not numbers I can read: '
                              '${badFields.join(', ')}. Use digits only, like '
                              '25000.',
                    style: AppText.label.w4
                        .tint(Barako.warningStrong)
                        .copyWith(height: 1.5),
                  ),
                ),
              )
            else if (!showResult)
              Text(
                'Enter your monthly basic pay to see the estimate.',
                style: AppText.small.tint(Barako.muted),
              )
            else ...[
              if (!withheldEntered)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Barako.card,
                    borderRadius: BorderRadius.circular(Radii.card),
                    border: Border.all(color: Barako.border),
                  ),
                  child: Text(
                    'Enter the tax withheld from your payslips to see whether '
                    'you are due a refund or still owe. Until then the '
                    'breakdown below shows what the year asks for.',
                    style: AppText.label.w4
                        .tint(Barako.textSecondary)
                        .copyWith(height: 1.5),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Barako.card,
                    borderRadius: BorderRadius.circular(Radii.card),
                    border: Border.all(
                      color: difference == 0
                          ? Barako.border
                          : isRefund
                          ? Barako.primary
                          : Barako.warningStrong,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Kicker(
                        difference == 0
                            ? 'YOU ARE SQUARE'
                            : isRefund
                            ? 'LIKELY REFUND'
                            : 'LIKELY STILL OWED',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatMoneyText(difference.abs()),
                        style: TextStyle(
                          fontFamily: Barako.displayFont,
                          color: difference == 0
                              ? Barako.text
                              : isRefund
                              ? Barako.primaryText
                              : Barako.warningStrong,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        difference == 0
                            ? 'What was withheld matches what the year asks '
                                  'for, so there should be nothing more to pay '
                                  'and nothing coming back.'
                            : isRefund
                            ? 'You paid more through the year than the annual '
                                  'computation asks for, so this should come '
                                  'back to you.'
                            : 'The annual computation asks for more than was '
                                  'withheld, so expect this to be deducted.',
                        style: AppText.small.copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Gap.lg),
              Kicker('HOW THAT ADDS UP'),
              const SizedBox(height: 8),
              _row('Regular pay, taxable', result['regularTaxable'] as double),
              _row(
                'Benefits above the ${formatMoneyText(bonusTaxFreeCeiling)} '
                'tax free ceiling',
                result['bonusTaxable'] as double,
              ),
              _row('Taxable for the year', result['annualTaxable'] as double),
              _row('Annual tax due', result['annualTaxDue'] as double),
              _row('Tax already withheld', result['taxWithheld'] as double),
              const SizedBox(height: Gap.lg),
              Text(
                'An estimate using the ${result['ratesYear']} tables and '
                '${result['monthsWorked']} months of work. It is not your '
                'Form 2316: your employer counts things this cannot see, like '
                'a previous employer that year or benefits treated '
                'differently. Use it to know roughly what is coming, then '
                'check the real thing when it arrives.',
                style: AppText.caption.copyWith(height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(label, style: AppText.small)),
        const SizedBox(width: 12),
        Text(formatMoneyText(value), style: AppText.label.w7),
      ],
    ),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(t, style: AppText.caption),
  );

  Widget _field(TextEditingController c, {required String hint}) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() {}),
    style: AppText.bodyLg,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Barako.faint),
      filled: true,
      fillColor: Barako.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        borderSide: BorderSide(color: Barako.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        borderSide: BorderSide(color: Barako.border),
      ),
    ),
  );
}
