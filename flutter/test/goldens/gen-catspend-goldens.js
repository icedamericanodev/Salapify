// Golden generator for "what has this category cost this month", executing
// the REAL spentFor predicate out of mobile/app/categories.js.
//
// That predicate is the half the Flutter port dropped, and dropping it made
// monthly caps inert for everything logged with the main + button, because
// that path never writes a categoryId at all. The rule has two arms: an
// entry tagged with this category, OR an untagged entry (or one whose tag
// points at a deleted category) whose LABEL is exactly the category name.
//
// The arrow lives inside a React component, so it is cut out by text and run
// with its collaborators injected. isThisMonth is the real one from
// lib/format.js, because the date half is where a transcription would drift.

const fs = require('fs');

function loadFormat() {
  const src = fs
    .readFileSync('/home/user/Salapify/mobile/lib/format.js', 'utf8')
    .replace(/^export /gm, '');
  const names = [...src.matchAll(/^function (\w+)/gm)].map((m) => m[1]);
  return new Function(`${src}\nreturn { ${names.join(', ')} };`)();
}
const { isThisMonth } = loadFormat();

const screen = fs.readFileSync('/home/user/Salapify/mobile/app/categories.js', 'utf8');
const start = screen.indexOf('  const spentFor = (c) =>');
if (start < 0) throw new Error('spentFor not found');
const end = screen.indexOf(';\n', screen.indexOf('.reduce(', start));
const text = screen.slice(start + '  const spentFor = '.length, end);
if (!text.includes('categoryId') || !text.includes('isThisMonth')) {
  throw new Error('extracted text does not look like spentFor');
}
const spentFor = new Function(
  'data',
  'validIds',
  'isThisMonth',
  `return (${text});`,
);

const REF = new Date(2026, 6, 15); // 15 July 2026, the month under test
const iso = (y, m, d) =>
  `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;

const CATEGORIES = [
  { id: 'food', name: 'Food' },
  { id: 'bills', name: 'Bills' },
  { id: 'transpo', name: 'Transport' },
];

const TRANSACTIONS = [
  // Tagged, this month: counts for Food.
  { id: 't1', type: 'expense', label: 'Jollibee', amount: 250, date: iso(2026, 7, 2), categoryId: 'food' },
  // UNTAGGED but labelled exactly: the arm the port dropped.
  { id: 't2', type: 'expense', label: 'Food', amount: 3500, date: iso(2026, 7, 3) },
  // Wrong case: RN's label match is exact, so this counts for nothing.
  { id: 't3', type: 'expense', label: 'food', amount: 90, date: iso(2026, 7, 4) },
  // Tag pointing at a category that no longer exists, label matches: counts.
  { id: 't4', type: 'expense', label: 'Bills', amount: 1800, date: iso(2026, 7, 5), categoryId: 'ghost' },
  // Tagged AND labelled as another category: the tag wins.
  { id: 't5', type: 'expense', label: 'Food', amount: 400, date: iso(2026, 7, 6), categoryId: 'bills' },
  // Income, never counts as spend.
  { id: 't6', type: 'income', label: 'Food', amount: 9999, date: iso(2026, 7, 7) },
  // Last month, out of the window.
  { id: 't7', type: 'expense', label: 'Food', amount: 500, date: iso(2026, 6, 30) },
  // Next month, also out.
  { id: 't8', type: 'expense', label: 'Food', amount: 600, date: iso(2026, 8, 1) },
  // Junk amount and a missing date, neither may throw.
  { id: 't9', type: 'expense', label: 'Transport', amount: 'abc', date: iso(2026, 7, 8) },
  { id: 't10', type: 'expense', label: 'Transport', amount: 120 },
  // A transfer and a debt row, which are not spending.
  { id: 't11', type: 'transfer', label: 'Food', amount: 1000, date: iso(2026, 7, 9) },
  { id: 't12', type: 'debt', label: 'Bills', amount: 700, date: iso(2026, 7, 9) },
];

const validIds = new Set(CATEGORIES.map((c) => c.id));
const data = { transactions: TRANSACTIONS };
const out = {
  ref: iso(2026, 7, 15),
  categories: CATEGORIES,
  transactions: TRANSACTIONS,
  spent: CATEGORIES.map((c) => ({
    id: c.id,
    // isThisMonth reads the real clock by default, so the reference date is
    // passed explicitly, exactly as the screen would on that day.
    // spentFor is built as a factory returning the shipped arrow, so it is
    // called twice: once to bind the collaborators, once with the category.
    amount: spentFor(data, validIds, (d) => isThisMonth(d, REF))(c),
  })),
};

const dest = '/home/user/Salapify/flutter/test/goldens/categoryspend_goldens.json';
fs.writeFileSync(dest, JSON.stringify(out, null, 2));
console.log('wrote', dest, JSON.stringify(out.spent));
