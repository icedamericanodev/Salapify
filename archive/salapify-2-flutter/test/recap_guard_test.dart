// The recap's non-finite guard: absurd amounts from a hand-edited backup can
// overflow moneyIn to Infinity, making kept/moneyIn NaN. Before the guard the
// share card crashed on open (the percent floor throws on NaN); now the month
// reads as no-verdict, the same honest fallback as a no-income month. This is
// a deliberate divergence from RN, which renders "NaN%" garbage instead.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/recap.dart';

void main() {
  test('overflowed income yields a null keptRate, not NaN', () {
    final recap = monthRecap({
      'transactions': [
        {
          'date': '2026-07-01',
          'type': 'income',
          'label': 'A',
          'amount': 1.5e308,
        },
        {
          'date': '2026-07-02',
          'type': 'income',
          'label': 'B',
          'amount': 1.5e308,
        },
        {
          'date': '2026-07-03',
          'type': 'expense',
          'label': 'Food',
          'amount': 100,
        },
      ],
    }, DateTime(2026, 7, 15));
    expect(recap['keptRate'], isNull);
    expect(recap['verdict'], contains('tracked July honestly'));
  });

  test('the guarded recap renders as text without throwing', () {
    final recap = monthRecap({
      'transactions': [
        {
          'date': '2026-07-01',
          'type': 'income',
          'label': 'A',
          'amount': 1.5e308,
        },
        {
          'date': '2026-07-02',
          'type': 'income',
          'label': 'B',
          'amount': 1.5e308,
        },
      ],
    }, DateTime(2026, 7, 15));
    final text = recapText(recap, (n) => n.toString(), true);
    expect(text, isNotEmpty);
    expect(text.contains('NaN'), isFalse);
  });

  test('a normal month is untouched by the guard', () {
    final recap = monthRecap({
      'transactions': [
        {
          'date': '2026-07-01',
          'type': 'income',
          'label': 'Sweldo',
          'amount': 20000,
        },
        {
          'date': '2026-07-02',
          'type': 'expense',
          'label': 'Food',
          'amount': 5000,
        },
      ],
    }, DateTime(2026, 7, 15));
    expect(recap['keptRate'], 0.75);
  });
}
