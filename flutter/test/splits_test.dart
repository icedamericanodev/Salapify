// Unit suite for money/splits.dart: the Hatian bill split engine. Net new math
// with no RN counterpart, so it is covered by these Dart tests. The invariant
// that must never break: the shares ALWAYS sum to the total to the centavo, for
// even and uneven divisions alike, so the app never invents or drops a peso.
// Also: your own share is separated from what is coming back, custom amounts
// are honored, include and exclude works, and junk never throws.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/splits.dart';

void main() {
  // Every included share, in centavos, must sum to the total in centavos.
  void expectSumsToTotal(Map<String, dynamic> r) {
    expect(r['ok'], true, reason: 'expected a successful split');
    final total = (r['total'] as num).toDouble();
    var sum = 0.0;
    for (final s in r['shares'] as List) {
      sum += (s['share'] as num).toDouble();
    }
    expect((sum * 100).round(), (total * 100).round(),
        reason: 'shares must sum to the total to the centavo');
    // yourShare + toCollect is the same identity, from the other direction.
    final your = (r['yourShare'] as num).toDouble();
    final collect = (r['toCollect'] as num).toDouble();
    expect(((your + collect) * 100).round(), (total * 100).round());
  }

  group('an even split lands exactly', () {
    final r = splitExpense(3000, [
      {'name': 'You', 'isYou': true},
      {'name': 'Juan'},
      {'name': 'Maria'},
    ]);
    test('each share is the equal part', () {
      for (final s in r['shares'] as List) {
        expect(s['share'], 1000);
      }
    });
    test('your share is separated from what is coming back', () {
      expect(r['yourShare'], 1000);
      expect(r['toCollect'], 2000);
      expect(r['collectFrom'], 2);
    });
    test('the shares sum to the total', () => expectSumsToTotal(r));
  });

  group('an uneven split gives leftover centavos to the first people', () {
    // 1000 / 3 = 333.34, 333.33, 333.33 (the first person absorbs the centavo).
    final r = splitExpense(1000, [
      {'name': 'You', 'isYou': true},
      {'name': 'Juan'},
      {'name': 'Maria'},
    ]);
    test('first share carries the extra centavo', () {
      final shares = (r['shares'] as List).map((s) => s['share']).toList();
      expect(shares, [333.34, 333.33, 333.33]);
    });
    test('the shares still sum to the total', () => expectSumsToTotal(r));
    test('what is coming back is exact', () {
      // You are turn 1 so you carry the extra centavo; collect 333.33 + 333.33.
      expect(r['yourShare'], 333.34);
      expect(r['toCollect'], 666.66);
    });
  });

  group('excluding a person removes them from the split', () {
    final r = splitExpense(900, [
      {'name': 'You', 'isYou': true},
      {'name': 'Juan'},
      {'name': 'Lola', 'included': false},
    ]);
    test('only the two included people split it', () {
      expect((r['shares'] as List).length, 2);
      for (final s in r['shares'] as List) {
        expect(s['share'], 450);
      }
    });
    test('sums to total', () => expectSumsToTotal(r));
  });

  group('you can front the bill but owe nothing yourself', () {
    // You paid but did not eat: exclude yourself, collect the whole total.
    final r = splitExpense(600, [
      {'name': 'You', 'isYou': true, 'included': false},
      {'name': 'Juan'},
      {'name': 'Maria'},
    ]);
    test('your share is zero and the whole total is coming back', () {
      expect(r['yourShare'], 0);
      expect(r['toCollect'], 600);
      expect(r['collectFrom'], 2);
    });
  });

  group('only you left in still balances', () {
    final r = splitExpense(500, [
      {'name': 'You', 'isYou': true},
      {'name': 'Juan', 'included': false},
    ]);
    test('you owe the whole thing, nothing to collect', () {
      expect(r['yourShare'], 500);
      expect(r['toCollect'], 0);
      expect(r['collectFrom'], 0);
    });
  });

  group('custom amounts are honored and the rest split the remainder', () {
    // Total 1000. Juan is sagot for 400 exactly; you and Maria split the 600.
    final r = splitExpense(1000, [
      {'name': 'You', 'isYou': true},
      {'name': 'Juan', 'amount': 400},
      {'name': 'Maria'},
    ]);
    test('the custom amount is kept', () {
      final juan = (r['shares'] as List).firstWhere((s) => s['name'] == 'Juan');
      expect(juan['share'], 400);
      expect(juan['custom'], true);
    });
    test('you and Maria split the remaining 600', () {
      expect(r['yourShare'], 300);
      final maria =
          (r['shares'] as List).firstWhere((s) => s['name'] == 'Maria');
      expect(maria['share'], 300);
    });
    test('sums to total', () => expectSumsToTotal(r));
    test('to collect is Juan 400 plus Maria 300', () {
      expect(r['toCollect'], 700);
      expect(r['collectFrom'], 2);
    });
  });

  group('problems the user must fix are surfaced, not papered over', () {
    test('custom amounts over the total are refused', () {
      final r = splitExpense(500, [
        {'name': 'You', 'isYou': true, 'amount': 400},
        {'name': 'Juan', 'amount': 400},
      ]);
      expect(r['ok'], false);
      expect(r['error'], 'over');
    });
    test('all-custom that does not add up reports the gap', () {
      final r = splitExpense(1000, [
        {'name': 'You', 'isYou': true, 'amount': 400},
        {'name': 'Juan', 'amount': 400},
      ]);
      expect(r['ok'], false);
      expect(r['error'], 'mismatch');
      expect(r['gap'], 200); // 1000 - 800 still unassigned
    });
    test('a negative total is refused', () {
      final r = splitExpense(-5, [
        {'name': 'You', 'isYou': true},
      ]);
      expect(r['ok'], false);
      expect(r['error'], 'total');
    });
    test('nobody included is refused', () {
      final r = splitExpense(500, [
        {'name': 'You', 'isYou': true, 'included': false},
      ]);
      expect(r['ok'], false);
      expect(r['error'], 'empty');
    });
  });

  group('junk never throws', () {
    test('a junk total and junk rows are safe', () {
      final r = splitExpense('abc', [
        {'name': 'You', 'isYou': true},
        'not a map',
        {'name': 'Juan', 'amount': 'xyz'}, // junk custom falls back to equal
      ]);
      // total 'abc' -> 0 centavos, so an all-zero even split that still sums.
      expect(r['ok'], true);
      expect(r['total'], 0);
      expectSumsToTotal(r);
    });
    test('a null participant list is refused, not a crash', () {
      final r = splitExpense(100, null);
      expect(r['ok'], false);
      expect(r['error'], 'empty');
    });
  });

  group('equalShare preview is centavo safe', () {
    test('even', () => expect(equalShare(900, 3), 300));
    test('uneven rounds the first person up', () => expect(equalShare(1000, 3), 333.34));
    test('bad count is zero', () => expect(equalShare(1000, 0), 0));
    test('bad total is zero', () => expect(equalShare(-1, 3), 0));
  });
}
