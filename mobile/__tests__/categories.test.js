// Regression suite for lib/categories.js: the pure delete-time recategorize.

import { recategorizeTransactions } from '../lib/categories';

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
