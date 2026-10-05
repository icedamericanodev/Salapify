// statement.js builds a plain text Statement of Account for one person's
// utang, ready to share over any messaging app. It only sums what is already
// stored, no forecasting, so the math always ties out: total lent minus total
// paid equals what is still open. The tone is warm and never a demand letter,
// in English or Tagalog. No dashes.

import { formatMoney } from './format';

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const num = (x) => (Number.isFinite(Number(x)) ? Number(x) : 0);

// 'YYYY-MM-DD' to 'Jul 8, 2026'. Junk or empty returns ''.
function fmtDate(iso) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(iso || ''));
  if (!m) return '';
  const month = MONTHS[Number(m[2]) - 1];
  if (!month) return '';
  return `${month} ${Number(m[3])}, ${m[1]}`;
}

const COPY = {
  en: {
    for: 'For', asOf: 'As of', utang: 'UTANG', due: 'Due', noDue: 'No due date', utangDefault: 'Utang',
    paidTag: 'paid', ofPaid: 'of', markedPaid: 'Marked paid',
    totalLent: 'Total lent', payHead: 'PAYMENTS RECEIVED', totalPaid: 'Total paid',
    stillOpen: 'STILL OPEN', fullyPaid: 'FULLY PAID',
    closeOpen: 'No pressure at all, this is just my own record so we are both on the same page. Salamat!',
    closePaid: 'Fully paid na, salamat! Keeping this just for our record. 🙌',
  },
  tl: {
    for: 'Para kay', asOf: 'As of', utang: 'UTANG', due: 'Due', noDue: 'Walang due date', utangDefault: 'Utang',
    paidTag: 'bayad na', ofPaid: 'ng', markedPaid: 'Minarkahang bayad',
    totalLent: 'Kabuuang inutang', payHead: 'MGA NABAYARAN NA', totalPaid: 'Kabuuang bayad',
    stillOpen: 'NATITIRA', fullyPaid: 'BAYAD NA LAHAT',
    closeOpen: 'Walang pressure ha, record ko lang ito para malinaw sa ating dalawa. Salamat!',
    closePaid: 'Bayad na lahat, salamat! Record lang natin ito. 🙌',
  },
};

// person: { name }, receivables: that person's receivable rows, opts:
// { lang: 'en' | 'tl', asOf: Date }. Returns the statement as one string.
//
// The reconciliation honors the receivable's `paid` flag exactly like the
// ledger does: a paid utang counts as fully settled even if it carries no
// logged payments (someone can mark cash paid without logging it, and legacy
// utang were settled before payment tracking existed). This keeps STILL OPEN
// equal to what the app shows as owed, so the statement can never bill a
// friend for money the app itself considers paid.
export function buildPersonStatement(person, receivables, opts = {}) {
  const t = COPY[opts.lang === 'tl' ? 'tl' : 'en'];
  const asOf = opts.asOf instanceof Date ? opts.asOf : new Date();
  const name = (person && typeof person.name === 'string' && person.name.trim()) || 'Someone';
  const list = Array.isArray(receivables) ? receivables : [];

  let totalLent = 0;
  const utangLines = [];
  const paymentEntries = []; // { date, amount, marked, note }
  for (const r of list) {
    const amount = num(r && r.amount);
    totalLent += amount;
    const ps = r && Array.isArray(r.payments) ? r.payments : [];
    let loggedSum = 0;
    for (const p of ps) {
      const pa = num(p && p.amount);
      loggedSum += pa;
      paymentEntries.push({ date: (p && p.date) || '', amount: pa, marked: false });
    }
    const isPaid = !!(r && r.paid);
    const label = (r && typeof r.note === 'string' && r.note.trim()) || t.utangDefault;
    // A paid utang whose logged payments fall short was settled by marking it
    // paid; record that difference so the payment lines still sum to Total paid.
    if (isPaid && amount - loggedSum > 0.005) {
      paymentEntries.push({ date: '', amount: amount - loggedSum, marked: true, note: label });
    }
    const due = fmtDate(r && r.dueDate);
    const status = isPaid
      ? ` · ${t.paidTag}`
      : loggedSum > 0.005
      ? ` · ${formatMoney(loggedSum)} ${t.ofPaid} ${formatMoney(amount)} ${t.paidTag}`
      : '';
    utangLines.push(`${due ? `${t.due} ${due}` : t.noDue}   ${label}   ${formatMoney(amount)}${status}`);
  }
  const totalPaid = paymentEntries.reduce((s, e) => s + e.amount, 0);
  const stillOpen = Math.max(0, Math.round((totalLent - totalPaid) * 100) / 100);
  const fullyPaid = totalLent > 0 && stillOpen <= 0.005;

  // Oldest first; the marked-paid lines (no date) come last.
  paymentEntries.sort((a, b) => {
    if (!a.date && b.date) return 1;
    if (a.date && !b.date) return -1;
    return a.date < b.date ? -1 : a.date > b.date ? 1 : 0;
  });

  const asOfStr = fmtDate(
    `${asOf.getFullYear()}-${String(asOf.getMonth() + 1).padStart(2, '0')}-${String(asOf.getDate()).padStart(2, '0')}`
  );

  const lines = ['SALAPIFY · Statement of Account', `${t.for}: ${name}`, `${t.asOf} ${asOfStr}`, '', t.utang, ...utangLines, `${t.totalLent}: ${formatMoney(totalLent)}`];
  if (paymentEntries.length > 0) {
    lines.push('', t.payHead);
    for (const e of paymentEntries) {
      if (e.marked) lines.push(`${t.markedPaid}   ${e.note}   ${formatMoney(e.amount)}`);
      else lines.push(`${fmtDate(e.date)}   ${formatMoney(e.amount)}`.trim());
    }
    lines.push(`${t.totalPaid}: ${formatMoney(totalPaid)}`);
  }

  lines.push('');
  if (fullyPaid) {
    lines.push(t.fullyPaid, '', t.closePaid);
  } else {
    lines.push(`${t.stillOpen}: ${formatMoney(stillOpen)}`, '', t.closeOpen);
  }
  lines.push('Made with Salapify.');
  return lines.join('\n');
}

// A one line reminder covering everything a person still owes, warm and
// non threatening, matching the ledger's existing reminder tone.
export function buildPersonReminder(person, owed, opts = {}) {
  const name = (person && typeof person.name === 'string' && person.name.trim()) || 'Someone';
  const amount = formatMoney(num(owed));
  if (opts.lang === 'tl') {
    return `Hi ${name}! Paalala lang sa ${amount} na total ng utang. Walang pressure, para lang di natin makalimutan. Salamat! 🙏`;
  }
  return `Hi ${name}! Friendly reminder about the ${amount} total you still owe. No rush, just so we both remember. Thank you! 🙏`;
}
