import React, { useState, useEffect } from 'react';
import { 
  Building2, Briefcase, Scale, FileText, FileCheck, 
  ShieldAlert, CheckSquare, Layers, Globe, HelpCircle, 
  ChevronDown, ChevronUp, Check, AlertTriangle, 
  ExternalLink, Sparkles, Compass, ShieldCheck, 
  ArrowRight, RotateCcw, Info, Smartphone, CreditCard, 
  Laptop, Calculator
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { SaaSAppStoreGuide } from './SaaSAppStoreGuide';

interface ChecklistItem {
  id: string;
  category: 'legal' | 'tax' | 'lgu' | 'employer' | 'digital';
  title: string;
  agency: string;
  description: string;
  importance: 'Mandatory' | 'Recommended' | 'Conditional';
}

const CHECKLIST_ITEMS: ChecklistItem[] = [
  {
    id: 'chk_dti_sec',
    category: 'legal',
    title: 'Register Business Name & Entity',
    agency: 'DTI (Sole Prop) or SEC (Corp/OPC/Partnership)',
    description: 'Secure DTI Business Name Registration Certificate or SEC Certificate of Incorporation/Partnership via eSPARC.',
    importance: 'Mandatory',
  },
  {
    id: 'chk_trademark',
    category: 'legal',
    title: 'File Trademark Application for Brand & Logo',
    agency: 'IPOPHL (Bureau of Trademarks)',
    description: 'Protect trade name and visual marks under RA 8293 first-to-file rule. DTI/SEC registration does not protect brand rights.',
    importance: 'Recommended',
  },
  {
    id: 'chk_brgy',
    category: 'lgu',
    title: 'Obtain Barangay Business Clearance',
    agency: 'Barangay Office of Location',
    description: 'Required clearance from the specific barangay where the physical office, co-working space, or facility operates.',
    importance: 'Mandatory',
  },
  {
    id: 'chk_locational',
    category: 'lgu',
    title: 'Secure Locational & Zoning Clearance',
    agency: 'City or Municipal Planning & Development Office',
    description: 'Confirms that your commercial activity conforms to municipal zoning laws and land-use plans.',
    importance: 'Mandatory',
  },
  {
    id: 'chk_fsic',
    category: 'lgu',
    title: 'Fire Safety Inspection Certificate (FSIC)',
    agency: 'Bureau of Fire Protection (BFP)',
    description: 'Inspection proving compliance with the Fire Code of the Philippines prior to Mayor\'s Permit issuance.',
    importance: 'Mandatory',
  },
  {
    id: 'chk_mayor_permit',
    category: 'lgu',
    title: 'Obtain Mayor\'s Business Permit',
    agency: 'LGU Business Permit & Licensing Office (BPLO)',
    description: 'The final local license allowing commercial operation within city or municipal boundaries.',
    importance: 'Mandatory',
  },
  {
    id: 'chk_bir_cor',
    category: 'tax',
    title: 'Secure BIR Certificate of Registration (Form 2303)',
    agency: 'Bureau of Internal Revenue (RDO)',
    description: 'Register via Form 1901 (Sole Prop) or Form 1903 (Corp/Partnership). Display publicly at place of business.',
    importance: 'Mandatory',
  },
  {
    id: 'chk_books',
    category: 'tax',
    title: 'Register & Stamp Official Books of Accounts',
    agency: 'Bureau of Internal Revenue (RDO)',
    description: 'Register manual, loose-leaf, or computerized journals and ledgers (Cash Receipts, Disbursements, General Journal, Ledger).',
    importance: 'Mandatory',
  },
  {
    id: 'chk_atp_invoice',
    category: 'tax',
    title: 'Authority to Print (ATP) Official Invoices',
    agency: 'Bureau of Internal Revenue (RDO)',
    description: 'Print compliant sales invoices with an accredited printer under the Ease of Paying Taxes (EOPT) Act standards.',
    importance: 'Mandatory',
  },
  {
    id: 'chk_sss',
    category: 'employer',
    title: 'Register as Employer with SSS',
    agency: 'Social Security System (SSS)',
    description: 'Employer Form R-1 and Employee initial reporting Form R-1A. Mandatory even if employing only 1 staff member.',
    importance: 'Mandatory',
  },
  {
    id: 'chk_philhealth',
    category: 'employer',
    title: 'Register Employer Account with PhilHealth',
    agency: 'Philippine Health Insurance Corporation',
    description: 'Secure PhilHealth Employer Number (PEN) via Form ER1 and register enrolled staff.',
    importance: 'Mandatory',
  },
  {
    id: 'chk_pagibig',
    category: 'employer',
    title: 'Register Employer Account with Pag-IBIG Fund',
    agency: 'Home Development Mutual Fund (HDMF)',
    description: 'Secure Pag-IBIG Employer ID via Form HQP-PFF-002 for mandatory monthly housing fund remittances.',
    importance: 'Mandatory',
  },
  {
    id: 'chk_dole',
    category: 'employer',
    title: 'File DOLE Rule 1020 Establishment Notice',
    agency: 'Department of Labor and Employment',
    description: 'Mandatory registration of commercial establishment with DOLE Regional Office within 30 days of opening.',
    importance: 'Mandatory',
  },
  {
    id: 'chk_npc',
    category: 'digital',
    title: 'National Privacy Commission (NPC) Compliance',
    agency: 'National Privacy Commission',
    description: 'Appoint Data Protection Officer (DPO), draft Privacy Notice and Manual under RA 10173 (Data Privacy Act).',
    importance: 'Mandatory',
  },
  {
    id: 'chk_ntc',
    category: 'digital',
    title: 'NTC Value-Added Service (VAS) Provider License',
    agency: 'National Telecommunications Commission',
    description: 'Required if offering messaging, VoIP, premium content, telecom-routed data, or wireless equipment services.',
    importance: 'Conditional',
  },
  {
    id: 'chk_ecommerce',
    category: 'digital',
    title: 'Internet Transactions Act (RA 11967) Trust Compliance',
    agency: 'DTI E-Commerce Bureau',
    description: 'Post transparent merchant identity, terms of service, fair refund policies, and register with the online business registry.',
    importance: 'Mandatory',
  },
  {
    id: 'chk_bsp_ops',
    category: 'digital',
    title: 'BSP Operator of Payment System (OPS) Registration',
    agency: 'Bangko Sentral ng Pilipinas',
    description: 'Required if holding, routing, or processing electronic consumer payments, digital wallets, or payment gateways.',
    importance: 'Conditional',
  },
  {
    id: 'chk_duns',
    category: 'digital',
    title: 'Obtain Free D-U-N-S Number from Dun & Bradstreet',
    agency: 'Dun & Bradstreet / Apple D-U-N-S Lookup',
    description: 'Required to enroll in the Apple Developer Program as an Organization and for Google Play enterprise verification using your SEC-registered company.',
    importance: 'Mandatory',
  },
  {
    id: 'chk_apple_org',
    category: 'digital',
    title: 'Apple Developer Program (Organization Account)',
    agency: 'Apple Inc. (Apple Developer)',
    description: 'Enables publishing under your corporate brand name instead of personal legal name, grants team seats, and qualifies for 15% Small Business Program.',
    importance: 'Mandatory',
  },
  {
    id: 'chk_google_play',
    category: 'digital',
    title: 'Google Play Console Developer Account',
    agency: 'Google LLC (Play Console)',
    description: 'Set up an Organization account ($25 one-time) to bypass the mandatory 20-tester 14-day closed testing hurdle imposed on new personal accounts.',
    importance: 'Mandatory',
  },
  {
    id: 'chk_mor_billing',
    category: 'digital',
    title: 'Merchant of Record (MoR) or Payment Gateway Setup',
    agency: 'Paddle / Lemon Squeezy / Stripe / PayMongo',
    description: 'Integrate Lemon Squeezy or Paddle to automate global VAT/sales tax, or PayMongo for local Philippine GCash and Maya checkouts.',
    importance: 'Mandatory',
  },
  {
    id: 'chk_account_delete',
    category: 'digital',
    title: 'In-App Account & Data Deletion Mechanism',
    agency: 'App Store Guideline 5.1.1(v) & RA 10173',
    description: 'Mandatory for any mobile application with account creation: include an in-app button allowing users to initiate full account deletion.',
    importance: 'Mandatory',
  },
  {
    id: 'chk_zero_vat_invoice',
    category: 'digital',
    title: 'BIR Zero-Rated Sales Invoice Setup for Global Remittances',
    agency: 'Bureau of Internal Revenue',
    description: 'Create compliant sales invoice templates under the EOPT Act documenting inward USD wire transfers from Apple, Google, or MoRs under Section 108(B)(2).',
    importance: 'Mandatory',
  },
];

interface PHBusinessStartupGuideProps {
  onBackToLessons?: () => void;
  initialTab?: 'entities' | 'roadmap' | 'checklist' | 'experts' | 'saas';
  initialSaasSubTab?: 'overview' | 'stores' | 'billing' | 'taxation' | 'survival' | 'calculator';
}

export const PHBusinessStartupGuide: React.FC<PHBusinessStartupGuideProps> = ({
  onBackToLessons,
  initialTab = 'roadmap',
  initialSaasSubTab = 'overview',
}) => {
  const [activeTab, setActiveTab] = useState<'entities' | 'roadmap' | 'checklist' | 'experts' | 'saas'>(initialTab);
  const [expandedPhase, setExpandedPhase] = useState<number | null>(1);
  const [checkedItems, setCheckedItems] = useState<string[]>([]);
  const [entityFilter, setEntityFilter] = useState<'all' | 'sole_prop' | 'opc' | 'corp' | 'partnership'>('all');

  // SaaS & App Store Launchpad sub-tab state
  const [saasSubTab, setSaasSubTab] = useState<'overview' | 'stores' | 'billing' | 'taxation' | 'survival' | 'calculator'>(initialSaasSubTab);

  useEffect(() => {
    if (initialTab) {
      setActiveTab(initialTab);
    }
  }, [initialTab]);

  useEffect(() => {
    if (initialSaasSubTab) {
      setSaasSubTab(initialSaasSubTab);
    }
  }, [initialSaasSubTab]);
  const [saasRevUsd, setSaasRevUsd] = useState<number>(2500);
  const [saasChannel, setSaasChannel] = useState<'apple' | 'google' | 'mor' | 'stripe' | 'paymongo'>('apple');
  const [saasTxCount, setSaasTxCount] = useState<number>(100);
  const [saasFxRate, setSaasFxRate] = useState<number>(58.50);
  const [saasTaxRegime, setSaasTaxRegime] = useState<'sole_8' | 'corp_cit' | 'graduated'>('sole_8');
  const [saasCostRatio, setSaasCostRatio] = useState<number>(25);

  // Interactive Entity Matcher Quiz state
  const [quizStep, setQuizStep] = useState<number>(0);
  const [quizAnswers, setQuizAnswers] = useState<{
    owners: string;
    liability: string;
    funding: string;
    compliance: string;
  }>({
    owners: '',
    liability: '',
    funding: '',
    compliance: '',
  });

  // Load saved checklist state
  useEffect(() => {
    try {
      const saved = localStorage.getItem('salapify_business_checklist');
      if (saved) {
        setCheckedItems(JSON.parse(saved));
      }
    } catch {
      // ignore
    }
  }, []);

  const toggleCheckItem = (id: string) => {
    let next: string[];
    if (checkedItems.includes(id)) {
      next = checkedItems.filter(item => item !== id);
    } else {
      next = [...checkedItems, id];
    }
    setCheckedItems(next);
    localStorage.setItem('salapify_business_checklist', JSON.stringify(next));
  };

  const checklistProgress = Math.round((checkedItems.length / CHECKLIST_ITEMS.length) * 100);

  // Entity recommendation logic
  const getEntityRecommendation = () => {
    if (!quizAnswers.owners) return null;
    if (quizAnswers.owners === 'single') {
      if (quizAnswers.liability === 'protected' || quizAnswers.funding === 'investors') {
        return {
          title: 'One Person Corporation (OPC)',
          summary: 'Ideal for solo entrepreneurs who demand complete operational autonomy while securing limited liability protection to safeguard personal assets.',
          reasons: [
            'Only 1 stockholder required under Revised Corporation Code (RA 11232).',
            'Personal properties (home, family savings) are shielded from corporate debt.',
            'No statutory minimum capital requirement (unless in regulated industries).',
            'Must appoint Nominee and Alternate Nominee to guarantee continuity.',
          ]
        };
      }
      return {
        title: 'Sole Proprietorship',
        summary: 'Best for low-capital, solo freelancers, home-based traders, or small retail businesses needing rapid, low-cost registration.',
        reasons: [
          'Registered simply with DTI (no complex corporate bylaws or board meetings).',
          'Lowest formation fees (₱200-₱2,000 DTI registration fee).',
          'Pass-through taxation: eligible for simplified 8% gross income tax under TRAIN law if revenue is under ₱3M.',
          'Trade-off: Unlimited personal liability for business debts and obligations.',
        ]
      };
    } else {
      if (quizAnswers.funding === 'investors' || quizAnswers.liability === 'protected') {
        return {
          title: 'Regular Stock Corporation',
          summary: 'The gold standard for scalable startups, tech ventures, and businesses with multiple co-founders planning to raise venture capital.',
          reasons: [
            'Can have 2 to 15 incorporators under the Revised Corporation Code.',
            'Can issue multiple share classes (common, preferred) to angel investors and venture funds.',
            'Limited liability for all shareholders up to their capital subscriptions.',
            'Subject to Corporate Income Tax (20% under CREATE for small-medium firms with taxable income under ₱5M and assets under ₱100M).',
          ]
        };
      }
      return {
        title: 'General or Limited Partnership',
        summary: 'Suited for two or more professional partners (consultants, designers, agencies) co-owning an enterprise under a joint agreement.',
        reasons: [
          'Registered with SEC via Articles of Partnership.',
          'Clear contractual profit/loss distribution between co-owners.',
          'Trade-off: In general partnerships, partners carry joint and several personal liability.',
        ]
      };
    }
  };

  const recommendation = getEntityRecommendation();

  return (
    <div className="space-y-4 pb-12">
      {/* Top Header & Context */}
      <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 sm:p-5 shadow-xs">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-3">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52] bg-[#FFEEDF] dark:bg-[#383029] px-2 py-0.5 rounded-md">
                Legal &amp; Regulatory Blueprint
              </span>
              <span className="text-[10px] font-semibold text-[#6B6156] dark:text-[#AC9E92]">
                Republic of the Philippines
              </span>
            </div>
            <h2 className="text-base sm:text-xl font-black text-[#15120F] dark:text-[#F6EFE8]">
              Philippine Business Startup &amp; Launch Guide
            </h2>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] mt-0.5 max-w-2xl">
              A comprehensive roadmap for structuring, registering, and legally operating sole proprietorships, partnerships, regular corporations, and One Person Corporations (OPC).
            </p>
          </div>

          {onBackToLessons && (
            <button
              type="button"
              onClick={onBackToLessons}
              className="self-start sm:self-center px-3 py-2 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] hover:bg-[#FFEEDF] dark:hover:bg-[#383029] text-[#6B6156] dark:text-[#AC9E92] hover:text-[#B03C09] dark:hover:text-[#FF9A52] border border-[#F3DFCD] dark:border-[#383029] transition-colors text-xs font-bold min-h-[44px] flex items-center gap-1.5 shrink-0"
            >
              <span>Back to Lessons</span>
            </button>
          )}
        </div>

        {/* Prominent Mandatory Professional Disclaimer */}
        <div className="bg-[#FFF5ED] dark:bg-[#2E241E] border border-[#F3DFCD] dark:border-[#5A5148] rounded-xl p-3.5 flex items-start gap-3">
          <AlertTriangle size={20} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0 mt-0.5" />
          <div className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
            <strong className="text-[#15120F] dark:text-[#F6EFE8] block mb-0.5">
              Important Legal &amp; Tax Disclaimer:
            </strong>
            This interactive guide is designed strictly for educational, structural comparison, and organizational planning purposes. It does not constitute formal legal, corporate, investment, or tax counsel. Laws, municipal ordinances, BIR tax regulations (such as the Ease of Paying Taxes Act), and agency filing procedures change frequently. Founders must consult with licensed Philippine CPAs, accredited corporate lawyers, and professional business consultants prior to signing contracts, paying filing fees, or commencing commercial operations.
          </div>
        </div>

        {/* Expert Council Banner */}
        <div className="mt-3 pt-3 border-t border-[#F3DFCD]/60 dark:border-[#383029] flex flex-wrap items-center gap-3 text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
          <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1">
            <Sparkles size={13} className="text-[#B03C09] dark:text-[#FF9A52]" /> Expert Advisory Council:
          </span>
          <span className="px-2 py-0.5 rounded-md bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/50 dark:border-[#383029]">
            Business Strategist &amp; Advisor
          </span>
          <span className="px-2 py-0.5 rounded-md bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/50 dark:border-[#383029]">
            PH Corporate Consultant
          </span>
          <span className="px-2 py-0.5 rounded-md bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/50 dark:border-[#383029]">
            BIR &amp; Gov Tax Specialist
          </span>
          <span className="px-2 py-0.5 rounded-md bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/50 dark:border-[#383029]">
            Legal &amp; Compliance Counsel
          </span>
        </div>
      </div>

      {/* Main Tab Navigation */}
      <div className="flex items-center gap-1.5 overflow-x-auto p-1 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-xl no-scrollbar">
        {[
          { id: 'roadmap', label: 'Registration Roadmap', icon: Compass },
          { id: 'saas', label: 'SaaS & App Stores', icon: Smartphone, badge: 'HOT' },
          { id: 'entities', label: 'Entity Comparison', icon: Building2 },
          { id: 'checklist', label: 'Readiness Tracker', icon: CheckSquare, badge: `${checkedItems.length}/${CHECKLIST_ITEMS.length}` },
          { id: 'experts', label: 'Expert Pitfalls & Q&A', icon: HelpCircle },
        ].map(tab => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              type="button"
              onClick={() => setActiveTab(tab.id as any)}
              className={`px-3 py-2 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 whitespace-nowrap min-h-[44px] shrink-0 ${
                isActive
                  ? 'bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] shadow-xs'
                  : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] hover:bg-[#FAFAFA] dark:hover:bg-[#1A1512]'
              }`}
            >
              <Icon size={15} />
              <span>{tab.label}</span>
              {tab.badge && (
                <span className={`text-[10px] px-1.5 py-0.2 rounded-full font-bold ${
                  isActive ? 'bg-white/20 text-white dark:text-[#14100D]' : 'bg-[#FFEEDF] text-[#B03C09] dark:bg-[#383029] dark:text-[#FF9A52]'
                }`}>
                  {tab.badge}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {/* TAB 1: REGISTRATION ROADMAP */}
      {activeTab === 'roadmap' && (
        <div className="space-y-4">
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
              Sequential Philippine Business Formation Pipeline
            </h3>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
              Follow this verified sequential order to prevent rejected filings, repeated LGU visits, and costly BIR late registration penalties.
            </p>
          </div>

          {/* Phase 1: Name & Entity */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl overflow-hidden shadow-xs">
            <button
              type="button"
              onClick={() => setExpandedPhase(expandedPhase === 1 ? null : 1)}
              className="w-full p-4 flex items-center justify-between text-left hover:bg-[#FAFAFA] dark:hover:bg-[#1E1915] transition-colors min-h-[44px]"
            >
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-xl bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center font-bold text-xs shrink-0">
                  1
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                      Initial Formation
                    </span>
                    <span className="text-[10px] font-semibold text-[#6B6156] dark:text-[#AC9E92]">
                      DTI / SEC eSPARC
                    </span>
                  </div>
                  <h4 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Phase 1: Legal Name Reservation &amp; Entity Registration
                  </h4>
                </div>
              </div>
              {expandedPhase === 1 ? <ChevronUp size={18} className="text-[#6B6156]" /> : <ChevronDown size={18} className="text-[#6B6156]" />}
            </button>

            {expandedPhase === 1 && (
              <div className="p-4 pt-0 border-t border-[#F3DFCD]/60 dark:border-[#383029] space-y-3 text-xs text-[#5A5148] dark:text-[#C6B8AC]">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mt-3">
                  {/* Sole Prop Path */}
                  <div className="p-3.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029]">
                    <span className="text-[11px] font-bold text-[#B03C09] dark:text-[#FF9A52] block mb-1">
                      For Sole Proprietorship: DTI BNRS
                    </span>
                    <p className="mb-2 leading-relaxed">
                      Register your trade name through the DTI Business Name Registration System (bnrs.dti.gov.ph). Select territorial scope:
                    </p>
                    <ul className="list-disc list-inside space-y-1 font-medium text-[#15120F] dark:text-[#F6EFE8]">
                      <li>Barangay: ₱200 fee (+ ₱30 documentary stamp)</li>
                      <li>City / Municipality: ₱500 fee (+ ₱30 doc stamp)</li>
                      <li>Regional: ₱1,000 fee (+ ₱30 doc stamp)</li>
                      <li>National: ₱2,000 fee (+ ₱30 doc stamp)</li>
                    </ul>
                    <p className="mt-2 text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                      *Valid for 5 years. DTI certificates alone do not authorize you to operate; LGU and BIR registrations remain mandatory.
                    </p>
                  </div>

                  {/* Corp / OPC / Partnership Path */}
                  <div className="p-3.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/70 dark:border-[#383029]">
                    <span className="text-[11px] font-bold text-[#B03C09] dark:text-[#FF9A52] block mb-1">
                      For Corp / OPC / Partnership: SEC eSPARC
                    </span>
                    <p className="mb-2 leading-relaxed">
                      Submit articles and bylaws online via the SEC Electronic Simplified Processing of Application for Registration of Company (esparc.sec.gov.ph):
                    </p>
                    <ul className="list-disc list-inside space-y-1 font-medium text-[#15120F] dark:text-[#F6EFE8]">
                      <li>Name Verification Slip (reserve company name)</li>
                      <li>Articles of Incorporation &amp; By-Laws (or OPC Articles)</li>
                      <li>Treasurer\'s Affidavit / Undertaking to change name</li>
                      <li>Nominee and Alternate Nominee acceptance (OPC only)</li>
                    </ul>
                    <p className="mt-2 text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                      *Filing fees are calculated based on authorized capital stock (minimum approx. ₱2,000 to ₱5,000+).
                    </p>
                  </div>
                </div>

                <div className="p-3 rounded-xl bg-[#FFEEDF]/60 dark:bg-[#383029]/50 border border-[#F3DFCD] dark:border-[#5A5148] flex items-start gap-2.5">
                  <Sparkles size={16} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0 mt-0.5" />
                  <div>
                    <strong className="text-[#15120F] dark:text-[#F6EFE8] block mb-0.5">
                      Consultant Insight: Business Name vs. Trademark Warning
                    </strong>
                    Registering your business name with DTI or SEC does <em>not</em> grant intellectual property ownership over your brand or logo. Another entity can legally register your brand name with IPOPHL if you fail to file a trademark.
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Phase 2: Trademark & Brand (IPOPHL) */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl overflow-hidden shadow-xs">
            <button
              type="button"
              onClick={() => setExpandedPhase(expandedPhase === 2 ? null : 2)}
              className="w-full p-4 flex items-center justify-between text-left hover:bg-[#FAFAFA] dark:hover:bg-[#1E1915] transition-colors min-h-[44px]"
            >
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-xl bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center font-bold text-xs shrink-0">
                  2
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                      Intellectual Property
                    </span>
                    <span className="text-[10px] font-semibold text-[#6B6156] dark:text-[#AC9E92]">
                      IPOPHL (First-to-File)
                    </span>
                  </div>
                  <h4 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Phase 2: Trademark &amp; Brand Asset Protection
                  </h4>
                </div>
              </div>
              {expandedPhase === 2 ? <ChevronUp size={18} className="text-[#6B6156]" /> : <ChevronDown size={18} className="text-[#6B6156]" />}
            </button>

            {expandedPhase === 2 && (
              <div className="p-4 pt-0 border-t border-[#F3DFCD]/60 dark:border-[#383029] space-y-3 text-xs text-[#5A5148] dark:text-[#C6B8AC]">
                <div className="space-y-2 mt-3">
                  <p className="leading-relaxed">
                    Under the Intellectual Property Code of the Philippines (Republic Act No. 8293), trademarks operate under the <strong>First-to-File principle</strong>. The person or company who files first holds legal priority, regardless of who used the name first in commerce.
                  </p>
                  
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5 my-2">
                    <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029]">
                      <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                        1. Search &amp; Nice Class
                      </span>
                      <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                        Conduct search on IPOPHL e-Search and WIPO Global Brand Database. Identify applicable Nice Classes (e.g., Class 9 for software, Class 35 for retail, Class 42 for SaaS).
                      </p>
                    </div>

                    <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029]">
                      <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                        2. File &amp; Examination
                      </span>
                      <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                        Submit application online via IPOPHL eTMfile. Examination takes 3-6 months. Once cleared, it is published in the IPOPHL e-Gazette for a 30-day public opposition period.
                      </p>
                    </div>

                    <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029]">
                      <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                        3. Registration &amp; DAU
                      </span>
                      <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                        Certificate is valid for 10 years. Crucial: You MUST file a Declaration of Actual Use (DAU) with proof of commerce within 3 years and 5 years to maintain the mark.
                      </p>
                    </div>
                  </div>

                  <div className="p-3 rounded-xl bg-[#FFEEDF]/60 dark:bg-[#383029]/50 border border-[#F3DFCD] dark:border-[#5A5148] flex items-start gap-2.5">
                    <Info size={16} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0 mt-0.5" />
                    <div>
                      <strong className="text-[#15120F] dark:text-[#F6EFE8] block mb-0.5">
                        Legal Counsel Pro-Tip:
                      </strong>
                      If building a digital product, app, or consumer brand, file your IPOPHL application on Day 1 before public launch. Competitors or trademark squatters who notice your initial traction can register your name, forcing costly rebranding or legal buyouts.
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Phase 3: LGU & Mayor's Permit */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl overflow-hidden shadow-xs">
            <button
              type="button"
              onClick={() => setExpandedPhase(expandedPhase === 3 ? null : 3)}
              className="w-full p-4 flex items-center justify-between text-left hover:bg-[#FAFAFA] dark:hover:bg-[#1E1915] transition-colors min-h-[44px]"
            >
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-xl bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center font-bold text-xs shrink-0">
                  3
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                      Local Governance
                    </span>
                    <span className="text-[10px] font-semibold text-[#6B6156] dark:text-[#AC9E92]">
                      Barangay &amp; City Hall (BPLO)
                    </span>
                  </div>
                  <h4 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Phase 3: Local Government Unit (LGU) Clearances &amp; Mayor\'s Permit
                  </h4>
                </div>
              </div>
              {expandedPhase === 3 ? <ChevronUp size={18} className="text-[#6B6156]" /> : <ChevronDown size={18} className="text-[#6B6156]" />}
            </button>

            {expandedPhase === 3 && (
              <div className="p-4 pt-0 border-t border-[#F3DFCD]/60 dark:border-[#383029] space-y-3 text-xs text-[#5A5148] dark:text-[#C6B8AC]">
                <div className="space-y-2 mt-3">
                  <p className="leading-relaxed">
                    You cannot legally operate a business without a Mayor\'s Permit from the city or municipality where your office, clinic, warehouse, or virtual office is located.
                  </p>

                  <div className="space-y-2">
                    <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029] flex items-start gap-2">
                      <span className="w-5 h-5 rounded-full bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] font-bold flex items-center justify-center text-[10px] shrink-0 mt-0.5">
                        A
                      </span>
                      <div>
                        <strong className="text-[#15120F] dark:text-[#F6EFE8] block">
                          Barangay Business Clearance
                        </strong>
                        <span className="text-[#6B6156] dark:text-[#AC9E92]">
                          Obtain from the barangay hall of your address. Requires DTI/SEC certificate, contract of lease, and proof of address. Fee: ₱300 - ₱1,500.
                        </span>
                      </div>
                    </div>

                    <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029] flex items-start gap-2">
                      <span className="w-5 h-5 rounded-full bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] font-bold flex items-center justify-center text-[10px] shrink-0 mt-0.5">
                        B
                      </span>
                      <div>
                        <strong className="text-[#15120F] dark:text-[#F6EFE8] block">
                          Locational / Zoning Clearance
                        </strong>
                        <span className="text-[#6B6156] dark:text-[#AC9E92]">
                          Verifies that your business activity is permitted in the designated commercial zone. Pure residential zoning may prohibit physical customer traffic.
                        </span>
                      </div>
                    </div>

                    <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029] flex items-start gap-2">
                      <span className="w-5 h-5 rounded-full bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] font-bold flex items-center justify-center text-[10px] shrink-0 mt-0.5">
                        C
                      </span>
                      <div>
                        <strong className="text-[#15120F] dark:text-[#F6EFE8] block">
                          Fire Safety Inspection Certificate (FSIC) &amp; Sanitary Permit
                        </strong>
                        <span className="text-[#6B6156] dark:text-[#AC9E92]">
                          Bureau of Fire Protection (BFP) inspects fire extinguishers, emergency exits, and electrical wiring. Health Department issues sanitary permits and staff health cards.
                        </span>
                      </div>
                    </div>

                    <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029] flex items-start gap-2">
                      <span className="w-5 h-5 rounded-full bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] font-bold flex items-center justify-center text-[10px] shrink-0 mt-0.5">
                        D
                      </span>
                      <div>
                        <strong className="text-[#15120F] dark:text-[#F6EFE8] block">
                          Business Permit and Licensing Office (BPLO) Assessment
                        </strong>
                        <span className="text-[#6B6156] dark:text-[#AC9E92]">
                          Submit all clearances. BPLO calculates local business taxes (LBT) and regulatory fees. Mayor\'s Permit is released along with official receipt and business plate.
                        </span>
                      </div>
                    </div>
                  </div>

                  <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] italic">
                    Note: Mayor\'s Permits must be renewed annually between January 1 and January 20 to avoid a 25% surcharge plus 2% monthly interest.
                  </p>
                </div>
              </div>
            )}
          </div>

          {/* Phase 4: BIR Tax Registration */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl overflow-hidden shadow-xs">
            <button
              type="button"
              onClick={() => setExpandedPhase(expandedPhase === 4 ? null : 4)}
              className="w-full p-4 flex items-center justify-between text-left hover:bg-[#FAFAFA] dark:hover:bg-[#1E1915] transition-colors min-h-[44px]"
            >
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-xl bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center font-bold text-xs shrink-0">
                  4
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                      National Taxation
                    </span>
                    <span className="text-[10px] font-semibold text-[#6B6156] dark:text-[#AC9E92]">
                      BIR Form 2303 &amp; Invoicing
                    </span>
                  </div>
                  <h4 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Phase 4: BIR Registration, Books of Accounts &amp; EOPT Act Invoices
                  </h4>
                </div>
              </div>
              {expandedPhase === 4 ? <ChevronUp size={18} className="text-[#6B6156]" /> : <ChevronDown size={18} className="text-[#6B6156]" />}
            </button>

            {expandedPhase === 4 && (
              <div className="p-4 pt-0 border-t border-[#F3DFCD]/60 dark:border-[#383029] space-y-3 text-xs text-[#5A5148] dark:text-[#C6B8AC]">
                <div className="space-y-3 mt-3">
                  <div className="p-3 rounded-xl bg-[#FFEEDF]/60 dark:bg-[#383029]/50 border border-[#F3DFCD] dark:border-[#5A5148]">
                    <span className="text-[11px] font-bold text-[#B03C09] dark:text-[#FF9A52] block mb-1">
                      Recent Law: Ease of Paying Taxes (EOPT) Act (RA 11976)
                    </span>
                    <ul className="list-disc list-inside space-y-1 text-[11px] leading-relaxed">
                      <li>The annual ₱500 BIR Registration Fee (Form 0605) has been <strong>permanently abolished</strong>.</li>
                      <li>Invoices are now the primary document for both sales of goods and sales of services (official receipts are now supplemental).</li>
                      <li>Taxpayers can now register and file taxes at any authorized RDO without territorial jurisdiction penalties.</li>
                    </ul>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029]">
                      <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                        Application Form
                      </span>
                      <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] mb-1.5">
                        Submit at your local Revenue District Office (RDO):
                      </p>
                      <ul className="list-disc list-inside space-y-1 font-medium text-[#15120F] dark:text-[#F6EFE8]">
                        <li>BIR Form 1901: Sole Proprietorship / Professionals</li>
                        <li>BIR Form 1903: Corporations &amp; Partnerships</li>
                      </ul>
                    </div>

                    <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029]">
                      <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                        Form 2303 (COR)
                      </span>
                      <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                        The Certificate of Registration lists all your mandatory tax returns (e.g. 2551Q Percentage Tax or 2550Q VAT, 1701Q/1702Q Income Tax, 1601C Withholding Tax on Compensation).
                      </p>
                    </div>
                  </div>

                  <div className="p-3.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029] space-y-2">
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] block">
                      Authority to Print (ATP) &amp; Books of Accounts
                    </span>
                    <p className="leading-relaxed">
                      Every business must register its official books:
                    </p>
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-center text-[11px] font-bold">
                      <div className="p-2 rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD]/50 dark:border-[#383029]">General Journal</div>
                      <div className="p-2 rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD]/50 dark:border-[#383029]">General Ledger</div>
                      <div className="p-2 rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD]/50 dark:border-[#383029]">Cash Receipts</div>
                      <div className="p-2 rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD]/50 dark:border-[#383029]">Cash Disbursements</div>
                    </div>
                    <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                      *Submit BIR Form 1906 for Authority to Print (ATP) with an accredited BIR printer for your physical sales invoices. If using electronic invoicing, apply for Permit to Use (PTU) or Computerized Accounting System (CAS).
                    </p>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Phase 5: Statutory Employer Registrations */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl overflow-hidden shadow-xs">
            <button
              type="button"
              onClick={() => setExpandedPhase(expandedPhase === 5 ? null : 5)}
              className="w-full p-4 flex items-center justify-between text-left hover:bg-[#FAFAFA] dark:hover:bg-[#1E1915] transition-colors min-h-[44px]"
            >
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-xl bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center font-bold text-xs shrink-0">
                  5
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                      Mandatory Labor Benefits
                    </span>
                    <span className="text-[10px] font-semibold text-[#6B6156] dark:text-[#AC9E92]">
                      SSS, PhilHealth, Pag-IBIG, DOLE
                    </span>
                  </div>
                  <h4 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Phase 5: Mandatory Statutory Employer Registrations
                  </h4>
                </div>
              </div>
              {expandedPhase === 5 ? <ChevronUp size={18} className="text-[#6B6156]" /> : <ChevronDown size={18} className="text-[#6B6156]" />}
            </button>

            {expandedPhase === 5 && (
              <div className="p-4 pt-0 border-t border-[#F3DFCD]/60 dark:border-[#383029] space-y-3 text-xs text-[#5A5148] dark:text-[#C6B8AC]">
                <div className="space-y-3 mt-3">
                  <p className="leading-relaxed">
                    Under Philippine labor laws, the moment you hire your first employee, you are legally classified as an employer and must register with all statutory institutions:
                  </p>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029]">
                      <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                        Social Security System (SSS)
                      </span>
                      <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] leading-relaxed">
                        Submit Form R-1 (Employer Registration) and Form R-1A (Employment Report). Mandatory for retirement, sickness, maternity, disability, and death benefits.
                      </p>
                    </div>

                    <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029]">
                      <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                        PhilHealth
                      </span>
                      <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] leading-relaxed">
                        Submit Form ER1 (Employer Data Record) to receive your PhilHealth Employer Number (PEN). Remit mandatory national healthcare coverage monthly.
                      </p>
                    </div>

                    <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029]">
                      <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                        Pag-IBIG Fund (HDMF)
                      </span>
                      <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] leading-relaxed">
                        Submit Form HQP-PFF-002 for employer registration. Provides national housing loan facilities and savings funds for employees.
                      </p>
                    </div>

                    <div className="p-3 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029]">
                      <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                        DOLE Rule 1020 Registration
                      </span>
                      <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] leading-relaxed">
                        File establishment notice with the Department of Labor and Employment within 30 days of commercial operations for workplace safety compliance.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Phase 6: Digital & Tech Compliance */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl overflow-hidden shadow-xs">
            <button
              type="button"
              onClick={() => setExpandedPhase(expandedPhase === 6 ? null : 6)}
              className="w-full p-4 flex items-center justify-between text-left hover:bg-[#FAFAFA] dark:hover:bg-[#1E1915] transition-colors min-h-[44px]"
            >
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-xl bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center font-bold text-xs shrink-0">
                  6
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                      Tech &amp; Digital Startups
                    </span>
                    <span className="text-[10px] font-semibold text-[#6B6156] dark:text-[#AC9E92]">
                      NPC, NTC, BSP, E-Commerce
                    </span>
                  </div>
                  <h4 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    Phase 6: Digital Products, Data Privacy &amp; Sectoral Licenses
                  </h4>
                </div>
              </div>
              {expandedPhase === 6 ? <ChevronUp size={18} className="text-[#6B6156]" /> : <ChevronDown size={18} className="text-[#6B6156]" />}
            </button>

            {expandedPhase === 6 && (
              <div className="p-4 pt-0 border-t border-[#F3DFCD]/60 dark:border-[#383029] space-y-3 text-xs text-[#5A5148] dark:text-[#C6B8AC]">
                <div className="space-y-3 mt-3">
                  <p className="leading-relaxed">
                    Digital startups, web platforms, mobile apps, SaaS, and e-commerce stores have specialized statutory requirements:
                  </p>

                  <div className="space-y-2.5">
                    {/* NPC */}
                    <div className="p-3.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029]">
                      <div className="flex items-center justify-between gap-2 mb-1">
                        <span className="font-bold text-[#B03C09] dark:text-[#FF9A52]">
                          National Privacy Commission (NPC) -- RA 10173 (Data Privacy Act)
                        </span>
                        <span className="text-[9px] font-bold px-1.5 py-0.2 bg-red-100 dark:bg-red-950 text-red-700 dark:text-red-400 rounded">
                          CRITICAL
                        </span>
                      </div>
                      <p className="leading-relaxed mb-2">
                        Any app or website collecting user data (emails, passwords, phone numbers, addresses, financial logs) must comply:
                      </p>
                      <ul className="list-disc list-inside space-y-1 text-[11px]">
                        <li>Appoint an official Data Protection Officer (DPO).</li>
                        <li>Register with the NPC if processing sensitive personal information of 1,000+ individuals or employing 250+ personnel.</li>
                        <li>Display a clear, accessible Privacy Notice and cookie/data consent banners on your website/app.</li>
                        <li>Maintain a strict 72-hour notification protocol to the NPC in the event of a security data breach.</li>
                      </ul>
                    </div>

                    {/* NTC */}
                    <div className="p-3.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029]">
                      <span className="font-bold text-[#B03C09] dark:text-[#FF9A52] block mb-1">
                        National Telecommunications Commission (NTC) -- VAS License
                      </span>
                      <p className="leading-relaxed">
                        If your tech platform provides messaging services, SMS gateways, VoIP calls, premium digital content delivery, or integrates direct telecom transmission, you must secure an NTC Value-Added Service (VAS) Certificate of Registration before public rollout.
                      </p>
                    </div>

                    {/* Internet Transactions Act */}
                    <div className="p-3.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029]">
                      <span className="font-bold text-[#B03C09] dark:text-[#FF9A52] block mb-1">
                        Internet Transactions Act of 2023 (RA 11967) &amp; DTI E-Commerce Bureau
                      </span>
                      <p className="leading-relaxed">
                        Applies to all digital marketplaces, online merchants, and social commerce sellers:
                      </p>
                      <ul className="list-disc list-inside space-y-1 text-[11px] mt-1">
                        <li>Must display registered business name, DTI/SEC number, geographic address, and active contact channels.</li>
                        <li>Online platforms are solidarily liable with merchants if they knowingly allow illegal, counterfeit, or hazardous products.</li>
                        <li>Registration with the Philippine Online Business Registry is mandated.</li>
                      </ul>
                    </div>

                    {/* Sectoral: BSP, SEC Lending, FDA */}
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 text-[11px]">
                      <div className="p-2.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029]">
                        <strong className="text-[#15120F] dark:text-[#F6EFE8] block mb-0.5">Fintech &amp; Payments</strong>
                        <span>BSP Operator of Payment System (OPS) registration is required for payment aggregators, escrow wallets, or digital money remitters.</span>
                      </div>
                      <div className="p-2.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029]">
                        <strong className="text-[#15120F] dark:text-[#F6EFE8] block mb-0.5">Lending &amp; BNPL</strong>
                        <span>Strict SEC Certificate of Authority under the Lending Company Regulation Act is required to offer digital credit or installments.</span>
                      </div>
                      <div className="p-2.5 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] border border-[#F3DFCD]/60 dark:border-[#383029]">
                        <strong className="text-[#15120F] dark:text-[#F6EFE8] block mb-0.5">Health &amp; Food</strong>
                        <span>FDA License to Operate (LTO) and Certificate of Product Registration (CPR) are required before listing cosmetics or ingestibles online.</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* TAB: SAAS, WEB APPS & APP STORE LAUNCHPAD */}
      {activeTab === 'saas' && <SaaSAppStoreGuide />}

      {/* TAB 2: ENTITY COMPARISON & SELECTOR */}
      {activeTab === 'entities' && (
        <div className="space-y-4">
          {/* Interactive Entity Matcher Quiz */}
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 sm:p-5 shadow-xs">
            <div className="flex items-center gap-2 mb-2">
              <Sparkles size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />
              <h3 className="text-sm sm:text-base font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Interactive Entity Matcher: Which Structure Fits Your Business?
              </h3>
            </div>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] mb-4">
              Answer 3 simple operational questions to get a personalized recommendation from our Philippine Corporate Advisory Council.
            </p>

            <div className="space-y-3">
              {/* Question 1 */}
              <div>
                <label className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1.5">
                  1. How many founders or co-owners will start the business?
                </label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => setQuizAnswers(prev => ({ ...prev, owners: 'single' }))}
                    className={`p-2.5 rounded-xl text-xs font-bold border transition-all min-h-[44px] text-left flex items-center justify-between ${
                      quizAnswers.owners === 'single'
                        ? 'bg-[#B03C09] text-white border-[#B03C09] dark:bg-[#FF9A52] dark:text-[#14100D] dark:border-[#FF9A52]'
                        : 'bg-[#FAFAFA] dark:bg-[#1A1512] text-[#6B6156] dark:text-[#AC9E92] border-[#F3DFCD] dark:border-[#383029]'
                    }`}
                  >
                    <span>Just me (Solo Founder)</span>
                    {quizAnswers.owners === 'single' && <Check size={14} />}
                  </button>
                  <button
                    type="button"
                    onClick={() => setQuizAnswers(prev => ({ ...prev, owners: 'multiple' }))}
                    className={`p-2.5 rounded-xl text-xs font-bold border transition-all min-h-[44px] text-left flex items-center justify-between ${
                      quizAnswers.owners === 'multiple'
                        ? 'bg-[#B03C09] text-white border-[#B03C09] dark:bg-[#FF9A52] dark:text-[#14100D] dark:border-[#FF9A52]'
                        : 'bg-[#FAFAFA] dark:bg-[#1A1512] text-[#6B6156] dark:text-[#AC9E92] border-[#F3DFCD] dark:border-[#383029]'
                    }`}
                  >
                    <span>2 or more Partners / Co-founders</span>
                    {quizAnswers.owners === 'multiple' && <Check size={14} />}
                  </button>
                </div>
              </div>

              {/* Question 2 */}
              <div>
                <label className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1.5">
                  2. What is your requirement regarding personal asset liability?
                </label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => setQuizAnswers(prev => ({ ...prev, liability: 'protected' }))}
                    className={`p-2.5 rounded-xl text-xs font-bold border transition-all min-h-[44px] text-left flex items-center justify-between ${
                      quizAnswers.liability === 'protected'
                        ? 'bg-[#B03C09] text-white border-[#B03C09] dark:bg-[#FF9A52] dark:text-[#14100D] dark:border-[#FF9A52]'
                        : 'bg-[#FAFAFA] dark:bg-[#1A1512] text-[#6B6156] dark:text-[#AC9E92] border-[#F3DFCD] dark:border-[#383029]'
                    }`}
                  >
                    <span>Shield personal assets (Limited Liability)</span>
                    {quizAnswers.liability === 'protected' && <Check size={14} />}
                  </button>
                  <button
                    type="button"
                    onClick={() => setQuizAnswers(prev => ({ ...prev, liability: 'low_risk' }))}
                    className={`p-2.5 rounded-xl text-xs font-bold border transition-all min-h-[44px] text-left flex items-center justify-between ${
                      quizAnswers.liability === 'low_risk'
                        ? 'bg-[#B03C09] text-white border-[#B03C09] dark:bg-[#FF9A52] dark:text-[#14100D] dark:border-[#FF9A52]'
                        : 'bg-[#FAFAFA] dark:bg-[#1A1512] text-[#6B6156] dark:text-[#AC9E92] border-[#F3DFCD] dark:border-[#383029]'
                    }`}
                  >
                    <span>Low commercial risk / Simplicity first</span>
                    {quizAnswers.liability === 'low_risk' && <Check size={14} />}
                  </button>
                </div>
              </div>

              {/* Question 3 */}
              <div>
                <label className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1.5">
                  3. Do you plan to raise venture capital or issue shares to outside investors?
                </label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => setQuizAnswers(prev => ({ ...prev, funding: 'investors' }))}
                    className={`p-2.5 rounded-xl text-xs font-bold border transition-all min-h-[44px] text-left flex items-center justify-between ${
                      quizAnswers.funding === 'investors'
                        ? 'bg-[#B03C09] text-white border-[#B03C09] dark:bg-[#FF9A52] dark:text-[#14100D] dark:border-[#FF9A52]'
                        : 'bg-[#FAFAFA] dark:bg-[#1A1512] text-[#6B6156] dark:text-[#AC9E92] border-[#F3DFCD] dark:border-[#383029]'
                    }`}
                  >
                    <span>Yes, will raise funding / issue shares</span>
                    {quizAnswers.funding === 'investors' && <Check size={14} />}
                  </button>
                  <button
                    type="button"
                    onClick={() => setQuizAnswers(prev => ({ ...prev, funding: 'bootstrapped' }))}
                    className={`p-2.5 rounded-xl text-xs font-bold border transition-all min-h-[44px] text-left flex items-center justify-between ${
                      quizAnswers.funding === 'bootstrapped'
                        ? 'bg-[#B03C09] text-white border-[#B03C09] dark:bg-[#FF9A52] dark:text-[#14100D] dark:border-[#FF9A52]'
                        : 'bg-[#FAFAFA] dark:bg-[#1A1512] text-[#6B6156] dark:text-[#AC9E92] border-[#F3DFCD] dark:border-[#383029]'
                    }`}
                  >
                    <span>No, self-funded / client revenue</span>
                    {quizAnswers.funding === 'bootstrapped' && <Check size={14} />}
                  </button>
                </div>
              </div>
            </div>

            {/* Recommendation Result */}
            {recommendation && (
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                className="mt-4 p-4 rounded-xl bg-[#FFEEDF] dark:bg-[#383029] border border-[#F3DFCD] dark:border-[#5A5148]"
              >
                <div className="flex items-center gap-2 mb-1.5">
                  <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                    Recommended Match
                  </span>
                  <h4 className="text-base font-black text-[#15120F] dark:text-[#F6EFE8]">
                    {recommendation.title}
                  </h4>
                </div>
                <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed mb-3">
                  {recommendation.summary}
                </p>
                <div className="space-y-1 text-xs">
                  {recommendation.reasons.map((r, i) => (
                    <div key={i} className="flex items-start gap-2">
                      <Check size={14} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0 mt-0.5" />
                      <span className="text-[#15120F] dark:text-[#F6EFE8]">{r}</span>
                    </div>
                  ))}
                </div>
              </motion.div>
            )}
          </div>

          {/* Detailed Entity Comparison Cards */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Sole Proprietorship */}
            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs flex flex-col justify-between">
              <div>
                <div className="flex items-center justify-between gap-2 mb-2">
                  <h4 className="text-sm font-black text-[#15120F] dark:text-[#F6EFE8]">
                    Sole Proprietorship
                  </h4>
                  <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-[#FAFAFA] dark:bg-[#1A1512] text-[#6B6156] dark:text-[#AC9E92] border border-[#F3DFCD]/50 dark:border-[#383029]">
                    Registered via DTI
                  </span>
                </div>
                <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] mb-3">
                  Owned entirely by one individual. The owner and the business are treated as a single legal person.
                </p>
                
                <div className="space-y-2 text-xs text-[#5A5148] dark:text-[#C6B8AC]">
                  <div className="flex justify-between border-b border-[#F3DFCD]/40 dark:border-[#383029] pb-1">
                    <span className="font-medium">Liability:</span>
                    <span className="font-bold text-red-600 dark:text-red-400">Unlimited (personal assets at risk)</span>
                  </div>
                  <div className="flex justify-between border-b border-[#F3DFCD]/40 dark:border-[#383029] pb-1">
                    <span className="font-medium">Capital Requirement:</span>
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">No minimum statutory capital</span>
                  </div>
                  <div className="flex justify-between border-b border-[#F3DFCD]/40 dark:border-[#383029] pb-1">
                    <span className="font-medium">Taxation Model:</span>
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">Pass-through (8% flat or graduated)</span>
                  </div>
                  <div className="flex justify-between border-b border-[#F3DFCD]/40 dark:border-[#383029] pb-1">
                    <span className="font-medium">Setup Timeline:</span>
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">Fastest (1-3 business days for DTI)</span>
                  </div>
                  <div className="flex justify-between pb-1">
                    <span className="font-medium">Investor Feasibility:</span>
                    <span className="font-bold text-[#6B6156]">Cannot sell equity shares</span>
                  </div>
                </div>
              </div>
            </div>

            {/* One Person Corporation (OPC) */}
            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs flex flex-col justify-between">
              <div>
                <div className="flex items-center justify-between gap-2 mb-2">
                  <h4 className="text-sm font-black text-[#15120F] dark:text-[#F6EFE8]">
                    One Person Corporation (OPC)
                  </h4>
                  <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52]">
                    Registered via SEC
                  </span>
                </div>
                <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] mb-3">
                  A modern corporate vehicle created under RA 11232 for solo founders who want corporate limited liability without needing a board of directors.
                </p>

                <div className="space-y-2 text-xs text-[#5A5148] dark:text-[#C6B8AC]">
                  <div className="flex justify-between border-b border-[#F3DFCD]/40 dark:border-[#383029] pb-1">
                    <span className="font-medium">Liability:</span>
                    <span className="font-bold text-emerald-600 dark:text-emerald-400">Limited to corporate assets</span>
                  </div>
                  <div className="flex justify-between border-b border-[#F3DFCD]/40 dark:border-[#383029] pb-1">
                    <span className="font-medium">Mandatory Officers:</span>
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">Nominee &amp; Alternate Nominee</span>
                  </div>
                  <div className="flex justify-between border-b border-[#F3DFCD]/40 dark:border-[#383029] pb-1">
                    <span className="font-medium">Taxation Model:</span>
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">Corporate Income Tax (CIT - 20%/25%)</span>
                  </div>
                  <div className="flex justify-between border-b border-[#F3DFCD]/40 dark:border-[#383029] pb-1">
                    <span className="font-medium">Corporate Governance:</span>
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">No Board or By-Laws required</span>
                  </div>
                  <div className="flex justify-between pb-1">
                    <span className="font-medium">Investor Feasibility:</span>
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">Must convert to regular corp to add owners</span>
                  </div>
                </div>
              </div>
            </div>

            {/* Regular Stock Corporation */}
            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs flex flex-col justify-between">
              <div>
                <div className="flex items-center justify-between gap-2 mb-2">
                  <h4 className="text-sm font-black text-[#15120F] dark:text-[#F6EFE8]">
                    Regular Stock Corporation
                  </h4>
                  <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52]">
                    Registered via SEC
                  </span>
                </div>
                <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] mb-3">
                  Formed by 2 to 15 incorporators. Issues shares of capital stock and is governed by an elected Board of Directors.
                </p>

                <div className="space-y-2 text-xs text-[#5A5148] dark:text-[#C6B8AC]">
                  <div className="flex justify-between border-b border-[#F3DFCD]/40 dark:border-[#383029] pb-1">
                    <span className="font-medium">Liability:</span>
                    <span className="font-bold text-emerald-600 dark:text-emerald-400">Limited to subscribed capital</span>
                  </div>
                  <div className="flex justify-between border-b border-[#F3DFCD]/40 dark:border-[#383029] pb-1">
                    <span className="font-medium">Governance:</span>
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">Board of Directors, President, CorpSec, Treasurer</span>
                  </div>
                  <div className="flex justify-between border-b border-[#F3DFCD]/40 dark:border-[#383029] pb-1">
                    <span className="font-medium">Taxation Model:</span>
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">CIT (20% under CREATE if taxable income &lt;= ₱5M)</span>
                  </div>
                  <div className="flex justify-between border-b border-[#F3DFCD]/40 dark:border-[#383029] pb-1">
                    <span className="font-medium">Reporting:</span>
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">Annual GIS (General Information Sheet) &amp; AFS</span>
                  </div>
                  <div className="flex justify-between pb-1">
                    <span className="font-medium">Investor Feasibility:</span>
                    <span className="font-bold text-emerald-600 dark:text-emerald-400">Highest (preferred by angels &amp; VCs)</span>
                  </div>
                </div>
              </div>
            </div>

            {/* Partnership */}
            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs flex flex-col justify-between">
              <div>
                <div className="flex items-center justify-between gap-2 mb-2">
                  <h4 className="text-sm font-black text-[#15120F] dark:text-[#F6EFE8]">
                    Partnership (General &amp; Limited)
                  </h4>
                  <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-[#FAFAFA] dark:bg-[#1A1512] text-[#6B6156] dark:text-[#AC9E92] border border-[#F3DFCD]/50 dark:border-[#383029]">
                    Registered via SEC
                  </span>
                </div>
                <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] mb-3">
                  Two or more persons bind themselves to contribute money, property, or industry to a common fund, with the intention of dividing profits.
                </p>

                <div className="space-y-2 text-xs text-[#5A5148] dark:text-[#C6B8AC]">
                  <div className="flex justify-between border-b border-[#F3DFCD]/40 dark:border-[#383029] pb-1">
                    <span className="font-medium">Liability:</span>
                    <span className="font-bold text-amber-600 dark:text-amber-400">Joint &amp; several for general partners</span>
                  </div>
                  <div className="flex justify-between border-b border-[#F3DFCD]/40 dark:border-[#383029] pb-1">
                    <span className="font-medium">Formation Document:</span>
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">Articles of Partnership</span>
                  </div>
                  <div className="flex justify-between border-b border-[#F3DFCD]/40 dark:border-[#383029] pb-1">
                    <span className="font-medium">General Professional Partnership (GPP):</span>
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">Tax-exempt entity (partners taxed individually)</span>
                  </div>
                  <div className="flex justify-between border-b border-[#F3DFCD]/40 dark:border-[#383029] pb-1">
                    <span className="font-medium">Commercial Partnership:</span>
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">Taxed like a regular corporation (CIT)</span>
                  </div>
                  <div className="flex justify-between pb-1">
                    <span className="font-medium">Continuity:</span>
                    <span className="font-bold text-[#6B6156]">Dissolved upon death or withdrawal of partner</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* TAB 3: READINESS TRACKER & CHECKLIST */}
      {activeTab === 'checklist' && (
        <div className="space-y-4">
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 sm:p-5 shadow-xs">
            <div className="flex items-center justify-between gap-3 mb-2">
              <div>
                <h3 className="text-sm sm:text-base font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  Philippine Legal Readiness Tracker
                </h3>
                <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
                  Check off each completed registration stage. Your progress is saved privately on this device.
                </p>
              </div>
              <div className="text-right shrink-0">
                <span className="text-lg font-black text-[#B03C09] dark:text-[#FF9A52]">
                  {checklistProgress}%
                </span>
                <span className="text-[10px] block font-bold text-[#6B6156] dark:text-[#AC9E92]">
                  {checkedItems.length} of {CHECKLIST_ITEMS.length} items
                </span>
              </div>
            </div>

            {/* Progress Bar */}
            <div className="w-full h-2.5 bg-[#FFEEDF] dark:bg-[#383029] rounded-full overflow-hidden">
              <motion.div 
                className="h-full bg-[#B03C09] dark:bg-[#FF9A52] rounded-full"
                initial={{ width: 0 }}
                animate={{ width: `${checklistProgress}%` }}
                transition={{ duration: 0.5, ease: 'easeOut' }}
              />
            </div>
          </div>

          {/* Checklist Items */}
          <div className="space-y-2.5">
            {CHECKLIST_ITEMS.map((item) => {
              const isChecked = checkedItems.includes(item.id);
              return (
                <div
                  key={item.id}
                  onClick={() => toggleCheckItem(item.id)}
                  className={`p-3.5 rounded-2xl border transition-all cursor-pointer flex items-start gap-3 select-none ${
                    isChecked
                      ? 'bg-[#FFEEDF]/50 dark:bg-[#383029]/40 border-[#B03C09]/40 dark:border-[#FF9A52]/40'
                      : 'bg-white dark:bg-[#27201A] border-[#F3DFCD] dark:border-[#383029] hover:border-[#B03C09]/40'
                  }`}
                >
                  <div className={`w-5 h-5 rounded-lg flex items-center justify-center shrink-0 mt-0.5 transition-colors ${
                    isChecked
                      ? 'bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D]'
                      : 'border border-[#AC9E92] dark:border-[#6B6156]'
                  }`}>
                    {isChecked && <Check size={13} strokeWidth={3} />}
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex flex-wrap items-center gap-1.5 mb-0.5">
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                        {item.title}
                      </span>
                      <span className="text-[9px] font-bold px-1.5 py-0.2 rounded bg-[#FAFAFA] dark:bg-[#1A1512] text-[#6B6156] dark:text-[#AC9E92] border border-[#F3DFCD]/50 dark:border-[#383029]">
                        {item.agency}
                      </span>
                      <span className={`text-[9px] font-bold px-1.5 py-0.2 rounded ${
                        item.importance === 'Mandatory'
                          ? 'bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-400'
                          : item.importance === 'Recommended'
                          ? 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-400'
                          : 'bg-blue-100 text-blue-800 dark:bg-blue-950 dark:text-blue-400'
                      }`}>
                        {item.importance}
                      </span>
                    </div>
                    <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] leading-relaxed">
                      {item.description}
                    </p>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* TAB 4: EXPERT PITFALLS & FAQS */}
      {activeTab === 'experts' && (
        <div className="space-y-4">
          <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
              Expert Council Warnings: Common Philippine Startup Mistakes
            </h3>
            <p className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
              Real-world advice from Philippine CPAs, corporate attorneys, and business advisors to save your venture from penalties, lawsuits, and closure.
            </p>
          </div>

          <div className="space-y-3">
            {/* Warning 1 */}
            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
              <div className="flex items-center gap-2 mb-1.5">
                <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                  BIR Compliance Expert
                </span>
                <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  Trap 1: Thinking DTI Registration is Enough to Start Selling
                </span>
              </div>
              <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                Many beginner entrepreneurs register with DTI online, open an online shop, and begin trading without ever visiting the BIR. Under Section 258 of the Tax Code, conducting business without a BIR Certificate of Registration (Form 2303) and without issuing official sales invoices is a criminal tax offense carrying heavy fines (₱10,000 to ₱50,000+) and potential establishment closure under Oplan Kandado.
              </p>
            </div>

            {/* Warning 2 */}
            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
              <div className="flex items-center gap-2 mb-1.5">
                <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                  CPA &amp; Tax Accountant
                </span>
                <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  Trap 2: Forgetting to File Zero-Income (Nil) Tax Returns
                </span>
              </div>
              <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                Once registered with the BIR, you must submit all tax returns listed on your Form 2303 (quarterly income tax, percentage tax, withholding tax) even if your business generated zero income during the quarter. Filing a zero or nil return is free, but failing to file results in a compromise penalty of ₱1,000 per unfiled return, which quickly balloons into tens of thousands of pesos in hidden open cases.
              </p>
            </div>

            {/* Warning 3 */}
            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
              <div className="flex items-center gap-2 mb-1.5">
                <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                  E-Commerce Specialist
                </span>
                <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  Trap 3: The 1% Withholding Tax on Marketplace Sellers (RR 16-2023)
                </span>
              </div>
              <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                Under BIR Revenue Regulations No. 16-2023, electronic marketplace operators (Shopee, Lazada, TikTok Shop) and digital financial service providers (GCash, Maya) are mandated to withhold a 1% creditable withholding tax on one-half (0.5% effective) of gross remittances to online sellers whose annual gross remittances exceed ₱500,000. All marketplace sellers must be BIR-registered to avoid account suspension.
              </p>
            </div>

            {/* Warning 4 */}
            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
              <div className="flex items-center gap-2 mb-1.5">
                <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                  Legal &amp; IP Counsel
                </span>
                <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  Trap 4: Missing the 3-Year Declaration of Actual Use (DAU) for Trademarks
                </span>
              </div>
              <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                Filing an IPOPHL trademark application is only the first step. You must submit a formal Declaration of Actual Use (DAU) accompanied by actual proof of use in Philippine commerce (sales receipts, website screenshots, product photos) within 3 years from the filing date. Missing this deadline causes the automatic refusal or cancellation of your registered mark.
              </p>
            </div>

            {/* Warning 5 */}
            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
              <div className="flex items-center gap-2 mb-1.5">
                <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                  Mobile &amp; App Store Specialist
                </span>
                <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  Trap 5: App Store Review Rejection -- Bypassing IAP or Missing In-App Account Deletion
                </span>
              </div>
              <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                Under Apple App Store Guideline 3.1.1, all digital subscriptions and digital feature unlocks on iOS must go through StoreKit In-App Purchases; attempting to link to an external web checkout will cause an immediate rejection. Furthermore, Guideline 5.1.1(v) requires any app with account creation to include a fully functional in-app account deletion mechanism that permanently purges user data.
              </p>
            </div>

            {/* Warning 6 */}
            <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 shadow-xs">
              <div className="flex items-center gap-2 mb-1.5">
                <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                  SaaS Business &amp; Tax Strategist
                </span>
                <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  Trap 6: The Global Sales Tax Trap -- Using Raw Stripe Instead of an MoR
                </span>
              </div>
              <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                When selling a Web SaaS to customers in Europe, the UK, or the US, using raw Stripe makes your Philippine company directly liable for registering and remitting local VAT and state sales tax across dozens of jurisdictions. Using a Merchant of Record (Paddle or Lemon Squeezy) delegates all global sales tax compliance to the MoR, leaving you with one clean, zero-rated B2B invoice per month.
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
