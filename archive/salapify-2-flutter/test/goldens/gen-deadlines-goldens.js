// Golden generator for the BIR deadline list, executing the real
// mobile/lib/taxdeadlines.js. It imports nothing, so dropping the export
// keyword leaves plain runnable JS and the function body below is the shipped
// characters.
//
// The cases that matter are the boundaries: a deadline dated TODAY must read
// as upcoming with 0 days left, the list must wrap across the year end, the
// 8% option must drop the percentage tax rows, and a junk date must give an
// empty list rather than a wrong one.

const fs = require('fs');

function load(rel) {
  const src = fs.readFileSync(rel, 'utf8').replace(/^export /gm, '');
  const names = [...src.matchAll(/^function (\w+)/gm)].map((m) => m[1]);
  return new Function(`${src}\nreturn { ${names.join(', ')} };`)();
}

const { taxDeadlines } = load('/home/user/Salapify/mobile/lib/taxdeadlines.js');

const iso = (d) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

const DAYS = [
  '2026-01-01', '2026-01-25', '2026-01-26', '2026-04-14', '2026-04-15',
  '2026-04-16', '2026-04-25', '2026-05-15', '2026-07-25', '2026-08-15',
  '2026-10-25', '2026-11-15', '2026-11-16', '2026-12-31',
  // A leap day and the day after, because date math loves February.
  '2028-02-29', '2028-03-01',
];

const cases = [];
for (const day of DAYS) {
  for (const onEight of [false, true]) {
    for (const count of [4, 1, 12, 0, 99]) {
      const rows = taxDeadlines(new Date(day + 'T09:30:00'), {
        onEightPercent: onEight,
        count,
      });
      cases.push({
        in: { today: day, onEightPercent: onEight, count },
        out: rows.map((r) => ({
          form: r.form,
          title: r.title,
          what: r.what,
          year: r.year,
          date: iso(r.date),
          daysLeft: r.daysLeft,
        })),
      });
    }
  }
}

// Junk in, empty out: never a wrong deadline.
for (const bad of ['not a date', '', null]) {
  cases.push({
    in: { today: bad === null ? '__null__' : bad, onEightPercent: false, count: 4 },
    out: taxDeadlines(bad === null ? null : bad, {}),
  });
}

const dest = '/home/user/Salapify/flutter/test/goldens/taxdeadlines_goldens.json';
fs.writeFileSync(dest, JSON.stringify({ cases }, null, 2));
console.log('wrote', dest, 'cases:', cases.length);
