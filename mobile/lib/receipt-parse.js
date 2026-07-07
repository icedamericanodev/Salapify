// Receipt parser. On-device OCR (Google ML Kit, added in the native rebuild)
// hands us the raw text of a receipt photo; this turns that text into a
// merchant, a date, and a total we can prefill into the expense or split
// form. Pure string work, no network, no dependency, easy to test.
//
// The house rule from Pan holds here too: this never invents a number. It
// only reads amounts that are printed on the receipt, and when it is not
// confident which one is the total it says so (confidence 'low', total null)
// so the screen asks you to confirm rather than guessing your money wrong.

// A money amount as printed: optional peso mark, thousands groups, decimals.
// "1,234.56", "150.00", "₱150", "P 150", "PHP 1200". Captures the numeric
// part only; the caller strips the commas.
const MONEY = /(?:php|p|₱)?\s*(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)/gi;

// Keywords that mark the line carrying the real total, strongest first. We
// prefer these over just taking the biggest number, because the biggest
// number on a receipt is often the cash tendered, not the total.
const TOTAL_KEYS = [
  { re: /\bamount\s*due\b/i, rank: 5 },
  { re: /\btotal\s*due\b/i, rank: 5 },
  { re: /\bgrand\s*total\b/i, rank: 4 },
  { re: /\btotal\s*amount\b/i, rank: 4 },
  { re: /\btotal\s*sale\b/i, rank: 3 },
  { re: /\btotal\b/i, rank: 2 },
];
// Lines that look like a total but are not the amount you spent. Checked
// first, so "Subtotal" and "Cash" never win the total.
const NOT_TOTAL = /\b(sub\s*total|subtotal|vat(?:able| amount| exempt)?|cash|tendered|change|tender|discount|senior|pwd|less\b)/i;

// Lines whose numbers are identifiers, not money: a TIN, a serial, a phone.
// Their digit runs would otherwise pollute the amounts list and the fallback
// total. A three-by-three grouped number (000-123-456) is the TIN giveaway.
const NOISE = /\b(tin|vat\s*reg|ser(?:ial)?\s*no|s\/n|tel|contact|phone|acct|account\s*no)\b/i;
function isNoise(line) {
  return NOISE.test(line) || /\d{3}[-\s]\d{3}[-\s]\d{3}/.test(line);
}

// Split raw OCR text (ML Kit returns one string with newlines) or an array
// of lines into clean, non-empty lines.
function toLines(input) {
  if (Array.isArray(input)) return input.map((l) => String(l == null ? '' : l)).map((l) => l.trim()).filter(Boolean);
  return String(input == null ? '' : input)
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean);
}

// Every money amount on a line, largest last as printed order is kept.
function amountsOn(line) {
  const out = [];
  let m;
  MONEY.lastIndex = 0;
  while ((m = MONEY.exec(line))) {
    const n = Number(m[1].replace(/,/g, ''));
    // A bare "2024" with no peso mark and no decimals on a line that also
    // holds a date is almost certainly a year, not money; the date pass
    // handles those. Here we keep it simple and let the caller weigh context.
    if (Number.isFinite(n) && n > 0) out.push(n);
  }
  return out;
}

// Pull a date in any common receipt format and normalise to YYYY-MM-DD.
const MONTHS = { jan: 1, feb: 2, mar: 3, apr: 4, may: 5, jun: 6, jul: 7, aug: 8, sep: 9, oct: 10, nov: 11, dec: 12 };
function pad(n) {
  return String(n).padStart(2, '0');
}
function validYmd(y, mo, d) {
  if (y < 100) y += 2000; // "26" -> 2026
  if (mo < 1 || mo > 12 || d < 1 || d > 31 || y < 2000 || y > 2100) return null;
  const dt = new Date(y, mo - 1, d);
  if (dt.getFullYear() !== y || dt.getMonth() !== mo - 1 || dt.getDate() !== d) return null;
  return `${y}-${pad(mo)}-${pad(d)}`;
}
function parseDate(text) {
  // 2026-07-03 or 2026/07/03
  let m = /\b(\d{4})[/-](\d{1,2})[/-](\d{1,2})\b/.exec(text);
  if (m) return validYmd(Number(m[1]), Number(m[2]), Number(m[3]));
  // Jul 3, 2026  /  3 Jul 2026
  m = /\b([a-z]{3,})\.?\s+(\d{1,2}),?\s+(\d{4})\b/i.exec(text);
  if (m && MONTHS[m[1].slice(0, 3).toLowerCase()]) return validYmd(Number(m[3]), MONTHS[m[1].slice(0, 3).toLowerCase()], Number(m[2]));
  m = /\b(\d{1,2})\s+([a-z]{3,})\.?\s+(\d{4})\b/i.exec(text);
  if (m && MONTHS[m[2].slice(0, 3).toLowerCase()]) return validYmd(Number(m[3]), MONTHS[m[2].slice(0, 3).toLowerCase()], Number(m[1]));
  // 07/03/2026 or 07-03-26. PH receipts skew US style (month first); if the
  // first part is over 12 it must be the day, so swap.
  m = /\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b/.exec(text);
  if (m) {
    let a = Number(m[1]), b = Number(m[2]);
    const y = Number(m[3]);
    let mo = a, d = b;
    if (a > 12 && b <= 12) { mo = b; d = a; }
    return validYmd(y, mo, d);
  }
  return null;
}

// Guess the merchant: the first real line of text near the top that is not a
// number, a date, an address, or boilerplate. Receipts print the store name
// first, so we scan only the first few lines.
const MERCHANT_SKIP = /\b(receipt|official|invoice|tin\b|vat reg|address|tel|contact|cashier|welcome|thank)/i;
function parseMerchant(lines) {
  for (const line of lines.slice(0, 5)) {
    if (MERCHANT_SKIP.test(line)) continue;
    const letters = line.replace(/[^a-z]/gi, '');
    if (letters.length < 3) continue; // skip pure-number / symbol lines
    if (parseDate(line)) continue;
    // A line that is mostly digits (an amount, a TIN) is not a name.
    const digits = (line.match(/\d/g) || []).length;
    if (digits > letters.length) continue;
    return line.replace(/\s{2,}/g, ' ').trim();
  }
  return null;
}

export function parseReceipt(input) {
  const lines = toLines(input);
  const raw = lines.join('\n');
  if (lines.length === 0) {
    return { total: null, totalConfidence: 'low', date: null, merchant: null, amounts: [], lineItems: [], raw: '' };
  }

  // Every amount anywhere, for the fallback and for the picker the UI shows.
  const allAmounts = [];
  for (const line of lines) {
    if (isNoise(line)) continue;
    for (const a of amountsOn(line)) allAmounts.push(a);
  }
  const amounts = [...new Set(allAmounts)].sort((x, y) => y - x);

  // Find the total by keyword, strongest keyword wins, ties break on the
  // larger amount. Lines that look like a total but are not (subtotal, cash,
  // change) are skipped entirely.
  let best = null; // { rank, amount }
  for (const line of lines) {
    if (NOT_TOTAL.test(line)) continue;
    let rank = 0;
    for (const k of TOTAL_KEYS) if (k.re.test(line)) { rank = Math.max(rank, k.rank); }
    if (!rank) continue;
    const onLine = amountsOn(line);
    if (!onLine.length) continue;
    const amount = Math.max(...onLine);
    if (!best || rank > best.rank || (rank === best.rank && amount > best.amount)) best = { rank, amount };
  }

  let total = null;
  let totalConfidence = 'low';
  if (best) {
    total = best.amount;
    totalConfidence = 'high';
  } else if (amounts.length) {
    // No total keyword found: fall back to the largest amount, but flag it
    // low so the screen asks the user to confirm before saving.
    total = amounts[0];
    totalConfidence = 'low';
  }

  // Best-effort item lines: a label followed by a trailing amount, skipping
  // the total and tax lines. Kept for the split screen to itemise later.
  const lineItems = [];
  for (const line of lines) {
    if (isNoise(line) || NOT_TOTAL.test(line) || TOTAL_KEYS.some((k) => k.re.test(line))) continue;
    const onLine = amountsOn(line);
    if (!onLine.length) continue;
    const label = line.replace(MONEY, '').replace(/[^a-z0-9 &.-]/gi, ' ').replace(/\s{2,}/g, ' ').trim();
    if (label.length >= 2) lineItems.push({ label, amount: onLine[onLine.length - 1] });
  }

  return {
    total,
    totalConfidence,
    date: parseDate(raw),
    merchant: parseMerchant(lines),
    amounts,
    lineItems,
    raw,
  };
}
