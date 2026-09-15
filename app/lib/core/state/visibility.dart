// What the user chose to leave out, and what each figure costs because of it.
//
// Founder direction, 2026-09-15, after a financial-coach and a
// security-privacy pass. They proposed two rules, "a hidden account does not
// count" or "a hidden account still counts", and asked specialists to settle
// it. The answer was that those are not two settings for one switch. They are
// two different NUMBERS, and each of the founder's rules is right about one of
// them:
//
//   NET WORTH is what you OWN. A fact. Hiding a row from a list does not
//   change who owns the money, so hidden money STAYS.
//
//   SAFE TO SPEND is what you can TOUCH this fortnight. A decision. Money you
//   deliberately put out of sight should LEAVE it.
//
// The asymmetry decides it: a safe-to-spend figure that is too high makes
// people overspend, and one that is too low only makes them slightly cautious.
//
// THREE STATES, TWO FLAGS, NO SCHEMA CHANGE. The stored flags already exist and
// already mean this, which is the whole reason no field was added:
//
//   isArchived: true        "Hide from my lists". The shipped app's own button
//                           says "Hide account" and writes exactly this, and
//                           its net worth has always kept counting the row. So
//                           this reading is not a reinterpretation of the
//                           founder's real data, it is finally doing what that
//                           button always implied.
//   includeInNetWorth:false "Do not count this as mine". For money you HOLD
//                           and do not OWN: this month's paluwagan pot sitting
//                           in your GCash, a remittance passing through to
//                           your parents, tuition held for a relative.
//                           Counting that as your wealth is a lie with a
//                           deadline.
//   both                    Closed. The account is finished and its balance is
//                           history.
//
// WHY NOT `countsInNetWorth`. That helper exists in the golden-locked engine
// (account_taxonomy.dart) and returns false for EITHER flag. Its name says net
// worth and its only real use is deciding which rows belong in the default
// LIST, which is a different question. It is left alone, and nothing here calls
// it, because editing a locked file is not an option and because the two
// questions genuinely have different answers.
import '../money/base_currency_scope.dart' show baseCurrencyOf, inBaseCurrency;
import '../money/commitments.dart' show liquidKinds;
import '../money/ledger.dart' show amountOf;

/// Hidden from the lists, but still the user's money.
bool isHiddenFromLists(dynamic row) => row is Map && row['isArchived'] == true;

/// Money the user holds but does not own.
bool isNotMine(dynamic row) => row is Map && row['includeInNetWorth'] == false;

/// Whether this row's money belongs in net worth.
///
/// Absent flags mean yes, so every row that predates this feature counts
/// exactly as it always did.
bool countsAsOwned(dynamic row) => !isNotMine(row);

/// Whether this row's money is spendable this fortnight.
///
/// Both flags take it out, and that is the asymmetry above: you cannot spend
/// what is not yours, and you have said you do not want to see what you hid.
bool countsAsSpendable(dynamic row) =>
    !isNotMine(row) && !isHiddenFromLists(row);

List<Map<String, dynamic>> _rows(dynamic v) => [
  for (final r in (v is List ? v : const []))
    if (r is Map) r.cast<String, dynamic>(),
];

/// The ledger with some rows taken out, FOR READING ONLY.
///
/// This is how a visibility rule reaches a money figure without any screen
/// doing arithmetic. Instead of computing a total and subtracting from it, the
/// unwanted rows are removed and the GOLDEN LOCKED engine is asked the same
/// question it always answers. Every sum, sign, rounding rule and
/// currency check stays exactly where it already lives, and there is no second
/// opinion about money anywhere in this file.
///
/// SHALLOW ON PURPOSE. The surviving rows are the same objects, not copies, so
/// this is cheap and safe to call on every build. It also means the result must
/// NEVER be written back through `ledger.mutate`: saving it would save a ledger
/// with the filtered rows deleted, which is how a view preference turns into
/// data loss.
Map<String, dynamic> _keeping(
  Map<String, dynamic> data,
  bool Function(dynamic row) keep,
  List<String> collections,
) {
  final out = Map<String, dynamic>.of(data);
  for (final c in collections) {
    final v = data[c];
    if (v is! List) continue;
    out[c] = [
      for (final r in v)
        if (keep(r)) r,
    ];
  }
  return out;
}

/// The ledger as the OWNERSHIP question sees it: what is not theirs is gone.
///
/// Feed this to `netWorthParts` and the answer is net worth with the paluwagan
/// pot left out, computed entirely by the engine. Hidden rows SURVIVE, because
/// hiding a row from a list does not change who owns the money.
Map<String, dynamic> ownedOnly(Map<String, dynamic> data) =>
    _keeping(data, countsAsOwned, const ['accounts', 'assets', 'debts']);

/// The ledger as SAFE TO SPEND sees it.
///
/// ONLY `accounts`, and that is the important half. `safeToSpend` reads
/// accounts for the liquid figure and reads `debts` and `recurring` for what is
/// COMMITTED, and a bill you hid from a list is still due on the same day.
/// Filtering the debts here would quietly forgive them, which would push safe
/// to spend UP, and a safe-to-spend figure that is too high is the one failure
/// mode this whole feature was designed around.
Map<String, dynamic> spendableOnly(Map<String, dynamic> data) =>
    _keeping(data, countsAsSpendable, const ['accounts']);

/// What is being left out of each figure, so a screen can SAY so.
///
/// Surfacing is the point, not filtering. Money that silently vanishes from a
/// total is indistinguishable from money the app lost, and on an offline app
/// with no support channel there is nobody to ask. Every screen that subtracts
/// one of these figures also renders the matching sentence.
class Excluded {
  const Excluded({
    required this.fromNetWorth,
    required this.notMineCount,
    required this.fromSpendable,
    required this.spendableCount,
    required this.hiddenCount,
  });

  /// Money that is on the books but is not the user's, so it is out of net
  /// worth. Positive means net worth is LOWER than the raw sum by this much.
  final double fromNetWorth;
  final int notMineCount;

  /// Liquid money that is hidden or not theirs, so it is out of safe to spend.
  final double fromSpendable;

  /// How many accounts [fromSpendable] came out of.
  ///
  /// Not the same as [hiddenCount]. A hidden SAVINGS account is hidden and was
  /// never in safe to spend, so it counts in one and not the other, and a
  /// sentence on Home that used the wrong one would name accounts that had
  /// nothing to do with the figure it was explaining.
  final int spendableCount;

  /// How many accounts are hidden from the lists, whether or not they count.
  final int hiddenCount;

  bool get anyNotMine => notMineCount > 0;
  bool get anyHidden => hiddenCount > 0;

  /// Whether safe to spend is lower than the raw liquid total, so a screen
  /// showing that figure knows it owes the user a sentence.
  bool get anySpendable => spendableCount > 0;

  /// Read the ledger once and answer both questions.
  ///
  /// FOREIGN ROWS ARE SKIPPED, exactly as `netWorthParts` skips them. It
  /// refuses to add a dollar balance into a peso total, so a subtraction here
  /// that did not make the same choice would take away money the total never
  /// added, and net worth would fall for a reason nobody could find.
  factory Excluded.of(Map<String, dynamic> data) {
    final base = baseCurrencyOf(data);

    var notMine = 0.0;
    var notMineCount = 0;
    var spendable = 0.0;
    var spendableCount = 0;
    var hiddenCount = 0;

    void scan(dynamic list, String amountKey, {required bool liability}) {
      for (final r in _rows(list)) {
        if (!inBaseCurrency(r, base)) continue;
        final amount = amountOf(r[amountKey]);

        if (isNotMine(r)) {
          // A liability that is not the user's LOWERS what is owed, so
          // removing it RAISES net worth. Signed rather than summed blindly,
          // or excluding somebody else's debt would look like a loss.
          notMine += liability ? -amount : amount;
          notMineCount++;
        }
        if (isHiddenFromLists(r)) hiddenCount++;
      }
    }

    scan(data['accounts'], 'balance', liability: false);
    scan(data['assets'], 'value', liability: false);
    scan(data['debts'], 'remaining', liability: true);

    // Safe to spend only ever looks at LIQUID accounts, so only those can be
    // taken out of it. Subtracting a hidden investment would lower a figure it
    // was never part of.
    for (final a in _rows(data['accounts'])) {
      if (!inBaseCurrency(a, base)) continue;
      if (!liquidKinds.contains(a['kind'])) continue;
      if (countsAsSpendable(a)) continue;
      spendable += amountOf(a['balance']);
      spendableCount++;
    }

    return Excluded(
      fromNetWorth: notMine,
      notMineCount: notMineCount,
      fromSpendable: spendable,
      spendableCount: spendableCount,
      hiddenCount: hiddenCount,
    );
  }
}
