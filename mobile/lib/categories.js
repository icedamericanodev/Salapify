// categories.js: pure helpers for the categories feature, kept out of the store
// and screens so they can be unit tested.

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
