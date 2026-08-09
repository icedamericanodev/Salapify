// Tools and More: the hub for the calculators and helpers being adapted
// one by one from the RN app.
//
// It used to be thirteen full-width blurb cards in one undifferentiated
// column, the audit's "card wall": every tool shouted equally, so nothing
// guided the eye and finding the take-home pay calculator meant reading all
// thirteen. Phase 6 groups them into a few short lists, one card per band,
// the same NavBand/NavTile row physics Menu uses. Each row still carries a
// one-line purpose, because a calculator's name alone ("Income tax") does
// not always say what it answers.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import '../widgets/nav_tile.dart';
import '../widgets/section.dart';
import 'bnpl_calculator.dart';
import 'contribution_calculator.dart';
import 'currency_converter.dart';
import 'loan_calculator.dart';
import 'notes.dart';
import 'salary_calculator.dart';
import 'tax_calculator.dart';
import 'tax_deadlines.dart';
import 'year_end_tax.dart';
import 'thirteenth_calculator.dart';

class ToolsScreen extends StatelessWidget {
  final SalapifyStore store;

  const ToolsScreen({super.key, required this.store});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Calculators',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _band(context, 'Salary and tax', [
              NavTile(
                icon: 'cash',
                label: 'Take-home pay',
                detail: 'Gross to net, after SSS, PhilHealth, Pag-IBIG and tax.',
                onTap: () => _open(context, const SalaryCalculatorScreen()),
              ),
              NavTile(
                icon: 'gift',
                label: '13th month pay',
                detail: 'What you should get by 24 December, and the tax-free cap.',
                onTap: () => _open(context, const ThirteenthCalculatorScreen()),
              ),
              NavTile(
                icon: 'bank',
                label: 'Contribution checker',
                detail: 'Monthly SSS, PhilHealth and Pag-IBIG for any salary.',
                onTap: () =>
                    _open(context, const ContributionCalculatorScreen()),
              ),
              NavTile(
                icon: 'billing',
                label: 'Income tax',
                detail: 'For freelancers and pros: flat 8% versus graduated.',
                onTap: () => _open(context, const TaxCalculatorScreen()),
              ),
              NavTile(
                icon: 'checklist',
                label: 'Year-end tax check',
                detail: 'For employees: a refund coming, or still to pay?',
                onTap: () => _open(context, YearEndTaxScreen(store: store)),
              ),
              NavTile(
                icon: 'scheduled',
                label: 'BIR dates',
                detail: 'The next filing deadlines, counted from today.',
                onTap: () => _open(context, TaxDeadlinesScreen(store: store)),
              ),
            ]),
            const SizedBox(height: Gap.xl),
            _band(context, 'Debt and installments', [
              NavTile(
                icon: 'percent',
                label: 'Loan calculator',
                detail: 'The real monthly payment and the true rate behind it.',
                onTap: () => _open(context, const LoanCalculatorScreen()),
              ),
              NavTile(
                icon: 'shopping',
                label: 'Installment true cost',
                detail: 'Is that 0% really 0%? The plan versus paying cash.',
                onTap: () => _open(context, const BnplCalculatorScreen()),
              ),
            ]),
            const SizedBox(height: Gap.xl),
            _band(context, 'Everyday money', [
              NavTile(
                icon: 'exchange',
                label: 'Currency converter',
                detail: 'Another currency, and it works offline once rates save.',
                onTap: () => _open(context, CurrencyConverterScreen(store: store)),
              ),
              NavTile(
                icon: 'note',
                label: 'Notes',
                detail: 'Lines with amounts add themselves up, like a receipt.',
                onTap: () => _open(context, NotesScreen(store: store)),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _band(BuildContext context, String title, List<NavTile> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: Gap.sm),
          // A header flag so a screen reader can jump between the tool groups,
          // matching the calculators' own in-screen section labels.
          child: Semantics(header: true, child: SectionHeader(title)),
        ),
        NavBand(tiles: tiles),
      ],
    );
  }
}
