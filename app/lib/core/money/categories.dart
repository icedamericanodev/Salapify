// Pure category helpers, ported from mobile/lib/categories.js and golden
// locked against that exact source. What is locked here is not arithmetic, it
// is the SHAPE of the data after a category is deleted: which entries keep
// their tag, which lose it, which children get promoted, and what order the
// tree renders in. Getting that wrong loses the link between an entry and its
// category silently, which a person only notices months later.
//
// normalizeCategoryTree already lives in data/backup.dart, because every load
// and restore has to run through it. These three are the rest of the family.

/// When a parent category is deleted its children lose their parent, so they
/// are promoted to top level rather than left pointing at something gone.
List<Map<String, dynamic>> promoteChildren(
  dynamic categories,
  dynamic parentId,
) {
  if (categories is! List) return const [];
  final pid = parentId is String && parentId.isNotEmpty ? parentId : null;
  final list = categories.whereType<Map>().map(
    (c) => c.cast<String, dynamic>(),
  );
  if (pid == null) return list.toList();
  return [
    for (final c in list)
      if (c['parentId'] == pid) ({...c}..remove('parentId')) else c,
  ];
}

/// One row of the display tree: the category and how deep it sits (0 or 1).
class CategoryRow {
  final Map<String, dynamic> cat;
  final int depth;
  const CategoryRow(this.cat, this.depth);
}

/// A flat list ordered for display: every top level category immediately
/// followed by its children, so a screen renders the tree by walking one list.
///
/// Anything the walk does not reach still comes out at top level. That is
/// deliberate defensive code in the RN original and it is kept: a category
/// that silently vanishes from this screen is a category the user cannot
/// delete, rename, or find, and they have no way to even know it is there.
List<CategoryRow> categoryTree(dynamic categories) {
  final list = categories is List
      ? categories
            .whereType<Map>()
            .map((c) => c.cast<String, dynamic>())
            .toList()
      : <Map<String, dynamic>>[];
  final ids = {for (final c in list) c['id']};
  bool hasRealParent(Map<String, dynamic> c) {
    final p = c['parentId'];
    return p is String && p.isNotEmpty && ids.contains(p) && p != c['id'];
  }

  final out = <CategoryRow>[];
  final rendered = <dynamic>{};
  for (final t in list.where((c) => !hasRealParent(c))) {
    out.add(CategoryRow(t, 0));
    rendered.add(t['id']);
    for (final child in list) {
      if (child['parentId'] == t['id'] && child['id'] != t['id']) {
        out.add(CategoryRow(child, 1));
        rendered.add(child['id']);
      }
    }
  }
  for (final c in list) {
    if (!rendered.contains(c['id'])) out.add(CategoryRow(c, 0));
  }
  return out;
}

/// Move every entry tagged [fromId] to [toId], or clear the tag entirely when
/// [toId] is null or empty.
///
/// This is NOT a money move: amounts, dates, accounts and everything else come
/// through untouched. The founder's rule is the whole point of this function
/// existing rather than a delete simply orphaning rows: when a category goes,
/// its history goes where the person chose.
List<Map<String, dynamic>> recategorizeTransactions(
  dynamic transactions,
  dynamic fromId,
  dynamic toId,
) {
  if (transactions is! List) return const [];
  final from = fromId is String && fromId.isNotEmpty ? fromId : null;
  final list = transactions.whereType<Map>().map(
    (t) => t.cast<String, dynamic>(),
  );
  if (from == null) return list.toList();
  final to = toId is String && toId.isNotEmpty ? toId : null;
  return [
    for (final t in list)
      if (t['categoryId'] != from)
        t
      else if (to != null)
        {...t, 'categoryId': to}
      else
        ({...t}..remove('categoryId')),
  ];
}

/// What each category has cost this month, keyed by category id.
///
/// The rule is RN's, both arms of it, and the second arm is the one this port
/// originally dropped: an entry counts for a category when it carries that
/// category's TAG, or when it has no usable tag and its LABEL is exactly the
/// category name. That matters because the main Log button never writes a
/// tag at all, so without the label arm a monthly cap was inert for the app's
/// primary way of recording money. The Categories screen said 0 while Budget
/// said 3,500 for the same category, in the same month.
///
/// The label match is case sensitive, matching the live app. Only expenses
/// count: income tagged with a category is not spending, and transfers and
/// debt rows are not either.
Map<String, double> spentByCategory(
  dynamic transactions,
  dynamic categories,
  DateTime ref,
) {
  final cats = categories is List
      ? categories
            .whereType<Map>()
            .map((c) => c.cast<String, dynamic>())
            .toList()
      : <Map<String, dynamic>>[];
  final validIds = {for (final c in cats) c['id']};
  final prefix =
      '${ref.year.toString().padLeft(4, '0')}-'
      '${ref.month.toString().padLeft(2, '0')}';
  final out = <String, double>{for (final c in cats) '${c['id']}': 0};
  if (transactions is! List) return out;
  for (final t in transactions) {
    if (t is! Map) continue;
    if (t['type'] != 'expense') continue;
    final date = t['date'];
    if (date is! String || !date.startsWith(prefix)) continue;
    final tag = t['categoryId'];
    final tagged = tag != null && validIds.contains(tag);
    for (final c in cats) {
      final id = '${c['id']}';
      final hit = tagged ? tag == c['id'] : t['label'] == c['name'];
      if (hit) {
        out[id] = (out[id] ?? 0) + _amount(t['amount']);
        break;
      }
    }
  }
  return out;
}

double _amount(dynamic v) {
  if (v is num) return v.isFinite ? v.toDouble() : 0;
  final parsed = double.tryParse('$v');
  return (parsed == null || !parsed.isFinite) ? 0 : parsed;
}

/// How many entries carry this category's tag. The number the delete sheet
/// shows, so nobody is ever asked to confirm a move of an unknown size.
int taggedCount(dynamic transactions, dynamic categoryId) {
  if (transactions is! List || categoryId == null) return 0;
  var n = 0;
  for (final t in transactions) {
    if (t is Map && t['categoryId'] == categoryId) n++;
  }
  return n;
}
