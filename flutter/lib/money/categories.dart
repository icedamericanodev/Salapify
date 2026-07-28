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
