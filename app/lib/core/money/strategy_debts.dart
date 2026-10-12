/// Feeds the person's own debts to the strategy engine (D31).
///
/// Kept OUT of debt_strategy.dart, which is the prototype's engine locked to
/// its own vectors and knows nothing about the app's models.
library;

import '../../models/models.dart';
import 'debt_strategy.dart';

/// The person's OWN open debts, as the strategy calculator's input (D31).
///
/// The calculator used to run on three hardcoded examples while the debts
/// somebody had just typed in sat one tab away. This reads them instead:
/// money owed BY the person, not settled, not archived, with something left.
///
/// The interest rate is not stored on a debt, so it comes from [ratesById],
/// which the calculator fills from boxes on the screen; a debt with no rate
/// typed is 0%, which is the honest default for family utang and wrong for a
/// card, and the screen says so. The minimum is the debt's own
/// [Debt.monthlyMinimum], or 0 when it has none, never an assumed percentage
/// (founder decision 2026-10-04).
///
/// Names are made unique, because the simulation keys rates and payoff order
/// by name and two debts to "Aling Nena" would otherwise share one rate.
List<DebtItemForStrategy> strategyDebtsFrom(
  List<Debt> debts, {
  Map<String, double> ratesById = const <String, double>{},
}) {
  final Map<String, int> seen = <String, int>{};
  final List<DebtItemForStrategy> out = <DebtItemForStrategy>[];
  for (final Debt d in debts) {
    if (d.direction != DebtDirection.iOwe) continue;
    if (d.isSettled || d.isArchived || !d.remaining.isPositive) continue;
    final String base = d.person.trim().isEmpty ? 'Debt' : d.person.trim();
    final int n = (seen[base] ?? 0) + 1;
    seen[base] = n;
    out.add(
      DebtItemForStrategy(
        id: d.id,
        name: n == 1 ? base : '$base ($n)',
        balance: d.remaining.pesos,
        interestRate: ratesById[d.id] ?? 0,
        minimumPayment: d.monthlyMinimum?.pesos ?? 0,
      ),
    );
  }
  return out;
}
