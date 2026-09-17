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
    'remittance' | '13th_month' | 'household' | 'payday_routine' | 'freelance_tax'
  >('remittance');
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
      setPhilippineSuiteTab('13th_month');
      setIsPhilippineSuiteOpen(true);
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
            setPhilippineSuiteTab('remittance');
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

              {/* Budget Pulse */}
              <BudgetPulseCard
                onSeeAll={() => {
                  setPlanInitialSegment('overview');
                  setCurrentTab('plan');
                }}
              />

              {/* 4 Quick Actions in one row */}
              <QuickActions
                onOpenLog={() => handleOpenLog('expense')}
                onOpenDebt={handleOpenDebt}
                onOpenBills={() => setIsBillsOpen(true)}
                onOpenMove={() => setIsTransferOpen(true)}
              />

              {/* Pan AI Copilot Quick Launcher Card */}
              <div className="p-3.5 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] shadow-xs space-y-2.5">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <div className="w-8 h-8 rounded-xl bg-gradient-to-tr from-[#B03C09] to-[#FF9A52] text-white flex items-center justify-center shadow-xs">
                      <Bot size={17} />
                    </div>
                    <div>
                      <div className="flex items-center gap-1.5">
                        <h3 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                          Pan AI Copilot
                        </h3>
                        <span className="text-[9px] font-bold px-1.5 py-0.2 rounded-md bg-[#16643F]/15 text-[#16643F] dark:bg-[#5FCB8E]/20 dark:text-[#5FCB8E]">
                          OFFLINE
                        </span>
                      </div>
                      <p className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                        Instant answers on your balances, debts &amp; sweldo
                      </p>
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => setIsPanOpen(true)}
                    className="text-[11px] font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline cursor-pointer"
                  >
                    Chat with Pan →
                  </button>
                </div>

                <div className="flex items-center gap-1.5 overflow-x-auto pb-0.5 no-scrollbar">
                  {[
                    'Can I afford ₱1,500?',
                    'Who owes me?',
                    'Which cards are due?',
                    'Food spending this month',
                  ].map((prompt, i) => (
                    <button
                      key={i}
                      type="button"
                      onClick={() => handleOpenPan(prompt)}
                      className="px-2.5 py-1 rounded-full text-[10px] font-semibold bg-[#FFEEDF]/60 dark:bg-[#27201A] hover:bg-[#FFEEDF] dark:hover:bg-[#383029] text-[#5A5148] dark:text-[#C6B8AC] border border-[#F3DFCD] dark:border-[#383029] shrink-0 whitespace-nowrap cursor-pointer transition-colors"
                    >
                      {prompt}
                    </button>
                  ))}
                </div>
              </div>

              {/* Philippine Financial Suite Quick Launch Card */}
              <div className="p-3.5 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] shadow-xs space-y-2.5">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <div className="w-8 h-8 rounded-xl bg-[#FFEEDF] dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center font-bold text-xs">
                      🇵🇭
                    </div>
                    <div>
                      <h3 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                        Philippine Local Suite
                      </h3>
                      <p className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                        Padala, 13th-Month, Ambagan &amp; Sweldo Routines
                      </p>
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      setPhilippineSuiteTab('remittance');
                      setIsPhilippineSuiteOpen(true);
                    }}
                    className="text-[11px] font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline cursor-pointer"
                  >
                    Open Hub →
                  </button>
                </div>

                <div className="grid grid-cols-4 gap-1.5 pt-1 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60">
                  {[
                    { id: 'remittance', label: 'Padala', icon: Send },
                    { id: '13th_month', label: '13th-Month', icon: Gift },
                    { id: 'household', label: 'Ambagan', icon: Home },
                    { id: 'freelance_tax', label: '8% Tax', icon: Calculator },
                  ].map((btn) => {
                    const Icon = btn.icon;
                    return (
                      <button
                        key={btn.id}
                        type="button"
                        onClick={() => {
                          setPhilippineSuiteTab(btn.id as any);
                          setIsPhilippineSuiteOpen(true);
                        }}
                        className="py-1.5 px-1 rounded-xl bg-[#FFEEDF]/40 dark:bg-[#14100D]/60 hover:bg-[#FFEEDF] dark:hover:bg-[#383029] text-center transition-all cursor-pointer border border-[#F3DFCD]/60 dark:border-[#383029]/60"
                      >
                        <div className="flex justify-center mb-0.5 text-[#B03C09] dark:text-[#FF9A52]">
                          <Icon size={14} />
                        </div>
                        <span className="text-[10px] font-bold text-[#5A5148] dark:text-[#C6B8AC] block truncate">
                          {btn.label}
                        </span>
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Live Reminders & Simulator Action Banner */}
              <motion.div initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.4, ease: "easeOut" }} className="p-3 sm:p-3.5 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] shadow-xs flex items-center justify-between gap-3">
                <div className="flex items-center gap-2.5 min-w-0">
                  <div className="w-9 h-9 rounded-xl bg-[#FFEEDF] dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center shrink-0">
                    <Bell size={18} />
                  </div>
                  <div className="min-w-0">
                    <div className="flex items-center gap-1.5 flex-wrap">
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                        Reminders &amp; Alerts
                      </span>
                      <span className="text-[9px] font-bold px-1.5 py-0.2 rounded-md bg-amber-400 text-amber-950">
                        SIMULATOR
                      </span>
                    </div>
                    <span className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] truncate block">
                      Daily log, payment due, bill &amp; subscription reminders
                    </span>
                  </div>
                </div>

                <button
                  type="button"
                  id="open-reminders-banner-btn"
                  onClick={() => setIsRemindersOpen(true)}
                  className="px-3 py-1.5 rounded-xl text-xs font-bold bg-[#B03C09] hover:bg-[#963307] text-white dark:bg-[#FF9A52] dark:hover:bg-[#ff8a38] dark:text-[#14100D] transition-colors shrink-0 flex items-center gap-1 cursor-pointer shadow-xs"
                >
                  <Sparkles size={13} />
                  <span>Test Alerts</span>
                </button>
              </motion.div>

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

              {/* Latest Transactions */}
              <LatestTransactions
                onSeeAll={() => {
                  setCurrentTab('ledger');
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
          animate={{ scale: 1, opacity: 1 }}
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          type="button"
          id="floating-pan-btn"
          onClick={() => handleOpenPan()}
          title="Ask Pan AI Copilot"
          className="fixed bottom-20 right-4 z-30 flex items-center gap-1.5 px-3.5 py-2 rounded-full bg-gradient-to-r from-[#B03C09] to-[#E05315] dark:from-[#FF9A52] dark:to-[#E06F28] text-white dark:text-[#1E0E03] shadow-lg shadow-black/20 font-bold text-xs cursor-pointer border border-white/20 transition-transform"
        >
          <Bot size={16} strokeWidth={2.4} />
          <span>Ask Pan</span>
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
