import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/plan.dart';

/// A daily figure under each budget (D31): what is left, over the days left.
void main() {
  BudgetStatus status(int limitCentavos, int spentCentavos) => BudgetStatus(
    category: 'Food & Dining',
    emoji: '',
    limit: Money(limitCentavos),
    spent: Money(spentCentavos),
    remaining: Money(limitCentavos - spentCentavos),
    percent: 0,
    entryCount: 0,
  );

  test('days left counts today and never reaches zero', () {
    expect(daysLeftInMonth(DateTime(2026, 9, 18)), 13);
    expect(daysLeftInMonth(DateTime(2026, 9, 30)), 1);
    expect(daysLeftInMonth(DateTime(2026, 2, 1)), 28);
    expect(daysLeftInMonth(DateTime(2028, 2, 29)), 1);
  });

  test('what is left, spread over the days left', () {
    // 3,900 left on the 18th of a 30-day month: 13 days, 300 a day.
    expect(
      budgetPerDay(status(500000, 110000), DateTime(2026, 9, 18)),
      const Money.pesos(300),
    );
  });

  test('rounded DOWN, so the days never add up to more than is left', () {
    // 200.00 over 3 days is 66.666. Rounding to nearest gives 66.67, and
    // 3 x 66.67 = 200.01, a centavo past the limit; down gives 66.66.
    final Money perDay = budgetPerDay(status(20000, 0), DateTime(2026, 9, 28))!;
    expect(perDay, const Money(6666));
    expect(perDay.centavos * 3, lessThanOrEqualTo(20000));
  });

  test('nothing left, or over, gives no daily figure', () {
    expect(budgetPerDay(status(10000, 10000), DateTime(2026, 9, 18)), isNull);
    expect(budgetPerDay(status(10000, 15000), DateTime(2026, 9, 18)), isNull);
  });
}
