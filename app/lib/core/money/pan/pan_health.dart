/// A financial health check, scored out of what can actually be measured.
///
/// Ported in intent from `computeFinancialHealthScore` in
/// src/utils/panAiEngine.ts, with two changes that are the whole reason this
/// file is longer than its original.
///
/// ## It never invents a number to score against
///
/// The prototype reads `c.creditLimit || 40000`, so a card with no limit
/// recorded is scored against a forty thousand peso limit nobody entered. A
/// person with one card and no limit set gets a utilisation percentage
/// computed from a figure Salapify made up, and then a rating built on it.
/// That is the single worst thing a money app can do, because the output
/// looks exactly like a measurement.
///
/// Here a component that cannot be measured is EXCLUDED, and the score is
/// expressed over the components that could be. Four out of four is a
/// fuller picture than three out of four, and the answer says which is which
/// rather than quietly filling the gap.
///
/// ## It reports, it does not prescribe
///
/// The prototype's advice list says to grow savings in named digital banks,
/// to pay down cards, to prioritise home meals. Those are instructions about
/// somebody's money from an app not licensed to give them. Every observation
/// here names what the figure IS and what it means, and stops.
library;

import '../../../models/models.dart';
import '../format.dart';
import 'pan_context.dart';

/// One measured part of the picture.
class HealthPart {
  const HealthPart({
    required this.name,
    required this.points,
    required this.outOf,
    required this.reading,
    this.note,
  });

  final String name;

  final int points;
  final int outOf;

  /// The figure itself, in words, so the answer can show the measurement and
  /// not only the mark. "1.4 months of cover" tells somebody more than "20".
  final String reading;

  /// Why it scored what it did, when that is not obvious.
  final String? note;
}

class HealthCheck {
  const HealthCheck({
    required this.parts,
    required this.unmeasured,
    required this.observations,
  });

  final List<HealthPart> parts;

  /// Parts that could not be measured, and what is missing for each. Shown,
  /// never hidden: a score that quietly covers three quarters of the picture
  /// reads as if it covered all of it.
  final List<({String name, String missing})> unmeasured;

  final List<String> observations;

  bool get measurable => parts.isNotEmpty;

  int get earned => parts.fold(0, (int s, HealthPart p) => s + p.points);
  int get possible => parts.fold(0, (int s, HealthPart p) => s + p.outOf);

  /// Zero to one hundred, over what was measured.
  int get score => possible == 0 ? 0 : ((earned / possible) * 100).round();

  /// The part carrying the most strain, by share of its own maximum.
  ///
  /// A total hides this. Three strong parts and one bad one average out to a
  /// number that reads as fine, and the one bad part is the whole reason
  /// somebody asked.
  HealthPart? get weakest {
    if (parts.isEmpty) return null;
    HealthPart worst = parts.first;
    for (final HealthPart p in parts) {
      if (p.points / p.outOf < worst.points / worst.outOf) worst = p;
    }
    return worst;
  }

  /// Plain words for the score. Deliberately descriptive rather than
  /// congratulatory: this is a reading, not a grade, and somebody at 48
  /// should not be told they have failed at anything.
  ///
  /// THE WEAKEST PART OVERRIDES THE TOTAL, and that rule came from looking at
  /// the rendered screen. A real ledger scored 85 and the badge read
  /// "Comfortable on every part measured" directly above a line saying "You
  /// owe more than you hold" and a row reading 5 of 20. Both were correct and
  /// together they were a lie, because an average is not a statement about
  /// every part. Nothing in 879 passing tests could see it; a screenshot
  /// showed it in a second.
  String get reading {
    if (!measurable) return 'Not enough recorded yet';

    final HealthPart? w = weakest;
    if (w != null && w.points / w.outOf <= 0.35) {
      return 'Stretched on ${w.name.toLowerCase()}';
    }

    if (score >= 80) return 'Comfortable on every part measured';
    if (score >= 65) return 'Sound, with one part under pressure';
    if (score >= 50) return 'Thin cushion';
    return 'Under pressure';
  }
}

HealthCheck runHealthCheck(PanFacts facts) {
  final List<HealthPart> parts = <HealthPart>[];
  final List<({String name, String missing})> missing =
      <({String name, String missing})>[];
  final List<String> notes = <String>[];

  _cover(facts, parts, missing, notes);
  _cardUse(facts, parts, missing, notes);
  _dailyPace(facts, parts, missing, notes);
  _owedAgainstHeld(facts, parts, missing, notes);

  // Receivables are not a score, they are a fact worth surfacing: money owed
  // to somebody is theirs and is not in their buffer.
  if (facts.owedToMe > 0) {
    notes.add(
      'Separately, ${formatPeso(facts.owedToMe)} is owed to you. It is yours and '
      'it is not in the figures above, because it is not on this phone yet.',
    );
  }

  return HealthCheck(parts: parts, unmeasured: missing, observations: notes);
}

/// How long the cash on hand would last. The app's own runway figure, not a
/// second estimate: two screens disagreeing about the same month is a defect
/// even when both are defensible.
void _cover(
  PanFacts facts,
  List<HealthPart> parts,
  List<({String name, String missing})> missing,
  List<String> notes,
) {
  if (facts.accounts.isEmpty) {
    missing.add((name: 'Cover', missing: 'no accounts recorded yet'));
    return;
  }

  final double months = facts.cashRunwayMonths;
  final int points = months >= 3
      ? 30
      : months >= 1
      ? 20
      : months >= 0.5
      ? 15
      : 10;

  parts.add(
    HealthPart(
      name: 'Cover',
      points: points,
      outOf: 30,
      reading: '${months.toStringAsFixed(1)} months of spending held in cash',
    ),
  );

  if (months < 1) {
    notes.add(
      'Under a month of cover means one unexpected bill lands on the same '
      'money as the groceries.',
    );
  }
}

/// Card balances against the limits that were actually entered.
void _cardUse(
  PanFacts facts,
  List<HealthPart> parts,
  List<({String name, String missing})> missing,
  List<String> notes,
) {
  final List<Account> cards = facts.accounts
      .where((Account a) => a.kind == AccountKind.credit)
      .toList();

  if (cards.isEmpty) {
    // NOT a full mark, and not a gap either. Somebody with no card has no
    // card risk, so the part is simply not part of their picture.
    missing.add((name: 'Card use', missing: 'no credit cards recorded'));
    return;
  }

  final List<Account> withLimits = cards
      .where((Account c) => (c.creditLimit ?? 0) > 0)
      .toList();

  if (withLimits.isEmpty) {
    missing.add((
      name: 'Card use',
      missing: 'no credit limit entered on any card',
    ));
    return;
  }

  final double limit = withLimits.fold(
    0,
    (double s, Account c) => s + (c.creditLimit ?? 0),
  );
  // A card balance is stored NEGATIVE when money is owed on it, which is why
  // this takes the absolute value of the negative side only. Reading the
  // stored sign straight through reported a maxed card as zero used.
  final double used = withLimits.fold(
    0,
    (double s, Account c) => s + (c.balance < 0 ? -c.balance : 0),
  );
  final double percent = (used / limit) * 100;

  final int points = percent <= 15
      ? 25
      : percent <= 30
      ? 20
      : percent <= 50
      ? 12
      : 5;

  parts.add(
    HealthPart(
      name: 'Card use',
      points: points,
      outOf: 25,
      reading: '${percent.round()}% of the limits you have entered',
      note: withLimits.length < cards.length
          ? '${cards.length - withLimits.length} of your cards have no limit '
                'entered, so they are left out of this.'
          : null,
    ),
  );

  if (percent > 30) {
    notes.add(
      'Card use above 30% of a limit is the level most lenders read as '
      'stretched. It is a rule of thumb, not a rule.',
    );
  }
}

void _dailyPace(
  PanFacts facts,
  List<HealthPart> parts,
  List<({String name, String missing})> missing,
  List<String> notes,
) {
  if (facts.payday.daysToPayday <= 0) {
    missing.add((name: 'Daily pace', missing: 'no payday cycle set'));
    return;
  }

  final double perDay = facts.safeToSpendPerDay;
  final int points = perDay >= 500
      ? 25
      : perDay >= 300
      ? 20
      : perDay >= 150
      ? 12
      : 5;

  parts.add(
    HealthPart(
      name: 'Daily pace',
      points: points,
      outOf: 25,
      reading:
          '${formatPeso(perDay)} a day for the '
          '${facts.payday.daysToPayday} days to payday',
    ),
  );
}

void _owedAgainstHeld(
  PanFacts facts,
  List<HealthPart> parts,
  List<({String name, String missing})> missing,
  List<String> notes,
) {
  if (facts.assets <= 0 && facts.liabilities <= 0) {
    missing.add((name: 'What you owe', missing: 'nothing recorded either way'));
    return;
  }

  if (facts.assets <= 0) {
    parts.add(
      HealthPart(
        name: 'What you owe',
        points: 5,
        outOf: 20,
        reading: '${formatPeso(facts.liabilities)} owed, against nothing held',
      ),
    );
    return;
  }

  final double ratio = facts.liabilities / facts.assets;
  final int points = ratio <= 0.2
      ? 20
      : ratio <= 0.4
      ? 16
      : ratio <= 0.7
      ? 12
      : 5;

  parts.add(
    HealthPart(
      name: 'What you owe',
      points: points,
      outOf: 20,
      reading:
          '${(ratio * 100).round()} pesos owed for every 100 pesos you hold',
    ),
  );

  if (ratio > 1) {
    notes.add(
      'You owe more than you hold. A housing loan alone can do this, and it '
      'is not the same thing as being in trouble.',
    );
  }
}
