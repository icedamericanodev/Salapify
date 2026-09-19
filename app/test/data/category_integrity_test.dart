import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

/// Category names are load bearing, and nothing was checking them.
///
/// A transaction stores its category as a STRING. The category manager counts
/// usage by matching that string, the fast-log parser returns one of these
/// strings, and the Log sheet's picker offers them. So a name that drifts by
/// one word is not a typo, it is a row whose spending is counted against
/// nothing and a category that looks unused and can therefore be deleted.
///
/// That is exactly what had happened. Two seeded transactions carried
/// "Business & Freelance Ops" and "Family & Remittance" while the list said
/// "Business & Freelance" and "Family Support", so a 6,000 padala sat in the
/// ledger and the Family category read as never used.
void main() {
  test('every transaction category exists in the category list', () {
    final Set<String> known = SeedData.categories
        .map((CategoryInfo c) => c.name)
        .toSet();

    final List<String> orphans = SeedData.transactions()
        .map((Transaction t) => t.category)
        .where((String c) => !known.contains(c))
        .toSet()
        .toList();

    expect(
      orphans,
      isEmpty,
      reason:
          'These categories are used by a transaction but are not in the '
          'category list, so their spending is counted against nothing and '
          'the category they were meant for looks unused: $orphans',
    );
  });

  test('every subcategory belongs to a category that exists', () {
    for (final Transaction t in SeedData.transactions()) {
      if (t.subcategory == null) continue;
      final CategoryInfo parent = SeedData.categories.firstWhere(
        (CategoryInfo c) => c.name == t.category,
        orElse: () => throw StateError('no category named ${t.category}'),
      );
      expect(
        parent.subcategories,
        contains(t.subcategory),
        reason:
            '${t.id} is filed under ${t.subcategory}, which is not one of '
            '${t.category}\'s sub-categories',
      );
    }
  });

  test('category names and ids are unique', () {
    final List<String> names = SeedData.categories
        .map((CategoryInfo c) => c.name)
        .toList();
    final List<String> ids = SeedData.categories
        .map((CategoryInfo c) => c.id)
        .toList();
    expect(names.toSet().length, names.length, reason: 'duplicate name');
    expect(ids.toSet().length, ids.length, reason: 'duplicate id');
  });

  test('the list carries the prototype\'s 21 categories, both sides and a '
      'transfer', () {
    // A count alone would pass on 21 wrong names, so the three that were
    // actually wrong are named. src/data/categories.ts is the source of truth.
    expect(SeedData.categories.length, 21);
    for (final String required in <String>[
      'Health & Medical',
      'Family Support & Remittance',
      'Business & Freelance Ops',
      'Side-hustle & Gig Income',
      'Investment & Passive Income',
      'Entertainment & Leisure',
      'Other Expenses',
      'Other Income',
    ]) {
      expect(
        SeedData.categories.any((CategoryInfo c) => c.name == required),
        isTrue,
        reason: '$required is missing or was paraphrased',
      );
    }

    expect(
      SeedData.categories
          .where((CategoryInfo c) => c.kind == CategoryKind.income)
          .length,
      7,
    );
    expect(
      SeedData.categories
          .where((CategoryInfo c) => c.kind == CategoryKind.both)
          .length,
      1,
      reason: 'Transfer is the only category that serves both sides',
    );
  });
}
