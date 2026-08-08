// Loan calculator: the RN tool adapted to Flutter on the golden-ported
// loan math. Its one job is honesty: show the real monthly payment and the
// TRUE effective rate, so a lender's friendly add-on quote cannot hide an
// effective rate roughly double it. All estimates; real contracts add fees
// and penalties, and the copy says so.

import 'package:flutter/material.dart';

import '../money/loan.dart';
import '../theme.dart';
import '../typography.dart';
import 'overview.dart' show formatMoney;

class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  final amount = TextEditingController();
  final term = TextEditingController();
  final rate = TextEditingController();
  String termUnit = 'months';
  String rateBasis = 'monthly';
  String method = 'diminishing';
  bool showSchedule = false;

  @override
  void dispose() {
    amount.dispose();
    term.dispose();
    rate.dispose();
    super.dispose();
  }

  double _parse(String s) {
    final cleaned = s.replaceAll(RegExp(r'[, ]'), '');
    if (cleaned.isEmpty) return 0;
    final n = double.tryParse(cleaned);
    return (n == null || !n.isFinite) ? 0 : n;
  }

  String _m(num n) => formatMoney((n + 0.5).floorToDouble());

  String _pct(num x) => '${(x * 100).toStringAsFixed(2)}%';

  Widget _seg(
    List<(String, String)> options,
    String value,
    void Function(String) onChange,
  ) {
    return Wrap(
      spacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o.$2),
            selected: value == o.$1,
            onSelected: (_) => setState(() => onChange(o.$1)),
            selectedColor: Barako.primary,
            backgroundColor: Barako.background,
            labelStyle: AppText.caption.w6.tint(
              value == o.$1 ? Barako.onPrimary : Barako.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(text, style: AppText.caption.w7),
  );

  @override
  Widget build(BuildContext context) {
    final amountNum = _parse(amount.text);
    final termNum = _parse(term.text);
    final rateNum = _parse(rate.text);
    // Clamp in DOUBLE space before toInt: a pasted 2e307 in years mode
    // multiplies to Infinity, and Infinity.toInt() throws where the RN
    // screen's Math.min clamp survives. Same result, no crash.
    final rawMonthsD = termUnit == 'years'
        ? (termNum * 12 + 0.5).floorToDouble()
        : (termNum + 0.5).floorToDouble();
    final termClamped = rawMonthsD > maxMonths;
    // clamp handles both infinities: +Infinity lands on the cap like RN's
    // Math.min, -Infinity lands on zero so a pasted negative monster shows
    // only the negative warning, never a result card beneath it.
    final months = rawMonthsD.clamp(0, maxMonths.toDouble()).toInt();

    final ready = amountNum > 0 && months >= 1 && rateNum >= 0;
    final badInput = amountNum < 0 || termNum < 0 || rateNum < 0;
    final needTerm =
        !ready && !badInput && amountNum > 0 && rateNum >= 0 && rawMonthsD < 1;
    final addon = method == 'addon';

    final r = ready
        ? loanSummary(
            amountNum,
            rateNum,
            months,
            method: method,
            rateBasis: rateBasis,
          )
        : null;
    // The payoff nugget uses the EXACT rate, not the display-rounded
    // quotedMonthlyRate, or its balance would contradict the schedule row
    // shown on the same screen (bank officer finding).
    final exactMonthlyRate = rateBasis == 'annual'
        ? rateNum / 100 / 12
        : rateNum / 100;
    final payoff = r != null
        ? payoffSaving(amountNum, exactMonthlyRate, months, months ~/ 2)
        : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Loan calculator',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'See the real monthly payment and the true cost of a loan. If your lender quoted an add-on rate, this shows what it really works out to.',
              style: AppText.small.tint(Barako.muted).copyWith(height: 1.4),
            ),
            _label('LOAN AMOUNT'),
            TextField(
              controller: amount,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              style: TextStyle(color: Barako.text),
              decoration: InputDecoration(
                prefixText: '₱ ',
                hintText: 'e.g. 100,000',
              ),
            ),
            _label('TERM'),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: term,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Barako.text),
                    decoration: InputDecoration(hintText: 'e.g. 12'),
                  ),
                ),
                const SizedBox(width: 12),
                _seg(
                  const [('months', 'Months'), ('years', 'Years')],
                  termUnit,
                  (v) => termUnit = v,
                ),
              ],
            ),
            _label('INTEREST RATE'),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: rate,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(color: Barako.text),
                    decoration: InputDecoration(
                      hintText: 'e.g. 1.5',
                      suffixText: '%',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _seg(
                  const [('monthly', 'Per month'), ('annual', 'Per year')],
                  rateBasis,
                  (v) => rateBasis = v,
                ),
              ],
            ),
            _label('HOW THE INTEREST IS CHARGED'),
            _seg(
              const [('diminishing', 'Diminishing'), ('addon', 'Add-on')],
              method,
              (v) => method = v,
            ),
            const SizedBox(height: 6),
            Text(
              addon
                  ? 'Add-on charges interest on the ORIGINAL amount for the whole term, common in in-house and informal financing. It looks cheap and is not.'
                  : 'Diminishing charges interest only on what you still owe, the way banks amortize.',
              style: AppText.caption.copyWith(height: 1.4),
            ),
            if (termClamped)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Term capped at $maxMonths months, no consumer loan runs a century.',
                  style: AppText.caption.tint(Barako.warning),
                ),
              ),
            if (badInput)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Amounts and rates cannot be negative.',
                  style: AppText.small.tint(Barako.warning),
                ),
              )
            else if (needTerm)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Enter the term and the numbers appear.',
                  style: AppText.small.tint(Barako.muted),
                ),
              )
            else if (!ready)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Enter the loan amount, term, and interest rate and the numbers appear.',
                  style: AppText.small.tint(Barako.muted),
                ),
              ),
            if (r != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MONTHLY PAYMENT',
                        style: TextStyle(
                          color: Barako.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _m(r['payment'] as double),
                        style: AppText.amountLg.w7,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Total interest', style: AppText.small),
                          ),
                          Text(
                            _m(r['totalInterest'] as double),
                            style: AppText.small.w6.tabular,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Total to pay', style: AppText.small),
                          ),
                          Text(
                            _m(r['totalPaid'] as double),
                            style: AppText.small.w6.tabular,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: addon ? null : Barako.card,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRUE COST',
                        style: TextStyle(
                          color: addon ? Barako.warning : Barako.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Quoted rate per year',
                              style: AppText.small,
                            ),
                          ),
                          Text(
                            _pct(r['nominalAnnualRate'] as double),
                            style: AppText.small,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Effective interest per year',
                              style: AppText.smallStrong,
                            ),
                          ),
                          Text(
                            _pct(r['effectiveAnnualRate'] as double),
                            style: AppText.body.w8.tint(
                              addon ? Barako.warning : Barako.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        addon
                            ? 'Your ${rateBasis == 'annual' ? '${_pct(r['nominalAnnualRate'] as double)} a year' : '${_pct(r['quotedMonthlyRate'] as double)} a month'} add-on really works out to about ${_pct(r['effectiveAnnualRate'] as double)} a year, once you account for paying interest on money you have already returned.'
                            : 'For a diminishing loan the quoted and effective rates differ only because of monthly compounding. At normal bank rates they stay close.',
                        style: AppText.caption.copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              if (payoff != null &&
                  months >= 2 &&
                  (payoff['interestSaved'] as double) > 0 &&
                  method == 'diminishing') ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Make your first ${months ~/ 2} payments, then pay the remaining ${_m(payoff['balanceCleared'] as double)} in one go, and you skip about ${_m(payoff['interestSaved'] as double)} of the remaining interest, if there is no pre-termination fee.',
                      style: AppText.small.copyWith(height: 1.4),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => showSchedule = !showSchedule),
                child: Text(
                  showSchedule
                      ? 'Hide the month by month schedule'
                      : 'Show the month by month schedule',
                ),
              ),
              if (showSchedule)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        for (final row
                            in (r['schedule'] as List)
                                .cast<Map<String, dynamic>>())
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 34,
                                  child: Text(
                                    '${row['period']}',
                                    style: AppText.caption,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${_m(row['interest'] as double)} interest · ${_m(row['principal'] as double)} principal',
                                    style: AppText.caption.tint(
                                      Barako.textSecondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  _m(row['balance'] as double),
                                  style: AppText.caption.w6
                                      .tint(Barako.textSecondary)
                                      .tabular,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'This is an estimate from the numbers you typed, not a loan offer. Real contracts add fees, insurance, and penalties, and a pre-termination charge can reduce the saving from paying early. Read the disclosure statement before signing. If a lender will not tell you the effective interest rate, that is a warning sign.',
                style: AppText.micro.w4
                    .tint(Barako.faint)
                    .copyWith(height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
