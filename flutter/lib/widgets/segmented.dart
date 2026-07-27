// One control for picking one of a few named options.
//
// Lifted out of the Appearance screen, where it started life as the
// light/dark/system picker, because the Utang tab needs the same shape to
// switch between what you owe and what you are owed. Two hand-rolled copies of
// a control drift the same way five hand-rolled copies of a kicker did.
//
// Hand rolled rather than Material's SegmentedButton, which arrives with a
// stadium shape, vertical dividers and its own checkmark, and would need six
// style overrides to lose them. This is shorter than the overrides would be.
//
// Four things changed on the way out of Appearance, and each is a rule this
// control now enforces for every caller:
//
// 1. The tap target floor is 48, not 44. 44 is the iOS minimum; Android wants
//    48, and this app is built for cheap Android phones.
// 2. Selection is never carried by colour alone. The fill and the heavier
//    weight are both colour-ish cues, and a bold word is not reliably
//    distinguishable from a plain one at a glance. A check glyph is a SHAPE,
//    which is what a colourblind user actually needs.
// 3. Labels wrap instead of overflowing. At text scale 2 on a 320dp phone,
//    two or three labels in a Row of Expandeds will not fit on one line, and
//    a wrapping Text inside an Expanded cannot overflow horizontally.
// 4. The fill animation honours the OS reduce-motion setting, the same way
//    PressableScale does.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// One choice in a [Segmented].
class SegmentOption<T> {
  final T value;
  final String label;

  /// What a screen reader should say. Falls back to the label.
  final String? semanticLabel;

  const SegmentOption({required this.value, required this.label, this.semanticLabel});
}

class Segmented<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T current;
  final void Function(T) onPick;

  // NOT const. build() reads mutable Barako getters, so a const call site
  // would let Element.updateChild skip build() and freeze this control in the
  // previous palette after a theme switch. Same rule as every shared widget
  // here, and palette_switch_test.dart enforces it.
  // ignore: prefer_const_constructors_in_immutables
  Segmented({
    super.key,
    required this.options,
    required this.current,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    // Zero duration under reduce-motion rather than a shorter one: the setting
    // means "no animation", not "less animation".
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Container(
      decoration: BoxDecoration(
        color: Barako.card,
        border: Border.all(color: Barako.border),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      padding: const EdgeInsets.all(Gap.xxs),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: o.value == current,
                label: o.semanticLabel ?? o.label,
                // The onTap is not decoration, and leaving it off is the bug
                // this control shipped with inside Appearance.
                //
                // ExcludeSemantics strips the InkWell's tap ACTION along with
                // its label, so without this the node advertised "button,
                // selected" and no way to activate it. Flutter's own tap target
                // guideline skips any node with neither a tap nor a longPress
                // action, so the control was not merely unlabelled to a screen
                // reader, it was INVISIBLE to the accessibility test that was
                // supposed to be checking it. The test passed with a 20 pixel
                // target until this line existed.
                onTap: () {
                  HapticFeedback.selectionClick();
                  onPick(o.value);
                },
                child: ExcludeSemantics(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onPick(o.value);
                      },
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: reduce ? 0 : 160),
                        curve: Curves.easeOut,
                        // 48, the Android floor. The consequence of a mis-tap
                        // on a control like this is never small: on Appearance
                        // it repaints the whole app, and on Utang it swaps the
                        // screen under your thumb.
                        constraints: const BoxConstraints(minHeight: 48),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.xs,
                          vertical: Gap.xs,
                        ),
                        decoration: BoxDecoration(
                          color: o.value == current
                              ? Barako.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (o.value == current) ...[
                              // The shape cue. Excluded from semantics because
                              // the Semantics wrapper above already announces
                              // the selected state, and a screen reader saying
                              // "check, Dark, selected" is noise.
                              Icon(
                                Icons.check,
                                size: 16,
                                color: Barako.onPrimary,
                              ),
                              const SizedBox(width: Gap.xs),
                            ],
                            Flexible(
                              child: Text(
                                o.label,
                                textAlign: TextAlign.center,
                                // Wraps rather than clips. A label that has run
                                // out of room should get taller, not vanish.
                                maxLines: 2,
                                style: TextStyle(
                                  color: o.value == current
                                      ? Barako.onPrimary
                                      : Barako.textSecondary,
                                  fontSize: 14,
                                  height: 1.2,
                                  fontWeight: o.value == current
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
