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
  const PanMessage.you(this.text)
    : fromPan = false,
      answer = null,
      badge = null,
      points = const <String>[];
  const PanMessage.pan(this.text, {this.badge, this.points = const <String>[]})
    : fromPan = true,
      answer = null;
  PanMessage.answer(PanAnswer a)
    : fromPan = true,
      answer = a,
      badge = a.badge,
      points = a.points,
      // The LEAD, not the display. display concatenates the lead, the
      // bullets, the More text and the trailer into one string for the
      // content guards to scan, and using it here printed every one of them
      // twice: once as a paragraph and again as the parts. A render caught
      // that in a second; no test could, because both halves were correct.
      text = a.text;

  final String text;
  final bool fromPan;
  final PanAnswer? answer;

  /// The short lines, carried on the message rather than read off [answer],
  /// so a RESTORED message shows them too. A restored one has no PanAnswer
  /// behind it by design.
  final List<String> points;

  /// Kept apart from [answer] so a RESTORED message can still carry its
  /// label. A conversation put back from disk has no PanAnswer behind it,
  /// deliberately: recomputing yesterday's figures today would print a stale
  /// peso amount that looks exactly like a current one.
  final String? badge;
}

class PanMessageBubble extends StatefulWidget {
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
  State<PanMessageBubble> createState() => _PanMessageBubbleState();
}

class _PanMessageBubbleState extends State<PanMessageBubble> {
  /// Collapsed on arrival, always. The whole point of the split is that the
  /// part somebody reads once is not in front of them on every visit after
  /// the first.
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final Palette palette = widget.palette;
    final PanMessage message = widget.message;
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
            if (message.badge != null) ...<Widget>[
              _Badge(palette: palette, label: message.badge!),
              const SizedBox(height: Spacing.sm),
            ],
            Text(
              message.text,
              style: pan
                  ? AppType.body(palette).copyWith(color: palette.textPrimary)
                  : AppType.body(palette).copyWith(color: palette.onAccent),
            ),
            // SHORT LINES, one idea each, instead of paragraphs. Prose on a
            // phone is skipped; a list is scanned. The dot is a character
            // rather than a bullet widget because a Row per line would
            // stop the text wrapping under itself.
            if (message.points.isNotEmpty) ...<Widget>[
              const SizedBox(height: Spacing.sm),
              for (final String point in message.points)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '•  ',
                        style: AppType.body(
                          palette,
                        ).copyWith(color: palette.accent),
                      ),
                      Expanded(
                        child: Text(
                          point,
                          style: AppType.body(
                            palette,
                          ).copyWith(color: palette.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (a?.more != null) ...<Widget>[
              const SizedBox(height: Spacing.sm),
              _MoreToggle(
                palette: palette,
                open: _open,
                onTap: () => setState(() => _open = !_open),
              ),
              if (_open)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.sm),
                  child: Text(
                    a!.more!,
                    style: AppType.body(
                      palette,
                    ).copyWith(color: palette.textSecondary),
                  ),
                ),
            ],
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
            // The trailer, small and last, rather than another paragraph in
            // the body. It has to be on screen and it is not the answer.
            if (a != null && a.aboutMoney) ...<Widget>[
              const SizedBox(height: Spacing.md),
              Text(PanAnswer.trailer, style: AppType.caption(palette)),
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
                      onTap: () => widget.onAction(act.id),
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
          // Padding rather than an alignment plus a minHeight. The pair
          // makes a Container fill its whole offered width, which turned two
          // side by side buttons into two stacked bars. 13 top and bottom on
          // an 18 point line is 44, the smallest a finger reliably hits, and
          // it scales up with the system font instead of clipping.
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: 13,
          ),
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

/// Opens the part that is read once and then skipped forever.
class _MoreToggle extends StatelessWidget {
  const _MoreToggle({
    required this.palette,
    required this.open,
    required this.onTap,
  });

  final Palette palette;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  open ? 'Less' : 'More',
                  style: AppType.rowMeta(palette).copyWith(
                    color: palette.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: palette.accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
