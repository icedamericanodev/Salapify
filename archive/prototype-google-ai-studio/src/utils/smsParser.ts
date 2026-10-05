import { Account } from '../types';

export interface ParsedSmsResult {
  amount: number;
  merchant: string;
  category: string;
  subcategory?: string;
  suggestedAccountId?: string;
  refNumber?: string;
  rawText: string;
  sourceType: 'gcash' | 'maya' | 'bpi' | 'bdo' | 'unionbank' | 'generic';
}

/**
 * Parses SMS and notification receipts from Philippine banks & e-wallets.
 * Supports:
 * - GCash: "You have sent PHP 450.00 of GCash to JOLLIBEE 09171234567 on 09-20-26 12:30. Ref. No. 100234567891."
 * - Maya: "You paid PHP 350.00 to Grab Philippines using your Maya card ending in 1234 on Sep 20. Ref: 987654."
 * - BPI: "Thank you for using your BPI Card ending in 5678 for PHP 850.00 at STARBUCKS BGC on 20-Sep-26."
 * - BDO: "Your BDO Debit Card ... was used at MC DONALDS for PHP 220.00 on 20/09/2026."
 * - UnionBank: "UB: An amount of PHP 1,500.00 was transferred from your account..."
 */
export function parsePhilippineSmsReceipt(
  text: string,
  accounts: Account[] = []
): ParsedSmsResult | null {
  if (!text || text.trim().length < 5) return null;

  const raw = text.trim();
  const lower = raw.toLowerCase();

  // 1. Extract Amount
  // Matches: PHP 450.00, PHP450, P450.50, ₱450, 450.00 php
  let amount = 0;
  const amountRegex = /(?:php|₱|p)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)/i;
  const amountMatch = raw.match(amountRegex);

  if (amountMatch && amountMatch[1]) {
    amount = parseFloat(amountMatch[1].replace(/,/g, ''));
  } else {
    // Fallback: look for pure numbers followed by 'pesos' or 'php'
    const fallbackRegex = /([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)\s*(?:pesos?|php)/i;
    const fallbackMatch = raw.match(fallbackRegex);
    if (fallbackMatch && fallbackMatch[1]) {
      amount = parseFloat(fallbackMatch[1].replace(/,/g, ''));
    }
  }

  if (amount <= 0 || isNaN(amount)) return null;

  // 2. Identify Source Institution / Account
  let sourceType: ParsedSmsResult['sourceType'] = 'generic';
  if (lower.includes('gcash')) {
    sourceType = 'gcash';
  } else if (lower.includes('maya') || lower.includes('paymaya')) {
    sourceType = 'maya';
  } else if (lower.includes('bpi')) {
    sourceType = 'bpi';
  } else if (lower.includes('bdo')) {
    sourceType = 'bdo';
  } else if (lower.includes('unionbank') || lower.includes('ub:')) {
    sourceType = 'unionbank';
  }

  // Find matching account id in user accounts
  let suggestedAccountId: string | undefined = undefined;
  if (accounts.length > 0) {
    const match = accounts.find((acc) => {
      const name = acc.name.toLowerCase();
      const inst = (acc.institution || '').toLowerCase();
      if (sourceType === 'gcash' && (name.includes('gcash') || inst.includes('gcash'))) return true;
      if (sourceType === 'maya' && (name.includes('maya') || inst.includes('maya'))) return true;
      if (sourceType === 'bpi' && (name.includes('bpi') || inst.includes('bpi'))) return true;
      if (sourceType === 'bdo' && (name.includes('bdo') || inst.includes('bdo'))) return true;
      if (sourceType === 'unionbank' && (name.includes('union') || inst.includes('union'))) return true;
      return false;
    });
    if (match) {
      suggestedAccountId = match.id;
    } else {
      suggestedAccountId = accounts[0].id;
    }
  }

  // 3. Extract Reference Number
  let refNumber: string | undefined = undefined;
  const refRegex = /(?:ref(?:erence)?\.?\s*(?:no\.?|number)?|trace|trace no\.?)\s*[:#]?\s*([a-zA-Z0-9_-]{5,})/i;
  const refMatch = raw.match(refRegex);
  if (refMatch && refMatch[1]) {
    refNumber = refMatch[1];
  }

  // 4. Extract Merchant Name & Category
  let merchant = 'Merchant';
  let category = 'Food & Dining';
  let subcategory: string | undefined = undefined;

  // Merchant detection patterns
  if (lower.includes('jollibee')) {
    merchant = 'Jollibee';
    category = 'Food & Dining';
    subcategory = 'Fast Food';
  } else if (lower.includes('mc donald') || lower.includes('mcdonalds') || lower.includes('mcdo')) {
    merchant = "McDonald's";
    category = 'Food & Dining';
    subcategory = 'Fast Food';
  } else if (lower.includes('starbucks')) {
    merchant = 'Starbucks';
    category = 'Food & Dining';
    subcategory = 'Coffee';
  } else if (lower.includes('grab')) {
    merchant = 'Grab';
    category = 'Transportation';
    subcategory = 'Ride Hailing';
  } else if (lower.includes('angkas') || lower.includes('joyride')) {
    merchant = lower.includes('angkas') ? 'Angkas' : 'JoyRide';
    category = 'Transportation';
    subcategory = 'Ride Hailing';
  } else if (lower.includes('meralco')) {
    merchant = 'Meralco';
    category = 'Bills & Utilities';
    subcategory = 'Electricity';
  } else if (lower.includes('maynilad') || lower.includes('manila water')) {
    merchant = lower.includes('maynilad') ? 'Maynilad' : 'Manila Water';
    category = 'Bills & Utilities';
    subcategory = 'Water';
  } else if (lower.includes('pldt') || lower.includes('converge') || lower.includes('globe')) {
    merchant = lower.includes('pldt') ? 'PLDT' : lower.includes('converge') ? 'Converge' : 'Globe Telecom';
    category = 'Bills & Utilities';
    subcategory = 'Internet';
  } else if (lower.includes('shopee')) {
    merchant = 'Shopee';
    category = 'Shopping';
    subcategory = 'Online';
  } else if (lower.includes('lazada')) {
    merchant = 'Lazada';
    category = 'Shopping';
    subcategory = 'Online';
  } else if (lower.includes('sm super') || lower.includes('sm store') || lower.includes('sm hyper')) {
    merchant = 'SM Store / Supermarket';
    category = 'Groceries';
    subcategory = 'Supermarket';
  } else if (lower.includes('puregold')) {
    merchant = 'Puregold';
    category = 'Groceries';
    subcategory = 'Supermarket';
  } else {
    // Generic extraction: look for "to [Merchant]" or "at [Merchant]"
    const toAtMatch = raw.match(/(?:to|at)\s+([A-Z0-9\s&'-]{3,24}?)(?:\s+(?:on|using|via|with|for|\d))/i);
    if (toAtMatch && toAtMatch[1]) {
      const candidate = toAtMatch[1].trim();
      if (!candidate.toLowerCase().includes('php') && !candidate.toLowerCase().includes('gcash') && !candidate.toLowerCase().includes('card')) {
        merchant = candidate;
      }
    }
  }

  return {
    amount,
    merchant,
    category,
    subcategory,
    suggestedAccountId,
    refNumber,
    rawText: raw,
    sourceType,
  };
}
