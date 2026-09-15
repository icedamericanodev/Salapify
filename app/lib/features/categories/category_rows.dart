// Categories: what they are, and the one rule about hiding one.
//
// Until now nothing in the app could create, rename or retire a category. Every
// screen READ `data['categories']` and the budget editor set a cap on one, so a
// person was stuck with the eight the app shipped, forever. `_migration4` only
// refills the defaults below schemaVersion 4 and a live ledger sits at 12, so
// an empty list stays empty and nothing anywhere puts them back.
//
// ARCHIVE, NEVER DELETE, and that is a decision rather than a shortcut. A
// recovery pass traced every reader of `categoryId` and found that deleting a
// category with 200 entries pointing at it does not lose a peso (Insights folds
// an unknown id into Uncategorised, and `budgetSummary` sums expenses whatever
// they are tagged), but it does destroy ATTRIBUTION with no way back: the
// Plan rows stop accounting for the month with nothing saying why, and
// re-creating the category mints a NEW id, so the ~150 entry keyword table in
// fastlog.dart, which points only at the eight `cat_*` defaults, never
// auto-tags "jollibee 250" again. Nothing on any screen would explain that.
//
// The accounts precedent settles the shape. An account needed THREE states
// because it holds a balance that must keep counting. A category holds no
// money, it is a label, so it needs ONE flag and reuses the same key.
import '../../core/money/categories.dart' show taggedCount;
import '../../core/money/format.dart' show formatMoney;
import '../../core/money/ledger.dart' show amountOf;

/// Hidden from the pickers, still counted everywhere.
///
/// The same key accounts use, deliberately: one vocabulary for one idea. It
/// survives a backup round trip with no schema change because `sanitizeData`
/// spreads the stored row before coercing known fields, the way `paluwagans`
/// and `quickAddsEdited` already survive, and it appears ONLY when true so no
/// golden fixture gains a key.
bool isArchivedCategory(dynamic row) => row is Map && row['isArchived'] == true;

/// The categories a picker offers: everything not retired.
///
/// THE ONLY PLACE ARCHIVE APPLIES. It must never filter `categoryBudgets` or
/// the Insights breakdown: a category that had 12,400 through it this month
/// keeps its row and its slice, or hiding a label would hide money that is
/// still inside the hero figure above it. Hiding is about what you can PICK
/// next time, never about what already happened.
List<Map<String, dynamic>> pickableCategories(Map<String, dynamic> data) => [
  for (final c in allCategories(data))
    if (!isArchivedCategory(c)) c,
];

/// Every category, retired ones included, in stored order.
List<Map<String, dynamic>> allCategories(Map<String, dynamic> data) => [
  for (final c
      in (data['categories'] is List ? data['categories'] as List : const []))
    if (c is Map) c.cast<String, dynamic>(),
];

/// What hiding this one costs, in the words the confirmation uses.
///
/// Returns an empty string when there is nothing to warn about, because a
/// category with no cap and no spending this month is a tier one change with an
/// un-hide control sitting right next to it, and a dialog over that is noise.
///
/// THE CAP IS THE DANGEROUS PART, and it is why this is not a silent toggle.
/// `budgetRows` emits a row for any category with a cap above zero OR spending
/// above zero, and `needALook` feeds the count in Plan's hero. Hide a category
/// while its cap is still set and Plan keeps drawing a capped row, possibly
/// over, possibly counted in the hero, that no control in the app can reach:
/// four taps from here to a number the user can never change again. So the cap
/// is cleared in the same write, and the sentence says so in pesos.
String hideConsequence(Map<String, dynamic> data, Map<String, dynamic> cat) {
  final cap = amountOf(cat['monthlyCap']);
  final tagged = taggedCount(data['transactions'], cat['id']);
  final name = (cat['name'] ?? 'This').toString();

  final parts = <String>[];
  if (tagged > 0) {
    parts.add(
      '$name stays on your reports and on the '
      '${tagged == 1 ? 'one entry' : '$tagged entries'} already tagged with '
      'it. It only stops appearing when you log something new.',
    );
  } else {
    parts.add(
      '$name stops appearing when you log something new. Nothing else '
      'changes.',
    );
  }
  if (cap > 0) {
    // NAMES THE FIGURE. "Its monthly limit is removed" is true and costs the
    // reader a trip to Plan to find out what they are giving up, which is
    // exactly the trip somebody does not take before tapping a confirm button.
    parts.add(
      'Its ${formatMoney(cap)} monthly limit is removed. Set it again if you '
      'bring the category back.',
    );
  }
  return parts.join('\n\n');
}

/// Whether a category can be removed outright rather than hidden.
///
/// Only when NOTHING points at it, and "nothing" means three things, not one.
/// The first version checked transactions alone and a QA pass found what that
/// missed: a parent category with a 5,000 monthly limit and two children under
/// it, tagged to no entry itself, read as removable. The button said "Remove
/// it" and the caption said "Nothing is tagged with this one yet, so it can go
/// completely". Both were false in the way that matters. One tap took the limit
/// with it and `normalizeCategoryTree` stripped both children's parentId on the
/// next commit, destroying a grouping the user had built, with no undo anywhere.
///
/// A category nobody ever used is a typo being tidied away, and refusing to
/// remove it would leave permanent litter in every picker. Anything with
/// history, a limit, or children beneath it is archived instead.
bool canRemove(Map<String, dynamic> data, Map<String, dynamic> cat) {
  if (taggedCount(data['transactions'], cat['id']) != 0) return false;
  if (amountOf(cat['monthlyCap']) > 0) return false;
  final id = cat['id'];
  for (final c in allCategories(data)) {
    if (c['id'] != id && c['parentId'] == id) return false;
  }
  return true;
}

/// What removing this one costs, in the words the confirmation uses.
///
/// Reached only when [canRemove] is true, so by construction there is no
/// history, no limit and nothing underneath. It still asks, because removal is
/// the one action on this screen with no way back: archive has its un-hide
/// control sitting permanently in the same list, and this has nothing.
String removeConsequence(Map<String, dynamic> cat) =>
    '${cat['name'] ?? 'This category'} is not used by anything, so nothing '
    'else changes. There is no way to bring it back, and a new one with the '
    'same name would not be the same category to the app.';

/// The subtitle under a category in the list.
String categoryCaption(Map<String, dynamic> data, Map<String, dynamic> cat) {
  final tagged = taggedCount(data['transactions'], cat['id']);
  final cap = amountOf(cat['monthlyCap']);
  final bits = <String>[
    if (tagged == 0)
      'Not used yet'
    else if (tagged == 1)
      '1 entry'
    else
      '$tagged entries',
    if (cap > 0) 'limit set',
  ];
  return bits.join(', ');
}
