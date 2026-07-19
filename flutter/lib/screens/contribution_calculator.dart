// Contribution checker: monthly SSS, PhilHealth, and Pag-IBIG for any
// salary, what comes out of your pay, what the employer adds, and the total
// credited to you. Adapted from the RN screen on the golden-ported phtax
// contributionBreakdown. Each line rounds to whole pesos once and the
// totals sum those rounded values, matching the RN screen so the parts
// always add up to the shown total.

import 'package:flutter/material.dart';

import '../money/phtax.dart';
import '../theme.dart';
import 'overview.dart' show formatMoney;

class ContributionCalculatorScreen extends StatefulWidget {
  const ContributionCalculatorScreen({super.key});

  @override
  State<ContributionCalculatorScreen> createState() =>
      _ContributionCalculatorScreenState();
}

class _ContributionCalculatorScreenState
    extends State<ContributionCalculatorScreen> {
  final salary = TextEditingController();

  @override
  void dispose() {
    salary.dispose();
    super.dispose();
  }

  double _parse(String s) {
    final cleaned = s.replaceAll(RegExp(r'[, ]'), '');
    if (cleaned.isEmpty) return 0;
    final n = double.tryParse(cleaned);
    return (n == null || !n.isFinite) ? 0 : n;
  }

  String _m(num n) => formatMoney((n + 0.5).floorToDouble());

  int _r(num n) => (n + 0.5).floorToDouble().toInt();

  @override
  Widget build(BuildContext context) {
    final salaryNum = _parse(salary.text);
    final r = contributionBreakdown(salaryNum);
    final ready = salaryNum > 0;

    final sss = (r['sss'] as Map).cast<String, dynamic>();
    final ph = (r['philhealth'] as Map).cast<String, dynamic>();
    final pag = (r['pagibig'] as Map).cast<String, dynamic>();

    // Round each line once, sum the rounded values, so the parts always add
    // up to the displayed total (PhilHealth's identical halves would
    // otherwise carry the same fraction twice).
    final rows = [
      ('SSS', _r(sss['employee'] as double), _r(sss['employer'] as double)),
      ('PhilHealth', _r(ph['employee'] as double),
          _r(ph['employer'] as double)),
      ('Pag-IBIG', _r(pag['employee'] as double),
          _r(pag['employer'] as double)),
    ];
    final eeTotal = rows.fold(0, (s, x) => s + x.$2);
    final erTotal = rows.fold(0, (s, x) => s + x.$3);
    final grandTotal = eeTotal + erTotal;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text('Contribution checker',
            style:
                TextStyle(color: Barako.text, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
                'See your monthly SSS, PhilHealth, and Pag-IBIG for any salary: what comes out of your pay, what your employer adds, and the total credited to you.',
                style: TextStyle(
                    color: Barako.muted, fontSize: 13, height: 1.4)),
            const SizedBox(height: 14),
            Text('MONTHLY SALARY',
                style: TextStyle(
                    color: Barako.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: salary,
              onChanged: (_) => setState(() {}),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: TextStyle(color: Barako.text),
              decoration: InputDecoration(
                  prefixText: '₱ ', hintText: 'e.g. 25,000'),
            ),
            if (ready) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text('Program',
                                style: TextStyle(
                                    color: Barako.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('You',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    color: Barako.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('Employer',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    color: Barako.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      for (final x in rows)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(x.$1,
                                    style: TextStyle(
                                        color: Barako.text,
                                        fontSize: 13)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(_m(x.$2),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        color: Barako.text,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ])),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(_m(x.$3),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        color: Barako.textSecondary,
                                        fontSize: 13,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ])),
                              ),
                            ],
                          ),
                        ),
                      Divider(color: Barako.border, height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text('Total',
                                style: TextStyle(
                                    color: Barako.text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(_m(eeTotal),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    color: Barako.text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ])),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(_m(erTotal),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    color: Barako.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ])),
                          ),
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
                    children: [
                      _sum('Deducted from your pay', _m(eeTotal),
                          strong: true),
                      _sum('Your employer adds', _m(erTotal), muted: true),
                      Divider(color: Barako.border, height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Total credited to you',
                                style: TextStyle(
                                    color: Barako.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                          ),
                          Text(_m(grandTotal),
                              style: TextStyle(
                                  color: Barako.primary,
                                  fontSize: 20,
                                  fontFamily: Barako.displayFont,
                                  fontWeight: FontWeight.w700)),
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
                      Text('GOOD TO KNOW',
                          style: TextStyle(
                              color: Barako.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 6),
                      Text(
                          'Your SSS is based on a Monthly Salary Credit of ${_m(r['msc'] as double)}, your salary rounded to the nearest 500 and kept between 5,000 and 35,000.',
                          style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 12,
                              height: 1.4)),
                      const SizedBox(height: 4),
                      Text(
                          'If you are self-employed or a voluntary member, you pay both shares yourself, so budget for close to the ${_m(grandTotal)} total above, less the small employer-only Employees Compensation part.',
                          style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 12,
                              height: 1.4)),
                    ],
                  ),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                    'Enter your monthly salary to see your contributions.',
                    style: TextStyle(
                        color: Barako.muted, fontSize: 13, height: 1.4)),
              ),
            const SizedBox(height: 12),
            Text(
                'Estimate based on $ratesYear SSS, PhilHealth, and Pag-IBIG rates. SSS includes the WISP portion above a 20,000 salary credit and the employer\'s small Employees Compensation share. Your payslip can differ with your employer\'s rounding and cut-off. Not a substitute for your official records.',
                style:
                    TextStyle(color: Barako.faint, fontSize: 11, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _sum(String label, String value,
          {bool strong = false, bool muted = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: muted ? Barako.muted : Barako.textSecondary,
                      fontSize: 13)),
            ),
            Text(value,
                style: TextStyle(
                    color: muted ? Barako.muted : Barako.text,
                    fontSize: 13,
                    fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      );
}
