// The six traps, and the five corrections that had to go into them.
//
// This tab is the one place in the guide that quotes PENALTIES, which is the
// sort of number somebody repeats to a business partner and acts on. The
// prototype got the headline one wrong in both directions, so the corrected
// figures are pinned here rather than left to a reviewer noticing again.
//
// Content tests, no widgets. Whether a person can SEE these is
// business_guide_journey_test.dart's job.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/business_guide_data.dart';

void main() {
  StartupTrap trapContaining(String needle) => startupTraps.firstWhere(
    (StartupTrap t) => t.body.contains(needle) || t.title.contains(needle),
    orElse: () => throw StateError('no trap mentions "$needle"'),
  );

  group('the shape holds', () {
    test('there are six, each with an expert, a title and a body', () {
      expect(startupTraps.length, 6);
      for (final StartupTrap t in startupTraps) {
        expect(t.expert, isNotEmpty);
        expect(t.title, isNotEmpty);
        expect(
          t.body.length,
          greaterThan(80),
          reason:
              'a warning too short '
              'to explain itself is worse than none',
        );
      }
    });

    test('no trap title repeats another', () {
      final Set<String> titles = <String>{
        for (final StartupTrap t in startupTraps) t.title,
      };
      expect(titles.length, startupTraps.length);
    });
  });

  group('Section 258, the figures the prototype got wrong', () {
    final StartupTrap t = trapContaining('Section 258');

    test('the fine is 5,000 to 20,000, not 10,000 to 50,000', () {
      // Verified against the Tax Code text during the port. The 30,000 to
      // 50,000 band in Section 258 is real but applies to businesses
      // distilling, rectifying, repacking, compounding or manufacturing
      // articles subject to excise tax. No reader of this app is one, so the
      // prototype quoted a band that does not apply AND raised the floor.
      expect(t.body, contains('5,000 to 20,000'));
      expect(t.body, isNot(contains('10,000')));
      expect(t.body, isNot(contains('50,000')));
    });

    test('it names the prison term, which the prototype omitted', () {
      expect(t.body, contains('six months to two years'));
    });

    test('not issuing an invoice is named as a SEPARATE offence', () {
      // The prototype merged Sections 258 and 264 under one citation, so a
      // reader would look up the wrong provision.
      expect(t.body, contains('Section 264'));
    });
  });

  group('the withholding trap explains what creditable means', () {
    final StartupTrap t = trapContaining('0.5%');

    test('the mechanic survived review and is stated', () {
      // 1% of one half really is how RR 16-2023 is drafted. The extraction
      // flagged it as looking self-contradictory and it is not.
      expect(t.body, contains('1% on half'));
      expect(t.body, contains('500,000'));
    });

    test('it says the tax is creditable rather than lost', () {
      // People routinely read a creditable withholding as a 0.5% haircut.
      expect(t.body, contains('CREDITABLE'));
    });
  });

  group('the zero rating error does not survive here either', () {
    // The same defect the checklist carried: promising a "zero-rated
    // invoice" with no mention that zero rating needs VAT registration.
    final StartupTrap t = trapContaining('merchant of record');

    test('it says zero rating needs VAT registration', () {
      expect(t.body, contains('VAT-registered'));
    });

    test('it does not leave the reader thinking the income is untaxed', () {
      expect(t.body.toLowerCase(), contains('never tax free'));
    });
  });

  group('the app store trap is not frozen at one moment in time', () {
    final StartupTrap t = trapContaining('storefront');

    test('it no longer promises an immediate rejection', () {
      // The prototype said linking to an external checkout "will cause an
      // immediate rejection", full stop. A 2025 US injunction and Google's
      // 2026 billing changes made that false in some places, and a list of
      // which storefront allows what this month would be wrong again by the
      // time anybody read it. So it points at the current rule instead.
      expect(t.body.toLowerCase(), isNot(contains('immediate rejection')));
      expect(t.body, contains('differs by country'));
    });

    test("Google's web link requirement is named, not just Apple's", () {
      expect(t.body, contains('web link'));
    });
  });

  group('no trap names a product that is mid-migration', () {
    test('Lemon Squeezy is not recommended by name', () {
      // Acquired in 2024 and migrating into its acquirer's own product.
      // Pointing a beginner at it by name points them at something moving.
      for (final StartupTrap t in startupTraps) {
        expect(t.body, isNot(contains('Lemon Squeezy')));
      }
    });
  });
}
