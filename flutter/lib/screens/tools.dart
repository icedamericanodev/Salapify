// Tools and More: the hub for the calculators and helpers being adapted
// one by one from the RN app. Each row opens a tool; the coming-soon list
// keeps the founder's roadmap visible in-app so testers know what is next.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import '../widgets/pressable_scale.dart';
import 'bnpl_calculator.dart';
import 'contribution_calculator.dart';
import 'currency_converter.dart';
import 'learn.dart';
import 'loan_calculator.dart';
import 'mindset.dart';
import 'notes.dart';
import 'salary_calculator.dart';
import 'tax_calculator.dart';
import 'thirteenth_calculator.dart';

class ToolsScreen extends StatelessWidget {
  final SalapifyStore store;

  /// Threaded through to Money courses so a lesson action can jump to a
  /// bottom tab (Budget, Utang, Insights).
  final void Function(int)? onSwitchTab;
  const ToolsScreen({super.key, required this.store, this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Tools',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _tool(
              context,
              icon: Icons.percent,
              title: 'Loan calculator',
              blurb:
                  'The real monthly payment and the TRUE rate hiding behind an add-on quote.',
              open: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoanCalculatorScreen()),
              ),
            ),
            _tool(
              context,
              icon: Icons.shopping_bag_outlined,
              title: 'Installment true cost',
              blurb:
                  'Is that 0% really 0%? The plan versus paying cash, honestly.',
              open: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BnplCalculatorScreen()),
              ),
            ),
            _tool(
              context,
              icon: Icons.payments_outlined,
              title: 'Take-home pay',
              blurb:
                  'Gross to net with SSS, PhilHealth, Pag-IBIG, and the BIR table.',
              open: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SalaryCalculatorScreen(),
                ),
              ),
            ),
            _tool(
              context,
              icon: Icons.card_giftcard_outlined,
              title: '13th month pay',
              blurb:
                  'What you should get by 24 December, and the tax-free ceiling.',
              open: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ThirteenthCalculatorScreen(),
                ),
              ),
            ),
            _tool(
              context,
              icon: Icons.request_quote_outlined,
              title: 'Income tax',
              blurb:
                  'Freelancers and pros: the flat 8% versus graduated, compared.',
              open: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TaxCalculatorScreen()),
              ),
            ),
            _tool(
              context,
              icon: Icons.account_balance_outlined,
              title: 'Contribution checker',
              blurb: 'Monthly SSS, PhilHealth, and Pag-IBIG for any salary.',
              open: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ContributionCalculatorScreen(),
                ),
              ),
            ),
            _tool(
              context,
              icon: Icons.currency_exchange,
              title: 'Currency converter',
              blurb:
                  'What your money is worth in another currency. Works offline once rates are saved.',
              open: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CurrencyConverterScreen(store: store),
                ),
              ),
            ),
            _tool(
              context,
              icon: Icons.sticky_note_2_outlined,
              title: 'Notes',
              blurb: 'Lines with amounts add themselves up, like a receipt.',
              open: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => NotesScreen(store: store)),
              ),
            ),
            _tool(
              context,
              icon: Icons.school_outlined,
              title: 'Money courses',
              blurb:
                  'Short, plain reads on your money and habits. Free, always.',
              open: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      LearnScreen(store: store, onSwitchTab: onSwitchTab),
                ),
              ),
            ),
            _tool(
              context,
              icon: Icons.self_improvement_outlined,
              title: 'Money mindset',
              blurb:
                  "Today's lesson, a quick impulse check before you buy, and your small wins.",
              open: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => MindsetScreen(store: store)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tool(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String blurb,
    required VoidCallback open,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressableScale(
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: open,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: Barako.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Barako.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          blurb,
                          style: TextStyle(color: Barako.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Barako.faint, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
