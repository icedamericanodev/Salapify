// Home. Answers question 1 of the five in 01-vision.md: am I okay right now?
//
// EMPTY FOR NOW, on purpose. Phase B3 builds the design system and the shell;
// Phase C wires each screen to the LedgerStore that landed in B2. What is here
// is the real title, the real spacing and the real empty state, so the founder
// is reviewing the actual screen rather than a placeholder.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell.dart';
import '../../design/kit.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen(
      children: [
        const TopBar(date: 'Saturday, Sep 13'),
        const SizedBox(height: 18),
        const ScreenTitle(
          title: 'Home',
          sub: 'Safe to spend, net worth and what is due.',
        ),
        const SizedBox(height: 20),
        const EmptyState(
          icon: Icons.pie_chart_outline_rounded,
          title: 'Nothing logged yet',
          body:
              'Tap Log to record your first expense. Once there is money in '
              'here, this screen leads with what is safe to spend before '
              'payday.',
        ),
        const SizedBox(height: 14),
        PillButton(
          label: 'Log your first entry',
          icon: Icons.add_rounded,
          onTap: () => context.push(logRoutePath),
        ),
      ],
    );
  }
}
