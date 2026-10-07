/**
 * Comprehensive Knowledge Base and System Limitations Repository for Pan AI.
 * 
 * Includes:
 * 1. App Feature Map & Deep Links (Safe to Spend, Sweldo Rail, Debt Beam, Split Bill,
 *    13th-Month, Freelancer 8% Tax, Academy Courses, PH Startup Guide, SaaS Launchpad,
 *    Trackers, Calculators, Backup/Export, Collaboration/Local Spaces).
 * 2. System Limitations Registry: Explicit repository of unsupported features
 *    (e.g., direct bank credential scraping, automatic SMS OTP reading, crypto trading,
 *     multi-device cloud sync without export/import, sending real-world bank transfers).
 * 3. Log of User Limitation Requests stored in client localStorage for future roadmap prioritization.
 */

export interface FeatureKnowledgeItem {
  id: string;
  name: string;
  keywords: string[];
  description: string;
  howToAccess: string;
  actionId?: string;
  actionPayload?: any;
  category: 'core' | 'academy' | 'calculators' | 'philippines' | 'trackers' | 'privacy';
  details: string[];
}

export interface SystemLimitationItem {
  id: string;
  title: string;
  triggerKeywords: string[];
  reason: string;
  offlineWorkaround: string;
  futureStatus: 'planned' | 'evaluated' | 'strictly_prohibited_privacy';
  actionId?: string;
  actionLabel?: string;
}

export interface LimitationRequestLog {
  id: string;
  query: string;
  limitationId: string;
  timestamp: number;
  count: number;
}

// 1. Comprehensive App Features Knowledge Map
export const APP_FEATURES: FeatureKnowledgeItem[] = [
  {
    id: 'feat_startup_guide',
    name: 'Philippine Business Startup Guide',
    keywords: [
      'start app business', 'start a business', 'start business', 'startup', 
      'business registration', 'dti', 'sec', 'mayors permit', 'lgu', 'opc', 
      'sole prop', 'incorporation', 'bir registration', 'eopt'
    ],
    description: 'A complete step-by-step masterclass and interactive checklist for registering and legally operating a business in the Philippines.',
    howToAccess: 'Navigate to Plan > Academy > PH Startup Guide tab.',
    actionId: 'open_startup_guide',
    category: 'academy',
    details: [
      'Interactive Entity Matcher: Helps choose between Sole Proprietorship (DTI), One Person Corporation (SEC OPC), and Regular Stock Corporation.',
      'Registration Roadmap: DTI/SEC eSPARC, Barangay Clearance, Mayor\'s Permit, BIR Form 1901/1903, and SSS/PhilHealth/Pag-IBIG employer enrollment.',
      'Checklist Tracker: Offline-persisted checklist with mandatory and conditional requirements.',
      'CPA & Legal Guidance: Specific compliance guidelines for the Ease of Paying Taxes (EOPT) Act.'
    ]
  },
  {
    id: 'feat_saas_launchpad',
    name: 'SaaS & App Store Launchpad',
    keywords: [
      'app store', 'google play', 'launch app', 'publish app', 'ios app', 
      'android app', 'd-u-n-s', 'duns', 'iap', 'in-app purchase', 'merchant of record', 
      'paddle', 'lemon squeezy', 'stripe ph', 'paymongo', 'saas tax', 'export vat'
    ],
    description: 'Comprehensive Philippine guide to launching mobile apps on Apple App Store & Google Play, obtaining D-U-N-S numbers, using Merchants of Record (MoR), and handling 0% Zero-Rated VAT.',
    howToAccess: 'Navigate to Plan > Academy > PH Startup Guide > SaaS & App Stores tab.',
    actionId: 'open_startup_guide_saas',
    category: 'academy',
    details: [
      'Free Philippine D-U-N-S Number protocol for Apple Developer Organization accounts via SEC registration.',
      'Google Play 20-tester hurdle vs. verified Organization accounts.',
      'Merchant of Record (MoR) strategy (Paddle, Lemon Squeezy) vs. direct Stripe/PayMongo gateway integration.',
      'Section 108(B)(2) 0% Zero-Rated VAT qualification for foreign inward software remittances.',
      'Interactive SaaS Net Revenue Calculator modeling app store cuts and BIR taxes.'
    ]
  },
  {
    id: 'feat_academy_courses',
    name: 'Salapify Academy Financial Literacy Courses',
    keywords: [
      'academy', 'course', 'courses', 'learn', 'education', 'modules', 
      'money mindset', 'lessons', 'classes'
    ],
    description: 'A 32-course financial curriculum spanning Money Mindset, Budgeting, Cash Flow, Emergency Funds, Debt Elimination, MP2, Freelancing, and Startup Legalities.',
    howToAccess: 'Navigate to Plan > Academy.',
    actionId: 'open_academy',
    category: 'academy',
    details: [
      '32 structured bite-sized modules with Philippine real-world case studies.',
      'Interactive Knowledge Checks and reflection exercises.',
      'Local progress saving stored on-device.'
    ]
  },
  {
    id: 'feat_safe_to_spend',
    name: 'Safe to Spend Engine & Sweldo Rail',
    keywords: [
      'safe to spend', 'sweldo rail', 'pacing', 'daily budget', 'how much can i spend',
      'petsa de peligro', 'sweldo cycle', 'cushion'
    ],
    description: 'Calculates the exact amount of money you can spend guilt-free today by subtracting committed bills, upcoming installments, and targeted savings from liquid cash.',
    howToAccess: 'Visible on Home hero card or tap the Safe-to-Spend banner.',
    actionId: 'open_safe_to_spend',
    category: 'core',
    details: [
      'Protects upcoming bills due before your next payday (15th/30th cadence).',
      'Divides remaining cushion evenly across remaining days to give your Daily Pace.',
      'Visual Sweldo Rail highlights danger zones so you never encounter petsa de peligro.'
    ]
  },
  {
    id: 'feat_debt_beam',
    name: 'Debt Both Ways & Debt Beam',
    keywords: [
      'debt beam', 'debts', 'utang', 'pautang', 'pahiram', 'who owes me', 
      'i owe', 'credit limit', 'borrowed', 'lent'
    ],
    description: 'Dual-direction debt tracking honoring Filipino culture: tracks both what you owe to institutions/friends, and what family/friends owe you (pahiram/split bills).',
    howToAccess: 'Tap the Debt Beam on the Home screen or open Debt Screen.',
    actionId: 'open_debt',
    category: 'core',
    details: [
      '5dp proportional Debt Beam comparing What You Owe vs. What is Owed To You.',
      'Partial payments and celebratory settlement animations.',
      'Protects scheduled debt payments inside Safe-to-Spend calculations.'
    ]
  },
  {
    id: 'feat_split_bill',
    name: 'Barkada Split Bill Calculator',
    keywords: [
      'split bill', 'barkada', 'split payment', 'dining split', 'group bill', 'hati'
    ],
    description: 'Quickly splits restaurant or group receipts among friends, including service charges and local taxes, and automatically logs receivables into Debt Both Ways.',
    howToAccess: 'Available in Quick Actions on Home screen or tap Barkada Split Bill.',
    actionId: 'open_split_bill',
    category: 'core',
    details: [
      'Custom tips, service charge percentages, and uneven sharing.',
      'Direct one-tap conversion of unpaid friend shares into Owed-to-Me debts.'
    ]
  },
  {
    id: 'feat_philippine_suite',
    name: 'Philippine Financial Suite',
    keywords: [
      '13th month', 'thirteenth month', 'freelancer tax', '8% tax', 'train law', 
      'remittance', 'ofw', 'household budget', 'yaya', 'kasambahay'
    ],
    description: 'Specialized tools designed for Philippine legal and financial realities: 13th-Month Pay tax calculator, Freelancer 8% Gross Income Tax estimator, OFW remittance fee optimizer, and Kasambahay wage ledger.',
    howToAccess: 'Tap Philippine Suite in Settings or Quick Actions.',
    actionId: 'open_13th_month',
    category: 'philippines',
    details: [
      'TRAIN Law ₱90,000 bonus tax exemption validator.',
      '8% flat tax vs Graduated Withholding Tax comparison for freelancers (Form 1701A).',
      'Kasambahay Law (Batas Kasambahay RA 10361) minimum wage & mandatory SSS/PhilHealth breakdown.'
    ]
  },
  {
    id: 'feat_trackers',
    name: 'Habit & Subscription Trackers',
    keywords: [
      'habits', 'subscription', 'subscriptions', 'netflix', 'spotify', 'recurring payment',
      'habit tracker'
    ],
    description: 'Monitor daily financial habits (e.g., cooking at home, no impulse delivery) and track active recurring subscriptions in PHP.',
    howToAccess: 'Navigate to Plan > Trackers.',
    actionId: 'open_plan_trackers',
    category: 'trackers',
    details: [
      'Streak tracking for mindful spending habits.',
      'Monthly recurring subscription cost tally with renewal alarms.'
    ]
  },
  {
    id: 'feat_decision_journal',
    name: 'Financial Decision Journal & Simulator',
    keywords: [
      'decision journal', 'what if', 'afford', 'buy car', 'decision scenario', 'simulation'
    ],
    description: 'A sandbox to model major financial purchases (gadgets, cars, vacations) against your daily Safe-to-Spend pace before committing real money.',
    howToAccess: 'Navigate to Plan > Decision Journal.',
    actionId: 'open_plan_decision',
    category: 'calculators',
    details: [
      'Simulate single upfront purchases or multi-month installment additions.',
      'Review retrospective outcomes to improve financial decision-making.'
    ]
  },
  {
    id: 'feat_offline_registry',
    name: 'System Limitations & Offline Inquiries Registry',
    keywords: [
      'offline registry', 'limitation registry', 'limitations registry', 'system limitations', 
      'limitations list', 'offline log', 'limitation requests', 'logged queries', 'limitation repository',
      'see the offline registry', 'where can i see the offline registry', 'offline logs'
    ],
    description: 'An on-device transparency registry detailing Salapify\'s architectural boundaries, security guardrails, and any unsupported feature queries logged from Pan.',
    howToAccess: 'Tap Settings (gear icon) > "Offline Registry" button, or open Your Setup > Privacy tab.',
    actionId: 'open_offline_registry',
    category: 'privacy',
    details: [
      'Lists active technical guardrails (zero bank credential scraping, no SMS access, no cloud sync).',
      'Displays all user queries logged to local storage (salapify_limitation_requests_log) for future updates.',
      'Includes one-tap shortcuts to safe local workarounds and ability to clear local request logs.'
    ]
  },
  {
    id: 'feat_offline_privacy',
    name: '100% Offline-First Privacy & Local Backups',
    keywords: [
      'privacy', 'offline', 'backup', 'export data', 'import data', 'sample data',
      'reset data', 'cloud'
    ],
    description: 'Salapify requires zero bank logins and zero cloud servers. All data remains exclusively on your device, with one-tap JSON backup and restore.',
    howToAccess: 'Tap Settings (gear icon) > Privacy Receipt or Export/Import Data.',
    actionId: 'open_setup_privacy',
    category: 'privacy',
    details: [
      'Zero network requests: 100% on-device IndexedDB / localStorage architecture.',
      'Downloadable JSON backup files for migrating across devices safely.',
      'Anonymous & keyless: no account registration required.'
    ]
  }
];

// 2. System Limitations Repository (Graceful handling of unsupported capabilities)
export const SYSTEM_LIMITATIONS: SystemLimitationItem[] = [
  {
    id: 'lim_bank_scraping',
    title: 'Direct Online Banking Credential Sync / Scraping',
    triggerKeywords: [
      'connect bpi', 'connect bdo', 'sync bpi', 'sync bdo', 'sync gcash', 'scrape bank', 
      'auto sync bank', 'link my bank account', 'link bank login', 'plaid', 'open banking', 
      'bank credentials', 'enter bank password'
    ],
    reason: 'To uphold absolute privacy and zero-trust security, Salapify strictly prohibits storing your online banking passwords or connecting to third-party scraping services. Philippine banks (BPI, BDO, UnionBank) frequently invalidate unapproved screen scrapers for user safety.',
    offlineWorkaround: 'You can add any Philippine bank, e-wallet, or credit card in Accounts with an initial balance in 5 seconds. Pan calculates running balances instantly based on your local entries.',
    futureStatus: 'strictly_prohibited_privacy',
    actionId: 'open_accounts',
    actionLabel: 'Manage Accounts Locally'
  },
  {
    id: 'lim_sms_otp_scraping',
    title: 'Automatic Background SMS / OTP Reading',
    triggerKeywords: [
      'read my sms', 'auto read text', 'read gcash sms', 'auto detect bdo sms', 
      'read otp', 'sms parser', 'auto import sms'
    ],
    reason: 'Salapify runs as a private web application in your browser and deliberately requests zero invasive SMS or OTP permissions to prevent unauthorized access to sensitive Philippine two-factor authentication codes.',
    offlineWorkaround: 'Logging an expense takes 3 taps using the Log Sheet, or you can ask Pan to log transactions for you anytime.',
    futureStatus: 'strictly_prohibited_privacy',
    actionId: 'open_log_expense',
    actionLabel: 'Quick Log Expense'
  },
  {
    id: 'lim_execute_bank_transfer',
    title: 'Initiating Real-World Money Transfers (InstaPay/PESONet)',
    triggerKeywords: [
      'send money to', 'transfer cash to', 'pay my meralco bill directly', 
      'send money via instapay', 'wire money', 'cash out'
    ],
    reason: 'Salapify is an analytical personal ledger and financial decision engine, not a licensed remittance agent or payment clearinghouse under Bangko Sentral ng Pilipinas (BSP) Circular 940.',
    offlineWorkaround: 'Execute your transfer securely inside your official bank app (BPI, GCash, Maya), then record the transfer in Salapify under Transfers to keep your balances perfectly synced.',
    futureStatus: 'evaluated',
    actionId: 'open_transfer',
    actionLabel: 'Record Internal Transfer'
  },
  {
    id: 'lim_live_crypto_trading',
    title: 'Live Crypto Trading & Blockchain Wallet Execution',
    triggerKeywords: [
      'buy bitcoin', 'trade crypto', 'connect metamask', 'binance sync', 
      'execute crypto trade', 'swap tokens'
    ],
    reason: 'Salapify focuses on core personal budgeting, sweldo pacing, Philippine tax compliance, and debt settlement. Live custodial crypto exchange integration is outside our financial safety guardrails.',
    offlineWorkaround: 'You can create a custom Asset account under Accounts (e.g. named "Crypto Stash" or "Binance") and update its Philippine Peso valuation whenever you rebalance your net worth.',
    futureStatus: 'evaluated',
    actionId: 'open_accounts',
    actionLabel: 'Add Custom Asset Account'
  },
  {
    id: 'lim_multi_device_auto_sync',
    title: 'Automatic Real-Time Multi-Device Cloud Sync',
    triggerKeywords: [
      'sync across my phone and laptop', 'cloud sync', 'realtime sync', 
      'login on another device', 'multi device cloud'
    ],
    reason: 'Salapify does not operate an external cloud database to store your sensitive balances. Everything lives on your local device.',
    offlineWorkaround: 'You can export an encrypted JSON backup file anytime from Settings > Data & Privacy, and import it into any other browser or phone in 2 seconds.',
    futureStatus: 'planned',
    actionId: 'open_settings',
    actionLabel: 'Open Backup & Export'
  }
];

// Local storage key for limitation requests log
const LIMITATION_REQUESTS_KEY = 'salapify_limitation_requests_log';

/**
 * Logs a detected system limitation request locally so founders/engineers can audit
 * what users frequently ask for that the current engine does not support.
 */
export function logSystemLimitationRequest(query: string, limitationId: string): void {
  try {
    const raw = localStorage.getItem(LIMITATION_REQUESTS_KEY);
    const logs: LimitationRequestLog[] = raw ? JSON.parse(raw) : [];

    const existing = logs.find((l) => l.limitationId === limitationId);
    if (existing) {
      existing.count += 1;
      existing.timestamp = Date.now();
      existing.query = query; // latest query
    } else {
      logs.push({
        id: `lim_req_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
        query,
        limitationId,
        timestamp: Date.now(),
        count: 1
      });
    }

    localStorage.setItem(LIMITATION_REQUESTS_KEY, JSON.stringify(logs));
  } catch {
    // Graceful fallback for non-storage environments
  }
}

/**
 * Retrieve all logged limitation requests (used for future updates & audits).
 */
export function getSystemLimitationLogs(): LimitationRequestLog[] {
  try {
    const raw = localStorage.getItem(LIMITATION_REQUESTS_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

/**
 * Find matching system limitation for a query if one exists.
 */
export function matchSystemLimitation(query: string): SystemLimitationItem | null {
  const q = query.toLowerCase().trim();
  for (const lim of SYSTEM_LIMITATIONS) {
    if (lim.triggerKeywords.some((kw) => q.includes(kw))) {
      return lim;
    }
  }
  return null;
}

/**
 * Find matching app feature knowledge item for a query if one exists.
 */
export function matchAppFeature(query: string): FeatureKnowledgeItem | null {
  const q = query.toLowerCase().trim();
  for (const feat of APP_FEATURES) {
    if (feat.keywords.some((kw) => q.includes(kw))) {
      return feat;
    }
  }
  return null;
}
