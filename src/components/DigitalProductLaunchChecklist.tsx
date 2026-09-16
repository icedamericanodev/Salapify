import React, { useState, useEffect } from 'react';
import { 
  CheckSquare, Check, Sparkles, AlertTriangle, 
  CreditCard, ShieldCheck, Scale, ChevronDown, 
  ChevronUp, RotateCcw, ExternalLink, Info, 
  HelpCircle, Smartphone, Lock, FileText, ArrowRight
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';

export interface LaunchChecklistItem {
  id: string;
  pillar: 'model' | 'gateway' | 'privacy';
  title: string;
  summary: string;
  priority: 'Critical' | 'High' | 'Recommended';
  agencyOrRule: string;
  details: {
    overview: string;
    actionSteps: string[];
    proTip: string;
    reference: string;
  };
}

const LAUNCH_CHECKLIST_ITEMS: LaunchChecklistItem[] = [
  // PILLAR 1: BUSINESS MODEL ARCHITECTURE (Subscription vs. One-Time)
  {
    id: 'chk_model_selection',
    pillar: 'model',
    title: 'Select Core Monetization Engine: Subscription vs. One-Time vs. Hybrid',
    summary: 'Align your pricing model with your ongoing infrastructure costs, product update frequency, and customer lifetime value.',
    priority: 'Critical',
    agencyOrRule: 'Business Strategy & Unit Economics',
    details: {
      overview: 'Choosing between recurring subscriptions and one-time payments is the foundational financial decision of your digital product. Subscriptions fund continuous cloud server and AI API costs, while one-time payments lower barrier to entry.',
      actionSteps: [
        'Audit your variable recurring costs (Vercel hosting, Supabase/Firebase database, OpenAI/Gemini tokens, email delivery). If monthly variable costs per user exceed $0.50, recurring subscriptions are necessary to prevent negative margins.',
        'If launching an offline utility tool, desktop app, or digital template with zero ongoing cloud costs, consider a one-time perpetual license or lifetime deal (LTD) to drive rapid early adoption.',
        'Consider a Hybrid Model: Offer a free tier or one-time base license, and monetize premium cloud sync, AI generation, or team collaboration via monthly add-on subscriptions.'
      ],
      proTip: 'In the Philippine market, credit card penetration is under 10%. If charging subscriptions, ensure your processor supports recurring e-wallet debits (via Maya or direct billing) or offer 3-month and 6-month prepaid passes via GCash.',
      reference: 'Philippine SaaS Benchmarks & Unit Economics'
    }
  },
  {
    id: 'chk_value_metric',
    pillar: 'model',
    title: 'Formulate Pricing Tiers & Usage Value Metric',
    summary: 'Define transparent pricing tiers linked to measurable customer value rather than arbitrary feature gates.',
    priority: 'High',
    agencyOrRule: 'Pricing Strategy',
    details: {
      overview: 'A strong pricing tier aligns with how your customers measure success (e.g., invoices generated, active team members, storage gigabytes, or AI prompts run per month).',
      actionSteps: [
        'Establish a Free Tier or 14-day trial with no credit card required to overcome initial adoption friction.',
        'Create 2 to 3 distinct tiers: Starter (Solo indie/freelancer), Pro (Power user/small team), and Business/Custom.',
        'Keep the pricing table simple with maximum 5 key comparison rows so users can decide in under 30 seconds.'
      ],
      proTip: 'Anchor your pricing: Display your Pro tier as "Most Popular" positioned in the center with subtle highlight styling to guide user decision-making.',
      reference: 'SaaS Pricing Psychology & Consumer Behavior'
    }
  },
  {
    id: 'chk_billing_cadence',
    pillar: 'model',
    title: 'Configure Monthly & Annual Billing with Upfront Discount',
    summary: 'Offer an annual billing discount to collect upfront working capital and reduce subscriber churn.',
    priority: 'High',
    agencyOrRule: 'Cash Flow Management',
    details: {
      overview: 'Annual subscriptions provide immediate non-dilutive working capital and lock in customers for a full 12 months, shielding your startup from month-to-month cancellation spikes.',
      actionSteps: [
        'Set the annual subscription price at 15% to 20% below the monthly rate (equivalent to "2 Months Free").',
        'Add a visible toggle on your paywall (Monthly vs. Annual) and default to the Annual plan with a clear "Save 20%" badge.',
        'Set up automated email notifications 14 days and 3 days before annual renewal charges occur.'
      ],
      proTip: 'Annual contracts reduce payment processing transaction fees by eliminating 11 recurring monthly payment gateway fixed fees.',
      reference: 'Financial Engineering for Bootstrapped Startups'
    }
  },
  {
    id: 'chk_appstore_312',
    pillar: 'model',
    title: 'App Store Guideline 3.1.2 Auto-Renewing Subscription Disclosures',
    summary: 'Comply with strict Apple and Google paywall terms to prevent instant app review rejection.',
    priority: 'Critical',
    agencyOrRule: 'Apple Guideline 3.1.2 & Google Play Policy',
    details: {
      overview: 'Apple and Google strictly enforce transparent subscription terms. Paywalls that disguise subscription renewals or hide cancellation terms are rejected immediately.',
      actionSteps: [
        'Display the exact price per period and unit price (e.g. "₱299/month or ₱2,490/year") in clear display typography.',
        'State clearly: "Payment will be charged to your Apple ID / Google Play account at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period."',
        'Include direct, clickable text links to your Terms of Use (EULA) and Privacy Policy on the paywall screen.',
        'Provide a functional "Restore Purchases" button on the paywall and in app settings for returning users.'
      ],
      proTip: 'Apple provides a Standard End User License Agreement (EULA). If you do not have custom legal counsel, you can reference Apple\'s Standard EULA link (apple.com/legal/internet-services/itunes/dev/stdeula/) alongside your custom Privacy Policy.',
      reference: 'Apple App Store Review Guidelines Section 3.1.2'
    }
  },
  {
    id: 'chk_churn_dunning',
    pillar: 'model',
    title: 'Implement Failed Payment Recovery (Dunning Management)',
    summary: 'Automate retries and customer recovery emails when recurring credit card or e-wallet charges fail.',
    priority: 'Recommended',
    agencyOrRule: 'Revenue Operations',
    details: {
      overview: 'Up to 30% of subscription cancellations are involuntary churn caused by expired cards, temporary credit limits, or banking fraud false positives.',
      actionSteps: [
        'Configure your billing system (Paddle, Stripe, or PayMongo) to perform smart retries over 7 to 14 days (e.g. retry on day 1, day 3, day 5, and day 7).',
        'Send an automated, polite email prompting the user to update their payment method before their account drops to the free tier.',
        'Implement an in-app banner for logged-in users with past-due subscriptions with a one-click payment update modal.'
      ],
      proTip: 'Philippine debit cards frequently fail recurring billing due to strict local bank OTP prompts. Sending an in-app notification asking users to approve recurring payments in their banking app rescues over 40% of failed local transactions.',
      reference: 'SaaS Involuntary Churn & Payment Resiliency'
    }
  },

  // PILLAR 2: PHILIPPINE PAYMENT GATEWAY INTEGRATION
  {
    id: 'chk_ph_gateway_selection',
    pillar: 'gateway',
    title: 'Select & Register with BSP-Compliant Philippine Payment Gateway',
    summary: 'Partner with an authorized Bangko Sentral ng Pilipinas Operator of Payment System (OPS) for domestic checkouts.',
    priority: 'Critical',
    agencyOrRule: 'BSP Circular No. 1049 & OPS Regulations',
    details: {
      overview: 'To accept Philippine e-wallets and local debit cards legally, you must integrate a BSP-registered payment gateway like PayMongo, Xendit Philippines, or Maya Checkout.',
      actionSteps: [
        'Prepare your business documentation: DTI Registration (Sole Prop) or SEC Certificate (OPC/Corporation), BIR Form 2303 Certificate of Registration, and founder government IDs.',
        'Sign up for a merchant account on PayMongo (paymongo.com) or Xendit (xendit.com).',
        'Submit your business website or app URL with visible Terms of Service, Privacy Policy, and Customer Support email.',
        'Complete identity verification and sign the merchant agreement to unlock live API keys.'
      ],
      proTip: 'PayMongo is favored by indie developers for its modern REST API and native Next.js/React SDKs. Xendit is favored for high-volume automated payouts and recurring direct debit.',
      reference: 'Bangko Sentral ng Pilipinas Registered Operators of Payment Systems'
    }
  },
  {
    id: 'chk_ewallet_integration',
    pillar: 'gateway',
    title: 'Integrate Philippine E-Wallets (GCash, Maya, GrabPay)',
    summary: 'Enable one-click digital wallet checkouts where the vast majority of Filipino digital consumers transact.',
    priority: 'Critical',
    agencyOrRule: 'Philippine Retail Payments System (NRPS)',
    details: {
      overview: 'Over 70% of digital transactions in the Philippines occur via GCash and Maya. An app or digital store that only accepts credit cards eliminates over 85% of potential local customers.',
      actionSteps: [
        'Enable GCash and Maya payment sources in your PayMongo or Xendit dashboard.',
        'Implement mobile-responsive redirect flow: When on desktop, display a high-contrast QR code (QR Ph compliant) for scanning; when on mobile, trigger a direct deep link to the GCash or Maya app.',
        'Ensure the return URL properly handles redirect states (success, cancelled, failed) without double-charging.'
      ],
      proTip: 'For mobile web checkouts, always preserve session tokens in localStorage or query params during external e-wallet app redirects so the user lands back in their authenticated dashboard.',
      reference: 'QR Ph National QR Code Standard & E-Wallet Integration'
    }
  },
  {
    id: 'chk_card_crossborder',
    pillar: 'gateway',
    title: 'Configure Local 3D Secure Card Processing (BPI, BDO, UnionBank)',
    summary: 'Support Visa, Mastercard, and JCB cards with mandatory 3D Secure OTP verification to eliminate fraud chargeback liability.',
    priority: 'High',
    agencyOrRule: 'Card Brand Security Rules (EMV 3DS)',
    details: {
      overview: '3D Secure prompts customers to enter a One-Time PIN (OTP) sent by their issuing bank. Once verified via 3DS, chargeback liability shifts from you (the merchant) to the card issuer.',
      actionSteps: [
        'Enable 3D Secure 2.0 (3DS) in your gateway settings for all debit and credit card transactions.',
        'Test cards from major Philippine banks (BPI, BDO, UnionBank, Metrobank) in staging sandbox.',
        'Display trusted security badges (SSL 256-bit encryption, Visa Secure, Mastercard Identity Check) on your checkout screen to build consumer trust.'
      ],
      proTip: 'Many Philippine debit cards require the cardholder to enable "International/Online Transactions" inside their mobile banking app. Add a brief helper tip on checkout: "Card declined? Please ensure online purchases are enabled in your bank app."',
      reference: 'EMVCo 3-D Secure Protocol Specification'
    }
  },
  {
    id: 'chk_webhook_resiliency',
    pillar: 'gateway',
    title: 'Build Secure Asynchronous Webhooks & Idempotency Handlers',
    summary: 'Safeguard your backend against duplicate subscription provisioning or missed payment notifications.',
    priority: 'Critical',
    agencyOrRule: 'System Architecture & PCI-DSS Best Practices',
    details: {
      overview: 'E-wallet and bank transfers are asynchronous. Relying solely on client-side redirect pages is dangerous because users may close their browser before the page loads. Webhooks guarantee fulfillment.',
      actionSteps: [
        'Create a dedicated server-side webhook endpoint (e.g. `/api/webhooks/payment`).',
        'Verify HMAC webhook signatures using the shared webhook secret provided by your gateway (e.g. PayMongo webhook signature header) before executing any business logic.',
        'Implement Idempotency: Record processed payment IDs in your database. If the gateway resends the same webhook event, return a 200 OK immediately without double-granting access or credits.',
        'Respond with HTTP 200 within 5 seconds to avoid gateway retry timeouts.'
      ],
      proTip: 'Store raw webhook payloads in an audit log table for 30 days. This makes debugging customer payment support tickets trivial.',
      reference: 'REST API Webhook Security & Idempotency Patterns'
    }
  },
  {
    id: 'chk_payout_settlement',
    pillar: 'gateway',
    title: 'Connect Verified Corporate Bank Account for Automated Settlement',
    summary: 'Configure settlement schedules to automatically sweep processed funds into your Philippine business account.',
    priority: 'High',
    agencyOrRule: 'Anti-Money Laundering Council (AMLC) & Tax Compliance',
    details: {
      overview: 'Payment gateways hold funds in escrow until scheduled payout batches. Settlement accounts must strictly match your legal entity registration.',
      actionSteps: [
        'Link a verified corporate bank account (UnionBank, BPI, or BDO) in your payment gateway dashboard.',
        'Confirm payout cadence: PayMongo settles T+3 to T+7 business days, while Xendit offers next-day settlement options.',
        'Review gateway payout fees (typically ₱0 to ₱50 per batch bank transfer). Schedule weekly batches to minimize transfer overhead.'
      ],
      proTip: 'UnionBank of the Philippines provides the fastest integration with local fintech gateways, often settling batch payouts within hours of release.',
      reference: 'Philippine Clearing House Corporation (PCHC) & Pesonet Rules'
    }
  },
  {
    id: 'chk_mor_international',
    pillar: 'gateway',
    title: 'Deploy Merchant of Record (MoR) for Global Customer Transactions',
    summary: 'Route international buyers through Paddle or Lemon Squeezy to automate foreign VAT and US state sales taxes.',
    priority: 'High',
    agencyOrRule: 'Cross-Border VAT & Sales Tax Regulations',
    details: {
      overview: 'If you sell to users in the EU, UK, or United States, local gateways like PayMongo cannot collect or remit European VAT or US state taxes. You become personally exposed to international tax audits.',
      actionSteps: [
        'Implement IP-based or currency-based checkout routing: If visitor currency is PHP, route to PayMongo/Maya; if USD/EUR/GBP, route to Lemon Squeezy or Paddle.',
        'Ensure your Terms of Service clarify that international purchases are fulfilled by the Merchant of Record as reseller.',
        'Receive consolidated monthly B2B payouts from the MoR and issue zero-rated BIR sales invoices under Section 108(B)(2).'
      ],
      proTip: 'Lemon Squeezy and Paddle support Apple Pay and Google Pay natively on web checkout, resulting in over 60% conversion rates for international desktop and mobile buyers.',
      reference: 'International E-Commerce Taxation & MoR Architecture'
    }
  },

  // PILLAR 3: USER DATA PROTECTION & PRIVACY PROTOCOLS
  {
    id: 'chk_npc_compliance',
    pillar: 'privacy',
    title: 'National Privacy Commission (NPC) Compliance & DPO Designation',
    summary: 'Comply with Republic Act No. 10173 (Data Privacy Act of 2012) and register with the NPC.',
    priority: 'Critical',
    agencyOrRule: 'RA 10173 & NPC Circular 2022-04',
    details: {
      overview: 'Any digital product operating in the Philippines or processing Filipino personal data must adhere to RA 10173. Non-compliance carries severe criminal penalties and operational injunctions.',
      actionSteps: [
        'Designate a Data Protection Officer (DPO). For solo founders and startups, the founder or lead technical architect can serve as the initial DPO.',
        'Register with the NPC online portal (npcregistration.privacy.gov.ph) if processing sensitive personal information of 1,000+ individuals or employing 250+ employees.',
        'Draft an internal Privacy Management Program (PMP) detailing data classification, storage, access control, and disposal procedures.'
      ],
      proTip: 'Keep a formal Data Sharing Agreement (DSA) on file with any third-party contractors or agencies who have database or server access.',
      reference: 'National Privacy Commission Guidelines on Registration & DPO Accountability'
    }
  },
  {
    id: 'chk_privacy_policy',
    pillar: 'privacy',
    title: 'Publish Accessible Privacy Notice with Complete Sub-Processor Disclosure',
    summary: 'Host a dedicated, public Privacy Notice URL that requires no authentication to read.',
    priority: 'Critical',
    agencyOrRule: 'RA 10173 Section 16 & App Store Guideline 5.1.1',
    details: {
      overview: 'Apple, Google, and the NPC mandate a transparent Privacy Notice detailing what data is collected, how it is processed, and who it is shared with.',
      actionSteps: [
        'Create a public web page at `https://yourdomain.com/privacy` that is permanently accessible without login.',
        'Itemize personal data collected: Names, email addresses, phone numbers, IP addresses, device identifiers, and payment reference tokens.',
        'Disclose all third-party sub-processors: e.g., Cloud Hosting (AWS/Vercel), Database (Supabase/Firebase), Payment Processor (PayMongo/Paddle), Analytics (Mixpanel/PostHog).',
        'State your Data Retention Policy: How long records are retained after account cancellation (e.g. 12 months for tax and audit compliance, then purged).'
      ],
      proTip: 'Do not use generic US templates that reference HIPAA or California CCPA without also citing the Philippine Data Privacy Act of 2012 (RA 10173) and NPC contact channels.',
      reference: 'NPC Advisory No. 2021-01 on Privacy Notices'
    }
  },
  {
    id: 'chk_cookie_consent',
    pillar: 'privacy',
    title: 'Deploy Cookie & Tracking Consent Banner with Explicit Opt-In',
    summary: 'Inform visitors of tracking cookies and third-party telemetry before loading marketing pixels.',
    priority: 'Recommended',
    agencyOrRule: 'NPC Guidelines on Tracking Technologies & GDPR',
    details: {
      overview: 'Loading tracking scripts (Meta Pixel, Google Analytics, Hotjar) before obtaining user consent violates international privacy standards and NPC fair processing principles.',
      actionSteps: [
        'Deploy a lightweight cookie consent banner that clearly distinguishes Essential Cookies (auth, session) from Analytics and Marketing Cookies.',
        'Block third-party tracking scripts until the user clicks "Accept All" or customizes their consent preferences.',
        'Provide an accessible link in the website footer allowing users to change their cookie preferences at any time.'
      ],
      proTip: 'Zero-cookie analytics tools like Plausible or Cloudflare Web Analytics require no consent banner because they do not collect personal identifiers or track across websites.',
      reference: 'Web Privacy & Tracking Technologies Compliance'
    }
  },
  {
    id: 'chk_data_encryption',
    pillar: 'privacy',
    title: 'Enforce End-to-End Transport & At-Rest Database Encryption',
    summary: 'Implement TLS 1.3, encrypted database volumes, and salted cryptographic password hashing.',
    priority: 'Critical',
    agencyOrRule: 'NPC Circular 16-01 (Security of Personal Data)',
    details: {
      overview: 'The NPC mandates appropriate technical and organizational security measures to protect personal data from accidental loss, unauthorized alteration, or breach.',
      actionSteps: [
        'Enforce HTTPS across all domains using TLS 1.3 and configure HTTP Strict Transport Security (HSTS) headers.',
        'Enable At-Rest Storage Encryption (AES-256) on your database instances, object storage buckets (S3/GCS), and automated database backups.',
        'Never store plaintext passwords: Use proven salted cryptographic algorithms such as bcrypt, Argon2, or PBKDF2 with high work factors.',
        'Store all API secrets, private keys, and payment credentials exclusively in environment variables, never hardcoded in source code repository commits.'
      ],
      proTip: 'Run automated secret scanner tools in your CI/CD pipeline (e.g. GitHub secret scanning) to catch accidentally committed tokens before deployment.',
      reference: 'National Privacy Commission Technical Security Standards'
    }
  },
  {
    id: 'chk_in_app_deletion',
    pillar: 'privacy',
    title: 'Implement Mandatory In-App Account & User Data Purge Mechanism',
    summary: 'Fulfill Apple Guideline 5.1.1(v) and NPC data subject rights with a functional self-service deletion button.',
    priority: 'Critical',
    agencyOrRule: 'Apple Guideline 5.1.1(v) & RA 10173 Section 16(e)',
    details: {
      overview: 'If users can create an account inside your app, they MUST be able to delete it inside the app. Apps that only offer "Email support to delete" get rejected by Apple.',
      actionSteps: [
        'Add a clear "Delete Account" button inside user Settings or Profile.',
        'Trigger a confirmation modal warning that deletion is permanent and cannot be undone.',
        'Build a backend cascade function that permanently deletes or anonymizes user records, profile photos, uploaded documents, and authentication credentials.',
        'If legal or tax retention requires keeping transaction logs for 5 years (BIR rules), anonymize all personal identifiers so the record cannot be linked back to the individual.'
      ],
      proTip: 'Apple allows a 24-hour grace period if immediate deletion is technically complex, but the initiation must occur entirely inside the app UI without forcing users to a web browser.',
      reference: 'App Store Review Guidelines 5.1.1(v) Account Deletion'
    }
  },
  {
    id: 'chk_breach_response',
    pillar: 'privacy',
    title: 'Establish 72-Hour Security Incident & Breach Response Protocol',
    summary: 'Formulate an actionable incident protocol to notify the NPC and data subjects within the statutory 72-hour window.',
    priority: 'Critical',
    agencyOrRule: 'NPC Circular 16-03 (Personal Data Breach Management)',
    details: {
      overview: 'In the event of a security breach involving sensitive personal information, Section 20(f) of RA 10173 requires notifying both the NPC and affected individuals within 72 hours.',
      actionSteps: [
        'Establish an internal Security Incident Response Team (SIRT) consisting of the DPO, lead engineer, and legal counsel.',
        'Draft an incident runbook: (1) Contain the breach and isolate affected servers; (2) Assess the scope of compromised data; (3) File preliminary notification with the NPC via complaints@privacy.gov.ph within 72 hours; (4) Notify affected users with clear steps to protect their accounts.',
        'Maintain an internal Security Incident Log documenting all investigated vulnerabilities and mitigation actions for at least 5 years.'
      ],
      proTip: 'Failing to report a major breach within 72 hours carries separate administrative and criminal liability under Section 30 of the Data Privacy Act.',
      reference: 'NPC Circular No. 16-03 Guidelines on Data Breach Management'
    }
  }
];

export const DigitalProductLaunchChecklist: React.FC = () => {
  const [checkedIds, setCheckedIds] = useState<string[]>([]);
  const [pillarFilter, setPillarFilter] = useState<'all' | 'model' | 'gateway' | 'privacy'>('all');
  const [expandedItemId, setExpandedItemId] = useState<string | null>(null);

  // Model Decider Mini-Tool state
  const [showModelDecider, setShowModelDecider] = useState<boolean>(false);
  const [deciderAnswers, setDeciderAnswers] = useState<{
    costs: string;
    updates: string;
    market: string;
  }>({
    costs: '',
    updates: '',
    market: '',
  });

  // Load from localStorage
  useEffect(() => {
    try {
      const saved = localStorage.getItem('salapify_saas_launch_checklist');
      if (saved) {
        setCheckedIds(JSON.parse(saved));
      }
    } catch {
      // ignore
    }
  }, []);

  const toggleItem = (id: string) => {
    let next: string[];
    if (checkedIds.includes(id)) {
      next = checkedIds.filter(i => i !== id);
    } else {
      next = [...checkedIds, id];
    }
    setCheckedIds(next);
    localStorage.setItem('salapify_saas_launch_checklist', JSON.stringify(next));
  };

  const selectAllInPillar = (pillar: 'all' | 'model' | 'gateway' | 'privacy') => {
    const targetItems = pillar === 'all' 
      ? LAUNCH_CHECKLIST_ITEMS 
      : LAUNCH_CHECKLIST_ITEMS.filter(item => item.pillar === pillar);
    const targetIds = targetItems.map(item => item.id);
    const next = Array.from(new Set([...checkedIds, ...targetIds]));
    setCheckedIds(next);
    localStorage.setItem('salapify_saas_launch_checklist', JSON.stringify(next));
  };

  const resetPillar = (pillar: 'all' | 'model' | 'gateway' | 'privacy') => {
    if (pillar === 'all') {
      setCheckedIds([]);
      localStorage.removeItem('salapify_saas_launch_checklist');
    } else {
      const remaining = checkedIds.filter(id => {
        const item = LAUNCH_CHECKLIST_ITEMS.find(i => i.id === id);
        return item && item.pillar !== pillar;
      });
      setCheckedIds(remaining);
      localStorage.setItem('salapify_saas_launch_checklist', JSON.stringify(remaining));
    }
  };

  const filteredItems = pillarFilter === 'all' 
    ? LAUNCH_CHECKLIST_ITEMS 
    : LAUNCH_CHECKLIST_ITEMS.filter(item => item.pillar === pillarFilter);

  const totalCount = LAUNCH_CHECKLIST_ITEMS.length;
  const completedCount = checkedIds.length;
  const progressPercent = Math.round((completedCount / totalCount) * 100);

  // Model Decider Recommendation logic
  const getModelRecommendation = () => {
    if (!deciderAnswers.costs || !deciderAnswers.updates || !deciderAnswers.market) return null;
    
    if (deciderAnswers.costs === 'high_recurring') {
      return {
        type: 'Recurring Monthly/Annual Subscription',
        rationale: 'Because your digital product incurs recurring server, database, or LLM token costs, a subscription model is mandatory to maintain healthy unit economics and prevent bankrupting cash flow.',
        phAdvice: 'To maximize conversions in the Philippines where credit card penetration is low, support recurring e-wallets or offer prepaid 3-month/6-month access passes via GCash and Maya.'
      };
    } else if (deciderAnswers.costs === 'zero_recurring' && deciderAnswers.updates === 'occasional') {
      return {
        type: 'One-Time Payment / Perpetual License',
        rationale: 'Because your software operates client-side or has negligible ongoing variable costs, a one-time purchase eliminates subscriber fatigue and drastically lowers customer acquisition resistance.',
        phAdvice: 'Price in local Philippine Pesos (e.g. ₱999 to ₱2,490) and allow direct checkout with GCash Scan-to-Pay for frictionless impulse buying.'
      };
    } else {
      return {
        type: 'Hybrid Freemium + Cloud Add-On',
        rationale: 'Provide a permanent free tier or one-time base license for local offline functionality, while charging a recurring subscription for cloud sync, team collaboration, or AI-powered premium workflows.',
        phAdvice: 'This gives you the broad distribution viral loop of a free app while monetizing serious business power users.'
      };
    }
  };

  const modelRec = getModelRecommendation();

  return (
    <div className="space-y-4">
      {/* Top Banner & Progress Meter */}
      <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 sm:p-5 shadow-xs">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-3">
          <div className="flex items-center gap-2.5">
            <div className="w-10 h-10 rounded-xl bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center shrink-0">
              <CheckSquare size={20} />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                  Interactive Verification Protocol
                </span>
                <span className="text-[9px] font-bold px-1.5 py-0.2 rounded bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-400">
                  {completedCount}/{totalCount} Completed
                </span>
              </div>
              <h3 className="text-base sm:text-lg font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Launching a Digital Product Checklist
              </h3>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => setShowModelDecider(!showModelDecider)}
              className="px-3 py-2 rounded-xl text-xs font-bold border border-[#B03C09]/40 text-[#B03C09] dark:border-[#FF9A52]/40 dark:text-[#FF9A52] hover:bg-[#FFEEDF]/50 dark:hover:bg-[#383029] transition-colors flex items-center gap-1.5 min-h-[44px]"
            >
              <Sparkles size={14} />
              <span>Model Decision Quiz</span>
            </button>
          </div>
        </div>

        <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] leading-relaxed mb-4">
          A rigorous pre-launch verification checklist across three critical pillars: choosing your business monetization model, integrating Philippine-compatible payment processors, and hardening user data protection under the Data Privacy Act (RA 10173) and App Store review policies.
        </p>

        {/* Progress Bar */}
        <div>
          <div className="flex items-center justify-between text-xs font-bold mb-1.5">
            <span className="text-[#15120F] dark:text-[#F6EFE8]">
              Overall Launch Readiness
            </span>
            <span className="font-mono text-[#B03C09] dark:text-[#FF9A52]">
              {progressPercent}% Complete
            </span>
          </div>
          <div className="w-full h-2.5 bg-[#F3DFCD]/50 dark:bg-[#383029] rounded-full overflow-hidden">
            <motion.div 
              className="h-full bg-[#B03C09] dark:bg-[#FF9A52] rounded-full"
              initial={{ width: 0 }}
              animate={{ width: `${progressPercent}%` }}
              transition={{ duration: 0.4 }}
            />
          </div>
        </div>

        {/* Category Filter Pills */}
        <div className="mt-4 pt-3 border-t border-[#F3DFCD]/70 dark:border-[#383029] flex items-center justify-between gap-2 flex-wrap">
          <div className="flex items-center gap-1.5 overflow-x-auto no-scrollbar py-0.5">
            {[
              { id: 'all', label: 'All Items', count: totalCount },
              { id: 'model', label: '1. Business Model', count: LAUNCH_CHECKLIST_ITEMS.filter(i => i.pillar === 'model').length },
              { id: 'gateway', label: '2. PH Gateways', count: LAUNCH_CHECKLIST_ITEMS.filter(i => i.pillar === 'gateway').length },
              { id: 'privacy', label: '3. Data Protection', count: LAUNCH_CHECKLIST_ITEMS.filter(i => i.pillar === 'privacy').length },
            ].map(tab => {
              const isSelected = pillarFilter === tab.id;
              return (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => setPillarFilter(tab.id as any)}
                  className={`px-2.5 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 whitespace-nowrap min-h-[44px] shrink-0 ${
                    isSelected
                      ? 'bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] shadow-xs'
                      : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] hover:bg-[#FAFAFA] dark:hover:bg-[#1E1915]'
                  }`}
                >
                  <span>{tab.label}</span>
                  <span className={`text-[10px] px-1.5 py-0.2 rounded-full ${
                    isSelected ? 'bg-white/20 text-white dark:text-[#14100D]' : 'bg-[#FFEEDF] text-[#B03C09] dark:bg-[#383029] dark:text-[#FF9A52]'
                  }`}>
                    {tab.count}
                  </span>
                </button>
              );
            })}
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => selectAllInPillar(pillarFilter)}
              className="text-[11px] font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline px-2 py-1 min-h-[44px] flex items-center"
            >
              Mark View Done
            </button>
            <span className="text-[#6B6156]">|</span>
            <button
              type="button"
              onClick={() => resetPillar(pillarFilter)}
              className="text-[11px] font-bold text-[#6B6156] dark:text-[#AC9E92] hover:text-red-600 dark:hover:text-red-400 px-2 py-1 min-h-[44px] flex items-center gap-1"
            >
              <RotateCcw size={12} />
              <span>Reset</span>
            </button>
          </div>
        </div>
      </div>

      {/* MODEL DECIDER INTERACTIVE TOOL MODAL / PANEL */}
      <AnimatePresence>
        {showModelDecider && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            className="bg-white dark:bg-[#27201A] border-2 border-[#B03C09]/40 dark:border-[#FF9A52]/40 rounded-2xl p-4 sm:p-5 shadow-xs overflow-hidden"
          >
            <div className="flex items-center justify-between gap-2 mb-3">
              <div className="flex items-center gap-2">
                <Sparkles size={18} className="text-[#B03C09] dark:text-[#FF9A52]" />
                <h4 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  Interactive Monetization Decider: Subscription vs. One-Time?
                </h4>
              </div>
              <button
                type="button"
                onClick={() => setShowModelDecider(false)}
                className="text-xs font-bold text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] px-2 py-1"
              >
                Close
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-3 mb-4">
              {/* Question 1 */}
              <div>
                <label className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1.5">
                  1. Ongoing Cloud &amp; Server Costs
                </label>
                <div className="space-y-1.5">
                  {[
                    { id: 'high_recurring', label: 'High (Cloud DB, AI tokens, real-time sync)' },
                    { id: 'zero_recurring', label: 'Zero / Minimal (Client-side app, local files)' }
                  ].map(opt => (
                    <button
                      key={opt.id}
                      type="button"
                      onClick={() => setDeciderAnswers(prev => ({ ...prev, costs: opt.id }))}
                      className={`w-full text-left p-2.5 rounded-xl text-xs font-medium border transition-colors min-h-[44px] ${
                        deciderAnswers.costs === opt.id
                          ? 'bg-[#FFEEDF] border-[#B03C09] text-[#B03C09] dark:bg-[#383029] dark:border-[#FF9A52] dark:text-[#FF9A52]'
                          : 'bg-[#FAFAFA] dark:bg-[#1A1512] border-[#F3DFCD] dark:border-[#383029] text-[#5A5148] dark:text-[#C6B8AC]'
                      }`}
                    >
                      {opt.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Question 2 */}
              <div>
                <label className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1.5">
                  2. Feature Roadmap &amp; Updates
                </label>
                <div className="space-y-1.5">
                  {[
                    { id: 'continuous', label: 'Continuous new tools, weekly releases, active roadmap' },
                    { id: 'occasional', label: 'Stable utility with occasional bug fixes' }
                  ].map(opt => (
                    <button
                      key={opt.id}
                      type="button"
                      onClick={() => setDeciderAnswers(prev => ({ ...prev, updates: opt.id }))}
                      className={`w-full text-left p-2.5 rounded-xl text-xs font-medium border transition-colors min-h-[44px] ${
                        deciderAnswers.updates === opt.id
                          ? 'bg-[#FFEEDF] border-[#B03C09] text-[#B03C09] dark:bg-[#383029] dark:border-[#FF9A52] dark:text-[#FF9A52]'
                          : 'bg-[#FAFAFA] dark:bg-[#1A1512] border-[#F3DFCD] dark:border-[#383029] text-[#5A5148] dark:text-[#C6B8AC]'
                      }`}
                    >
                      {opt.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Question 3 */}
              <div>
                <label className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block mb-1.5">
                  3. Primary Target Audience
                </label>
                <div className="space-y-1.5">
                  {[
                    { id: 'b2b_teams', label: 'Businesses, clinics, SMEs, or corporate teams' },
                    { id: 'consumers', label: 'Individual retail consumers, students, hobbyists' }
                  ].map(opt => (
                    <button
                      key={opt.id}
                      type="button"
                      onClick={() => setDeciderAnswers(prev => ({ ...prev, market: opt.id }))}
                      className={`w-full text-left p-2.5 rounded-xl text-xs font-medium border transition-colors min-h-[44px] ${
                        deciderAnswers.market === opt.id
                          ? 'bg-[#FFEEDF] border-[#B03C09] text-[#B03C09] dark:bg-[#383029] dark:border-[#FF9A52] dark:text-[#FF9A52]'
                          : 'bg-[#FAFAFA] dark:bg-[#1A1512] border-[#F3DFCD] dark:border-[#383029] text-[#5A5148] dark:text-[#C6B8AC]'
                      }`}
                    >
                      {opt.label}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            {/* Recommendation Result */}
            {modelRec ? (
              <div className="p-3.5 rounded-xl bg-[#FFF8F3] dark:bg-[#2A211B] border border-[#F3DFCD] dark:border-[#5A5148] flex items-start gap-3">
                <Sparkles size={18} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0 mt-0.5" />
                <div className="text-xs space-y-1">
                  <div className="flex items-center gap-2">
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
                      Recommended Strategy:
                    </span>
                    <span className="font-bold text-[#B03C09] dark:text-[#FF9A52] bg-[#FFEEDF] dark:bg-[#383029] px-2 py-0.5 rounded">
                      {modelRec.type}
                    </span>
                  </div>
                  <p className="text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                    {modelRec.rationale}
                  </p>
                  <p className="text-[#B03C09] dark:text-[#FF9A52] font-semibold text-[11px] pt-1">
                    *PH Market Insight: {modelRec.phAdvice}
                  </p>
                </div>
              </div>
            ) : (
              <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] italic text-center">
                Select your parameters above to reveal your tailored monetization model.
              </p>
            )}
          </motion.div>
        )}
      </AnimatePresence>

      {/* CHECKLIST ITEMS LIST */}
      <div className="space-y-2.5">
        {filteredItems.map(item => {
          const isChecked = checkedIds.includes(item.id);
          const isExpanded = expandedItemId === item.id;

          // Priority badge style
          const priorityBadge = item.priority === 'Critical'
            ? 'bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-400'
            : item.priority === 'High'
            ? 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-400'
            : 'bg-blue-100 text-blue-800 dark:bg-blue-950 dark:text-blue-400';

          // Pillar Icon
          const PillarIcon = item.pillar === 'model' 
            ? Scale 
            : item.pillar === 'gateway' 
            ? CreditCard 
            : ShieldCheck;

          return (
            <div
              key={item.id}
              className={`bg-white dark:bg-[#27201A] border rounded-2xl transition-all shadow-xs overflow-hidden ${
                isChecked
                  ? 'border-emerald-500/40 bg-emerald-500/5 dark:bg-emerald-950/10'
                  : 'border-[#F3DFCD] dark:border-[#383029] hover:border-[#B03C09]/40'
              }`}
            >
              {/* Card Header & Checkbox Row */}
              <div className="p-3.5 sm:p-4 flex items-start gap-3">
                <button
                  type="button"
                  onClick={() => toggleItem(item.id)}
                  aria-label={`Toggle ${item.title}`}
                  className={`w-6 h-6 rounded-lg border flex items-center justify-center shrink-0 mt-0.5 transition-all min-h-[44px] min-w-[44px] ${
                    isChecked
                      ? 'bg-emerald-600 border-emerald-600 text-white'
                      : 'border-[#C6B8AC] dark:border-[#5A5148] hover:border-[#B03C09] bg-white dark:bg-[#1E1915]'
                  }`}
                >
                  {isChecked && <Check size={16} className="stroke-[2.5]" />}
                </button>

                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap mb-1">
                    <span className={`text-[9px] font-bold px-1.5 py-0.2 rounded ${priorityBadge}`}>
                      {item.priority}
                    </span>
                    <span className="text-[10px] font-semibold text-[#6B6156] dark:text-[#AC9E92] flex items-center gap-1">
                      <PillarIcon size={12} /> {item.agencyOrRule}
                    </span>
                  </div>

                  <h4 
                    onClick={() => setExpandedItemId(isExpanded ? null : item.id)}
                    className={`text-xs sm:text-sm font-bold cursor-pointer transition-colors ${
                      isChecked
                        ? 'text-[#6B6156] dark:text-[#AC9E92] line-through'
                        : 'text-[#15120F] dark:text-[#F6EFE8] hover:text-[#B03C09] dark:hover:text-[#FF9A52]'
                    }`}
                  >
                    {item.title}
                  </h4>

                  <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed mt-1">
                    {item.summary}
                  </p>
                </div>

                <button
                  type="button"
                  onClick={() => setExpandedItemId(isExpanded ? null : item.id)}
                  className="p-2 text-[#6B6156] hover:text-[#15120F] dark:hover:text-[#F6EFE8] shrink-0 min-h-[44px] min-w-[44px] flex items-center justify-center"
                  aria-label="Toggle details"
                >
                  {isExpanded ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
                </button>
              </div>

              {/* Expandable Step Details & Deep Dive */}
              <AnimatePresence>
                {isExpanded && (
                  <motion.div
                    initial={{ opacity: 0, height: 0 }}
                    animate={{ opacity: 1, height: 'auto' }}
                    exit={{ opacity: 0, height: 0 }}
                    className="border-t border-[#F3DFCD]/60 dark:border-[#383029] bg-[#FAFAFA] dark:bg-[#1E1915] p-4 text-xs text-[#5A5148] dark:text-[#C6B8AC] space-y-3"
                  >
                    <div>
                      <strong className="text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                        Executive Overview &amp; Rationale:
                      </strong>
                      <p className="leading-relaxed">
                        {item.details.overview}
                      </p>
                    </div>

                    <div>
                      <strong className="text-[#15120F] dark:text-[#F6EFE8] block mb-1">
                        Step-by-Step Action Plan:
                      </strong>
                      <ul className="space-y-1.5 list-disc list-inside">
                        {item.details.actionSteps.map((step, idx) => (
                          <li key={idx} className="leading-relaxed">
                            <span>{step}</span>
                          </li>
                        ))}
                      </ul>
                    </div>

                    {/* Pro Tip Box */}
                    <div className="p-3 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD]/70 dark:border-[#383029]">
                      <div className="flex items-center gap-1.5 text-[#B03C09] dark:text-[#FF9A52] font-bold text-[11px] mb-1">
                        <Sparkles size={13} />
                        <span>Philippine Founder Pro-Tip:</span>
                      </div>
                      <p className="text-[11px] leading-relaxed">
                        {item.details.proTip}
                      </p>
                    </div>

                    <div className="flex items-center justify-between text-[10px] text-[#6B6156] dark:text-[#AC9E92] pt-1">
                      <span>Statutory / Platform Source: {item.details.reference}</span>
                      <button
                        type="button"
                        onClick={() => toggleItem(item.id)}
                        className="font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline"
                      >
                        {isChecked ? 'Mark as Incomplete' : 'Mark as Completed'}
                      </button>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          );
        })}
      </div>
    </div>
  );
};
