// Money Mindset Phase 5's new, Flutter-only purchase math: turning a
// recurring subscription amount into its monthly and annual size, and
// weighing a purchase against an existing savings goal. Nothing here has an
// RN counterpart (Phase 5 is a Flutter-first feature), so nothing here is
// golden-locked; it is exercised directly by mindset_purchase_test.dart, the
// same way mindset_waiting.dart's own header explains for the Waiting queue.
//
// Every function here is read-only: none of them ever change a goal, a
// debt, a budget, or an account. They only describe what a purchase would
// mean, the same decision-support contract the rest of this screen keeps.
// The true cost of a credit or BNPL plan already has its own tested engine
// (bnpl.dart's bnplCost), so this file does not duplicate it; the screen
// calls that directly.

import 'goal_plan.dart' show goalWhatIf, requiredContribution;
import 'ledger.dart' show amountOf;

/// How many times a year a subscription bills, by its chosen frequency.
/// An unrecognized frequency falls back to monthly (12) rather than
/// throwing, the same forgiving-input contract every other money parser in
/// this app keeps.
const Map<String, double> _billsPerYear = {
  'weekly': 52,
  'monthly': 12,
  'quarterly': 4,
  'annual': 1,
};

/// The monthly and annual size of a recurring [amount] billed at
/// [frequency]. A non-positive or non-finite amount reads as nothing to
/// show (both zero), matching every other optional money field on this
/// screen rather than throwing on a blank or half-typed field.
Map<String, double> subscriptionEquivalents(double amount, String frequency) {
  if (!(amount > 0) || !amount.isFinite) {
    return const {'monthly': 0, 'annual': 0};
  }
  final perYear = _billsPerYear[frequency] ?? 12;
  final annual = amount * perYear;
  return {'monthly': annual / 12, 'annual': annual};
}

/// The pesos, percent, and (only when reliable) time cost of spending
/// [purchaseAmount] on this instead of putting it toward [goal]. Null
/// whenever the comparison would say nothing real: no goal picked, no
/// usable amount, or a goal that is already fully funded (nothing left to
/// trade off against).
///
/// The delay estimate reuses goal_plan.dart's own requiredContribution and
/// goalWhatIf, the tested engine Goals and Insights already show a person,
/// so this never invents a second way to project a goal date. It stays null
/// unless that engine already has a real deadline and a real contribution
/// amount for this goal; a goal with no deadline has no honest "how much
/// later" to give, so the caller omits it rather than guessing (per the
/// founder's rule: an estimate must be explainable or absent).
Map<String, dynamic>? goalTradeoff({
  required Map<String, dynamic>? goal,
  required double? purchaseAmount,
  required DateTime now,
}) {
  if (goal == null) return null;
  final amount = purchaseAmount;
  if (amount == null || !(amount > 0) || !amount.isFinite) return null;
  final target = amountOf(goal['target']);
  final saved = amountOf(goal['saved']);
  final remaining = target - saved;
  if (!(remaining > 0)) return null;

  Map<String, dynamic>? delay;
  final contribution = requiredContribution(goal, now);
  final perPeriod = amountOf(contribution['amount']);
  if (contribution['hasDeadline'] == true && perPeriod > 0) {
    final frequency = contribution['frequency'] as String;
    // Same pace, same frequency, projected against the target this goal
    // already has versus one that is [amount] bigger: the difference in
    // periods is how much later that pace would finish, without ever
    // touching the goal's own stored saved or target.
    final without = goalWhatIf(
      goal,
      now,
      perPeriod: perPeriod,
      frequency: frequency,
    );
    final delayed = goalWhatIf(
      {...goal, 'target': target + amount},
      now,
      perPeriod: perPeriod,
      frequency: frequency,
    );
    if (without != null && delayed != null) {
      final extraPeriods =
          (delayed['periods'] as int) - (without['periods'] as int);
      if (extraPeriods > 0) {
        delay = {'periods': extraPeriods, 'frequency': frequency};
      }
    }
  }

  final rawName = goal['name'];
  final name = (rawName is String && rawName.trim().isNotEmpty)
      ? rawName.trim()
      : 'this goal';
  return {
    'goalName': name,
    'remaining': remaining,
    'purchaseAmount': amount,
    'percentOfRemaining': amount / remaining * 100,
    'delay': delay,
  };
}
