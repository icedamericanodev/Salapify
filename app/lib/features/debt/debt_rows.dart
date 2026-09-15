// Debt, both ways, as a list. What you owe, and what is owed to you.
//
// 04-screens.md: "Segmented: I owe, Owed to me. Section Open: rows per person
// or lender ... Section Settled: settled rows tinted green with the name
// struck through."
//
// This file derives the rows and invents no money. Three stored collections
// feed it and they do NOT share a shape, which is the whole reason this file
// exists rather than the screen reading the ledger directly:
//
//   debts        formal borrowing (loans, installments, cards). Keyed on
//                `remaining`. Has an interest rate and a due day. Written by
//                core/money/debts.dart.
//   payables     informal "I owe Juan". Keyed on `amount` minus `payments`.
//   receivables  informal "Juan owes me". Same shape as payables. Written by
//                core/money/receivables.dart.
//
// THE ONE INVARIANT. The headline figure on this screen is computed by
// `debtTotals`, the SAME function Home's debt beam already calls, so the two
// surfaces can never disagree about what the founder owes. That is not
// defensive tidiness: Home says "Debt, both ways" in a card the user taps to
// get here, and a list that added up to something else would make the tap
// itself a bug report. `debt_test.dart` asserts the equality.
//
// WHAT COUNTS, and why some rows do not. `trackedRemaining` (golden locked)
// counts a payable or receivable only when `cashLeg` is true, meaning real
// money actually left a real account. A "legacy" utang recorded without a cash
// leg is a real debt that the ledger has no money movement for, so it is
// deliberately absent from net worth. Those rows are still LISTED here, marked
// `countsInTotal: false`, because hiding a debt the founder recorded is worse
// than explaining one. The headline stays the tracked total either way, so
// listing them cannot pull the two screens apart.
import '../../core/money/account_taxonomy.dart' show AccountStore, resolveKind;
import '../../core/money/debtmath.dart' show dueDateFor;
import '../../core/money/format.dart' show formatMoney;
import '../../core/money/ledger.dart' show amountOf;
import '../../core/money/receivables.dart' show paidSumOf, remainingOf;
import '../accounts/accounts_screen.dart'
    show DebtTotals, debtTotals, rollsIntoDebtSummary;

/// Which way the money goes.
enum DebtDirection {
  /// What the founder owes: the `debts` collection plus `payables`.
  iOwe,

  /// What other people owe the founder: `receivables`.
  owedToMe,
}

/// Which stored collection a row came from.
///
/// Carried rather than inferred, because it decides what can be DONE with the
/// row. `debts` and `receivables` both have a ported write engine; `payables`
/// does not, in this app or in the two frozen ones, so a payable is read only
/// until that engine is ported. A screen that offered a Record payment button
/// over a collection with no write path would be a dead control.
enum DebtSource { debts, payables, receivables }

/// One lender, or one person, as the screen draws them.
class DebtRow {
  const DebtRow({
    required this.id,
    required this.name,
    required this.remaining,
    required this.original,
    required this.paidSoFar,
    required this.paymentCount,
    required this.nextDueIso,
    required this.settled,
    required this.source,
    required this.countsInTotal,
  });

  final String id;
  final String name;

  /// What is still owed on this row, never below zero.
  final double remaining;

  /// What the row started at, or zero when the ledger does not record it.
  ///
  /// A `debts` row stores only `remaining` and is rewritten in place on every
  /// payment, so there is no original to recover and this is zero for them.
  /// That is why [hasProgress] exists: a progress bar drawn against an unknown
  /// starting point is a picture of nothing.
  final double original;

  final double paidSoFar;

  /// How many payments have been recorded. Zero for a `debts` row, which keeps
  /// no payment list of its own.
  final int paymentCount;

  /// The next scheduled payment date, ISO, or null when the row has no
  /// schedule. Comes from the golden locked `dueDateFor`, which already moves
  /// a weekend or PH holiday due date to the next banking day.
  final String? nextDueIso;

  final bool settled;
  final DebtSource source;

  /// Whether this row's money is inside the headline total.
  ///
  /// False only for an untracked (no cash leg) payable or receivable. See the
  /// file header: those are listed and explained, never silently dropped.
  final bool countsInTotal;

  /// Whether a progress bar would be telling the truth.
  ///
  /// `paidSoFar > 0`, not `>= 0`, and the difference is a whole grey bar. With
  /// `>=` every untouched debt drew a zero length track under its row: a flat
  /// grey line that reads as a loading state or a broken control rather than
  /// as "nothing paid yet", which the caption already says in words. Found by
  /// rendering the screen, invisible to every test in the file.
  bool get hasProgress => original > 0 && paidSoFar > 0;

  /// How far through this debt the founder is, 0 to 1.
  double get progress => hasProgress ? (paidSoFar / original).clamp(0, 1) : 0;

  /// A row the founder can record a payment against.
  bool get writable => source != DebtSource.payables;
}

/// One direction of the screen: open rows, settled rows, and the total.
class DebtSide {
  const DebtSide({
    required this.open,
    required this.settled,
    required this.total,
    required this.countedRows,
  });

  final List<DebtRow> open;
  final List<DebtRow> settled;

  /// The headline. Equal to the matching half of [debtTotals] by construction,
  /// because it IS that value rather than a second sum over the same rows.
  final double total;

  /// How many open rows are inside [total]. The screen compares this against
  /// `open.length` to decide whether to explain the difference.
  final int countedRows;

  bool get isEmpty => open.isEmpty && settled.isEmpty;

  /// Open rows the headline does not include, which the screen names out loud.
  int get uncountedRows => open.length - countedRows;
}

/// Both directions, derived once.
class DebtBoard {
  const DebtBoard({required this.iOwe, required this.owedToMe});

  final DebtSide iOwe;
  final DebtSide owedToMe;

  DebtSide side(DebtDirection d) => d == DebtDirection.iOwe ? iOwe : owedToMe;

  bool get isEmpty => iOwe.isEmpty && owedToMe.isEmpty;
}

/// What one row says under the name.
///
/// PUBLIC, and here rather than private inside the screen, so the width guard
/// in `row_fits_test.dart` can measure what the screen ACTUALLY composes. It
/// lived in the widget first, and the test then measured a hand-copied list of
/// caption strings: it would have stayed green through any change to the
/// wording, which is a guard that protects the test rather than the founder.
///
/// ONE FACT, and it is the due date wherever there is one.
///
/// The caption carried three at first, "₱1,800 of ₱3,000 paid · due Sep 25",
/// which wrapped onto a second line on a 412dp phone and orphaned the day
/// number: 36 points against an 18 point line.
///
/// Trimming it to "₱1,800 paid · due Sep 25" fits at 18, so the paid figure was
/// NOT dropped for width. It was dropped because the row already carries it
/// twice, once in the bar underneath and once in the amount column, and because
/// the caption has an optional third part: "not in your totals" for an
/// untracked row. "due Sep 25 · not in your totals" fits and the same line with
/// a paid figure in front of it does not. The exact figure is not lost; the
/// detail screen states it in words under its own bar, one tap away.
///
/// Captions DO wrap at 320dp, here and everywhere else: the account row's own
/// "BPI, Savings account" measures 36 points there too. That is the app's
/// existing behaviour rather than a bar this screen fails, and holding Debt to
/// a stricter one would have meant inventing a rule no other list obeys.
String debtRowCaption(DebtRow row, String Function(DateTime) formatDate) {
  if (row.settled) return 'Settled, all paid';

  final parts = <String>[];
  if (row.nextDueIso != null) {
    final d = DateTime.tryParse(row.nextDueIso!);
    parts.add(d == null ? 'due soon' : 'due ${formatDate(d)}');
  } else if (row.paidSoFar > 0) {
    parts.add('${_money(row.paidSoFar)} paid so far');
  } else {
    parts.add('pay when you can');
  }
  // "not counted", not "not in your totals". The longer phrase measured 18
  // points beside "due Sep 25" and 36 beside "due Dec 31", so it fitted or
  // wrapped depending on the MONTH NAME, which is not a property anybody would
  // think to check and would have shipped as an intermittent two line row. The
  // short form has real headroom, and the sentence under the list explains what
  // it means in full.
  if (!row.countsInTotal) parts.add('not counted');
  return parts.join(' · ');
}

/// Read a stored list, skipping anything that is not a record.
List<Map<String, dynamic>> _rows(dynamic v) => [
  for (final r in (v is List ? v : const []))
    if (r is Map) r.cast<String, dynamic>(),
];

String _money(double v) => formatMoney(v);

bool _truthy(dynamic v) =>
    v != null && v != false && v != '' && !(v is num && v == 0);

/// Turn one informal row (a payable or a receivable) into a screen row.
///
/// `remainingOf` and `paidSumOf` are the golden locked pair `trackedRemaining`
/// itself uses per row, so a row's own figure can never drift from the total
/// it lands in.
DebtRow _fromInformal(Map<String, dynamic> r, DebtSource source) {
  final left = remainingOf(r);
  final paid = paidSumOf(r);
  final cashLeg = _truthy(r['cashLeg']);
  return DebtRow(
    id: (r['id'] ?? '').toString(),
    name: (r['name'] ?? 'Someone').toString(),
    remaining: left,
    original: amountOf(r['amount']),
    paidSoFar: paid,
    paymentCount: _rows(r['payments']).length,
    // An informal utang carries a single due date, not a repeating schedule.
    nextDueIso: (r['dueDate'] ?? '').toString().isEmpty
        ? null
        : r['dueDate'].toString(),
    settled: _truthy(r['paid']) || left <= 0,
    source: source,
    countsInTotal: cashLeg,
  );
}

/// Turn one formal debt into a screen row.
DebtRow _fromDebt(Map<String, dynamic> r, DateTime ref) {
  final left = amountOf(r['remaining']);
  return DebtRow(
    id: (r['id'] ?? '').toString(),
    name: (r['name'] ?? 'Debt').toString(),
    remaining: left > 0 ? left : 0,
    // A debts row is rewritten in place on every payment, so what it started
    // at is simply not in the ledger. Claiming an original here would mean
    // inventing one, and a progress bar is not worth a made up number.
    original: 0,
    paidSoFar: 0,
    paymentCount: 0,
    nextDueIso: dueDateFor(r, ref),
    settled: left <= 0,
    source: DebtSource.debts,
    countsInTotal: true,
  );
}

/// Sort the open rows the way somebody reads them: what is due soonest first,
/// then the biggest, then by name so the order never wobbles between builds.
///
/// A row with no date sorts AFTER every dated row rather than before, because
/// "pay when you can" is genuinely less urgent than a date, and putting the
/// undated rows on top would bury the only thing on this screen with a
/// deadline.
int _byUrgency(DebtRow a, DebtRow b) {
  final ad = a.nextDueIso, bd = b.nextDueIso;
  if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
  if (ad != null && bd == null) return -1;
  if (ad == null && bd != null) return 1;
  if (a.remaining != b.remaining) return b.remaining.compareTo(a.remaining);
  return a.name.compareTo(b.name);
}

/// Split one direction's rows into open and settled, and attach its headline.
DebtSide _side(List<DebtRow> all, double total) {
  final open = [
    for (final r in all)
      if (!r.settled) r,
  ]..sort(_byUrgency);
  final settled = [
    for (final r in all)
      if (r.settled) r,
  ]..sort((a, b) => a.name.compareTo(b.name));
  return DebtSide(
    open: open,
    settled: settled,
    total: total,
    countedRows: open.where((r) => r.countsInTotal).length,
  );
}

/// The whole screen, derived from the ledger.
///
/// [ref] is the clock, injected rather than read, so a due date in a test is
/// the same due date on every run.
DebtBoard debtBoardFrom(Map<String, dynamic> data, DateTime ref) {
  // The headline figures come from the function Home already uses. Summing the
  // rows again here would produce a second definition of "what you owe" and
  // the two would eventually disagree, which is the exact defect this codebase
  // has had to fix on two separate screens already.
  final DebtTotals totals = debtTotals(data);

  final iOwe = <DebtRow>[
    // Only the debts that do not get their own section in Accounts. A credit
    // card lives under Credit there, and counting it here as well would show
    // the founder the same card twice with no way to tell that it was one
    // card. This is the same filter `debtTotals` applies to build the total
    // these rows sit under.
    for (final r in _rows(data['debts']))
      if (rollsIntoDebtSummary(resolveKind(r, AccountStore.debts).category.id))
        _fromDebt(r, ref),
    for (final r in _rows(data['payables']))
      _fromInformal(r, DebtSource.payables),
  ];

  final owedToMe = <DebtRow>[
    for (final r in _rows(data['receivables']))
      _fromInformal(r, DebtSource.receivables),
  ];

  return DebtBoard(
    iOwe: _side(iOwe, totals.owed),
    owedToMe: _side(owedToMe, totals.due),
  );
}
