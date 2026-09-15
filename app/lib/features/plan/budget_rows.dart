// What each category has left this month.
//
// The engine ships ONE budget figure, a single monthly limit for everything
// (`budgetSummary`), and that figure is what the hero on this screen shows,
// unchanged and golden locked. What it does not ship is the per category
// view 04-screens.md asks for: a row per category with what is left in it.
//
// So this derives that, and it is deliberately the smallest derivation that
// can answer the question. It INVENTS no money. The cap is `monthlyCap`, a
// field the schema has carried for twelve versions and the user sets. The
// spend is this month's expenses tagged to that category, and which months
// count is `isThisMonth` from the golden locked `statements.dart` rather than
// a second date rule written here, because two month rules that disagree is
// exactly the class of defect nothing would catch.
//
// It lives in the feature rather than in core/money for one reason: core/money
// is byte identical to the shipped app's engine, file for file, and this has
// no counterpart there to be identical to. `debtTotals` on the Accounts screen
// sits in the feature layer for the same reason.
//
// FREE, and a core feature. Decision D19, founder's call on 2026-09-14, made
// once v3 became a public app rather than the founder's own.
//
// The shipped app treats a per category cap as paid: `whereItWent` reads
// `monthlyCap` only when `settings.pro` is set. That rule is untouched in the
// engine, because that file is byte identical to the shipped app's; this screen
// simply does not consult it. The reasoning is that Salapify's standing promise
// is core features free forever, and a budget app whose budgets sit behind a
// wall fails that promise at the first screen a stranger opens. Pro earns its
// money on history, forecasting, multi currency and export instead.
//
// Do not "restore parity" with the engine's Pro check here later. Moving a
// feature behind a wall after people have it is the one thing the monetization
// promises rule out.
import '../../core/money/ledger.dart' show amountOf;
import '../../core/money/statements.dart' show isThisMonth;

/// One category's month: what it may spend, and what it has.
class BudgetRow {
  const BudgetRow({
    required this.id,
    required this.name,
    required this.icon,
    required this.cap,
    required this.spent,
    this.parentId,
    this.fromChildren = 0,
  });

  final String id;
  final String name;

  /// The category this one sits under, or null at top level.
  ///
  /// Carried so a screen can INDENT rather than re-derive the tree, and so the
  /// one rule that keeps the figures honest is checkable in one place: a total
  /// across rows must sum the TOP LEVEL only, because a parent's [spent]
  /// already contains its children's.
  final String? parentId;

  /// How much of [spent] came from children rather than from entries tagged
  /// directly to this category.
  ///
  /// The screen needs it to say so out loud. A parent reading 3,200 beside a
  /// child reading 3,200 is the same peso drawn twice, and a reader with no
  /// sentence explaining that will reasonably conclude the app is counting it
  /// twice. It is zero for every leaf and for every parent whose children have
  /// no spending.
  final double fromChildren;

  /// Whether any of [spent] came from underneath.
  bool get rollsUp => fromChildren > 0;

  /// The user's emoji, left exactly as they chose it. Category icons are user
  /// data and live in the backup file, so the theme never reaches them. Only
  /// icons SALAPIFY authors are Material glyphs in the accent.
  final String icon;

  /// The monthly limit, or zero when this category has none.
  final double cap;
  final double spent;

  /// Whether a limit was ever set. A category with no cap still earns a row
  /// once money goes through it, but it gets no bar and no "left" figure,
  /// because there is nothing to be left OF.
  bool get capped => cap > 0;

  double get remaining => cap - spent;
  bool get over => capped && spent > cap;

  /// How full the bar is. Clamped, so an over budget row shows a full bar and
  /// says how far over in words rather than drawing past its own track.
  double get fraction => capped ? (spent / cap).clamp(0.0, 1.0) : 0.0;

  /// Down to a quarter of the limit, or past it. The screen colours these and
  /// the hero counts them, so the definition lives in ONE place.
  bool get needsALook => capped && remaining <= cap * 0.25;
}

/// Every category worth a row this month, the ones needing attention first.
///
/// A category earns a row if it has a limit OR money went through it. A
/// limit with no spending still shows, because "₱3,000 left of ₱3,000" is the
/// answer to "can I afford this" and hiding it until the first peso is spent
/// would make the screen emptiest exactly when it is most useful.
List<BudgetRow> categoryBudgets(Map<String, dynamic> data, DateTime ref) {
  final spent = <String, double>{};
  for (final t
      in (data['transactions'] is List
          ? data['transactions'] as List
          : const [])) {
    if (t is! Map) continue;
    if (t['type'] != 'expense') continue;
    if (!isThisMonth(t['date'], ref)) continue;
    final id = t['categoryId'];
    if (id is! String || id.isEmpty) continue;
    spent[id] = (spent[id] ?? 0) + amountOf(t['amount']);
  }

  // A PARENT COUNTS EVERYTHING UNDER IT. Founder decision, 2026-09-15, on the
  // only question sub-categories really pose: cap Utilities at 5,000, log 3,200
  // to Electricity underneath it, and Utilities has to say 3,200 of 5,000. The
  // alternative, which is what this function did before, is a limit that sits
  // there reading 0 while the money it was meant to govern goes past it.
  //
  // ONE LEVEL of children, and that is not an assumption, it is enforced.
  // `normalizeCategoryTree` in core/data/backup.dart runs on every load and
  // every restore and flattens self-parents, orphans, cycles and any third
  // level to top level by removing parentId. So a child cannot itself have
  // children, and a recursive walk here would be code defending against a
  // state the store cannot hold.
  final childrenOf = <String, List<Map<String, dynamic>>>{};
  final cats = [
    for (final c
        in (data['categories'] is List ? data['categories'] as List : const []))
      if (c is Map && c['id'] is String && (c['id'] as String).isNotEmpty)
        c.cast<String, dynamic>(),
  ];
  final ids = {for (final c in cats) c['id']};

  // ONE definition of "has a real parent", used by both the rollup and the row,
  // because the first version had two and they disagreed. A category naming
  // ITSELF as its parent was skipped by the rollup, correctly, and still
  // reported `parentId` on its row, so anything summing the top level only, the
  // rule that stops double counting, would have dropped that category's money
  // out of the total entirely. A test caught it; two copies of a rule is how it
  // got written.
  String? realParent(Map<String, dynamic> c) {
    final p = c['parentId'];
    if (p is! String || p.isEmpty) return null;
    if (p == c['id']) return null;
    if (!ids.contains(p)) return null;
    return p;
  }

  for (final c in cats) {
    // A parentId pointing at nothing, or at itself, is treated as no parent,
    // matching what normalizeCategoryTree does to it on the next load.
    final p = realParent(c);
    if (p == null) continue;
    (childrenOf[p] ??= []).add(c);
  }

  final rows = <BudgetRow>[];
  for (final c in cats) {
    final id = c['id'] as String;
    final cap = amountOf(c['monthlyCap']);
    final own = spent[id] ?? 0.0;
    final below = (childrenOf[id] ?? const []).fold(
      0.0,
      (t, k) => t + (spent[k['id']] ?? 0.0),
    );
    final used = own + below;
    if (cap <= 0 && used <= 0) continue;
    rows.add(
      BudgetRow(
        id: id,
        name: (c['name'] ?? '').toString(),
        icon: (c['icon'] ?? '').toString(),
        cap: cap,
        spent: used,
        parentId: realParent(c),
        fromChildren: below,
      ),
    );
  }

  // Ordered by what needs deciding, not alphabetically. A budget screen is
  // read when somebody is about to spend, so the category closest to its
  // limit belongs at the top. Capped rows sort by how full they are; rows
  // with no limit follow, largest spend first, because they are information
  // rather than a decision.
  int byUrgency(BudgetRow a, BudgetRow b) {
    if (a.capped != b.capped) return a.capped ? -1 : 1;
    if (a.capped) {
      final byFullness = b.fraction.compareTo(a.fraction);
      if (byFullness != 0) return byFullness;
      // Two rows equally full: the one further over is the sharper problem,
      // and a clamped fraction cannot tell them apart.
      final byOverspend = (b.spent - b.cap).compareTo(a.spent - a.cap);
      if (byOverspend != 0) return byOverspend;
    }
    return b.spent.compareTo(a.spent);
  }

  // A CHILD FOLLOWS ITS PARENT, and urgency orders within each level rather
  // than across the whole list. Sorting everything by urgency alone scatters a
  // child far from the parent whose figure already contains it, and the screen
  // then indents a row with nothing above it to be indented UNDER. The reader
  // is left with two figures that overlap and no way to see that they do.
  final top = [
    for (final r in rows)
      if (r.parentId == null) r,
  ]..sort(byUrgency);
  final kids = <String, List<BudgetRow>>{};
  for (final r in rows) {
    if (r.parentId != null) (kids[r.parentId!] ??= []).add(r);
  }
  for (final list in kids.values) {
    list.sort(byUrgency);
  }

  return [
    for (final parent in top) ...[parent, ...?kids[parent.id]],
    // A child whose parent earned no row of its own still has to appear, or
    // its money is on no screen at all. It cannot happen today, because a
    // parent with a spending child always clears the row test, and it is one
    // line to make that a fact rather than a belief.
    for (final entry in kids.entries)
      if (!top.any((p) => p.id == entry.key)) ...entry.value,
  ];
}

/// How many rows need a look. What the hero sentence counts.
int needALook(List<BudgetRow> rows) => rows.where((r) => r.needsALook).length;
