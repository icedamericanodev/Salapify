import {
  InvestmentAsset,
  InvestmentAssetClass,
  InvestmentRiskProfile,
  MarketDataProviderType,
  PortfolioSummary
} from '../types';

export interface ProviderPriceQuote {
  symbol: string;
  pricePhp: number;
  priceUsd?: number;
  change24hPercent?: number;
  source: string;
  asOf: string;
  licensingNotice: string;
}

export interface MarketDataProviderAdapter {
  id: MarketDataProviderType;
  name: string;
  supportedClasses: InvestmentAssetClass[];
  description: string;
  licensingNotice: string;
  fetchPriceQuote: (symbol: string, assetClass: InvestmentAssetClass) => Promise<ProviderPriceQuote>;
}

// 1. Manual / Local Offline Provider Adapter (Zero third-party network transmission)
export const ManualOfflineAdapter: MarketDataProviderAdapter = {
  id: 'manual',
  name: 'Manual / Self-Reported Valuation',
  supportedClasses: [
    'stocks',
    'bonds',
    'mutual_funds',
    'etfs',
    'crypto',
    'mp2',
    'time_deposits',
    'insurance_linked',
    'real_estate'
  ],
  description: '100% private, offline self-reported values from bank statements, passbooks, and appraisals.',
  licensingNotice: 'Self-reported personal data. No third-party data licenses required.',
  fetchPriceQuote: async (symbol: string) => {
    return {
      symbol,
      pricePhp: 1.0,
      source: 'User Manual Entry',
      asOf: new Date().toISOString(),
      licensingNotice: 'Offline user verification.'
    };
  }
};

// 2. CoinGecko Adapter (Decentralized Crypto Assets)
export const CoinGeckoAdapter: MarketDataProviderAdapter = {
  id: 'coingecko',
  name: 'CoinGecko Crypto Adapter',
  supportedClasses: ['crypto'],
  description: 'Specialized cryptocurrency market data adapter for BTC, ETH, and digital tokens.',
  licensingNotice: 'CoinGecko API data is for personal tracking only. Commercial display requires CoinGecko API Pro licensing.',
  fetchPriceQuote: async (symbol: string) => {
    // Simulated resilient adapter with offline fallback
    const sym = symbol.toUpperCase();
    const mockPrices: Record<string, number> = {
      BTC: 3950000,
      ETH: 198000,
      SOL: 8900,
      USDT: 58.5
    };
    const price = mockPrices[sym] || 1000;
    return {
      symbol: sym,
      pricePhp: price,
      priceUsd: price / 58.5,
      change24hPercent: 2.45,
      source: 'CoinGecko API (Adapter)',
      asOf: new Date().toISOString(),
      licensingNotice: 'Personal non-commercial tracking use under CoinGecko API Terms.'
    };
  }
};

// 3. Twelve Data Adapter (Global Stocks & ETFs)
export const TwelveDataAdapter: MarketDataProviderAdapter = {
  id: 'twelve_data',
  name: 'Twelve Data Global Markets Adapter',
  supportedClasses: ['stocks', 'etfs', 'mutual_funds'],
  description: 'Global equity and ETF market data provider covering international and regional exchanges.',
  licensingNotice: 'Twelve Data quotes are delayed by 15 minutes for free tiers. Commercial display requires formal redistribution licensing.',
  fetchPriceQuote: async (symbol: string) => {
    const sym = symbol.toUpperCase();
    const mockPrices: Record<string, number> = {
      FMETF: 102.50,
      SM: 915.00,
      BDO: 154.20,
      ALI: 34.50,
      TEL: 1420.00
    };
    const price = mockPrices[sym] || 100.0;
    return {
      symbol: sym,
      pricePhp: price,
      change24hPercent: 0.85,
      source: 'Twelve Data API (Adapter)',
      asOf: new Date().toISOString(),
      licensingNotice: 'Non-commercial personal reference. Subject to Twelve Data redistribution terms.'
    };
  }
};

// 4. Polygon.io Adapter (Primarily U.S. Equities & Options)
export const PolygonAdapter: MarketDataProviderAdapter = {
  id: 'polygon',
  name: 'Polygon.io U.S. Market Adapter',
  supportedClasses: ['stocks', 'etfs'],
  description: 'High-precision U.S. equity, ETF, and index feed provider.',
  licensingNotice: 'Polygon.io market feeds require separate commercial licensing agreements before public redistribution.',
  fetchPriceQuote: async (symbol: string) => {
    const sym = symbol.toUpperCase();
    const mockUsdPrices: Record<string, number> = {
      VOO: 512.0,
      QQQ: 485.0,
      AAPL: 228.0,
      NVDA: 118.0
    };
    const usdPrice = mockUsdPrices[sym] || 50.0;
    const phpPrice = usdPrice * 58.5; // Conversion at 1 USD = 58.50 PHP
    return {
      symbol: sym,
      priceUsd: usdPrice,
      pricePhp: phpPrice,
      change24hPercent: 1.15,
      source: 'Polygon.io API (Adapter)',
      asOf: new Date().toISOString(),
      licensingNotice: 'For personal private analysis only. Commercial distribution strictly prohibited without Polygon licensing.'
    };
  }
};

export const PROVIDER_ADAPTERS: Record<MarketDataProviderType, MarketDataProviderAdapter> = {
  manual: ManualOfflineAdapter,
  coingecko: CoinGeckoAdapter,
  twelve_data: TwelveDataAdapter,
  polygon: PolygonAdapter
};

export const MARKET_DATA_LICENSING_WARNING =
  'Licensing Compliance Notice: All market data displayed via external adapters (CoinGecko, Twelve Data, Polygon) is strictly for personal verification and tracking. Separate commercial licensing agreements must be reviewed and executed before publicly displaying or redistributing live market quotes.';

/**
 * Calculates comprehensive portfolio metrics including:
 * - Cost basis
 * - Dividends
 * - Unrealized gains/losses (PHP & %)
 * - Asset allocation
 * - Risk exposure
 * - Investment-to-Net-Worth ratio
 */
export function calculatePortfolioSummary(
  investments: InvestmentAsset[],
  totalNetWorth: number
): PortfolioSummary {
  let totalValuation = 0;
  let totalCostBasis = 0;
  let totalDividendsEarned = 0;
  let totalContributions = 0;
  let totalWithdrawals = 0;

  const classMap: Record<InvestmentAssetClass, number> = {
    stocks: 0,
    bonds: 0,
    mutual_funds: 0,
    etfs: 0,
    crypto: 0,
    mp2: 0,
    time_deposits: 0,
    insurance_linked: 0,
    real_estate: 0
  };

  const riskMap: Record<InvestmentRiskProfile, number> = {
    conservative: 0,
    moderate: 0,
    aggressive: 0,
    speculative: 0
  };

  investments.forEach((asset) => {
    const val = asset.currentValuation || asset.units * asset.currentPricePerUnit || 0;
    totalValuation += val;
    totalCostBasis += asset.costBasis || 0;
    totalDividendsEarned += asset.totalDividendsEarned || 0;
    totalContributions += asset.totalContributions || 0;
    totalWithdrawals += asset.totalWithdrawals || 0;

    classMap[asset.assetClass] = (classMap[asset.assetClass] || 0) + val;
    riskMap[asset.riskProfile] = (riskMap[asset.riskProfile] || 0) + val;
  });

  const totalUnrealizedGainLoss = totalValuation - totalCostBasis;
  const totalUnrealizedGainLossPercent =
    totalCostBasis > 0 ? (totalUnrealizedGainLoss / totalCostBasis) * 100 : 0;

  const assetClassLabels: Record<InvestmentAssetClass, string> = {
    stocks: 'Stocks (PSE & Global)',
    bonds: 'Bonds & RTBs',
    mutual_funds: 'Mutual Funds / UITFs',
    etfs: 'ETFs',
    crypto: 'Crypto & Digital Assets',
    mp2: 'Pag-IBIG MP2',
    time_deposits: 'Time Deposits',
    insurance_linked: 'Insurance-Linked (VUL)',
    real_estate: 'Real Estate'
  };

  const assetAllocation = (Object.keys(classMap) as InvestmentAssetClass[])
    .map((cls) => {
      const amount = classMap[cls];
      const percentage = totalValuation > 0 ? (amount / totalValuation) * 100 : 0;
      return {
        assetClass: cls,
        label: assetClassLabels[cls],
        amount,
        percentage
      };
    })
    .filter((item) => item.amount > 0 || item.percentage > 0)
    .sort((a, b) => b.amount - a.amount);

  const riskProfileLabels: Record<InvestmentRiskProfile, string> = {
    conservative: 'Conservative (Low Volatility)',
    moderate: 'Moderate (Balanced Growth)',
    aggressive: 'Aggressive (High Growth)',
    speculative: 'Speculative (High Volatility)'
  };

  const riskAllocation = (Object.keys(riskMap) as InvestmentRiskProfile[])
    .map((rp) => {
      const amount = riskMap[rp];
      const percentage = totalValuation > 0 ? (amount / totalValuation) * 100 : 0;
      return {
        riskProfile: rp,
        label: riskProfileLabels[rp],
        amount,
        percentage
      };
    })
    .filter((item) => item.amount > 0 || item.percentage > 0)
    .sort((a, b) => b.amount - a.amount);

  const effectiveNetWorth = Math.max(totalNetWorth, totalValuation);
  const investmentToNetWorthRatio =
    effectiveNetWorth > 0 ? (totalValuation / effectiveNetWorth) * 100 : 0;

  return {
    totalValuation,
    totalCostBasis,
    totalUnrealizedGainLoss,
    totalUnrealizedGainLossPercent,
    totalDividendsEarned,
    totalContributions,
    totalWithdrawals,
    investmentToNetWorthRatio,
    assetAllocation,
    riskAllocation
  };
}
