// Hidden accounts, and the ways a visibility rule can make an app lie about
// what somebody has.
//
// The founder proposed two rules, "a hidden account does not count" or "it
// still counts", and asked specialists to settle it. The answer was that those
// are two different NUMBERS: net worth is what you OWN, safe to spend is what
// you can TOUCH. Each of their rules is right about one of them. These tests
// are that split, made unfalsifiable.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/commitments.dart' show safeToSpend;
import 'package:salapify/core/money/statements.dart' show netWorthParts;
import 'package:salapify/core/money/ledger.dart' show amountOf;
import 'package:salapify/core/state/visibility.dart';
import 'package:salapify/dev/sample_ledger.dart' show sampleAnchor;

import '../support/memory_store.dart';

double _netWorth(Map<String, dynamic> d) =>
    amountOf(netWorthParts(d)['netWorth']);

/// The lived-in ledger with one account flagged.
Map<String, dynamic> _withFlag(String id, String key, dynamic value) {
  final d = livedIn();
  for (final a in (d['accounts'] as List)) {
    if (a is Map && a['id'] == id) a[key] = value;
  }
  return d;
}

void main() {
  group('hiding changes NOTHING about what you own', () {
    test('net worth is byte-identical before and after hiding', () {
      // THE INVARIANT. Hiding a row from a list cannot change who owns the
      // money. If this ever fails, the app is telling somebody they got poorer
      // by tidying their screen.
      final before = livedIn();
      final after = _withFlag('a_bpi', 'isArchived', true);

      expect(_netWorth(after), _netWorth(before));

      // Did anything happen. The invariant above also holds when the flag was
      // never written, which is the failure mode that passes hardest when the
      // feature is most broken.
      final flagged = (after['accounts'] as List).where(
        (a) => a is Map && a['isArchived'] == true,
      );
      expect(
        flagged,
        hasLength(1),
        reason: 'the fixture was not actually flagged, so this proves nothing',
      );
      expect(Excluded.of(after).hiddenCount, 1);
      expect(
        Excluded.of(after).fromNetWorth,
        0,
        reason:
            'hiding took money out of net worth, which tells somebody they '
            'own less because they tidied a list',
      );
    });

    test('but it DOES leave what you can spend', () {
      // The other half, and the founder's second rule, correct about the other
      // number. A safe-to-spend figure that is too high makes people overspend.
      //
      // GCash, not BPI. `liquidKinds` is cash, ewallet and checking, so a
      // SAVINGS account is not in safe to spend to begin with. An earlier
      // version of this test hid BPI and expected 42,300 to leave a figure it
      // was never part of: the test was wrong about the fixture, not the code
      // wrong about the rule.
      final after = _withFlag('a_gcash', 'isArchived', true);
      final gcash =
          (after['accounts'] as List).firstWhere(
                (a) => a is Map && a['id'] == 'a_gcash',
              )
              as Map;

      expect(amountOf(gcash['balance']), greaterThan(0));
      expect(
        Excluded.of(after).fromSpendable,
        amountOf(gcash['balance']),
        reason:
            'hidden money is still counted as spendable, so the app offers a '
            'fortnight budget that includes money the user put out of sight',
      );
    });
  });

  group('money you hold but do not own', () {
    test('leaves net worth, and says by how much', () {
      // The paluwagan case: this month's pot is sitting in your GCash and it
      // leaves on a fixed date. Counting it as your wealth is a lie with a
      // deadline.
      final data = _withFlag('a_gcash', 'includeInNetWorth', false);
      final gcash =
          (data['accounts'] as List).firstWhere(
                (a) => a is Map && a['id'] == 'a_gcash',
              )
              as Map;

      final excluded = Excluded.of(data);
      expect(excluded.notMineCount, 1);
      expect(excluded.fromNetWorth, amountOf(gcash['balance']));
      expect(
        excluded.fromNetWorth,
        greaterThan(0),
        reason:
            'the fixture account holds nothing, so this test cannot tell a '
            'working exclusion from a broken one',
      );
    });

    test('and it leaves what you can spend too', () {
      // You cannot spend what is not yours. Both flags take a row out of
      // spendable; only this one takes it out of net worth.
      final data = _withFlag('a_gcash', 'includeInNetWorth', false);
      expect(Excluded.of(data).fromSpendable, greaterThan(0));
    });

    test('excluding somebody ELSE\'S debt is not a loss', () {
      // The sign trap. A liability that is not yours lowers what you owe, so
      // removing it RAISES net worth. Summed blindly it would look like money
      // disappearing.
      final data = livedIn();
      for (final x in (data['debts'] as List)) {
        if (x is Map && x['id'] == 'd_lola') x['includeInNetWorth'] = false;
      }

      expect(
        Excluded.of(data).fromNetWorth,
        lessThan(0),
        reason:
            'a debt that is not yours was treated as money leaving your net '
            'worth, so disowning a debt would make you look poorer',
      );
    });
  });

  group('the rules never fire when they should not', () {
    test('an untouched ledger excludes nothing at all', () {
      // The other half of the alarm. A rule that fires on a normal ledger
      // would quietly restate everybody's net worth.
      final e = Excluded.of(livedIn());
      expect(e.fromNetWorth, 0);
      expect(e.fromSpendable, 0);
      expect(e.notMineCount, 0);
      expect(e.hiddenCount, 0);
      expect(e.anyHidden, isFalse);
      expect(e.anyNotMine, isFalse);
    });

    test('an empty ledger does not throw or invent a figure', () {
      final e = Excluded.of(<String, dynamic>{});
      expect(e.fromNetWorth, 0);
      expect(e.fromSpendable, 0);
    });

    test('a NON-liquid hidden account does not touch safe to spend', () {
      // Safe to spend only ever looked at liquid accounts, so only those can
      // be taken out of it. Subtracting a hidden investment would lower a
      // figure it was never part of.
      final data = livedIn();
      (data['accounts'] as List).add({
        'id': 'a_td',
        'name': 'Time deposit',
        'kind': 'savings',
        'balance': 50000.0,
        'isArchived': true,
      });

      final e = Excluded.of(data);
      expect(e.hiddenCount, 1);
      expect(
        e.fromSpendable,
        0,
        reason:
            'a hidden savings account was subtracted from safe to spend, '
            'which never included it',
      );
    });

    test('a FOREIGN row is skipped, exactly as net worth skips it', () {
      // netWorthParts refuses to add a dollar balance into a peso total. A
      // subtraction that did not make the same choice would take away money
      // the total never added, and net worth would fall for a reason nobody
      // could find.
      final data = livedIn();
      (data['accounts'] as List).add({
        'id': 'a_usd',
        'name': 'USD savings',
        'kind': 'savings',
        'balance': 1000.0,
        'currencyCode': 'USD',
        'includeInNetWorth': false,
      });

      expect(
        Excluded.of(data).fromNetWorth,
        0,
        reason:
            'a foreign balance was subtracted from a peso total it was never '
            'part of, so net worth dropped by money that was never in it',
      );
    });
  });

  group('the filtered ledger, which is how the rule reaches a figure', () {
    // No screen and no state file subtracts anything from a total. The rows
    // are removed and the GOLDEN LOCKED engine answers the same question it
    // always answers. These tests are what makes that claim checkable.

    test('what the engine returns MATCHES what Excluded measured', () {
      // The drift guard. Two things now describe the same exclusion: the
      // filtered ledger produces the figure, and `Excluded` produces the
      // sentence beside it. If they ever disagree, the hero says one thing and
      // the line under it says another, on the same panel.
      final data = _withFlag('a_gcash', 'includeInNetWorth', false);

      final full = amountOf(netWorthParts(data)['netWorth']);
      final owned = amountOf(netWorthParts(ownedOnly(data))['netWorth']);

      expect(owned, closeTo(full - Excluded.of(data).fromNetWorth, 0.005));
      expect(
        owned,
        lessThan(full),
        reason:
            'filtering the ledger changed nothing, so the hero is still '
            'counting money the user said is not theirs',
      );
    });

    test('ownedOnly KEEPS a hidden row, because hiding is not disowning', () {
      final data = _withFlag('a_bpi', 'isArchived', true);
      expect(
        amountOf(netWorthParts(ownedOnly(data))['netWorth']),
        amountOf(netWorthParts(livedIn())['netWorth']),
      );
      expect(
        (ownedOnly(data)['accounts'] as List).length,
        (data['accounts'] as List).length,
        reason: 'a hidden account was dropped from the net worth ledger',
      );
    });

    test('spendableOnly takes hidden liquid money out of safe to spend', () {
      final data = _withFlag('a_gcash', 'isArchived', true);
      final gcash =
          (data['accounts'] as List).firstWhere(
                (a) => a is Map && a['id'] == 'a_gcash',
              )
              as Map;

      final before = safeToSpend(livedIn(), sampleAnchor);
      final after = safeToSpend(spendableOnly(data), sampleAnchor);

      // DIRECTIONAL. "The figure did not go up" would also pass if the filter
      // did nothing at all.
      expect(
        amountOf(after['liquid']),
        closeTo(amountOf(before['liquid']) - amountOf(gcash['balance']), 0.005),
      );
      expect(
        amountOf(after['available']),
        lessThan(amountOf(before['available'])),
      );
    });

    test('but a hidden DEBT is still committed, because the bill is still due', () {
      // The trap this rule exists to avoid. Filtering debts out would forgive
      // them, pushing safe to spend UP, which is the exact failure mode the
      // whole design was built around.
      //
      // THE FIXTURE HAD TO GROW A DEBT FOR THIS TEST TO MEAN ANYTHING. The
      // first version simply hid the lived-in ledger's own two debts and
      // asserted committed was unchanged. It passed with the guard deliberately
      // broken, because at the anchor date neither of those debts is due
      // inside the four days to payday, so neither was ever in the bill list
      // and filtering them out could not change a figure they were not part of.
      // A test that cannot reach the branch it guards is not a weak test, it
      // is a green light wired to nothing.
      Map<String, dynamic> withImminentDebt({required bool hidden}) {
        final d = livedIn();
        (d['debts'] as List).add({
          'id': 'd_due_now',
          'name': 'Card due this week',
          'subtype': 'credit_card',
          'remaining': 9000.00,
          'creditLimit': 30000.00,
          'dueDay': sampleAnchor.day + 1,
          'minPayment': 900.00,
          if (hidden) 'isArchived': true,
        });
        return d;
      }

      final baseline = amountOf(
        safeToSpend(livedIn(), sampleAnchor)['committed'],
      );
      final withDebt = amountOf(
        safeToSpend(withImminentDebt(hidden: false), sampleAnchor)['committed'],
      );

      // Did anything happen. Without this the assertion below is two equal
      // numbers that were never going to differ.
      expect(
        withDebt,
        greaterThan(baseline),
        reason:
            'the added debt never reached the bill list, so this test cannot '
            'tell a preserved commitment from a forgiven one',
      );

      expect(
        amountOf(
          safeToSpend(
            spendableOnly(withImminentDebt(hidden: true)),
            sampleAnchor,
          )['committed'],
        ),
        withDebt,
        reason:
            'hiding a debt lowered what is committed, so the app now offers '
            'to spend money that a bill is already claiming',
      );
    });

    test('filtering never touches the ledger it was given', () {
      // The result is shallow on purpose and must never be written back. This
      // pins the half that would be a data loss bug rather than a display one.
      final data = _withFlag('a_gcash', 'includeInNetWorth', false);
      final countBefore = (data['accounts'] as List).length;

      ownedOnly(data);
      spendableOnly(data);

      expect((data['accounts'] as List).length, countBefore);
      expect(data['accounts'], hasLength(greaterThan(0)));
    });
  });

  group('the two flags mean two different things', () {
    test('hidden is not not-mine, and the pair is closed', () {
      final hidden = {'isArchived': true};
      final notMine = {'includeInNetWorth': false};
      final closed = {'isArchived': true, 'includeInNetWorth': false};
      const plain = <String, dynamic>{};

      expect(isHiddenFromLists(hidden), isTrue);
      expect(
        countsAsOwned(hidden),
        isTrue,
        reason: 'hiding took ownership away',
      );
      expect(countsAsSpendable(hidden), isFalse);

      expect(isHiddenFromLists(notMine), isFalse);
      expect(countsAsOwned(notMine), isFalse);
      expect(countsAsSpendable(notMine), isFalse);

      expect(countsAsOwned(closed), isFalse);
      expect(countsAsSpendable(closed), isFalse);

      // A row that predates the feature counts exactly as it always did.
      expect(countsAsOwned(plain), isTrue);
      expect(countsAsSpendable(plain), isTrue);
    });
  });
}
