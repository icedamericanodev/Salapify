import 'dart:math' as math;

import 'js_round.dart';

/// Credit card payoff and the snowball against avalanche simulator, ported
/// from src/utils/loanCalculators.ts.

// ------------------------------------------------------------ Credit card

enum CardPaymentStrategy { minimumOnly, fixedAmount }

class CardPayoffRow {
  const CardPayoffRow({
    required this.month,
    required this.payment,
    required this.interest,
    required this.principal,
    required this.balance,
  });

  final int month;
  final double payment;
  final double interest;
  final double principal;
  final double balance;
}

class CreditCardPayoffResult {
  const CreditCardPayoffResult({
    required this.monthsToPayoff,
    required this.totalInterestPaid,
    required this.totalAmountPaid,
    required this.schedule,
    this.warningMessage,
  });

  final int monthsToPayoff;
  final double totalInterestPaid;
  final double totalAmountPaid;
  final List<CardPayoffRow> schedule;
  final String? warningMessage;
}

/// The minimum payment trap, under the BSP 3% monthly finance charge cap.
///
/// Paying the minimum is not a small version of paying the balance, it is a
/// different outcome: the minimum is 3% of the balance PLUS that month's
/// interest, so it shrinks as the balance shrinks and the payoff stretches for
/// years. Showing that is the entire point of this calculator.
///
/// Two details carried over exactly. The schedule is THINNED after month 36,
/// keeping only every sixth month, so a 20 year payoff does not return 240
/// rows. And monthsToPayoff is read off the LAST ROW KEPT, so once thinning
/// starts it can under-report by up to five months. That is the prototype's
/// behaviour and a screen reading it should say "about".
CreditCardPayoffResult calculateCreditCardPayoff({
  required double currentBalance,
  double monthlyInterestRate = 3.0,
  CardPaymentStrategy paymentStrategy = CardPaymentStrategy.minimumOnly,
  double fixedMonthlyPayment = 1500,
}) {
  final double rate = monthlyInterestRate / 100;
  double balance = currentBalance;
  double totalInterest = 0;
  double totalPaid = 0;
  final List<CardPayoffRow> schedule = <CardPayoffRow>[];

  // A 30 year ceiling, because a minimum-only payoff on a high rate can
  // otherwise never terminate.
  const int maxMonths = 360;

  for (int month = 1; month <= maxMonths; month++) {
    if (balance <= 0.5) break;

    final double interest = balance * rate;
    double payment;
    if (paymentStrategy == CardPaymentStrategy.minimumOnly) {
      // The Philippine bank standard: 3% of the balance plus the finance
      // charge, with an 850 peso floor.
      payment = math.max(850, (balance * 0.03) + interest);
    } else {
      payment = math.max(850, fixedMonthlyPayment);
    }

    if (payment > balance + interest) {
      payment = balance + interest;
    }

    final double principalPaid = payment - interest;
    balance = math.max(0, balance - principalPaid);
    totalInterest += interest;
    totalPaid += payment;

    if (month <= 36 || month % 6 == 0 || balance <= 0) {
      schedule.add(CardPayoffRow(
        month: month,
        payment: jsRound(payment).toDouble(),
        interest: jsRound(interest).toDouble(),
        principal: jsRound(principalPaid).toDouble(),
        balance: jsRound(balance).toDouble(),
      ));
    }

    if (balance <= 0) break;
  }

  return CreditCardPayoffResult(
    monthsToPayoff: schedule.isNotEmpty ? schedule.last.month : 0,
    totalInterestPaid: jsRound(totalInterest).toDouble(),
    totalAmountPaid: jsRound(totalPaid).toDouble(),
    schedule: schedule,
    warningMessage:
        paymentStrategy == CardPaymentStrategy.minimumOnly && currentBalance > 20000
            ? 'Warning: Paying only the minimum due triggers compounding '
                'finance charges under the 3% monthly BSP cap, extending '
                'repayment to years.'
            : null,
  );
}

// --------------------------------------------------------- Payoff strategy

enum PayoffStrategy { snowball, avalanche }

class DebtItemForStrategy {
  const DebtItemForStrategy({
    required this.id,
    required this.name,
    required this.balance,
    required this.interestRate,
    required this.minimumPayment,
  });

  final String id;
  final String name;
  final double balance;

  /// Annual, as a percentage.
  final double interestRate;
  final double minimumPayment;
}

class StrategySimulationResult {
  const StrategySimulationResult({
    required this.strategy,
    required this.monthsToDebtFreedom,
    required this.totalInterestPaid,
    required this.totalAmountPaid,
    required this.orderOfPayoff,
  });

  final PayoffStrategy strategy;
  final int monthsToDebtFreedom;
  final double totalInterestPaid;
  final double totalAmountPaid;
  final List<String> orderOfPayoff;
}

class StrategyComparison {
  const StrategyComparison({
    required this.snowball,
    required this.avalanche,
    required this.interestDifference,
  });

  final StrategySimulationResult snowball;
  final StrategySimulationResult avalanche;

  /// What the snowball costs over the avalanche. Never negative: avalanche is
  /// mathematically optimal, snowball is optimal for morale.
  final double interestDifference;
}

class _Active {
  _Active(this.name, this.currentBalance, this.monthlyRate, this.minimumPayment);

  final String name;
  double currentBalance;
  final double monthlyRate;
  final double minimumPayment;
}

/// Snowball, smallest balance first, against avalanche, highest rate first.
///
/// The order is decided ONCE, before the first month, and not re-sorted as
/// balances fall. That matters for snowball: a debt that starts second
/// smallest stays second in line even if another overtakes it. Ported as the
/// prototype has it.
StrategyComparison simulateDebtStrategies({
  required List<DebtItemForStrategy> debts,
  required double extraMonthlyBudget,
}) {
  StrategySimulationResult run(PayoffStrategy strategy) {
    final List<_Active> active = debts
        .map((DebtItemForStrategy d) => _Active(
              d.name,
              d.balance,
              d.interestRate / 100 / 12,
              d.minimumPayment,
            ))
        .toList();

    if (strategy == PayoffStrategy.snowball) {
      active.sort((_Active a, _Active b) =>
          a.currentBalance.compareTo(b.currentBalance));
    } else {
      final Map<String, double> rates = <String, double>{
        for (final DebtItemForStrategy d in debts) d.name: d.interestRate,
      };
      active.sort((_Active a, _Active b) =>
          (rates[b.name] ?? 0).compareTo(rates[a.name] ?? 0));
    }

    int months = 0;
    double totalInterest = 0;
    double totalPaid = 0;
    final List<String> orderOfPayoff = <String>[];
    const int maxMonths = 240;

    while (active.any((_Active d) => d.currentBalance > 1) &&
        months < maxMonths) {
      months++;
      double extraAvailable = extraMonthlyBudget;

      // 1. Accrue interest, then take every minimum.
      for (final _Active d in active) {
        if (d.currentBalance <= 0) continue;
        final double interest = d.currentBalance * d.monthlyRate;
        totalInterest += interest;
        d.currentBalance += interest;

        final double minPay = math.min(d.currentBalance, d.minimumPayment);
        d.currentBalance -= minPay;
        totalPaid += minPay;

        if (d.currentBalance <= 0.01 && !orderOfPayoff.contains(d.name)) {
          orderOfPayoff.add(d.name);
          // The freed minimum rolls into this month's extra. That rollover is
          // what makes either strategy accelerate.
          extraAvailable += d.minimumPayment;
        }
      }

      // 2. Throw everything spare at the debt at the front of the queue.
      _Active? target;
      for (final _Active d in active) {
        if (d.currentBalance > 0.01) {
          target = d;
          break;
        }
      }
      if (target != null && extraAvailable > 0) {
        final double extraPay = math.min(target.currentBalance, extraAvailable);
        target.currentBalance -= extraPay;
        totalPaid += extraPay;
        if (target.currentBalance <= 0.01 &&
            !orderOfPayoff.contains(target.name)) {
          orderOfPayoff.add(target.name);
        }
      }
    }

    return StrategySimulationResult(
      strategy: strategy,
      monthsToDebtFreedom: months,
      totalInterestPaid: jsRound(totalInterest).toDouble(),
      totalAmountPaid: jsRound(totalPaid).toDouble(),
      orderOfPayoff: orderOfPayoff,
    );
  }

  final StrategySimulationResult snowball = run(PayoffStrategy.snowball);
  final StrategySimulationResult avalanche = run(PayoffStrategy.avalanche);

  return StrategyComparison(
    snowball: snowball,
    avalanche: avalanche,
    interestDifference: math.max(
      0,
      snowball.totalInterestPaid - avalanche.totalInterestPaid,
    ),
  );
}
