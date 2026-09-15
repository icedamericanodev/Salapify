import { CategoryPack } from '../types';

export const STARTER_CATEGORY_PACKS: CategoryPack[] = [
  {
    id: 'employee',
    title: 'Young Professional / Corporate',
    subtitle: 'Standard sweldo budget for office, BPO, and hybrid corporate workers.',
    emoji: '💼',
    categories: [
      { name: 'Food & Groceries', emoji: '🛒', defaultLimit: 8000 },
      { name: 'Rent & Living', emoji: '🏠', defaultLimit: 9000 },
      { name: 'Utilities & WiFi', emoji: '💡', defaultLimit: 3500 },
      { name: 'Commute & Grab', emoji: '🚖', defaultLimit: 3000 },
      { name: 'SSS / PhilHealth / Pag-IBIG', emoji: '🏛️', defaultLimit: 2500 },
      { name: 'Weekend Treats & Hangouts', emoji: '☕', defaultLimit: 3000 },
    ],
  },
  {
    id: 'freelancer',
    title: 'Freelancer & Remote Contractor',
    subtitle: 'Built for independent creators with 8% tax reserve and business expenses.',
    emoji: '💻',
    categories: [
      { name: '8% BIR Tax Reserve', emoji: '🧾', defaultLimit: 4000 },
      { name: 'Fiber WiFi & Electricity', emoji: '⚡', defaultLimit: 4500 },
      { name: 'Software & Tools', emoji: '🛠️', defaultLimit: 2500 },
      { name: 'Food & Deliveries', emoji: '🍲', defaultLimit: 7500 },
      { name: 'Voluntary SSS / PhilHealth', emoji: '🛡️', defaultLimit: 3000 },
      { name: 'Equipment Fund', emoji: '🎧', defaultLimit: 2000 },
    ],
  },
  {
    id: 'student',
    title: 'Student & University',
    subtitle: 'Allowance pacing for college and university students.',
    emoji: '🎓',
    categories: [
      { name: 'Daily Baon & Canteen', emoji: '🍱', defaultLimit: 3500 },
      { name: 'Jeepney & Commute', emoji: '🚌', defaultLimit: 1500 },
      { name: 'School Supplies & Books', emoji: '📚', defaultLimit: 1200 },
      { name: 'Barkada Coffee & Hangout', emoji: '🧋', defaultLimit: 1500 },
      { name: 'Treats & Snacks', emoji: '🍟', defaultLimit: 1000 },
    ],
  },
  {
    id: 'ofw',
    title: 'OFW Family & Household',
    subtitle: 'Budgeting remittances, padala, family household bills, and health funds.',
    emoji: '🌏',
    categories: [
      { name: 'Family Padala / Remittance', emoji: '💌', defaultLimit: 15000 },
      { name: 'Household Groceries', emoji: '🍚', defaultLimit: 9000 },
      { name: 'Meralco & Water', emoji: '🔌', defaultLimit: 4500 },
      { name: 'Tuition & Kids', emoji: '🎒', defaultLimit: 6000 },
      { name: 'Medical & Emergency Health', emoji: '💊', defaultLimit: 3000 },
      { name: 'Paluwagan / Savings', emoji: '🤝', defaultLimit: 2000 },
    ],
  },
];
