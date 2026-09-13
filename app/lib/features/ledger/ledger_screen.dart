// Ledger. Question 3: what happened? Every entry, grouped by day, searchable.
//
// Empty until Phase C wires it to the store. See home_screen.dart.
import 'package:flutter/material.dart';

import '../../design/kit.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Screen(
      children: [
        SizedBox(height: 14),
        ScreenTitle(
          title: 'Ledger',
          sub: 'Everything you have logged, newest first.',
        ),
        SizedBox(height: 20),
        EmptyState(
          icon: Icons.article_outlined,
          title: 'No entries yet',
          body:
              'Every expense, income and transfer you log lands here, grouped '
              'by the day it happened.',
        ),
      ],
    );
  }
}
