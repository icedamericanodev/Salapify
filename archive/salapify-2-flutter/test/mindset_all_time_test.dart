// Vectors for the all-time money-avoided total: the same win-amount sum the
// 30-day snapshot uses, with no date window.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/mindset_wins.dart';

void main() {
  test('sums every win with a usable amount, ignoring the date', () {
    final r = mindsetAllTimeAvoided([
      {'amount': 3200, 'date': '2020-01-01'}, // years ago still counts
      {'amount': 1800, 'date': '2026-08-01'},
      {'amount': 500, 'date': '2026-08-14'},
    ]);
    expect(r.total, closeTo(5500, 0.001));
    expect(r.count, 3);
  });

  test('a zero, negative, or non-numeric amount is not counted', () {
    final r = mindsetAllTimeAvoided([
      {'amount': 1000},
      {'amount': 0}, // a blank field, not avoided spending
      {'amount': -50},
      {'amount': 'x'},
      {'note': 'no amount at all'},
    ]);
    expect(r.total, closeTo(1000, 0.001));
    expect(r.count, 1);
  });

  test('empty and junk inputs are a clean zero, never a throw', () {
    expect(mindsetAllTimeAvoided(const []).total, 0);
    expect(mindsetAllTimeAvoided(const []).count, 0);
    expect(mindsetAllTimeAvoided(null).total, 0);
    expect(mindsetAllTimeAvoided('nope').count, 0);
    expect(mindsetAllTimeAvoided([null, 42, 'x']).count, 0);
  });
}
