// The one primary action button.
//
// The main call to action had been re-spelled at least four times: the log
// and edit sheets, the goals empty state and paluwagan each rebuilt the same
// FilledButton with the same explicit colors the theme already sets, and each
// invented its own busy treatment ("Saving..." text, or nothing). This widget
// owns the shape once: theme colors, one padding, one label size, and a busy
// state that swaps in a spinner and disables the tap without moving the
// layout.
//
// It stays a FilledButton underneath, so everything the theme decides
// (color, radius, letter spacing, disabled treatment) keeps coming from
// theme.dart. This file only adds what a style cannot: the busy behavior.
// Secondary and tertiary actions do not get a wrapper; a bare OutlinedButton
// or TextButton is already correct by theme, and a wrapper that only
// forwards would be a layer for its own sake.

import 'package:flutter/material.dart';

import '../theme.dart';

class PrimaryButton extends StatelessWidget {
  final String label;

  /// Null disables the button (the theme draws the disabled state).
  final VoidCallback? onPressed;

  /// While true the button is disabled and shows a small spinner beside the
  /// label, so a slow save cannot be double-tapped and never looks frozen.
  final bool busy;

  /// The label while busy. Defaults to [label], which keeps the width stable.
  final String? busyLabel;

  /// Optional leading icon (a semantic name is the caller's business; this
  /// takes the resolved glyph).
  final IconData? icon;

  /// Fill the available width. The app's save buttons are full-width; inline
  /// CTAs pass false.
  final bool expand;

  // NOT const. build() reads mutable Barako getters through the theme, and a
  // const call site would let Element.updateChild skip build() after a theme
  // switch. Same rule as every shared widget here.
  // ignore: prefer_const_constructors_in_immutables
  PrimaryButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.busy = false,
    this.busyLabel,
    this.icon,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    // Vertical padding, not a fixed height, so large accessibility text grows
    // the button instead of clipping inside it. Type comes entirely from the
    // theme's filledButtonTheme; the only styling here is what busy needs.
    //
    // While busy the button disables its tap, and Material's default
    // disabled treatment (12 percent fill, 38 percent ink) would turn the
    // primary action gray mid-save, which reads as "it broke" rather than
    // "it is working". Busy keeps the working look; only a truly disabled
    // button (onPressed null, not busy) goes quiet.
    final style = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.gutter,
        vertical: Gap.md,
      ),
      disabledBackgroundColor: busy ? Barako.primary : null,
      disabledForegroundColor: busy ? Barako.onPrimary : null,
    );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy) ...[
          // Decorative to a screen reader; the label carries the state.
          ExcludeSemantics(
            child: SizedBox(
              width: IconSizes.dense,
              height: IconSizes.dense,
              // The button keeps its working colors while busy (see the
              // style above), so the spinner draws in the same ink as the
              // label beside it.
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Barako.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: Gap.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: IconSizes.dense),
          const SizedBox(width: Gap.sm),
        ],
        // With no busyLabel the visual label stays put while busy, so the
        // only screen-reader evidence would be "disabled", which reads as
        // broken; the semantic label says busy out loud in that case.
        Flexible(
          child: busy && busyLabel == null
              ? Semantics(label: '$label, busy', child: Text(label))
              : Text(busy ? busyLabel! : label),
        ),
      ],
    );
    final button = FilledButton(
      style: style,
      onPressed: busy ? null : onPressed,
      child: child,
    );
    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
