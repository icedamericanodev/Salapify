import React, { createContext, useContext, useState, useEffect, useMemo } from 'react';
import {
  ThemeMode,
  Transaction,
  TransactionStatus,
  Account,
  AccountKind,
  Debt,
  Budget,
  UpcomingItem,
  Goal,
  PaydayCycle,
  StarterPackId,
  ProfileEntity,
  ReconciliationRecord,
  CategoryInfo,
  BillItem,
  InstallmentPlan,
  IncomeStream,
  DecisionScenario,
  SafeToSpendAnalysis,
  HealthCheckInsight,
  ReminderSettings,
  AppNotification,
  ReminderType,
  CollaborationRole,
  CollaborationSpace,
  CollaboratorMember,
  ExpenseSplit,
  SplitParticipant,
  AuditLogEntry,
  TransactionComment,
  TransactionApproval,
  SplitMethod,
  RemittanceRecord,
  ThirteenthMonthPlan,
  ThirteenthMonthAllocation,
  PaydayRoutineTemplate,
  HouseholdAmbagPool,
  FreelanceTaxCalculation,
  InvestmentAsset,
  InvestmentTxType,
  PortfolioSummary,
  ControlCenterAlert,
  FinancialCloseMonth,
  DecisionJournalEntry,
  AdviserSessionConfig,
} from '../types';
import {
  INITIAL_ACCOUNTS,
  INITIAL_BUDGETS,
  INITIAL_DEBTS,
  INITIAL_GOALS,
  INITIAL_PAYDAY,
  INITIAL_TRANSACTIONS,
  INITIAL_UPCOMING,
  INITIAL_RECONCILIATION_HISTORY,
  INITIAL_BILLS,
  INITIAL_INSTALLMENTS,
  INITIAL_INCOME_STREAMS,
} from '../data/initialData';
import {
  INITIAL_COLLABORATION_SPACES,
  INITIAL_COLLABORATOR_MEMBERS,
  INITIAL_EXPENSE_SPLITS,
  INITIAL_AUDIT_LOGS,
} from '../data/initialCollaborationData';
import { ACCOUNTING_CATEGORIES } from '../data/categories';
import { STARTER_CATEGORY_PACKS } from '../data/categoryPacks';
import { convertToPhp } from '../utils/currencies';
import { computeSafeToSpend } from '../utils/safeToSpendEngine';
import { generateHealthCheckInsights } from '../utils/healthCheckEngine';
import {
  calculateSimplifiedDebts,
  calculateSplitShares,
  canPerformAction,
  checkMemberAccess,
} from '../utils/collaborationEngine';
import {
  DEFAULT_REMINDER_SETTINGS,
  evaluateReminders,
  playNotificationChime,
  sendNativeWebNotification,
  formatTimeDisplay,
} from '../utils/notificationEngine';
import {
  calculate13thMonthPay,
  calculateFreelanceTax,
  INITIAL_REMITTANCES,
  INITIAL_PAYDAY_TEMPLATES,
  INITIAL_HOUSEHOLD_AMBAG,
} from '../utils/philippineFinances';
import { INITIAL_INVESTMENTS } from '../data/initialInvestments';
import { calculatePortfolioSummary } from '../utils/investmentProviders';
import { runControlCenterScan, buildFinancialTruthMetadata } from '../utils/financialTruthEngine';

interface FinancialContextType {
  themeMode: ThemeMode;
  toggleTheme: () => void;
  setThemeMode: (mode: ThemeMode) => void;

  activeProfile: ProfileEntity | 'all';
  setActiveProfile: (profile: ProfileEntity | 'all') => void;

  isOnboarded: boolean;
  completeOnboarding: (params: {
    accountName: string;
    institution: string;
    kind: AccountKind;
    balance: number;
    cycleType: '15_30' | 'monthly' | 'weekly';
    starterPackId?: StarterPackId;
  }) => void;
  restartOnboarding: () => void;
  applyStarterPack: (packId: StarterPackId) => void;

  transactions: Transaction[];
  accounts: Account[];
  debts: Debt[];
  budgets: Budget[];
  upcoming: UpcomingItem[];
  goals: Goal[];
  payday: PaydayCycle;
  reconciliationHistory: ReconciliationRecord[];
  categories: CategoryInfo[];

  // Phase 3 & 4 data
  bills: BillItem[];
  installments: InstallmentPlan[];
  incomeStreams: IncomeStream[];
  decisionScenario: DecisionScenario;
  safeToSpendAnalysis: SafeToSpendAnalysis;
  healthCheckInsights: HealthCheckInsight[];

  // Phase 5: Collaboration & Shared Finances
  spaces: CollaborationSpace[];
  activeSpaceId: string | 'all';
  activeSpace: CollaborationSpace | null;
  setActiveSpaceId: (spaceId: string | 'all') => void;
  members: CollaboratorMember[];
  activeMemberId: string;
  activeMember: CollaboratorMember;
  switchActiveMember: (memberId: string) => void;
  createSpace: (space: Omit<CollaborationSpace, 'id' | 'createdAt'>) => CollaborationSpace;
  updateSpace: (id: string, updates: Partial<CollaborationSpace>) => void;
  deleteSpace: (id: string) => void;
  addMember: (member: Omit<CollaboratorMember, 'id' | 'joinedDate'>) => CollaboratorMember;
  updateMemberRole: (memberId: string, role: CollaborationRole, expiresAt?: number | null) => void;
  revokeMemberAccess: (memberId: string) => void;
  addTransactionComment: (txId: string, text: string, replyToCommentId?: string, mentions?: string[]) => void;
  approveTransaction: (txId: string, note?: string) => void;
  rejectTransaction: (txId: string, reason: string) => void;
  attachReceiptToTransaction: (txId: string, fileDataUrl: string, fileName: string) => void;
  removeReceiptFromTransaction: (txId: string) => void;
  expenseSplits: ExpenseSplit[];
  createExpenseSplit: (split: Omit<ExpenseSplit, 'id' | 'createdAt' | 'isFullySettled'>) => ExpenseSplit;
  recordSplitSettlement: (
    splitId: string,
    participantMemberId: string,
    method?: 'gcash' | 'maya' | 'cash' | 'bank_transfer' | 'offset',
    accountId?: string
  ) => void;
  deleteExpenseSplit: (splitId: string) => void;
  auditLogs: AuditLogEntry[];
  addAuditLogEntry: (entry: Omit<AuditLogEntry, 'id' | 'timestamp'>) => void;
  exportAuditLogCsv: () => void;
  pendingApprovalsCount: number;

  // Calculated values
  totalAssets: number;
  totalLiabilities: number;
  totalCreditUsed: number;
  totalDebtsIOwe: number;
  totalDebtsOwedToMe: number;
  netWorth: number;
  safeToSpend: number;
  safeToSpendPerDay: number;

  // Actions
  addTransaction: (tx: Omit<Transaction, 'id' | 'createdAt'>) => Transaction;
  updateTransaction: (id: string, updates: Partial<Transaction>, changeNote?: string) => void;
  deleteTransaction: (id: string) => void;
  changeTransactionStatus: (id: string, newStatus: TransactionStatus, note?: string) => void;
  createAdjustmentTransaction: (accountId: string, varianceAmount: number, note: string) => Transaction;
  recordReconciliation: (record: Omit<ReconciliationRecord, 'id' | 'createdAt'>) => void;

  // Bills actions
  addBill: (bill: Omit<BillItem, 'id'>) => void;
  updateBill: (id: string, updates: Partial<BillItem>) => void;
  deleteBill: (id: string) => void;
  markBillPaid: (id: string, accountId?: string) => void;

  // Installments actions
  addInstallment: (inst: Omit<InstallmentPlan, 'id'>) => void;
  updateInstallment: (id: string, updates: Partial<InstallmentPlan>) => void;
  deleteInstallment: (id: string) => void;
  recordInstallmentPayment: (id: string, accountId?: string) => void;
  recordInstallmentExtraPayment: (id: string, amount: number, note?: string, accountId?: string) => void;

  // Income streams actions
  addIncomeStream: (stream: Omit<IncomeStream, 'id'>) => void;
  updateIncomeStream: (id: string, updates: Partial<IncomeStream>) => void;
  deleteIncomeStream: (id: string) => void;
  setDecisionScenario: (scenario: DecisionScenario) => void;

  // Category management
  getCategoryTransactionCount: (categoryName: string, subcategoryName?: string) => number;
  addMainCategory: (params: {
    name: string;
    emoji: string;
    type: 'expense' | 'income' | 'both';
    subcategories?: string[];
    initialBudgetLimit?: number;
  }) => { success: boolean; error?: string };
  addSubcategory: (categoryIdOrName: string, subcategoryName: string) => { success: boolean; error?: string };
  deleteMainCategory: (categoryIdOrName: string) => { success: boolean; error?: string };
  deleteSubcategory: (categoryIdOrName: string, subcategoryName: string) => { success: boolean; error?: string };

  addAccount: (account: Omit<Account, 'id'>) => void;
  updateAccount: (id: string, updates: Partial<Account>) => void;
  deleteAccount: (id: string) => void;

  addDebt: (debt: Omit<Debt, 'id' | 'isSettled'>) => void;
  recordDebtPayment: (debtId: string, amount: number, accountId?: string) => void;
  toggleDebtSettled: (debtId: string) => void;

  updateBudgetLimit: (category: string, limit: number) => void;
  addBudget: (category: string, emoji: string, limit: number) => void;
  deleteBudget: (category: string) => void;

  updatePayday: (data: Partial<PaydayCycle>) => void;
  addUpcoming: (item: Omit<UpcomingItem, 'id'>) => void;
  deleteUpcoming: (id: string) => void;
  markUpcomingPaid: (id: string, accountId?: string) => void;

  addGoal: (goal: Omit<Goal, 'id' | 'currentAmount'> & { currentAmount?: number }) => void;
  contributeToGoal: (goalId: string, amount: number, accountId?: string) => void;
  resetToSampleData: () => void;

  // Phase 5: Recurring Local Notifications & Reminders
  reminderSettings: ReminderSettings;
  updateReminderSettings: (updates: Partial<ReminderSettings>) => void;
  notifications: AppNotification[];
  unreadNotificationsCount: number;
  markNotificationRead: (id: string) => void;
  markAllNotificationsRead: () => void;
  clearNotification: (id: string) => void;
  clearAllNotifications: () => void;
  triggerSimulatedReminder: (type: ReminderType) => void;
  activeToasts: AppNotification[];
  dismissToast: (id: string) => void;
  requestWebNotificationPermission: () => Promise<NotificationPermission>;
  webNotificationPermission: NotificationPermission;

  // Phase 6: Philippine-Local Features & Tools
  remittances: RemittanceRecord[];
  thirteenthMonthPlan: ThirteenthMonthPlan;
  paydayTemplates: PaydayRoutineTemplate[];
  householdAmbag: HouseholdAmbagPool;
  addRemittance: (record: Omit<RemittanceRecord, 'id'>) => void;
  updateRemittance: (id: string, updates: Partial<RemittanceRecord>) => void;
  deleteRemittance: (id: string) => void;
  update13thMonthPlan: (salary: number, monthsWorked: number, marginalTaxRate?: number) => void;
  update13thMonthAllocations: (allocations: ThirteenthMonthAllocation[]) => void;
  applyPaydayRoutine: (templateId: string) => { success: boolean; createdTxCount: number };
  updateHouseholdAmbagPool: (updates: Partial<HouseholdAmbagPool>) => void;
  recordHouseholdAmbagPayment: (memberId: string, amount: number, accountId?: string) => void;
  calculateFreelanceTaxProvision: (grossIncome: number, taxOption: '8_percent_git' | 'graduated_rates') => FreelanceTaxCalculation;

  // Phase 9: Investment Tracking (Tracking, Not Trading)
  investments: InvestmentAsset[];
  portfolioSummary: PortfolioSummary;
  addInvestmentAsset: (asset: Omit<InvestmentAsset, 'id' | 'lastUpdated' | 'unrealizedGainLoss' | 'unrealizedGainLossPercent'>, fundingAccountId?: string) => InvestmentAsset;
  updateInvestmentAsset: (id: string, updates: Partial<InvestmentAsset>) => void;
  deleteInvestmentAsset: (id: string) => void;
  recordInvestmentActivity: (
    assetId: string,
    activity: {
      type: InvestmentTxType;
      amount: number;
      units?: number;
      pricePerUnit?: number;
      fee?: number;
      note?: string;
      accountId?: string;
    }
  ) => void;
  updateAssetValuation: (assetId: string, newPricePerUnit: number) => void;

  // Salapify Competitive Edge & Truth Architecture
  controlCenterAlerts: ControlCenterAlert[];
  dismissControlCenterAlert: (id: string) => void;
  financialCloseRecords: FinancialCloseMonth[];
  performFinancialClose: (monthId: string, notes?: string) => void;
  decisionJournal: DecisionJournalEntry[];
  addDecisionJournalEntry: (entry: Omit<DecisionJournalEntry, 'id' | 'createdAt'>) => void;
  updateDecisionJournalOutcome: (id: string, outcome: string, reflection?: string) => void;
  adviserSession: AdviserSessionConfig;
  toggleAdviserMode: (enable: boolean, adviserName?: string) => void;
  toggleAdviserMaskBalances: () => void;
}

const FinancialContext = createContext<FinancialContextType | undefined>(undefined);

const STORAGE_KEYS = {
  THEME: 'salapify_theme',
  ACTIVE_PROFILE: 'salapify_active_profile',
  TRANSACTIONS: 'salapify_transactions_v3_acct',
  ACCOUNTS: 'salapify_accounts_v3_acct',
  DEBTS: 'salapify_debts_v3',
  BUDGETS: 'salapify_budgets_v3',
  UPCOMING: 'salapify_upcoming_v3',
  GOALS: 'salapify_goals_v3',
  PAYDAY: 'salapify_payday_v3',
  RECONCILIATIONS: 'salapify_reconciliations_v3',
  ONBOARDED: 'salapify_onboarded_v3',
  CATEGORIES: 'salapify_categories_v3',
  BILLS: 'salapify_bills_v3',
  INSTALLMENTS: 'salapify_installments_v3',
  INCOME_STREAMS: 'salapify_income_streams_v3',
  DECISION_SCENARIO: 'salapify_decision_scenario_v3',
  REMINDER_SETTINGS: 'salapify_reminder_settings_v3',
  NOTIFICATIONS: 'salapify_notifications_v3',
  SENT_REMINDER_TAGS: 'salapify_sent_reminder_tags_v3',
  SPACES: 'salapify_spaces_v5',
  ACTIVE_SPACE_ID: 'salapify_active_space_id_v5',
  MEMBERS: 'salapify_members_v5',
  ACTIVE_MEMBER_ID: 'salapify_active_member_id_v5',
  EXPENSE_SPLITS: 'salapify_expense_splits_v5',
  AUDIT_LOGS: 'salapify_audit_logs_v5',
  REMITTANCES: 'salapify_remittances_v6',
  THIRTEENTH_MONTH: 'salapify_13th_month_v6',
  PAYDAY_TEMPLATES: 'salapify_payday_templates_v6',
  HOUSEHOLD_AMBAG: 'salapify_household_ambag_v6',
  INVESTMENTS: 'salapify_investments_v9',
  DECISION_JOURNAL: 'salapify_decision_journal_v9',
  FINANCIAL_CLOSE: 'salapify_financial_close_v9',
  ADVISER_SESSION: 'salapify_adviser_session_v9',
  DISMISSED_ALERTS: 'salapify_dismissed_alerts_v9',
};

export const FinancialProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [themeMode, setThemeModeState] = useState<ThemeMode>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.THEME);
    return saved === 'gabi' ? 'gabi' : 'hapon';
  });

  const [activeProfile, setActiveProfileState] = useState<ProfileEntity | 'all'>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.ACTIVE_PROFILE) as (ProfileEntity | 'all');
    return saved || 'all';
  });

  const [isOnboarded, setIsOnboarded] = useState<boolean>(() => {
    return localStorage.getItem(STORAGE_KEYS.ONBOARDED) === 'true';
  });

  const [transactions, setTransactions] = useState<Transaction[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.TRANSACTIONS);
    return saved ? JSON.parse(saved) : INITIAL_TRANSACTIONS;
  });

  const [accounts, setAccounts] = useState<Account[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.ACCOUNTS);
    return saved ? JSON.parse(saved) : INITIAL_ACCOUNTS;
  });

  const [debts, setDebts] = useState<Debt[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.DEBTS);
    return saved ? JSON.parse(saved) : INITIAL_DEBTS;
  });

  const [budgets, setBudgets] = useState<Budget[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.BUDGETS);
    return saved ? JSON.parse(saved) : INITIAL_BUDGETS;
  });

  const [upcoming, setUpcoming] = useState<UpcomingItem[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.UPCOMING);
    return saved ? JSON.parse(saved) : INITIAL_UPCOMING;
  });

  const [goals, setGoals] = useState<Goal[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.GOALS);
    return saved ? JSON.parse(saved) : INITIAL_GOALS;
  });

  const [payday, setPayday] = useState<PaydayCycle>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.PAYDAY);
    return saved ? JSON.parse(saved) : INITIAL_PAYDAY;
  });

  const [reconciliationHistory, setReconciliationHistory] = useState<ReconciliationRecord[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.RECONCILIATIONS);
    return saved ? JSON.parse(saved) : INITIAL_RECONCILIATION_HISTORY;
  });

  const [categories, setCategories] = useState<CategoryInfo[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.CATEGORIES);
    if (saved) {
      try {
        const parsed = JSON.parse(saved);
        if (Array.isArray(parsed) && parsed.length > 0) return parsed;
      } catch {
        return ACCOUNTING_CATEGORIES;
      }
    }
    return ACCOUNTING_CATEGORIES;
  });

  const [bills, setBills] = useState<BillItem[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.BILLS);
    return saved ? JSON.parse(saved) : INITIAL_BILLS;
  });

  const [installments, setInstallments] = useState<InstallmentPlan[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.INSTALLMENTS);
    return saved ? JSON.parse(saved) : INITIAL_INSTALLMENTS;
  });

  const [incomeStreams, setIncomeStreams] = useState<IncomeStream[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.INCOME_STREAMS);
    return saved ? JSON.parse(saved) : INITIAL_INCOME_STREAMS;
  });

  const [decisionScenario, setDecisionScenarioState] = useState<DecisionScenario>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.DECISION_SCENARIO) as DecisionScenario;
    return saved === 'optimistic' ? 'optimistic' : 'conservative';
  });

  const [reminderSettings, setReminderSettingsState] = useState<ReminderSettings>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.REMINDER_SETTINGS);
    if (saved) {
      try {
        return { ...DEFAULT_REMINDER_SETTINGS, ...JSON.parse(saved) };
      } catch {
        return DEFAULT_REMINDER_SETTINGS;
      }
    }
    return DEFAULT_REMINDER_SETTINGS;
  });

  const [notifications, setNotifications] = useState<AppNotification[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.NOTIFICATIONS);
    if (saved) {
      try {
        const parsed = JSON.parse(saved);
        if (Array.isArray(parsed)) return parsed;
      } catch {
        // Fallback to initial sample notifications below
      }
    }
    return [
      {
        id: 'initial-daily-1',
        type: 'daily_expense',
        title: 'Daily Expense Reminder',
        body: 'It is past 8:00 PM and you have not logged any expenses for today yet. Keep your sweldo records up to date!',
        timestamp: Date.now() - 1000 * 60 * 45,
        isRead: false,
        actionType: 'open_log_expense',
      },
      {
        id: 'initial-payment-1',
        type: 'payment_due',
        title: 'Payment Due: BDO Credit Card',
        body: 'Outstanding balance of ₱14,250.00 is due in 2 days (Sep 18). Pay before cutoff to avoid finance charges.',
        timestamp: Date.now() - 1000 * 60 * 120,
        isRead: false,
        actionType: 'open_bills',
        metadata: {
          amount: 14250,
          dueDate: 'Sep 18',
          name: 'BDO Credit Card',
        },
      },
      {
        id: 'initial-bill-1',
        type: 'bill_due',
        title: 'Bill Due: Meralco Electricity',
        body: '₱3,850.00 is due in 2 days (Sep 18). Settle early to prevent late surcharges or service cutoff.',
        timestamp: Date.now() - 1000 * 60 * 240,
        isRead: false,
        actionType: 'open_bills',
        metadata: {
          amount: 3850,
          dueDate: 'Sep 18',
          name: 'Meralco Electricity',
        },
      },
      {
        id: 'initial-sub-1',
        type: 'subscription',
        title: 'Subscription Renewal: Spotify Premium Family',
        body: '₱239.00 will auto-renew tomorrow. Ensure your payment card is funded or cancel if not using.',
        timestamp: Date.now() - 1000 * 60 * 360,
        isRead: false,
        actionType: 'open_bills',
        metadata: {
          amount: 239,
          dueDate: 'Tomorrow',
          name: 'Spotify Premium Family',
        },
      },
    ];
  });

  const [sentNotificationTags, setSentNotificationTags] = useState<string[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.SENT_REMINDER_TAGS);
    if (saved) {
      try {
        const parsed = JSON.parse(saved);
        if (Array.isArray(parsed)) return parsed;
      } catch {
        return [];
      }
    }
    return [];
  });

  const [activeToasts, setActiveToasts] = useState<AppNotification[]>([]);

  const [webNotificationPermission, setWebNotificationPermission] = useState<NotificationPermission>(() => {
    if (typeof window !== 'undefined' && 'Notification' in window) {
      return Notification.permission;
    }
    return 'default';
  });

  // Phase 5: Collaboration states
  const [spaces, setSpaces] = useState<CollaborationSpace[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.SPACES);
    return saved ? JSON.parse(saved) : INITIAL_COLLABORATION_SPACES;
  });

  const [activeSpaceId, setActiveSpaceIdState] = useState<string | 'all'>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.ACTIVE_SPACE_ID);
    return saved || 'all';
  });

  const [members, setMembers] = useState<CollaboratorMember[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.MEMBERS);
    return saved ? JSON.parse(saved) : INITIAL_COLLABORATOR_MEMBERS;
  });

  const [activeMemberId, setActiveMemberIdState] = useState<string>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.ACTIVE_MEMBER_ID);
    return saved || 'member_carla';
  });

  const [expenseSplits, setExpenseSplits] = useState<ExpenseSplit[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.EXPENSE_SPLITS);
    return saved ? JSON.parse(saved) : INITIAL_EXPENSE_SPLITS;
  });

  const [auditLogs, setAuditLogs] = useState<AuditLogEntry[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.AUDIT_LOGS);
    return saved ? JSON.parse(saved) : INITIAL_AUDIT_LOGS;
  });

  // Phase 6 State
  const [remittances, setRemittances] = useState<RemittanceRecord[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.REMITTANCES);
    return saved ? JSON.parse(saved) : INITIAL_REMITTANCES;
  });

  const [thirteenthMonthPlan, setThirteenthMonthPlan] = useState<ThirteenthMonthPlan>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.THIRTEENTH_MONTH);
    return saved ? JSON.parse(saved) : calculate13thMonthPay(45000, 12, 0.20);
  });

  const [paydayTemplates, setPaydayTemplates] = useState<PaydayRoutineTemplate[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.PAYDAY_TEMPLATES);
    return saved ? JSON.parse(saved) : INITIAL_PAYDAY_TEMPLATES;
  });

  const [householdAmbag, setHouseholdAmbag] = useState<HouseholdAmbagPool>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.HOUSEHOLD_AMBAG);
    return saved ? JSON.parse(saved) : INITIAL_HOUSEHOLD_AMBAG;
  });

  // Phase 9: Investment Tracking states
  const [investments, setInvestments] = useState<InvestmentAsset[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.INVESTMENTS);
    return saved ? JSON.parse(saved) : INITIAL_INVESTMENTS;
  });

  const [dismissedAlertIds, setDismissedAlertIds] = useState<string[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.DISMISSED_ALERTS);
    return saved ? JSON.parse(saved) : [];
  });

  const [financialCloseRecords, setFinancialCloseRecords] = useState<FinancialCloseMonth[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.FINANCIAL_CLOSE);
    if (saved) return JSON.parse(saved);
    return [
      {
        id: '2026-08',
        periodLabel: 'August 2026',
        isClosed: true,
        closedAt: 1725184800000,
        closedBy: 'Primary User',
        checklist: {
          missingTransactionsReviewed: true,
          duplicatesResolved: true,
          accountBalancesReconciled: true,
          variancesAcknowledged: true,
          monthlyReportConfirmed: true,
        },
        totalInflow: 81000,
        totalOutflow: 48550,
        netSavings: 32450,
        totalVariance: 0,
        notes: 'August books officially closed with zero unresolved reconciliation adjustments.'
      }
    ];
  });

  const [decisionJournal, setDecisionJournal] = useState<DecisionJournalEntry[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.DECISION_JOURNAL);
    if (saved) return JSON.parse(saved);
    return [
      {
        id: 'dec_mp2_vs_td',
        title: 'Pag-IBIG MP2 vs Maya High-Yield Time Deposit Allocation',
        decisionDate: '2026-08-15',
        category: 'investment',
        optionsConsidered: [
          { name: '100% Maya Time Deposit Plus (6.00% p.a.)', cost: 50000, pros: 'Liquid within 6 months; monthly milestones', cons: '20% withholding tax applies' },
          { name: 'Split 70% MP2 + 30% Maya TD', cost: 50000, pros: 'Tax-free compounded dividend, government-backed', cons: '5-year maturity commitment' }
        ],
        chosenOption: 'Split 70% MP2 + 30% Maya TD',
        estimatedCost: 50000,
        expectedBenefit: 'Higher compound growth with zero tax drag on 70% of capital.',
        assumptions: ['7% p.a. MP2 historical dividend rate', '30% liquidity is sufficient for midterm needs'],
        reviewDate: '2026-12-31',
        status: 'evaluated',
        actualOutcome: '7.05% dividend credited; Maya boosted yield received on schedule.',
        learningReflection: 'The tax exemption of MP2 significantly outpaces taxable digital bank yields for multi-year capital.',
        createdAt: 1723708800000
      },
      {
        id: 'dec_tax_8pct',
        title: 'Freelance Tax Choice: 8% Gross Income Tax vs Graduated Income Tax',
        decisionDate: '2026-01-10',
        category: 'tax',
        optionsConsidered: [
          { name: 'Graduated Income Tax with 40% OSD', cost: 18000, pros: 'Allowed if business expenses exceed 40%', cons: 'Requires separate 3% percentage tax and complex quarterly BIR filings' },
          { name: '8% Flat Gross Income Tax (TRAIN Law)', cost: 12000, pros: 'In lieu of both income tax and percentage tax; first 250k exempt', cons: 'Non-refundable if gross income is low' }
        ],
        chosenOption: '8% Flat Gross Income Tax (TRAIN Law)',
        estimatedCost: 12000,
        expectedBenefit: 'Saves approximately ₱24,000 annually in taxes and accounting compliance overhead.',
        assumptions: ['Annual gross revenue between ₱800,000 and ₱1.5M', 'Operating expenses below 40% of gross'],
        reviewDate: '2026-12-15',
        status: 'active',
        createdAt: 1704873600000
      }
    ];
  });

  const [adviserSession, setAdviserSession] = useState<AdviserSessionConfig>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.ADVISER_SESSION);
    if (saved) return JSON.parse(saved);
    return {
      isActive: false,
      adviserName: 'Registered Financial Planner (RFP)',
      expiresAt: null,
      maskBalances: false,
      allowedSections: {
        balanceSheet: true,
        incomeExpense: true,
        debtSchedule: true,
        investments: true,
        cashflow: true,
      },
      auditLog: []
    };
  });

  // Save Phase 9 to localStorage
  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.INVESTMENTS, JSON.stringify(investments));
  }, [investments]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.DISMISSED_ALERTS, JSON.stringify(dismissedAlertIds));
  }, [dismissedAlertIds]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.FINANCIAL_CLOSE, JSON.stringify(financialCloseRecords));
  }, [financialCloseRecords]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.DECISION_JOURNAL, JSON.stringify(decisionJournal));
  }, [decisionJournal]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.ADVISER_SESSION, JSON.stringify(adviserSession));
  }, [adviserSession]);

  // Save changes to localStorage
  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.REMITTANCES, JSON.stringify(remittances));
  }, [remittances]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.THIRTEENTH_MONTH, JSON.stringify(thirteenthMonthPlan));
  }, [thirteenthMonthPlan]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.PAYDAY_TEMPLATES, JSON.stringify(paydayTemplates));
  }, [paydayTemplates]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.HOUSEHOLD_AMBAG, JSON.stringify(householdAmbag));
  }, [householdAmbag]);

  // Save changes to localStorage
  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.THEME, themeMode);
    if (themeMode === 'gabi') {
      document.documentElement.classList.add('dark');
      document.body.className =
        'bg-[#14100D] text-[#F6EFE8] antialiased selection:bg-[#FF9A52]/20 selection:text-[#FF9A52]';
    } else {
      document.documentElement.classList.remove('dark');
      document.body.className =
        'bg-[#FFEEDF] text-[#15120F] antialiased selection:bg-[#B03C09]/20 selection:text-[#B03C09]';
    }
  }, [themeMode]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.ACTIVE_PROFILE, activeProfile);
  }, [activeProfile]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.TRANSACTIONS, JSON.stringify(transactions));
  }, [transactions]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.ACCOUNTS, JSON.stringify(accounts));
  }, [accounts]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.DEBTS, JSON.stringify(debts));
  }, [debts]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.BUDGETS, JSON.stringify(budgets));
  }, [budgets]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.UPCOMING, JSON.stringify(upcoming));
  }, [upcoming]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.GOALS, JSON.stringify(goals));
  }, [goals]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.PAYDAY, JSON.stringify(payday));
  }, [payday]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.RECONCILIATIONS, JSON.stringify(reconciliationHistory));
  }, [reconciliationHistory]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.CATEGORIES, JSON.stringify(categories));
  }, [categories]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.BILLS, JSON.stringify(bills));
  }, [bills]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.INSTALLMENTS, JSON.stringify(installments));
  }, [installments]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.INCOME_STREAMS, JSON.stringify(incomeStreams));
  }, [incomeStreams]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.DECISION_SCENARIO, decisionScenario);
  }, [decisionScenario]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.REMINDER_SETTINGS, JSON.stringify(reminderSettings));
  }, [reminderSettings]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.NOTIFICATIONS, JSON.stringify(notifications));
  }, [notifications]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.SENT_REMINDER_TAGS, JSON.stringify(sentNotificationTags));
  }, [sentNotificationTags]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.SPACES, JSON.stringify(spaces));
  }, [spaces]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.MEMBERS, JSON.stringify(members));
  }, [members]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.EXPENSE_SPLITS, JSON.stringify(expenseSplits));
  }, [expenseSplits]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.AUDIT_LOGS, JSON.stringify(auditLogs));
  }, [auditLogs]);

  // Periodic recurring evaluation engine (checks every 30 seconds and on window focus)
  useEffect(() => {
    const runEvaluation = () => {
      const result = evaluateReminders({
        settings: reminderSettings,
        transactions,
        debts,
        bills,
        installments,
        accounts,
        upcoming,
        sentNotificationTags,
      });

      if (result.newNotifications.length > 0) {
        setNotifications((prev) => [...result.newNotifications, ...prev]);
        setSentNotificationTags(result.updatedSentTags);

        if (reminderSettings.inAppToastsEnabled) {
          setActiveToasts((prev) => [...result.newNotifications, ...prev]);
        }

        if (reminderSettings.soundEnabled) {
          playNotificationChime();
        }

        if (reminderSettings.webNotificationsEnabled) {
          result.newNotifications.forEach((n) => sendNativeWebNotification(n));
        }
      }
    };

    runEvaluation();
    const interval = setInterval(runEvaluation, 30000);

    const handleFocus = () => runEvaluation();
    window.addEventListener('focus', handleFocus);
    document.addEventListener('visibilitychange', handleFocus);

    return () => {
      clearInterval(interval);
      window.removeEventListener('focus', handleFocus);
      document.removeEventListener('visibilitychange', handleFocus);
    };
  }, [
    reminderSettings,
    transactions,
    debts,
    bills,
    installments,
    accounts,
    upcoming,
    sentNotificationTags,
  ]);

  const toggleTheme = () => {
    setThemeModeState((prev) => (prev === 'hapon' ? 'gabi' : 'hapon'));
  };

  const setThemeMode = (mode: ThemeMode) => {
    setThemeModeState(mode);
  };

  const setActiveProfile = (profile: ProfileEntity | 'all') => {
    setActiveProfileState(profile);
  };

  const setDecisionScenario = (scenario: DecisionScenario) => {
    setDecisionScenarioState(scenario);
  };

  // Profile-filtered accounts for balance calculations
  const filteredAccounts = activeProfile === 'all'
    ? accounts
    : accounts.filter((a) => !a.profile || a.profile === activeProfile);

  // Accounting Classification of Assets & Liabilities
  const assetKinds: AccountKind[] = ['cash', 'bank', 'gcash', 'maya', 'debit', 'investment', 'receivable'];
  const liabilityKinds: AccountKind[] = ['credit', 'loan', 'mortgage'];

  const totalAssets = filteredAccounts
    .filter((a) => assetKinds.includes(a.kind))
    .reduce((sum, a) => sum + convertToPhp(a.balance, a.currency || 'PHP'), 0);

  const totalLiabilities = filteredAccounts
    .filter((a) => liabilityKinds.includes(a.kind))
    .reduce((sum, a) => sum + convertToPhp(a.balance, a.currency || 'PHP'), 0);

  const totalCreditUsed = filteredAccounts
    .filter((a) => a.kind === 'credit')
    .reduce((sum, a) => sum + convertToPhp(a.balance, a.currency || 'PHP'), 0);

  const totalDebtsIOwe = debts
    .filter((d) => !d.isSettled && d.direction === 'i_owe')
    .reduce((sum, d) => sum + Math.max(0, d.totalAmount - d.paidAmount), 0);

  const totalDebtsOwedToMe = debts
    .filter((d) => !d.isSettled && d.direction === 'owed_to_me')
    .reduce((sum, d) => sum + Math.max(0, d.totalAmount - d.paidAmount), 0);

  // Net worth = Assets minus Liabilities
  const totalInvestmentsValuation = investments.reduce((sum, inv) => sum + (inv.currentValuation || 0), 0);
  const netWorth = totalAssets - totalLiabilities + totalInvestmentsValuation;

  // Payday-Aware Safe to Spend Analysis (Phase 3)
  const safeToSpendAnalysis = useMemo(() => {
    return computeSafeToSpend({
      accounts: filteredAccounts,
      transactions,
      bills,
      debtsIOwe: totalDebtsIOwe,
      installments,
      incomeStreams,
      payday,
      scenario: decisionScenario,
    });
  }, [
    filteredAccounts,
    transactions,
    bills,
    totalDebtsIOwe,
    installments,
    incomeStreams,
    payday,
    decisionScenario,
  ]);

  const safeToSpend = safeToSpendAnalysis.safeToSpendUntilPayday;
  const safeToSpendPerDay = safeToSpendAnalysis.safeToSpendToday;

  // Money Health Check Insights (Phase 3)
  const healthCheckInsights = useMemo(() => {
    return generateHealthCheckInsights({
      accounts: filteredAccounts,
      transactions,
      debts,
      budgets,
      bills,
      installments,
      goals,
      payday,
      reconciliations: reconciliationHistory,
    });
  }, [
    filteredAccounts,
    transactions,
    debts,
    budgets,
    bills,
    installments,
    goals,
    payday,
    reconciliationHistory,
  ]);

  // Add Transaction with Double-Entry and Account Balance Updates
  const addTransaction = (txData: Omit<Transaction, 'id' | 'createdAt'>): Transaction => {
    const newTx: Transaction = {
      ...txData,
      id: `tx_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      createdAt: Date.now(),
      originalAmount: txData.originalAmount ?? txData.amount,
      currency: txData.currency || 'PHP',
      status: txData.status || 'confirmed',
      profile: txData.profile || (activeProfile === 'all' ? 'personal' : activeProfile),
    };

    setTransactions((prev) => [newTx, ...prev]);

    // Don't update account balance if transaction status is excluded or duplicate
    if (newTx.status !== 'excluded' && newTx.status !== 'duplicate') {
      setAccounts((prev) =>
        prev.map((acc) => {
          if (acc.id === newTx.accountId) {
            if (newTx.type === 'expense') {
              return { ...acc, balance: acc.balance - newTx.amount };
            } else if (newTx.type === 'income') {
              return { ...acc, balance: acc.balance + newTx.amount };
            } else if (newTx.type === 'transfer') {
              return { ...acc, balance: acc.balance - newTx.amount };
            }
          }
          if (newTx.type === 'transfer' && acc.id === newTx.toAccountId) {
            return { ...acc, balance: acc.balance + newTx.amount };
          }
          return acc;
        })
      );
    }

    return newTx;
  };

  // Update Transaction with traceable change history audit trail
  const updateTransaction = (
    id: string,
    updates: Partial<Transaction>,
    changeNote?: string
  ) => {
    setTransactions((prev) => {
      const existing = prev.find((t) => t.id === id);
      if (!existing) return prev;

      const changeRecords: Transaction['changeHistory'] = [
        ...(existing.changeHistory || []),
      ];

      // Track differences for audit trail
      Object.keys(updates).forEach((key) => {
        const k = key as keyof Transaction;
        if (k !== 'changeHistory' && updates[k] !== undefined && updates[k] !== existing[k]) {
          changeRecords.push({
            timestamp: Date.now(),
            field: String(k),
            fromValue: existing[k] as string | number | boolean | undefined,
            toValue: updates[k] as string | number | boolean | undefined,
            note: changeNote || 'Updated transaction details',
          });
        }
      });

      // Handle balance difference if amount, type, or account changed
      const oldAmount = existing.amount;
      const newAmount = updates.amount !== undefined ? updates.amount : oldAmount;
      const delta = newAmount - oldAmount;

      if (delta !== 0 && existing.status !== 'excluded' && existing.status !== 'duplicate') {
        setAccounts((accs) =>
          accs.map((acc) => {
            if (acc.id === existing.accountId) {
              if (existing.type === 'expense' || existing.type === 'transfer') {
                return { ...acc, balance: acc.balance - delta };
              } else if (existing.type === 'income') {
                return { ...acc, balance: acc.balance + delta };
              }
            }
            if (existing.type === 'transfer' && acc.id === existing.toAccountId) {
              return { ...acc, balance: acc.balance + delta };
            }
            return acc;
          })
        );
      }

      const updatedTx: Transaction = {
        ...existing,
        ...updates,
        status: updates.status || (delta !== 0 ? 'corrected' : existing.status),
        changeHistory: changeRecords,
      };

      return prev.map((t) => (t.id === id ? updatedTx : t));
    });
  };

  const changeTransactionStatus = (
    id: string,
    newStatus: TransactionStatus,
    note?: string
  ) => {
    updateTransaction(id, { status: newStatus }, note || `Status changed to ${newStatus}`);
  };

  const deleteTransaction = (id: string) => {
    const tx = transactions.find((t) => t.id === id);
    if (tx && tx.status !== 'excluded' && tx.status !== 'duplicate') {
      // Revert ledger balances
      setAccounts((prev) =>
        prev.map((acc) => {
          if (acc.id === tx.accountId) {
            if (tx.type === 'expense' || tx.type === 'transfer') {
              return { ...acc, balance: acc.balance + tx.amount };
            } else if (tx.type === 'income') {
              return { ...acc, balance: acc.balance - tx.amount };
            }
          }
          if (tx.type === 'transfer' && acc.id === tx.toAccountId) {
            return { ...acc, balance: acc.balance - tx.amount };
          }
          return acc;
        })
      );
    }
    setTransactions((prev) => prev.filter((t) => t.id !== id));
  };

  // Traceable Manual Balance Adjustment: creates an accounting-grade transaction in the ledger
  const createAdjustmentTransaction = (
    accountId: string,
    varianceAmount: number,
    note: string
  ): Transaction => {
    const targetAccount = accounts.find((a) => a.id === accountId);
    const isIncrease = varianceAmount > 0;
    const absAmount = Math.abs(varianceAmount);

    const adjustmentTx = addTransaction({
      type: isIncrease ? 'income' : 'expense',
      amount: absAmount,
      originalAmount: absAmount,
      currency: targetAccount?.currency || 'PHP',
      category: isIncrease ? 'Adjustments & Found Cash' : 'Adjustments & Write-offs',
      subcategory: isIncrease ? 'Reconciliation Upward Adjustment' : 'Reconciliation Discrepancy Write-down',
      accountId,
      profile: targetAccount?.profile || 'personal',
      merchant: `Reconciliation Adjustment (${targetAccount?.name || 'Account'})`,
      date: new Date().toISOString().split('T')[0],
      note: `Traceable reconciliation adjustment: ${note}. Variance of ₱${absAmount.toFixed(2)} resolved.`,
      tags: ['#reconciliation', '#traceable-adjustment'],
      status: 'reconciled',
      isAdjustment: true,
    });

    return adjustmentTx;
  };

  const recordReconciliation = (record: Omit<ReconciliationRecord, 'id' | 'createdAt'>) => {
    const newRecord: ReconciliationRecord = {
      ...record,
      id: `rec_${Date.now()}`,
      createdAt: Date.now(),
    };
    setReconciliationHistory((prev) => [newRecord, ...prev]);
  };

  // Accounts
  const addAccount = (accountData: Omit<Account, 'id'>) => {
    const newAccount: Account = {
      ...accountData,
      id: `acc_${Date.now()}`,
    };
    setAccounts((prev) => [...prev, newAccount]);
  };

  const updateAccount = (id: string, updates: Partial<Account>) => {
    setAccounts((prev) => prev.map((a) => (a.id === id ? { ...a, ...updates } : a)));
  };

  const deleteAccount = (id: string) => {
    setAccounts((prev) => prev.filter((a) => a.id !== id));
  };

  // Debts
  const addDebt = (debtData: Omit<Debt, 'id' | 'isSettled'>) => {
    const newDebt: Debt = {
      ...debtData,
      id: `debt_${Date.now()}`,
      isSettled: false,
    };
    setDebts((prev) => [...prev, newDebt]);
  };

  const recordDebtPayment = (debtId: string, amount: number, accountId?: string) => {
    setDebts((prev) =>
      prev.map((d) => {
        if (d.id === debtId) {
          const newPaid = d.paidAmount + amount;
          const isSettled = newPaid >= d.totalAmount;
          return {
            ...d,
            paidAmount: newPaid,
            isSettled,
            settledDate: isSettled ? new Date().toISOString().split('T')[0] : d.settledDate,
            installmentCurrent: d.installmentCurrent
              ? Math.min(d.installmentTotal || 12, d.installmentCurrent + 1)
              : undefined,
          };
        }
        return d;
      })
    );

    const d = debts.find((item) => item.id === debtId);
    if (accountId && d) {
      if (d.direction === 'i_owe') {
        addTransaction({
          type: 'expense',
          amount,
          category: 'Debt & Loan Servicing',
          subcategory: 'Personal Loan Installment',
          accountId,
          person: d.person,
          merchant: `Repayment to ${d.person}`,
          date: new Date().toISOString().split('T')[0],
          note: `Payment for debt: ${d.person}`,
          tags: ['#debt-payment'],
          status: 'confirmed',
          profile: 'personal',
        });
      } else {
        addTransaction({
          type: 'income',
          amount,
          category: 'Receivables & Repayments',
          subcategory: 'Pahiram Repayment Collected',
          accountId,
          person: d.person,
          merchant: `Repayment from ${d.person}`,
          date: new Date().toISOString().split('T')[0],
          note: `Collected pahiram from ${d.person}`,
          tags: ['#receivable-collected'],
          status: 'confirmed',
          profile: 'personal',
        });
      }
    }
  };

  const toggleDebtSettled = (debtId: string) => {
    setDebts((prev) =>
      prev.map((d) => {
        if (d.id === debtId) {
          const newSettled = !d.isSettled;
          return {
            ...d,
            isSettled: newSettled,
            settledDate: newSettled ? new Date().toISOString().split('T')[0] : undefined,
            paidAmount: newSettled ? d.totalAmount : d.paidAmount,
          };
        }
        return d;
      })
    );
  };

  // Budgets
  const updateBudgetLimit = (category: string, limit: number) => {
    setBudgets((prev) =>
      prev.map((b) => (b.category === category ? { ...b, limit } : b))
    );
  };

  const addBudget = (category: string, emoji: string, limit: number) => {
    setBudgets((prev) => {
      const existing = prev.find((b) => b.category === category);
      if (existing) {
        return prev.map((b) => (b.category === category ? { ...b, limit, emoji } : b));
      }
      return [...prev, { category, emoji, limit }];
    });
  };

  const deleteBudget = (category: string) => {
    setBudgets((prev) => prev.filter((b) => b.category !== category));
  };

  // Category & Subcategory Management
  const getCategoryTransactionCount = (categoryName: string, subcategoryName?: string): number => {
    const normCat = categoryName.trim().toLowerCase();
    if (subcategoryName && subcategoryName.trim()) {
      const normSub = subcategoryName.trim().toLowerCase();
      return transactions.filter(
        (t) =>
          t.category.trim().toLowerCase() === normCat &&
          (t.subcategory || '').trim().toLowerCase() === normSub
      ).length;
    }
    return transactions.filter(
      (t) => t.category.trim().toLowerCase() === normCat
    ).length;
  };

  const addMainCategory = (params: {
    name: string;
    emoji: string;
    type: 'expense' | 'income' | 'both';
    subcategories?: string[];
    initialBudgetLimit?: number;
  }): { success: boolean; error?: string } => {
    const trimmedName = params.name.trim();
    if (!trimmedName) {
      return { success: false, error: 'Category name cannot be empty.' };
    }

    const exists = categories.some(
      (c) => c.name.trim().toLowerCase() === trimmedName.toLowerCase()
    );
    if (exists) {
      return { success: false, error: `A category named "${trimmedName}" already exists.` };
    }

    const cleanSubcategories = (params.subcategories || [])
      .map((s) => s.trim())
      .filter((s) => s.length > 0);

    const newId = `cat_${Date.now()}_${trimmedName.toLowerCase().replace(/[^a-z0-9]/g, '_')}`;
    const newCat: CategoryInfo = {
      id: newId,
      name: trimmedName,
      emoji: params.emoji.trim() || '🏷️',
      type: params.type,
      subcategories: cleanSubcategories,
      isCustom: true,
    };

    setCategories((prev) => [...prev, newCat]);

    if (params.type === 'expense' || params.type === 'both') {
      const limit =
        params.initialBudgetLimit && params.initialBudgetLimit > 0
          ? params.initialBudgetLimit
          : 2500;
      setBudgets((prev) => {
        if (prev.some((b) => b.category.toLowerCase() === trimmedName.toLowerCase())) return prev;
        return [...prev, { category: trimmedName, emoji: newCat.emoji, limit }];
      });
    }

    return { success: true };
  };

  const addSubcategory = (
    categoryIdOrName: string,
    subcategoryName: string
  ): { success: boolean; error?: string } => {
    const trimmedSub = subcategoryName.trim();
    if (!trimmedSub) {
      return { success: false, error: 'Subcategory name cannot be empty.' };
    }

    const catIndex = categories.findIndex(
      (c) => c.id === categoryIdOrName || c.name.toLowerCase() === categoryIdOrName.toLowerCase()
    );
    if (catIndex === -1) {
      return { success: false, error: 'Category not found.' };
    }

    const cat = categories[catIndex];
    const subExists = cat.subcategories.some(
      (s) => s.trim().toLowerCase() === trimmedSub.toLowerCase()
    );
    if (subExists) {
      return {
        success: false,
        error: `Subcategory "${trimmedSub}" already exists in ${cat.name}.`,
      };
    }

    setCategories((prev) => {
      const updated = [...prev];
      updated[catIndex] = {
        ...cat,
        subcategories: [...cat.subcategories, trimmedSub],
      };
      return updated;
    });

    return { success: true };
  };

  const deleteMainCategory = (categoryIdOrName: string): { success: boolean; error?: string } => {
    const cat = categories.find(
      (c) => c.id === categoryIdOrName || c.name.toLowerCase() === categoryIdOrName.toLowerCase()
    );
    if (!cat) {
      return { success: false, error: 'Category not found.' };
    }

    const txCount = getCategoryTransactionCount(cat.name);
    if (txCount > 0) {
      return {
        success: false,
        error: `Cannot delete "${cat.name}": It has ${txCount} transaction${txCount > 1 ? 's' : ''} recorded in your ledger. Delete or reassign those transactions first to protect accounting integrity.`,
      };
    }

    setCategories((prev) => prev.filter((c) => c.id !== cat.id));
    setBudgets((prev) => prev.filter((b) => b.category.toLowerCase() !== cat.name.toLowerCase()));

    return { success: true };
  };

  const deleteSubcategory = (
    categoryIdOrName: string,
    subcategoryName: string
  ): { success: boolean; error?: string } => {
    const trimmedSub = subcategoryName.trim();
    const catIndex = categories.findIndex(
      (c) => c.id === categoryIdOrName || c.name.toLowerCase() === categoryIdOrName.toLowerCase()
    );
    if (catIndex === -1) {
      return { success: false, error: 'Category not found.' };
    }

    const cat = categories[catIndex];
    const txCount = getCategoryTransactionCount(cat.name, trimmedSub);
    if (txCount > 0) {
      return {
        success: false,
        error: `Cannot delete subcategory "${trimmedSub}": It is linked to ${txCount} transaction${txCount > 1 ? 's' : ''}.`,
      };
    }

    setCategories((prev) => {
      const updated = [...prev];
      updated[catIndex] = {
        ...cat,
        subcategories: cat.subcategories.filter(
          (s) => s.trim().toLowerCase() !== trimmedSub.toLowerCase()
        ),
      };
      return updated;
    });

    return { success: true };
  };

  // Payday & Upcoming
  const updatePayday = (data: Partial<PaydayCycle>) => {
    setPayday((prev) => {
      const updated = { ...prev, ...data };
      localStorage.setItem(STORAGE_KEYS.PAYDAY, JSON.stringify(updated));
      return updated;
    });
  };

  const addUpcoming = (item: Omit<UpcomingItem, 'id'>) => {
    const newItem: UpcomingItem = {
      ...item,
      id: `up_${Date.now()}`,
    };
    setUpcoming((prev) => [...prev, newItem]);
  };

  const deleteUpcoming = (id: string) => {
    setUpcoming((prev) => prev.filter((u) => u.id !== id));
  };

  const markUpcomingPaid = (id: string, accountId?: string) => {
    const item = upcoming.find((u) => u.id === id);
    if (!item) return;

    setUpcoming((prev) =>
      prev.map((u) => (u.id === id ? { ...u, isPaid: true } : u))
    );

    const targetAccountId = accountId || accounts[0]?.id;
    if (targetAccountId && !item.isIncome) {
      addTransaction({
        type: 'expense',
        amount: item.amount,
        category: 'Bills & Utilities',
        subcategory: 'Electricity (Meralco)',
        accountId: targetAccountId,
        merchant: item.name,
        date: new Date().toISOString().split('T')[0],
        note: `Paid scheduled item: ${item.name}`,
        tags: ['#bills'],
        status: 'confirmed',
        profile: 'household',
      });
    }
  };

  // Goals
  const addGoal = (goalData: Omit<Goal, 'id' | 'currentAmount'> & { currentAmount?: number }) => {
    const newGoal: Goal = {
      ...goalData,
      id: `goal_${Date.now()}`,
      currentAmount: goalData.currentAmount || 0,
    };
    setGoals((prev) => [...prev, newGoal]);
  };

  const contributeToGoal = (goalId: string, amount: number, accountId?: string) => {
    setGoals((prev) =>
      prev.map((g) => {
        if (g.id === goalId) {
          return { ...g, currentAmount: g.currentAmount + amount };
        }
        return g;
      })
    );

    if (accountId) {
      const g = goals.find((item) => item.id === goalId);
      addTransaction({
        type: 'expense',
        amount,
        category: 'Other Expenses',
        subcategory: 'Miscellaneous Expense',
        accountId,
        merchant: `Goal: ${g?.name || 'Savings'}`,
        date: new Date().toISOString().split('T')[0],
        note: `Contributed to ${g?.name}`,
        tags: ['#goal', '#ipon'],
        status: 'confirmed',
        profile: 'personal',
      });
    }
  };

  // Bills Actions (Phase 4)
  const addBill = (billData: Omit<BillItem, 'id'>) => {
    const newBill: BillItem = {
      ...billData,
      id: `bill_${Date.now()}`,
    };
    setBills((prev) => [...prev, newBill]);
    // Also sync with upcoming items so existing reminders capture it
    addUpcoming({
      name: newBill.name,
      amount: newBill.amount,
      dueDate: newBill.dueDate,
      type: newBill.category === 'subscription' ? 'subscription' : 'bill',
      isIncome: false,
      isPaid: newBill.isPaid,
    });
  };

  const updateBill = (id: string, updates: Partial<BillItem>) => {
    setBills((prev) => prev.map((b) => (b.id === id ? { ...b, ...updates } : b)));
  };

  const deleteBill = (id: string) => {
    setBills((prev) => prev.filter((b) => b.id !== id));
  };

  const markBillPaid = (id: string, accountId?: string) => {
    const bill = bills.find((b) => b.id === id);
    if (!bill) return;

    const todayStr = new Date().toISOString().split('T')[0];
    setBills((prev) =>
      prev.map((b) => (b.id === id ? { ...b, isPaid: true, lastPaidDate: todayStr } : b))
    );

    // Sync matching upcoming item if one exists
    setUpcoming((prev) =>
      prev.map((u) => (u.name.toLowerCase() === bill.name.toLowerCase() ? { ...u, isPaid: true } : u))
    );

    const targetAccountId = accountId || bill.accountId || accounts[0]?.id;
    if (targetAccountId) {
      addTransaction({
        type: 'expense',
        amount: bill.amount,
        category: 'Bills & Utilities',
        subcategory: bill.category === 'subscription' ? 'Subscriptions' : 'Electricity',
        accountId: targetAccountId,
        merchant: bill.name,
        date: todayStr,
        note: `Paid bill: ${bill.name}`,
        tags: ['#bill', `#${bill.category}`],
        status: 'confirmed',
        profile: 'household',
      });
    }
  };

  // Installments Actions (Phase 4)
  const addInstallment = (instData: Omit<InstallmentPlan, 'id'>) => {
    const newInst: InstallmentPlan = {
      ...instData,
      id: `inst_${Date.now()}`,
    };
    setInstallments((prev) => [...prev, newInst]);
  };

  const updateInstallment = (id: string, updates: Partial<InstallmentPlan>) => {
    setInstallments((prev) => prev.map((inst) => (inst.id === id ? { ...inst, ...updates } : inst)));
  };

  const deleteInstallment = (id: string) => {
    setInstallments((prev) => prev.filter((inst) => inst.id !== id));
  };

  const recordInstallmentPayment = (id: string, accountId?: string) => {
    const inst = installments.find((i) => i.id === id);
    if (!inst) return;

    const nextPaid = inst.paidInstallments + 1;
    const isNowSettled = nextPaid >= inst.totalInstallments;
    const nextBalance = isNowSettled ? 0 : Math.max(0, inst.runningBalance - inst.installmentAmount);
    const nextPrincipal = isNowSettled ? 0 : Math.max(0, inst.principalRemaining - (inst.principal / inst.totalInstallments));

    setInstallments((prev) =>
      prev.map((item) =>
        item.id === id
          ? {
              ...item,
              paidInstallments: nextPaid,
              runningBalance: nextBalance,
              principalRemaining: nextPrincipal,
              isSettled: isNowSettled,
            }
          : item
      )
    );

    const targetAccountId = accountId || accounts[0]?.id;
    if (targetAccountId) {
      addTransaction({
        type: 'expense',
        amount: inst.installmentAmount,
        category: 'Debt & Loan Servicing',
        subcategory: 'Personal Loan',
        accountId: targetAccountId,
        merchant: `${inst.provider} - ${inst.name}`,
        date: new Date().toISOString().split('T')[0],
        note: `Installment #${nextPaid} of ${inst.totalInstallments}: ${inst.name}`,
        tags: ['#installment', '#debt'],
        status: 'confirmed',
        profile: 'personal',
      });
    }
  };

  const recordInstallmentExtraPayment = (id: string, amount: number, note?: string, accountId?: string) => {
    const inst = installments.find((i) => i.id === id);
    if (!inst) return;

    const extraPaymentId = `ext_${Date.now()}`;
    const dateStr = new Date().toISOString().split('T')[0];
    const newExtra = { id: extraPaymentId, date: dateStr, amount, note: note || 'Principal prepayment' };

    const newRunning = Math.max(0, inst.runningBalance - amount);
    const newPrincipal = Math.max(0, inst.principalRemaining - amount);
    const isNowSettled = newRunning <= 0;

    setInstallments((prev) =>
      prev.map((item) =>
        item.id === id
          ? {
              ...item,
              runningBalance: newRunning,
              principalRemaining: newPrincipal,
              isSettled: isNowSettled,
              extraPayments: [...(item.extraPayments || []), newExtra],
            }
          : item
      )
    );

    const targetAccountId = accountId || accounts[0]?.id;
    if (targetAccountId) {
      addTransaction({
        type: 'expense',
        amount,
        category: 'Debt & Loan Servicing',
        subcategory: 'Personal Loan',
        accountId: targetAccountId,
        merchant: `${inst.provider} - ${inst.name}`,
        date: dateStr,
        note: `Prepayment on installment: ${inst.name} (${note || 'Principal reduction'})`,
        tags: ['#installment', '#prepayment'],
        status: 'confirmed',
        profile: 'personal',
      });
    }
  };

  // Income Streams Actions (Phase 3)
  const addIncomeStream = (streamData: Omit<IncomeStream, 'id'>) => {
    const newStream: IncomeStream = {
      ...streamData,
      id: `stream_${Date.now()}`,
    };
    setIncomeStreams((prev) => [...prev, newStream]);
  };

  const updateIncomeStream = (id: string, updates: Partial<IncomeStream>) => {
    setIncomeStreams((prev) => prev.map((s) => (s.id === id ? { ...s, ...updates } : s)));
  };

  const deleteIncomeStream = (id: string) => {
    setIncomeStreams((prev) => prev.filter((s) => s.id !== id));
  };

  const applyStarterPack = (packId: StarterPackId) => {
    const pack = STARTER_CATEGORY_PACKS.find((p) => p.id === packId);
    if (!pack) return;
    const newBudgets: Budget[] = pack.categories.map((c) => ({
      category: c.name,
      emoji: c.emoji,
      limit: c.defaultLimit,
    }));
    setBudgets(newBudgets);
    localStorage.setItem(STORAGE_KEYS.BUDGETS, JSON.stringify(newBudgets));
  };

  const completeOnboarding = (params: {
    accountName: string;
    institution: string;
    kind: AccountKind;
    balance: number;
    cycleType: '15_30' | 'monthly' | 'weekly';
    starterPackId?: StarterPackId;
  }) => {
    let monogram = params.accountName.slice(0, 2).toUpperCase();
    if (params.institution === 'GCash') monogram = 'GC';
    else if (params.institution === 'Maya') monogram = 'MY';
    else if (params.institution === 'BPI') monogram = 'BPI';
    else if (params.institution === 'BDO') monogram = 'BDO';
    else if (params.institution === 'UnionBank') monogram = 'UB';
    else if (params.institution === 'MariBank') monogram = 'SB';
    else if (params.institution === 'Cash') monogram = '₱';

    const newAccount: Account = {
      id: 'acc_' + Date.now(),
      name: params.accountName,
      institution: params.institution,
      kind: params.kind,
      balance: params.balance,
      monogram,
      profile: 'personal',
    };

    setAccounts([newAccount]);
    setTransactions([]);
    setDebts([]);

    if (params.starterPackId) {
      applyStarterPack(params.starterPackId);
    }

    setPayday((prev) => {
      const updated = {
        ...prev,
        cycleType: params.cycleType,
      };
      localStorage.setItem(STORAGE_KEYS.PAYDAY, JSON.stringify(updated));
      return updated;
    });

    setIsOnboarded(true);
    localStorage.setItem(STORAGE_KEYS.ONBOARDED, 'true');
    localStorage.setItem(STORAGE_KEYS.ACCOUNTS, JSON.stringify([newAccount]));
    localStorage.setItem(STORAGE_KEYS.TRANSACTIONS, JSON.stringify([]));
    localStorage.setItem(STORAGE_KEYS.DEBTS, JSON.stringify([]));
  };

  const restartOnboarding = () => {
    setIsOnboarded(false);
    localStorage.removeItem(STORAGE_KEYS.ONBOARDED);
  };

  const updateReminderSettings = (updates: Partial<ReminderSettings>) => {
    setReminderSettingsState((prev) => ({ ...prev, ...updates }));
  };

  const markNotificationRead = (id: string) => {
    setNotifications((prev) =>
      prev.map((n) => (n.id === id ? { ...n, isRead: true } : n))
    );
  };

  const markAllNotificationsRead = () => {
    setNotifications((prev) => prev.map((n) => ({ ...n, isRead: true })));
  };

  const clearNotification = (id: string) => {
    setNotifications((prev) => prev.filter((n) => n.id !== id));
    setActiveToasts((prev) => prev.filter((t) => t.id !== id));
  };

  const clearAllNotifications = () => {
    setNotifications([]);
    setActiveToasts([]);
  };

  const dismissToast = (id: string) => {
    setActiveToasts((prev) => prev.filter((t) => t.id !== id));
  };

  const requestWebNotificationPermission = async (): Promise<NotificationPermission> => {
    if (typeof window === 'undefined' || !('Notification' in window)) {
      return 'denied';
    }
    try {
      const perm = await Notification.requestPermission();
      setWebNotificationPermission(perm);
      if (perm === 'granted') {
        updateReminderSettings({ webNotificationsEnabled: true });
      }
      return perm;
    } catch {
      return 'denied';
    }
  };

  const triggerSimulatedReminder = (type: ReminderType) => {
    let notif: AppNotification;
    const now = Date.now();

    if (type === 'daily_expense') {
      const timeDisplay = formatTimeDisplay(reminderSettings.dailyExpenseReminderTime);
      notif = {
        id: `sim-daily-${now}`,
        type: 'daily_expense',
        title: 'Daily Expense Reminder',
        body: `It is past ${timeDisplay} and you have not logged any expenses for today yet. Tap to record your daily coffee, commute, or lunch entries!`,
        timestamp: now,
        isRead: false,
        actionType: 'open_log_expense',
      };
    } else if (type === 'payment_due') {
      notif = {
        id: `sim-payment-${now}`,
        type: 'payment_due',
        title: 'Payment Due: BDO Credit Card',
        body: '₱14,250.00 statement balance is due in 2 days (Sep 18). Pay before cutoff to maintain clean credit standing.',
        timestamp: now,
        isRead: false,
        actionType: 'open_bills',
        metadata: {
          amount: 14250,
          dueDate: 'Sep 18',
          name: 'BDO Credit Card',
        },
      };
    } else if (type === 'bill_due') {
      notif = {
        id: `sim-bill-${now}`,
        type: 'bill_due',
        title: 'Bill Due: Meralco Electricity',
        body: '₱3,850.00 is due in 2 days (Sep 18). Settle early to prevent late surcharges or electricity disconnection.',
        timestamp: now,
        isRead: false,
        actionType: 'open_bills',
        metadata: {
          amount: 3850,
          dueDate: 'Sep 18',
          name: 'Meralco Electricity',
        },
      };
    } else {
      notif = {
        id: `sim-sub-${now}`,
        type: 'subscription',
        title: 'Subscription Renewal: Spotify Premium Family',
        body: '₱239.00 will auto-renew tomorrow. Check if you still use this subscription or ensure your card is funded.',
        timestamp: now,
        isRead: false,
        actionType: 'open_bills',
        metadata: {
          amount: 239,
          dueDate: 'Tomorrow',
          name: 'Spotify Premium Family',
        },
      };
    }

    setNotifications((prev) => [notif, ...prev]);

    if (reminderSettings.inAppToastsEnabled) {
      setActiveToasts((prev) => [notif, ...prev]);
    }

    if (reminderSettings.soundEnabled) {
      playNotificationChime();
    }

    if (reminderSettings.webNotificationsEnabled) {
      sendNativeWebNotification(notif);
    }
  };

  const unreadNotificationsCount = useMemo(() => {
    return notifications.filter((n) => !n.isRead).length;
  }, [notifications]);

  // Phase 5: Collaboration Computed Values & Methods
  const activeMember = useMemo(() => {
    const found = members.find((m) => m.id === activeMemberId);
    return found || members[0] || INITIAL_COLLABORATOR_MEMBERS[0];
  }, [members, activeMemberId]);

  const activeSpace = useMemo(() => {
    if (activeSpaceId === 'all') return null;
    return spaces.find((s) => s.id === activeSpaceId) || null;
  }, [spaces, activeSpaceId]);

  const pendingApprovalsCount = useMemo(() => {
    return transactions.filter(
      (tx) => tx.approval?.status === 'pending_approval'
    ).length;
  }, [transactions]);

  const addAuditLogEntry = (entry: Omit<AuditLogEntry, 'id' | 'timestamp'>) => {
    const newEntry: AuditLogEntry = {
      ...entry,
      id: `audit_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      timestamp: Date.now(),
      actorName: entry.actorName || activeMember.name,
      actorRole: entry.actorRole || activeMember.role,
    };
    setAuditLogs((prev) => [newEntry, ...prev]);
  };

  const exportAuditLogCsv = () => {
    const headers = ['Timestamp', 'Date & Time', 'Actor Name', 'Role', 'Action Type', 'Entity Type', 'Title', 'Description', 'Space ID'];
    const rows = auditLogs.map((log) => [
      log.timestamp,
      new Date(log.timestamp).toLocaleString('en-PH'),
      `"${(log.actorName || '').replace(/"/g, '""')}"`,
      log.actorRole,
      log.actionType,
      log.entityType,
      `"${(log.title || '').replace(/"/g, '""')}"`,
      `"${(log.description || '').replace(/"/g, '""')}"`,
      log.spaceId || 'General',
    ]);
    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `Salapify_Audit_Trail_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const addTransactionComment = (
    txId: string,
    text: string,
    replyToCommentId?: string,
    mentions?: string[]
  ) => {
    const comment: TransactionComment = {
      id: `comm_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      transactionId: txId,
      authorId: activeMember.id,
      authorName: activeMember.name,
      authorRole: activeMember.role,
      authorAvatar: activeMember.avatar,
      text,
      replyToCommentId,
      mentions,
      createdAt: Date.now(),
    };

    setTransactions((prev) =>
      prev.map((t) => {
        if (t.id === txId) {
          const currentComments = t.comments || [];
          return {
            ...t,
            comments: [...currentComments, comment],
          };
        }
        return t;
      })
    );

    addAuditLogEntry({
      actorName: activeMember.name,
      actorRole: activeMember.role,
      actionType: 'added_comment',
      entityType: 'comment',
      entityId: txId,
      title: `Comment on transaction`,
      description: text,
      spaceId: activeSpaceId !== 'all' ? activeSpaceId : undefined,
    });
  };

  const approveTransaction = (txId: string, note?: string) => {
    setTransactions((prev) =>
      prev.map((t) => {
        if (t.id === txId) {
          return {
            ...t,
            status: 'confirmed',
            approval: {
              status: 'approved',
              requestedBy: t.approval?.requestedBy || t.collaboratorName || 'Contributor',
              requestedAt: t.approval?.requestedAt || t.createdAt,
              reviewedBy: activeMember.name,
              reviewedAt: Date.now(),
              reviewedRole: activeMember.role,
              reason: note,
            },
          };
        }
        return t;
      })
    );

    addAuditLogEntry({
      actorName: activeMember.name,
      actorRole: activeMember.role,
      actionType: 'approved_tx',
      entityType: 'transaction',
      entityId: txId,
      title: `Approved transaction`,
      description: note ? `Approved with note: ${note}` : 'Approved by authorized space manager',
      spaceId: activeSpaceId !== 'all' ? activeSpaceId : undefined,
    });
  };

  const rejectTransaction = (txId: string, reason: string) => {
    setTransactions((prev) =>
      prev.map((t) => {
        if (t.id === txId) {
          return {
            ...t,
            status: 'excluded',
            approval: {
              status: 'rejected',
              requestedBy: t.approval?.requestedBy || t.collaboratorName || 'Contributor',
              requestedAt: t.approval?.requestedAt || t.createdAt,
              reviewedBy: activeMember.name,
              reviewedAt: Date.now(),
              reviewedRole: activeMember.role,
              reason,
            },
          };
        }
        return t;
      })
    );

    addAuditLogEntry({
      actorName: activeMember.name,
      actorRole: activeMember.role,
      actionType: 'rejected_tx',
      entityType: 'transaction',
      entityId: txId,
      title: `Rejected transaction`,
      description: `Rejection reason: ${reason}`,
      spaceId: activeSpaceId !== 'all' ? activeSpaceId : undefined,
    });
  };

  const attachReceiptToTransaction = (txId: string, fileDataUrl: string, fileName: string) => {
    setTransactions((prev) =>
      prev.map((t) => {
        if (t.id === txId) {
          return {
            ...t,
            attachmentUrl: fileDataUrl,
            attachmentName: fileName,
          };
        }
        return t;
      })
    );

    addAuditLogEntry({
      actorName: activeMember.name,
      actorRole: activeMember.role,
      actionType: 'attached_receipt',
      entityType: 'transaction',
      entityId: txId,
      title: `Attached receipt: ${fileName}`,
      description: `Uploaded receipt documentation for transaction`,
      spaceId: activeSpaceId !== 'all' ? activeSpaceId : undefined,
    });
  };

  const removeReceiptFromTransaction = (txId: string) => {
    setTransactions((prev) =>
      prev.map((t) => {
        if (t.id === txId) {
          const { attachmentUrl, attachmentName, ...rest } = t;
          return rest as Transaction;
        }
        return t;
      })
    );
  };

  const createSpace = (spaceData: Omit<CollaborationSpace, 'id' | 'createdAt'>): CollaborationSpace => {
    const newSpace: CollaborationSpace = {
      ...spaceData,
      id: `space_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      createdAt: Date.now(),
    };
    setSpaces((prev) => [newSpace, ...prev]);

    addAuditLogEntry({
      actorName: activeMember.name,
      actorRole: activeMember.role,
      actionType: 'created_space',
      entityType: 'space',
      entityId: newSpace.id,
      title: `Created Space: ${newSpace.name}`,
      description: `Initialized ${newSpace.type} collaboration space with ${newSpace.members.length} members`,
      spaceId: newSpace.id,
    });

    return newSpace;
  };

  const updateSpace = (id: string, updates: Partial<CollaborationSpace>) => {
    setSpaces((prev) =>
      prev.map((s) => (s.id === id ? { ...s, ...updates } : s))
    );
    addAuditLogEntry({
      actorName: activeMember.name,
      actorRole: activeMember.role,
      actionType: 'updated_space',
      entityType: 'space',
      entityId: id,
      title: `Updated Space settings`,
      description: `Modified parameters for space`,
      spaceId: id,
    });
  };

  const deleteSpace = (id: string) => {
    setSpaces((prev) => prev.filter((s) => s.id !== id));
    if (activeSpaceId === id) {
      setActiveSpaceIdState('all');
    }
    addAuditLogEntry({
      actorName: activeMember.name,
      actorRole: activeMember.role,
      actionType: 'updated_space',
      entityType: 'space',
      entityId: id,
      title: `Deleted Space`,
      description: `Removed space ${id}`,
    });
  };

  const addMember = (memberData: Omit<CollaboratorMember, 'id' | 'joinedDate'>): CollaboratorMember => {
    const newMember: CollaboratorMember = {
      ...memberData,
      id: `member_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      joinedDate: new Date().toISOString().split('T')[0],
    };
    setMembers((prev) => [...prev, newMember]);

    if (activeSpaceId !== 'all') {
      setSpaces((prev) =>
        prev.map((s) => {
          if (s.id === activeSpaceId) {
            return {
              ...s,
              members: [...s.members, newMember],
            };
          }
          return s;
        })
      );
    }

    addAuditLogEntry({
      actorName: activeMember.name,
      actorRole: activeMember.role,
      actionType: 'invited_member',
      entityType: 'member',
      entityId: newMember.id,
      title: `Invited ${newMember.name} as ${newMember.role}`,
      description: newMember.expiresAt
        ? `Access expires on ${new Date(newMember.expiresAt).toLocaleDateString('en-PH')}`
        : 'Permanent access granted',
      spaceId: activeSpaceId !== 'all' ? activeSpaceId : undefined,
    });

    return newMember;
  };

  const updateMemberRole = (memberId: string, role: CollaborationRole, expiresAt?: number | null) => {
    setMembers((prev) =>
      prev.map((m) =>
        m.id === memberId
          ? {
              ...m,
              role,
              expiresAt: expiresAt !== undefined ? expiresAt : m.expiresAt,
            }
          : m
      )
    );

    setSpaces((prev) =>
      prev.map((s) => ({
        ...s,
        members: s.members.map((m) =>
          m.id === memberId
            ? {
                ...m,
                role,
                expiresAt: expiresAt !== undefined ? expiresAt : m.expiresAt,
              }
            : m
        ),
      }))
    );

    addAuditLogEntry({
      actorName: activeMember.name,
      actorRole: activeMember.role,
      actionType: 'updated_role',
      entityType: 'member',
      entityId: memberId,
      title: `Updated role for member`,
      description: `Role changed to ${role}${expiresAt ? ` (expires ${new Date(expiresAt).toLocaleDateString('en-PH')})` : ''}`,
      spaceId: activeSpaceId !== 'all' ? activeSpaceId : undefined,
    });
  };

  const revokeMemberAccess = (memberId: string) => {
    setMembers((prev) => prev.filter((m) => m.id !== memberId));
    setSpaces((prev) =>
      prev.map((s) => ({
        ...s,
        members: s.members.filter((m) => m.id !== memberId),
      }))
    );
    addAuditLogEntry({
      actorName: activeMember.name,
      actorRole: activeMember.role,
      actionType: 'revoked_access',
      entityType: 'member',
      entityId: memberId,
      title: `Revoked access for member`,
      description: 'Removed member permissions from workspace',
      spaceId: activeSpaceId !== 'all' ? activeSpaceId : undefined,
    });
  };

  const switchActiveMember = (memberId: string) => {
    setActiveMemberIdState(memberId);
    localStorage.setItem(STORAGE_KEYS.ACTIVE_MEMBER_ID, memberId);
    const target = members.find((m) => m.id === memberId);
    if (target) {
      addAuditLogEntry({
        actorName: target.name,
        actorRole: target.role,
        actionType: 'updated_role',
        entityType: 'member',
        entityId: memberId,
        title: `Switched actor to ${target.name}`,
        description: `Current session acting as ${target.name} (${target.role})`,
        spaceId: activeSpaceId !== 'all' ? activeSpaceId : undefined,
      });
    }
  };

  const setActiveSpaceId = (spaceId: string | 'all') => {
    setActiveSpaceIdState(spaceId);
    localStorage.setItem(STORAGE_KEYS.ACTIVE_SPACE_ID, spaceId);
  };

  const createExpenseSplit = (
    splitData: Omit<ExpenseSplit, 'id' | 'createdAt' | 'isFullySettled'>
  ): ExpenseSplit => {
    const isFullySettled = splitData.participants.every((p) => p.hasPaid);
    const newSplit: ExpenseSplit = {
      ...splitData,
      id: `split_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      createdAt: Date.now(),
      isFullySettled,
    };
    setExpenseSplits((prev) => [newSplit, ...prev]);

    splitData.participants.forEach((p) => {
      if (!p.hasPaid && p.memberId !== splitData.payerId && p.shareAmount > 0) {
        addDebt({
          person: p.name,
          direction: 'owed_to_me',
          totalAmount: p.shareAmount,
          paidAmount: 0,
          scheduleType: 'flexible',
          dueDate: splitData.dueDate || new Date(Date.now() + 86400000 * 7).toISOString().split('T')[0],
          notes: `Split share for "${splitData.title}" (${p.sharePercentage ? `${p.sharePercentage}%` : 'fixed'})`,
          splitId: newSplit.id,
        });
      }
    });

    addAuditLogEntry({
      actorName: activeMember.name,
      actorRole: activeMember.role,
      actionType: 'created_split',
      entityType: 'split',
      entityId: newSplit.id,
      title: `Created Split: ${newSplit.title}`,
      description: `Total ₱${newSplit.totalAmount.toLocaleString()} split across ${newSplit.participants.length} participants`,
      spaceId: newSplit.spaceId,
    });

    return newSplit;
  };

  const recordSplitSettlement = (
    splitId: string,
    participantMemberId: string,
    method: 'gcash' | 'maya' | 'cash' | 'bank_transfer' | 'offset' = 'gcash',
    accountId?: string
  ) => {
    let participantName = '';
    let settledAmount = 0;
    let splitTitle = '';
    let currentSpaceId: string | undefined = undefined;

    setExpenseSplits((prev) =>
      prev.map((s) => {
        if (s.id === splitId) {
          splitTitle = s.title;
          currentSpaceId = s.spaceId;
          const updatedParticipants: SplitParticipant[] = s.participants.map((p) => {
            if (p.memberId === participantMemberId) {
              participantName = p.name;
              settledAmount = p.shareAmount;
              return {
                ...p,
                hasPaid: true,
                settledAt: new Date().toISOString().split('T')[0],
                settledMethod: method,
              };
            }
            return p;
          });
          const allPaid = updatedParticipants.every((p) => p.hasPaid);
          return {
            ...s,
            participants: updatedParticipants,
            isFullySettled: allPaid,
          };
        }
        return s;
      })
    );

    setDebts((prev) =>
      prev.map((d) => {
        if (d.splitId === splitId && d.person.toLowerCase().includes(participantName.toLowerCase())) {
          return { ...d, isSettled: true };
        }
        return d;
      })
    );

    if (accountId && settledAmount > 0) {
      addTransaction({
        type: 'income',
        amount: settledAmount,
        originalAmount: settledAmount,
        currency: 'PHP',
        category: 'Debt Repayment & Reimbursements',
        subcategory: 'Split Bill Reimbursement',
        accountId,
        profile: 'personal',
        person: participantName,
        merchant: `Settlement: ${splitTitle}`,
        date: new Date().toISOString().split('T')[0],
        note: `Split settlement received via ${method.toUpperCase()}`,
        tags: ['#split-settlement', '#reimbursement'],
        status: 'confirmed',
        spaceId: currentSpaceId,
      });
    }

    addAuditLogEntry({
      actorName: activeMember.name,
      actorRole: activeMember.role,
      actionType: 'settled_split',
      entityType: 'split',
      entityId: splitId,
      title: `${participantName} settled ₱${settledAmount.toLocaleString()}`,
      description: `Payment recorded via ${method.toUpperCase()} for "${splitTitle}"`,
      spaceId: currentSpaceId,
    });
  };

  const deleteExpenseSplit = (splitId: string) => {
    setExpenseSplits((prev) => prev.filter((s) => s.id !== splitId));
    addAuditLogEntry({
      actorName: activeMember.name,
      actorRole: activeMember.role,
      actionType: 'deleted_split',
      entityType: 'split',
      entityId: splitId,
      title: `Deleted expense split`,
      description: `Removed expense split record`,
    });
  };

  // Phase 6 Actions
  const addRemittance = (record: Omit<RemittanceRecord, 'id'>) => {
    const id = `remit-${Date.now()}`;
    const newRecord: RemittanceRecord = { ...record, id };
    setRemittances((prev) => [newRecord, ...prev]);

    // Automatically record corresponding outflow in ledger
    addTransaction({
      type: 'expense',
      amount: newRecord.amount,
      category: 'Family Support & Remittance',
      subcategory: 'Monthly Family Allowance',
      accountId: accounts.find((a) => a.kind === 'bank' || a.kind === 'gcash')?.id || accounts[0]?.id || '',
      merchant: `${newRecord.channel.replace(/_/g, ' ').toUpperCase()} Padala`,
      person: newRecord.recipientName,
      date: newRecord.date,
      note: `Padala for ${newRecord.purpose.replace(/_/g, ' ')} (${newRecord.provinceCity}) · Ref: ${newRecord.referenceNumber || 'N/A'}`,
      tags: ['#padala', '#remittance', `#${newRecord.channel}`],
      status: 'confirmed',
    });
  };

  const updateRemittance = (id: string, updates: Partial<RemittanceRecord>) => {
    setRemittances((prev) => prev.map((r) => (r.id === id ? { ...r, ...updates } : r)));
  };

  const deleteRemittance = (id: string) => {
    setRemittances((prev) => prev.filter((r) => r.id !== id));
  };

  const update13thMonthPlan = (salary: number, monthsWorked: number, marginalTaxRate: number = 0.20) => {
    const updated = calculate13thMonthPay(salary, monthsWorked, marginalTaxRate);
    setThirteenthMonthPlan(updated);
  };

  const update13thMonthAllocations = (allocations: ThirteenthMonthAllocation[]) => {
    setThirteenthMonthPlan((prev) => ({ ...prev, allocations }));
  };

  const applyPaydayRoutine = (templateId: string): { success: boolean; createdTxCount: number } => {
    const template = paydayTemplates.find((t) => t.id === templateId);
    if (!template) return { success: false, createdTxCount: 0 };

    let createdCount = 0;
    const today = new Date().toISOString().split('T')[0];

    // Record salary entry first
    addTransaction({
      type: 'income',
      amount: template.baseSalary,
      category: 'Salary & Compensation',
      subcategory: '15th Sweldo Cutoff',
      accountId: accounts.find((a) => a.kind === 'bank')?.id || accounts[0]?.id || '',
      merchant: 'Company Payroll / Employer',
      date: today,
      note: `Sweldo credit applied from ${template.name}`,
      tags: ['#sweldo', '#payroll', '#quincena'],
      status: 'confirmed',
    });
    createdCount++;

    // Record allocated transfers and budget assignments
    for (const item of template.items) {
      if (item.bucket === 'bills') {
        addTransaction({
          type: 'expense',
          amount: item.amount,
          category: item.category,
          accountId: accounts.find((a) => a.kind === 'bank' || a.kind === 'gcash')?.id || accounts[0]?.id || '',
          merchant: item.name,
          date: today,
          note: `Auto-allocated bill payment from ${template.name}`,
          tags: ['#payday-routine', '#bills'],
          status: 'confirmed',
        });
        createdCount++;
      } else if (item.bucket === 'ipon_mp2') {
        const destAccount = accounts.find((a) => a.kind === 'investment' || a.institution.includes('MariBank') || a.institution.includes('GoTyme'));
        const sourceAccount = accounts.find((a) => a.kind === 'bank') || accounts[0];
        if (destAccount && sourceAccount) {
          addTransaction({
            type: 'transfer',
            amount: item.amount,
            category: 'Transfer',
            accountId: sourceAccount.id,
            toAccountId: destAccount.id,
            merchant: `Transfer to ${destAccount.name}`,
            date: today,
            note: `Automated Ipon & Pag-IBIG MP2 contribution from sweldo`,
            tags: ['#ipon', '#mp2', '#savings-first'],
            status: 'confirmed',
          });
          createdCount++;
        }
      }
    }

    return { success: true, createdTxCount: createdCount };
  };

  const updateHouseholdAmbagPool = (updates: Partial<HouseholdAmbagPool>) => {
    setHouseholdAmbag((prev) => ({ ...prev, ...updates }));
  };

  const recordHouseholdAmbagPayment = (memberId: string, amount: number, accountId?: string) => {
    setHouseholdAmbag((prev) => {
      const updatedMembers = prev.members.map((m) => {
        if (m.id === memberId) {
          const newPaid = m.actualPaidThisMonth + amount;
          return {
            ...m,
            actualPaidThisMonth: newPaid,
            isSettled: newPaid >= m.monthlyExpectedAmbag,
          };
        }
        return m;
      });

      const totalCollected = updatedMembers.reduce((sum, m) => sum + m.actualPaidThisMonth, 0);
      return {
        ...prev,
        members: updatedMembers,
        totalCollectedThisMonth: totalCollected,
      };
    });

    const targetMember = householdAmbag.members.find((m) => m.id === memberId);
    if (targetMember && targetMember.relation === 'Self') {
      addTransaction({
        type: 'expense',
        amount,
        category: 'Bills & Utilities',
        subcategory: 'Electricity (Meralco)',
        accountId: accountId || accounts[0]?.id || '',
        merchant: 'Ambagan sa Bahay (Family Shared Pool)',
        date: new Date().toISOString().split('T')[0],
        note: `Personal household ambag payment for ${householdAmbag.cycleMonth}`,
        tags: ['#ambag', '#household', '#family-share'],
        status: 'confirmed',
      });
    }
  };

  const calculateFreelanceTaxProvision = (
    grossIncome: number,
    taxOption: '8_percent_git' | 'graduated_rates'
  ): FreelanceTaxCalculation => {
    return calculateFreelanceTax(grossIncome, taxOption);
  };

  // Phase 9: Investment Tracking & Competitive Edge Calculations
  const portfolioSummary = useMemo<any>(() => {
    return calculatePortfolioSummary(investments, netWorth);
  }, [investments, netWorth]);

  const rawControlAlerts = useMemo(() => {
    return runControlCenterScan(transactions, accounts, debts, budgets);
  }, [transactions, accounts, debts, budgets]);

  const controlCenterAlerts = useMemo(() => {
    return rawControlAlerts.filter((a) => !dismissedAlertIds.includes(a.id));
  }, [rawControlAlerts, dismissedAlertIds]);

  const addInvestmentAsset = (
    assetData: Omit<InvestmentAsset, 'id' | 'lastUpdated' | 'unrealizedGainLoss' | 'unrealizedGainLossPercent'>, fundingAccountId?: string
  ): InvestmentAsset => {
    const id = `inv_${Date.now()}_${Math.random().toString(36).substr(2, 4)}`;
    const costBasis = assetData.costBasis || 0;
    const valuation =
      assetData.currentValuation ||
      (assetData.units ? assetData.units * assetData.currentPricePerUnit : costBasis);
    const unrealizedGainLoss = valuation - costBasis;
    const unrealizedGainLossPercent = costBasis > 0 ? (unrealizedGainLoss / costBasis) * 100 : 0;

    
    const newAsset: InvestmentAsset = {
      ...assetData,
      id,
      costBasis,
      currentValuation: valuation,
      unrealizedGainLoss,
      unrealizedGainLossPercent,
      totalDividendsEarned: assetData.totalDividendsEarned || 0,
      totalContributions: assetData.totalContributions || costBasis,
      totalWithdrawals: assetData.totalWithdrawals || 0,
      lastUpdated: new Date().toISOString().split('T')[0]
    };

    if (fundingAccountId && costBasis > 0) {
      addTransaction({
        date: new Date().toISOString().split('T')[0],
        accountId: fundingAccountId,
        type: 'transfer',
        amount: costBasis,
        category: 'Investment Funding',
        merchant: newAsset.name,
        note: `Funded investment: ${newAsset.name}`,
        status: 'confirmed',
        profile: 'personal'
      });
    }

    setInvestments((prev) => [newAsset, ...prev]);

    return newAsset;
  };

  const updateInvestmentAsset = (id: string, updates: Partial<InvestmentAsset>) => {
    setInvestments((prev) =>
      prev.map((item) => {
        if (item.id !== id) return item;
        const merged = { ...item, ...updates };
        const costBasis = merged.costBasis || 0;
        const valuation =
          merged.currentValuation ||
          (merged.units ? merged.units * merged.currentPricePerUnit : costBasis);
        const unrealizedGainLoss = valuation - costBasis;
        const unrealizedGainLossPercent = costBasis > 0 ? (unrealizedGainLoss / costBasis) * 100 : 0;
        return {
          ...merged,
          costBasis,
          currentValuation: valuation,
          unrealizedGainLoss,
          unrealizedGainLossPercent,
          lastUpdated: new Date().toISOString().split('T')[0]
        };
      })
    );
  };

  const deleteInvestmentAsset = (id: string) => {
    setInvestments((prev) => prev.filter((a) => a.id !== id));
  };

  const recordInvestmentActivity = (
    assetId: string,
    activity: {
      type: InvestmentTxType;
      amount: number;
      units?: number;
      pricePerUnit?: number;
      fee?: number;
      note?: string;
      accountId?: string;
    }
  ) => {
    setInvestments((prev) =>
      prev.map((asset) => {
        if (asset.id !== assetId) return asset;

        let newUnits = asset.units;
        let newCostBasis = asset.costBasis;
        let newDividends = asset.totalDividendsEarned || 0;
        let newContributions = asset.totalContributions || 0;
        let newWithdrawals = asset.totalWithdrawals || 0;
        const price = activity.pricePerUnit || asset.currentPricePerUnit || 1;

        if (activity.type === 'buy' || activity.type === 'contribution') {
          const addedUnits = activity.units || (price > 0 ? activity.amount / price : 0);
          newUnits += addedUnits;
          newCostBasis += activity.amount;
          newContributions += activity.amount;
        } else if (activity.type === 'sell' || activity.type === 'withdrawal') {
          const removedUnits = activity.units || (price > 0 ? activity.amount / price : 0);
          const ratio = asset.units > 0 ? Math.min(1, removedUnits / asset.units) : 1;
          newUnits = Math.max(0, newUnits - removedUnits);
          newCostBasis = Math.max(0, newCostBasis - newCostBasis * ratio);
          newWithdrawals += activity.amount;
        } else if (activity.type === 'dividend') {
          newDividends += activity.amount;
        }

        const newAverageCost = newUnits > 0 ? newCostBasis / newUnits : asset.averageCostPerUnit;
        const newValuation = newUnits > 0 ? newUnits * asset.currentPricePerUnit : newCostBasis;
        const newUnrealizedGainLoss = newValuation - newCostBasis;
        const newUnrealizedGainLossPercent = newCostBasis > 0 ? (newUnrealizedGainLoss / newCostBasis) * 100 : 0;

        return {
          ...asset,
          units: newUnits,
          costBasis: newCostBasis,
          averageCostPerUnit: newAverageCost,
          currentValuation: newValuation,
          totalDividendsEarned: newDividends,
          totalContributions: newContributions,
          totalWithdrawals: newWithdrawals,
          unrealizedGainLoss: newUnrealizedGainLoss,
          unrealizedGainLossPercent: newUnrealizedGainLossPercent,
          lastUpdated: new Date().toISOString().split('T')[0]
        };
      })
    );

    // If account specified, add transaction in ledger
    if (activity.accountId) {
      const asset = investments.find((a) => a.id === assetId);
      const assetName = asset ? asset.name : 'Investment';
      if (activity.type === 'buy' || activity.type === 'contribution') {
        addTransaction({
          type: 'expense',
          amount: activity.amount,
          category: 'Investments',
          subcategory: asset?.assetClass || 'Contribution',
          accountId: activity.accountId,
          merchant: `${assetName} (${activity.type.toUpperCase()})`,
          date: new Date().toISOString().split('T')[0],
          note: activity.note || `Investment purchase of ${assetName}`,
          tags: ['#investments', '#portfolio', `#${activity.type}`],
          status: 'confirmed'
        });
      } else if (activity.type === 'sell' || activity.type === 'withdrawal' || activity.type === 'dividend') {
        addTransaction({
          type: 'income',
          amount: activity.amount,
          category: 'Investments',
          subcategory: activity.type === 'dividend' ? 'Dividends' : 'Redemption',
          accountId: activity.accountId,
          merchant: `${assetName} (${activity.type.toUpperCase()})`,
          date: new Date().toISOString().split('T')[0],
          note: activity.note || `Investment ${activity.type} from ${assetName}`,
          tags: ['#investments', '#yield', `#${activity.type}`],
          status: 'confirmed'
        });
      }
    }
  };

  const updateAssetValuation = (assetId: string, newPricePerUnit: number) => {
    setInvestments((prev) =>
      prev.map((asset) => {
        if (asset.id !== assetId) return asset;
        const currentValuation = asset.units * newPricePerUnit;
        const unrealizedGainLoss = currentValuation - asset.costBasis;
        const unrealizedGainLossPercent =
          asset.costBasis > 0 ? (unrealizedGainLoss / asset.costBasis) * 100 : 0;
        return {
          ...asset,
          currentPricePerUnit: newPricePerUnit,
          currentValuation,
          unrealizedGainLoss,
          unrealizedGainLossPercent,
          lastUpdated: new Date().toISOString().split('T')[0]
        };
      })
    );
  };

  const dismissControlCenterAlert = (id: string) => {
    setDismissedAlertIds((prev) => [...prev, id]);
  };

  const performFinancialClose = (monthId: string, notes?: string) => {
    const monthTransactions = transactions.filter((t) => t.date.startsWith(monthId));
    const income = monthTransactions
      .filter((t) => t.type === 'income')
      .reduce((sum, t) => sum + t.amount, 0);
    const expenses = monthTransactions
      .filter((t) => t.type === 'expense')
      .reduce((sum, t) => sum + t.amount, 0);

    const [yearStr, monthStr] = monthId.split('-');
    const dateObj = new Date(parseInt(yearStr), parseInt(monthStr) - 1, 1);
    const periodLabel = dateObj.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });

    const newRecord: FinancialCloseMonth = {
      id: monthId,
      periodLabel,
      isClosed: true,
      closedAt: Date.now(),
      closedBy: activeMember ? activeMember.name : 'Primary User',
      checklist: {
        missingTransactionsReviewed: true,
        duplicatesResolved: true,
        accountBalancesReconciled: true,
        variancesAcknowledged: true,
        monthlyReportConfirmed: true,
      },
      totalInflow: income,
      totalOutflow: expenses,
      netSavings: income - expenses,
      totalVariance: 0,
      notes: notes || `Financial Close finalized for ${periodLabel}. Reconciled and locked.`
    };

    setFinancialCloseRecords((prev) => [newRecord, ...prev.filter((r) => r.id !== monthId)]);
  };

  const addDecisionJournalEntry = (
    entry: Omit<DecisionJournalEntry, 'id' | 'createdAt'>
  ) => {
    const id = `dec_${Date.now()}`;
    const newEntry: DecisionJournalEntry = {
      ...entry,
      id,
      createdAt: Date.now()
    };
    setDecisionJournal((prev) => [newEntry, ...prev]);
  };

  const updateDecisionJournalOutcome = (
    id: string,
    outcome: string,
    reflection?: string
  ) => {
    setDecisionJournal((prev) =>
      prev.map((dec) => {
        if (dec.id !== id) return dec;
        return {
          ...dec,
          status: 'evaluated',
          actualOutcome: outcome,
          learningReflection: reflection || dec.learningReflection
        };
      })
    );
  };

  const toggleAdviserMode = (enable: boolean, adviserName?: string) => {
    setAdviserSession((prev) => ({
      ...prev,
      isActive: enable,
      adviserName: adviserName || prev.adviserName,
      expiresAt: enable ? Date.now() + 2 * 3600 * 1000 : null,
      auditLog: [
        {
          timestamp: Date.now(),
          action: enable ? `Adviser session activated for ${adviserName || prev.adviserName}` : 'Adviser session ended'
        },
        ...prev.auditLog
      ]
    }));
  };

  const toggleAdviserMaskBalances = () => {
    setAdviserSession((prev) => ({
      ...prev,
      maskBalances: !prev.maskBalances
    }));
  };

  const resetToSampleData = () => {
    const freshTransactions = JSON.parse(JSON.stringify(INITIAL_TRANSACTIONS));
    const freshAccounts = JSON.parse(JSON.stringify(INITIAL_ACCOUNTS));
    const freshDebts = JSON.parse(JSON.stringify(INITIAL_DEBTS));
    const freshBudgets = JSON.parse(JSON.stringify(INITIAL_BUDGETS));
    const freshUpcoming = JSON.parse(JSON.stringify(INITIAL_UPCOMING));
    const freshGoals = JSON.parse(JSON.stringify(INITIAL_GOALS));
    const freshPayday = JSON.parse(JSON.stringify(INITIAL_PAYDAY));
    const freshRec = JSON.parse(JSON.stringify(INITIAL_RECONCILIATION_HISTORY));
    const freshCategories = JSON.parse(JSON.stringify(ACCOUNTING_CATEGORIES));
    const freshBills = JSON.parse(JSON.stringify(INITIAL_BILLS));
    const freshInstallments = JSON.parse(JSON.stringify(INITIAL_INSTALLMENTS));
    const freshIncomeStreams = JSON.parse(JSON.stringify(INITIAL_INCOME_STREAMS));
    const freshSpaces = JSON.parse(JSON.stringify(INITIAL_COLLABORATION_SPACES));
    const freshMembers = JSON.parse(JSON.stringify(INITIAL_COLLABORATOR_MEMBERS));
    const freshSplits = JSON.parse(JSON.stringify(INITIAL_EXPENSE_SPLITS));
    const freshAuditLogs = JSON.parse(JSON.stringify(INITIAL_AUDIT_LOGS));
    const freshRemittances = JSON.parse(JSON.stringify(INITIAL_REMITTANCES));
    const fresh13th = calculate13thMonthPay(45000, 12, 0.20);
    const freshPaydayTmpl = JSON.parse(JSON.stringify(INITIAL_PAYDAY_TEMPLATES));
    const freshAmbag = JSON.parse(JSON.stringify(INITIAL_HOUSEHOLD_AMBAG));

    setTransactions(freshTransactions);
    setAccounts(freshAccounts);
    setDebts(freshDebts);
    setBudgets(freshBudgets);
    setUpcoming(freshUpcoming);
    setGoals(freshGoals);
    setPayday(freshPayday);
    setReconciliationHistory(freshRec);
    setCategories(freshCategories);
    setBills(freshBills);
    setInstallments(freshInstallments);
    setIncomeStreams(freshIncomeStreams);
    setSpaces(freshSpaces);
    setMembers(freshMembers);
    setExpenseSplits(freshSplits);
    setAuditLogs(freshAuditLogs);
    setRemittances(freshRemittances);
    setThirteenthMonthPlan(fresh13th);
    setPaydayTemplates(freshPaydayTmpl);
    setHouseholdAmbag(freshAmbag);
    setActiveSpaceIdState('all');
    setActiveMemberIdState('member_carla');
    setDecisionScenarioState('conservative');
    setActiveProfileState('all');
    setIsOnboarded(true);

    localStorage.setItem(STORAGE_KEYS.ONBOARDED, 'true');
    localStorage.setItem(STORAGE_KEYS.TRANSACTIONS, JSON.stringify(freshTransactions));
    localStorage.setItem(STORAGE_KEYS.ACCOUNTS, JSON.stringify(freshAccounts));
    localStorage.setItem(STORAGE_KEYS.DEBTS, JSON.stringify(freshDebts));
    localStorage.setItem(STORAGE_KEYS.BUDGETS, JSON.stringify(freshBudgets));
    localStorage.setItem(STORAGE_KEYS.UPCOMING, JSON.stringify(freshUpcoming));
    localStorage.setItem(STORAGE_KEYS.GOALS, JSON.stringify(freshGoals));
    localStorage.setItem(STORAGE_KEYS.PAYDAY, JSON.stringify(freshPayday));
    localStorage.setItem(STORAGE_KEYS.RECONCILIATIONS, JSON.stringify(freshRec));
    localStorage.setItem(STORAGE_KEYS.CATEGORIES, JSON.stringify(freshCategories));
    localStorage.setItem(STORAGE_KEYS.BILLS, JSON.stringify(freshBills));
    localStorage.setItem(STORAGE_KEYS.INSTALLMENTS, JSON.stringify(freshInstallments));
    localStorage.setItem(STORAGE_KEYS.INCOME_STREAMS, JSON.stringify(freshIncomeStreams));
    localStorage.setItem(STORAGE_KEYS.SPACES, JSON.stringify(freshSpaces));
    localStorage.setItem(STORAGE_KEYS.MEMBERS, JSON.stringify(freshMembers));
    localStorage.setItem(STORAGE_KEYS.EXPENSE_SPLITS, JSON.stringify(freshSplits));
    localStorage.setItem(STORAGE_KEYS.AUDIT_LOGS, JSON.stringify(freshAuditLogs));
    localStorage.setItem(STORAGE_KEYS.REMITTANCES, JSON.stringify(freshRemittances));
    localStorage.setItem(STORAGE_KEYS.THIRTEENTH_MONTH, JSON.stringify(fresh13th));
    localStorage.setItem(STORAGE_KEYS.PAYDAY_TEMPLATES, JSON.stringify(freshPaydayTmpl));
    localStorage.setItem(STORAGE_KEYS.HOUSEHOLD_AMBAG, JSON.stringify(freshAmbag));
    localStorage.setItem(STORAGE_KEYS.ACTIVE_SPACE_ID, 'all');
    localStorage.setItem(STORAGE_KEYS.ACTIVE_MEMBER_ID, 'member_carla');
    localStorage.setItem(STORAGE_KEYS.DECISION_SCENARIO, 'conservative');
    localStorage.setItem(STORAGE_KEYS.ACTIVE_PROFILE, 'all');

    const freshInvestments = JSON.parse(JSON.stringify(INITIAL_INVESTMENTS));
    setInvestments(freshInvestments);
    localStorage.setItem(STORAGE_KEYS.INVESTMENTS, JSON.stringify(freshInvestments));

    setDismissedAlertIds([]);
    localStorage.setItem(STORAGE_KEYS.DISMISSED_ALERTS, JSON.stringify([]));

    setReminderSettingsState(DEFAULT_REMINDER_SETTINGS);
    localStorage.setItem(STORAGE_KEYS.REMINDER_SETTINGS, JSON.stringify(DEFAULT_REMINDER_SETTINGS));
    setSentNotificationTags([]);
    localStorage.setItem(STORAGE_KEYS.SENT_REMINDER_TAGS, JSON.stringify([]));
  };

  return (
    <FinancialContext.Provider
      value={{
        themeMode,
        toggleTheme,
        setThemeMode,
        activeProfile,
        setActiveProfile,
        isOnboarded,
        completeOnboarding,
        restartOnboarding,
        applyStarterPack,
        transactions,
        accounts,
        debts,
        budgets,
        upcoming,
        goals,
        payday,
        reconciliationHistory,
        categories,
        bills,
        installments,
        incomeStreams,
        decisionScenario,
        safeToSpendAnalysis,
        healthCheckInsights,
        totalAssets,
        totalLiabilities,
        totalCreditUsed,
        totalDebtsIOwe,
        totalDebtsOwedToMe,
        netWorth,
        safeToSpend,
        safeToSpendPerDay,
        addTransaction,
        updateTransaction,
        deleteTransaction,
        changeTransactionStatus,
        createAdjustmentTransaction,
        recordReconciliation,
        addBill,
        updateBill,
        deleteBill,
        markBillPaid,
        addInstallment,
        updateInstallment,
        deleteInstallment,
        recordInstallmentPayment,
        recordInstallmentExtraPayment,
        addIncomeStream,
        updateIncomeStream,
        deleteIncomeStream,
        setDecisionScenario,
        getCategoryTransactionCount,
        addMainCategory,
        addSubcategory,
        deleteMainCategory,
        deleteSubcategory,
        addAccount,
        updateAccount,
        deleteAccount,
        addDebt,
        recordDebtPayment,
        toggleDebtSettled,
        updateBudgetLimit,
        addBudget,
        deleteBudget,
        updatePayday,
        addUpcoming,
        deleteUpcoming,
        markUpcomingPaid,
        addGoal,
        contributeToGoal,
        resetToSampleData,
        reminderSettings,
        updateReminderSettings,
        notifications,
        unreadNotificationsCount,
        markNotificationRead,
        markAllNotificationsRead,
        clearNotification,
        clearAllNotifications,
        triggerSimulatedReminder,
        activeToasts,
        dismissToast,
        requestWebNotificationPermission,
        webNotificationPermission,
        spaces,
        activeSpaceId,
        activeSpace,
        setActiveSpaceId,
        members,
        activeMemberId,
        activeMember,
        switchActiveMember,
        createSpace,
        updateSpace,
        deleteSpace,
        addMember,
        updateMemberRole,
        revokeMemberAccess,
        addTransactionComment,
        approveTransaction,
        rejectTransaction,
        attachReceiptToTransaction,
        removeReceiptFromTransaction,
        expenseSplits,
        createExpenseSplit,
        recordSplitSettlement,
        deleteExpenseSplit,
        auditLogs,
        addAuditLogEntry,
        exportAuditLogCsv,
        pendingApprovalsCount,
        remittances,
        thirteenthMonthPlan,
        paydayTemplates,
        householdAmbag,
        addRemittance,
        updateRemittance,
        deleteRemittance,
        update13thMonthPlan,
        update13thMonthAllocations,
        applyPaydayRoutine,
        updateHouseholdAmbagPool,
        recordHouseholdAmbagPayment,
        calculateFreelanceTaxProvision,
        investments,
        portfolioSummary,
        addInvestmentAsset,
        updateInvestmentAsset,
        deleteInvestmentAsset,
        recordInvestmentActivity,
        updateAssetValuation,
        controlCenterAlerts,
        dismissControlCenterAlert,
        financialCloseRecords,
        performFinancialClose,
        decisionJournal,
        addDecisionJournalEntry,
        updateDecisionJournalOutcome,
        adviserSession,
        toggleAdviserMode,
        toggleAdviserMaskBalances,
      }}
    >
      {children}
    </FinancialContext.Provider>
  );
};

export const useFinancial = () => {
  const context = useContext(FinancialContext);
  if (!context) {
    throw new Error('useFinancial must be used within a FinancialProvider');
  }
  return context;
};
