import React, { useState } from 'react';
import { motion } from 'motion/react';
import { FinancialProvider, useFinancial } from './context/FinancialContext';
import { Header } from './components/Header';
import { HeroPanel } from './components/HeroPanel';
import { QuickActions } from './components/QuickActions';
import { DebtBeamCard } from './components/DebtBeamCard';
import { ComingUpCard } from './components/ComingUpCard';
import { BudgetPulseCard } from './components/BudgetPulseCard';
import { LatestTransactions } from './components/LatestTransactions';
import { TabBar, TabType } from './components/TabBar';
import { LogSheet } from './components/LogSheet';
import { DebtScreen } from './components/DebtScreen';
import { LedgerScreen } from './components/LedgerScreen';
import { ReportsScreen } from './components/ReportsScreen';
import { PlanScreen } from './components/PlanScreen';
import { AccountsScreen } from './components/AccountsScreen';
import { AddDebtModal } from './components/AddDebtModal';
import { SettingsModal } from './components/SettingsModal';
import { InfoModal } from './components/InfoModal';
import { OnboardingFlow } from './components/OnboardingFlow';
import { TaxCalculatorModal } from './components/TaxCalculatorModal';
import { BusinessTaxSimulatorModal } from './components/BusinessTaxSimulatorModal';
import { SavingsInvestmentModal } from './components/SavingsInvestmentModal';
import { TransferModal } from './components/TransferModal';
import { YourSetupModal } from './components/YourSetupModal';
import { SplitBillModal } from './components/SplitBillModal';
import { BillsModal } from './components/BillsModal';
import { RemindersModal } from './components/RemindersModal';
import { NotificationToast } from './components/NotificationToast';
import { SafeToSpendModal } from './components/SafeToSpendModal';
import { HealthCheckModal } from './components/HealthCheckModal';
import { CollaborationHub } from './components/CollaborationHub';
import { TransactionDetailModal } from './components/TransactionDetailModal';
import { PhilippineFeaturesModal } from './components/PhilippineFeaturesModal';
import { PetsaDePeligroCard } from './components/PetsaDePeligroCard';
import { DigitalBankYieldCard } from './components/DigitalBankYieldCard';
import { PanChatModal } from './components/PanChatModal';
import { OfflineRegistryModal } from './components/OfflineRegistryModal';
import { TransactionType, AppNotification, Transaction } from './types';
import { Bell, Sparkles, Send, Gift, Home, Calculator, Bot } from 'lucide-react';

function SalapifyMain() {
  const { themeMode, isOnboarded } = useFinancial();
  const [currentTab, setCurrentTab] = useState<TabType>('home');
  const [planInitialSegment, setPlanInitialSegment] = useState<'overview' | 'budget' | 'upcoming' | 'goals' | 'decision' | 'trackers' | 'calculators' | 'academy'>('overview');
  const [academyInitialMode, setAcademyInitialMode] = useState<'courses' | 'startup_guide'>('courses');
  const [startupGuideInitialTab, setStartupGuideInitialTab] = useState<'entities' | 'roadmap' | 'checklist' | 'experts' | 'saas'>('roadmap');
  const [saasLaunchpadInitialSubTab, setSaasLaunchpadInitialSubTab] = useState<'overview' | 'stores' | 'billing' | 'taxation' | 'survival' | 'calculator'>('overview');
  const [isViewingDebtScreen, setIsViewingDebtScreen] = useState(false);
  const [isLogOpen, setIsLogOpen] = useState(false);
  const [logInitialType, setLogInitialType] = useState<TransactionType>('expense');
  const [isAddDebtOpen, setIsAddDebtOpen] = useState(false);
  const [isBillsOpen, setIsBillsOpen] = useState(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [isInfoOpen, setIsInfoOpen] = useState(false);
  const [isTaxCalculatorOpen, setIsTaxCalculatorOpen] = useState(false);
  const [isBusinessSimulatorOpen, setIsBusinessSimulatorOpen] = useState(false);
  const [isSavingsPlannerOpen, setIsSavingsPlannerOpen] = useState(false);
  const [isTransferOpen, setIsTransferOpen] = useState(false);
  const [isSetupOpen, setIsSetupOpen] = useState(false);
  const [setupInitialTab, setSetupInitialTab] = useState<'payday' | 'categories' | 'recurring' | 'emergency' | 'privacy'>('payday');
  const [isSplitBillOpen, setIsSplitBillOpen] = useState(false);
  const [isRemindersOpen, setIsRemindersOpen] = useState(false);
  const [isSafeToSpendOpen, setIsSafeToSpendOpen] = useState(false);
  const [isHealthCheckOpen, setIsHealthCheckOpen] = useState(false);
  const [isCollaborationOpen, setIsCollaborationOpen] = useState(false);
  const [selectedTxForDetail, setSelectedTxForDetail] = useState<Transaction | null>(null);
  const [isPhilippineSuiteOpen, setIsPhilippineSuiteOpen] = useState(false);
  const [philippineSuiteTab, setPhilippineSuiteTab] = useState<
    'calculator' | 'mindset' | 'treats' | 'fx'
  >('fx');
  const [isPanOpen, setIsPanOpen] = useState(false);
  const [panInitialPrompt, setPanInitialPrompt] = useState<string | undefined>(undefined);
  const [isOfflineRegistryOpen, setIsOfflineRegistryOpen] = useState(false);

  const handleOpenPan = (prompt?: string) => {
    setPanInitialPrompt(prompt);
    setIsPanOpen(true);
  };

  const handlePanNavigate = (actionId: string, payload?: any) => {
    if (actionId === 'open_safe_to_spend') {
      setIsSafeToSpendOpen(true);
    } else if (actionId === 'open_log_expense') {
      handleOpenLog('expense');
    } else if (actionId === 'open_debt') {
      handleOpenDebt();
    } else if (actionId === 'open_bills') {
      setIsBillsOpen(true);
    } else if (actionId === 'open_transfer') {
      setIsTransferOpen(true);
    } else if (actionId === 'open_split_bill') {
      setIsSplitBillOpen(true);
    } else if (actionId === 'open_13th_month') {
      setIsTaxCalculatorOpen(true);
    } else if (actionId === 'open_savings_planner') {
      setIsSavingsPlannerOpen(true);
    } else if (actionId === 'open_tax_calc') {
      setIsTaxCalculatorOpen(true);
    } else if (actionId === 'open_accounts') {
      setIsViewingDebtScreen(false);
      setCurrentTab('accounts');
    } else if (actionId === 'open_ledger') {
      setIsViewingDebtScreen(false);
      setCurrentTab('ledger');
    } else if (actionId === 'open_reports') {
      setIsViewingDebtScreen(false);
      setCurrentTab('reports');
    } else if (actionId === 'open_academy') {
      setIsViewingDebtScreen(false);
      setPlanInitialSegment('academy');
      setAcademyInitialMode('courses');
      setCurrentTab('plan');
    } else if (actionId === 'open_startup_guide') {
      setIsViewingDebtScreen(false);
      setPlanInitialSegment('academy');
      setAcademyInitialMode('startup_guide');
      setStartupGuideInitialTab(payload?.tab || 'roadmap');
      setCurrentTab('plan');
    } else if (actionId === 'open_startup_guide_saas') {
      setIsViewingDebtScreen(false);
      setPlanInitialSegment('academy');
      setAcademyInitialMode('startup_guide');
      setStartupGuideInitialTab('saas');
      setSaasLaunchpadInitialSubTab(payload?.subTab || 'overview');
      setCurrentTab('plan');
    } else if (actionId === 'open_plan_trackers') {
      setIsViewingDebtScreen(false);
      setPlanInitialSegment('trackers');
      setCurrentTab('plan');
    } else if (actionId === 'open_plan_decision') {
      setIsViewingDebtScreen(false);
      setPlanInitialSegment('decision');
      setCurrentTab('plan');
    } else if (actionId === 'open_plan_calculators') {
      setIsViewingDebtScreen(false);
      setPlanInitialSegment('calculators');
      setCurrentTab('plan');
    } else if (actionId === 'open_settings') {
      setIsSettingsOpen(true);
    } else if (actionId === 'open_setup_privacy') {
      setSetupInitialTab('privacy');
      setIsSetupOpen(true);
    } else if (actionId === 'open_offline_registry') {
      setIsOfflineRegistryOpen(true);
    }
  };

  if (!isOnboarded) {
    return <OnboardingFlow />;
  }

  const handleOpenLog = (type: TransactionType = 'expense') => {
    setLogInitialType(type);
    setIsLogOpen(true);
  };

  const handleOpenDebt = () => {
    setIsViewingDebtScreen(true);
  };

  const handleSelectTab = (tab: TabType) => {
    setIsViewingDebtScreen(false);
    if (tab === 'plan') {
      setPlanInitialSegment('overview');
    }
    setCurrentTab(tab);
  };

  const handleToastAction = (notification: AppNotification) => {
    if (notification.actionType === 'open_log_expense') {
      handleOpenLog('expense');
    } else if (notification.actionType === 'open_bills') {
      setIsBillsOpen(true);
    } else if (notification.actionType === 'open_debts') {
      handleOpenDebt();
    } else if (notification.actionType === 'open_installments') {
      setIsBillsOpen(true);
    } else {
      setIsRemindersOpen(true);
    }
  };

  const isDark = themeMode === 'gabi';

  return (
    <div
      data-theme={themeMode}
      className={`min-h-screen flex flex-col transition-colors duration-200 ${
        isDark ? 'dark bg-[#14100D] text-[#F6EFE8]' : 'bg-[#FFEEDF] text-[#15120F]'
      }`}
    >
      {/* Floating Notification Toasts */}
      <NotificationToast onActionClick={handleToastAction} />

      {/* Mobile-first centered container */}
      <div className="w-full max-w-md mx-auto px-4 py-2 flex flex-col min-h-screen relative">
        {/* Header */}
        <Header
          onOpenSettings={() => setIsSettingsOpen(true)}
          onOpenInfo={() => setIsInfoOpen(true)}
          onOpenReminders={() => setIsRemindersOpen(true)}
          onOpenCollaboration={() => setIsCollaborationOpen(true)}
          onOpenPhilippineSuite={() => {
            setPhilippineSuiteTab('fx');
            setIsPhilippineSuiteOpen(true);
          }}
          onOpenPan={() => handleOpenPan()}
        />

        {/* Tab / View Content */}
        <main className="flex-1 flex flex-col pt-1">
          {isViewingDebtScreen ? (
            <DebtScreen
              onBack={() => setIsViewingDebtScreen(false)}
              onOpenAddDebt={() => setIsAddDebtOpen(true)}
              onOpenSplitBill={() => setIsSplitBillOpen(true)}
            />
          ) : currentTab === 'home' ? (
            <div className="flex flex-col gap-4 pb-36">
              {/* The Hero Panel with Sweldo Rail */}
              <HeroPanel
                onOpenSafeToSpend={() => setIsSafeToSpendOpen(true)}
                onOpenHealthCheck={() => setIsHealthCheckOpen(true)}
              />

              {/* Petsa de Peligro Survival Shield & Luho Jar */}
              <PetsaDePeligroCard
                onOpenLog={(amount, category, note) => {
                  handleOpenLog('expense');
                }}
                onOpenSafeToSpend={() => setIsSafeToSpendOpen(true)}
                onOpenPan={(prompt) => handleOpenPan(prompt)}
              />

              {/* 4 Quick Actions in one row */}
              <QuickActions
                onOpenLog={() => handleOpenLog('expense')}
                onOpenDebt={handleOpenDebt}
                onOpenBills={() => setIsBillsOpen(true)}
                onOpenMove={() => setIsTransferOpen(true)}
              />

              {/* Latest Transactions immediately following Quick Actions */}
              <LatestTransactions
                onSeeAll={() => {
                  setCurrentTab('ledger');
                }}
              />

              {/* Budget Pulse */}
              <BudgetPulseCard
                onSeeAll={() => {
                  setPlanInitialSegment('overview');
                  setCurrentTab('plan');
                }}
              />

              {/* Debt Beam Card */}
              <DebtBeamCard onSeeAll={handleOpenDebt} />

              {/* Coming Up Card */}
              <ComingUpCard
                onSeeAll={() => {
                  setPlanInitialSegment('upcoming');
                  setCurrentTab('plan');
                }}
                onOpenBills={() => setIsBillsOpen(true)}
              />

              {/* Digital Bank Yield Ladder (SeaBank, Maya, GoTyme, Tonik) */}
              <DigitalBankYieldCard
                onOpenPhilippineSuite={() => {
                  setPhilippineSuiteTab('calculator');
                  setIsPhilippineSuiteOpen(true);
                }}
              />
            </div>
          ) : currentTab === 'ledger' ? (
            <LedgerScreen />
          ) : currentTab === 'reports' ? (
            <ReportsScreen />
          ) : currentTab === 'plan' ? (
            <PlanScreen
              initialSegment={planInitialSegment}
              initialAcademyMode={academyInitialMode}
              initialStartupTab={startupGuideInitialTab}
              initialSaasSubTab={saasLaunchpadInitialSubTab}
              onOpenBills={() => setIsBillsOpen(true)}
              onOpenDebt={handleOpenDebt}
              onOpenTaxCalculator={() => setIsTaxCalculatorOpen(true)}
              onOpenBusiness={() => setIsBusinessSimulatorOpen(true)}
              onOpenSavingsPlanner={() => setIsSavingsPlannerOpen(true)}
            />
          ) : (
            <AccountsScreen onOpenDebt={handleOpenDebt} />
          )}
        </main>

        {/* Floating Pan AI Copilot Launcher */}
        <motion.button
          initial={{ scale: 0, opacity: 0 }}
          animate={{
            scale: [1, 1.04, 1],
            boxShadow: [
              '0 10px 15px -3px rgba(0, 0, 0, 0.2), 0 0 0 0 rgba(176, 60, 9, 0.4)',
              '0 12px 20px -3px rgba(0, 0, 0, 0.25), 0 0 0 6px rgba(176, 60, 9, 0)',
              '0 10px 15px -3px rgba(0, 0, 0, 0.2), 0 0 0 0 rgba(176, 60, 9, 0)',
            ],
            opacity: 1,
          }}
          transition={{
            scale: {
              duration: 2.6,
              repeat: Infinity,
              ease: 'easeInOut',
            },
            boxShadow: {
              duration: 2.6,
              repeat: Infinity,
              ease: 'easeInOut',
            },
            opacity: { duration: 0.3 },
          }}
          whileHover={{ scale: 1.08 }}
          whileTap={{ scale: 0.95 }}
          type="button"
          id="floating-pan-btn"
          onClick={() => handleOpenPan()}
          title="Ask Pan AI Copilot"
          className="fixed bottom-20 right-4 z-30 flex items-center gap-1.5 px-3.5 py-2 rounded-full bg-gradient-to-r from-[#B03C09] to-[#E05315] dark:from-[#FF9A52] dark:to-[#E06F28] text-white dark:text-[#1E0E03] shadow-lg shadow-black/20 font-bold text-xs cursor-pointer border border-white/20"
        >
          <Bot size={16} strokeWidth={2.4} />
          <span>Ask Pan</span>
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-300 dark:bg-emerald-950 animate-pulse ml-0.5" />
        </motion.button>

        {/* Fixed TabBar */}
        <TabBar
          currentTab={isViewingDebtScreen ? 'accounts' : currentTab}
          onSelectTab={handleSelectTab}
          onOpenLog={() => handleOpenLog('expense')}
        />

        {/* Payday-Aware Safe-to-Spend Multi-Scenario Modal (Phase 3) */}
        <SafeToSpendModal
          isOpen={isSafeToSpendOpen}
          onClose={() => setIsSafeToSpendOpen(false)}
        />

        {/* Money Health Check Explanatory Diagnostic Modal (Phase 3) */}
        <HealthCheckModal
          isOpen={isHealthCheckOpen}
          onClose={() => setIsHealthCheckOpen(false)}
          onNavigateTo={(target) => {
            setIsHealthCheckOpen(false);
            if (target === 'bills') {
              setIsBillsOpen(true);
            } else if (target === 'debt') {
              handleOpenDebt();
            } else if (target === 'plan-budget') {
              setPlanInitialSegment('overview');
              setCurrentTab('plan');
            } else if (target === 'decision') {
              setPlanInitialSegment('decision');
              setCurrentTab('plan');
            } else if (target === 'reports-reconciliation') {
              setCurrentTab('reports');
            }
          }}
        />

        {/* Reminders & Notifications Modal (Phase 5 Simulator) */}
        <RemindersModal
          isOpen={isRemindersOpen}
          onClose={() => setIsRemindersOpen(false)}
          onOpenLogExpense={() => handleOpenLog('expense')}
          onOpenBills={() => setIsBillsOpen(true)}
          onOpenDebts={handleOpenDebt}
          onOpenInstallments={() => setIsBillsOpen(true)}
        />

        {/* 250ms Glide-Up Log Sheet */}
        <LogSheet
          isOpen={isLogOpen}
          onClose={() => setIsLogOpen(false)}
          initialType={logInitialType}
        />

        {/* Bills & Scheduled Payables Modal */}
        <BillsModal
          isOpen={isBillsOpen}
          onClose={() => setIsBillsOpen(false)}
        />

        {/* Add Debt Modal */}
        <AddDebtModal
          isOpen={isAddDebtOpen}
          onClose={() => setIsAddDebtOpen(false)}
        />

        {/* Settings Modal */}
        <SettingsModal
          isOpen={isSettingsOpen}
          onClose={() => setIsSettingsOpen(false)}
          onOpenTaxCalculator={() => setIsTaxCalculatorOpen(true)}
          onOpenYourSetup={(tab) => {
            setSetupInitialTab(tab || 'payday');
            setIsSetupOpen(true);
          }}
          onOpenReminders={() => setIsRemindersOpen(true)}
          onOpenCollaboration={() => setIsCollaborationOpen(true)}
          onOpenOfflineRegistry={() => setIsOfflineRegistryOpen(true)}
        />

        {/* Phase 5 Shared Finances & Collaboration Hub */}
        <CollaborationHub
          isOpen={isCollaborationOpen}
          onClose={() => setIsCollaborationOpen(false)}
          onOpenSplitBill={() => setIsSplitBillOpen(true)}
          onOpenTransactionDetail={(tx) => setSelectedTxForDetail(tx)}
        />

        {/* Transaction Detail, Comments, Receipts & Approvals Modal */}
        <TransactionDetailModal
          transaction={selectedTxForDetail}
          isOpen={!!selectedTxForDetail}
          onClose={() => setSelectedTxForDetail(null)}
        />

        {/* Your Setup Hub & Payday Editor */}
        <YourSetupModal
          isOpen={isSetupOpen}
          onClose={() => setIsSetupOpen(false)}
          initialTab={setupInitialTab}
          onOpenTaxCalculator={() => setIsTaxCalculatorOpen(true)}
          onOpenOfflineRegistry={() => setIsOfflineRegistryOpen(true)}
        />

        {/* Dedicated Fast Transfer Modal */}
        <TransferModal
          isOpen={isTransferOpen}
          onClose={() => setIsTransferOpen(false)}
        />

        {/* Barkada Split Bill & Pahiram Modal */}
        <SplitBillModal
          isOpen={isSplitBillOpen}
          onClose={() => setIsSplitBillOpen(false)}
        />

        {/* Tax Calculator Modal (CPA & Tax Advisory) */}
        <TaxCalculatorModal
          isOpen={isTaxCalculatorOpen}
          onClose={() => setIsTaxCalculatorOpen(false)}
        />
        {/* Business & Pricing Simulator */}
        <BusinessTaxSimulatorModal
          isOpen={isBusinessSimulatorOpen}
          onClose={() => setIsBusinessSimulatorOpen(false)}
        />
        {/* Savings & Investment Planner */}
        <SavingsInvestmentModal
          isOpen={isSavingsPlannerOpen}
          onClose={() => setIsSavingsPlannerOpen(false)}
        />

        {/* Info Modal */}
        <InfoModal
          isOpen={isInfoOpen}
          onClose={() => setIsInfoOpen(false)}
        />

        {/* Phase 6 Philippine Local Financial Suite Modal */}
        <PhilippineFeaturesModal
          isOpen={isPhilippineSuiteOpen}
          onClose={() => setIsPhilippineSuiteOpen(false)}
          defaultTab={philippineSuiteTab}
        />

        {/* Pan AI Copilot Chatbot Modal */}
        <PanChatModal
          isOpen={isPanOpen}
          onClose={() => {
            setIsPanOpen(false);
            setPanInitialPrompt(undefined);
          }}
          onNavigateTo={handlePanNavigate}
          initialQuery={panInitialPrompt}
        />

        {/* System Limitations & Offline Registry Modal */}
        <OfflineRegistryModal
          isOpen={isOfflineRegistryOpen}
          onClose={() => setIsOfflineRegistryOpen(false)}
          onNavigateAction={handlePanNavigate}
        />
      </div>
    </div>
  );
}

export default function App() {
  return (
    <FinancialProvider>
      <SalapifyMain />
    </FinancialProvider>
  );
}
