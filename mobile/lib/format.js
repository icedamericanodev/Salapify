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
