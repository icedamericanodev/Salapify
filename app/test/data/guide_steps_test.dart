// Does a ticked checklist box survive, and does it survive the right things?
//
// The business startup guide is thirty government steps that take weeks of
// real life to get through, so the tick is the whole point of it. Founder
// direction, 2026-09-22, chose "save them, include in backup" over the two
// cheaper options, which makes this the first thing Salapify 3 stores that is
// not money.
//
// That puts it squarely in the category this repository stops for: stored
// data. So the round trip is measured here rather than assumed, including the
// three ways a store like this usually goes wrong.
//   1. It writes, and the next launch cannot read it back.
//   2. It reads, and quietly drops an id it does not recognise, which unticks
//      somebody's checklist the next time anything is saved.
//   3. It survives a wipe, so a phone handed to somebody else still says how
//      far into registering a business the last owner had got.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/state/financial_state.dart';

void main() {
  FinancialState fresh() => FinancialState(clock: DateTime.utc(2026, 9, 22));

  group('a tick survives the file', () {
    test('ticking writes it and reading gets it back', () {
      final FinancialState s = fresh();
      expect(s.isGuideStepDone('chk_dti_sec'), isFalse);

      s.toggleGuideStep('chk_dti_sec');
      s.toggleGuideStep('chk_brgy');

      final Snapshot reloaded = Snapshot.fromJson(
        s.snapshot().toJson(at: DateTime.utc(2026, 9, 22)),
      );
      expect(reloaded.guideSteps, <String>{'chk_dti_sec', 'chk_brgy'});
    });

    test('ticking twice unticks, and that also persists', () {
      final FinancialState s = fresh();
      s.toggleGuideStep('chk_dti_sec');
      s.toggleGuideStep('chk_dti_sec');
      expect(s.isGuideStepDone('chk_dti_sec'), isFalse);

      final Snapshot reloaded = Snapshot.fromJson(
        s.snapshot().toJson(at: DateTime.utc(2026, 9, 22)),
      );
      expect(reloaded.guideSteps, isEmpty);
    });

    test('an untouched checklist adds no key to the file at all', () {
      // Somebody who never opens a guide should not pay a byte for it, and a
      // backup file that gains "guideSteps": [] on every save is noise in
      // every diff forever.
      final Map<String, dynamic> json = fresh().snapshot().toJson(
        at: DateTime.utc(2026, 9, 22),
      );
      expect(json.containsKey(Snapshot.kGuideSteps), isFalse);
    });

    test(
      'the same two ticks always write the same list, in the same order',
      () {
        // Insertion order is a Set's iteration order, so without the sort two
        // identical checklists would write the key two different ways and every
        // diff of a backup file would be noisy for no reason.
        //
        // This asserts the KEY, not the whole encoded document, and the first
        // version did the latter. That version passed on its own and failed in
        // the full suite, because comparing two entire snapshots drags in every
        // other field, and this file mints several ids from
        // DateTime.now().microsecondsSinceEpoch. So it was testing determinism
        // of the whole document while claiming to test the ordering of one
        // list, and it was flaky for a reason that had nothing to do with what
        // it was guarding. A flaky guard gets ignored, and then it is not there
        // for the real thing.
        List<Object?> written(List<String> taps) {
          final FinancialState s = fresh();
          for (final String t in taps) {
            s.toggleGuideStep(t);
          }
          return s.snapshot().toJson(
                at: DateTime.utc(2026, 9, 22),
              )[Snapshot.kGuideSteps]
              as List<Object?>;
        }

        expect(
          written(<String>['chk_brgy', 'chk_dti_sec']),
          written(<String>['chk_dti_sec', 'chk_brgy']),
        );
        expect(written(<String>['chk_brgy', 'chk_dti_sec']), <String>[
          'chk_brgy',
          'chk_dti_sec',
        ], reason: 'sorted, not insertion ordered');
      },
    );
  });

  group('reading is lenient, because these are checkboxes', () {
    test('an id this build has never heard of is KEPT, not dropped', () {
      // The failure this guards is silent and permanent: a newer build, or a
      // guide whose steps were renamed, writes ids this build does not know.
      // Dropping them here would untick a real person's checklist on the very
      // next save, and nothing would ever say so.
      final Snapshot s = Snapshot.fromJson(<String, dynamic>{
        'accounts': <dynamic>[],
        Snapshot.kGuideSteps: <dynamic>['chk_dti_sec', 'chk_from_the_future'],
      });
      expect(s.guideSteps, contains('chk_from_the_future'));
    });

    test('a malformed key never stops the ledger loading', () {
      // A tickbox must not be able to lock somebody out of their accounts.
      // Same argument reminderSettings and the notification tray already make
      // in snapshot.dart, and it applies harder to this.
      for (final Object? bad in <Object?>[
        'not a list',
        42,
        <String, dynamic>{'nope': true},
        null,
      ]) {
        final Snapshot s = Snapshot.fromJson(<String, dynamic>{
          'accounts': <dynamic>[],
          Snapshot.kGuideSteps: bad,
        });
        expect(s.guideSteps, isEmpty, reason: 'on $bad');
      }
    });

    test('junk inside a good list is skipped, the rest survives', () {
      final Snapshot s = Snapshot.fromJson(<String, dynamic>{
        'accounts': <dynamic>[],
        Snapshot.kGuideSteps: <dynamic>['chk_ok', '', 7, null, 'chk_also_ok'],
      });
      expect(s.guideSteps, <String>{'chk_ok', 'chk_also_ok'});
    });
  });

  group('counting', () {
    test('progress counts only steps the guide still lists', () {
      // A step ticked and later removed from the guide keeps its tick, per
      // the rule above, but must not push that guide past 100%.
      final FinancialState s = fresh();
      s.toggleGuideStep('chk_a');
      s.toggleGuideStep('chk_retired');

      expect(s.guideStepsDoneAmong(<String>['chk_a', 'chk_b']), 1);
      expect(s.isGuideStepDone('chk_retired'), isTrue);
    });
  });

  group('a wipe really is a wipe', () {
    test('deleteEverything clears the ticks too', () async {
      // The wipe screen says "Salapify is empty". A checklist still reading
      // 14 of 30 done would make that sentence false, and this is exactly the
      // record somebody handing on a phone means to erase.
      final FinancialState s = fresh();
      s.toggleGuideStep('chk_dti_sec');
      expect(s.guideSteps, isNotEmpty);

      await s.deleteEverything();

      expect(s.guideSteps, isEmpty);
      final Map<String, dynamic> json = s.snapshot().toJson(
        at: DateTime.utc(2026, 9, 22),
      );
      expect(json.containsKey(Snapshot.kGuideSteps), isFalse);
    });
  });

  group('this is not a ledger', () {
    test('guideSteps is not one of the collections that identify a file', () {
      // A file holding nothing but ticked checkboxes must not pass the gate
      // and restore as an empty book, which is the exact trap the
      // notifications key is already kept out of.
      expect(Snapshot.collectionKeys, isNot(contains(Snapshot.kGuideSteps)));
    });
  });
}
