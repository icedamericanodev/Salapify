import { TransactionType, ProfileEntity } from '../types';

export interface FastLogParsed {
  isValid: boolean;
  type: TransactionType;
  amount: number;
  merchant: string;
  category: string;
  person?: string;
  suggestedPerson?: string;
  suggestedAccountKind?: 'cash' | 'gcash' | 'maya' | 'bank' | 'credit';
  suggestedProfile?: ProfileEntity;
  displayPreview: string;
}

const CATEGORY_KEYWORDS: Record<string, string> = {
  // Food & Dining
  jollibee: 'Food & Dining',
  mcdonalds: 'Food & Dining',
  mcdo: 'Food & Dining',
  starbucks: 'Food & Dining',
  coffee: 'Food & Dining',
  kape: 'Food & Dining',
  chowking: 'Food & Dining',
  manginasal: 'Food & Dining',
  inasal: 'Food & Dining',
  kfc: 'Food & Dining',
  lunch: 'Food & Dining',
  dinner: 'Food & Dining',
  breakfast: 'Food & Dining',
  almusal: 'Food & Dining',
  tanghalian: 'Food & Dining',
  hapunan: 'Food & Dining',
  merienda: 'Food & Dining',
  snack: 'Food & Dining',
  food: 'Food & Dining',
  samgyup: 'Food & Dining',
  milktea: 'Food & Dining',
  boba: 'Food & Dining',
  karinderya: 'Food & Dining',
  taho: 'Food & Dining',
  pares: 'Food & Dining',
  siomai: 'Food & Dining',
  foodpanda: 'Food & Dining',
  grabfood: 'Food & Dining',

  // Transport & Commute
  angkas: 'Transport & Commute',
  grab: 'Transport & Commute',
  joyride: 'Transport & Commute',
  moveit: 'Transport & Commute',
  taxi: 'Transport & Commute',
  mrt: 'Transport & Commute',
  lrt: 'Transport & Commute',
  gas: 'Transport & Commute',
  gasoline: 'Transport & Commute',
  petron: 'Transport & Commute',
  shell: 'Transport & Commute',
  caltex: 'Transport & Commute',
  toll: 'Transport & Commute',
  rfid: 'Transport & Commute',
  easytrip: 'Transport & Commute',
  autosweep: 'Transport & Commute',
  jeep: 'Transport & Commute',
  jeepney: 'Transport & Commute',
  trike: 'Transport & Commute',
  tricycle: 'Transport & Commute',
  bus: 'Transport & Commute',
  pamasahe: 'Transport & Commute',
  commute: 'Transport & Commute',
  parking: 'Transport & Commute',

  // Groceries & Market
  puregold: 'Groceries',
  sm: 'Groceries',
  supermarket: 'Groceries',
  robinsons: 'Groceries',
  grocery: 'Groceries',
  palengke: 'Groceries',
  waltermart: 'Groceries',
  landmark: 'Groceries',
  dali: 'Groceries',
  oave: 'Groceries',
  pantry: 'Groceries',
  bigas: 'Groceries',
  ulam: 'Groceries',

  // Bills & Utilities
  meralco: 'Bills & Utilities',
  kuryente: 'Bills & Utilities',
  maynilad: 'Bills & Utilities',
  manilawater: 'Bills & Utilities',
  tubig: 'Bills & Utilities',
  pldt: 'Bills & Utilities',
  converge: 'Bills & Utilities',
  globe: 'Bills & Utilities',
  smart: 'Bills & Utilities',
  dito: 'Bills & Utilities',
  load: 'Bills & Utilities',
  postpaid: 'Bills & Utilities',
  netflix: 'Bills & Utilities',
  spotify: 'Bills & Utilities',
  icloud: 'Bills & Utilities',
  youtube: 'Bills & Utilities',
  rent: 'Housing & Rent',
  upa: 'Housing & Rent',
  condo: 'Housing & Rent',
  wifi: 'Bills & Utilities',

  // Shopping & E-commerce
  shopee: 'Shopping & Personal',
  lazada: 'Shopping & Personal',
  tiktok: 'Shopping & Personal',
  budol: 'Shopping & Personal',
  uniqlo: 'Shopping & Personal',
  zara: 'Shopping & Personal',
  'h&m': 'Shopping & Personal',
  clothes: 'Shopping & Personal',
  damit: 'Shopping & Personal',
  watsons: 'Health & Medical',
  mercury: 'Health & Medical',
  generika: 'Health & Medical',
  gamot: 'Health & Medical',
  meds: 'Health & Medical',
  doctor: 'Health & Medical',

  // Family Support & Remittance (Padala)
  padala: 'Family Support & Remittance',
  remit: 'Family Support & Remittance',
  palawan: 'Family Support & Remittance',
  cebuana: 'Family Support & Remittance',
  lbc: 'Family Support & Remittance',
  allowance: 'Family Support & Remittance',
  baon: 'Family Support & Remittance',
  tuition: 'Family Support & Remittance',
  tulong: 'Family Support & Remittance',

  // Debt & Installments
  utang: 'Debt & Loan Servicing',
  bayad: 'Debt & Loan Servicing',
  hulog: 'Debt & Loan Servicing',
  spaylater: 'Debt & Loan Servicing',
  lazpaylater: 'Debt & Loan Servicing',
  homecredit: 'Debt & Loan Servicing',
  ggives: 'Debt & Loan Servicing',
  gcredit: 'Debt & Loan Servicing',
  loan: 'Debt & Loan Servicing',

  // Salary & Inflows
  sweldo: 'Salary & Compensation',
  salary: 'Salary & Compensation',
  sahod: 'Salary & Compensation',
  payroll: 'Salary & Compensation',
  bonus: 'Salary & Compensation',
  thirteenth: 'Salary & Compensation',
  '13th': 'Salary & Compensation',
  pamasko: 'Other Income',
  tip: 'Other Income',

  // Investments & MP2
  mp2: 'Investment & Passive Income',
  pagibig: 'Investment & Passive Income',
  seabank: 'Investment & Passive Income',
  gotyme: 'Investment & Passive Income',
  stocks: 'Investment & Passive Income',
  dividend: 'Investment & Passive Income',
  interest: 'Investment & Passive Income',

  // Business & Side Hustle
  client: 'Business Revenue',
  retainer: 'Business Revenue',
  benta: 'Business Revenue',
  resell: 'Side-hustle & Gig Income',
  gig: 'Side-hustle & Gig Income',
  upwork: 'Side-hustle & Gig Income',
  freelance: 'Side-hustle & Gig Income',

  // Household Ambag
  ambag: 'Bills & Utilities',
  ambagan: 'Bills & Utilities',
  share: 'Bills & Utilities',
  hati: 'Bills & Utilities',
};

export function parseFastLog(input: string): FastLogParsed {
  const trimmed = input.trim();
  if (!trimmed) {
    return {
      isValid: false,
      type: 'expense',
      amount: 0,
      merchant: '',
      category: 'Food & Dining',
      displayPreview: '',
    };
  }

  // Look for number patterns (supports 250, 250.50, 2,500, etc.)
  const numberRegex = /(?:₱|\b)(\d+(?:,\d{3})*(?:\.\d{1,2})?)\b/;
  const numberMatch = trimmed.match(numberRegex);

  let amount = 0;
  let remainingText = trimmed;

  if (numberMatch) {
    const rawNumber = numberMatch[1].replace(/,/g, '');
    amount = parseFloat(rawNumber);
    remainingText = trimmed.replace(numberMatch[0], '').trim();
  }

  // Extract account hints
  let suggestedAccountKind: 'cash' | 'gcash' | 'maya' | 'bank' | 'credit' | undefined;
  if (/\b(gcash|gc)\b/i.test(remainingText)) {
    suggestedAccountKind = 'gcash';
    remainingText = remainingText.replace(/\b(gcash|gc)\b/gi, '').trim();
  } else if (/\b(maya|paymaya)\b/i.test(remainingText)) {
    suggestedAccountKind = 'maya';
    remainingText = remainingText.replace(/\b(maya|paymaya)\b/gi, '').trim();
  } else if (/\b(cash|barya|alkansya|wallet)\b/i.test(remainingText)) {
    suggestedAccountKind = 'cash';
    remainingText = remainingText.replace(/\b(cash|barya|alkansya|wallet)\b/gi, '').trim();
  } else if (/\b(bpi|bdo|ub|unionbank|seabank|gotyme|metrobank|bank)\b/i.test(remainingText)) {
    suggestedAccountKind = 'bank';
  } else if (/\b(spaylater|lazpaylater|homecredit|cc|card)\b/i.test(remainingText)) {
    suggestedAccountKind = 'credit';
  }

  // Extract Person hint ("kay nanay", "ni kuya", "for mama")
  let person: string | undefined;
  const personMatch = remainingText.match(/(?:kay|ni|to|for)\s+([a-zA-Z]+)/i);
  if (personMatch) {
    person = personMatch[1].charAt(0).toUpperCase() + personMatch[1].slice(1);
  }

  // Clean remaining words
  const words = remainingText
    .toLowerCase()
    .replace(/[^\w\s]/gi, '')
    .split(/\s+/)
    .filter(Boolean);

  let type: TransactionType = 'expense';
  let category = 'Food & Dining';
  let suggestedProfile: ProfileEntity = 'personal';

  // Check type keywords
  if (
    words.some((w) =>
      ['sweldo', 'salary', 'sahod', 'income', 'bonus', 'freelance', 'client', '13th', 'thirteenth', 'benta', 'payout'].includes(w)
    )
  ) {
    type = 'income';
    category = 'Salary & Compensation';
    if (words.some((w) => ['client', 'benta', 'retainer', 'upwork', 'freelance'].includes(w))) {
      suggestedProfile = 'business';
      category = 'Business Revenue';
    }
  } else if (words.some((w) => ['transfer', 'lipat', 'send', 'move'].includes(w))) {
    type = 'transfer';
    category = 'Transfer';
  } else if (words.some((w) => ['ambag', 'ambagan', 'kuryente', 'tubig', 'pambahay'].includes(w))) {
    suggestedProfile = 'household';
  }

  // Check for category keywords
  for (const word of words) {
    if (CATEGORY_KEYWORDS[word]) {
      category = CATEGORY_KEYWORDS[word];
      break;
    }
  }

  // Merchant / Label formatting
  const merchant = remainingText
    ? remainingText
        .split(' ')
        .filter((w) => w.length > 0)
        .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
        .join(' ')
    : 'Quick Entry';

  const typeLabel = type === 'expense' ? 'Expense' : type === 'income' ? 'Income' : 'Transfer';
  const displayPreview =
    amount > 0
      ? `Got it: ${typeLabel} · ₱${amount.toLocaleString('en-PH', {
          minimumFractionDigits: 2,
        })} · ${merchant} · ${category}${person ? ` (${person})` : ''}`
      : `Type Taglish entry (e.g. "padala kay nanay 8000 palawan" or "jollibee 250 gcash")`;

  return {
    isValid: amount > 0,
    type,
    amount,
    merchant,
    category,
    person,
    suggestedAccountKind,
    suggestedProfile,
    displayPreview,
  };
}
