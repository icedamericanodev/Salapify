// Golden vectors for creditUtilization, the f4.63 Credit Utilization Radar.
// Hand-computed from a fixture so the ratios are checkable without trusting the
// function under test. Utilization is balance / limit; only 'credit card' debts
// count; a card with no limit is flagged and kept out of the overall ratio.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/credit_utilization.dart';

void main() {
  List<Map<String, dynamic>> debts() => [
    // 9000 / 30000 = 0.30, exactly on the healthy line (<= 30% is healthy).
    {'id': 'A', 'type': 'credit card', 'remaining': 9000, 'creditLimit': 30000},
    // 24000 / 30000 = 0.80, high.
    {'id': 'B', 'type': 'credit card', 'remaining': 24000, 'creditLimit': 30000},
    // 5000 / 10000 = 0.50, watch (> 30%, not yet high).
    {'id': 'C', 'type': 'credit card', 'remaining': 5000, 'creditLimit': 10000},
    // Paid off: 0 / 20000 = 0.0, healthy.
    {'id': 'D', 'type': 'credit card', 'remaining': 0, 'creditLimit': 20000},
    // No limit saved: flagged, excluded from the overall ratio.
    {'id': 'E', 'type': 'credit card', 'remaining': 15000, 'creditLimit': 0},
    // Over the limit: 33000 / 30000 = 1.10, maxed.
    {'id': 'F', 'type': 'credit card', 'remaining': 33000, 'creditLimit': 30000},
    // A loan is not a revolving card: excluded entirely.
    {'id': 'G', 'type': 'personal loan', 'remaining': 50000, 'minPayment': 2000},
  ];

  test('per-card ratios and bands match the hand-computed vector', () {
    final r = creditUtilization(debts())!;
    final cards = r['cards'] as List<CardUtilization>;
    final byId = {for (final c in cards) c.id: c};

    expect(byId['A']!.utilization, closeTo(0.30, 1e-9));
    expect(byId['A']!.band, UtilizationBand.healthy);
    expect(byId['B']!.utilization, closeTo(0.80, 1e-9));
    expect(byId['B']!.band, UtilizationBand.high);
    expect(byId['C']!.utilization, closeTo(0.50, 1e-9));
    expect(byId['C']!.band, UtilizationBand.watch);
    expect(byId['D']!.utilization, closeTo(0.0, 1e-9));
    expect(byId['D']!.band, UtilizationBand.healthy);
    expect(byId['E']!.utilization, isNull);
    expect(byId['E']!.band, UtilizationBand.none);
    expect(byId['F']!.utilization, closeTo(1.10, 1e-9));
    expect(byId['F']!.band, UtilizationBand.maxed);
    // The loan never appears.
    expect(byId.containsKey('G'), isFalse);
  });

  test('overall ratio excludes the no-limit card and the loan', () {
    final r = creditUtilization(debts())!;
    // Balance = 9000 + 24000 + 5000 + 0 + 33000 = 71000 (E and G excluded).
    expect(r['overallBalance'], 71000.0);
    // Limit = 30000 + 30000 + 10000 + 20000 + 30000 = 120000.
    expect(r['overallLimit'], 120000.0);
    expect(r['overall'] as double, closeTo(71000 / 120000, 1e-9));
    expect(r['overallBand'], UtilizationBand.high); // ~0.592
    expect(r['limitsUnset'], 1);
    expect(r['cardCount'], 6); // six cards, the loan is not one
  });

  test('worst utilization sorts first, no-limit cards sink to the bottom', () {
    final r = creditUtilization(debts())!;
    final ids = [for (final c in r['cards'] as List<CardUtilization>) c.id];
    // F (1.10) > B (0.80) > C (0.50) > A (0.30) > D (0.0), then E (no limit).
    expect(ids, ['F', 'B', 'C', 'A', 'D', 'E']);
  });

  test('no credit card means no radar at all', () {
    expect(
      creditUtilization([
        {'id': 'L', 'type': 'personal loan', 'remaining': 5000},
      ]),
      isNull,
    );
    expect(creditUtilization(const []), isNull);
    expect(creditUtilization(null), isNull);
  });

  test('cards with no limit at all show no radar (nothing to measure)', () {
    // A book of credit cards that all lack a saved limit has no ratio to show,
    // so the radar stays hidden rather than nagging. This also keeps the card
    // name from appearing twice on the Debts screen (radar + list), which the
    // journey tests tap by name.
    expect(
      creditUtilization([
        {'id': 'a', 'type': 'credit card', 'name': 'BPI card', 'remaining': 8000},
        {'id': 'b', 'type': 'credit card', 'remaining': 3000, 'creditLimit': 0},
      ]),
      isNull,
    );
  });

  test('a card exactly one centavo over the line is watch, not healthy', () {
    // Directional guard on the 30% boundary: 30% is healthy, a hair over is not.
    final r = creditUtilization([
      {'id': 'X', 'type': 'credit card', 'remaining': 3001, 'creditLimit': 10000},
    ])!;
    final c = (r['cards'] as List<CardUtilization>).single;
    expect(c.utilization, closeTo(0.3001, 1e-9));
    expect(c.band, UtilizationBand.watch);
  });
}
