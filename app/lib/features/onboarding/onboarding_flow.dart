import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../design/tokens.dart';
import '../../state/financial_state.dart';
import 'first_account_screen.dart';
import 'welcome_screen.dart';

/// The two screens a first launch can show, and the fork between them.
///
/// Deliberately tiny. It owns WHICH screen is up and nothing else: both
/// screens collect, this decides when, and [FinancialState] decides what
/// happens to the data. That split is the same one every sheet in the app
/// already uses, and it is what lets the screens be rendered on their own for
/// review without a store behind them.
///
/// ## How it ends
///
/// It does not pop or push anything. Both store calls set `onboardedAt` and
/// notify, `needsWelcome` goes false, and `main.dart` rebuilds into the
/// shell on the next frame. So there is exactly one place that decides
/// whether a person is onboarded, and no second copy of that decision living
/// in a navigator stack that could disagree with the file.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.palette, required this.state});

  final Palette palette;
  final FinancialState state;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  bool _askingForAccount = false;

  @override
  Widget build(BuildContext context) {
    if (_askingForAccount) {
      return FirstAccountScreen(
        palette: widget.palette,
        onDone: (String name, String balance) {
          // PARSED HERE, so the screen stays a screen. An unreadable figure
          // becomes zero rather than a crash or a refusal: somebody who types
          // nonsense into their opening balance has made a mistake they can
          // correct from Accounts in two taps, and refusing to let them in
          // over it would be the app guarding its own tidiness rather than
          // their money.
          final double typed =
              double.tryParse(balance.replaceAll(',', '')) ?? 0;
          widget.state.startWithOwnMoney(
            accountName: name.isEmpty ? 'Cash' : name,
            // Guarded, because a non-finite double throws inside Money and a
            // keyboard can produce one.
            opening: typed.isFinite ? Money.fromDouble(typed) : Money.zero,
          );
        },
      );
    }

    return WelcomeScreen(
      palette: widget.palette,
      onStartReal: () => setState(() => _askingForAccount = true),
      onStartDemo: widget.state.startWithExampleData,
    );
  }
}
