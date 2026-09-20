import 'dart:math' as math;

import 'js_round.dart';

/// Splitting a 13th month or year-end bonus, after the tax on it.
///
/// Founder spec, 2026-09-20, feature 3. The TRAIN arithmetic and the 50 / 30
/// / 20 split are the spec's.
///
/// ## It shares the ceiling with the calculator already in the app
///
/// `calculate13thMonthPay` in ph_tax.dart has done this tax since the tax
/// batch, with the same 90,000 ceiling and the same 0.20 marginal rate, and
/// it is locked by golden vectors. Writing a second 90000 here is how two
/// screens end up disagreeing about one person's December, so the constant
/// is declared once and both read it.
///
/// The two take DIFFERENT INPUTS on purpose and that is the whole reason this
/// exists. The calculator starts from a basic monthly salary and works the
/// 13th month out; this starts from a figure somebody was actually told they
/// are getting, which is what a person has in November when the number comes
/// down from HR and is not one twelfth of anything tidy.
///
/// ## What is deliberately NOT here
///
/// The spec routes the first bucket to "SeaBank, Maya, Pag-IBIG MP2". Those
/// names do not appear, and the omission is not squeamishness. An app that
/// reads your balance and then tells you which named institution to move it
/// to is doing the thing an investment adviser is registered to do, and
/// `pan_bans.dart` already fails the build over exactly this wording
/// everywhere Pan can reach. A bucket says what the money is FOR. Where to
/// put it is the person's to choose.

/// The TRAIN ceiling: 13th month pay and other benefits are exempt from
/// income tax up to this much, per year, in total.
///
/// RA 10963 raised it from 82,000 to 90,000. It is a COMBINED annual figure
/// covering the 13th month and other benefits together, not a fresh
/// allowance per payment, which is why the screen says so rather than
/// implying a clean slate.
const double trainBenefitsExemptCeiling = 90000;

/// The rate used for the taxable excess.
///
/// The same 0.20 `calculate13thMonthPay` already defaults to, so the two
/// agree. It is a STAND-IN for graduated withholding rather than a rate
/// anybody is charged by name: the real figure depends on the band the
/// excess lands in, and the screen says the word "roughly" out loud.
const double bonusMarginalRateAssumption = 0.20;

/// One share of the bonus.
class BonusBucket {
  const BonusBucket({
    required this.id,
    required this.name,
    required this.percent,
    required this.amount,
    required this.purpose,
  });

  final String id;
  final String name;
  final int percent;
  final double amount;

  /// What the money is FOR, in plain words. Never where to put it.
  final String purpose;
}

/// A bonus, what the tax takes, and where the rest could go.
class BonusPlan {
  const BonusPlan({
    required this.bonus,
    required this.taxExempt,
    required this.taxable,
    required this.estimatedTax,
    required this.net,
    required this.buckets,
  });

  final double bonus;

  /// The part under the ceiling, which is not taxed.
  final double taxExempt;

  /// The part above it, which is.
  final double taxable;

  final double estimatedTax;
  final double net;
  final List<BonusBucket> buckets;

  /// How much of the exemption this bonus uses, 0 to 1, for the bar.
  double get exemptUsed =>
      bonus <= 0 ? 0 : (taxExempt / trainBenefitsExemptCeiling).clamp(0.0, 1.0);

  bool get isFullyExempt => taxable <= 0;

  /// True when the whole allowance is spoken for by this bonus alone.
  bool get ceilingReached => taxExempt >= trainBenefitsExemptCeiling;
}

/// The default split, named once so changing it is one edit.
///
/// Fifty to a cushion, thirty to debt, twenty to Christmas. The last bucket
/// is the one that makes the other two survive contact with December: a plan
/// that allocates nothing to Pamasko gets abandoned in the first week of
/// gift-buying, and then the whole bonus goes.
const int bonusEmergencyPercent = 50;
const int bonusDebtPercent = 30;
const int bonusTreatsPercent = 20;

BonusPlan allocateBonus({
  required double bonus,
  double marginalRate = bonusMarginalRateAssumption,
  double benefitsAlreadyReceived = 0,
}) {
  final double gross = math.max(0, bonus);

  // WHAT IS LEFT OF THE ALLOWANCE, not the whole of it.
  //
  // The 90,000 covers the 13th month AND other benefits for the year
  // together. Somebody who has already had a 30,000 performance bonus has
  // 60,000 of room left, and treating the ceiling as fresh would tell them a
  // 90,000 13th month is entirely tax free when a third of it is not.
  //
  // Defaults to zero, so the ordinary case is the spec's arithmetic exactly,
  // and the screen can ask when it matters.
  final double roomLeft = math.max(
    0,
    trainBenefitsExemptCeiling - math.max(0, benefitsAlreadyReceived),
  );

  final double exempt = math.min(gross, roomLeft);
  final double taxable = math.max(0, gross - exempt);
  final double tax = jsRound(taxable * marginalRate).toDouble();
  final double net = gross - tax;

  return BonusPlan(
    bonus: gross,
    taxExempt: exempt,
    taxable: taxable,
    estimatedTax: tax,
    net: net,
    buckets: <BonusBucket>[
      BonusBucket(
        id: 'cushion',
        name: 'Cushion',
        percent: bonusEmergencyPercent,
        amount: jsRound(net * bonusEmergencyPercent / 100).toDouble(),
        purpose:
            'Money you do not touch, for the month something goes wrong. '
            'A bonus is the one time of year this can grow in one step.',
      ),
      BonusBucket(
        id: 'debt',
        name: 'Debt',
        percent: bonusDebtPercent,
        amount: jsRound(net * bonusDebtPercent / 100).toDouble(),
        purpose:
            'Whatever costs you the most to keep. Paying it down is the only '
            'guaranteed return on this page.',
      ),
      BonusBucket(
        id: 'pamasko',
        name: 'Pamasko and treats',
        percent: bonusTreatsPercent,
        amount: jsRound(net * bonusTreatsPercent / 100).toDouble(),
        purpose:
            'Spent on purpose and without guilt. A plan with nothing here '
            'is the plan people abandon in the first week of December.',
      ),
    ],
  );
}

/// The quick amounts the card offers, from the spec.
const List<double> bonusQuickAmounts = <double>[
  25000,
  50000,
  75000,
  90000,
  120000,
];
