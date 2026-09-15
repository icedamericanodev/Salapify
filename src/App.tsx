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
import { TransactionType } from './types';

function SalapifyMain() {
  const { themeMode, isOnboarded } = useFinancial();
  const [currentTab, setCurrentTab] = useState<TabType>('home');
  const [planInitialSegment, setPlanInitialSegment] = useState<'budget' | 'upcoming' | 'goals'>('budget');
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

  const isDark = themeMode === 'gabi';

  return (
    <div
      data-theme={themeMode}
      className={`min-h-screen flex flex-col transition-colors duration-200 ${
        isDark ? 'dark bg-[#14100D] text-[#F6EFE8]' : 'bg-[#FFEEDF] text-[#15120F]'
      }`}
    >
      {/* Mobile-first centered container */}
      <div className="w-full max-w-md mx-auto px-4 py-2 flex flex-col min-h-screen relative">
        {/* Header */}
        <Header
          onOpenSettings={() => setIsSettingsOpen(true)}
          onOpenInfo={() => setIsInfoOpen(true)}
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
            <div className="flex flex-col gap-4 pb-24">
              {/* The Hero Panel with Sweldo Rail */}
              <HeroPanel />

              {/* 4 Quick Actions in one row */}
              <QuickActions
                onOpenLog={() => handleOpenLog('expense')}
                onOpenDebt={handleOpenDebt}
                onOpenBills={() => setIsBillsOpen(true)}
                onOpenMove={() => setIsTransferOpen(true)}
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

              {/* Latest Transactions */}
              <LatestTransactions
                onSeeAll={() => {
                  setCurrentTab('ledger');
                }}
              />
            </div>
          ) : currentTab === 'ledger' ? (
            <LedgerScreen />
          ) : currentTab === 'plan' ? (
            <PlanScreen initialSegment={planInitialSegment} />
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
        />

        {/* Your Setup Hub & Payday Editor */}
        <YourSetupModal
          isOpen={isSetupOpen}
          onClose={() => setIsSetupOpen(false)}
          initialTab={setupInitialTab}
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
