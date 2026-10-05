// Regression suite for lib/statement.js: the shareable Statement of Account.
import { buildPersonStatement, buildPersonReminder } from '../lib/statement';

const asOf = new Date(2026, 6, 8); // Jul 8, 2026

const juan = { name: 'Juan Dela Cruz' };
const juanRec = [
  { id: 'a', note: 'Lunch', dueDate: '2026-06-01', amount: 500, paid: false, payments: [{ id: 'p1', amount: 200, date: '2026-06-20' }] },
  { id: 'b', note: 'Load', dueDate: '2026-06-15', amount: 300, paid: false, payments: [] },
];

describe('buildPersonStatement', () => {
  test('the money reconciles: total lent, total paid, still open', () => {
    const s = buildPersonStatement(juan, juanRec, { lang: 'en', asOf });
    expect(s).toContain('Total lent: ₱800');
    expect(s).toContain('Total paid: ₱200');
    expect(s).toContain('STILL OPEN: ₱600');
  });

  test('lists each utang with its due date and label, and the payment', () => {
    const s = buildPersonStatement(juan, juanRec, { lang: 'en', asOf });
    expect(s).toContain('Jun 1, 2026');
    expect(s).toContain('Lunch');
    expect(s).toContain('Jun 15, 2026');
    expect(s).toContain('Load');
    expect(s).toContain('Jun 20, 2026   ₱200');
    expect(s).toContain('For: Juan Dela Cruz');
    expect(s).toContain('As of Jul 8, 2026');
  });

  test('a fully paid person gets the receipt tone, not a nudge', () => {
    const paid = [{ id: 'a', note: 'Lunch', dueDate: '2026-06-01', amount: 500, paid: true, payments: [{ id: 'p1', amount: 500, date: '2026-06-20' }] }];
    const s = buildPersonStatement(juan, paid, { lang: 'en', asOf });
    expect(s).toContain('FULLY PAID');
    expect(s).not.toContain('STILL OPEN');
    expect(s).toContain('Fully paid na, salamat!');
  });

  test('a paid utang with no logged payment is settled, never billed', () => {
    // The critical case: one utang marked paid via the toggle (no payment
    // rows) sitting next to an open one. The screen shows only the open one
    // as owed; the statement must agree and never dun for the settled amount.
    const mixed = [
      { id: 'a', note: 'Lunch', amount: 500, paid: true, payments: [] },
      { id: 'b', note: 'Load', amount: 300, paid: false, payments: [] },
    ];
    const s = buildPersonStatement(juan, mixed, { lang: 'en', asOf });
    expect(s).toContain('STILL OPEN: ₱300'); // not ₱800
    expect(s).toContain('Marked paid'); // the settled 500 is shown, not billed
    expect(s).toContain('Total paid: ₱500');
  });

  test('a person fully settled only by the paid toggle gets the receipt tone', () => {
    const s = buildPersonStatement(juan, [{ id: 'a', note: 'Lunch', amount: 500, paid: true, payments: [] }], { lang: 'en', asOf });
    expect(s).toContain('FULLY PAID');
    expect(s).not.toContain('STILL OPEN');
  });

  test('Tagalog uses the Tagalog labels and closing', () => {
    const s = buildPersonStatement(juan, juanRec, { lang: 'tl', asOf });
    expect(s).toContain('Para kay: Juan Dela Cruz');
    expect(s).toContain('Kabuuang inutang: ₱800');
    expect(s).toContain('NATITIRA: ₱600');
    expect(s).toContain('Walang pressure ha');
  });

  test('an utang with no due date reads clean, no crash on junk', () => {
    const s = buildPersonStatement(juan, [{ id: 'x', amount: 100, payments: [] }], { lang: 'en', asOf });
    expect(s).toContain('No due date');
    expect(s).toContain('Total lent: ₱100');
    // junk never throws
    expect(() => buildPersonStatement(null, null, {})).not.toThrow();
    expect(() => buildPersonStatement({}, [{ amount: 'bad', payments: 'no' }], {})).not.toThrow();
  });
});

describe('buildPersonReminder', () => {
  test('covers the whole owed total, warm tone, both languages', () => {
    expect(buildPersonReminder(juan, 600, { lang: 'en' })).toContain('₱600');
    expect(buildPersonReminder(juan, 600, { lang: 'en' })).toContain('No rush');
    expect(buildPersonReminder(juan, 600, { lang: 'tl' })).toContain('Walang pressure');
    expect(() => buildPersonReminder(null, NaN, {})).not.toThrow();
  });
});
