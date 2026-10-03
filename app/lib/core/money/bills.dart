import '../../models/models.dart';

/// Which expense category a scheduled item's payment should land in.
///
/// This lives in core/money/ rather than beside the screen because a category
/// is not decoration: it decides which summary a peso appears in. A payment
/// filed wrongly sits perfectly in the ledger and is missing from every
/// report that reads it, which is the hardest kind of defect to notice,
/// because nothing is ever blank and no total is ever obviously wrong.
///
/// ## What the prototype does, and why none of it is here
///
/// `markUpcomingPaid` in src/context/FinancialContext.tsx writes
/// `subcategory: 'Electricity (Meralco)'` on EVERY bill it pays. Paying
/// Spotify files it under electricity. That is not a category scheme, it is
/// the first example somebody wrote while testing.
///
/// ## Why a map and not a single fallback
///
/// The first version of this returned 'Bills & Utilities' for everything
/// without a stored category, and no seed item has a stored category, so in
/// practice every bill would have landed there, Spotify included. Honest, and
/// just as useless to somebody reading their own spending.
///
/// ## The guesses are named
///
/// Four of these are judgement calls rather than obvious, and they are flagged
/// here so the next person changes them deliberately:
///
///   - `subscription` goes to Entertainment & Leisure, which fits Spotify and
///     Netflix and does NOT fit a business software subscription. The pay
///     dialog offers a picker so that case can be corrected in one tap.
///   - `tuition` goes to Other Expenses because Salapify has no education
///     category. Inventing one here would be a category list change, which is
///     stored data and the founder's call, not a side effect of paying a bill.
///   - `government` goes to Other Expenses for the same reason: SSS, PhilHealth
///     and Pag-IBIG contributions are not utilities, and there is no
///     contributions category to put them in.
///   - `insurance` goes to Health & Medical, which fits HMO and life cover and
///     not motor insurance.
///
/// [UpcomingItemType.payday] has no entry it can reach, because income rows
/// never write an expense. It is mapped anyway so the switch stays exhaustive
/// and a new type cannot be added without someone deciding where it belongs.
String defaultCategoryFor(UpcomingItem item) {
  // A category the person actually stored always wins. The map is only ever a
  // starting point for an item that has none.
  final String? own = item.category;
  if (own != null && own.trim().isNotEmpty) return own;

  return switch (item.type) {
    UpcomingItemType.bill => 'Bills & Utilities',
    UpcomingItemType.subscription => 'Entertainment & Leisure',
    UpcomingItemType.debt => 'Debt & Loan Servicing',
    UpcomingItemType.rent => 'Housing & Rent',
    UpcomingItemType.remittance => 'Family Support & Remittance',
    UpcomingItemType.insurance => 'Health & Medical',
    UpcomingItemType.tuition => 'Other Expenses',
    UpcomingItemType.government => 'Other Expenses',
    UpcomingItemType.payday => 'Other Expenses',
  };
}
