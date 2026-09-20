export type ThemeMode = 'hapon' | 'gabi';

export type TransactionType = 'expense' | 'income' | 'transfer';

export type ProfileEntity = 'personal' | 'household' | 'business' | 'side_hustle';

export type CurrencyCode = 'PHP' | 'USD' | 'EUR' | 'JPY' | 'SGD';

export type TransactionStatus =
  | 'pending'
  | 'confirmed'
  | 'reconciled'
  | 'duplicate'
  | 'corrected'
  | 'excluded';

export interface TransactionChangeRecord {
  timestamp: number;
  field: string;
  fromValue: string | number | boolean | undefined;
  toValue: string | number | boolean | undefined;
  note?: string;
}

export interface Transaction {
  id: string;
  type: TransactionType;
  amount: number; // edited / current value
  originalAmount?: number; // original value before corrections
  currency?: CurrencyCode;
  category: string; // Main category
  subcategory?: string;
  accountId: string; // Source account
  toAccountId?: string; // Destination account (transfers)
  profile?: ProfileEntity;
  person?: string; // Person involved (Mom, Kuya Mark, Client, Vendor)
  tags?: string[];
  merchant?: string;
  note?: string;
  attachmentUrl?: string; // Receipt or document
  attachmentName?: string;
  isTaxDeductible?: boolean; // BIR-deductible business/freelance expense
  taxTinOrRef?: string; // BIR TIN or official receipt reference number
  date: string; // ISO date format YYYY-MM-DD
  createdAt: number;
  status?: TransactionStatus;
  changeHistory?: TransactionChangeRecord[];
  isAdjustment?: boolean; // Traceable balance adjustment from reconciliation
  spaceId?: string; // Collaboration Space ID
  collaboratorId?: string; // Member who logged the transaction
  collaboratorName?: string;
  comments?: TransactionComment[];
  approval?: TransactionApproval;
  splitId?: string;
}

export type AccountKind =
  | 'cash'
  | 'bank'
  | 'gcash'
  | 'maya'
  | 'debit'
  | 'credit'
  | 'loan'
  | 'mortgage'
  | 'investment'
  | 'receivable';

export interface Account {
  id: string;
  name: string;
  kind: AccountKind;
  institution: string; // GCash, Maya, BPI, BDO, UnionBank, MariBank, GoTyme, Landbank, etc.
  balance: number;
  currency?: CurrencyCode;
  profile?: ProfileEntity;
  creditLimit?: number;
  dueDate?: string;
  statementDate?: string;
  interestRate?: number; // Annual interest percentage
  accountNumber?: string;
  monogram: string;
  notes?: string;
  cardNetwork?: 'visa' | 'mastercard' | 'amex' | 'jcb' | 'none';
  cardTier?: 'regular' | 'gold' | 'platinum' | 'black' | 'custom';
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
  splitId?: string;
}

export interface Budget {
  category: string;
  limit: number;
  emoji: string;
}

export type UpcomingItemType =
  | 'bill'
  | 'subscription'
  | 'payday'
  | 'debt'
  | 'remittance'
  | 'rent'
  | 'insurance'
  | 'tuition'
  | 'government';

export interface UpcomingItem {
  id: string;
  name: string;
  amount: number;
  dueDate: string; // e.g. "Today", "Sunday", "Sep 18", "Monday"
  type: UpcomingItemType;
  isIncome?: boolean;
  isPaid?: boolean;
  emoji?: string;
  category?: string;
  isRecurring?: boolean;
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
  subcategories: string[];
  type?: 'expense' | 'income' | 'both';
  isCustom?: boolean;
}

export type StarterPackId = 'student' | 'employee' | 'freelancer' | 'ofw';

export interface CategoryPack {
  id: StarterPackId;
  title: string;
  subtitle: string;
  emoji: string;
  categories: { name: string; emoji: string; defaultLimit: number }[];
}

export type ReportPeriod =
  | 'daily'
  | 'weekly'
  | 'monthly'
  | 'quarterly'
  | 'semi_annually'
  | 'annually'
  | 'custom';

export interface ReconciliationRecord {
  id: string;
  accountId: string;
  date: string;
  bookBalance: number;
  actualBalance: number;
  variance: number;
  status: 'balanced' | 'discrepancy';
  notes?: string;
  adjustmentTxId?: string;
  createdAt: number;
}

// ----------------------------------------------------
// PHASE 3: DAILY DECISION & SAFE-TO-SPEND TYPES
// ----------------------------------------------------

export type IncomeStreamType =
  | 'weekly_income'
  | 'semimonthly_salary'
  | 'monthly_salary'
  | 'freelance'
  | 'irregular'
  | 'thirteenth_month'
  | 'remittance';

export interface IncomeStream {
  id: string;
  name: string;
  type: IncomeStreamType;
  expectedAmount: number;
  nextExpectedDate: string; // YYYY-MM-DD or descriptive
  notes?: string;
  isConfirmed?: boolean;
}

export type DecisionScenario = 'conservative' | 'optimistic';

export interface SafeToSpendAnalysis {
  scenario: DecisionScenario;
  safeToSpendToday: number;
  safeToSpendUntilPayday: number;
  safeToSave: number;
  amountReserved: number;
  cashRunwayDays: number;
  cashRunwayMonths: number;
  reservedBreakdown: {
    bills: number;
    debtMinimums: number;
    installments: number;
    emergencyBuffer: number;
  };
  totalLiquidCash: number;
  totalExpectedInflow: number;
  daysToPayday: number;
}

export type HealthCheckMetric =
  | 'cash_runway'
  | 'debt_pressure'
  | 'emergency_fund_gap'
  | 'fee_leakage'
  | 'budget_variance'
  | 'income_stability'
  | 'reconciliation_status'
  | 'savings_consistency'
  | 'future_commitments'
  | 'forecast_reliability'
  | 'payday_crunch'
  | 'yield_optimization';

export type HealthSeverity = 'optimal' | 'warning' | 'critical' | 'neutral';

export interface HealthCheckInsight {
  id: HealthCheckMetric;
  title: string;
  severity: HealthSeverity;
  scoreText: string;
  whatHappened: string;
  whyDetected: string;
  usedTransactions: { id: string; name: string; amount: number; date: string }[];
  assumptions: string;
  confidence: 'High' | 'Medium' | 'Low';
  confidencePercentage: number;
  recommendedAction: string;
  correctionActionLabel?: string;
  correctionType?: 'budget' | 'reconcile' | 'emergency_goal' | 'bills' | 'debt' | 'fees';
}

// ----------------------------------------------------
// PHASE 4: BILLS, INSTALLMENTS, AND DEBT TYPES
// ----------------------------------------------------

export type BillCategory =
  | 'utility'
  | 'rent'
  | 'subscription'
  | 'insurance'
  | 'tuition'
  | 'government'
  | 'remittance'
  | 'other';

export type BillRecurrence = 'one_time' | 'recurring' | 'variable';

export interface BillItem {
  id: string;
  name: string;
  amount: number;
  category: BillCategory;
  recurrence: BillRecurrence;
  dueDate: string; // Day of month (e.g. "15th") or YYYY-MM-DD
  renewalDate?: string;
  gracePeriodDays?: number;
  lateFeeAmount?: number;
  lateFeePercentage?: number;
  reminderDaysBefore?: number;
  accountId?: string; // Preferred account
  isPaid?: boolean;
  lastPaidDate?: string;
  notes?: string;
}

export type InterestRateType = 'annual' | 'monthly' | 'daily' | 'fixed';
export type PaymentFrequency = 'monthly' | 'semimonthly' | 'biweekly' | 'weekly';

export interface InstallmentPlan {
  id: string;
  name: string; // e.g. "iPhone 15 via Home Credit", "Abenson Refrigerator via BPI SIP"
  provider: string; // Home Credit, BPI SIP, SpayLater, LazPayLater, etc.
  principal: number;
  interestRate: number; // percentage
  interestRateType: InterestRateType;
  totalInterest: number;
  totalPayable: number;
  termMonths: number;
  paymentFrequency: PaymentFrequency;
  startDate: string; // YYYY-MM-DD
  maturityDate: string; // YYYY-MM-DD
  installmentAmount: number; // Scheduled payment per cycle
  paidInstallments: number;
  totalInstallments: number;
  runningBalance: number;
  principalRemaining: number;
  interestRemaining: number;
  extraPayments: { id: string; date: string; amount: number; note?: string }[];
  isSettled: boolean;
  notes?: string;
}

export interface AmortizationRow {
  period: number;
  dueDate: string;
  scheduledPayment: number;
  principalComponent: number;
  interestComponent: number;
  extraPayment: number;
  remainingBalance: number;
}

export interface YearlyAmortizationSummary {
  year: number;
  totalPayment: number;
  principalPaid: number;
  interestPaid: number;
  extraPaid?: number;
  endingBalance: number;
  monthCount?: number;
}

// ----------------------------------------------------
// PHASE 5: RECURRING LOCAL NOTIFICATIONS & REMINDERS
// ----------------------------------------------------

export type ReminderType =
  | 'daily_expense'
  | 'payment_due'
  | 'bill_due'
  | 'subscription';

export interface ReminderSettings {
  dailyExpenseReminderEnabled: boolean;
  dailyExpenseReminderTime: string; // "HH:MM" in 24h format (e.g. "20:00")
  paymentDueReminderEnabled: boolean;
  paymentDueDaysBefore: number; // Days in advance (e.g. 1, 2, 3)
  billReminderEnabled: boolean;
  billDaysBefore: number; // Days in advance
  subscriptionReminderEnabled: boolean;
  subscriptionDaysBefore: number; // Days in advance
  webNotificationsEnabled: boolean;
  inAppToastsEnabled: boolean;
  soundEnabled: boolean;
}

export interface AppNotification {
  id: string;
  type: ReminderType;
  title: string;
  body: string;
  timestamp: number;
  isRead: boolean;
  actionType?: 'open_log_expense' | 'open_bills' | 'open_debts' | 'open_installments' | 'open_collaboration' | 'open_approvals';
  referenceId?: string;
  metadata?: {
    amount?: number;
    dueDate?: string;
    name?: string;
  };
}

// ----------------------------------------------------
// PHASE 5: SHARED FINANCES & COLLABORATION TYPES
// ----------------------------------------------------

export type CollaborationRole = 'owner' | 'editor' | 'contributor' | 'view_only';

export type CollaborationSpaceType =
  | 'couple'
  | 'household'
  | 'friends'
  | 'business'
  | 'adviser'
  | 'custom';

export interface CollaboratorMember {
  id: string;
  name: string;
  email?: string;
  role: CollaborationRole;
  avatar?: string;
  color?: string;
  phoneOrGcash?: string;
  joinedDate: string;
  expiresAt?: number | null; // Timestamp for expiring access
  isExpired?: boolean;
  isCurrentActor?: boolean; // For local persona simulation
  notes?: string;
}

export interface CollaborationSpace {
  id: string;
  name: string;
  type: CollaborationSpaceType;
  emoji: string;
  description: string;
  accountIds: string[]; // Linked shared accounts
  members: CollaboratorMember[];
  requireApprovalsAbove?: number; // Threshold in PHP where approval is required
  allowContributorDelete?: boolean;
  createdAt: number;
  isArchived?: boolean;
}

export interface TransactionComment {
  id: string;
  transactionId: string;
  authorId: string;
  authorName: string;
  authorRole: CollaborationRole;
  authorAvatar?: string;
  text: string;
  mentions?: string[]; // e.g. ['@Accountant', '@Partner', '@Sam']
  replyToCommentId?: string;
  createdAt: number;
}

export type TransactionApprovalStatus =
  | 'not_required'
  | 'pending_approval'
  | 'approved'
  | 'rejected';

export interface TransactionApproval {
  status: TransactionApprovalStatus;
  requestedBy?: string; // Member name
  requestedAt?: number;
  reviewedBy?: string; // Member name
  reviewedAt?: number;
  reviewedRole?: CollaborationRole;
  reason?: string;
}

export type SplitCategoryType = 'couple' | 'personal' | 'household' | 'business' | 'friends';

export type SplitMethod = 'equal' | 'percentage' | 'fixed' | 'shares';

export interface SplitParticipant {
  memberId: string;
  name: string;
  avatar?: string;
  sharePercentage?: number;
  shareAmount: number;
  hasPaid: boolean;
  settledAt?: string;
  settledMethod?: 'gcash' | 'maya' | 'cash' | 'bank_transfer' | 'offset';
  settledTransactionId?: string;
  notes?: string;
}

export interface ExpenseSplit {
  id: string;
  transactionId?: string;
  title: string;
  totalAmount: number;
  payerId: string;
  payerName: string;
  splitType: SplitCategoryType;
  splitMethod: SplitMethod;
  participants: SplitParticipant[];
  isFullySettled: boolean;
  createdAt: number;
  dueDate?: string;
  spaceId?: string;
  receiptUrl?: string;
  notes?: string;
}

export interface SimplifiedDebtTransfer {
  fromMemberId: string;
  fromMemberName: string;
  toMemberId: string;
  toMemberName: string;
  fromName?: string;
  toName?: string;
  amount: number;
  suggestedMethod?: string;
  reason?: string;
}

export type AuditLogAction =
  | 'created_transaction'
  | 'updated_transaction'
  | 'deleted_transaction'
  | 'approved_transaction'
  | 'rejected_transaction'
  | 'approved_tx'
  | 'rejected_tx'
  | 'added_comment'
  | 'attached_receipt'
  | 'removed_receipt'
  | 'created_split'
  | 'deleted_split'
  | 'settled_split'
  | 'invited_member'
  | 'removed_member'
  | 'updated_role'
  | 'revoked_access'
  | 'expired_access'
  | 'switched_persona'
  | 'created_space'
  | 'updated_space'
  | 'deleted_space';

export interface AuditLogEntry {
  id: string;
  timestamp: number;
  actorName: string;
  actorRole: CollaborationRole;
  actionType: AuditLogAction;
  entityType: 'transaction' | 'split' | 'member' | 'space' | 'receipt' | 'approval' | 'comment';
  entityId?: string;
  title: string;
  description: string;
  metadata?: Record<string, any>;
  spaceId?: string;
}

// ----------------------------------------------------
// PHASE 6: PHILIPPINE-LOCAL FEATURES & TOOLS
// ----------------------------------------------------

export type RemittanceChannel =
  | 'palawan_express'
  | 'cebuana_lhuillier'
  | 'gcash_padala'
  | 'maya'
  | 'lbc'
  | 'western_union'
  | 'mlhuillier'
  | 'bdo_remit'
  | 'bank_transfer'
  | 'cash_handover';

export interface RemittanceRecord {
  id: string;
  recipientName: string;
  relationship: string; // Nanay, Tatay, Kapatid, Anak, Spouse, Relatives
  provinceCity: string; // e.g., "Iloilo City", "Pangasinan", "Cebu", "Davao"
  channel: RemittanceChannel;
  amount: number;
  fee: number;
  claimedByDate?: string;
  referenceNumber?: string;
  purpose: 'living_allowance' | 'school_tuition' | 'medical_maintenance' | 'house_renovation' | 'emergency';
  cadence: 'monthly' | 'quincena_15_30' | 'one_time' | 'quarterly';
  status: 'sent' | 'claimed' | 'scheduled';
  date: string; // YYYY-MM-DD
  notes?: string;
}

export interface ThirteenthMonthAllocation {
  id: string;
  category: string;
  name: string;
  percentage: number;
  targetAmount: number;
  note?: string;
}

export interface ThirteenthMonthPlan {
  basicMonthlySalary: number;
  monthsWorkedTotal: number;
  calculatedGrossAmount: number;
  taxExemptThreshold: number; // 90,000 under TRAIN Law
  taxExemptAmount: number;
  taxableExcessAmount: number;
  estimatedWithholdingTax: number;
  net13thMonthPay: number;
  allocations: ThirteenthMonthAllocation[];
  status: 'projected' | 'received' | 'allocated';
}

export type PaydayAllocationBucket = 'bills' | 'ipon_mp2' | 'padala' | 'debt_service' | 'daily_allowance';

export interface PaydayAllocationItem {
  id: string;
  name: string;
  category: string;
  amount: number;
  percentage: number;
  targetAccountId?: string;
  bucket: PaydayAllocationBucket;
  isAutomaticTransfer?: boolean;
}

export interface PaydayRoutineTemplate {
  id: string;
  name: string;
  cycleType: '15_30' | 'monthly' | 'weekly';
  cutoff: '15th' | '30th' | 'both';
  baseSalary: number;
  items: PaydayAllocationItem[];
  notes?: string;
}

export interface FreelanceTaxCalculation {
  grossIncome: number;
  taxOption: '8_percent_git' | 'graduated_rates';
  allowableDeduction: number; // 250,000 standard deduction for 8% GIT
  taxableBase: number;
  estimatedTaxDue: number;
  effectiveTaxRate: number;
  monthlyTaxProvision: number;
  leanMonthsBufferRecommended: number; // 3-6 months buffer
}

export interface HouseholdAmbagMember {
  id: string;
  name: string;
  relation: string; // e.g. "Self", "Partner", "Kuya", "Ate", "Mama"
  monthlyIncome?: number;
  assignedSharePercentage: number;
  monthlyExpectedAmbag: number;
  actualPaidThisMonth: number;
  assignedUtilities: string[]; // e.g. ['Meralco', 'Converge WiFi']
  isSettled: boolean;
}

export interface HouseholdAmbagPool {
  id: string;
  name: string;
  totalMonthlyExpenseTarget: number;
  totalCollectedThisMonth: number;
  members: HouseholdAmbagMember[];
  billsIncluded: { name: string; amount: number; paidByMemberId?: string }[];
  cycleMonth: string; // e.g. "2026-09"
}

export interface CashDenominationCount {
  p1000: number;
  p500: number;
  p200: number;
  p100: number;
  p50: number;
  p20: number;
  coins: number;
}

// ----------------------------------------------------
// PHASE 9: INVESTMENT TRACKING TYPES (TRACKING, NOT TRADING)
// ----------------------------------------------------

export type InvestmentAssetClass =
  | 'stocks'
  | 'bonds'
  | 'mutual_funds'
  | 'etfs'
  | 'crypto'
  | 'mp2'
  | 'time_deposits'
  | 'insurance_linked'
  | 'real_estate';

export type InvestmentRiskProfile =
  | 'conservative'
  | 'moderate'
  | 'aggressive'
  | 'speculative';

export type InvestmentTxType =
  | 'buy'
  | 'sell'
  | 'dividend'
  | 'interest'
  | 'contribution'
  | 'withdrawal'
  | 'fee'
  | 'revaluation';

export type MarketDataProviderType =
  | 'manual'
  | 'coingecko'
  | 'twelve_data'
  | 'polygon';

export interface InvestmentTransaction {
  id: string;
  assetId: string;
  type: InvestmentTxType;
  date: string; // YYYY-MM-DD
  amount: number; // Total cash flow in PHP
  units?: number;
  pricePerUnit?: number;
  fee?: number;
  note?: string;
  createdAt: number;
}

export interface InvestmentAsset {
  id: string;
  name: string;
  symbolOrTicker?: string;
  assetClass: InvestmentAssetClass;
  riskProfile: InvestmentRiskProfile;
  institutionOrPlatform: string;
  units: number;
  costBasis: number;
  averageCostPerUnit: number;
  currentPricePerUnit: number;
  currentValuation: number;
  unrealizedGainLoss: number;
  unrealizedGainLossPercent: number;
  totalDividendsEarned: number;
  totalContributions: number;
  totalWithdrawals: number;
  currency: 'PHP' | 'USD';
  dataProvider?: MarketDataProviderType;
  lastUpdated: string;
  notes?: string;
  maturityDate?: string;
  history?: {
    date: string;
    valuation: number;
    pricePerUnit: number;
  }[];
}

export interface PortfolioSummary {
  totalValuation: number;
  totalCostBasis: number;
  totalUnrealizedGainLoss: number;
  totalUnrealizedGainLossPercent: number;
  totalDividendsEarned: number;
  totalContributions: number;
  totalWithdrawals: number;
  investmentToNetWorthRatio: number;
  assetAllocation: {
    assetClass: InvestmentAssetClass;
    label: string;
    amount: number;
    percentage: number;
  }[];
  riskAllocation: {
    riskProfile: InvestmentRiskProfile;
    label: string;
    amount: number;
    percentage: number;
  }[];
}

// ----------------------------------------------------
// SALAPIFY COMPETITIVE EDGE ARCHITECTURE
// ----------------------------------------------------

// 1. Financial Truth Layer
export interface FinancialTruthMetadata {
  source: 'manual_verified' | 'bank_statement_ocr' | 'csv_import' | 'direct_entry' | 'system_calculated';
  freshness: string;
  confidenceScore: number;
  lastReconciledDate?: string;
  calculationTrail: string[];
  changeHistoryCount: number;
  isImmutableAuditLocked?: boolean;
}

// 2. Financial Close
export interface FinancialCloseMonth {
  id: string; // e.g. "2026-08"
  periodLabel: string;
  isClosed: boolean;
  closedAt?: number;
  closedBy?: string;
  checklist: {
    missingTransactionsReviewed: boolean;
    duplicatesResolved: boolean;
    accountBalancesReconciled: boolean;
    variancesAcknowledged: boolean;
    monthlyReportConfirmed: boolean;
  };
  totalInflow: number;
  totalOutflow: number;
  netSavings: number;
  totalVariance: number;
  notes?: string;
}

// 3. Personal Financial Control Center
export type ControlCenterAlertSeverity = 'low' | 'medium' | 'high' | 'critical';

export type ControlCenterAlertType =
  | 'duplicate_charge'
  | 'balance_mismatch'
  | 'category_drift'
  | 'unexpected_recurring'
  | 'new_payee'
  | 'high_fee'
  | 'cash_shortfall'
  | 'debt_payment_risk'
  | 'forecast_variance'
  | 'missing_receipt';

export interface ControlCenterAlert {
  id: string;
  type: ControlCenterAlertType;
  title: string;
  description: string;
  severity: ControlCenterAlertSeverity;
  amount?: number;
  relatedAccountId?: string;
  relatedTransactionId?: string;
  detectedAt: number;
  isDismissed: boolean;
  suggestedAction: string;
}

// 4. Financial Digital Twin Scenarios
export type DigitalTwinScenarioType =
  | 'job_loss'
  | 'delayed_income'
  | 'rent_increase'
  | 'medical_expense'
  | 'new_child'
  | 'thirteenth_month'
  | 'debt_prepayment'
  | 'business_slowdown'
  | 'major_purchase';

export interface DigitalTwinSimulationResult {
  scenarioType: DigitalTwinScenarioType;
  title: string;
  description: string;
  baselineRunwayMonths: number;
  simulatedRunwayMonths: number;
  baselineSafeToSpend: number;
  simulatedSafeToSpend: number;
  baselineNetWorth: number;
  simulatedNetWorth: number;
  bufferImpactPhp: number;
  recommendations: string[];
}

// 5. Evidence Pack
export interface EvidencePackConfig {
  includeBalanceSheet: boolean;
  includeIncomeStatement: boolean;
  includeCashFlow: boolean;
  includeReconciliation: boolean;
  includeVariances: boolean;
  includeDebtSchedule: boolean;
  includeSavingsProgress: boolean;
  includeAuditHistory: boolean;
  targetPurpose: 'bank_loan' | 'visa_application' | 'investor_report' | 'personal_audit' | 'tax_compliance';
  periodMonth: string;
}

// 6. Scam Assistant
export type ScamThreatFlag =
  | 'urgency'
  | 'impersonation'
  | 'guaranteed_returns'
  | 'otp_pin_request'
  | 'unusual_payment'
  | 'unlicensed_investment';

export interface ScamAnalysisResult {
  riskScore: number;
  riskLevel: 'Safe' | 'Suspicious' | 'Dangerous' | 'Critical Scam';
  detectedFlags: {
    flag: ScamThreatFlag;
    title: string;
    description: string;
    evidenceFound?: string;
  }[];
  regulatoryAdvice: string;
  recommendedAction: string;
}

// 7. Financial Decision Journal
export interface DecisionJournalEntry {
  id: string;
  title: string;
  category: string;
  decisionDate: string;
  optionsConsidered: {
    name: string;
    cost: number;
    pros: string;
    cons: string;
  }[];
  chosenOption: string;
  estimatedCost: number;
  expectedBenefit: string;
  assumptions: string[];
  reviewDate: string;
  actualOutcome?: string;
  learningReflection?: string;
  status: 'planned' | 'active' | 'evaluated';
  createdAt: number;
}

// 8. Professional Adviser Mode
export interface AdviserSessionConfig {
  isActive: boolean;
  adviserName: string;
  expiresAt: number | null;
  maskBalances: boolean;
  allowedSections: {
    balanceSheet: boolean;
    incomeExpense: boolean;
    debtSchedule: boolean;
    investments: boolean;
    cashflow: boolean;
  };
  auditLog: {
    timestamp: number;
    action: string;
  }[];
}


