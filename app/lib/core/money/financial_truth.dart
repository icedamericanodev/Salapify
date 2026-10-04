import 'currencies.dart' show formatCurrency;
import 'debt.dart' show outstanding;
import 'money.dart';
import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../../models/models.dart';

/// The Financial Truth engine, ported from src/utils/financialTruthEngine.ts.
///
/// Two halves. The CONTROL CENTRE SCAN reads the ledger and raises alerts about
/// what looks wrong. The DIGITAL TWIN answers "what if", by re-running the
/// runway and net worth under a shock.
///
/// Neither invents money. Both read what is already stored and report on it, so
/// nothing here writes to the ledger.

/// Matches JavaScript's Number.toLocaleString() for the figures the prototype
/// embeds in alert prose: grouped in threes, decimals only when present.
final NumberFormat _loose = NumberFormat('#,##0.###');

String _n(double v) => _loose.format(v);

// --------------------------------------------------------- Control centre

enum AlertType {
  duplicateCharge,
  balanceMismatch,
  categoryDrift,
  unexpectedRecurring,
  newPayee,
  highFee,
  cashShortfall,
  debtPaymentRisk,
  forecastVariance,
  missingReceipt,
}

enum AlertSeverity { low, medium, high, critical }

class ControlCenterAlert {
  const ControlCenterAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
    required this.suggestedAction,
    this.amount,
    this.relatedTransactionId,
    this.relatedAccountId,
  });

  final String id;
  final AlertType type;
  final String title;
  final String description;
  final AlertSeverity severity;
  final String suggestedAction;
  final double? amount;
  final String? relatedTransactionId;
  final String? relatedAccountId;
}

/// The ten checks, in the prototype's own order.
///
/// Rule 1 is the expensive one: it compares every expense against every other
/// expense, which is quadratic. Fine for a personal ledger and worth knowing
/// before anyone points it at years of data.
List<ControlCenterAlert> runControlCenterScan({
  required List<Transaction> transactions,
  required List<Account> accounts,
  required List<Debt> debts,
  required List<Budget> budgets,
}) {
  final List<ControlCenterAlert> alerts = <ControlCenterAlert>[];

  final List<Transaction> expenses = transactions
      .where((Transaction t) => t.type == TransactionType.expense)
      .toList();

  // 1. The same amount twice, at the same merchant or in the same category,
  //    within 48 hours. The commonest real defect in a hand-kept ledger.
  for (int i = 0; i < expenses.length; i++) {
    for (int j = i + 1; j < expenses.length; j++) {
      final Transaction a = expenses[i];
      final Transaction b = expenses[j];
      if (a.id == b.id) continue;

      final bool sameMerchant =
          a.merchant != null &&
          b.merchant != null &&
          a.merchant!.toLowerCase() == b.merchant!.toLowerCase();
      final bool sameCategory =
          a.category.toLowerCase() == b.category.toLowerCase();
      // EXACT now. The 0.01 tolerance existed because two doubles holding
      // the same peso figure can differ in their last bits. Two centavo
      // counts cannot, so a near-match is no longer treated as a
      // duplicate: 100.00 and 100.01 are two different charges.
      final bool sameAmount = a.amount == b.amount;

      final DateTime? da = DateTime.tryParse(a.date);
      final DateTime? db = DateTime.tryParse(b.date);
      if (da == null || db == null) continue;
      final double dayDiff =
          (da.difference(db).inMilliseconds).abs() / (1000 * 3600 * 24);

      if (sameAmount && (sameMerchant || sameCategory) && dayDiff <= 2) {
        alerts.add(
          ControlCenterAlert(
            id: 'alert_dup_${a.id}_${b.id}',
            type: AlertType.duplicateCharge,
            title: 'Potential Duplicate Transaction',
            description:
                'Two identical charges of ₱${_n(a.amount.pesos)} for "${a.merchant ?? a.category}" '
                'recorded within 48 hours (${a.date} and ${b.date}).',
            severity: AlertSeverity.medium,
            amount: a.amount.pesos,
            relatedTransactionId: b.id,
            suggestedAction:
                'Review transaction ledger and mark redundant entry as duplicate or excluded.',
          ),
        );
        break; // One alert per left-hand transaction, not per pair.
      }
    }
  }

  // 2. A negative balance on an account that cannot legitimately hold one.
  //    Credit, loan and mortgage accounts are excluded, and the reason is NOT
  //    the one this comment used to give. It said owing money is their normal
  //    state, which reads as though a borrowing account owes money when its
  //    balance is negative. It does not: this app stores a liability balance
  //    POSITIVE when money is owed, and net worth subtracts a plain sum of
  //    them. A negative balance on a card means the card owes YOU, after an
  //    overpayment. That is unusual and legitimate, which is why it is
  //    excluded here, and the exclusion is right for a different reason than
  //    the comment claimed. See test/core/money/credit_sign_test.dart; two
  //    engines were written against the wrong reading of this sentence.
  for (final Account acc in accounts) {
    final bool borrowing =
        acc.kind == AccountKind.credit ||
        acc.kind == AccountKind.loan ||
        acc.kind == AccountKind.mortgage;
    if (!borrowing && acc.balance < Money.pesos(0)) {
      alerts.add(
        ControlCenterAlert(
          id: 'alert_neg_bal_${acc.id}',
          type: AlertType.balanceMismatch,
          title: 'Negative Balance in ${acc.name}',
          // The SYMBOL follows the account, and the AMOUNT is converted.
          // Two different fixes for two different readers.
          //
          // The description used a hardcoded peso sign on the raw stored
          // figure, so a dollar account overdrawn by 200 read "negative
          // balance of ₱-200" when the hole is ₱11,700. Showing it in the
          // account's own currency is what the Accounts screen already
          // does for a foreign balance, and it is the honest figure: it is
          // the number on that bank's statement, which is what somebody
          // reconciling will be holding.
          //
          // `amount` is the opposite case. Nothing reads it as a currency,
          // every other alert in this file puts a peso figure there, and a
          // caller ranking alerts by size would sort a dollar against
          // pesos. So that one converts.
          description:
              'Account has a negative balance of '
              '${formatCurrency(acc.balance.pesos, acc.currency)}. '
              'A reconciliation adjustment is needed.',
          severity: AlertSeverity.high,
          amount: acc.balanceInPhp.abs.pesos,
          relatedAccountId: acc.id,
          suggestedAction:
              'Reconcile account balance against actual mobile banking / e-wallet statement.',
        ),
      );
    }
  }

  // 3. A category more than 15% past its limit. High once it passes 30%.
  for (final Budget b in budgets) {
    // STATUS IS CHECKED, which it was not. This alert summed every expense in
    // the category whatever its state, so an entry marked excluded, duplicate
    // or taken back kept pushing the category toward an orange warning for
    // good. That was already wrong for the two older states; it becomes
    // visible with the third, because taking a payment back and watching the
    // warning stay is the obvious thing a person would notice.
    final Money spent = transactions
        .where(
          (Transaction t) =>
              t.countsTowardTotals &&
              t.type == TransactionType.expense &&
              t.category.toLowerCase() == b.category.toLowerCase(),
        )
        // FOLDED IN CENTAVOS, not pesos. Every term is already exact, and
        // adding them as doubles was the one place drift could creep into a
        // comparison that decides whether somebody is told they overspent.
        .fold<Money>(Money.zero, (Money s, Transaction t) => s + t.amount);

    if (spent > b.limit.times(1.15)) {
      alerts.add(
        ControlCenterAlert(
          id: 'alert_drift_${b.category}',
          type: AlertType.categoryDrift,
          title: 'Category Drift: ${b.category}',
          description:
              'Spent ₱${_n(spent.pesos)} which is '
              '${((spent.pesos / b.limit.pesos) * 100).round()}% '
              'of your ₱${_n(b.limit.pesos)} budget limit.',
          severity: spent > b.limit.times(1.3)
              ? AlertSeverity.high
              : AlertSeverity.medium,
          amount: (spent - b.limit).pesos,
          suggestedAction:
              'Pace daily expenses or temporarily reallocate limit from discretionary categories.',
        ),
      );
    }
  }

  // 7. Liquid cash under 5,000. Note this set is NOT the same as the Safe to
  //    Spend engine's liquid set: it leaves out debit accounts. The difference
  //    is the prototype's and is preserved.
  //
  //    AND money the person has SET ASIDE is left out too, which is P2.3.
  //    This file does not call `isLiquid`, it types the kinds out again, so
  //    it was the one place the protected-accounts fix could have been missed
  //    entirely. It drives the loudest alarm the app has: without this line,
  //    somebody with 50,000 in GSave and 400 in their spending wallet gets no
  //    shortfall warning at all, because the app can see 50,400 of "cash".
  final double liquidCash = accounts
      .where(
        (Account a) =>
            (a.kind == AccountKind.cash ||
                a.kind == AccountKind.bank ||
                a.kind == AccountKind.gcash ||
                a.kind == AccountKind.maya) &&
            a.purpose != AccountPurpose.protected,
      )
      // CONVERTED, unlike the sibling fold in safe_to_spend.dart, and the
      // difference is deliberate rather than an inconsistency.
      //
      // safe_to_spend.dart is parity with a prototype whose Account type
      // has NO currency field at all, so converting in there would change
      // a golden-locked engine against a design that cannot express
      // foreign money. This prototype is different: src/types.ts:30 gives
      // Account an optional `currency`, and financialTruthEngine.ts simply
      // ignores it. That is a defect in the prototype, not a constraint,
      // so matching it would mean porting the bug on purpose.
      //
      // Converting in the engine rather than at the caller, also
      // deliberately: runControlCenterScan has no caller in lib/ yet, so
      // there is no boundary to convert at, and leaving it raw would mean
      // the first caller inherits the defect silently.
      //
      // Every golden vector is peso-only, where balanceInPhp returns
      // balance untouched, so none of them move.
      .fold<double>(0, (double s, Account a) => s + a.balanceInPhp.pesos);

  if (liquidCash < 5000) {
    alerts.add(
      ControlCenterAlert(
        id: 'alert_cash_shortfall',
        type: AlertType.cashShortfall,
        title: 'Cash Shortfall Risk',
        description:
            'Liquid reserves are down to ₱${_n(liquidCash)}, below the '
            '₱5,000 working buffer.',
        severity: AlertSeverity.critical,
        amount: liquidCash,
        suggestedAction:
            'Move funds from savings or pause discretionary spending until the next payday.',
      ),
    );
  }

  // 8. Debt owed above 80% of liquid reserves.
  // ONE implementation of "what you owe", shared with every screen.
  //
  // This used to be its own copy, identical to `outstanding` except that it
  // dropped the floor. `Debt.remaining` clamps at zero and this did not, and
  // the result is summed, so an OVERPAID debt subtracted from the total.
  //
  // Reachable in two taps: overpay a debt (which is deliberately allowed),
  // it settles, then tap "Not settled after all". Measured gap 2,000.00
  // between this alert and the figure the Debts screen shows for the same
  // debts. It also gates the alert, so an overpaid debt could silence a real
  // debt-pressure warning.
  final double totalDebtOwed = outstanding(debts, DebtDirection.iOwe).pesos;

  if (totalDebtOwed > liquidCash * 0.8 && totalDebtOwed > 0) {
    alerts.add(
      ControlCenterAlert(
        id: 'alert_debt_pressure',
        type: AlertType.debtPaymentRisk,
        title: 'Debt Service Cashflow Pressure',
        description:
            'Pending debt obligations (₱${_n(totalDebtOwed)}) represent '
            '${((totalDebtOwed / (liquidCash == 0 ? 1 : liquidCash)) * 100).round()}% '
            'of your available liquid reserves.',
        severity: AlertSeverity.high,
        amount: totalDebtOwed,
        suggestedAction:
            'Review installment amortization schedules and reserve minimum due amounts.',
      ),
    );
  }

  // 9. Total spending past total budget.
  // Both sides in centavos, so the comparison that raises this alert cannot
  // turn on a fraction neither figure really has.
  final Money totalExpenses = expenses.fold<Money>(
    Money.zero,
    (Money s, Transaction t) => s + t.amount,
  );
  final Money totalBudgeted = budgets.fold<Money>(
    Money.zero,
    (Money s, Budget b) => s + b.limit,
  );

  if (totalBudgeted.isPositive && totalExpenses > totalBudgeted) {
    alerts.add(
      ControlCenterAlert(
        id: 'alert_forecast_variance',
        type: AlertType.forecastVariance,
        title: 'Forecast Variance',
        description:
            'Total spending of ₱${_n(totalExpenses.pesos)} exceeds the '
            '₱${_n(totalBudgeted.pesos)} budgeted across all categories.',
        severity: AlertSeverity.high,
        amount: (totalExpenses - totalBudgeted).pesos,
        suggestedAction:
            'Re-forecast the remaining cycle or reallocate between category limits.',
      ),
    );
  }

  return alerts;
}

// ------------------------------------------------------------ Digital twin

enum TwinScenario {
  jobLoss,
  delayedIncome,
  rentIncrease,
  medicalExpense,
  newChild,
  thirteenthMonth,
  debtPrepayment,
  businessSlowdown,
}

class TwinSimulationResult {
  const TwinSimulationResult({
    required this.scenario,
    required this.baselineRunwayMonths,
    required this.simulatedRunwayMonths,
    required this.baselineSafeToSpend,
    required this.simulatedSafeToSpend,
    required this.baselineNetWorth,
    required this.simulatedNetWorth,
    required this.bufferImpactPhp,
    required this.recommendations,
  });

  final TwinScenario scenario;
  final double baselineRunwayMonths;
  final double simulatedRunwayMonths;
  final double baselineSafeToSpend;
  final double simulatedSafeToSpend;
  final double baselineNetWorth;
  final double simulatedNetWorth;

  /// Negative for a shock, positive for a windfall.
  final double bufferImpactPhp;
  final List<String> recommendations;
}

/// Re-runs the runway, the spendable buffer and net worth under one shock.
///
/// The shock sizes are FIXED pesos, not proportions: a 50,000 medical bill, a
/// 3,500 rent rise, 14,000 a month for a child, a 30,000 prepayment. They are
/// the prototype's assumptions about Philippine costs and are ported as
/// constants rather than quietly turned into settings.
TwinSimulationResult simulateDigitalTwin({
  required TwinScenario scenario,
  required double currentLiquidCash,
  required double monthlyExpenseRunrate,
  required double currentNetWorth,
  required double monthlyIncome,
}) {
  // With no spending on record the runway cannot be computed, so the prototype
  // assumes six months rather than dividing by zero.
  final double baselineRunwayMonths = monthlyExpenseRunrate > 0
      ? currentLiquidCash / monthlyExpenseRunrate
      : 6;
  final double baselineSafeToSpend = math.max(0, currentLiquidCash * 0.4);
  final double safeRunrate = monthlyExpenseRunrate == 0
      ? 1
      : monthlyExpenseRunrate;

  switch (scenario) {
    case TwinScenario.jobLoss:
      final double survival = monthlyExpenseRunrate * 0.75;
      return TwinSimulationResult(
        scenario: scenario,
        baselineRunwayMonths: baselineRunwayMonths,
        simulatedRunwayMonths: survival > 0 ? currentLiquidCash / survival : 0,
        baselineSafeToSpend: baselineSafeToSpend,
        simulatedSafeToSpend: 0,
        baselineNetWorth: currentNetWorth,
        simulatedNetWorth: currentNetWorth - survival * 3,
        bufferImpactPhp: -monthlyIncome * 3,
        recommendations: const <String>[
          'Immediately activate emergency survival budget (freeze leisure and dining out).',
          'File SSS Unemployment Benefit claim (grants up to ₱20,000 for qualified SSS contributors).',
          'Notify lenders for grace periods or interest-only restructuring on amortizations.',
        ],
      );

    case TwinScenario.delayedIncome:
      final double deficit = monthlyExpenseRunrate * 0.5;
      return TwinSimulationResult(
        scenario: scenario,
        baselineRunwayMonths: baselineRunwayMonths,
        simulatedRunwayMonths: math.max(
          0,
          (currentLiquidCash - deficit) / safeRunrate,
        ),
        baselineSafeToSpend: baselineSafeToSpend,
        simulatedSafeToSpend: math.max(0, (currentLiquidCash - deficit) * 0.3),
        baselineNetWorth: currentNetWorth,
        simulatedNetWorth: currentNetWorth,
        bufferImpactPhp: -deficit,
        recommendations: const <String>[
          'Bridge utilities using liquid high-yield savings without touching long-term investments.',
          'Negotiate payment terms with landlords or service providers before due dates.',
          'Avoid high-interest short-term online lending apps (OLAs) with predatory daily penalties.',
        ],
      );

    case TwinScenario.rentIncrease:
      const double monthlyBump = 3500;
      const double annualBump = monthlyBump * 12;
      return TwinSimulationResult(
        scenario: scenario,
        baselineRunwayMonths: baselineRunwayMonths,
        simulatedRunwayMonths: math.max(
          0,
          currentLiquidCash / (monthlyExpenseRunrate + monthlyBump),
        ),
        baselineSafeToSpend: baselineSafeToSpend,
        simulatedSafeToSpend: math.max(0, baselineSafeToSpend - monthlyBump),
        baselineNetWorth: currentNetWorth,
        simulatedNetWorth: currentNetWorth - annualBump,
        bufferImpactPhp: -annualBump,
        recommendations: const <String>[
          'Verify if rent increase complies with Philippine Rent Control Act (ceiling limits for lower-rent brackets).',
          'Offset the ₱3,500 monthly increase by optimizing electricity (aircon inverter timers) or cooking at home.',
          'Consider distance vs transport fare tradeoffs if relocating.',
        ],
      );

    case TwinScenario.medicalExpense:
      const double bill = 50000;
      final double after = math.max(0, currentLiquidCash - bill);
      return TwinSimulationResult(
        scenario: scenario,
        baselineRunwayMonths: baselineRunwayMonths,
        simulatedRunwayMonths: monthlyExpenseRunrate > 0
            ? after / monthlyExpenseRunrate
            : 0,
        baselineSafeToSpend: baselineSafeToSpend,
        simulatedSafeToSpend: math.max(0, after * 0.2),
        baselineNetWorth: currentNetWorth,
        simulatedNetWorth: currentNetWorth - bill,
        bufferImpactPhp: -bill,
        recommendations: const <String>[
          'Confirm PhilHealth case rate coverage and HMO limits before settling the bill.',
          'Request a hospital payment plan rather than drawing on high-interest credit.',
          'Rebuild the emergency fund before resuming discretionary spending.',
        ],
      );

    case TwinScenario.newChild:
      const double care = 14000;
      return TwinSimulationResult(
        scenario: scenario,
        baselineRunwayMonths: baselineRunwayMonths,
        simulatedRunwayMonths:
            currentLiquidCash / (monthlyExpenseRunrate + care),
        baselineSafeToSpend: baselineSafeToSpend,
        simulatedSafeToSpend: math.max(0, baselineSafeToSpend - care),
        baselineNetWorth: currentNetWorth,
        simulatedNetWorth: currentNetWorth - care * 12,
        bufferImpactPhp: -care * 12,
        recommendations: const <String>[
          'Claim SSS maternity or paternity benefits and update PhilHealth dependents.',
          'Budget for recurring pediatric and vaccination schedules, not just the delivery.',
          'Start an education fund early, where time does most of the work.',
        ],
      );

    case TwinScenario.thirteenthMonth:
      final double bonus = monthlyIncome;
      return TwinSimulationResult(
        scenario: scenario,
        baselineRunwayMonths: baselineRunwayMonths,
        simulatedRunwayMonths: (currentLiquidCash + bonus) / safeRunrate,
        baselineSafeToSpend: baselineSafeToSpend,
        simulatedSafeToSpend: baselineSafeToSpend + bonus * 0.3,
        baselineNetWorth: currentNetWorth,
        simulatedNetWorth: currentNetWorth + bonus,
        bufferImpactPhp: bonus,
        recommendations: const <String>[
          'Allocate before it arrives, or it is spent before it is counted.',
          'Clear the highest interest balance first, then top up the emergency fund.',
          'Keep a deliberate share for the holidays rather than pretending there is none.',
        ],
      );

    case TwinScenario.debtPrepayment:
      const double prepay = 30000;
      // Roughly a year of interest at 18%, the usual card or personal loan
      // rate. An estimate, not a payoff simulation.
      const double interestSaved = prepay * 0.18;
      return TwinSimulationResult(
        scenario: scenario,
        baselineRunwayMonths: baselineRunwayMonths,
        simulatedRunwayMonths: math.max(
          0,
          (currentLiquidCash - prepay) / safeRunrate,
        ),
        baselineSafeToSpend: baselineSafeToSpend,
        simulatedSafeToSpend: math.max(0, baselineSafeToSpend - prepay * 0.3),
        baselineNetWorth: currentNetWorth,
        simulatedNetWorth: currentNetWorth + interestSaved,
        bufferImpactPhp: interestSaved,
        recommendations: const <String>[
          'Prepay the highest rate balance first; the rate decides, not the size.',
          'Confirm the lender applies prepayments to principal, not to future interest.',
          'Keep at least one month of expenses liquid after prepaying.',
        ],
      );

    case TwinScenario.businessSlowdown:
      final double revenueCut = monthlyIncome * 0.3;
      return TwinSimulationResult(
        scenario: scenario,
        baselineRunwayMonths: baselineRunwayMonths,
        simulatedRunwayMonths: currentLiquidCash / safeRunrate,
        baselineSafeToSpend: baselineSafeToSpend,
        simulatedSafeToSpend: math.max(
          0,
          baselineSafeToSpend - revenueCut * 0.5,
        ),
        baselineNetWorth: currentNetWorth,
        simulatedNetWorth: currentNetWorth - revenueCut * 3,
        bufferImpactPhp: -revenueCut * 3,
        recommendations: const <String>[
          'Separate business and personal cash before the slowdown forces the issue.',
          'Cut variable costs first, and protect the ones that generate revenue.',
          'Renegotiate supplier terms early rather than missing a payment later.',
        ],
      );
  }
}
