import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// The four shortcuts, ported from src/components/QuickActions.tsx.
///
/// Log, Debt, Bills, Move, in that order, with Log filled in the accent. An
/// earlier pass guessed this set and got it wrong; the order and the wording
/// are the prototype's.
class QuickActions extends StatelessWidget {
  const QuickActions({
    super.key,
    required this.palette,
    this.onLog,
    this.onDebt,
    this.onBills,
    this.onMove,
  });

  final Palette palette;
  final VoidCallback? onLog;
  final VoidCallback? onDebt;
  final VoidCallback? onBills;
  final VoidCallback? onMove;

  @override
  Widget build(BuildContext context) {
    final List<_Action> actions = <_Action>[
      _Action('Log', Icons.add, onLog, highlight: true),
      _Action('Debt', Icons.volunteer_activism_outlined, onDebt),
      _Action('Bills', Icons.receipt_long_outlined, onBills),
      _Action('Move', Icons.swap_horiz, onMove),
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
    final Color background = action.highlight
        ? palette.accent
        : palette.surface;
    final Color foreground = action.highlight
        ? palette.onAccent
        : palette.textSecondary;

    return Semantics(
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
                  color: action.highlight ? Colors.transparent : palette.border,
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
    );
  }
}
