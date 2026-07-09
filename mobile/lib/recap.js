// The monthly recap: one plain object summarizing the month, used by the
// share card. Pure math over the saved data, no dates invented, nothing
// guessed. Everything defends against missing or malformed collections so a
// recap can never crash the screen that shows it.

const num = (x) => (Number.isFinite(Number(x)) ? Number(x) : 0);

// Month key like "2026-07" for a Date.
function monthKey(d) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

// Build the recap for the month containing `ref` (default: now).
// Returns {
//   label, monthKey, moneyIn, moneyOut, kept, keptRate (0..1 or null),
//   topCats: [{ label, amount, pct }], biggest: { label, amount } | null,
//   daysLogged, debtPaid, utangCollected, verdict
// }
export function monthRecap(data, ref = new Date()) {
  const key = monthKey(ref);
  const label = `${MONTHS[ref.getMonth()]} ${ref.getFullYear()}`;
  const txns = Array.isArray(data && data.transactions) ? data.transactions : [];
  const cats = Array.isArray(data && data.categories) ? data.categories : [];
  const catNames = new Map(cats.map((c) => [c && c.id, c && c.name]));

  let moneyIn = 0;
  let moneyOut = 0;
  const byCat = Object.create(null);
  const days = new Set();
  let biggest = null;
  for (const t of txns) {
    if (!t || String(t.date || '').slice(0, 7) !== key) continue;
    if (t.type === 'income') {
      // Days logged counts only real income and expense entries; transfer
      // and debt record rows are bookkeeping, not logging.
      days.add(String(t.date).slice(0, 10));
      moneyIn += num(t.amount);
    } else if (t.type === 'expense') {
      days.add(String(t.date).slice(0, 10));
      const amt = num(t.amount);
      moneyOut += amt;
      // String() everywhere: a quick add restored from a hand edited backup
      // can carry a numeric label, and that must never crash the recap.
      const name =
        String((t.categoryId && catNames.get(t.categoryId)) || '').trim() ||
        String(t.label || '').trim() ||
        'Other';
      const k = name.toLowerCase();
      if (!byCat[k]) byCat[k] = { label: name, amount: 0 };
      byCat[k].amount += amt;
      if (!biggest || amt > biggest.amount) biggest = { label: name, amount: amt };
    }
  }

  const topCats = Object.values(byCat)
    .sort((a, b) => b.amount - a.amount)
    .slice(0, 3)
    .map((c) => ({ ...c, pct: moneyOut > 0 ? Math.round((c.amount / moneyOut) * 100) : 0 }));

  // Debt paid down this month: count principal only, since interest is a cost
  // that does not lower what you owe. Legacy payments predate the split, so fall
  // back to the whole amount as principal for them.
  const payments = Array.isArray(data && data.payments) ? data.payments : [];
  const debtPaid = payments.reduce(
    (t, p) =>
      p && String(p.date || '').slice(0, 7) === key
        ? t + Math.max(0, num(p.principal != null ? p.principal : p.amount))
        : t,
    0
  );

  // Utang collected: partial payments recorded on receivables this month.
  let utangCollected = 0;
  for (const r of Array.isArray(data && data.receivables) ? data.receivables : []) {
    for (const p of Array.isArray(r && r.payments) ? r.payments : []) {
      if (p && String(p.date || '').slice(0, 7) === key) utangCollected += Math.max(0, num(p.amount));
    }
  }

  const kept = moneyIn - moneyOut;
  const keptRate = moneyIn > 0 ? kept / moneyIn : null;

  // One honest sentence. Thresholds mirror the coach's tone elsewhere:
  // celebrate real saving, stay factual when money ran negative. Quiet
  // only means truly quiet: no logging AND no money moved anywhere, or a
  // debt-payment-only month would carry a verdict claiming nothing happened.
  let verdict;
  if (moneyIn === 0 && moneyOut === 0 && days.size === 0 && debtPaid === 0 && utangCollected === 0) {
    verdict = 'A quiet month. Log your money and next month tells a story.';
  } else if (keptRate !== null && keptRate >= 0.2) {
    verdict = `You kept ${Math.round(keptRate * 100)}% of your income. Solid month.`;
  } else if (keptRate !== null && keptRate > 0) {
    verdict = `You kept ${Math.round(keptRate * 100)}% of your income. Every peso kept counts.`;
  } else if (keptRate !== null) {
    verdict = 'Spending passed income this month. Next month is a fresh start.';
  } else {
    verdict = `You tracked ${MONTHS[ref.getMonth()]} honestly. That is the habit that changes things.`;
  }

  return {
    label,
    monthKey: key,
    moneyIn,
    moneyOut,
    kept,
    keptRate,
    topCats,
    biggest,
    daysLogged: days.size,
    debtPaid,
    utangCollected,
    verdict,
  };
}

// The plain text version of the recap, for the share-as-text fallback and
// for anyone who prefers words over an image. hideAmounts swaps peso values
// for percentages so nothing sensitive leaves the phone unless chosen.
export function recapText(recap, formatMoney, hideAmounts = false) {
  const lines = [`My ${recap.label} with Salapify:`];
  if (recap.keptRate !== null) {
    if (hideAmounts) {
      // Never claim "kept 0%" about an overspent month; say what happened.
      lines.push(
        recap.kept >= 0
          ? `Kept ${Math.round(recap.keptRate * 100)}% of my income.`
          : 'Spending passed my income this month.'
      );
    } else {
      lines.push(
        `Money in ${formatMoney(recap.moneyIn)}, out ${formatMoney(recap.moneyOut)}, kept ${formatMoney(recap.kept)}.`
      );
    }
  }
  if (recap.topCats[0]) {
    lines.push(`Top spending: ${recap.topCats[0].label} (${recap.topCats[0].pct}%).`);
  }
  if (recap.daysLogged > 0) lines.push(`Logged ${recap.daysLogged} ${recap.daysLogged === 1 ? 'day' : 'days'}.`);
  lines.push(recap.verdict);
  lines.push('Tracked with Salapify, on your money\'s side. ☕');
  return lines.join('\n');
}
