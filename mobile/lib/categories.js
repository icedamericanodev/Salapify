// categories.js: pure helpers for the categories feature, kept out of the store
// and screens so they can be unit tested.

// Clean the parentId field across the whole category list so the tree is always
// AT MOST two levels, with no self-parent, no dangling parent, and no cycle.
// Returns a NEW list. A category's parentId is kept only when it points at a real
// OTHER category that is itself top level; anything else (missing, self, orphan,
// a parent that is itself a child, a cycle) drops the parentId so the category
// becomes top level. This is the one choke point every load and restore runs
// through, so a hand edited or corrupt backup can never brick the nested view.
export function normalizeCategoryTree(categories) {
  const list = Array.isArray(categories) ? categories : [];
  const byId = new Map(list.filter((c) => c && c.id).map((c) => [c.id, c]));
  const strip = (c) => {
    const { parentId, ...rest } = c;
    return rest;
  };
  return list.map((c) => {
    if (!c) return c;
    const p = typeof c.parentId === 'string' && c.parentId ? c.parentId : null;
    if (!p || p === c.id) return strip(c); // no parent, empty, or self
    const parent = byId.get(p);
    if (!parent) return strip(c); // dangling parent: promote to top level
    // The parent must itself be top level (enforces the 2 level cap and breaks
    // any cycle): if the parent points at a real other category, this one would
    // be a third level, so flatten it to top level.
    const parentHasRealParent =
      typeof parent.parentId === 'string' &&
      parent.parentId &&
      parent.parentId !== parent.id &&
      byId.has(parent.parentId);
    if (parentHasRealParent) return strip(c);
    return { ...c, parentId: p };
  });
}

// When a parent category is deleted, its children lose their parent, so promote
// them to top level (clear parentId) rather than leave a dangling reference.
// Returns a NEW list.
export function promoteChildren(categories, parentId) {
  if (!Array.isArray(categories) || !parentId) return categories || [];
  return categories.map((c) => {
    if (c && c.parentId === parentId) {
      const { parentId: _p, ...rest } = c;
      return rest;
    }
    return c;
  });
}

// Order a flat category list into display order: each top level category
// immediately followed by its children, so a screen can render the tree by
// walking one array. Each entry is tagged with depth (0 or 1). Orphans and any
// category whose parent is missing render at top level (defensive; the tree is
// already normalized on load, this just keeps rendering safe).
export function categoryTree(categories) {
  const list = Array.isArray(categories) ? categories.filter(Boolean) : [];
  const ids = new Set(list.map((c) => c.id));
  const tops = list.filter((c) => !(typeof c.parentId === 'string' && c.parentId && ids.has(c.parentId) && c.parentId !== c.id));
  const childrenOf = (pid) => list.filter((c) => c.parentId === pid && c.id !== pid);
  const out = [];
  for (const t of tops) {
    out.push({ cat: t, depth: 0 });
    for (const child of childrenOf(t.id)) out.push({ cat: child, depth: 1 });
  }
  return out;
}

// Move every transaction tagged with fromId to toId, or (toId null/empty) clear
// the tag so the entry becomes uncategorized. Returns a NEW array; untagged
// entries and entries tagged with other categories are returned unchanged. This
// is not a money move, so amounts and everything else are left exactly as they
// are. Used when a category is deleted so its history goes where the user chose
// instead of silently orphaning.
export function recategorizeTransactions(transactions, fromId, toId) {
  if (!Array.isArray(transactions) || !fromId) return transactions || [];
  return transactions.map((t) => {
    if (!t || t.categoryId !== fromId) return t;
    if (toId) return { ...t, categoryId: toId };
    const { categoryId, ...rest } = t;
    return rest;
  });
}
