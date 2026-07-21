// "Where your next peso should go": a sound order of operations for spare
// money. It reconciles the emergency cushion, the costliest debt, and goals
// into ONE ranked order so the app never quietly rewards finishing a gadget
// goal while a credit card compounds. Pure and offline; it composes three
// engines already locked to the RN app (safeToSpend, emergencyRunway,
// goalPace), and the composition itself is golden-locked in
// surplus_golden_test.dart against the executed RN engines. A guide, not a
// promise.

import 'analytics.dart' show emergencyRunway, goalPace;
import 'commitments.dart' show safeToSpend;
import 'ledger.dart' show amountOf;

/// Debt types that carry real interest in life. The store fills a missing rate
/// with 0, so a 0 rate on these almost always means the user never entered it,
/// not that the debt is free. An informal utang at 0% is left alone.
const Set<String> _interestBearingTypes = {'credit card', 'bnpl', 'loan'};

/// True when at least one still-funded, not-done goal exists, using the same
/// filter the Insights goal simulator uses (target > 0, not done, remaining
/// > 0). goalPace is already golden-locked, so this stays consistent to the peso.
bool _hasActiveGoal(dynamic goals, DateTime ref) {
  for (final g in (goals is List ? goals : const [])) {
    if (g is! Map) continue;
    final gm = g.cast<String, dynamic>();
    if (!(amountOf(gm['target']) > 0)) continue;
    final p = goalPace(gm, ref);
    if (p['done'] == true) continue;
    if (amountOf(p['remaining']) > 0) return true;
  }
  return false;
}

/// The reconciled plan for where the next spare peso should go. Returns the
/// primary `step` ('starter' | 'debt' | 'fuller' | 'goal' | 'set'), the pieces
/// behind it, and honesty flags. `applicable` is false on a truly empty app,
/// so the card hides until there is something to reason about.
Map<String, dynamic> nextPesoPlan(Map<String, dynamic> data, DateTime ref) {
  final sts = safeToSpend(data, ref);
  final runway = emergencyRunway(data, ref);
  final spare = amountOf(sts['available']);
  final crunch = !(spare > 0);
  final buffer = amountOf(runway['buffer']);
  final avg = amountOf(runway['avgMonthlyExpense']);
  // monthsCovered is null until two completed months with spending exist; that
  // is the honest "we know your typical spend" gate emergencyRunway enforces.
  final hasHistory = runway['monthsCovered'] != null;

  // Starter cushion: one month of typical spend when we know it, else a plain
  // 10k floor. Never the full fund; that waits behind high-interest debt.
  final starterTarget =
      hasHistory && avg > 0 ? avg : amountOf(runway['firstTarget']);
  final starterGap = starterTarget - buffer > 0 ? starterTarget - buffer : 0.0;
  final fullTarget = hasHistory && avg > 0 ? avg * 3 : 0.0;
  final fullGap =
      fullTarget > 0 && fullTarget - buffer > 0 ? fullTarget - buffer : 0.0;

  // Highest monthly-rate debt with a real rate saved wins the debt tier. A
  // strict `>` keeps the first of any tie, matching the RN linear scan.
  Map<String, dynamic>? topDebt;
  var rateUnfilled = false;
  for (final raw in (data['debts'] is List ? data['debts'] as List : const [])) {
    if (raw is! Map) continue;
    final d = raw.cast<String, dynamic>();
    final remaining = amountOf(d['remaining']);
    if (!(remaining > 0.5)) continue;
    final rate = amountOf(d['monthlyRate']);
    if (rate > 0) {
      if (topDebt == null || rate > (topDebt['monthlyRate'] as double)) {
        final nameRaw = d['name'];
        final name = (nameRaw is String && nameRaw.trim().isNotEmpty)
            ? nameRaw.trim()
            : 'your debt';
        topDebt = {'name': name, 'monthlyRate': rate, 'remaining': remaining};
      }
    } else if (_interestBearingTypes.contains(d['type'])) {
      // An interest-bearing debt with no rate reads as free and would be
      // wrongly deprioritized; flag it instead of ranking on a fake zero.
      rateUnfilled = true;
    }
  }

  final activeGoal = _hasActiveGoal(data['goals'], ref);

  // The sound order. Starter cushion before debt (a shock with no cushion
  // becomes new utang), then the costliest debt, then the fuller fund, then
  // goals. 'set' means every must is handled.
  final String step;
  if (starterGap > 0) {
    step = 'starter';
  } else if (topDebt != null) {
    step = 'debt';
  } else if (fullGap > 0) {
    step = 'fuller';
  } else if (activeGoal) {
    step = 'goal';
  } else {
    step = 'set';
  }

  final applicable =
      hasHistory || buffer > 0 || topDebt != null || activeGoal || rateUnfilled;

  return {
    'step': step,
    'applicable': applicable,
    'spare': spare,
    'crunch': crunch,
    'buffer': buffer,
    'avgMonthlyExpense': avg,
    'hasHistory': hasHistory,
    'starterTarget': starterTarget,
    'starterGap': starterGap,
    'fullTarget': fullTarget,
    'fullGap': fullGap,
    'topDebt': topDebt,
    'rateUnfilled': rateUnfilled,
    'activeGoal': activeGoal,
  };
}
