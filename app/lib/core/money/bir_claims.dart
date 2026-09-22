import '../../models/models.dart';

/// What a person could put in front of the BIR, out of what they have logged.
///
/// Founder spec, 2026-09-20, feature 4, the "Tax-Deductible & BIR Receipts
/// Hub". The filtering and the totals are the spec's. Two things are not, and
/// both are here because the spec's own wording asks for something its
/// formula does not deliver.
///
/// ## "Substantiated" has to mean substantiated
///
/// The spec's third metric is "Substantiated Receipts Count" and computes it
/// as `deductibleTransactions.length`, which is every row somebody ticked. A
/// tick is not substantiation. Section 34 of the Tax Code lets the
/// Commissioner disallow a deduction that is not supported by adequate
/// records, and in practice that means the official receipt or the sales
/// invoice, with the supplier's TIN on it. A row marked deductible with no
/// reference and no photograph is a claim with nothing behind it.
///
/// Counting those as substantiated is the worst possible direction to be
/// wrong in, because the number exists to tell somebody how much of their
/// claim they could actually defend. So this splits them: [substantiated]
/// carries a reference or an attached receipt, [unsupported] does not, and
/// the screen shows both.
///
/// ## The tax shield is NOT a flat quarter of the total
///
/// The spec asks for `totalClaimable * 0.25`. Three things make that wrong
/// often enough to matter, and a tax figure that is wrong is worse than no
/// tax figure at all:
///
///  1. UNDER THE 8 PERCENT ELECTION THERE ARE NO ITEMISED DEDUCTIONS. A
///     freelancer who elected it saves nothing from these receipts. Their
///     shield is zero, not a quarter.
///  2. UNDER THE OPTIONAL STANDARD DEDUCTION the deduction is 40 percent of
///     gross sales whatever the receipts say. Again the shield is not
///     computed from this total.
///  3. EVEN ON GRADUATED AND ITEMISED, 25 percent is one bracket of six. The
///     graduated table runs 0, 15, 20, 25, 30 and 32 percent, so the saving
///     depends on the income the deduction comes off. Somebody under the
///     250,000 exemption saves nothing at all, and quoting them a quarter of
///     their receipts is telling them money is coming that is not.
///
/// So [taxShieldAt] takes the rate as an argument and the caller has to say
/// which one it is using. There is no default, on purpose: a default is how
/// a made-up rate ends up on a screen with a peso sign in front of it.

/// A transaction is claimable when the person said so, or when it is filed
/// under the app's own business category, or when it carries the tag.
///
/// THE CATEGORY NAME IS THE APP'S. The spec tests `t.category == 'Business'`
/// and Salapify's category is 'Business & Freelance Ops', so the spec's test
/// matches nothing at all and the whole business half of the feature would
/// be silently empty. This is the third time the spec's category vocabulary
/// has differed from the app's; see receipt_ocr.dart for the first.
const String businessCategory = 'Business & Freelance Ops';

/// The tag somebody can put on an entry to claim it without changing its
/// category.
const String claimableTag = 'tax-deductible';

bool isClaimable(Transaction t) =>
    t.type == TransactionType.expense &&
    t.countsTowardTotals &&
    (t.isTaxDeductible ||
        t.category == businessCategory ||
        t.tags.contains(claimableTag));

/// True when a claim has something behind it.
///
/// A stored reference (an OR or SI number, or the supplier's TIN) or an
/// attached image of the receipt. Either is evidence; a tick on its own is
/// not.
bool isSubstantiated(Transaction t) =>
    (t.taxTinOrRef != null && t.taxTinOrRef!.trim().isNotEmpty) ||
    t.hasAttachment;

class BirClaimSummary {
  const BirClaimSummary({
    required this.entries,
    required this.totalClaimable,
    required this.substantiated,
    required this.substantiatedAmount,
    required this.unsupported,
    required this.unsupportedAmount,
  });

  /// Every claimable expense in the period, newest first as they arrived.
  final List<Transaction> entries;

  final double totalClaimable;

  /// Claims with a reference or a receipt image behind them.
  final int substantiated;
  final double substantiatedAmount;

  /// Claims with neither. Shown, never hidden: this is the figure that tells
  /// somebody what they still have to go and find.
  final int unsupported;
  final double unsupportedAmount;

  int get count => entries.length;
  bool get any => entries.isNotEmpty;

  /// What the deduction is worth AT A RATE THE CALLER NAMES.
  ///
  /// No default rate. See the header: the spec's flat 25 percent is zero for
  /// anyone on the 8 percent election or the OSD, and one bracket of six for
  /// everybody else.
  double taxShieldAt(double rate) {
    if (rate <= 0) return 0;
    // Only what could be defended. Quoting a saving on claims with no
    // receipt behind them is quoting a saving that gets disallowed.
    return substantiatedAmount * rate;
  }
}

/// Everything the hub shows, from the transactions of the active period.
///
/// [transactions] must ALREADY be filtered to the period by the caller, the
/// same way every other figure on the Reports screen is, so the hub and the
/// numbers above it can never disagree about which month they are describing.
BirClaimSummary summariseClaims(List<Transaction> transactions) {
  final List<Transaction> entries = transactions.where(isClaimable).toList();

  double total = 0;
  int substantiated = 0;
  double substantiatedAmount = 0;
  int unsupported = 0;
  double unsupportedAmount = 0;

  for (final Transaction t in entries) {
    final double amount = t.amount;
    total += amount;
    if (isSubstantiated(t)) {
      substantiated += 1;
      substantiatedAmount += amount;
    } else {
      unsupported += 1;
      unsupportedAmount += amount;
    }
  }

  return BirClaimSummary(
    entries: entries,
    totalClaimable: total,
    substantiated: substantiated,
    substantiatedAmount: substantiatedAmount,
    unsupported: unsupported,
    unsupportedAmount: unsupportedAmount,
  );
}

/// The graduated brackets, as MARGINAL rates, for the one place the hub is
/// allowed to name a percentage.
///
/// These are the TRAIN rates in force from 2023, and they are here so the
/// screen can offer the person their own bracket rather than assume one.
/// Naming the bracket is what turns "you will save 12,000" into "if you are
/// in the 20 percent band, this is worth about 12,000", and only the second
/// of those is a sentence Salapify can stand behind.
const List<({String label, double rate})> graduatedBrackets =
    <({String label, double rate})>[
      (label: 'Up to ₱250,000, no income tax', rate: 0.0),
      (label: '₱250,000 to ₱400,000', rate: 0.15),
      (label: '₱400,000 to ₱800,000', rate: 0.20),
      (label: '₱800,000 to ₱2,000,000', rate: 0.25),
      (label: '₱2,000,000 to ₱8,000,000', rate: 0.30),
      (label: 'Over ₱8,000,000', rate: 0.35),
    ];
