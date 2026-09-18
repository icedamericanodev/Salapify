// Golden generator for the account-to-account transfer, run from mobile/.
//
// The rule is to EXECUTE the shipped RN code, never to re-implement it from
// understanding, because understanding is exactly what misses a coercion or
// a rounding edge. saveTransfer is awkward for that: it lives inline in a
// React screen (mobile/app/accounts.js), so it cannot be required.
//
// So this reads the real file, cuts out the real saveTransfer body TEXT, and
// runs THAT with the screen's collaborators injected as plain functions. The
// arithmetic, the Number coercions, the Math.round calls and the string
// replace are the shipped characters, not a transcription of them. The one
// import it needs, formatMoney (for the overdraft message), comes from the
// real mobile/lib/format.js through babel.

const fs = require('fs');
const path = require('path');

const MOBILE = '/home/user/Salapify/mobile';

// mobile/ has no node_modules in this sandbox (and no network to install
// one), so the usual babel route is unavailable. format.js needs none of it:
// it imports nothing, so dropping the `export` keyword from the real source
// leaves plain runnable JS. The function bodies executed below are the
// shipped characters either way, which is the part that matters.
function loadFormat() {
  const src = fs
    .readFileSync(path.join(MOBILE, 'lib', 'format.js'), 'utf8')
    .replace(/^export /gm, '');
  const names = [...src.matchAll(/^function (\w+)/gm)].map((m) => m[1]);
  return new Function(`${src}\nreturn { ${names.join(', ')} };`)();
}

const { formatMoney } = loadFormat();

// Cut the real function body out of the screen source.
const screen = fs.readFileSync(path.join(MOBILE, 'app', 'accounts.js'), 'utf8');
const start = screen.indexOf('  function saveTransfer() {');
if (start < 0) throw new Error('saveTransfer not found in accounts.js');
const end = screen.indexOf('\n  }\n', start);
if (end < 0) throw new Error('could not find the end of saveTransfer');
const body = screen.slice(screen.indexOf('{', start) + 1, end);
if (!body.includes('Math.round') || !body.includes('transferFromId')) {
  throw new Error('extracted body does not look like saveTransfer');
}

// The screen's collaborators, as plain recorders.
const realSaveTransfer = new Function(
  'transfer',
  'data',
  'formatMoney',
  'todayISO',
  'updateItem',
  'addTransaction',
  'setTransferErr',
  'setTransfer',
  body,
);

const TODAY = '2026-07-28';

function run(accounts, transferForm) {
  const writes = [];
  const added = [];
  let error = '';
  let closed = false;
  realSaveTransfer(
    transferForm,
    { accounts },
    formatMoney,
    () => TODAY,
    (coll, id, patch) => writes.push({ coll, id, patch }),
    (tx) => added.push(tx),
    (msg) => {
      error = msg;
    },
    () => {
      closed = true;
    },
  );
  return { error, writes, added, closed };
}

const ACCOUNTS = [
  { id: 'cash', name: 'Cash on hand', balance: 3200 },
  { id: 'bpi', name: 'BPI Savings', balance: 48500.55 },
  { id: 'gcash', name: 'GCash', balance: 0 },
  { id: 'odd', name: 'Odd balance', balance: '1250.005' },
  { id: 'junk', name: 'Junk balance', balance: 'not a number' },
  { id: 'neg', name: 'Negative', balance: -40 },
  // A destination sitting on a tenth of a centavo below zero. Transferring
  // in lands the new balance exactly on a NEGATIVE half centavo, which is
  // the one place JS Math.round (floor(x + 0.5)) and Dart's round() (half
  // away from zero) disagree. Without a row like this the whole rounding
  // rule is untested: swapping the Dart port to .round() passed every other
  // case in this file.
  { id: 'halfneg', name: 'Half below zero', balance: -4.995 },
];

// Amounts chosen for the edges that actually bite: comma and space stripping,
// centavo half-values (JS Math.round is floor(x+0.5), which differs from Dart
// on negative halves), an exact-balance transfer, an overdraft by one centavo,
// zero, negative, junk, empty, and a float-residue pair.
const AMOUNTS = [
  '100',
  '1,000',
  ' 2 500 ',
  '0.1',
  '0.005',
  '0.015',
  '2.675',
  '3200',
  '3200.01',
  '48500.55',
  '0',
  '-5',
  '',
  'abc',
  '1e3',
  '0.30000000000000004',
  '99999999999',
  // JS Number() accepts more than a Dart double.tryParse does, and a pasted
  // or restored value can be any of these. Better to learn the divergence
  // from a golden than from a wrong balance.
  '.5',
  '5.',
  '  ',
  '0x10',
  'Infinity',
  '+7',
  '1,2,3',
  // The amounts that land -4.995 exactly on a negative half centavo.
  '0.03',
  '0.04',
  '0.05',
  '0.07',
];

const cases = [];
for (const amount of AMOUNTS) {
  for (const [fromId, toId] of [
    ['cash', 'gcash'],
    ['bpi', 'cash'],
    ['odd', 'gcash'],
    ['junk', 'cash'],
    ['neg', 'cash'],
    // Into the negative accounts, which is the only way to reach a negative
    // rounding boundary: an overdraft-blocked source can never produce one.
    ['cash', 'neg'],
    ['cash', 'halfneg'],
    ['bpi', 'halfneg'],
  ]) {
    cases.push({
      in: { amount, fromId, toId },
      out: run(ACCOUNTS, { amount, fromId, toId }),
    });
  }
}

// The rejection paths that do not depend on the amount.
for (const form of [
  { amount: '100', fromId: 'cash', toId: 'cash' },
  { amount: '100', fromId: '', toId: 'cash' },
  { amount: '100', fromId: 'cash', toId: '' },
  { amount: '100', fromId: 'ghost', toId: 'cash' },
  { amount: '100', fromId: 'cash', toId: 'ghost' },
]) {
  cases.push({ in: form, out: run(ACCOUNTS, form) });
}

const out = { today: TODAY, accounts: ACCOUNTS, cases };
const dest = '/home/user/Salapify/flutter/test/goldens/transfer_goldens.json';
fs.writeFileSync(dest, JSON.stringify(out, null, 2));
console.log('wrote', dest, 'cases:', cases.length);
