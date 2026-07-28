// Golden generator for the Statement of Account and the one line reminder.
//
// The rule is to EXECUTE the shipped RN code, never to re-implement it from
// understanding, because understanding is exactly what misses a coercion or a
// rounding edge. mobile/lib/statement.js is a clean module whose only import
// is formatMoney, so both are loaded the same way the other generators here
// load format.js: read the real source, drop the `export` keywords, run it.
// The characters executed below are the shipped characters.
//
// Every fixture passes an explicit asOf date. buildPersonStatement falls back
// to `new Date()` when asOf is not a Date, and a golden file that changes
// depending on the day it was generated is not a golden file.
//
// Run from anywhere:  node flutter/test/goldens/gen-statement-goldens.js
// Writes:             flutter/test/goldens/statement_goldens.json

const fs = require('fs');
const path = require('path');

const MOBILE = '/home/user/Salapify/mobile';

// mobile/ has no node_modules in this sandbox (and no network to install
// one), so the usual babel route is unavailable. Neither of these two files
// needs it: format.js imports nothing, and statement.js imports only
// formatMoney, which is injected below.
function runModule(relPath, injected = {}) {
  const src = fs
    .readFileSync(path.join(MOBILE, relPath), 'utf8')
    .replace(/^export /gm, '')
    .replace(/^import .*$/gm, '');
  const names = [...src.matchAll(/^function (\w+)/gm)].map((m) => m[1]);
  const argNames = Object.keys(injected);
  const fn = new Function(
    ...argNames,
    `${src}\nreturn { ${names.join(', ')} };`
  );
  return fn(...argNames.map((n) => injected[n]));
}

const { formatMoney } = runModule('lib/format.js');
const { buildPersonStatement, buildPersonReminder } = runModule(
  'lib/statement.js',
  { formatMoney }
);

const AS_OF = new Date(2026, 6, 28); // Jul 28, 2026, local, like the app

// Every case is named for the rule it pins, so a Dart failure says which one.
const statementCases = [
  {
    name: 'one open utang, no payments',
    person: { name: 'Ana' },
    receivables: [
      { id: 'r1', amount: 1500, note: 'Lunch money', dueDate: '2026-07-15' },
    ],
  },
  {
    name: 'the same statement in Tagalog',
    lang: 'tl',
    person: { name: 'Ana' },
    receivables: [
      { id: 'r1', amount: 1500, note: 'Lunch money', dueDate: '2026-07-15' },
    ],
  },
  {
    name: 'partial payments, oldest payment first',
    person: { name: 'Ben Cruz' },
    receivables: [
      {
        id: 'r1',
        amount: 5000,
        note: 'Emergency',
        dueDate: '2026-06-30',
        payments: [
          { id: 'p2', amount: 1000, date: '2026-07-10' },
          { id: 'p1', amount: 500, date: '2026-06-05' },
        ],
      },
    ],
  },
  {
    name: 'marked paid with no logged payment, the reconciling line',
    person: { name: 'Ben Cruz' },
    receivables: [
      { id: 'r1', amount: 2000, note: 'Groceries', paid: true },
    ],
  },
  {
    name: 'marked paid with a short logged payment',
    person: { name: 'Ben' },
    receivables: [
      {
        id: 'r1',
        amount: 2000,
        note: 'Groceries',
        paid: true,
        payments: [{ id: 'p1', amount: 750, date: '2026-07-01' }],
      },
    ],
  },
  {
    name: 'marked paid in Tagalog',
    lang: 'tl',
    person: { name: 'Ben' },
    receivables: [{ id: 'r1', amount: 2000, paid: true }],
  },
  {
    name: 'several utang, one paid one open',
    person: { name: 'Carla' },
    receivables: [
      {
        id: 'r1',
        amount: 800,
        note: 'Load',
        dueDate: '2026-05-01',
        paid: true,
        payments: [{ id: 'p1', amount: 800, date: '2026-05-20' }],
      },
      { id: 'r2', amount: 1200, dueDate: '2026-08-01' },
    ],
  },
  {
    name: 'fully paid across every utang',
    person: { name: 'Carla' },
    receivables: [
      {
        id: 'r1',
        amount: 800,
        paid: true,
        payments: [{ id: 'p1', amount: 800, date: '2026-05-20' }],
      },
      {
        id: 'r2',
        amount: 200,
        paid: true,
        payments: [{ id: 'p2', amount: 200, date: '2026-06-02' }],
      },
    ],
  },
  {
    name: 'overpaid never goes negative',
    person: { name: 'Dan' },
    receivables: [
      {
        id: 'r1',
        amount: 500,
        payments: [
          { id: 'p1', amount: 400, date: '2026-07-01' },
          { id: 'p2', amount: 300, date: '2026-07-02' },
        ],
      },
    ],
  },
  {
    name: 'a payment with no date sorts after dated ones',
    person: { name: 'Elle' },
    receivables: [
      {
        id: 'r1',
        amount: 3000,
        payments: [
          { id: 'p1', amount: 100, date: '' },
          { id: 'p2', amount: 200, date: '2026-07-04' },
          { id: 'p3', amount: 300, date: '2026-01-04' },
        ],
      },
    ],
  },
  {
    name: 'junk amounts and junk dates',
    person: { name: 'Fred' },
    receivables: [
      { id: 'r1', amount: 'abc', note: '   ', dueDate: '2026-13-05' },
      { id: 'r2', amount: '1,200', dueDate: 'tomorrow' },
      { id: 'r3', amount: '2400', dueDate: '2026-02-29' },
      { id: 'r4', amount: null, payments: [{ id: 'p', amount: 'x', date: 5 }] },
    ],
  },
  {
    name: 'centavos in the total',
    person: { name: 'Gina' },
    receivables: [
      {
        id: 'r1',
        amount: 1000.55,
        payments: [{ id: 'p1', amount: 0.5, date: '2026-07-02' }],
      },
    ],
  },
  {
    name: 'a hair under the settled threshold still counts as open',
    person: { name: 'Hana' },
    receivables: [
      {
        id: 'r1',
        amount: 100,
        payments: [{ id: 'p1', amount: 99.99, date: '2026-07-02' }],
      },
    ],
  },
  {
    name: 'no receivables at all',
    person: { name: 'Iris' },
    receivables: [],
  },
  {
    name: 'a nameless person falls back to Someone',
    person: { name: '   ' },
    receivables: [{ id: 'r1', amount: 100 }],
  },
  {
    name: 'no person object at all',
    person: null,
    receivables: [{ id: 'r1', amount: 100 }],
  },
  {
    name: 'a name that is not a string',
    person: { name: 42 },
    receivables: [{ id: 'r1', amount: 100 }],
  },
  {
    name: 'receivables that are not a list',
    person: { name: 'Jun' },
    receivables: null,
  },
  {
    name: 'a negative utang',
    person: { name: 'Kai' },
    receivables: [{ id: 'r1', amount: -750, note: 'Refunded' }],
  },
  {
    name: 'an unknown language falls back to English',
    lang: 'es',
    person: { name: 'Lia' },
    receivables: [{ id: 'r1', amount: 100, dueDate: '2026-12-25' }],
  },
];

const reminderCases = [
  { name: 'plain English reminder', person: { name: 'Ana' }, owed: 1500 },
  { name: 'Tagalog reminder', lang: 'tl', person: { name: 'Ana' }, owed: 1500 },
  { name: 'nameless', person: { name: '  ' }, owed: 200 },
  { name: 'no person', person: null, owed: 200 },
  { name: 'junk owed', person: { name: 'Ben' }, owed: 'abc' },
  { name: 'string owed', person: { name: 'Ben' }, owed: '2400.60' },
  { name: 'zero owed', person: { name: 'Ben' }, owed: 0 },
  { name: 'negative owed', person: { name: 'Ben' }, owed: -50 },
  {
    name: 'unknown language falls back to English',
    lang: 'es',
    person: { name: 'Ben' },
    owed: 100,
  },
];

// The person screen's flat payment history with its running received total is
// not a function, it is a loose block inside a React component, so it cannot
// be required either. Same technique as the transfer goldens: cut the real
// block TEXT out of mobile/app/person.js and run THOSE characters.
function loadHistory() {
  const src = fs.readFileSync(path.join(MOBILE, 'app', 'person.js'), 'utf8');
  const start = src.indexOf('  const flat = [];');
  if (start < 0) throw new Error('the flat payment block moved in person.js');
  const marker = '.reverse();';
  const end = src.indexOf(marker, start);
  if (end < 0) throw new Error('could not find the end of the payment block');
  const body = src.slice(start, end + marker.length);
  return new Function(
    'receivables',
    `${body}\nreturn paymentRows;`
  );
}
const paymentHistory = loadHistory();

const historyCases = [
  {
    name: 'two utang, payments interleaved by date',
    receivables: [
      {
        id: 'r1',
        note: 'Emergency',
        payments: [
          { id: 'p1', amount: 500, date: '2026-06-05' },
          { id: 'p3', amount: 1000, date: '2026-07-10' },
        ],
      },
      {
        id: 'r2',
        note: 'Load',
        payments: [{ id: 'p2', amount: 250, date: '2026-06-20' }],
      },
    ],
  },
  {
    name: 'the same payment id on two different utang',
    receivables: [
      { id: 'r1', note: 'A', payments: [{ id: 'p', amount: 10, date: '2026-01-01' }] },
      { id: 'r2', note: 'B', payments: [{ id: 'p', amount: 20, date: '2026-01-02' }] },
    ],
  },
  {
    name: 'no note falls back to Utang',
    receivables: [{ id: 'r1', payments: [{ id: 'p', amount: 5, date: '2026-03-03' }] }],
  },
  {
    name: 'no payments at all',
    receivables: [{ id: 'r1', note: 'A' }, { id: 'r2', note: 'B', payments: [] }],
  },
  {
    name: 'junk amounts and missing dates',
    receivables: [
      {
        id: 'r1',
        note: 'A',
        payments: [
          { id: 'p1', amount: 'abc', date: '' },
          { id: 'p2', amount: '300', date: '2026-02-02' },
          { id: 'p3', amount: null },
        ],
      },
    ],
  },
  {
    name: 'two payments on the same day keep their order',
    receivables: [
      {
        id: 'r1',
        note: 'A',
        payments: [
          { id: 'p1', amount: 100, date: '2026-05-05' },
          { id: 'p2', amount: 200, date: '2026-05-05' },
          { id: 'p3', amount: 300, date: '2026-05-05' },
        ],
      },
    ],
  },
  { name: 'no receivables', receivables: [] },
];

const out = {
  asOf: '2026-07-28',
  history: historyCases.map((c) => ({
    name: c.name,
    receivables: c.receivables,
    rows: paymentHistory(c.receivables),
  })),
  statements: statementCases.map((c) => ({
    name: c.name,
    lang: c.lang || 'en',
    person: c.person,
    receivables: c.receivables,
    text: buildPersonStatement(c.person, c.receivables, {
      lang: c.lang,
      asOf: AS_OF,
    }),
  })),
  reminders: reminderCases.map((c) => ({
    name: c.name,
    lang: c.lang || 'en',
    person: c.person,
    owed: c.owed,
    text: buildPersonReminder(c.person, c.owed, { lang: c.lang }),
  })),
};

const dest = path.join(__dirname, 'statement_goldens.json');
fs.writeFileSync(dest, `${JSON.stringify(out, null, 2)}\n`);
console.log(
  `wrote ${dest}: ${out.statements.length} statements, ${out.reminders.length} reminders`
);
