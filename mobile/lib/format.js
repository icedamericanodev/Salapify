// format.js holds small helpers for showing values nicely.

// formatMoney turns a number like 48500 into a string like "P48,500".
// We use "P" style by passing a symbol. It rounds to whole units for a clean
// look and adds commas every three digits. Negative values get a minus sign.
export function formatMoney(amount, symbol = '₱') {
  // ₱ is the peso sign. We will make this come from settings later.
  const n = Math.round(Number(amount) || 0);
  const sign = n < 0 ? '-' : '';
  const digits = Math.abs(n)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, ','); // insert commas
  return sign + symbol + digits;
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
