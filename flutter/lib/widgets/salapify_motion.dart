import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

/// Salapify's shared motion boundary. Motion explains state changes; it never
/// blocks access to financial information and disappears when the platform's
/// reduced-motion preference is enabled.
class SalapifyFadeThrough extends StatelessWidget {
  final Object stateKey;
  final Widget child;
  final Duration duration;

  const SalapifyFadeThrough({
    super.key,
    required this.stateKey,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return PageTransitionSwitcher(
      duration: duration,
      transitionBuilder: (current, primary, secondary) => FadeThroughTransition(
        animation: primary,
        secondaryAnimation: secondary,
        child: current,
      ),
      child: KeyedSubtree(key: ValueKey(stateKey), child: child),
    );
  }
}
