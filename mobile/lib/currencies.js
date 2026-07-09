// The currencies the app understands, in one shared place so the Settings
// currency picker and the per transaction currency picker never drift apart.
//
// There are deliberately NO exchange rates stored here. Salapify is offline
// first, and a cached rate goes stale silently, a finance app must never quietly
// show a wrong peso figure. So when a user logs an expense in another currency,
// they give the rate at that moment, and we store the already converted base
// amount. Everything downstream stays in the one base currency.

export const CURRENCIES = [
  { code: 'PHP', symbol: '₱' },
  { code: 'USD', symbol: '$' },
  { code: 'EUR', symbol: '€' },
  { code: 'GBP', symbol: '£' },
  { code: 'JPY', symbol: '¥' },
  { code: 'CNY', symbol: '¥' },
  { code: 'KRW', symbol: '₩' },
  { code: 'INR', symbol: '₹' },
  { code: 'IDR', symbol: 'Rp' },
  { code: 'MYR', symbol: 'RM' },
  { code: 'SGD', symbol: 'S$' },
  { code: 'THB', symbol: '฿' },
  { code: 'VND', symbol: '₫' },
  { code: 'HKD', symbol: 'HK$' },
  { code: 'AUD', symbol: 'A$' },
  { code: 'CAD', symbol: 'C$' },
  { code: 'AED', symbol: 'AED' },
  { code: 'SAR', symbol: 'SAR' },
  { code: 'CHF', symbol: 'CHF' },
  { code: 'NZD', symbol: 'NZ$' },
];

// The sign to show for a currency code, falling back to the code itself so an
// unknown code never renders blank.
export function currencySymbol(code) {
  const c = CURRENCIES.find((x) => x.code === code);
  return c ? c.symbol : String(code || '');
}

// A short original amount label like "¥1,000" or "USD 12", shown next to a
// converted expense so the user still sees what they actually paid. Whole
// numbers only, matching how formatMoney renders base amounts.
export function formatForeign(amount, code) {
  const n = Number(amount);
  if (!Number.isFinite(n)) return '';
  const whole = Math.round(n).toLocaleString('en-US');
  return `${currencySymbol(code)}${whole}`;
}
