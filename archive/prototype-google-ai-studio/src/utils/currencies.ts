import { CurrencyCode } from '../types';

export interface CurrencyOption {
  code: CurrencyCode;
  symbol: string;
  name: string;
}

export const SUPPORTED_CURRENCIES: CurrencyOption[] = [
  { code: 'PHP', symbol: '₱', name: 'Philippine Peso' },
  { code: 'USD', symbol: '$', name: 'US Dollar' },
  { code: 'EUR', symbol: '€', name: 'Euro' },
  { code: 'JPY', symbol: '¥', name: 'Japanese Yen' },
  { code: 'SGD', symbol: 'S$', name: 'Singapore Dollar' },
];

export const CURRENCY_SYMBOLS: Record<CurrencyCode, string> = {
  PHP: '₱',
  USD: '$',
  EUR: '€',
  JPY: '¥',
  SGD: 'S$',
};

export const CURRENCY_NAMES: Record<CurrencyCode, string> = {
  PHP: 'Philippine Peso (PHP)',
  USD: 'US Dollar (USD)',
  EUR: 'Euro (EUR)',
  JPY: 'Japanese Yen (JPY)',
  SGD: 'Singapore Dollar (SGD)',
};

// Fixed indicative exchange rates relative to PHP base (1 unit = X PHP)
export const EXCHANGE_RATES_TO_PHP: Record<CurrencyCode, number> = {
  PHP: 1.0,
  USD: 58.50,
  EUR: 63.80,
  JPY: 0.385,
  SGD: 44.20,
};

export function convertToPhp(amount: number, currency: CurrencyCode = 'PHP'): number {
  const rate = EXCHANGE_RATES_TO_PHP[currency] || 1.0;
  return amount * rate;
}

export function formatCurrency(
  amount: number,
  currency: CurrencyCode = 'PHP',
  includeDecimals: boolean = true
): string {
  const symbol = CURRENCY_SYMBOLS[currency] || '₱';
  const formatted = Math.abs(amount).toLocaleString('en-PH', {
    minimumFractionDigits: includeDecimals ? 2 : 0,
    maximumFractionDigits: includeDecimals ? 2 : 0,
  });

  const sign = amount < 0 ? '-' : '';
  return `${sign}${symbol}${formatted}`;
}
