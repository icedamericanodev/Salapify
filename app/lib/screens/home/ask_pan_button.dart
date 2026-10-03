import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// The floating Ask Pan button, ported from src/components/PanFloatingButton.tsx.
///
/// It rides above the scrolling content and sits clear of the tab bar, so the
/// assistant is reachable from anywhere on Home without taking a card slot.
class AskPanButton extends StatelessWidget {
  const AskPanButton({super.key, required this.palette, this.onTap});

  final Palette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ask Pan, the money assistant',
      child: Material(
        color: palette.accent,
        borderRadius: BorderRadius.circular(Radii.pill),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.pill),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.smart_toy_outlined,
                  size: 18,
                  color: palette.onAccent,
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  'Ask Pan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: palette.onAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
