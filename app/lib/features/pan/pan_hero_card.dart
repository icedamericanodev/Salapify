import 'package:flutter/material.dart';

import '../../core/money/pan/pan_context.dart';
import '../../core/money/format.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';

/// The Pan card on Home, showing the most relevant thing it could tell you.
///
/// Ported from `src/components/PanHeroCard.tsx`, which is an orphan in the
/// prototype: the component exists and App.tsx never renders it. So the
/// placement here is a decision rather than a port, and it sits under the
/// quick actions, where a card that leads somewhere belongs.
///
/// Three things did not come across, and each for the same reason.
///
/// "Pan Copilot" claims a category of product Salapify does not have. There
/// is no model behind any of this; every answer is a keyword match and some
/// arithmetic, and dressing that as a copilot makes the answers feel more
/// authoritative than they have earned.
///
/// "100% PRIVATE" is an absolute claim, and `truthful_claims_test.dart` fails
/// the build on one. The currency converter makes a request, so the honest
/// badge is the same one the header uses.
///
/// The emoji on its three chips are OS-drawn stickers the palette cannot
/// reach and that change shape between phones. Salapify's own icons are
/// Material glyphs in the accent, which is why the chips here carry none.
///
/// What it DOES do that the prototype's does not is change with the ledger.
/// A card that says the same sentence every day stops being read by the end
/// of the first week, and the whole point of it is to be the thing somebody
/// glances at.
class PanHeroCard extends StatelessWidget {
  const PanHeroCard({
    super.key,
    required this.palette,
    required this.facts,
    required this.onAsk,
  });

  final Palette palette;
  final PanFacts facts;

  /// Opens Pan. With a question, that question is already asked; without
  /// one, Pan opens on its own introduction.
  final void Function(String? question) onAsk;

  @override
  Widget build(BuildContext context) {
    final _Teaser t = _teaserFor(facts);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onAsk(null),
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(Radii.tile),
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: palette.onAccent,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Ask Pan', style: AppType.rowTitle(palette)),
                        const SizedBox(height: 2),
                        Text(
                          t.line,
                          style: AppType.rowMeta(palette),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: palette.accent),
                ],
              ),
              const SizedBox(height: Spacing.md),
              // Wrap rather than a horizontal scroller. The prototype's row
              // scrolls sideways, which hides the third chip behind a gesture
              // nobody knows is there; at 320dp with large text these need to
              // be able to stack instead.
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: <Widget>[
                  for (final String q in t.chips)
                    _Chip(palette: palette, label: q, onTap: () => onAsk(q)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Teaser {
  const _Teaser(this.line, this.chips);
  final String line;
  final List<String> chips;
}

/// The one sentence worth putting on Home right now.
///
/// Ordered by what would actually change somebody's next hour. A bill landing
/// before payday beats a Safe to Spend figure, because the figure already has
/// the bill inside it and the bill is the thing they have not thought about.
_Teaser _teaserFor(PanFacts facts) {
  if (facts.accounts.isEmpty) {
    return const _Teaser(
      'Nothing recorded yet. Ask what Salapify does with what you add.',
      <String>['What happens when I log an expense?', 'Is my data private?'],
    );
  }

  final List<BillItem> soon = _dueBeforePayday(facts);
  if (soon.isNotEmpty) {
    final double total = soon.fold(0, (double s, BillItem b) => s + b.amount);
    return _Teaser(
      '${formatPeso(total)} of bills land before your next payday',
      const <String>[
        'What bills are due?',
        'What is safe to spend?',
        'How am I doing?',
      ],
    );
  }

  if (facts.payday.daysToPayday > 0) {
    return _Teaser(
      '${formatPeso(facts.safeToSpendUntilPayday)} safe to spend, '
      '${facts.payday.daysToPayday} '
      '${facts.payday.daysToPayday == 1 ? 'day' : 'days'} to payday',
      const <String>[
        'What is safe to spend?',
        'How am I doing?',
        'Who owes me money?',
      ],
    );
  }

  // No payday set, so no daily pace and no horizon. Say what is true rather
  // than borrowing a sentence that needs a date nobody gave us.
  return _Teaser(
    '${formatPeso(facts.liquidCash)} in cash. No payday set yet.',
    const <String>[
      'How much do I have right now?',
      'How am I doing?',
      'Where did my money go?',
    ],
  );
}

List<BillItem> _dueBeforePayday(PanFacts facts) {
  final int days = facts.payday.daysToPayday;
  if (days <= 0) return const <BillItem>[];
  final DateTime today = DateTime(
    facts.now.year,
    facts.now.month,
    facts.now.day,
  );
  final DateTime horizon = today.add(Duration(days: days));

  return facts.bills.where((BillItem b) {
    if (b.isPaid) return false;
    final DateTime? d = DateTime.tryParse(b.dueDate);
    if (d == null) return false;
    final DateTime day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(today) && !day.isAfter(horizon);
  }).toList();
}

class _Chip extends StatelessWidget {
  const _Chip({
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
          // 44, the smallest a finger reliably hits. The prototype's chips
          // are about 24 high, which is fine with a mouse and is a miss on a
          // phone held in one hand on a jeepney.
          // NO alignment, and no minHeight constraint either. Both were
          // here and together they are the trap this app has now fallen
          // into six times: a Container with an alignment and no width
          // fills every pixel it is offered, so three chips became three
          // full width bars stacked down the card. Padding gives the height
          // instead, and it grows with the text size rather than against
          // it.
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: palette.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: palette.border),
          ),
          child: Text(label, style: AppType.rowMeta(palette)),
        ),
      ),
    );
  }
}
