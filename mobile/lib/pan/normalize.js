// Pan text normalization. Turns a raw user message into a clean, lowercased
// token string the intent matcher can score, folding common Taglish words to
// the English tokens the intent keywords use. Kept as small data tables, not
// logic, so the vocabulary grows without touching the matcher. No LLM, no
// network, no dependencies: pure string work that runs in microseconds.

// Diacritic folding, explicit and tiny (Filipino text rarely uses these, but
// pasted text might). Avoids leaning on Hermes String.normalize edge cases.
const DIACRITICS = {
  á: 'a', à: 'a', â: 'a', ä: 'a', ã: 'a',
  é: 'e', è: 'e', ê: 'e', ë: 'e',
  í: 'i', ì: 'i', î: 'i', ï: 'i',
  ó: 'o', ò: 'o', ô: 'o', ö: 'o', õ: 'o',
  ú: 'u', ù: 'u', û: 'u', ü: 'u',
  ñ: 'n', ç: 'c',
};

// Single-token Taglish to canonical English. The matcher only knows English
// tokens, so this is the whole bilingual layer.
const SYNONYMS = {
  utang: 'owe',
  pautang: 'owe',
  naniningil: 'owe',
  sweldo: 'payday',
  suweldo: 'payday',
  sahod: 'payday',
  kinsenas: 'payday',
  katapusan: 'payday',
  gastos: 'spending',
  gastusin: 'spend',
  gumastos: 'spend',
  gastador: 'spending',
  pera: 'money',
  kwarta: 'money',
  kuwarta: 'money',
  ipon: 'savings',
  naiipon: 'save',
  maipon: 'save',
  magipon: 'save',
  bayad: 'pay',
  bayaran: 'pay',
  babayaran: 'pay',
  bayarin: 'bills',
  utangko: 'debt',
  magkano: 'howmuch',
  kaya: 'can',
  pwede: 'can',
  sino: 'who',
  kanino: 'who',
  kelan: 'when',
  kailan: 'when',
  ngayon: 'today',
  buwan: 'month',
  linggo: 'week',
  araw: 'day',
  matatapos: 'finish',
  natitira: 'left',
  natira: 'left',
  abutin: 'reach',
  budget: 'budget',
  baon: 'spend',
};

// Multi-word Taglish phrases, folded before tokenizing.
const PHRASES = [
  [/\bmay utang sa akin\b/g, 'who owe me'],
  [/\bsino may utang\b/g, 'who owe'],
  [/\bkanino ako naniningil\b/g, 'who owe me'],
  [/\bmagkano pa\b/g, 'howmuch left'],
  [/\bkaya ko pa ba\b/g, 'can i'],
  [/\bkaya ko ba\b/g, 'can i'],
  [/\bkumusta( ang)? gastos\b/g, 'how spending'],
  [/\bpang gastos\b/g, 'spend'],
  [/\bhanggang sweldo\b/g, 'until payday'],
  [/\bhow much can i\b/g, 'howmuch can i'],
  [/\bhow much do i\b/g, 'howmuch i'],
  [/\bhow much is\b/g, 'howmuch'],
];

export function normalize(raw) {
  let s = String(raw || '').toLowerCase();
  s = s.replace(/[À-ſ]/g, (ch) => DIACRITICS[ch] || ch);
  // Fold known phrases first, while spacing is intact.
  for (const [re, to] of PHRASES) s = s.replace(re, to);
  // Keep letters, digits, %, and spaces. Everything else becomes a space.
  s = s.replace(/[^a-z0-9%\s]/g, ' ');
  const tokens = s.split(/\s+/).filter(Boolean).map((t) => SYNONYMS[t] || t);
  return tokens.join(' ');
}

// Pull the first money-like number out of a message: "2000", "2,000", "1.5k",
// "P350". Returns a Number, or null when there is none. Used by the
// can-I-afford intent; the arithmetic that follows stays in the engine.
export function extractAmount(raw) {
  const s = String(raw || '').toLowerCase().replace(/,/g, '');
  const m = s.match(/(\d+(?:\.\d+)?)\s*([km])?/);
  if (!m) return null;
  let n = Number(m[1]);
  if (!Number.isFinite(n)) return null;
  if (m[2] === 'k') n *= 1000;
  if (m[2] === 'm') n *= 1000000;
  return n;
}
