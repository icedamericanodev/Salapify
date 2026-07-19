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

  /// Centavo form for the sub-peso band where whole-peso rounding would
  /// print a self-contradiction like "₱12,000 is less than ₱12,000".
  String _mc(num n) {
    final fixed = n.toStringAsFixed(2);
    final dot = fixed.indexOf('.');
    var whole = fixed.substring(0, dot);
    final neg = whole.startsWith('-');
    if (neg) whole = whole.substring(1);
    final buf = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
      buf.write(whole[i]);
    }
    return '${neg ? '-' : ''}₱$buf${fixed.substring(dot)}';
  }

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
    final rateCapped = (r['annualRate'] as double) > 10;
    final rateDisplay =
        rateCapped ? 'over 1,000%' : pct(r['annualRate'] as double);
    // The sentence form reads naturally either way; "about over 1,000%" is
    // broken English (bank officer finding, same defect latent in RN).
    final rateSentence = rateCapped
        ? 'more than 1,000% a year'
        : 'about ${pct(r['annualRate'] as double)} a year';

    final badInput = priceNum < 0 ||
        monthlyNum < 0 ||
        downNum < 0 ||
        feeNum < 0 ||
        monthsNum < 0;
    final ready = priceNum > 0 && monthsNum >= 1 && monthlyNum > 0;
    final monthsCapped = monthsNum > 60;
    final underpays = r['underpays'] as bool;
    // Centavos when whole-peso rounding would make the underpays figures
    // read equal (QA finding: "₱12,000 is less than ₱12,000").
    final sameRounded =
        _m(r['totalPaid'] as double) == _m(r['cash'] as double);
    final paidText = sameRounded
        ? _mc(r['totalPaid'] as double)
        : _m(r['totalPaid'] as double);
    final cashText =
        sameRounded ? _mc(r['cash'] as double) : _m(r['cash'] as double);
    // Display-level honesty for the sub-peso band (QA finding): when the
    // extra cost and the fee are both under half a peso, every figure the
    // screen can print says "same as cash", so the warning framing with a
    // "₱0 more" claim would be the dishonest one. The engine's own
    // trulyFree (0.005 epsilon) stays golden-locked; this widens only what
    // the SCREEN calls free, to its own display resolution.
    final trulyFree = (r['trulyFree'] as bool) ||
        (!underpays &&
            (r['extraCost'] as double) < 0.5 &&
            (r['fee'] as double) < 0.5);

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
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 6),
                      Text(
                          'Your payments come to $paidText, which is less than the $cashText cash price. Double check the monthly amount, the months, and the downpayment. If a trade in, voucher, or discount covers part of the price, add that amount to the downpayment.',
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
                              fontSize: 11,
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
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 6),
                      if (trulyFree)
                        Text(
                            'Based on your numbers, this costs the same as paying cash today. Just make sure you can keep up with the ${_m(r['monthly'] as double)} a month for ${r['months']} months.',
                            style: TextStyle(
                                color: Barako.primaryText,
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
                            'This plan costs you ${_m(r['extraCost'] as double)} more than paying cash, $rateSentence on the ${_m(r['netCredit'] as double)} of credit you receive. If you can wait, saving up for ${r['months']} months and paying cash costs no interest. The extra ${_m(r['extraCost'] as double)} is the price of getting it today.',
                            style: TextStyle(
                                color: Barako.muted,
                                fontSize: 12,
                                height: 1.4)),
                      ] else if ((r['extraCost'] as double) <= 0.005)
                        // A fee that exactly offsets the installments: the
                        // total matches cash but part of it was a fee, so
                        // never print the self-contradicting "costs you ₱0
                        // more" (bank officer finding).
                        Text(
                            'Based on your numbers the total matches the cash price, but part of it is a ${_m(r['fee'] as double)} fee paid upfront, so make sure the installments really are that low.',
                            style: TextStyle(
                                color: Barako.muted,
                                fontSize: 12,
                                height: 1.4))
                      else
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
