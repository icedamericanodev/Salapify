// Plan. Questions 4 and 5: what is coming, and where does it go?
// Budget, upcoming bills, payday, due dates.
//
// Empty until Phase C wires it to the store. See home_screen.dart.
import 'package:flutter/material.dart';

import '../../design/kit.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Screen(
      children: [
        SizedBox(height: 14),
        ScreenTitle(
          title: 'Plan',
          sub: 'Your budget, and what is due before the next payday.',
        ),
        SizedBox(height: 20),
        EmptyState(
          icon: Icons.donut_small_outlined,
          title: 'No budget set',
          body:
              'Set a monthly amount per category and this screen shows what '
              'is left, not just what is spent.',
        ),
      ],
    );
  }
}
