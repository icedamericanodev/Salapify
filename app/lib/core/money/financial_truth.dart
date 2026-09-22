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
      final bool sameAmount = (a.amount - b.amount).abs() < 0.01;

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
                'Two identical charges of ₱${_n(a.amount)} for "${a.merchant ?? a.category}" '
                'recorded within 48 hours (${a.date} and ${b.date}).',
            severity: AlertSeverity.medium,
            amount: a.amount,
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
  //    Credit, loan and mortgage accounts are excluded: owing money IS their
  //    normal state.
  for (final Account acc in accounts) {
    final bool borrowing =
        acc.kind == AccountKind.credit ||
        acc.kind == AccountKind.loan ||
        acc.kind == AccountKind.mortgage;
    if (!borrowing && acc.balance < 0) {
      alerts.add(
        ControlCenterAlert(
          id: 'alert_neg_bal_${acc.id}',
          type: AlertType.balanceMismatch,
          title: 'Negative Balance in ${acc.name}',
          description:
              'Account has a negative balance of ₱${_n(acc.balance)}. '
              'A reconciliation adjustment is needed.',
          severity: AlertSeverity.high,
          amount: acc.balance.abs(),
          relatedAccountId: acc.id,
          suggestedAction:
              'Reconcile account balance against actual mobile banking / e-wallet statement.',
        ),
      );
    }
  }

  // 3. A category more than 15% past its limit. High once it passes 30%.
  for (final Budget b in budgets) {
    final double spent = transactions
        .where(
          (Transaction t) =>
              t.type == TransactionType.expense &&
              t.category.toLowerCase() == b.category.toLowerCase(),
        )
        .fold<double>(0, (double s, Transaction t) => s + t.amount);

    if (spent > b.limit * 1.15) {
      alerts.add(
        ControlCenterAlert(
          id: 'alert_drift_${b.category}',
          type: AlertType.categoryDrift,
          title: 'Category Drift: ${b.category}',
          description:
              'Spent ₱${_n(spent)} which is ${((spent / b.limit) * 100).round()}% '
              'of your ₱${_n(b.limit)} budget limit.',
          severity: spent > b.limit * 1.3
              ? AlertSeverity.high
              : AlertSeverity.medium,
          amount: spent - b.limit,
          suggestedAction:
              'Pace daily expenses or temporarily reallocate limit from discretionary categories.',
        ),
      );
    }
  }

  // 7. Liquid cash under 5,000. Note this set is NOT the same as the Safe to
  //    Spend engine's liquid set: it leaves out debit accounts. The difference
  //    is the prototype's and is preserved.
  final double liquidCash = accounts
      .where(
        (Account a) =>
            a.kind == AccountKind.cash ||
            a.kind == AccountKind.bank ||
            a.kind == AccountKind.gcash ||
            a.kind == AccountKind.maya,
      )
      .fold<double>(0, (double s, Account a) => s + a.balance);

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
  final double totalDebtOwed = debts
      .where((Debt d) => d.direction == DebtDirection.iOwe && !d.isSettled)
      .fold<double>(
        0,
        (double s, Debt d) => s + (d.totalAmount - d.paidAmount),
      );

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
  final double totalExpenses = expenses.fold<double>(
    0,
    (double s, Transaction t) => s + t.amount,
  );
  final double totalBudgeted = budgets.fold<double>(
    0,
    (double s, Budget b) => s + b.limit,
  );

  if (totalBudgeted > 0 && totalExpenses > totalBudgeted) {
    alerts.add(
      ControlCenterAlert(
        id: 'alert_forecast_variance',
        type: AlertType.forecastVariance,
        title: 'Forecast Variance',
        description:
            'Total spending of ₱${_n(totalExpenses)} exceeds the '
            '₱${_n(totalBudgeted)} budgeted across all categories.',
        severity: AlertSeverity.high,
        amount: totalExpenses - totalBudgeted,
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
