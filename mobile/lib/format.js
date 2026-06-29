// format.js holds small helpers for showing values nicely.

// The currency symbol used by formatMoney when no symbol is passed. It is kept
// here as a single value and updated from settings (see AppData), so changing
// the currency relabels amounts across the whole app without touching every
// call site.
let currentSymbol = '₱';
export function setCurrencySymbol(symbol) {
  if (symbol) currentSymbol = symbol;
}

// formatMoney turns a number like 48500 into a string like "₱48,500".
// It rounds to whole units, adds commas every three digits, and uses the
// current currency symbol unless one is passed in.
export function formatMoney(amount, symbol) {
  const sym = symbol || currentSymbol;
  const n = Math.round(Number(amount) || 0);
  const sign = n < 0 ? '-' : '';
  const digits = Math.abs(n)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, ','); // insert commas
  return sign + sym + digits;
}

// daysUntilPayday counts the days to the next payday. We assume the common
// Filipino schedule: the 15th and the last day of each month. Later this
// becomes a setting the user can change.
export function daysUntilPayday(today = new Date()) {
  const y = today.getFullYear();
  const m = today.getMonth();
  const lastDay = new Date(y, m + 1, 0).getDate(); // last day of this month
  const startToday = new Date(y, m, today.getDate()); // ignore the time part

  // The next few possible paydays, in order.
  const candidates = [
    new Date(y, m, 15),
    new Date(y, m, lastDay),
    new Date(y, m + 1, 15),
  ];
  for (const c of candidates) {
    const diff = Math.round((c - startToday) / 86400000); // ms in a day
    if (diff >= 0) return diff;
  }
  return 0;
}
