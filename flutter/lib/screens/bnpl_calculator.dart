// Installment true cost: is that "0% interest" really 0%? Adapted from the
// RN screen on the golden-ported bnpl engine. Enter the plan and see the
// real cost versus paying cash, and the true rate a monthly quote can
// hide. Impossible numbers get their own honest state instead of a fake
// reassurance.

import 'package:flutter/material.dart';

import '../money/bnpl.dart';
import '../theme.dart';
import 'overview.dart' show formatMoney;

class BnplCalculatorScreen extends StatefulWidget {
  const BnplCalculatorScreen({super.key});

  @override
  State<BnplCalculatorScreen> createState() => _BnplCalculatorScreenState();
}

class _BnplCalculatorScreenState extends State<BnplCalculatorScreen> {
  final price = TextEditingController();
  final months = TextEditingController();
  final monthly = TextEditingController();
  final down = TextEditingController();
  final fee = TextEditingController();

  @override
  void dispose() {
    price.dispose();
    months.dispose();
    monthly.dispose();
    down.dispose();
    fee.dispose();
    super.dispose();
  }

  double _parse(String s) {
    final cleaned = s.replaceAll(RegExp(r'[, ]'), '');
    if (cleaned.isEmpty) return 0;
    final n = double.tryParse(cleaned);
    return (n == null || !n.isFinite) ? 0 : n;
  }

  String _m(num n) => formatMoney((n + 0.5).floorToDouble());

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text,
            style: TextStyle(
                color: Barako.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      );

  Widget _field(TextEditingController c, String hint, {bool peso = true}) =>
      TextField(
        controller: c,
        onChanged: (_) => setState(() {}),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: Barako.text),
        decoration:
            InputDecoration(prefixText: peso ? '₱ ' : null, hintText: hint),
      );

  @override
  Widget build(BuildContext context) {
    final priceNum = _parse(price.text);
    final monthsNum = (_parse(months.text) + 0.5).floorToDouble();
    final monthlyNum = _parse(monthly.text);
    final downNum = _parse(down.text);
    final feeNum = _parse(fee.text);

    final r = bnplCost({
      'cashPrice': priceNum,
      'downpayment': downNum,
      'months': monthsNum,
      'monthlyPayment': monthlyNum,
      'upfrontFee': feeNum,
    });

    String pct(num x) => '${(x * 100).toStringAsFixed(1)}%';
    // A real rate above 1,000% a year is arithmetically true on a punishing
    // fee but reads as broken, so cap the display and let the peso extra
    // cost carry it.
    final rateDisplay = (r['annualRate'] as double) > 10
        ? 'over 1,000%'
        : pct(r['annualRate'] as double);

    final badInput = priceNum < 0 ||
        monthlyNum < 0 ||
        downNum < 0 ||
        feeNum < 0 ||
        monthsNum < 0;
    final ready = priceNum > 0 && monthsNum >= 1 && monthlyNum > 0;
    final monthsCapped = monthsNum > 60;
    final underpays = r['underpays'] as bool;
    final trulyFree = r['trulyFree'] as bool;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text('Installment true cost',
            style:
                TextStyle(color: Barako.text, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
                'Is that "0% interest" really 0%? Enter the plan and see the real cost versus paying cash, and the true rate a monthly quote can hide.',
                style: TextStyle(
                    color: Barako.muted, fontSize: 13, height: 1.4)),
            _label('CASH PRICE (IF YOU PAID IN FULL TODAY)'),
            _field(price, 'e.g. 12,000'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('MONTHS TO PAY'),
                      _field(months, 'e.g. 6', peso: false),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('MONTHLY PAYMENT'),
                      _field(monthly, 'e.g. 2,100'),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('DOWNPAYMENT (OPTIONAL)'),
                      _field(down, '0'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('UPFRONT FEE (OPTIONAL)'),
                      _field(fee, '0'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
                'Some "0%" plans still charge a processing or convenience fee. Put it in the upfront fee box and it shows up in the real cost.',
                style: TextStyle(
                    color: Barako.muted, fontSize: 12, height: 1.4)),
            const SizedBox(height: 12),
            if (badInput)
              Text('Check your numbers. None of the amounts can be negative.',
                  style: TextStyle(color: Barako.warning, fontSize: 13))
            else if (!ready)
              Text(
                  'Enter the cash price, the months to pay, and the monthly payment to see the real cost.',
                  style: TextStyle(color: Barako.muted, fontSize: 13))
            else if (underpays)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CHECK YOUR NUMBERS',
                          style: TextStyle(
                              color: Barako.warning,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 6),
                      Text(
                          'Your payments come to ${_m(r['totalPaid'] as double)}, which is less than the ${_m(r['cash'] as double)} cash price. Double check the monthly amount, the months, and the downpayment.',
                          style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 13,
                              height: 1.4)),
                    ],
                  ),
                ),
              )
            else ...[
              if (monthsCapped)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                      'Using 60 months, the longest this tool estimates.',
                      style:
                          TextStyle(color: Barako.warning, fontSize: 12)),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL YOU WILL PAY',
                          style: TextStyle(
                              color: Barako.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 4),
                      Text(_m(r['totalPaid'] as double),
                          style: TextStyle(
                              color: Barako.text,
                              fontSize: 30,
                              fontFamily: Barako.displayFont,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Cash price',
                                style: TextStyle(
                                    color: Barako.textSecondary,
                                    fontSize: 13)),
                          ),
                          Text(_m(r['cash'] as double),
                              style: TextStyle(
                                  color: Barako.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Extra over cash',
                                style: TextStyle(
                                    color: Barako.textSecondary,
                                    fontSize: 13)),
                          ),
                          Text(_m(r['extraCost'] as double),
                              style: TextStyle(
                                  color: (r['extraCost'] as double) > 0
                                      ? Barako.warning
                                      : Barako.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TRUE COST',
                          style: TextStyle(
                              color: trulyFree
                                  ? Barako.muted
                                  : Barako.warning,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 6),
                      if (trulyFree)
                        Text(
                            'Based on your numbers, this costs the same as paying cash today. Just make sure you can keep up with the ${_m(r['monthly'] as double)} a month for ${r['months']} months.',
                            style: TextStyle(
                                color: Barako.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.4))
                      else if (r['rateReliable'] as bool) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text('Real interest per year',
                                  style: TextStyle(
                                      color: Barako.text,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ),
                            Text(rateDisplay,
                                style: TextStyle(
                                    color: Barako.warning,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                            'This plan costs you ${_m(r['extraCost'] as double)} more than paying cash, about $rateDisplay a year on the ${_m(r['netCredit'] as double)} of credit you receive. Saving up for ${r['months']} months and paying cash would cost nothing.',
                            style: TextStyle(
                                color: Barako.muted,
                                fontSize: 12,
                                height: 1.4)),
                      ] else
                        Text(
                            'This plan costs you ${_m(r['extraCost'] as double)} more than paying cash. Paying cash would cost nothing.',
                            style: TextStyle(
                                color: Barako.muted,
                                fontSize: 12,
                                height: 1.4)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
                'An estimate from the numbers you enter, not a loan offer. Real plans can add late fees and penalties. If a plan will not show you the total you will pay or a clear rate, that is a warning sign.',
                style:
                    TextStyle(color: Barako.faint, fontSize: 11, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
