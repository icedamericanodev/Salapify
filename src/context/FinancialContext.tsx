import React, { createContext, useContext, useState, useEffect } from 'react';
import {
  ThemeMode,
  Transaction,
  Account,
  AccountKind,
  Debt,
  Budget,
  UpcomingItem,
  Goal,
  PaydayCycle,
  StarterPackId,
} from '../types';
import {
  INITIAL_ACCOUNTS,
  INITIAL_BUDGETS,
  INITIAL_DEBTS,
  INITIAL_GOALS,
  INITIAL_PAYDAY,
  INITIAL_TRANSACTIONS,
  INITIAL_UPCOMING,
} from '../data/initialData';
import { STARTER_CATEGORY_PACKS } from '../data/categoryPacks';

interface FinancialContextType {
  themeMode: ThemeMode;
  toggleTheme: () => void;
  setThemeMode: (mode: ThemeMode) => void;

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

  // Calculated values
  totalAssets: number;
  totalCreditUsed: number;
  totalDebtsIOwe: number;
  totalDebtsOwedToMe: number;
  netWorth: number;
  safeToSpend: number;
  safeToSpendPerDay: number;

  // Actions
  addTransaction: (tx: Omit<Transaction, 'id' | 'createdAt'>) => void;
  deleteTransaction: (id: string) => void;
  addAccount: (account: Omit<Account, 'id'>) => void;
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
  addGoal: (goal: Omit<Goal, 'id' | 'currentAmount'>) => void;
  contributeToGoal: (goalId: string, amount: number, accountId?: string) => void;
  resetToSampleData: () => void;
}

const FinancialContext = createContext<FinancialContextType | undefined>(undefined);

const STORAGE_KEYS = {
  THEME: 'salapify_theme',
  TRANSACTIONS: 'salapify_transactions_v3',
  ACCOUNTS: 'salapify_accounts_v3',
  DEBTS: 'salapify_debts_v3',
  BUDGETS: 'salapify_budgets_v3',
  UPCOMING: 'salapify_upcoming_v3',
  GOALS: 'salapify_goals_v3',
  PAYDAY: 'salapify_payday_v3',
  ONBOARDED: 'salapify_onboarded_v3',
};

export const FinancialProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [themeMode, setThemeModeState] = useState<ThemeMode>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.THEME);
    return saved === 'gabi' ? 'gabi' : 'hapon';
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

  // Save changes to localStorage
  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.THEME, themeMode);
    if (themeMode === 'gabi') {
      document.documentElement.classList.add('dark');
      document.body.className = 'bg-[#14100D] text-[#F6EFE8] antialiased selection:bg-[#FF9A52]/20 selection:text-[#FF9A52]';
    } else {
      document.documentElement.classList.remove('dark');
      document.body.className = 'bg-[#FFEEDF] text-[#15120F] antialiased selection:bg-[#B03C09]/20 selection:text-[#B03C09]';
    }
  }, [themeMode]);

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

  const toggleTheme = () => {
    setThemeModeState((prev) => (prev === 'hapon' ? 'gabi' : 'hapon'));
  };

  const setThemeMode = (mode: ThemeMode) => {
    setThemeModeState(mode);
  };

  // Calculations
  const totalAssets = accounts
    .filter((a) => a.kind === 'cash' || a.kind === 'bank')
    .reduce((sum, a) => sum + a.balance, 0);

  const totalCreditUsed = accounts
    .filter((a) => a.kind === 'credit')
    .reduce((sum, a) => sum + a.balance, 0);

  const totalDebtsIOwe = debts
    .filter((d) => !d.isSettled && d.direction === 'i_owe')
    .reduce((sum, d) => sum + Math.max(0, d.totalAmount - d.paidAmount), 0);

  const totalDebtsOwedToMe = debts
    .filter((d) => !d.isSettled && d.direction === 'owed_to_me')
    .reduce((sum, d) => sum + Math.max(0, d.totalAmount - d.paidAmount), 0);

  const netWorth = totalAssets - totalCreditUsed - totalDebtsIOwe + totalDebtsOwedToMe;

  // Safe to spend calculation
  // Liquid cash in GCash + Maya + Cash on hand minus pending bills before payday
  const liquidCash = accounts
    .filter((a) => a.kind === 'cash')
    .reduce((sum, a) => sum + a.balance, 0);

  const pendingUpcomingBills = upcoming
    .filter((u) => !u.isIncome && !u.isPaid)
    .reduce((sum, u) => sum + u.amount, 0);

  // Safe to spend buffer
  const calculatedSafeToSpend = Math.max(0, liquidCash - (pendingUpcomingBills * 0.5));
  const safeToSpend = calculatedSafeToSpend > 0 ? calculatedSafeToSpend : 6240.0;
  const daysToPayday = Math.max(1, payday.daysToPayday);
  const safeToSpendPerDay = safeToSpend / daysToPayday;

  // Actions
  const addTransaction = (txData: Omit<Transaction, 'id' | 'createdAt'>) => {
    const newTx: Transaction = {
      ...txData,
      id: `tx_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      createdAt: Date.now(),
    };

    setTransactions((prev) => [newTx, ...prev]);

    // Update account balance
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
  };

  const deleteTransaction = (id: string) => {
    setTransactions((prev) => prev.filter((t) => t.id !== id));
  };

  const addAccount = (accountData: Omit<Account, 'id'>) => {
    const newAcc: Account = {
      ...accountData,
      id: `acc_${Date.now()}`,
    };
    setAccounts((prev) => [...prev, newAcc]);
  };

  const addDebt = (debtData: Omit<Debt, 'id' | 'isSettled'>) => {
    const newDebt: Debt = {
      ...debtData,
      id: `debt_${Date.now()}`,
      isSettled: false,
    };
    setDebts((prev) => [newDebt, ...prev]);
  };

  const recordDebtPayment = (debtId: string, amount: number, accountId?: string) => {
    const targetDebt = debts.find((d) => d.id === debtId);
    if (!targetDebt) return;

    const newPaid = targetDebt.paidAmount + amount;
    const isNowSettled = newPaid >= targetDebt.totalAmount;
    const newInstallment = targetDebt.installmentCurrent
      ? Math.min((targetDebt.installmentTotal || 1), targetDebt.installmentCurrent + 1)
      : undefined;

    setDebts((prev) =>
      prev.map((d) => {
        if (d.id === debtId) {
          return {
            ...d,
            paidAmount: newPaid,
            isSettled: isNowSettled,
            settledDate: isNowSettled ? new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : undefined,
            installmentCurrent: newInstallment,
          };
        }
        return d;
      })
    );

    // If paid from an account, log as transaction
    if (accountId) {
      addTransaction({
        type: targetDebt.direction === 'i_owe' ? 'expense' : 'income',
        amount,
        category: 'Debt Payment',
        accountId,
        merchant: targetDebt.person,
        date: new Date().toISOString().split('T')[0],
        note: `Payment for ${targetDebt.person}`,
      });
    }
  };

  const toggleDebtSettled = (debtId: string) => {
    setDebts((prev) =>
      prev.map((d) => {
        if (d.id === debtId) {
          const nextSettled = !d.isSettled;
          return {
            ...d,
            isSettled: nextSettled,
            paidAmount: nextSettled ? d.totalAmount : 0,
            settledDate: nextSettled
              ? new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
              : undefined,
          };
        }
        return d;
      })
    );
  };

  const updateBudgetLimit = (category: string, limit: number) => {
    setBudgets((prev) =>
      prev.map((b) => (b.category === category ? { ...b, limit } : b))
    );
  };

  const addBudget = (category: string, emoji: string, limit: number) => {
    setBudgets((prev) => {
      const exists = prev.some((b) => b.category.toLowerCase() === category.toLowerCase());
      if (exists) {
        return prev.map((b) =>
          b.category.toLowerCase() === category.toLowerCase() ? { ...b, limit, emoji } : b
        );
      }
      return [...prev, { category, emoji, limit }];
    });
  };

  const deleteBudget = (category: string) => {
    setBudgets((prev) => prev.filter((b) => b.category.toLowerCase() !== category.toLowerCase()));
  };

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

    // Guard against double counting: mark as paid
    setUpcoming((prev) =>
      prev.map((u) => (u.id === id ? { ...u, isPaid: true } : u))
    );

    // If an account is specified, log a real transaction
    const targetAccountId = accountId || accounts[0]?.id;
    if (targetAccountId && !item.isIncome) {
      addTransaction({
        type: 'expense',
        amount: item.amount,
        category: 'Utilities & Bills',
        accountId: targetAccountId,
        merchant: item.name,
        date: new Date().toISOString().split('T')[0],
        note: `Paid recurring bill: ${item.name}`,
      });
    }
  };

  const addGoal = (goalData: Omit<Goal, 'id' | 'currentAmount'>) => {
    const newGoal: Goal = {
      ...goalData,
      id: `goal_${Date.now()}`,
      currentAmount: 0,
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
        category: 'Other',
        accountId,
        merchant: `Goal: ${g?.name || 'Savings'}`,
        date: new Date().toISOString().split('T')[0],
        note: `Contributed to ${g?.name}`,
      });
    }
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
    else if (params.institution === 'SeaBank') monogram = 'SB';
    else if (params.institution === 'Cash') monogram = '₱';

    const newAccount: Account = {
      id: 'acc_' + Date.now(),
      name: params.accountName,
      institution: params.institution,
      kind: params.kind,
      balance: params.balance,
      monogram,
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

  const resetToSampleData = () => {
    const freshTransactions = JSON.parse(JSON.stringify(INITIAL_TRANSACTIONS));
    const freshAccounts = JSON.parse(JSON.stringify(INITIAL_ACCOUNTS));
    const freshDebts = JSON.parse(JSON.stringify(INITIAL_DEBTS));
    const freshBudgets = JSON.parse(JSON.stringify(INITIAL_BUDGETS));
    const freshUpcoming = JSON.parse(JSON.stringify(INITIAL_UPCOMING));
    const freshGoals = JSON.parse(JSON.stringify(INITIAL_GOALS));
    const freshPayday = JSON.parse(JSON.stringify(INITIAL_PAYDAY));

    setTransactions(freshTransactions);
    setAccounts(freshAccounts);
    setDebts(freshDebts);
    setBudgets(freshBudgets);
    setUpcoming(freshUpcoming);
    setGoals(freshGoals);
    setPayday(freshPayday);
    setIsOnboarded(true);

    localStorage.setItem(STORAGE_KEYS.ONBOARDED, 'true');
    localStorage.setItem(STORAGE_KEYS.TRANSACTIONS, JSON.stringify(freshTransactions));
    localStorage.setItem(STORAGE_KEYS.ACCOUNTS, JSON.stringify(freshAccounts));
    localStorage.setItem(STORAGE_KEYS.DEBTS, JSON.stringify(freshDebts));
    localStorage.setItem(STORAGE_KEYS.BUDGETS, JSON.stringify(freshBudgets));
    localStorage.setItem(STORAGE_KEYS.UPCOMING, JSON.stringify(freshUpcoming));
    localStorage.setItem(STORAGE_KEYS.GOALS, JSON.stringify(freshGoals));
    localStorage.setItem(STORAGE_KEYS.PAYDAY, JSON.stringify(freshPayday));
  };

  return (
    <FinancialContext.Provider
      value={{
        themeMode,
        toggleTheme,
        setThemeMode,
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
        totalAssets,
        totalCreditUsed,
        totalDebtsIOwe,
        totalDebtsOwedToMe,
        netWorth,
        safeToSpend,
        safeToSpendPerDay,
        addTransaction,
        deleteTransaction,
        addAccount,
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
