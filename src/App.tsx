import React, { useState } from 'react';
import { FinancialProvider, useFinancial } from './context/FinancialContext';
import { Header } from './components/Header';
import { HeroPanel } from './components/HeroPanel';
import { QuickActions } from './components/QuickActions';
import { DebtBeamCard } from './components/DebtBeamCard';
import { ComingUpCard } from './components/ComingUpCard';
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
import { TransactionType, AppNotification, Transaction } from './types';
import { Bell, Sparkles, Send, Gift, Home, Calculator } from 'lucide-react';

function SalapifyMain() {
  const { themeMode, isOnboarded } = useFinancial();
  const [currentTab, setCurrentTab] = useState<TabType>('home');
  const [planInitialSegment, setPlanInitialSegment] = useState<'budget' | 'upcoming' | 'goals' | 'decision'>('budget');
  const [isViewingDebtScreen, setIsViewingDebtScreen] = useState(false);
  const [isLogOpen, setIsLogOpen] = useState(false);
  const [logInitialType, setLogInitialType] = useState<TransactionType>('expense');
  const [isAddDebtOpen, setIsAddDebtOpen] = useState(false);
  const [isBillsOpen, setIsBillsOpen] = useState(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [isInfoOpen, setIsInfoOpen] = useState(false);
  const [isTaxCalculatorOpen, setIsTaxCalculatorOpen] = useState(false);
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
      setPlanInitialSegment('budget');
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

              {/* 4 Quick Actions in one row */}
              <QuickActions
                onOpenLog={() => handleOpenLog('expense')}
                onOpenDebt={handleOpenDebt}
                onOpenBills={() => setIsBillsOpen(true)}
                onOpenMove={() => setIsTransferOpen(true)}
              />

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
              <div className="p-3 sm:p-3.5 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] shadow-xs flex items-center justify-between gap-3">
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
              </div>

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
              onOpenBills={() => setIsBillsOpen(true)}
              onOpenDebt={handleOpenDebt}
            />
          ) : (
            <AccountsScreen onOpenDebt={handleOpenDebt} />
          )}
        </main>

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
              setPlanInitialSegment('budget');
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
