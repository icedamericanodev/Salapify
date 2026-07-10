// Regression suite for lib/categories.js: the pure delete-time recategorize.

import { recategorizeTransactions, normalizeCategoryTree, promoteChildren, categoryTree } from '../lib/categories';

const base = [
  { id: 't1', type: 'expense', amount: 100, categoryId: 'cat_food' },
  { id: 't2', type: 'expense', amount: 50, categoryId: 'cat_transport' },
  { id: 't3', type: 'expense', amount: 30, categoryId: 'cat_food' },
  { id: 't4', type: 'income', amount: 20000 }, // no category
];

describe('recategorizeTransactions moves or clears only the matching tag', () => {
  test('reassign moves only the matching entries to the new category', () => {
    const out = recategorizeTransactions(base, 'cat_food', 'cat_groceries');
    expect(out.find((t) => t.id === 't1').categoryId).toBe('cat_groceries');
    expect(out.find((t) => t.id === 't3').categoryId).toBe('cat_groceries');
    // Untouched: a different category and an untagged entry.
    expect(out.find((t) => t.id === 't2').categoryId).toBe('cat_transport');
    expect(out.find((t) => t.id === 't4').categoryId).toBeUndefined();
  });

  test('uncategorize (toId null) removes the tag entirely, not sets it to empty', () => {
    const out = recategorizeTransactions(base, 'cat_food', null);
    const t1 = out.find((t) => t.id === 't1');
    expect('categoryId' in t1).toBe(false);
    // Others unchanged.
    expect(out.find((t) => t.id === 't2').categoryId).toBe('cat_transport');
  });

  test('amounts and every other field are left exactly as they were', () => {
    const out = recategorizeTransactions(base, 'cat_food', 'cat_groceries');
    const t1 = out.find((t) => t.id === 't1');
    expect(t1.amount).toBe(100);
    expect(t1.type).toBe('expense');
  });

  test('a missing fromId or non-array input is safe', () => {
    expect(recategorizeTransactions(base, '', 'cat_x')).toBe(base);
    expect(recategorizeTransactions(null, 'cat_food', 'cat_x')).toEqual([]);
  });
});

describe('normalizeCategoryTree keeps the tree at most two levels and valid', () => {
  const pid = (out, id) => out.find((c) => c.id === id).parentId;
  test('a valid child keeps its parent; a top level category has no parentId', () => {
    const out = normalizeCategoryTree([
      { id: 'food', name: 'Food' },
      { id: 'coffee', name: 'Coffee', parentId: 'food' },
    ]);
    expect(pid(out, 'coffee')).toBe('food');
    expect('parentId' in out.find((c) => c.id === 'food')).toBe(false);
  });
  test('self-parent, orphan parent, and empty parentId all drop to top level', () => {
    const out = normalizeCategoryTree([
      { id: 'a', name: 'A', parentId: 'a' }, // self
      { id: 'b', name: 'B', parentId: 'ghost' }, // orphan
      { id: 'c', name: 'C', parentId: '' }, // empty
    ]);
    expect('parentId' in out.find((c) => c.id === 'a')).toBe(false);
    expect('parentId' in out.find((c) => c.id === 'b')).toBe(false);
    expect('parentId' in out.find((c) => c.id === 'c')).toBe(false);
  });
  test('a third level is flattened to top level (parent is itself a child)', () => {
    const out = normalizeCategoryTree([
      { id: 'food', name: 'Food' },
      { id: 'coffee', name: 'Coffee', parentId: 'food' },
      { id: 'latte', name: 'Latte', parentId: 'coffee' }, // would be level 3
    ]);
    expect(pid(out, 'coffee')).toBe('food');
    expect('parentId' in out.find((c) => c.id === 'latte')).toBe(false);
  });
  test('a cycle is broken (all flattened), never an infinite loop', () => {
    const out = normalizeCategoryTree([
      { id: 'a', name: 'A', parentId: 'b' },
      { id: 'b', name: 'B', parentId: 'a' },
    ]);
    expect('parentId' in out.find((c) => c.id === 'a')).toBe(false);
    expect('parentId' in out.find((c) => c.id === 'b')).toBe(false);
  });
});

describe('promoteChildren lifts a deleted parent\'s children to top level', () => {
  test('only the deleted parent\'s children lose their parentId', () => {
    const out = promoteChildren(
      [
        { id: 'food', name: 'Food' },
        { id: 'coffee', name: 'Coffee', parentId: 'food' },
        { id: 'grab', name: 'Grab', parentId: 'transport' },
      ],
      'food'
    );
    expect('parentId' in out.find((c) => c.id === 'coffee')).toBe(false);
    expect(out.find((c) => c.id === 'grab').parentId).toBe('transport');
  });
});

describe('categoryTree orders parents then their children with depth', () => {
  test('each parent is immediately followed by its children', () => {
    const tree = categoryTree([
      { id: 'food', name: 'Food' },
      { id: 'transport', name: 'Transport' },
      { id: 'coffee', name: 'Coffee', parentId: 'food' },
    ]);
    expect(tree.map((x) => x.cat.id)).toEqual(['food', 'coffee', 'transport']);
    expect(tree.map((x) => x.depth)).toEqual([0, 1, 0]);
  });

  test('a third level row in a non normalized list still renders, never vanishes', () => {
    // latte -> coffee -> food. childrenOf only expands one level, so without the
    // defensive tail latte would silently disappear from the list.
    const tree = categoryTree([
      { id: 'food', name: 'Food' },
      { id: 'coffee', name: 'Coffee', parentId: 'food' },
      { id: 'latte', name: 'Latte', parentId: 'coffee' },
    ]);
    expect(tree.map((x) => x.cat.id).sort()).toEqual(['coffee', 'food', 'latte']);
  });
});
