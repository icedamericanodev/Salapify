import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/pan/pan_bans.dart';
import 'package:salapify/core/money/ph_tax.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

/// What the 13th month calculator is willing to SAY.
///
/// The arithmetic is pinned by ph_tax_golden_test.dart, which checks the
/// allocations count five and sum to the net and says nothing about their
/// words. That gap is how this shipped and stayed shipped:
///
///   category: 'Ipon & Pag-IBIG MP2'
///   name:     'Pag-IBIG MP2 / High-Yield Savings Boost'
///   note:     'Compounding wealth builder for long-term goals'
///
/// Three problems in one row, all of them on screen. It named a specific
/// product as the place to put money. It used "high-yield", which
/// pan_bans.dart already fails the build over everywhere Pan can reach. And
/// "compounding wealth builder" is a return claim about an instrument whose
/// dividend is declared annually out of the fund's net income and is not
/// guaranteed.
///
/// It survived because `bannedPhraseIn` is wired into pan_engine.dart and
/// nowhere else. That is the lesson this repository has now learned three
/// times in one month: A GUARD SCOPED TO A LOCATION IS A GUARD UNTIL THE
/// CONTENT MOVES. This file is the bans reaching a second place.
void main() {
  final ThirteenthMonthPlan plan = calculate13thMonthPay(
    basicMonthlySalary: 45000,
  );

  Iterable<String> copyOf(ThirteenthMonthAllocation a) => <String>[
    a.category,
    a.name,
    a.note,
  ];

  group('the split names no product and promises no return', () {
    test('every line passes the content bans', () {
      for (final ThirteenthMonthAllocation a in plan.allocations) {
        for (final String line in copyOf(a)) {
          final String? bad = bannedPhraseIn(line);
          expect(
            bad,
            isNull,
            reason: 'allocation ${a.id} says "$line", which trips "$bad"',
          );
        }
      }
    });

    test('and no bucket is a place to put money', () {
      // SEPARATE FROM THE BANS ABOVE, on purpose. `bannedPhraseIn` lets
      // Pag-IBIG, SSS and PhilHealth through by name, deliberately: naming
      // them when somebody asked about them is education and CLAUDE.md says
      // so. The rule here is narrower and applies because these buckets are
      // DESTINATIONS for the reader's own money rather than explanations.
      // Telling somebody which fund their 13th month should go into is not
      // teaching them what a fund is.
      const List<String> destinations = <String>[
        'mp2',
        'pag-ibig',
        'pagibig',
        'sss',
        'seabank',
        'gotyme',
        'maribank',
        'tonik',
        'cimb',
        'komo',
        'gcash',
        'maya',
        'bpi',
        'bdo',
      ];
      for (final ThirteenthMonthAllocation a in plan.allocations) {
        final String text = copyOf(a).join(' ').toLowerCase();
        for (final String d in destinations) {
          expect(
            text.contains(d),
            isFalse,
            reason: 'allocation ${a.id} points the money at "$d"',
          );
        }
      }
    });

    test('and every bucket still says what it is FOR', () {
      // The other half of the alarm. Stripping the copy to nothing would
      // pass both tests above and leave five unexplained percentages.
      for (final ThirteenthMonthAllocation a in plan.allocations) {
        expect(a.category, isNotEmpty, reason: a.id);
        expect(a.note.length, greaterThan(20), reason: '${a.id} note is bare');
      }
    });
  });

  group('the labels themselves', () {
    test('four of the five are real app categories, and one is not', () {
      // Recorded rather than fixed, because nothing files a transaction from
      // these: the sheet prints them. It matters only if somebody later
      // wires this to a write, at which point a label that is not a category
      // becomes the defect where money sits perfectly in the ledger and
      // vanishes from every summary that reads it.
      //
      // The savings bucket has no real counterpart, and that is correct:
      // putting money into savings is a TRANSFER in this app's model, not an
      // expense category, so there is nothing for it to match.
      final Set<String> real = SeedData.categories
          .map((CategoryInfo c) => c.name)
          .toSet();
      final List<String> notCategories = plan.allocations
          .map((ThirteenthMonthAllocation a) => a.category)
          .where((String c) => !real.contains(c))
          .toList();
      expect(
        notCategories,
        <String>['Savings and emergency fund'],
        reason:
            'a bucket label stopped matching a real category, or a new one '
            'appeared. Either is fine while these only print, and neither is '
            'fine the day one of them files a transaction.',
      );
    });
  });
}
