// The three question matcher, branch by branch.
//
// This is a DECISION, not a calculation, and it is the closest thing in the
// business guide to advice: somebody answers three questions and the app
// names a legal structure. So every reachable branch is pinned, including
// the two that are reached with questions left BLANK, because those are the
// ones a reader hits by tapping once and scrolling.
//
// The prototype's tree is reproduced exactly. Where its CONTENT was wrong the
// content was corrected during the port (see the 8% reasons below); where its
// LOGIC merely looks odd, the logic is kept, because changing which structure
// the app recommends is a different decision from fixing a tax sentence.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/business_guide_data.dart';

void main() {
  group('nothing is recommended until question one is answered', () {
    test('no owners answer gives no match at all', () {
      expect(matchEntity(), isNull);
      expect(matchEntity(owners: ''), isNull);
      // Even with the other two answered. A recommendation nobody asked for
      // is a recommendation somebody might act on.
      expect(matchEntity(liability: 'protected', funding: 'investors'), isNull);
    });
  });

  group('one founder', () {
    test('wanting their assets shielded gets an OPC', () {
      expect(
        matchEntity(owners: 'single', liability: 'protected')?.title,
        'One Person Corporation (OPC)',
      );
    });

    test('planning to raise money gets an OPC even at low risk', () {
      // The disjunction: either answer alone is enough.
      expect(
        matchEntity(
          owners: 'single',
          liability: 'low_risk',
          funding: 'investors',
        )?.title,
        'One Person Corporation (OPC)',
      );
    });

    test('low risk and self funded gets a sole proprietorship', () {
      expect(
        matchEntity(
          owners: 'single',
          liability: 'low_risk',
          funding: 'bootstrapped',
        )?.title,
        'Sole Proprietorship',
      );
    });

    test('answering only question one still lands somewhere sensible', () {
      // Reachable by one tap and a scroll, so it is pinned rather than left
      // to chance. The simplest structure is the right thing to show to
      // somebody who has told the app almost nothing.
      expect(matchEntity(owners: 'single')?.title, 'Sole Proprietorship');
    });
  });

  group('two or more founders', () {
    test('raising money gets a stock corporation', () {
      expect(
        matchEntity(owners: 'multiple', funding: 'investors')?.title,
        'Regular Stock Corporation',
      );
    });

    test('wanting shielded assets also gets a stock corporation', () {
      expect(
        matchEntity(owners: 'multiple', liability: 'protected')?.title,
        'Regular Stock Corporation',
      );
    });

    test('low risk and self funded gets a partnership', () {
      expect(
        matchEntity(
          owners: 'multiple',
          liability: 'low_risk',
          funding: 'bootstrapped',
        )?.title,
        'General or Limited Partnership',
      );
    });

    test('answering only question one lands on a partnership', () {
      expect(
        matchEntity(owners: 'multiple')?.title,
        'General or Limited Partnership',
      );
    });
  });

  group('every outcome is actually sayable', () {
    test('each match has a title, a summary and at least three reasons', () {
      // A branch that returns an empty card would pass every test above.
      for (final EntityMatch? m in <EntityMatch?>[
        matchEntity(owners: 'single', liability: 'protected'),
        matchEntity(owners: 'single', liability: 'low_risk'),
        matchEntity(owners: 'multiple', funding: 'investors'),
        matchEntity(owners: 'multiple', liability: 'low_risk'),
      ]) {
        expect(m, isNotNull);
        expect(m!.title, isNotEmpty);
        expect(m.summary, isNotEmpty);
        expect(m.reasons.length, greaterThanOrEqualTo(3));
        for (final String r in m.reasons) {
          expect(r, isNotEmpty);
        }
      }
    });
  });

  group('the tax corrections are IN the recommendation, not just the docs', () {
    // These four assertions are the port's most expensive correction, pinned
    // where somebody reads it rather than where it was written down.
    //
    // The prototype told a sole proprietor they were "eligible for simplified
    // 8% gross income tax under TRAIN law if revenue is under P3M". The 8% is
    // on GROSS SALES. Gross income in the Tax Code is sales less cost of
    // sales, so a reader applying it that way underpays: on 2,000,000 of
    // sales with 1,200,000 of costs the gap is roughly 96,000 before
    // surcharge and interest.
    final EntityMatch sole = matchEntity(
      owners: 'single',
      liability: 'low_risk',
    )!;
    final String eight = sole.reasons.firstWhere(
      (String r) => r.contains('8%'),
    );

    test('it says gross SALES, never gross income', () {
      expect(eight, contains('gross sales'));
      expect(
        eight.toLowerCase(),
        isNot(contains('gross income')),
        reason: 'this is the wording that made a reader underpay',
      );
    });

    test('it names the 250,000 the rate applies above', () {
      expect(eight, contains('250,000'));
    });

    test('it says you must be non-VAT to elect it', () {
      expect(eight.toLowerCase(), contains('non-vat'));
    });

    test('it says the election has a deadline and locks for the year', () {
      // A missed election deadline costs as much as a wrong rate: the
      // taxpayer is on graduated plus percentage tax for the whole year with
      // no way back.
      expect(eight.toLowerCase(), contains('first quarter'));
      expect(eight.toLowerCase(), contains('locked'));
    });

    test('the corporation rate carries BOTH CREATE conditions', () {
      // 20% needs taxable income at or under 5M AND assets at or under 100M.
      // The prototype stated one condition in one place and two in another.
      final EntityMatch corp = matchEntity(
        owners: 'multiple',
        funding: 'investors',
      )!;
      final String rate = corp.reasons.firstWhere(
        (String r) => r.contains('20%'),
      );
      expect(rate, contains('5M'));
      expect(rate, contains('100M'));
    });
  });
}
