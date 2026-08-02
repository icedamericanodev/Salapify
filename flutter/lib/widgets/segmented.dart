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
// 3. Labels wrap instead of overflowing, and the whole control STACKS
//    vertically when even wrapping cannot fit. At text scale 2 on a narrow
//    phone, three labels in a Row of Expandeds each get a third of the width,
//    and "System" (the longest) needs more than two lines and starts to clip.
//    So the control measures the longest label at the live text scale and, when
//    it will not fit on two lines in a horizontal third, lays the segments out
//    as a full-width vertical stack instead. At normal scale nothing changes.
// 4. The fill animation honours the OS reduce-motion setting, the same way
//    PressableScale does.
// 5. The check-glyph slot is reserved on EVERY segment, not just the selected
//    one, so selecting a segment does not steal width from its label and make
//    it wrap differently (or make the row jump height) than its neighbours.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../typography.dart';
import '../widgets/salapify_icon.dart';

/// One choice in a [Segmented].
class SegmentOption<T> {
  final T value;
  final String label;

  /// What a screen reader should say. Falls back to the label.
  final String? semanticLabel;

  const SegmentOption({
    required this.value,
    required this.label,
    this.semanticLabel,
  });
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

  // The label style. w700 is the selected (heaviest, widest) weight, used as
  // the worst case when measuring whether a label fits horizontally.
  static const double _labelSize = 14;
  // The reserved leading slot: a 16px check glyph plus a Gap.xs gap, kept on
  // every segment so selection never changes a label's available width.
  static const double _leadingSlot = 16 + Gap.xs;

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
      // LayoutBuilder so the fit test sees the real width the control was given,
      // not a guess. constraints.maxWidth here is already inside the padding.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = _fitsHorizontally(context, constraints.maxWidth);
          final segments = [
            for (final o in options) _segment(context, o, reduce),
          ];
          if (horizontal) {
            return Row(
              children: [for (final s in segments) Expanded(child: s)],
            );
          }
          // Full-width vertical stack: each segment gets the whole width, so a
          // long label wraps far later, and a tiny gap keeps them distinct.
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < segments.length; i++) ...[
                if (i > 0) const SizedBox(height: Gap.xxs),
                segments[i],
              ],
            ],
          );
        },
      ),
    );
  }

  /// Would the longest label fit on two lines inside a horizontal segment at
  /// the live text scale? If not, the caller stacks the control vertically.
  bool _fitsHorizontally(BuildContext context, double totalWidth) {
    if (totalWidth <= 0) return true; // nothing to measure yet
    final scaler = MediaQuery.textScalerOf(context);
    // Each segment gets an equal slice; inside it the label loses the reserved
    // leading slot and the segment's own horizontal padding (Gap.xs each side).
    final labelWidth =
        (totalWidth / options.length) - _leadingSlot - (Gap.xs * 2);
    if (labelWidth <= 0) return false;
    // Measure in the SAME font the label actually renders in. The rendered Text
    // sets no family, so it inherits the theme default (Jakarta), which runs a
    // touch wider than the test/OS default; measuring in the default font would
    // under-estimate the width and report "fits" when Jakarta would overflow and
    // clip. w700 is the selected (widest) weight, the worst case for either
    // caller.
    final style = DefaultTextStyle.of(context).style.copyWith(
      fontSize: _labelSize,
      height: 1.2,
      fontWeight: FontWeight.w700,
    );
    for (final o in options) {
      final tp = TextPainter(
        text: TextSpan(text: o.label, style: style),
        maxLines: 2,
        textScaler: scaler,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: labelWidth);
      if (tp.didExceedMaxLines) return false;
    }
    return true;
  }

  /// One tappable segment, identical in horizontal and vertical layouts.
  Widget _segment(BuildContext context, SegmentOption<T> o, bool reduce) {
    final selected = o.value == current;
    return Semantics(
      button: true,
      selected: selected,
      label: o.semanticLabel ?? o.label,
      // The onTap is not decoration, and leaving it off is the bug this control
      // shipped with inside Appearance.
      //
      // ExcludeSemantics strips the InkWell's tap ACTION along with its label,
      // so without this the node advertised "button, selected" and no way to
      // activate it. Flutter's own tap target guideline skips any node with
      // neither a tap nor a longPress action, so the control was not merely
      // unlabelled to a screen reader, it was INVISIBLE to the accessibility
      // test that was supposed to be checking it. The test passed with a 20
      // pixel target until this line existed.
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
              // 48, the Android floor. The consequence of a mis-tap on a
              // control like this is never small: on Appearance it repaints the
              // whole app, and on Utang it swaps the screen under your thumb.
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.xs,
                vertical: Gap.xs,
              ),
              decoration: BoxDecoration(
                color: selected ? Barako.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // The reserved leading slot. When selected it holds the check
                  // glyph (a SHAPE cue, so selection is never colour-only);
                  // when not, an equal-width spacer so every label wraps the
                  // same way regardless of which segment is selected.
                  if (selected) ...[
                    // Excluded from semantics because the Semantics wrapper
                    // above already announces the selected state, and a screen
                    // reader saying "check, Dark, selected" is noise.
                    Icon(salapifyIcon('check'), size: 16, color: Barako.onPrimary),
                    const SizedBox(width: Gap.xs),
                  ] else
                    const SizedBox(width: _leadingSlot),
                  Flexible(
                    child: Text(
                      o.label,
                      textAlign: TextAlign.center,
                      // Wraps rather than clips. A label that has run out of
                      // room should get taller, not vanish.
                      maxLines: 2,
                      // Anchored to AppText.label, but size stays pinned to
                      // _labelSize (the same constant the fit math at build()
                      // measures with) and weight/height/color are preserved
                      // exactly, so the segmented layout metric does not move.
                      style: AppText.label.copyWith(
                        color: selected
                            ? Barako.onPrimary
                            : Barako.textSecondary,
                        fontSize: _labelSize,
                        height: 1.2,
                        fontWeight: selected
                            ? TypeWeight.bold
                            : TypeWeight.medium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
