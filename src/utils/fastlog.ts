import { TransactionType } from '../types';

export interface FastLogParsed {
  isValid: boolean;
  type: TransactionType;
  amount: number;
  merchant: string;
  category: string;
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
  snack: 'Food & Dining',
  food: 'Food & Dining',
  samgyup: 'Food & Dining',
  milktea: 'Food & Dining',
  boba: 'Food & Dining',

  // Transport
  angkas: 'Transport',
  grab: 'Transport',
  joyride: 'Transport',
  taxi: 'Transport',
  mrt: 'Transport',
  lrt: 'Transport',
  gas: 'Transport',
  gasoline: 'Transport',
  toll: 'Transport',
  jeep: 'Transport',
  commute: 'Transport',

  // Groceries
  puregold: 'Groceries',
  sm: 'Groceries',
  supermarket: 'Groceries',
  robinsons: 'Groceries',
  grocery: 'Groceries',
  palengke: 'Groceries',
  waltermart: 'Groceries',

  // Bills & Utilities
  meralco: 'Bills & Utilities',
  maynilad: 'Bills & Utilities',
  manilawater: 'Bills & Utilities',
  pldt: 'Bills & Utilities',
  converge: 'Bills & Utilities',
  globe: 'Bills & Utilities',
  smart: 'Bills & Utilities',
  netflix: 'Bills & Utilities',
  spotify: 'Bills & Utilities',
  rent: 'Bills & Utilities',
  kuryente: 'Bills & Utilities',
  tubig: 'Bills & Utilities',
  wifi: 'Bills & Utilities',

  // Shopping
  shopee: 'Shopping',
  lazada: 'Shopping',
  tiktok: 'Shopping',
  uniqlo: 'Shopping',
  zara: 'Shopping',
  clothes: 'Shopping',

  // Health
  mercury: 'Health & Meds',
  watsons: 'Health & Meds',
  generika: 'Health & Meds',
  meds: 'Health & Meds',
  doctor: 'Health & Meds',

  // Salary / Income
  sweldo: 'Salary',
  salary: 'Salary',
  sahod: 'Salary',
  payroll: 'Salary',
  freelance: 'Other',
  bonus: 'Other',

  // Debt Payment
  utang: 'Debt Payment',
  bayad: 'Debt Payment',
  paid: 'Debt Payment',
  homecredit: 'Debt Payment',
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

  // Clean remaining text
  const words = remainingText
    .toLowerCase()
    .replace(/[^\w\s]/gi, '')
    .split(/\s+/)
    .filter(Boolean);

  let type: TransactionType = 'expense';
  let category = 'Food & Dining';

  // Check type keywords
  if (words.some((w) => ['sweldo', 'salary', 'sahod', 'income', 'bonus', 'freelance', 'client'].includes(w))) {
    type = 'income';
    category = 'Salary';
  } else if (words.some((w) => ['transfer', 'lipat', 'send', 'move'].includes(w))) {
    type = 'transfer';
    category = 'Transfer';
  } else if (words.some((w) => ['utang', 'bayad', 'paid', 'loan', 'homecredit'].includes(w))) {
    type = 'expense';
    category = 'Debt Payment';
  }

  // Check for category keywords
  for (const word of words) {
    if (CATEGORY_KEYWORDS[word]) {
      category = CATEGORY_KEYWORDS[word];
      break;
    }
  }

  // Merchant / Label capitalizing
  const merchant = remainingText
    ? remainingText
        .split(' ')
        .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
        .join(' ')
    : 'Quick Entry';

  const typeLabel = type === 'expense' ? 'Expense' : type === 'income' ? 'Income' : 'Transfer';
  const displayPreview = amount > 0 
    ? `Got it: ${typeLabel} · ₱${amount.toLocaleString('en-PH', { minimumFractionDigits: 2 })} · ${merchant} · ${category}`
    : `Type a description and amount (e.g. "jollibee 250")`;

  return {
    isValid: amount > 0,
    type,
    amount,
    merchant,
    category,
    displayPreview,
  };
}
