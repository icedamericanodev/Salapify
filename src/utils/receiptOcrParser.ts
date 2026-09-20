import { Account } from '../types';

export interface ReceiptLineItem {
  desc: string;
  qty: number;
  price: number;
}

export interface ReceiptOcrResult {
  merchant: string;
  amount: number;
  date: string; // YYYY-MM-DD
  category: string;
  subcategory: string;
  suggestedAccountId?: string;
  taxTinOrRef?: string;
  isTaxDeductible: boolean;
  vatAmount?: number;
  confidence: number;
  lineItems: ReceiptLineItem[];
  rawText: string;
  detectedType: 'official_receipt' | 'grocery_slip' | 'ewallet_screenshot' | 'pos_thermal';
}

export interface ReceiptPreset {
  id: string;
  title: string;
  subtitle: string;
  badge: string;
  imageThumbnail: string; // CSS style or SVG representation
  sampleText: string;
}

export const PRESET_PHILIPPINE_RECEIPTS: ReceiptPreset[] = [
  {
    id: 'jollibee',
    title: 'Jollibee Food Corp.',
    subtitle: 'Official Receipt (TIN Registered)',
    badge: 'Food & Dining',
    imageThumbnail: 'bg-red-700 text-amber-300',
    sampleText: `JOLLIBEE BGC 32ND ST
Jollibee Foods Corp.
TIN: 000-388-123-00000 VAT Reg
Date: 2026-09-20 12:45
OR No: 892341
1 2-PC CHICKENJOY MEAL 245.00
1 PEACH MANGO PIE 55.00
SUBTOTAL: 300.00
VAT 12%: 32.14
TOTAL AMOUNT DUE: PHP 300.00
PAID VIA MAYA: 300.00
CHANGE: 0.00
THIS SERVES AS AN OFFICIAL RECEIPT`,
  },
  {
    id: 'puregold',
    title: 'Puregold Price Club',
    subtitle: 'Grocery Thermal Slip',
    badge: 'Groceries',
    imageThumbnail: 'bg-emerald-800 text-yellow-300',
    sampleText: `PUREGOLD PRICE CLUB INC.
SHAW BLVD BRANCH
TIN: 004-744-221-000
Date: 2026-09-19 16:20
SI#: PG-99214
1 DINORADO RICE 5KG 285.00
2 FRESH EGGS DOZEN 190.00
4 SAN MARINO CORNED TUNA 180.00
2 FRESH MILK 1L 220.00
SUBTOTAL: 875.00
TOTAL SALE: ₱875.00
PAID VIA GCASH: 875.00
ITEMS COUNT: 9
VAT EXEMPT: 285.00
VATABLE: 590.00`,
  },
  {
    id: 'seven_eleven',
    title: '7-Eleven Store',
    subtitle: 'City Blends Coffee & Hotdog',
    badge: 'Convenience',
    imageThumbnail: 'bg-orange-600 text-white',
    sampleText: `PHILIPPINE SEVEN CORP
7-ELEVEN STORE #1042 BGC
Date: 2026-09-20 08:15
1 CITY BLENDS LARGE 55.00
1 BIG BITE HOTDOG 45.00
TOTAL PHP 100.00
CASH 100.00
CHANGE 0.00
THANK YOU COME AGAIN`,
  },
  {
    id: 'gcash_send',
    title: 'GCash Express Send',
    subtitle: 'Payment to Delivery Partner',
    badge: 'E-Wallet',
    imageThumbnail: 'bg-blue-600 text-white',
    sampleText: `GCash Express Send
Successfully Sent!
Amount: PHP 450.00
To: JOLLIBEE DELIVERY
Mobile: 0917-888-2345
Ref. No. 100234567891
Date: Sep 20, 2026 1:15 PM`,
  },
  {
    id: 'grab_maya',
    title: 'GrabCar via Maya',
    subtitle: 'Ride-Hailing Digital Receipt',
    badge: 'Transport',
    imageThumbnail: 'bg-emerald-600 text-white',
    sampleText: `Grab Philippines
Ride Receipt
Paid to: GRABCAR 4-SEATER
Total Amount: PHP 385.00
Payment Method: Maya Card *1234
Ref ID: MY-882910
Date: 20 Sep 2026 09:30 AM`,
  },
  {
    id: 'mercury_drug',
    title: 'Mercury Drug Corp.',
    subtitle: 'Pharmacy / Health Official Receipt',
    badge: 'Healthcare',
    imageThumbnail: 'bg-rose-700 text-white',
    sampleText: `MERCURY DRUG CORP
MAKATI AVENUE BRANCH
TIN: 000-112-998-000
Date: 2026-09-18 19:40
OR# 459102
1 BIOGESIC 500MG 10S 85.00
1 ASCORBIC ACID 100S 350.00
SUBTOTAL: 435.00
TOTAL AMOUNT DUE: PHP 435.00
BPI DEBIT: 435.00
OFFICIAL RECEIPT`,
  },
];

/**
 * Extracts vendor name, category, and subcategory from raw receipt text
 */
function extractMerchantAndCategory(text: string): {
  merchant: string;
  category: string;
  subcategory: string;
} {
  const lower = text.toLowerCase();

  if (lower.includes('jollibee')) {
    return { merchant: 'Jollibee', category: 'Food & Dining', subcategory: 'Fast Food' };
  }
  if (lower.includes('mcdonald') || lower.includes('mcdo')) {
    return { merchant: "McDonald's", category: 'Food & Dining', subcategory: 'Fast Food' };
  }
  if (lower.includes('starbucks')) {
    return { merchant: 'Starbucks', category: 'Food & Dining', subcategory: 'Coffee & Snacks' };
  }
  if (lower.includes('7-eleven') || lower.includes('philippine seven')) {
    return { merchant: '7-Eleven', category: 'Food & Dining', subcategory: 'Convenience' };
  }
  if (lower.includes('puregold')) {
    return { merchant: 'Puregold', category: 'Groceries', subcategory: 'Supermarket' };
  }
  if (lower.includes('sm supermarket') || lower.includes('sm hypermarket') || lower.includes('savemore')) {
    return { merchant: 'SM Supermarket', category: 'Groceries', subcategory: 'Supermarket' };
  }
  if (lower.includes('robinsons supermarket')) {
    return { merchant: 'Robinsons Supermarket', category: 'Groceries', subcategory: 'Supermarket' };
  }
  if (lower.includes('mercury drug')) {
    return { merchant: 'Mercury Drug', category: 'Healthcare', subcategory: 'Medicine' };
  }
  if (lower.includes('watsons')) {
    return { merchant: 'Watsons', category: 'Healthcare', subcategory: 'Personal Care' };
  }
  if (lower.includes('grab')) {
    if (lower.includes('food') || lower.includes('mart')) {
      return { merchant: 'GrabFood', category: 'Food & Dining', subcategory: 'Delivery' };
    }
    return { merchant: 'GrabCar', category: 'Transportation', subcategory: 'Ride Hailing' };
  }
  if (lower.includes('shopee')) {
    return { merchant: 'Shopee', category: 'Shopping', subcategory: 'Online Shopping' };
  }
  if (lower.includes('lazada')) {
    return { merchant: 'Lazada', category: 'Shopping', subcategory: 'Online Shopping' };
  }
  if (lower.includes('meralco')) {
    return { merchant: 'Meralco', category: 'Bills & Utilities', subcategory: 'Electricity' };
  }
  if (lower.includes('manila water') || lower.includes('maynilad')) {
    return { merchant: 'Water Utility', category: 'Bills & Utilities', subcategory: 'Water' };
  }
  if (lower.includes('pldt') || lower.includes('converge') || lower.includes('globe')) {
    return { merchant: 'Internet / Telco', category: 'Bills & Utilities', subcategory: 'Internet' };
  }
  if (lower.includes('petron') || lower.includes('shell') || lower.includes('caltex')) {
    return { merchant: 'Gas Station', category: 'Transportation', subcategory: 'Fuel' };
  }

  // Fallback: take the first non-empty line as merchant name
  const lines = text.split('\n').map((l) => l.trim()).filter((l) => l.length > 0);
  const firstLine = lines[0] || 'Store Receipt';
  const cleanFirstLine = firstLine.slice(0, 30);

  return { merchant: cleanFirstLine, category: 'Food & Dining', subcategory: 'General' };
}

/**
 * Extracts total amount from text, prioritizing explicit "Total Amount Due" or "Total" rows
 * while ignoring subtotal, VAT, cash rendered, and change.
 */
function extractTotalAmount(text: string): number {
  const lines = text.split('\n');

  // Priority 1: Check lines explicitly indicating Total Due or Total
  const totalKeywords = [
    /total\s*(?:amount\s*due|sale|amount)?\s*[:=]?\s*(?:php|₱|p)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)/i,
    /(?:amount|paid)\s*[:=]?\s*(?:php|₱|p)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)/i,
    /(?:php|₱|p)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)\s*total/i,
  ];

  for (const line of lines) {
    // Skip subtotal or change lines
    if (/subtotal|change|sukli|vat\s*12|cash\s*tendered/i.test(line)) continue;

    for (const regex of totalKeywords) {
      const match = line.match(regex);
      if (match && match[1]) {
        const amt = parseFloat(match[1].replace(/,/g, ''));
        if (amt > 0 && !isNaN(amt)) {
          return amt;
        }
      }
    }
  }

  // Priority 2: General match for any PHP or ₱ amount
  const generalRegex = /(?:php|₱|p)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)/gi;
  let matches: number[] = [];
  let m;
  while ((m = generalRegex.exec(text)) !== null) {
    if (m[1]) {
      const parsed = parseFloat(m[1].replace(/,/g, ''));
      if (parsed > 0) matches.push(parsed);
    }
  }

  if (matches.length > 0) {
    // Often the largest amount in the receipt is the grand total
    return Math.max(...matches);
  }

  return 0;
}

/**
 * Extracts transaction date or falls back to today's date in YYYY-MM-DD format
 */
function extractDate(text: string): string {
  const todayStr = new Date().toISOString().split('T')[0];

  // Look for YYYY-MM-DD
  const isoMatch = text.match(/\b(202[0-9])-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])\b/);
  if (isoMatch) return `${isoMatch[1]}-${isoMatch[2]}-${isoMatch[3]}`;

  // Look for DD/MM/YYYY or DD-MM-YYYY
  const dmyMatch = text.match(/\b(0[1-9]|[12][0-9]|3[01])[\/\-](0[1-9]|1[0-2])[\/\-](202[0-9])\b/);
  if (dmyMatch) return `${dmyMatch[3]}-${dmyMatch[2]}-${dmyMatch[1]}`;

  // Look for "Sep 20, 2026" or "20 Sep 2026"
  const monthNames: Record<string, string> = {
    jan: '01', feb: '02', mar: '03', apr: '04', may: '05', jun: '06',
    jul: '07', aug: '08', sep: '09', oct: '10', nov: '11', dec: '12',
  };

  const textDateMatch = text.match(/\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+([0-9]{1,2})(?:st|nd|rd|th)?,?\s+(202[0-9])\b/i);
  if (textDateMatch) {
    const month = monthNames[textDateMatch[1].toLowerCase().slice(0, 3)] || '09';
    const day = textDateMatch[2].padStart(2, '0');
    const year = textDateMatch[3];
    return `${year}-${month}-${day}`;
  }

  const dmyTextMatch = text.match(/\b([0-9]{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*,?\s+(202[0-9])\b/i);
  if (dmyTextMatch) {
    const day = dmyTextMatch[1].padStart(2, '0');
    const month = monthNames[dmyTextMatch[2].toLowerCase().slice(0, 3)] || '09';
    const year = dmyTextMatch[3];
    return `${year}-${month}-${day}`;
  }

  return todayStr;
}

/**
 * Parses line items (quantity, item description, price)
 */
function extractLineItems(text: string): ReceiptLineItem[] {
  const lines = text.split('\n');
  const items: ReceiptLineItem[] = [];

  // Match pattern like: "1 2-PC CHICKENJOY MEAL 245.00" or "2 FRESH EGGS 190.00"
  const itemRegex = /^\s*([0-9]+)\s+([A-Z0-9\s\-\.\/]+?)\s+([0-9]+(?:\.[0-9]{2})?)\s*$/i;

  for (const line of lines) {
    const trimmed = line.trim();
    // Skip headers and totals
    if (/total|subtotal|vat|tin|change|sukli|paid|date|receipt|cash/i.test(trimmed)) continue;

    const match = trimmed.match(itemRegex);
    if (match) {
      const qty = parseInt(match[1], 10) || 1;
      const desc = match[2].trim();
      const price = parseFloat(match[3]) || 0;
      if (price > 0 && desc.length > 2) {
        items.push({ desc, qty, price });
      }
    }
  }

  return items;
}

/**
 * Main Receipt & Screenshot OCR Parser Engine
 */
export function parseReceiptOcr(text: string, accounts: Account[] = []): ReceiptOcrResult {
  const raw = (text || '').trim();
  const lower = raw.toLowerCase();

  // 1. Identify Merchant & Categories
  const { merchant, category, subcategory } = extractMerchantAndCategory(raw);

  // 2. Extract Total Amount
  const amount = extractTotalAmount(raw);

  // 3. Extract Date
  const date = extractDate(raw);

  // 4. Line items
  const lineItems = extractLineItems(raw);

  // 5. Detect Tax Deductibility & BIR Official Receipt markers
  const isTaxDeductible =
    lower.includes('tin:') ||
    lower.includes('official receipt') ||
    lower.includes('vat reg') ||
    lower.includes('sales invoice') ||
    lower.includes('bir permit');

  // Extract TIN or OR / Ref number
  let taxTinOrRef: string | undefined;
  const tinMatch = raw.match(/TIN\s*[:#]?\s*([0-9]{3}[-\s]?[0-9]{3}[-\s]?[0-9]{3}[-\s]?[0-9]{3,5})/i);
  if (tinMatch && tinMatch[1]) {
    taxTinOrRef = `TIN: ${tinMatch[1].replace(/\s+/g, '-')}`;
  } else {
    const orMatch = raw.match(/(?:OR\s*No|SI#|OR#|Ref\.?\s*No|Ref\s*ID)\s*[:#]?\s*([A-Za-z0-9\-]+)/i);
    if (orMatch && orMatch[1]) {
      taxTinOrRef = orMatch[1];
    }
  }

  // 6. Detect Receipt Type
  let detectedType: ReceiptOcrResult['detectedType'] = 'pos_thermal';
  if (lower.includes('official receipt') || lower.includes('vat reg')) {
    detectedType = 'official_receipt';
  } else if (lower.includes('supermarket') || lower.includes('grocery') || lower.includes('items count')) {
    detectedType = 'grocery_slip';
  } else if (lower.includes('successfully sent') || lower.includes('payment successful') || lower.includes('express send')) {
    detectedType = 'ewallet_screenshot';
  }

  // 7. Account matching
  let suggestedAccountId: string | undefined;
  if (accounts.length > 0) {
    if (lower.includes('gcash')) {
      const gcashAcc = accounts.find((a) => a.kind === 'gcash' || a.name.toLowerCase().includes('gcash'));
      if (gcashAcc) suggestedAccountId = gcashAcc.id;
    } else if (lower.includes('maya')) {
      const mayaAcc = accounts.find((a) => a.kind === 'maya' || a.name.toLowerCase().includes('maya'));
      if (mayaAcc) suggestedAccountId = mayaAcc.id;
    } else if (lower.includes('bpi')) {
      const bpiAcc = accounts.find((a) => a.name.toLowerCase().includes('bpi') || a.institution.toLowerCase().includes('bpi'));
      if (bpiAcc) suggestedAccountId = bpiAcc.id;
    } else if (lower.includes('bdo')) {
      const bdoAcc = accounts.find((a) => a.name.toLowerCase().includes('bdo') || a.institution.toLowerCase().includes('bdo'));
      if (bdoAcc) suggestedAccountId = bdoAcc.id;
    }

    // Default to first account if none matched
    if (!suggestedAccountId) {
      suggestedAccountId = accounts[0].id;
    }
  }

  // Calculate simulated confidence
  let confidence = 88;
  if (amount > 0) confidence += 5;
  if (merchant && merchant !== 'Store Receipt') confidence += 4;
  if (taxTinOrRef) confidence += 2;

  return {
    merchant,
    amount: Math.max(0, amount),
    date,
    category,
    subcategory,
    suggestedAccountId,
    taxTinOrRef,
    isTaxDeductible,
    confidence: Math.min(99, confidence),
    lineItems,
    rawText: raw,
    detectedType,
  };
}
