export type ThemeMode = 'hapon' | 'gabi';

export type TransactionType = 'expense' | 'income' | 'transfer';

export interface Transaction {
  id: string;
  type: TransactionType;
  amount: number;
  category: string;
  accountId: string;
  toAccountId?: string;
  date: string; // ISO date format YYYY-MM-DD
  merchant?: string;
  note?: string;
  createdAt: number;
}

export type AccountKind = 'cash' | 'bank' | 'credit';

export interface Account {
  id: string;
  name: string;
  kind: AccountKind;
  institution: string; // GCash, Maya, BPI, BDO, UnionBank, SeaBank, GoTyme, etc.
  balance: number;
  creditLimit?: number;
  dueDate?: string;
  monogram: string;
}

export type DebtDirection = 'i_owe' | 'owed_to_me';

export interface Debt {
  id: string;
  person: string; // Person or institution name (e.g., "Home Credit", "Mom", "Kuya Mark")
  direction: DebtDirection;
  totalAmount: number;
  paidAmount: number;
  dueDate?: string;
  installmentCurrent?: number;
  installmentTotal?: number;
  isSettled: boolean;
  settledDate?: string;
  scheduleType: 'scheduled' | 'flexible';
  notes?: string;
}

export interface Budget {
  category: string;
  limit: number;
  emoji: string;
}

export interface UpcomingItem {
  id: string;
  name: string;
  amount: number;
  dueDate: string; // e.g. "Today", "Sunday", "Sep 18", "Monday"
  type: 'bill' | 'subscription' | 'payday' | 'debt';
  isIncome?: boolean;
  isPaid?: boolean;
}

export interface Goal {
  id: string;
  name: string;
  emoji: string;
  targetAmount: number;
  currentAmount: number;
  targetDate: string;
  monthlyTarget: number;
}

export interface PaydayCycle {
  cycleType: '15_30' | 'monthly' | 'weekly';
  lastPayday: string; // e.g. "Sep 1"
  nextPayday: string; // e.g. "Sep 15"
  daysToPayday: number;
  expectedIncome: number;
}

export interface CategoryInfo {
  id: string;
  name: string;
  emoji: string;
}

export type StarterPackId = 'student' | 'employee' | 'freelancer' | 'ofw';

export interface CategoryPack {
  id: StarterPackId;
  title: string;
  subtitle: string;
  emoji: string;
  categories: { name: string; emoji: string; defaultLimit: number }[];
}
