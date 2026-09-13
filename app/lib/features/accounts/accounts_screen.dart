// Accounts. Question 2: what do I own and owe?
//
// Accounts, not Wallets. See D3, and the comment on NavBar.tabs.
// Empty until Phase C wires it to the store. See home_screen.dart.
import 'package:flutter/material.dart';

import '../../design/kit.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Screen(
      children: [
        SizedBox(height: 14),
        ScreenTitle(
          title: 'Accounts',
          sub: 'Cash, bank, e-wallet, credit, and both directions of debt.',
        ),
        SizedBox(height: 20),
        EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'No accounts yet',
          body:
              'Add where your money actually sits and this screen leads with '
              'your net worth.',
        ),
      ],
    );
  }
}
