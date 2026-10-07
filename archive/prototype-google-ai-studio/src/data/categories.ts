import { CategoryInfo } from '../types';

export const ACCOUNTING_CATEGORIES: CategoryInfo[] = [
  // Expenses
  {
    id: 'food',
    name: 'Food & Dining',
    emoji: '🍔',
    type: 'expense',
    subcategories: [
      'Fast Food & Karinderya',
      'Sit-down Restaurants',
      'Coffee & Milk Tea',
      'Food Delivery (Grab/Foodpanda)',
      'Office Lunch & Snacks',
    ],
  },
  {
    id: 'groceries',
    name: 'Groceries',
    emoji: '🛒',
    type: 'expense',
    subcategories: [
      'Supermarket (SM/Puregold/Robinsons)',
      'Wet Market (Palengke)',
      'Pantry & Staples',
      'Toiletries & Household Supplies',
    ],
  },
  {
    id: 'transport',
    name: 'Transport & Commute',
    emoji: '🛵',
    type: 'expense',
    subcategories: [
      'Ride Hailing (Grab/Angkas/Joyride)',
      'Public Transit (Jeep/Bus/MRT/LRT)',
      'Fuel & Gas',
      'Tolls & RFID (Easytrip/Autosweep)',
      'Parking & Vehicle Maintenance',
    ],
  },
  {
    id: 'bills',
    name: 'Bills & Utilities',
    emoji: '⚡',
    type: 'expense',
    subcategories: [
      'Electricity (Meralco)',
      'Water (Maynilad/Manila Water)',
      'Home Internet (PLDT/Converge/Globe)',
      'Mobile Postpaid/Prepaid Load',
      'Digital Subscriptions (Spotify/Netflix/iCloud)',
    ],
  },
  {
    id: 'housing',
    name: 'Housing & Rent',
    emoji: '🏠',
    type: 'expense',
    subcategories: [
      'Apartment / House Rent',
      'Condo / HOA Dues',
      'Home Repairs & Maintenance',
      'Furniture & Appliance Repair',
    ],
  },
  {
    id: 'health',
    name: 'Health & Medical',
    emoji: '💊',
    type: 'expense',
    subcategories: [
      'Pharmacy & Maintenance Meds',
      'Doctor Consultation & Clinic',
      'Dental Care',
      'HMO Co-pay & Diagnostics',
      'Fitness & Gym Membership',
    ],
  },
  {
    id: 'shopping',
    name: 'Shopping & Personal',
    emoji: '🛍️',
    type: 'expense',
    subcategories: [
      'Clothing & Footwear',
      'Gadgets & Tech Accessories',
      'E-commerce (Shopee/Lazada)',
      'Personal Grooming & Salon',
    ],
  },
  {
    id: 'debt_servicing',
    name: 'Debt & Loan Servicing',
    emoji: '🤝',
    type: 'expense',
    subcategories: [
      'Credit Card Balance Payment',
      'Personal Loan Installment',
      'Gadget Loan (Home Credit/SpayLater/LazPay)',
      'Mortgage Monthly Amortization',
      'Pag-IBIG / SSS Salary Loan Repayment',
    ],
  },
  {
    id: 'family_support',
    name: 'Family Support & Remittance',
    emoji: '❤️',
    type: 'expense',
    subcategories: [
      'Monthly Family Allowance',
      'Parents & Sibling Support',
      'School Tuition / Baon',
      'Family Gifts & Celebrations',
    ],
  },
  {
    id: 'business_expense',
    name: 'Business & Freelance Ops',
    emoji: '💼',
    type: 'expense',
    subcategories: [
      'Software & SaaS Subscriptions',
      'Subcontractor & Freelancer Fees',
      'Client Entertainment & Meetings',
      'Marketing & Ads (Meta/Google)',
      'Office Supplies & Shipping',
      'Professional Licenses & BIR Taxes',
    ],
  },
  {
    id: 'entertainment',
    name: 'Entertainment & Leisure',
    emoji: '🎬',
    type: 'expense',
    subcategories: [
      'Cinema & Concerts',
      'Gaming & In-app Purchases',
      'Weekend Trips & Staycations',
      'Hobbies & Leisure',
    ],
  },
  {
    id: 'adjustments_expense',
    name: 'Adjustments & Write-offs',
    emoji: '⚖️',
    type: 'expense',
    subcategories: [
      'Reconciliation Discrepancy Write-down',
      'Bank Service Fees & Penalties',
      'Unresolved Ledger Variance',
    ],
  },
  {
    id: 'other_expense',
    name: 'Other Expenses',
    emoji: '📦',
    type: 'expense',
    subcategories: ['Miscellaneous Expense', 'Donations & Tithes'],
  },

  // Income
  {
    id: 'salary',
    name: 'Salary & Compensation',
    emoji: '💰',
    type: 'income',
    subcategories: [
      '15th Sweldo Cutoff',
      '30th Sweldo Cutoff',
      '13th Month Pay (Tax-exempt under 90k)',
      'Overtime & Holiday Pay',
      'De Minimis Benefits & Allowance',
      'Performance Bonus',
    ],
  },
  {
    id: 'business_revenue',
    name: 'Business Revenue',
    emoji: '🏢',
    type: 'income',
    subcategories: [
      'Client Service Retainers',
      'Product Sales Revenue',
      'Consulting Fees',
      'Project Milestone Payments',
    ],
  },
  {
    id: 'side_hustle_income',
    name: 'Side-hustle & Gig Income',
    emoji: '✨',
    type: 'income',
    subcategories: [
      'Freelance Writing/Design/Dev',
      'Online Store / Reselling',
      'Affiliate & Content Creator Payouts',
      'Baking / Food Selling',
    ],
  },
  {
    id: 'investment_income',
    name: 'Investment & Passive Income',
    emoji: '📈',
    type: 'income',
    subcategories: [
      'Digital Bank High-Yield Interest',
      'Pag-IBIG MP2 Dividends',
      'Stock / Mutual Fund Dividends',
      'Rental Property Income',
    ],
  },
  {
    id: 'receivables_collected',
    name: 'Receivables & Repayments',
    emoji: '💸',
    type: 'income',
    subcategories: [
      'Pahiram Repayment Collected',
      'Split Bill Reimbursement',
      'Company Expense Reimbursement',
    ],
  },
  {
    id: 'adjustments_income',
    name: 'Adjustments & Found Cash',
    emoji: '⚖️',
    type: 'income',
    subcategories: [
      'Reconciliation Upward Adjustment',
      'Cashback & Merchant Rebates',
      'Found Money / Windfall',
    ],
  },
  {
    id: 'other_income',
    name: 'Other Income',
    emoji: '🪙',
    type: 'income',
    subcategories: ['Gift Money / Pamasko', 'Miscellaneous Inflow'],
  },

  // Transfer
  {
    id: 'transfer',
    name: 'Transfer',
    emoji: '🔄',
    type: 'both',
    subcategories: [
      'Bank to E-Wallet Transfer',
      'E-Wallet to Bank Transfer',
      'ATM Cash Withdrawal',
      'Savings Allocation',
    ],
  },
];

export const PROFILE_OPTIONS = [
  { id: 'personal', name: 'Personal', description: 'Everyday living, food, and commute', color: '#B03C09' },
  { id: 'household', name: 'Household', description: 'Shared home rent, utilities, and joint groceries', color: '#8A3B14' },
  { id: 'business', name: 'Business', description: 'Registered company revenue and operations', color: '#16643F' },
  { id: 'side_hustle', name: 'Side-hustle', description: 'Freelance gigs, consulting, and commissions', color: '#7E38B7' },
] as const;

export const STATUS_BADGE_CONFIG = {
  confirmed: { label: 'Confirmed', bg: 'bg-emerald-500/15', text: 'text-emerald-700 dark:text-emerald-300', border: 'border-emerald-500/30' },
  reconciled: { label: 'Reconciled', bg: 'bg-blue-500/15', text: 'text-blue-700 dark:text-blue-300', border: 'border-blue-500/30' },
  pending: { label: 'Pending', bg: 'bg-amber-500/15', text: 'text-amber-700 dark:text-amber-300', border: 'border-amber-500/30' },
  duplicate: { label: 'Duplicate', bg: 'bg-rose-500/15', text: 'text-rose-700 dark:text-rose-300', border: 'border-rose-500/30' },
  corrected: { label: 'Corrected', bg: 'bg-purple-500/15', text: 'text-purple-700 dark:text-purple-300', border: 'border-purple-500/30' },
  excluded: { label: 'Excluded', bg: 'bg-stone-500/15', text: 'text-stone-600 dark:text-stone-400', border: 'border-stone-500/30' },
};
