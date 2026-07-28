// Year-end tax check for employees: am I getting a refund, or do I still owe?
//
// Every December an employer trues up the whole year's tax, and steady monthly
// withholding rarely matches the real annual tax once a 13th month, a bonus, a
// raise, or a mid-year start are counted. This estimates the annual tax due
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

  /// Typed text to a number the engine can use: commas and spaces out, blank
  /// and junk to zero. The engine clamps and rounds from there, so this stays
  /// a reader rather than a second place where money rules live.
  num _num(TextEditingController c) {
    final raw = c.text.replaceAll(RegExp(r'[, ]'), '').trim();
    if (raw.isEmpty) return 0;
    final v = num.tryParse(raw);
    return (v == null || !v.isFinite || v < 0) ? 0 : v;
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
    final showResult = basic > 0;
    final difference = result['difference'] as double;
    final isRefund = result['isRefund'] as bool;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Year-end tax check',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Every December your employer works out the whole year at once. '
              'Steady monthly tax rarely matches that once a 13th month, a '
              'bonus, a raise, or a mid-year start are counted, so most '
              'people are owed a little back or owe a little more.',
              style: TextStyle(
                color: Barako.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: Gap.lg),
            _label('Monthly basic pay'),
            _field(_basic, hint: 'e.g. 25000'),
            _label('Monthly taxable allowance'),
            _field(_allowance, hint: 'Leave empty if none'),
            _label('Months worked this year'),
            _field(_months, hint: '12 if you worked the whole year'),
            _label('Bonuses and 13th month, for the year'),
            _field(_bonuses, hint: 'Total for the year'),
            _label('Tax already withheld, for the year'),
            _field(_withheld, hint: 'From your payslips'),
            const SizedBox(height: Gap.xl),
            if (!showResult)
              Text(
                'Enter your monthly basic pay to see the estimate.',
                style: TextStyle(color: Barako.muted, fontSize: 13),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Barako.card,
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: Border.all(
                    color: isRefund ? Barako.primary : Barako.warningStrong,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Kicker(isRefund ? 'LIKELY REFUND' : 'LIKELY STILL OWED'),
                    const SizedBox(height: 6),
                    Text(
                      formatMoneyText(difference.abs()),
                      style: TextStyle(
                        fontFamily: Barako.displayFont,
                        color: isRefund
                            ? Barako.primaryText
                            : Barako.warningStrong,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isRefund
                          ? 'You paid more through the year than the annual '
                                'computation asks for, so this should come '
                                'back to you.'
                          : 'The annual computation asks for more than was '
                                'withheld, so expect this to be deducted.',
                      style: TextStyle(
                        color: Barako.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.lg),
              Kicker('HOW THAT ADDS UP'),
              const SizedBox(height: 8),
              _row('Regular pay, taxable', result['regularTaxable'] as double),
              _row(
                'Bonuses above the ${formatMoneyText(bonusTaxFreeCeiling)} '
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
                style: TextStyle(
                  color: Barako.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
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
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Barako.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          formatMoneyText(value),
          style: TextStyle(
            color: Barako.text,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(t, style: TextStyle(color: Barako.muted, fontSize: 12)),
  );

  Widget _field(TextEditingController c, {required String hint}) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() {}),
    style: TextStyle(color: Barako.text, fontSize: 16),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Barako.faint),
      filled: true,
      fillColor: Barako.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: Barako.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: Barako.border),
      ),
    ),
  );
}
