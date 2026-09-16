import React, { useState } from 'react';
import { 
  Smartphone, Laptop, CreditCard, ShieldCheck, 
  Building2, Globe, AlertTriangle, CheckCircle2, 
  ExternalLink, Sparkles, ChevronRight, Calculator, 
  HelpCircle, ArrowRight, ShieldAlert, FileText, 
  Scale, Users, Check, Info, Layers, CheckSquare
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { DigitalProductLaunchChecklist } from './DigitalProductLaunchChecklist';

export const SaaSAppStoreGuide: React.FC = () => {
  const [subTab, setSubTab] = useState<'overview' | 'launch_checklist' | 'stores' | 'billing' | 'taxation' | 'survival' | 'calculator'>('overview');

  // Interactive Revenue & Tax Simulator State
  const [monthlyGrossUsd, setMonthlyGrossUsd] = useState<number>(3000);
  const [avgTicketPriceUsd, setAvgTicketPriceUsd] = useState<number>(20);
  const [platformChannel, setPlatformChannel] = useState<'apple' | 'google' | 'mor' | 'stripe' | 'paymongo'>('apple');
  const [usdPhpRate, setUsdPhpRate] = useState<number>(58.50);
  const [taxRegime, setTaxRegime] = useState<'sole_8' | 'corp_cit' | 'graduated'>('sole_8');
  const [businessExpensePct, setBusinessExpensePct] = useState<number>(25); // For CIT deductions

  // Derived calculations
  const transactionCount = Math.max(1, Math.round(monthlyGrossUsd / Math.max(1, avgTicketPriceUsd)));

  // Calculate platform fee
  let platformFeeUsd = 0;
  let platformFeeLabel = '';

  if (platformChannel === 'apple') {
    platformFeeUsd = monthlyGrossUsd * 0.15; // Small Business Program 15%
    platformFeeLabel = 'Apple App Store (15% Small Business Program)';
  } else if (platformChannel === 'google') {
    platformFeeUsd = monthlyGrossUsd * 0.15; // Google 15% tier
    platformFeeLabel = 'Google Play Store (15% Tier)';
  } else if (platformChannel === 'mor') {
    platformFeeUsd = (monthlyGrossUsd * 0.05) + (transactionCount * 0.50); // Paddle/LemonSqueezy ~5% + $0.50
    platformFeeLabel = 'Merchant of Record (Paddle / Lemon Squeezy ~5% + $0.50/tx)';
  } else if (platformChannel === 'stripe') {
    platformFeeUsd = (monthlyGrossUsd * 0.029) + (transactionCount * 0.30) + (monthlyGrossUsd * 0.015); // Stripe international ~4.4% + $0.30
    platformFeeLabel = 'Stripe Payment Gateway (2.9% + $0.30/tx + 1.5% cross-border)';
  } else if (platformChannel === 'paymongo') {
    // PayMongo local PH cards (~3.5% + ₱15) / GCash (~2.5%) -> approx 3.2%
    platformFeeUsd = (monthlyGrossUsd * 0.032) + (transactionCount * 0.25);
    platformFeeLabel = 'PayMongo Philippine Gateway (Cards 3.5% + GCash/Maya 2.5%)';
  }

  const netPayoutUsd = Math.max(0, monthlyGrossUsd - platformFeeUsd);
  const grossPhp = monthlyGrossUsd * usdPhpRate;
  const platformFeePhp = platformFeeUsd * usdPhpRate;
  const netPayoutPhp = netPayoutUsd * usdPhpRate;

  // Estimated Monthly Tax
  let estimatedMonthlyTaxPhp = 0;
  let taxExplanation = '';

  if (taxRegime === 'sole_8') {
    // 8% on gross receipts over ₱250,000 threshold (~₱20,833/month exemption)
    const monthlyExemption = 20833;
    const taxableReceipts = Math.max(0, grossPhp - monthlyExemption);
    estimatedMonthlyTaxPhp = taxableReceipts * 0.08;
    taxExplanation = '8% flat rate on gross sales above ₱250k annual threshold. 0% Zero-Rated VAT applies to foreign export revenue. No 3% percentage tax!';
  } else if (taxRegime === 'corp_cit') {
    // OPC / Regular Corp: 20% CIT on net taxable income (CREATE Act for MSME)
    const monthlyExpenses = netPayoutPhp * (businessExpensePct / 100);
    const netTaxableIncome = Math.max(0, netPayoutPhp - monthlyExpenses);
    estimatedMonthlyTaxPhp = netTaxableIncome * 0.20;
    taxExplanation = `20% Corporate Income Tax (CREATE Act) after deducting estimated ${businessExpensePct}% business costs (hosting, software tools, salaries, internet).`;
  } else {
    // Graduated rates estimate (approximate effective rate under TRAIN Law)
    const annualNet = netPayoutPhp * 12;
    let annualTax = 0;
    if (annualNet <= 250000) annualTax = 0;
    else if (annualNet <= 400000) annualTax = (annualNet - 250000) * 0.15;
    else if (annualNet <= 800000) annualTax = 22500 + (annualNet - 400000) * 0.20;
    else if (annualNet <= 2000000) annualTax = 102500 + (annualNet - 800000) * 0.25;
    else if (annualNet <= 5000000) annualTax = 402500 + (annualNet - 2000000) * 0.30;
    else annualTax = 1302500 + (annualNet - 5000000) * 0.35;
    estimatedMonthlyTaxPhp = annualTax / 12;
    taxExplanation = 'Graduated personal income tax brackets under TRAIN Law with itemized or optional standard deductions (OSD).';
  }

  const netTakeHomePhp = Math.max(0, netPayoutPhp - estimatedMonthlyTaxPhp);
  const takeHomePct = grossPhp > 0 ? Math.round((netTakeHomePhp / grossPhp) * 100) : 0;

  return (
    <div className="space-y-4">
      {/* SaaS Guide Header */}
      <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 sm:p-5 shadow-xs">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-2">
          <div className="flex items-center gap-2.5">
            <div className="w-10 h-10 rounded-xl bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center shrink-0">
              <Smartphone size={20} />
            </div>
            <div>
              <div className="flex items-center gap-2 flex-wrap">
                <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                  SaaS &amp; App Store Playbook
                </span>
                <span className="text-[9px] font-bold px-1.5 py-0.2 rounded bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52]">
                  GLOBAL &amp; PH
                </span>
              </div>
              <h2 className="text-base sm:text-lg font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Launching Apps, SaaS &amp; Digital Products from the Philippines
              </h2>
            </div>
          </div>
        </div>

        <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] leading-relaxed">
          The definitive blueprint for indie hackers, software founders, and mobile app creators in the Philippines. Learn how to publish on Apple App Store &amp; Google Play, obtain a free D-U-N-S number, set up Merchant of Record (MoR) billing, qualify for 0% Zero-Rated VAT under Section 108, and pass store reviews without rejections.
        </p>

        {/* Sub-tab Navigation */}
        <div className="mt-4 pt-3 border-t border-[#F3DFCD]/70 dark:border-[#383029] flex items-center gap-1.5 overflow-x-auto no-scrollbar">
          {[
            { id: 'overview', label: '5-Stage Architecture', icon: Layers },
            { id: 'launch_checklist', label: 'Launch Checklist', icon: CheckSquare, badge: 'TRACKER' },
            { id: 'stores', label: 'Apple & Google Stores', icon: Smartphone },
            { id: 'billing', label: 'MoR vs. Gateways', icon: CreditCard },
            { id: 'taxation', label: 'BIR Taxes & Payouts', icon: Scale },
            { id: 'survival', label: 'Review Survival & Privacy', icon: ShieldCheck },
            { id: 'calculator', label: 'Revenue Simulator', icon: Calculator },
          ].map(tab => {
            const Icon = tab.icon;
            const isCurrent = subTab === tab.id;
            return (
              <button
                key={tab.id}
                type="button"
                onClick={() => setSubTab(tab.id as any)}
                className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 whitespace-nowrap min-h-[44px] shrink-0 ${
                  isCurrent
                    ? 'bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] shadow-xs'
                    : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] hover:bg-[#FAFAFA] dark:hover:bg-[#1E1915]'
                }`}
              >
                <Icon size={14} />
                <span>{tab.label}</span>
                {tab.badge && (
                  <span className={`text-[9px] px-1.5 py-0.2 rounded-full font-bold ${
                    isCurrent ? 'bg-white/20 text-white dark:text-[#14100D]' : 'bg-[#FFEEDF] text-[#B03C09] dark:bg-[#383029] dark:text-[#FF9A52]'
                  }`}>
                    {tab.badge}
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* SUB-TAB 1: OVERVIEW & 5-STAGE ARCHITECTURE */}
      {subTab === 'overview' && (
        <div className="space-y-4">
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
              The 5-Stage SaaS &amp; App Launch Pipeline
            </h3>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
              Unlike traditional physical stores, software businesses operate across international app stores, cross-border payment processors, and foreign tax boundaries.
            </p>

            <div className="grid grid-cols-1 md:grid-cols-5 gap-2.5 mt-4">
              {/* Step 1 */}
              <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029] flex flex-col justify-between">
                <div>
                  <div className="w-6 h-6 rounded-lg bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center text-xs font-bold mb-2">
                    1
                  </div>
                  <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
                    Entity &amp; D-U-N-S
                  </h4>
                  <p className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                    Form an SEC OPC or Corporation to secure an Organization account on Apple &amp; Google, and claim your free D-U-N-S number.
                  </p>
                </div>
                <span className="text-[10px] font-bold text-[#B03C09] dark:text-[#FF9A52] mt-2 block">
                  Week 1-3
                </span>
              </div>

              {/* Step 2 */}
              <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029] flex flex-col justify-between">
                <div>
                  <div className="w-6 h-6 rounded-lg bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center text-xs font-bold mb-2">
                    2
                  </div>
                  <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
                    Store Developer Accounts
                  </h4>
                  <p className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                    Enroll in Apple Developer ($99/yr) &amp; Google Play ($25 one-time). Bypass Google 20-tester testing trap with verified Org.
                  </p>
                </div>
                <span className="text-[10px] font-bold text-[#B03C09] dark:text-[#FF9A52] mt-2 block">
                  Week 3-4
                </span>
              </div>

              {/* Step 3 */}
              <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029] flex flex-col justify-between">
                <div>
                  <div className="w-6 h-6 rounded-lg bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center text-xs font-bold mb-2">
                    3
                  </div>
                  <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
                    Global Monetization
                  </h4>
                  <p className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                    Implement In-App Purchases (IAP) for mobile, and Merchant of Record (Paddle/Lemon Squeezy) for Web SaaS to automate global VAT.
                  </p>
                </div>
                <span className="text-[10px] font-bold text-[#B03C09] dark:text-[#FF9A52] mt-2 block">
                  Week 4-6
                </span>
              </div>

              {/* Step 4 */}
              <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029] flex flex-col justify-between">
                <div>
                  <div className="w-6 h-6 rounded-lg bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center text-xs font-bold mb-2">
                    4
                  </div>
                  <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
                    Store Review &amp; Privacy
                  </h4>
                  <p className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                    Deploy public Privacy Policy URL, in-app account deletion, and Sign in with Apple to guarantee pass on first review submission.
                  </p>
                </div>
                <span className="text-[10px] font-bold text-[#B03C09] dark:text-[#FF9A52] mt-2 block">
                  Launch Week
                </span>
              </div>

              {/* Step 5 */}
              <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029] flex flex-col justify-between">
                <div>
                  <div className="w-6 h-6 rounded-lg bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center text-xs font-bold mb-2">
                    5
                  </div>
                  <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
                    BIR 0% VAT Payouts
                  </h4>
                  <p className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                    Receive USD wire transfers into Philippine bank, issue zero-rated sales invoices under Section 108, and file quarterly tax returns.
                  </p>
                </div>
                <span className="text-[10px] font-bold text-[#B03C09] dark:text-[#FF9A52] mt-2 block">
                  Monthly Run
                </span>
              </div>
            </div>
          </div>

          {/* Quick Launch Checklist CTA Banner */}
          <div className="bg-gradient-to-r from-[#FFF8F3] to-[#FFEEDF] dark:from-[#2A211B] dark:to-[#1E1915] border border-[#B03C09]/30 dark:border-[#FF9A52]/30 rounded-2xl p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3 shadow-xs">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] flex items-center justify-center shrink-0">
                <CheckSquare size={20} />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <h4 className="text-xs sm:text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Interactive Digital Product Launch Checklist
                  </h4>
                  <span className="text-[9px] font-bold px-1.5 py-0.2 rounded bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D]">
                    17 VERIFIED STEPS
                  </span>
                </div>
                <p className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed mt-0.5">
                  Track monetization models (subscription vs one-time), Philippine e-wallet integrations (GCash, Maya), and RA 10173 data privacy protocols with persistent local storage.
                </p>
              </div>
            </div>
            <button
              type="button"
              onClick={() => setSubTab('launch_checklist')}
              className="px-3.5 py-2 rounded-xl text-xs font-bold bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] hover:opacity-90 transition-opacity flex items-center gap-1.5 shrink-0 self-start sm:self-auto min-h-[44px]"
            >
              <span>Open Launch Checklist</span>
              <ArrowRight size={14} />
            </button>
          </div>

          {/* Key Strategic Decisions for Tech Founders */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 sm:p-5 shadow-xs">
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] mb-3">
              Strategic Decision Matrix for Software Founders
            </h3>

            <div className="space-y-3">
              <div className="p-3.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029]">
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded bg-[#FFEEDF] text-[#B03C09] dark:bg-[#383029] dark:text-[#FF9A52]">
                    DECISION 1
                  </span>
                  <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Should you incorporate in the Philippines or use a US Delaware C-Corp / Singapore entity?
                  </h4>
                </div>
                <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed mt-1">
                  If you are bootstrapping or raising from local angels, an SEC-registered <strong>One Person Corporation (OPC)</strong> or <strong>Philippine Stock Corporation</strong> is 100% legal, costs less than ₱15,000 to form, and allows opening corporate accounts with BPI, UnionBank, or BDO. You only need a Delaware C-Corp (via Stripe Atlas or Firstbase) if you are accepted into Y Combinator, Techstars, or raising institutional US venture capital that explicitly demands a Delaware flip.
                </p>
              </div>

              <div className="p-3.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029]">
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded bg-[#FFEEDF] text-[#B03C09] dark:bg-[#383029] dark:text-[#FF9A52]">
                    DECISION 2
                  </span>
                  <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Individual Developer Account vs. Organization Developer Account
                  </h4>
                </div>
                <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed mt-1">
                  Always choose an <strong>Organization Account</strong> if you plan to build a real brand. Individual accounts publicly expose your personal legal name on the App Store and Google Play, cannot grant permissions to team members without sharing master Apple IDs, and trigger Google\'s brutal 2023 requirement of finding 20 testers for 14 continuous days before you can publish.
                </p>
              </div>

              <div className="p-3.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029]">
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded bg-[#FFEEDF] text-[#B03C09] dark:bg-[#383029] dark:text-[#FF9A52]">
                    DECISION 3
                  </span>
                  <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Web SaaS: Payment Gateway (Stripe/PayMongo) vs. Merchant of Record (Paddle/Lemon Squeezy)
                  </h4>
                </div>
                <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed mt-1">
                  If your customers are global (US, Europe, UK, Australia), use a <strong>Merchant of Record (MoR)</strong> like Paddle or Lemon Squeezy. The MoR acts as the legal reseller, collects and remits European VAT and US state sales taxes, and pays you one clean B2B payout every month. If your customers are purely in the Philippines, use <strong>PayMongo</strong> or <strong>Xendit</strong> to support GCash, Maya, and local bank transfers.
                </p>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* SUB-TAB: LAUNCH CHECKLIST */}
      {subTab === 'launch_checklist' && <DigitalProductLaunchChecklist />}

      {/* SUB-TAB 2: APPLE & GOOGLE PLAY STORE PLAYBOOK */}
      {subTab === 'stores' && (
        <div className="space-y-4">
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
              Apple Developer &amp; Google Play Console Playbook
            </h3>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
              How to properly structure developer accounts, obtain a free D-U-N-S number in the Philippines, and avoid costly platform bottlenecks.
            </p>

            {/* Individual vs Org Comparison Table */}
            <div className="overflow-x-auto mt-4">
              <table className="w-full text-left text-xs border border-[#F3DFCD] dark:border-[#383029] rounded-xl overflow-hidden">
                <thead className="bg-[#FFEEDF]/60 dark:bg-[#383029] text-[#15120F] dark:text-[#F6EFE8]">
                  <tr>
                    <th className="p-3 font-bold">Feature / Policy</th>
                    <th className="p-3 font-bold">Individual Account</th>
                    <th className="p-3 font-bold">Organization Account (Recommended)</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#F3DFCD]/60 dark:divide-[#383029] text-[#5A5148] dark:text-[#C6B8AC]">
                  <tr>
                    <td className="p-3 font-semibold text-[#15120F] dark:text-[#F6EFE8]">Store Seller Name</td>
                    <td className="p-3 text-red-600 dark:text-red-400">Your personal legal name (Juan Dela Cruz)</td>
                    <td className="p-3 text-emerald-600 dark:text-emerald-400 font-bold">Your company name (Acme Technologies OPC)</td>
                  </tr>
                  <tr>
                    <td className="p-3 font-semibold text-[#15120F] dark:text-[#F6EFE8]">Team Roles &amp; Access</td>
                    <td className="p-3">None. Must share personal Apple ID password to let developers test.</td>
                    <td className="p-3 text-emerald-600 dark:text-emerald-400 font-bold">Full granular roles (Admins, Developers, Marketers, Finance).</td>
                  </tr>
                  <tr>
                    <td className="p-3 font-semibold text-[#15120F] dark:text-[#F6EFE8]">Google Play 2023+ Rule</td>
                    <td className="p-3 text-red-600 dark:text-red-400">Must recruit 20 testers for 14 continuous days before production release.</td>
                    <td className="p-3 text-emerald-600 dark:text-emerald-400 font-bold">Bypasses the 20-tester closed testing gate with verified business entity.</td>
                  </tr>
                  <tr>
                    <td className="p-3 font-semibold text-[#15120F] dark:text-[#F6EFE8]">Prerequisites</td>
                    <td className="p-3">Valid Government ID and personal credit card.</td>
                    <td className="p-3 font-medium text-[#15120F] dark:text-[#F6EFE8]">SEC Certificate, D-U-N-S Number, Company Website &amp; Domain Email.</td>
                  </tr>
                  <tr>
                    <td className="p-3 font-semibold text-[#15120F] dark:text-[#F6EFE8]">Annual Cost</td>
                    <td className="p-3">Apple: $99/yr | Google: $25 one-time</td>
                    <td className="p-3">Apple: $99/yr | Google: $25 one-time (Same cost!)</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          {/* D-U-N-S Number Guide */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 sm:p-5 shadow-xs">
            <div className="flex items-center gap-2 mb-2">
              <Sparkles size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />
              <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                How to Get a Free D-U-N-S Number for Philippine Entities
              </h3>
            </div>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] mb-3 leading-relaxed">
              Dun &amp; Bradstreet assigns a unique 9-digit identifier (D-U-N-S) to verified legal businesses worldwide. Apple requires this to verify your company before enrolling as an Organization. <strong>Never pay third-party agencies thousands of pesos for a D-U-N-S number--Apple provides it completely free!</strong>
            </p>

            <div className="space-y-2.5 text-xs text-[#5A5148] dark:text-[#C6B8AC]">
              <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029] flex items-start gap-3">
                <div className="w-5 h-5 rounded-full bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center font-bold text-[10px] shrink-0 mt-0.5">
                  1
                </div>
                <div>
                  <strong className="text-[#15120F] dark:text-[#F6EFE8] block mb-0.5">
                    Prepare Legal Corporate Documents
                  </strong>
                  You must have your SEC Certificate of Incorporation (for an OPC or Regular Corporation), official registered office address, and Tax Identification Number (TIN).
                </div>
              </div>

              <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029] flex items-start gap-3">
                <div className="w-5 h-5 rounded-full bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center font-bold text-[10px] shrink-0 mt-0.5">
                  2
                </div>
                <div>
                  <strong className="text-[#15120F] dark:text-[#F6EFE8] block mb-0.5">
                    Set Up Active Company Website &amp; Domain Email
                  </strong>
                  Apple and D&amp;B verify that your business is live. You must have a working website (e.g. <code>https://yourcompany.com</code>) and a matching email address (e.g. <code>carlam@yourcompany.com</code>). Applications using free Gmail or Yahoo accounts will be rejected.
                </div>
              </div>

              <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029] flex items-start gap-3">
                <div className="w-5 h-5 rounded-full bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center font-bold text-[10px] shrink-0 mt-0.5">
                  3
                </div>
                <div>
                  <strong className="text-[#15120F] dark:text-[#F6EFE8] block mb-0.5">
                    Submit via Apple Free D-U-N-S Lookup Tool
                  </strong>
                  Visit <code>developer.apple.com/enroll/duns-lookup/</code> and enter your SEC legal entity name and address. If no record is found, click &quot;Submit your information&quot;. Dun &amp; Bradstreet will email you within 5 to 14 business days requesting a copy of your SEC certificate.
                </div>
              </div>

              <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029] flex items-start gap-3">
                <div className="w-5 h-5 rounded-full bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center font-bold text-[10px] shrink-0 mt-0.5">
                  4
                </div>
                <div>
                  <strong className="text-[#15120F] dark:text-[#F6EFE8] block mb-0.5">
                    Receive 9-Digit D-U-N-S &amp; Wait 48 Hours
                  </strong>
                  Once D&amp;B issues your D-U-N-S number, wait 2 business days for Apple servers to synchronize before entering it on Apple Developer enrollment.
                </div>
              </div>
            </div>
          </div>

          {/* Small Business Program 15% */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
              Apple Small Business Program &amp; Google 15% Tier
            </h3>
            <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
              By default, Apple and Google take a 30% commission on digital In-App Purchases (IAP). However, both platforms offer a <strong>15% reduced commission rate</strong> for developers earning under $1,000,000 USD per calendar year:
            </p>
            <ul className="list-disc list-inside space-y-1 text-xs text-[#15120F] dark:text-[#F6EFE8] font-medium mt-2">
              <li><strong>Apple App Store Small Business Program:</strong> Requires manual enrollment at <code>developer.apple.com/app-store/small-business-program/</code>. Reduces fee from 30% to 15% on all paid apps and in-app purchases.</li>
              <li><strong>Google Play 15% Service Fee Tier:</strong> Automatically applies 15% fee on the first $1,000,000 USD of annual developer earnings once your account group is registered in Play Console.</li>
            </ul>
          </div>
        </div>
      )}

      {/* SUB-TAB 3: MOR VS PAYMENT GATEWAY */}
      {subTab === 'billing' && (
        <div className="space-y-4">
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
              The Merchant of Record (MoR) Revolution for Web SaaS
            </h3>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] leading-relaxed">
              When launching a web application or SaaS accessible worldwide, the single biggest compliance trap for Filipino founders is <strong>cross-border sales tax and VAT</strong>. Here is why choosing between an MoR and a raw payment gateway changes everything.
            </p>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mt-4">
              {/* MoR Path */}
              <div className="p-4 rounded-xl bg-gradient-to-br from-[#FFF8F3] to-[#FFEEDF] dark:from-[#2A211B] dark:to-[#1E1915] border border-[#F3DFCD] dark:border-[#5A5148]">
                <div className="flex items-center justify-between gap-2 mb-2">
                  <span className="text-xs font-bold text-[#B03C09] dark:text-[#FF9A52] uppercase tracking-wide">
                    Merchant of Record (MoR)
                  </span>
                  <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D]">
                    BEST FOR GLOBAL SAAS
                  </span>
                </div>
                <h4 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
                  Paddle / Lemon Squeezy
                </h4>
                <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed mb-3">
                  The MoR is the legal reseller of your software. They buy your digital license at wholesale and resell it to the consumer.
                </p>
                <ul className="space-y-1.5 text-xs text-[#15120F] dark:text-[#F6EFE8]">
                  <li className="flex items-start gap-1.5">
                    <Check size={14} className="text-emerald-600 dark:text-emerald-400 shrink-0 mt-0.5" />
                    <span><strong>Global Sales Tax &amp; EU VAT:</strong> MoR handles all tax filings in EU, UK, US states, and Australia.</span>
                  </li>
                  <li className="flex items-start gap-1.5">
                    <Check size={14} className="text-emerald-600 dark:text-emerald-400 shrink-0 mt-0.5" />
                    <span><strong>Chargeback Protection:</strong> MoR absorbs fraud and payment compliance liabilities.</span>
                  </li>
                  <li className="flex items-start gap-1.5">
                    <Check size={14} className="text-emerald-600 dark:text-emerald-400 shrink-0 mt-0.5" />
                    <span><strong>BIR Invoicing in PH:</strong> You issue only 1 B2B invoice per month to Paddle/Lemon Squeezy!</span>
                  </li>
                  <li className="flex items-start gap-1.5">
                    <Check size={14} className="text-emerald-600 dark:text-emerald-400 shrink-0 mt-0.5" />
                    <span><strong>Fee Structure:</strong> Typically 5% + $0.50 per transaction (includes tax automation).</span>
                  </li>
                </ul>
              </div>

              {/* Gateway Path */}
              <div className="p-4 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029]">
                <div className="flex items-center justify-between gap-2 mb-2">
                  <span className="text-xs font-bold text-[#6B6156] dark:text-[#AC9E92] uppercase tracking-wide">
                    Payment Gateway
                  </span>
                  <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-400">
                    BEST FOR PH DOMESTIC
                  </span>
                </div>
                <h4 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
                  Stripe / PayMongo / Xendit
                </h4>
                <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed mb-3">
                  The gateway is merely a payment conduit. You remain the legal merchant and seller for every individual customer transaction.
                </p>
                <ul className="space-y-1.5 text-xs text-[#15120F] dark:text-[#F6EFE8]">
                  <li className="flex items-start gap-1.5">
                    <AlertTriangle size={14} className="text-amber-600 dark:text-amber-400 shrink-0 mt-0.5" />
                    <span><strong>Global Tax Liability:</strong> You must personally register and remit VAT in Europe and every US state where you meet thresholds!</span>
                  </li>
                  <li className="flex items-start gap-1.5">
                    <Check size={14} className="text-emerald-600 dark:text-emerald-400 shrink-0 mt-0.5" />
                    <span><strong>Philippine E-Wallets:</strong> PayMongo supports GCash, Maya, GrabPay, and direct BPI/BDO checkouts.</span>
                  </li>
                  <li className="flex items-start gap-1.5">
                    <AlertTriangle size={14} className="text-amber-600 dark:text-amber-400 shrink-0 mt-0.5" />
                    <span><strong>BIR Invoicing:</strong> Must issue official sales invoices for every single domestic customer.</span>
                  </li>
                  <li className="flex items-start gap-1.5">
                    <Check size={14} className="text-emerald-600 dark:text-emerald-400 shrink-0 mt-0.5" />
                    <span><strong>Fee Structure:</strong> 2.9% + $0.30 (Stripe) or 3.5% + ₱15 (PayMongo cards).</span>
                  </li>
                </ul>
              </div>
            </div>
          </div>

          {/* Summary Recommendation */}
          <div className="bg-[#FFF5ED] dark:bg-[#2E241E] border border-[#F3DFCD] dark:border-[#5A5148] rounded-xl p-3.5 flex items-start gap-3">
            <Info size={18} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0 mt-0.5" />
            <div className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
              <strong className="text-[#15120F] dark:text-[#F6EFE8] block mb-0.5">
                The Golden Rule of SaaS Monetization from the Philippines:
              </strong>
              If &gt;80% of your subscribers are abroad, integrate <strong>Lemon Squeezy or Paddle</strong>. The slightly higher fee (5% vs 2.9%) saves you tens of thousands of dollars in foreign sales tax audits, CPA cross-border retainers, and merchant liabilities. If your software targets Philippine clinics, schools, or local SMEs, integrate <strong>PayMongo or Xendit</strong> so customers can pay via GCash and Maya.
            </div>
          </div>
        </div>
      )}

      {/* SUB-TAB 4: BIR TAXATION & PAYOUTS */}
      {subTab === 'taxation' && (
        <div className="space-y-4">
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
              Philippine Taxation of SaaS &amp; App Store Inward Remittances
            </h3>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
              Validated by our CPA Council: how to legally account for Apple, Google, Stripe, or MoR wire transfers into your Philippine bank account.
            </p>

            <div className="space-y-3 mt-4 text-xs text-[#5A5148] dark:text-[#C6B8AC]">
              {/* Zero-Rated VAT */}
              <div className="p-3.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029]">
                <div className="flex items-center justify-between gap-2 mb-1">
                  <span className="font-bold text-[#B03C09] dark:text-[#FF9A52] text-xs">
                    1. 0% Zero-Rated VAT under Section 108(B)(2) of the Tax Code
                  </span>
                  <span className="text-[9px] font-bold px-1.5 py-0.2 rounded bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-400">
                    TAX BENEFIT
                  </span>
                </div>
                <p className="leading-relaxed">
                  Under Philippine tax law, services rendered to a person or entity engaged in business conducted outside the Philippines, paid for in acceptable foreign currency (USD, EUR) and accounted for in accordance with the rules of the Bangko Sentral ng Pilipinas (BSP), are subject to <strong>0% Zero-Rated VAT</strong>.
                </p>
                <div className="p-2.5 rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD]/60 dark:border-[#383029] mt-2 space-y-1">
                  <strong className="text-[#15120F] dark:text-[#F6EFE8] block">Mandatory Audit Trail Requirements:</strong>
                  <ul className="list-disc list-inside text-[11px] space-y-0.5">
                    <li>Copy of Apple Developer Agreement, Google Play Agreement, or MoR contract showing the client is a foreign entity (e.g. Apple Distribution International Ltd, Ireland).</li>
                    <li>Official Bank Credit Memo or Bank Statement proving inward foreign currency remittance into your Philippine bank account (BPI, BDO, UnionBank) or Wise account.</li>
                    <li>Official BIR Sales Invoice marked explicitly with &quot;Zero-Rated Sales&quot;.</li>
                  </ul>
                </div>
              </div>

              {/* Invoicing under EOPT */}
              <div className="p-3.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029]">
                <div className="flex items-center justify-between gap-2 mb-1">
                  <span className="font-bold text-[#B03C09] dark:text-[#FF9A52] text-xs">
                    2. Invoicing under the Ease of Paying Taxes (EOPT) Act (RA 11976)
                  </span>
                  <span className="text-[9px] font-bold px-1.5 py-0.2 rounded bg-blue-100 text-blue-800 dark:bg-blue-950 dark:text-blue-400">
                    INVOICING RULE
                  </span>
                </div>
                <p className="leading-relaxed">
                  Under the EOPT Act, the &quot;Official Receipt&quot; is no longer the primary document for services. You must issue an <strong>Official Sales Invoice</strong> for all revenues.
                </p>
                <p className="leading-relaxed mt-1">
                  When receiving a monthly payout from Apple, Google, or Paddle, issue one consolidated sales invoice for that specific payout remittance. State the foreign corporation as the buyer, convert the USD payout to PHP using the official BSP reference exchange rate on the date of inward remittance, and record the transaction in your registered Sales Journal.
                </p>
              </div>

              {/* Sole Prop 8% Option */}
              <div className="p-3.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029]">
                <div className="flex items-center justify-between gap-2 mb-1">
                  <span className="font-bold text-[#B03C09] dark:text-[#FF9A52] text-xs">
                    3. The 8% Flat Gross Income Tax Option (For Solo Founders)
                  </span>
                  <span className="text-[9px] font-bold px-1.5 py-0.2 rounded bg-[#FFEEDF] text-[#B03C09] dark:bg-[#383029] dark:text-[#FF9A52]">
                    SOLO FOUNDERS
                  </span>
                </div>
                <p className="leading-relaxed">
                  If you operate as a Sole Proprietorship registered with DTI and BIR, and your gross annual receipts do not exceed ₱3,000,000, you can elect the <strong>8% Gross Income Tax rate</strong> in lieu of graduated income tax and 3% percentage tax. You receive a standard ₱250,000 annual deduction, and you only pay 8% on the excess! This is extraordinarily cost-effective for solo software developers.
                </p>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* SUB-TAB 5: STORE REVIEW SURVIVAL & PRIVACY */}
      {subTab === 'survival' && (
        <div className="space-y-4">
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
              App Store Review Survival &amp; Regulatory Compliance
            </h3>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
              The top reasons Apple App Store and Google Play reject new apps, and how to guarantee first-time review approval.
            </p>

            <div className="space-y-3 mt-4 text-xs text-[#5A5148] dark:text-[#C6B8AC]">
              {/* Trap 1: Guideline 3.1.1 IAP */}
              <div className="p-3.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029]">
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-400">
                    GUIDELINE 3.1.1
                  </span>
                  <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    The In-App Purchases (IAP) Mandate
                  </h4>
                </div>
                <p className="leading-relaxed">
                  If your mobile app unlocks features, delivers premium subscriptions, or sells digital goods consumed inside the app, you <strong>MUST use Apple StoreKit / Google Play Billing</strong>. You are strictly forbidden from placing a link inside the app that redirects users to an external website or Stripe checkout. Attempting to bypass IAP will result in an immediate, hard rejection.
                </p>
              </div>

              {/* Trap 2: In-App Account Deletion */}
              <div className="p-3.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029]">
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-400">
                    GUIDELINE 5.1.1(V)
                  </span>
                  <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Mandatory In-App Account &amp; Data Deletion
                  </h4>
                </div>
                <p className="leading-relaxed">
                  If your app supports user account creation (email sign-up, Google, Apple), you <strong>MUST provide an in-app button allowing users to initiate complete account deletion and data purge</strong>. Simply writing &quot;Contact us via email to delete your account&quot; is no longer accepted by Apple and will cause an instant rejection.
                </p>
              </div>

              {/* Trap 3: Sign in with Apple */}
              <div className="p-3.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029]">
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded bg-amber-100 text-amber-700 dark:bg-amber-950 dark:text-amber-400">
                    GUIDELINE 4.8
                  </span>
                  <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Sign in with Apple Requirement
                  </h4>
                </div>
                <p className="leading-relaxed">
                  If your iOS app offers third-party social logins (e.g. &quot;Sign in with Google&quot; or &quot;Sign in with Facebook&quot;), you must offer &quot;Sign in with Apple&quot; as an equivalent option, positioned prominently.
                </p>
              </div>

              {/* Trap 4: NPC Data Privacy Act */}
              <div className="p-3.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029]">
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded bg-blue-100 text-blue-700 dark:bg-blue-950 dark:text-blue-400">
                    RA 10173 / NPC
                  </span>
                  <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Public Privacy Policy URL &amp; National Privacy Commission
                  </h4>
                </div>
                <p className="leading-relaxed">
                  Both Apple and Google require a publicly accessible Privacy Policy URL hosted on the internet that can be opened without logging into the app. Under Republic Act No. 10173 (Data Privacy Act of 2012), your Privacy Notice must disclose what personal data is collected, purpose of processing, third-party SDKs utilized (e.g. Firebase, Mixpanel, Sentry), retention periods, and contact details of your designated Data Protection Officer (DPO).
                </p>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* SUB-TAB 6: REVENUE & TAX SIMULATOR */}
      {subTab === 'calculator' && (
        <div className="space-y-4">
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 sm:p-5 shadow-xs">
            <div className="flex items-center gap-2 mb-2">
              <Calculator size={18} className="text-[#B03C09] dark:text-[#FF9A52]" />
              <h3 className="text-sm sm:text-base font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Interactive SaaS &amp; App Store Revenue Simulator
              </h3>
            </div>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] mb-4">
              Simulate monthly gross sales, platform cuts (Apple 15% vs MoR 5%), inward USD wire payouts, and estimated Philippine BIR tax liability to see your true take-home income in Philippine Pesos.
            </p>

            <div className="grid grid-cols-1 lg:grid-cols-12 gap-5">
              {/* Input Controls */}
              <div className="lg:col-span-5 space-y-3.5">
                {/* Gross Revenue Input */}
                <div>
                  <div className="flex items-center justify-between text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
                    <label>Monthly Gross Revenue (USD)</label>
                    <span className="text-[#B03C09] dark:text-[#FF9A52] font-mono">${monthlyGrossUsd.toLocaleString()}</span>
                  </div>
                  <input
                    type="range"
                    min="100"
                    max="20000"
                    step="100"
                    value={monthlyGrossUsd}
                    onChange={e => setMonthlyGrossUsd(Number(e.target.value))}
                    className="w-full accent-[#B03C09] dark:accent-[#FF9A52] cursor-pointer"
                  />
                  <div className="flex items-center gap-1.5 mt-1.5 overflow-x-auto no-scrollbar">
                    {[500, 1500, 3000, 5000, 10000].map(val => (
                      <button
                        key={val}
                        type="button"
                        onClick={() => setMonthlyGrossUsd(val)}
                        className={`text-[10px] px-2 py-1 rounded-md font-bold border transition-colors ${
                          monthlyGrossUsd === val
                            ? 'bg-[#B03C09] text-white border-[#B03C09] dark:bg-[#FF9A52] dark:text-[#14100D]'
                            : 'bg-[#FAFAFA] dark:bg-[#1A1512] text-[#6B6156] dark:text-[#AC9E92] border-[#F3DFCD] dark:border-[#383029]'
                        }`}
                      >
                        ${val.toLocaleString()}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Average Price / Subscription Ticket */}
                <div>
                  <div className="flex items-center justify-between text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
                    <label>Average Subscription Price (USD)</label>
                    <span className="font-mono text-[#15120F] dark:text-[#F6EFE8]">${avgTicketPriceUsd} / mo</span>
                  </div>
                  <input
                    type="range"
                    min="5"
                    max="100"
                    step="5"
                    value={avgTicketPriceUsd}
                    onChange={e => setAvgTicketPriceUsd(Number(e.target.value))}
                    className="w-full accent-[#B03C09] dark:accent-[#FF9A52] cursor-pointer"
                  />
                  <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                    ~{transactionCount} paying subscribers / transactions per month
                  </span>
                </div>

                {/* Platform / Monetization Channel */}
                <div>
                  <label className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                    Monetization Channel &amp; Gateway
                  </label>
                  <select
                    value={platformChannel}
                    onChange={e => setPlatformChannel(e.target.value as any)}
                    className="w-full p-2.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-hidden focus:border-[#B03C09] min-h-[44px]"
                  >
                    <option value="apple">Apple App Store (15% Small Business Program)</option>
                    <option value="google">Google Play Store (15% Tier)</option>
                    <option value="mor">Merchant of Record (Paddle / Lemon Squeezy ~5% + $0.50)</option>
                    <option value="stripe">Stripe Payment Gateway (~2.9% + $0.30 + cross-border)</option>
                    <option value="paymongo">PayMongo Philippine Gateway (Local GCash / Cards)</option>
                  </select>
                </div>

                {/* Philippine Tax Structure */}
                <div>
                  <label className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                    Philippine BIR Tax Regime
                  </label>
                  <select
                    value={taxRegime}
                    onChange={e => setTaxRegime(e.target.value as any)}
                    className="w-full p-2.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-hidden focus:border-[#B03C09] min-h-[44px]"
                  >
                    <option value="sole_8">Sole Proprietor: 8% Gross Income Tax (Under ₱3M)</option>
                    <option value="corp_cit">OPC / Corporation: 20% CIT (CREATE Act for MSME)</option>
                    <option value="graduated">Graduated Personal Income Tax Rates (TRAIN)</option>
                  </select>
                </div>

                {/* Exchange Rate */}
                <div className="flex items-center justify-between gap-2 p-2.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029]">
                  <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    USD / PHP Exchange Rate
                  </span>
                  <div className="flex items-center gap-1 text-xs font-mono font-bold text-[#B03C09] dark:text-[#FF9A52]">
                    <span>₱</span>
                    <input
                      type="number"
                      value={usdPhpRate}
                      onChange={e => setUsdPhpRate(Number(e.target.value))}
                      className="w-16 p-1 rounded bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-right text-xs"
                      step="0.5"
                    />
                  </div>
                </div>
              </div>

              {/* Simulation Results Display */}
              <div className="lg:col-span-7 bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD] dark:border-[#383029] rounded-xl p-4 sm:p-5 flex flex-col justify-between">
                <div>
                  <span className="text-[10px] font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                    Monthly Financial Breakdown
                  </span>
                  <div className="flex items-baseline justify-between gap-2 pb-3 border-b border-[#F3DFCD]/70 dark:border-[#383029]">
                    <div>
                      <span className="text-xs text-[#6B6156] dark:text-[#AC9E92]">Estimated Net Take-Home</span>
                      <div className="text-xl sm:text-2xl font-bold font-mono text-[#B03C09] dark:text-[#FF9A52]">
                        ₱{Math.round(netTakeHomePhp).toLocaleString()}
                      </div>
                    </div>
                    <div className="text-right">
                      <span className="text-[10px] px-2 py-0.5 rounded-full font-bold bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-400">
                        {takeHomePct}% retained
                      </span>
                    </div>
                  </div>

                  {/* Flow Breakdown items */}
                  <div className="space-y-2.5 py-3 text-xs">
                    {/* Gross */}
                    <div className="flex items-center justify-between text-[#15120F] dark:text-[#F6EFE8]">
                      <span>1. Gross Sales Revenue</span>
                      <div className="text-right font-mono font-semibold">
                        <span>${monthlyGrossUsd.toLocaleString()}</span>
                        <span className="text-[#6B6156] dark:text-[#AC9E92] text-[11px] block">
                          (₱{Math.round(grossPhp).toLocaleString()})
                        </span>
                      </div>
                    </div>

                    {/* Platform cut */}
                    <div className="flex items-center justify-between text-red-600 dark:text-red-400">
                      <span>2. Platform Fee ({platformFeeLabel.split('(')[0]})</span>
                      <div className="text-right font-mono font-semibold">
                        <span>-${Math.round(platformFeeUsd).toLocaleString()}</span>
                        <span className="text-[11px] block">
                          (-₱{Math.round(platformFeePhp).toLocaleString()})
                        </span>
                      </div>
                    </div>

                    {/* Inward bank wire */}
                    <div className="flex items-center justify-between text-[#15120F] dark:text-[#F6EFE8] pt-1 border-t border-[#F3DFCD]/60 dark:border-[#383029]">
                      <span className="font-bold">3. Inward Bank Wire (BPI / UnionBank / BDO)</span>
                      <div className="text-right font-mono font-bold text-emerald-600 dark:text-emerald-400">
                        <span>${Math.round(netPayoutUsd).toLocaleString()}</span>
                        <span className="text-[11px] block">
                          (₱{Math.round(netPayoutPhp).toLocaleString()})
                        </span>
                      </div>
                    </div>

                    {/* BIR Tax */}
                    <div className="flex items-center justify-between text-amber-700 dark:text-amber-400">
                      <span>4. Estimated BIR Tax Liability</span>
                      <div className="text-right font-mono font-semibold">
                        <span>-₱{Math.round(estimatedMonthlyTaxPhp).toLocaleString()}</span>
                        <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] block">
                          (0% Zero-Rated VAT applies)
                        </span>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Tax Insight Box */}
                <div className="mt-3 p-3 rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD]/70 dark:border-[#383029] text-[11px] text-[#5A5148] dark:text-[#C6B8AC]">
                  <strong className="text-[#15120F] dark:text-[#F6EFE8] block mb-0.5">
                    CPA Council Advisory Note:
                  </strong>
                  {taxExplanation}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
