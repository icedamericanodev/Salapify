// The one choice chip.
//
// The same chip was copy-pasted with its own colors in over a dozen files
// (selectedColor, backgroundColor, labelStyle, side, every time), which is
// exactly how the log and edit sheets ended up with two different chip skins
// on the same form. Phase 1 moved the whole look into the theme's chipTheme,
// so the styling here is deliberately NOTHING: a bare ChoiceChip is already
// correct, and a call site that wants to restyle one has to argue with this
// file first.
//
// What the theme cannot own is behavior: picking a chip is a selection, so
// it clicks (Haptics.select), the same word the segmented control speaks.
// One place, so a chip can never buzz differently per screen.

import 'package:flutter/material.dart';

import '../theme.dart';

class SalapifyChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;

  /// Called on tap. ChoiceChip reports the would-be state; most callers just
  /// set their selection, matching how every site already used it.
  final ValueChanged<bool>? onSelected;

  // NOT const. The theme the chip resolves against reads mutable Barako
  // getters; a const call site would freeze it after a theme switch. Same
  // rule as every shared widget here.
  // ignore: prefer_const_constructors_in_immutables
  SalapifyChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      // The check is a SHAPE cue, same rule as the segmented control's
      // glyph: selection never carried by color alone. The theme keeps the
      // checkmark off for legacy call sites; chips that adopt this widget
      // opt into the cue.
      showCheckmark: true,
      checkmarkColor: Barako.onPrimary,
      onSelected: onSelected == null
          ? null
          : (v) {
              // Only a CHANGE clicks. Re-tapping the selected chip changes
              // nothing, and a buzz on a no-op teaches the hand to distrust
              // every other buzz in the app.
              if (!selected) Haptics.select();
              onSelected!(v);
            },
    );
  }
}
