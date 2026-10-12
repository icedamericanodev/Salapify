import 'package:flutter/material.dart';

import '../../design/motion.dart';
import '../../design/tokens.dart';

/// The five shortcuts. Four of them are ported from
/// archive/prototype-google-ai-studio/src/components/QuickActions.tsx.
///
/// Log, Debt, Bills, Move, in that order, with Log filled in the accent. An
/// earlier pass guessed this set and got it wrong; the order and the wording
/// are the prototype's.
///
/// SPLIT IS THE FIFTH, and it is here on founder direction, 2026-10-01. It
/// first shipped as a card inside the debts register, and the comment
/// justifying that placement argued a fifth shortcut "would crowd it on a
/// narrow phone". That was reasoning, not measuring, and the founder went
/// looking for the feature the way anybody would, did not find it, and said
/// move it. Splitting a bill happens at a table with people waiting, which is
/// the worst possible moment to need a scroll and three taps.
class QuickActions extends StatelessWidget {
  const QuickActions({
    super.key,
    required this.palette,
    this.onLog,
    this.onDebt,
    this.onBills,
    this.onMove,
    this.onSplit,
  });

  final Palette palette;
  final VoidCallback? onLog;
  final VoidCallback? onDebt;
  final VoidCallback? onBills;
  final VoidCallback? onMove;
  final VoidCallback? onSplit;

  @override
  Widget build(BuildContext context) {
    final List<_Action> actions = <_Action>[
      _Action('Log', Icons.add, onLog, highlight: true),
      _Action('Debt', Icons.volunteer_activism_outlined, onDebt),
      _Action('Bills', Icons.receipt_long_outlined, onBills),
      _Action('Move', Icons.swap_horiz, onMove),
      // The same glyph the Split a bill sheet opens with, so the shortcut and
      // the thing it opens are recognisably one feature.
      _Action('Split', Icons.groups_outlined, onSplit),
    ];

    return Row(
      children: <Widget>[
        for (final _Action a in actions)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
              child: _QuickActionButton(palette: palette, action: a),
            ),
          ),
      ],
    );
  }
}

class _Action {
  const _Action(this.label, this.icon, this.onTap, {this.highlight = false});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool highlight;
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.palette, required this.action});

  final Palette palette;
  final _Action action;

  @override
  Widget build(BuildContext context) {
    // The tile asks for 52 and TAKES WHAT IT IS GIVEN, which is the whole
    // reason a fifth shortcut needed no layout work.
    //
    // This started out as a LayoutBuilder that shrank the tile by hand,
    // written on the arithmetic that at 320dp the row has 288 to give out, a
    // fifth slot gets 57.6, 8 of that is the slot's own padding, and a 52 box
    // in 49.6 is a 2.4 pixel overflow. The arithmetic is right and the
    // conclusion is wrong: `Container(width: 52)` resolves to a tight
    // constraint ENFORCED against the parent's, so Flutter clamps it to 49.6
    // and nothing overflows. The deliberate break that was supposed to prove
    // the shrinking mattered passed with the shrinking removed, which is how
    // this was caught.
    //
    // What that costs at 320dp is a tile 49.6 wide by 52 tall instead of a
    // square, and a 2.4 pixel difference is not worth a widget that has to be
    // explained. It stays above the 44 touch floor, which the test asserts.
    final Color background = action.highlight
        ? palette.accent
        : palette.surface;
    final Color foreground = action.highlight
        ? palette.onAccent
        : palette.textSecondary;

    return Pressable(
      child: Semantics(
        button: true,
        label: action.label,
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(Radii.control),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(Radii.control),
                  border: Border.all(
                    color: action.highlight
                        ? Colors.transparent
                        : palette.border,
                  ),
                ),
                child: Icon(action.icon, size: 20, color: foreground),
              ),
              const SizedBox(height: 6),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
