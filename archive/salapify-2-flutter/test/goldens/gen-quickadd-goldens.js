// Golden generator for the quick add button list: which additions are accepted,
// which are silently refused, and what the list looks like afterwards.
//
// The rule is to EXECUTE the shipped RN code, never to re-implement it from
// understanding. addQuickAdd and removeQuickAdd are not exported functions,
// they are declared inside a React component in mobile/app/preferences.js, so
// they cannot be required. Same technique the transfer and statement
// generators use: cut the real function body TEXT out of the screen and run
// THOSE characters with the screen's collaborators injected.
//
// Run from anywhere:  node flutter/test/goldens/gen-quickadd-goldens.js
// Writes:             flutter/test/goldens/quickadd_goldens.json

const fs = require('fs');
const path = require('path');

const MOBILE = '/home/user/Salapify/mobile';

const src = fs.readFileSync(path.join(MOBILE, 'app', 'preferences.js'), 'utf8');

function cut(name) {
  const start = src.indexOf(`  function ${name}(`);
  if (start < 0) throw new Error(`${name} moved in preferences.js`);
  const end = src.indexOf('\n  }\n', start);
  if (end < 0) throw new Error(`could not find the end of ${name}`);
  return src.slice(start, end + 4);
}

// The two bodies, run together so addQuickAdd's duplicate check sees the same
// settings object removeQuickAdd mutates.
const body = `${cut('addQuickAdd')}\n${cut('removeQuickAdd')}`;

// Collaborators: the screen's state and its updateSettings reducer, as plain
// values. settings.quickAdds is what the app really stores.
function run(startList, action) {
  const settings = { quickAdds: startList === null ? undefined : [...startList] };
  let qaLabel = action.label === undefined ? '' : action.label;
  let qaAmount = action.amount === undefined ? '' : action.amount;
  const cleared = { label: false, amount: false };
  const fn = new Function(
    'settings',
    'updateSettings',
    'getLabel',
    'getAmount',
    'setQaLabel',
    'setQaAmount',
    `const qaLabel = getLabel(); const qaAmount = getAmount();
     ${body}
     return { addQuickAdd, removeQuickAdd };`
  );
  const api = fn(
    settings,
    (patch) => Object.assign(settings, patch),
    () => qaLabel,
    () => qaAmount,
    (v) => {
      cleared.label = v === '';
    },
    (v) => {
      cleared.amount = v === '';
    }
  );
  if (action.kind === 'add') api.addQuickAdd();
  else api.removeQuickAdd(action.index);
  return { list: settings.quickAdds || [], cleared };
}

const START = [
  { label: 'Food', amount: 150 },
  { label: 'Transport', amount: 50 },
];

const cases = [
  { name: 'a plain new button', kind: 'add', label: 'Coffee', amount: '120' },
  { name: 'a decimal amount', kind: 'add', label: 'Jeep', amount: '13.50' },
  { name: 'a label with surrounding spaces is trimmed', kind: 'add', label: '  Load  ', amount: '100' },
  { name: 'an exact duplicate label is refused', kind: 'add', label: 'Food', amount: '999' },
  { name: 'a duplicate in a different case is refused', kind: 'add', label: 'fOOd', amount: '999' },
  { name: 'a duplicate that only differs by spaces is refused', kind: 'add', label: '  food ', amount: '999' },
  { name: 'an empty label is refused', kind: 'add', label: '', amount: '100' },
  { name: 'a whitespace only label is refused', kind: 'add', label: '   ', amount: '100' },
  { name: 'a zero amount is refused', kind: 'add', label: 'Zero', amount: '0' },
  { name: 'a negative amount is refused', kind: 'add', label: 'Neg', amount: '-50' },
  { name: 'a junk amount is refused', kind: 'add', label: 'Junk', amount: 'abc' },
  { name: 'an empty amount is refused', kind: 'add', label: 'Blank', amount: '' },
  { name: 'a whitespace amount is refused', kind: 'add', label: 'Space', amount: '   ' },
  { name: 'a comma grouped amount is refused', kind: 'add', label: 'Comma', amount: '1,500' },
  { name: 'a leading plus is accepted', kind: 'add', label: 'Plus', amount: '+70' },
  { name: 'a hex literal is accepted', kind: 'add', label: 'Hex', amount: '0x10' },
  { name: 'an infinite amount is refused', kind: 'add', label: 'Inf', amount: 'Infinity' },
  { name: 'a very large amount is accepted', kind: 'add', label: 'Big', amount: '999999999' },
  // Two cases RN ACCEPTS and this app deliberately does not. They are in the
  // fixture so the divergence is recorded on purpose rather than discovered:
  // the replay asserts RN's answer, and the Dart test asserts the refusal
  // beside it with the reason.
  { name: 'RN accepts a sub centavo amount', kind: 'add', label: 'Kape', amount: '0.004' },
  { name: 'RN accepts a very long label', kind: 'add', label: 'Pamasahe papuntang opisina tapos pauwi rin sa gabi', amount: '92' },
  { name: 'remove the first', kind: 'remove', index: 0 },
  { name: 'remove the last', kind: 'remove', index: 1 },
  { name: 'remove an index that is not there', kind: 'remove', index: 9 },
  { name: 'remove a negative index', kind: 'remove', index: -1 },
];

const out = {
  start: START,
  cases: cases.map((c) => {
    const r = run(START, c);
    return {
      name: c.name,
      kind: c.kind,
      label: c.label,
      amount: c.amount,
      index: c.index,
      // JSON has no Infinity, so an amount that came out non finite is
      // recorded as a sentinel rather than silently becoming null.
      list: r.list.map((q) => ({
        label: q.label,
        amount: Number.isFinite(q.amount) ? q.amount : '__nonfinite__',
      })),
      // Whether the screen cleared its two input fields, which is the signal
      // the user gets that the add was accepted.
      accepted: r.cleared.label && r.cleared.amount,
    };
  }),
  // Adding to a list that has never been set at all.
  fromNothing: (() => {
    const r = run(null, { kind: 'add', label: 'First', amount: '75' });
    return { list: r.list, accepted: r.cleared.label && r.cleared.amount };
  })(),
};

const dest = path.join(__dirname, 'quickadd_goldens.json');
fs.writeFileSync(dest, `${JSON.stringify(out, null, 2)}\n`);
console.log(`wrote ${dest}: ${out.cases.length} cases`);
