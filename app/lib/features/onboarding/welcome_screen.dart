import 'package:flutter/material.dart';

import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// The first screen a stranger meets, and the only question onboarding asks
/// that is not about their money.
///
/// NOT WIRED INTO THE APP YET. `main.dart` still goes straight to AppShell, so
/// a fresh install behaves exactly as it did. This exists so the founder can
/// look at the design before approving the two decisions it depends on:
/// whether the demo data survives a fresh install at all, and one stored
/// field so the app can remember it has introduced itself. Both are
/// founder-gated under the STOP conditions, so neither is assumed here.
///
/// ## Why a choice rather than a welcome
///
/// Design agreed in docs/reviews/onboarding-design.md. A fresh install opens
/// on sample data today, and a user panel found the worst moment is not the
/// first glance, it is the first REAL entry landing beside the fake ones. The
/// alternative, starting empty, trades that for an intimidating wall of
/// zeroes. Asking costs one tap and no personal information, and it buys a
/// declared intent: somebody who chose the example data cannot be confused by
/// the figures, because they authored the fiction.
///
/// ## Why there is nothing else on it
///
/// No carousel, no tour, no skip. The house rule is that a screen carries
/// figures and the one line needed to read them, and teaching goes behind the
/// `i` dot where somebody can pull it at the moment it applies. A three screen
/// value proposition swipe is the purest violation of that, at the one moment
/// a person has no context to attach it to.
///
/// The one line of copy is a claim about PRIVACY and it stays on screen rather
/// than going behind a dot, because it is what a person needs in order not to
/// reach the wrong conclusion about what a money app is going to do with their
/// money. That is the stated exception to the rule, not a loophole in it.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.palette,
    this.onStartReal,
    this.onStartDemo,
  });

  final Palette palette;

  /// Chosen by somebody who wants their own figures. Under the agreed design
  /// this path seeds NOTHING, including the payday.
  final VoidCallback? onStartReal;

  /// Chosen by somebody who wants to look around first. Keeps the demo, and
  /// Home then carries a permanent one line exit from it.
  final VoidCallback? onStartDemo;

  @override
  Widget build(BuildContext context) {
    final Palette p = palette;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Spacer(flex: 3),

              // The real mark, not a drawn stand-in. It carries its own plate
              // so it is never tinted by the mood.
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/brand/salapify_logo.png',
                  width: 64,
                  height: 64,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const SizedBox(height: Spacing.xl),

              Text(
                'Salapify',
                style: AppType.hero(p).copyWith(color: p.accent),
              ),
              const SizedBox(height: Spacing.sm),

              Text(
                'Every peso in and out, and where it went.',
                style: AppType.body(p).copyWith(color: p.textSecondary),
              ),

              const SizedBox(height: Spacing.xxl),

              // THE PRIVACY LINE, on screen rather than behind a dot. See the
              // class doc: a wrong conclusion here is the expensive one.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  // Concentric: this sits on the page rather than inside a
                  // card, so it takes the control radius and not the card one.
                  borderRadius: BorderRadius.circular(Radii.control),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: p.accent,
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Text(
                        'Offline. No account, no sign up. Everything stays on '
                        'this phone.',
                        style: AppType.body(p),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 4),

              _ChoiceButton(
                palette: p,
                label: 'Start with my own money',
                filled: true,
                onTap: onStartReal,
              ),
              const SizedBox(height: Spacing.md),
              _ChoiceButton(
                palette: p,
                label: 'Look around with example data first',
                filled: false,
                onTap: onStartDemo,
              ),

              const SizedBox(height: Spacing.lg),
              Text(
                // NOT a disclaimer and not teaching. It removes the reason
                // somebody hesitates over the left hand choice, which is the
                // fear that picking wrong is permanent.
                'You can switch either way later.',
                style: AppType.caption(p),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the two choices.
///
/// Not [PrimaryButton], because these two are PEERS. The filled one is the
/// recommendation and the quiet one is a real alternative, not a cancel, so
/// it keeps the same height, the same radius and the same 48dp target and
/// differs only in weight.
class _ChoiceButton extends StatefulWidget {
  const _ChoiceButton({
    required this.palette,
    required this.label,
    required this.filled,
    this.onTap,
  });

  final Palette palette;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  State<_ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<_ChoiceButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final bool filled = widget.filled;

    return Semantics(
      button: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        child: AnimatedScale(
          // 0.96, the house floor. Below that it reads as a glitch rather
          // than as a press.
          // Still when the phone asks for less motion.
          scale: _down && !reduceMotion(context) ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Material(
            color: filled ? p.accent : p.surface,
            borderRadius: BorderRadius.circular(Radii.control),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(Radii.control),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 52),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.control),
                  border: filled ? null : Border.all(color: p.borderStrong),
                ),
                child: Text(
                  widget.label,
                  style: AppType.button(
                    p,
                    color: filled ? p.onAccent : p.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
