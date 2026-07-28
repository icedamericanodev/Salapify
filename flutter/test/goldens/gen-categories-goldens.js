// Golden generator for the category helpers, executing the REAL
// mobile/lib/categories.js rather than a reading of it.
//
// The file imports nothing, so stripping the `export` keyword leaves plain
// runnable JS: the function bodies below are the shipped characters. (The
// usual babel route is unavailable here, mobile/ has no node_modules in this
// sandbox and no network to install one.)
//
// What is being locked is not arithmetic, it is the SHAPE of data after a
// category is deleted: which entries keep their tag, which lose it, which
// children get promoted, and what order the tree renders in. Getting that
// wrong loses the connection between an entry and its category silently,
// which is exactly the kind of thing a user only notices months later.

const fs = require('fs');
const path = require('path');

const MOBILE = '/home/user/Salapify/mobile';

function loadModule(rel) {
  const src = fs
    .readFileSync(path.join(MOBILE, rel), 'utf8')
    .replace(/^export /gm, '');
  const names = [...src.matchAll(/^function (\w+)/gm)].map((m) => m[1]);
  return new Function(`${src}\nreturn { ${names.join(', ')} };`)();
}

const { normalizeCategoryTree, promoteChildren, categoryTree, recategorizeTransactions } =
  loadModule('lib/categories.js');

// The category shapes that actually turn up: a clean two level tree, a
// self-parent, a dangling parent, a three level chain (which the two level
// cap must flatten), a cycle, and junk.
const TREES = {
  flat: [
    { id: 'food', name: 'Food', icon: '🍚' },
    { id: 'bills', name: 'Bills', icon: '💡' },
  ],
  nested: [
    { id: 'food', name: 'Food', icon: '🍚' },
    { id: 'groceries', name: 'Groceries', icon: '🛒', parentId: 'food' },
    { id: 'eatout', name: 'Eating out', icon: '🍽️', parentId: 'food' },
    { id: 'bills', name: 'Bills', icon: '💡' },
  ],
  threeDeep: [
    { id: 'a', name: 'A' },
    { id: 'b', name: 'B', parentId: 'a' },
    { id: 'c', name: 'C', parentId: 'b' },
  ],
  selfParent: [{ id: 'x', name: 'X', parentId: 'x' }],
  dangling: [{ id: 'y', name: 'Y', parentId: 'ghost' }],
  cycle: [
    { id: 'p', name: 'P', parentId: 'q' },
    { id: 'q', name: 'Q', parentId: 'p' },
  ],
  withCaps: [
    { id: 'food', name: 'Food', icon: '🍚', monthlyCap: 3000 },
    { id: 'bills', name: 'Bills', icon: '💡', monthlyCap: 0 },
  ],
  junk: [null, { name: 'no id' }, { id: 'ok', name: 'Ok' }],
};

const TXNS = [
  { id: 't1', type: 'expense', amount: 250, categoryId: 'food' },
  { id: 't2', type: 'expense', amount: 100, categoryId: 'groceries' },
  { id: 't3', type: 'expense', amount: 80 },
  { id: 't4', type: 'income', amount: 15000, categoryId: 'bills' },
  { id: 't5', type: 'expense', amount: 60, categoryId: 'food' },
];

const out = { normalize: [], promote: [], tree: [], recategorize: [] };

for (const [name, list] of Object.entries(TREES)) {
  out.normalize.push({ in: { name, list }, out: normalizeCategoryTree(list) });
  out.tree.push({
    in: { name, list },
    // depth plus the id, which is what a renderer actually consumes.
    out: categoryTree(list).map((r) => ({ id: r.cat && r.cat.id, depth: r.depth })),
  });
  for (const pid of ['food', 'a', 'ghost', '', null]) {
    out.promote.push({
      in: { name, parentId: pid },
      out: promoteChildren(list, pid),
    });
  }
}

// The move-or-orphan decision, which is the founder's call: entries move to a
// chosen category, and only an explicit null clears the tag.
for (const fromId of ['food', 'groceries', 'bills', 'missing', '', null]) {
  for (const toId of ['bills', 'food', null, '', undefined]) {
    out.recategorize.push({
      in: { fromId, toId: toId === undefined ? '__undefined__' : toId },
      out: recategorizeTransactions(TXNS, fromId, toId),
    });
  }
}
out.transactions = TXNS;

const dest = '/home/user/Salapify/flutter/test/goldens/categories_goldens.json';
fs.writeFileSync(dest, JSON.stringify(out, null, 2));
console.log(
  'wrote', dest,
  'normalize:', out.normalize.length,
  'promote:', out.promote.length,
  'tree:', out.tree.length,
  'recategorize:', out.recategorize.length,
);
