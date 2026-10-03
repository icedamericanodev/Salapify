// The one shape for an insight: observation, meaning, way forward.
//
// Insights currently renders a wall of near-identical cards where the
// observation, the interpretation and the action run together as prose. The
// redesign of that screen is a later phase; this primitive exists NOW so the
// redesign lands on a shared shape instead of minting one mid-rewrite, the
// same order tokens-then-components the whole overhaul follows.
//
// The three slots are the discipline: an insight that cannot fill
// [observation] is not an insight, [meaning] is where the app earns its
// coach role (what the number says, not just the number), and the action is
// optional because not every observation deserves a button. Deliberately NOT
// adopted anywhere yet; the first adopters are the intelligence phase's
// business.

import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';
import 'salapify_icon.dart';

/// The emotional register of an insight, carried by the kicker's ink and
/// never by color alone (the words say what the color hints).
enum InsightTone {
  /// Ordinary reading: caramel, the inside-card kicker voice.
  neutral,

  /// Something going well: the accent voice.
  positive,

  /// Something needing a look: the warning voice. Reserved for genuine risk,
  /// never ordinary spending, same rule as everywhere else.
  attention,
}

class InsightCard extends StatelessWidget {
  /// The uppercase topic label ("FOOD SPENDING").
  final String kicker;

  /// What happened, with a number in it ("You spent ₱1,420 more on food.").
  final String observation;

  /// What it means ("Most of the increase came from delivery.").
  final String? meaning;

  /// The way forward. Both or neither of [actionLabel] and [onAction].
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Optional semantic icon name beside the kicker.
  final String? icon;

  /// Optional micro visualization between the meaning and the action.
  final Widget? visual;

  final InsightTone tone;

  // NOT const. build() reads mutable Barako getters. Same rule as every
  // shared widget here.
  // ignore: prefer_const_constructors_in_immutables
  InsightCard({
    super.key,
    required this.kicker,
    required this.observation,
    this.meaning,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.visual,
    this.tone = InsightTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final kickerInk = switch (tone) {
      InsightTone.neutral => Barako.caramel,
      InsightTone.positive => Barako.primaryText,
      InsightTone.attention => Barako.warning,
    };
    return Card(
      child: Padding(
        padding: Insets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  SalapifyGlyph(icon!, size: IconSizes.dense),
                  const SizedBox(width: Gap.sm),
                ],
                Expanded(
                  child: Text(
                    kicker,
                    style: Barako.kickerStyle.copyWith(color: kickerInk),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(observation, style: AppText.bodyStrong),
            if (meaning != null) ...[
              const SizedBox(height: Gap.xs),
              Text(meaning!, style: AppText.small),
            ],
            if (visual != null) ...[const SizedBox(height: Gap.md), visual!],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Gap.xs),
              // A text action, not a filled one: an insight suggests, the
              // screen's real CTA commands. Zero padding with a 48 minimum
              // keeps the left edge aligned without shrinking the target.
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 48),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One labelled figure, standalone or in a grouped band: `Income` over
/// `₱52,000`, with an optional delta line. The single-column sibling of
/// StatPair (section.dart); use StatPair when exactly two figures answer
/// one question.
class Metric extends StatelessWidget {
  final String label;
  final String value;

  /// Optional movement line under the value ("+₱4,200 vs June"). Words carry
  /// the direction; [deltaColor] only reinforces it.
  final String? delta;
  final Color? deltaColor;

  /// Tint for the value figure.
  final Color? valueColor;

  // NOT const. build() reads mutable Barako getters. Same rule as every
  // shared widget here.
  // ignore: prefer_const_constructors_in_immutables
  Metric({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.deltaColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.small.tint(Barako.muted)),
        const SizedBox(height: Gap.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: valueColor == null
                ? AppText.amountMetric
                : AppText.amountMetric.tint(valueColor!),
          ),
        ),
        if (delta != null) ...[
          const SizedBox(height: Gap.xxs),
          Text(delta!, style: AppText.caption.tint(deltaColor ?? Barako.muted)),
        ],
      ],
    );
  }
}
