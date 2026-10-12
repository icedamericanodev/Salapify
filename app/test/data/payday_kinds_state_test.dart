import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/health_check.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/pan/pan_engine.dart';
import 'package:salapify/core/money/payday_schedule.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// The store's side of D37: the countdown, the bill window, a "last until"
/// date that has passed, and the Health Check's monthly take-home.
void main() {
  // A Monday. The example ledger's dates are September; nothing here needs
  // them, only a clock the test controls.
  final DateTime monday = DateTime(2026, 10, 12, 9);

  Future<FinancialState> fresh({DateTime? at}) async {
    final FinancialState s = FinancialState(
      clock: at ?? monday,
      store: MemorySnapshotStore(),
    );
    await s.restore();
    s.startWithExampleData();
    return s;
  }

  // A bill due 20 days from the Monday: inside a 30 day window, outside a
  // four day countdown.
  UpcomingItem rentIn20Days() => const UpcomingItem(
    id: 'up_rent_d37',
    name: 'Rent D37',
    amount: Money.pesos(8000),
    dueDate: '2026-11-01',
    type: UpcomingItemType.rent,
  );

  bool holdsRent(FinancialState s) =>
      s.billsHeldBack.any((BillItem b) => b.name == 'Rent D37');

  test('paid every Friday: four days to payday from a Monday, and saved as a '
      'weekly rule', () async {
    final FinancialState s = await fresh();
    s.setPaydayRule(weekday: DateTime.friday);
    expect(s.payday.isSet, isTrue);
    expect(s.payday.daysToPayday, 4);
    expect(s.payday.nextPayday, 'Oct 16');
    expect(s.payday.cycleType, 'weekly');
    expect(s.paydaySchedule!.kind, PaydayKind.weekly);
  });

  test('weekly pay holds back rent due in 20 days; twice a month due in 3 '
      'does not (D37.3, D33 unchanged)', () async {
    final FinancialState weekly = await fresh();
    weekly.addUpcoming(rentIn20Days());
    weekly.setPaydayRule(weekday: DateTime.friday);
    expect(weekly.payday.daysToPayday, 4);
    expect(holdsRent(weekly), isTrue, reason: 'rent offered as spending');
    expect(
      weekly.upcomingThisCycle.any((UpcomingItem u) => u.name == 'Rent D37'),
      isTrue,
      reason: '"Going out" must match what Safe to Spend held back (D36)',
    );

    final FinancialState twice = await fresh();
    twice.addUpcoming(rentIn20Days());
    // The 15th and 30th from the 12th: three days to payday.
    twice.setPaydayRule(daysOfMonth: <int>[15, 30]);
    expect(twice.payday.daysToPayday, 3);
    expect(holdsRent(twice), isFalse);
  });

  test(
    'switching from weekly to twice a month leaves no weekday behind',
    () async {
      final FinancialState s = await fresh();
      s.setPaydayRule(weekday: DateTime.friday);
      s.setPaydayRule(daysOfMonth: <int>[15, 30]);
      expect(s.payday.paydayWeekday, isNull);
      expect(s.paydaySchedule!.kind, PaydayKind.daysOfMonth);
    },
  );

  group('no fixed payday', () {
    test('counts down to the date, and no expected income is kept', () async {
      final FinancialState s = await fresh();
      s.setPaydayRule(
        lastUntil: DateTime(2026, 10, 20),
        expectedIncome: const Money.pesos(20000),
      );
      expect(s.payday.daysToPayday, 8);
      expect(s.payday.expectedIncome, Money.zero);
      expect(s.paydayDatePassed, isFalse);
    });

    test('once the date has come the daily figure is off and the app asks '
        'for the next date', () async {
      // Saved on the Monday, opened again on the Friday: the same stored
      // rule, read after its date, the way a phone reads it.
      final MemorySnapshotStore disk = MemorySnapshotStore();
      final FinancialState monday0 = FinancialState(clock: monday, store: disk);
      await monday0.restore();
      monday0.startWithExampleData();
      monday0.setPaydayRule(lastUntil: DateTime(2026, 10, 14));
      expect(monday0.payday.isSet, isTrue);
      expect(monday0.payday.daysToPayday, 2);
      await monday0.flushWrites();

      final FinancialState friday0 = FinancialState(
        clock: DateTime(2026, 10, 16, 8),
        store: disk,
      );
      await friday0.restore();
      // The stored countdown said 2. It must not be read as still true.
      expect(friday0.payday.isSet, isFalse);
      expect(friday0.payday.daysToPayday, 0);
      expect(friday0.paydayDatePassed, isTrue);
    });
  });

  test('Health Check: a twice-a-month payday set in the app counts two '
      'paydays a month, the same as the example data does', () async {
    final FinancialState s = await fresh(at: DateTime(2026, 9, 18));
    String? promised(FinancialState st) => st.healthReport.indicators
        .firstWhere((HealthIndicator i) => i.id == 'promised')
        .reading;
    final String? fromExample = promised(s);
    expect(fromExample, isNotNull);

    // Re-saving the SAME rule through the editor used to halve the monthly
    // take-home: measured 10% shown as 20% (ledger-reconciler).
    s.setPaydayRule(
      daysOfMonth: <int>[15, 30],
      expectedIncome: const Money.pesos(32500),
    );
    expect(s.payday.cycleType, 'semi_monthly');
    expect(promised(s), fromExample);
  });

  group('QA fixes (2026-10-12)', () {
    test('no fixed payday with a date of tomorrow still holds back rent due '
        'in three days (D37.5)', () async {
      final FinancialState s = await fresh();
      s.addUpcoming(
        const UpcomingItem(
          id: 'up_rent_soon',
          name: 'Rent D37',
          amount: Money.pesos(15000),
          dueDate: '2026-10-15',
          type: UpcomingItemType.rent,
        ),
      );
      s.setPaydayRule(lastUntil: DateTime(2026, 10, 13));
      expect(s.payday.daysToPayday, 1);
      expect(holdsRent(s), isTrue, reason: 'rent offered as spending money');
    });

    test('the bill caption says what the window is', () async {
      final FinancialState twice = await fresh();
      twice.setPaydayRule(daysOfMonth: <int>[15, 30]);
      expect(twice.billWindowPhrase, 'by payday');

      final FinancialState weekly = await fresh();
      weekly.setPaydayRule(weekday: DateTime.friday);
      expect(weekly.billWindowPhrase, 'in the next 30 days');
    });

    test('Health Check: no fixed payday says why "promised" is not measured, '
        'with no button back to an editor that cannot answer it', () async {
      final FinancialState s = await fresh();
      s.setPaydayRule(lastUntil: DateTime(2026, 10, 20));
      final HealthIndicator promised = s.healthReport.indicators.firstWhere(
        (HealthIndicator i) => i.id == 'promised',
      );
      expect(promised.measured, isFalse);
      expect(promised.need, isNull);
      expect(promised.missing, contains('no fixed payday'));
    });

    test('Pan calls the date what it is, not a payday', () async {
      final FinancialState s = await fresh();
      s.setPaydayRule(lastUntil: DateTime(2026, 10, 20));
      final String text = askPan('When is my payday?', s.panFacts).text;
      expect(text, contains('last until'));
      expect(text, isNot(contains('next payday')));
    });
  });
}
