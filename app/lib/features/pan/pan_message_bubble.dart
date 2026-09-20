import 'package:flutter/material.dart';

import '../../core/money/pan/pan_engine.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// One message in the Pan conversation.
///
/// Four parts, and the order is the point: a BADGE saying what kind of answer
/// this is, the SENTENCE, the FIGURES as rows, and then anywhere the answer
/// leads. A figure inside a paragraph is read; a figure in a row is seen, and
/// the figures are usually the reason somebody asked.
///
/// The prototype's badges included "Financial Coach" and "CPA & Tax
/// Advisory". Neither came across. A badge here says what the ANSWER is, never
/// who is speaking, because a professional title Salapify has not got changes
/// how much weight a reader gives everything under it.
class PanMessage {
  const PanMessage.you(this.text) : fromPan = false, answer = null;
  const PanMessage.pan(this.text) : fromPan = true, answer = null;
  PanMessage.answer(PanAnswer a) : fromPan = true, answer = a, text = a.display;

  final String text;
  final bool fromPan;
  final PanAnswer? answer;
}

class PanMessageBubble extends StatelessWidget {
  const PanMessageBubble({
    super.key,
    required this.palette,
    required this.message,
    required this.onAction,
  });

  final Palette palette;
  final PanMessage message;

  /// Called with an id from `panActionIds`. The bubble knows nothing about
  /// screens, and the engine knows nothing about widgets; the sheet is the
  /// only place the two meet.
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final bool pan = message.fromPan;
    final PanAnswer? a = message.answer;

    return Align(
      alignment: pan ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: pan ? palette.surfaceAlt : palette.accent,
          borderRadius: BorderRadius.circular(Radii.tile),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (a?.badge != null) ...<Widget>[
              _Badge(palette: palette, label: a!.badge!),
              const SizedBox(height: Spacing.sm),
            ],
            Text(
              message.text,
              style: pan
                  ? AppType.body(palette).copyWith(color: palette.textPrimary)
                  : AppType.body(palette).copyWith(color: palette.onAccent),
            ),
            if (a != null && a.figures.isNotEmpty) ...<Widget>[
              const SizedBox(height: Spacing.sm),
              for (final PanFigure f in a.figures)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(f.label, style: AppType.rowMeta(palette)),
                      ),
                      Text(f.value, style: AppType.amountSmall(palette)),
                    ],
                  ),
                ),
            ],
            if (a != null && a.actions.isNotEmpty) ...<Widget>[
              const SizedBox(height: Spacing.md),
              // Wrap, not Row. Two buttons at 320dp with a long label is the
              // shape that overflows, and this screen has no horizontal
              // scroll to absorb it.
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: <Widget>[
                  for (final PanAction act in a.actions)
                    _ActionButton(
                      palette: palette,
                      label: act.label,
                      onTap: () => onAction(act.id),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.palette, required this.label});

  final Palette palette;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Wrapped in an Align, because a Container with padding and no width
    // fills every pixel it is offered and the badge becomes a full width bar.
    // That has now happened five separate times in this app.
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          label,
          style: AppType.rowMeta(
            palette,
          ).copyWith(color: palette.accent, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.palette,
    required this.label,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          // 44 high, which is the smallest a finger reliably hits. A chat
          // bubble invites fast tapping and a 32dp target in a wall of text
          // is the one people miss.
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: palette.accent.withValues(alpha: 0.35)),
          ),
          child: Text(
            label,
            style: AppType.rowMeta(
              palette,
            ).copyWith(color: palette.accent, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
