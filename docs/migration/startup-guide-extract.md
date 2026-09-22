# PHBusinessStartupGuide content extraction

Source: `/home/user/Salapify/src/components/PHBusinessStartupGuide.tsx` (1,488 lines).

Scope of this extraction: the ROADMAP tab, the ENTITIES tab, and the EXPERTS tab only.
The `checklist` tab and the `saas` tab (`<SaaSAppStoreGuide />`) are deliberately excluded.

Faithfulness note: every string in quotes below is copied character for character from the
source. HTML entities in the source (`&amp;`, `&lt;`) are shown as the character they render
as (`&`, `<`) and flagged where it matters. Where the source contains a literal backslash
inside JSX text (`Mayor\'s`), it is reproduced exactly and listed under SUSPECT.

---

# 1. ROADMAP TAB (`activeTab === 'roadmap'`, lines 439 to 983)

## Tab intro card (lines 441 to 448)

- heading: "Sequential Philippine Business Formation Pipeline"
- body: "Follow this verified sequential order to prevent rejected filings, repeated LGU visits, and costly BIR late registration penalties."

Structure note: each phase is a collapsible card. The card header carries a circled phase
number, an uppercase kicker, an agency line, and the phase heading, plus a chevron
(`ChevronUp` when expanded, `ChevronDown` when collapsed). `expandedPhase` defaults to `1`,
so Phase 1 is open on first render, and only one phase can be open at a time.

---

## Phase 1 (lines 450 to 534)

- phase number: `1`
- kicker (small uppercase): "Initial Formation"
- agency line beside it: "DTI / SEC eSPARC"
- phase heading: "Phase 1: Legal Name Reservation & Entity Registration"

### Body, in source order

Two side-by-side panels (`grid`, 1 column on mobile, 2 on md).

**Panel A, sole proprietorship path**

- panel subhead (accent colour): "For Sole Proprietorship: DTI BNRS"
- body: "Register your trade name through the DTI Business Name Registration System (bnrs.dti.gov.ph). Select territorial scope:"
- bullet (cost): "Barangay: ₱200 fee (+ ₱30 documentary stamp)"
- bullet (cost): "City / Municipality: ₱500 fee (+ ₱30 doc stamp)"
- bullet (cost): "Regional: ₱1,000 fee (+ ₱30 doc stamp)"
- bullet (cost): "National: ₱2,000 fee (+ ₱30 doc stamp)"
- footnote (muted, small, duration + caveat): "*Valid for 5 years. DTI certificates alone do not authorize you to operate; LGU and BIR registrations remain mandatory."

**Panel B, corporation / OPC / partnership path**

- panel subhead (accent colour): "For Corp / OPC / Partnership: SEC eSPARC"
- body: "Submit articles and bylaws online via the SEC Electronic Simplified Processing of Application for Registration of Company (esparc.sec.gov.ph):"
- bullet: "Name Verification Slip (reserve company name)"
- bullet: "Articles of Incorporation & By-Laws (or OPC Articles)"
- bullet: "Treasurer\'s Affidavit / Undertaking to change name"  <- backslash is in the source, see SUSPECT
- bullet: "Nominee and Alternate Nominee acceptance (OPC only)"
- footnote (muted, small, cost): "*Filing fees are calculated based on authorized capital stock (minimum approx. ₱2,000 to ₱5,000+)."

**Tip callout** (accent-tinted panel, `Sparkles` icon)

- callout heading (bold): "Consultant Insight: Business Name vs. Trademark Warning"
- callout body: "Registering your business name with DTI or SEC does not grant intellectual property ownership over your brand or logo. Another entity can legally register your brand name with IPOPHL if you fail to file a trademark."
  - the word "not" is wrapped in `<em>` in the source (italic emphasis)

---

## Phase 2 (lines 535 to 616)

- phase number: `2`
- kicker: "Intellectual Property"
- agency line: "IPOPHL (First-to-File)"
- phase heading: "Phase 2: Trademark & Brand Asset Protection"

### Body, in source order

- body paragraph: "Under the Intellectual Property Code of the Philippines (Republic Act No. 8293), trademarks operate under the First-to-File principle. The person or company who files first holds legal priority, regardless of who used the name first in commerce."
  - "First-to-File principle" is wrapped in `<strong>` in the source

Three numbered step cards (`grid`, 1 column on mobile, 3 on sm):

**Step card 1**
- heading: "1. Search & Nice Class"
- body (muted, small): "Conduct search on IPOPHL e-Search and WIPO Global Brand Database. Identify applicable Nice Classes (e.g., Class 9 for software, Class 35 for retail, Class 42 for SaaS)."

**Step card 2**
- heading: "2. File & Examination"
- body (muted, small, contains durations): "Submit application online via IPOPHL eTMfile. Examination takes 3-6 months. Once cleared, it is published in the IPOPHL e-Gazette for a 30-day public opposition period."

**Step card 3**
- heading: "3. Registration & DAU"
- body (muted, small, contains durations): "Certificate is valid for 10 years. Crucial: You MUST file a Declaration of Actual Use (DAU) with proof of commerce within 3 years and 5 years to maintain the mark."

**Tip callout** (accent-tinted panel, `Info` icon)

- callout heading (bold): "Legal Counsel Pro-Tip:"
- callout body: "If building a digital product, app, or consumer brand, file your IPOPHL application on Day 1 before public launch. Competitors or trademark squatters who notice your initial traction can register your name, forcing costly rebranding or legal buyouts."

---

## Phase 3 (lines 617 to 712)

- phase number: `3`
- kicker: "Local Governance"
- agency line: "Barangay & City Hall (BPLO)"
- phase heading: "Phase 3: Local Government Unit (LGU) Clearances & Mayor\'s Permit"  <- backslash is in the source, see SUSPECT

### Body, in source order

- body paragraph: "You cannot legally operate a business without a Mayor\'s Permit from the city or municipality where your office, clinic, warehouse, or virtual office is located."  <- backslash in source

Four lettered rows, each a bordered panel with a circled letter badge:

**Row A** (badge "A")
- row heading (bold): "Barangay Business Clearance"
- row body (muted, contains a cost range): "Obtain from the barangay hall of your address. Requires DTI/SEC certificate, contract of lease, and proof of address. Fee: ₱300 - ₱1,500."

**Row B** (badge "B")
- row heading (bold): "Locational / Zoning Clearance"
- row body (muted): "Verifies that your business activity is permitted in the designated commercial zone. Pure residential zoning may prohibit physical customer traffic."

**Row C** (badge "C")
- row heading (bold): "Fire Safety Inspection Certificate (FSIC) & Sanitary Permit"
- row body (muted): "Bureau of Fire Protection (BFP) inspects fire extinguishers, emergency exits, and electrical wiring. Health Department issues sanitary permits and staff health cards."

**Row D** (badge "D")
- row heading (bold): "Business Permit and Licensing Office (BPLO) Assessment"
- row body (muted): "Submit all clearances. BPLO calculates local business taxes (LBT) and regulatory fees. Mayor\'s Permit is released along with official receipt and business plate."  <- backslash in source

**Closing note** (small, muted, italic, warning in tone but not a boxed callout, deadline + penalty)

- "Note: Mayor\'s Permits must be renewed annually between January 1 and January 20 to avoid a 25% surcharge plus 2% monthly interest."  <- backslash in source

---

## Phase 4 (lines 713 to 798)

- phase number: `4`
- kicker: "National Taxation"
- agency line: "BIR Form 2303 & Invoicing"
- phase heading: "Phase 4: BIR Registration, Books of Accounts & EOPT Act Invoices"

### Body, in source order

**Highlight callout** (accent-tinted panel, no icon)

- callout heading (accent, bold, small): "Recent Law: Ease of Paying Taxes (EOPT) Act (RA 11976)"
- bullet (cost / abolition): "The annual ₱500 BIR Registration Fee (Form 0605) has been permanently abolished."
  - "permanently abolished" is wrapped in `<strong>` in the source
- bullet: "Invoices are now the primary document for both sales of goods and sales of services (official receipts are now supplemental)."
- bullet: "Taxpayers can now register and file taxes at any authorized RDO without territorial jurisdiction penalties."

Two side-by-side cards (`grid`, 1 column on mobile, 2 on sm):

**Card 1**
- heading: "Application Form"
- body (muted, small): "Submit at your local Revenue District Office (RDO):"
- bullet (form number): "BIR Form 1901: Sole Proprietorship / Professionals"
- bullet (form number): "BIR Form 1903: Corporations & Partnerships"

**Card 2**
- heading: "Form 2303 (COR)"
- body (muted, small, form numbers): "The Certificate of Registration lists all your mandatory tax returns (e.g. 2551Q Percentage Tax or 2550Q VAT, 1701Q/1702Q Income Tax, 1601C Withholding Tax on Compensation)."

**Books of accounts panel**

- panel heading (bold): "Authority to Print (ATP) & Books of Accounts"
- body: "Every business must register its official books:"
- four small centred chip tiles (`grid`, 2 columns on mobile, 4 on sm), each just a label:
  - "General Journal"
  - "General Ledger"
  - "Cash Receipts"
  - "Cash Disbursements"
- footnote (muted, small, form number): "*Submit BIR Form 1906 for Authority to Print (ATP) with an accredited BIR printer for your physical sales invoices. If using electronic invoicing, apply for Permit to Use (PTU) or Computerized Accounting System (CAS)."

---

## Phase 5 (lines 799 to 878)

- phase number: `5`
- kicker: "Mandatory Labor Benefits"
- agency line: "SSS, PhilHealth, Pag-IBIG, DOLE"
- phase heading: "Phase 5: Mandatory Statutory Employer Registrations"

### Body, in source order

- body paragraph: "Under Philippine labor laws, the moment you hire your first employee, you are legally classified as an employer and must register with all statutory institutions:"

Four cards (`grid`, 1 column on mobile, 2 on sm):

**Card 1**
- heading: "Social Security System (SSS)"
- body (muted, small, form numbers): "Submit Form R-1 (Employer Registration) and Form R-1A (Employment Report). Mandatory for retirement, sickness, maternity, disability, and death benefits."

**Card 2**
- heading: "PhilHealth"
- body (muted, small, form number): "Submit Form ER1 (Employer Data Record) to receive your PhilHealth Employer Number (PEN). Remit mandatory national healthcare coverage monthly."

**Card 3**
- heading: "Pag-IBIG Fund (HDMF)"
- body (muted, small, form number): "Submit Form HQP-PFF-002 for employer registration. Provides national housing loan facilities and savings funds for employees."

**Card 4**
- heading: "DOLE Rule 1020 Registration"
- body (muted, small, deadline): "File establishment notice with the Department of Labor and Employment within 30 days of commercial operations for workplace safety compliance."

---

## Phase 6 (lines 879 to 981)

- phase number: `6`
- kicker: "Tech & Digital Startups"
- agency line: "NPC, NTC, BSP, E-Commerce"
- phase heading: "Phase 6: Digital Products, Data Privacy & Sectoral Licenses"

### Body, in source order

- body paragraph: "Digital startups, web platforms, mobile apps, SaaS, and e-commerce stores have specialized statutory requirements:"

**Block 1, NPC** (bordered panel, carries a red "CRITICAL" badge)

- block heading (accent, bold): "National Privacy Commission (NPC) -- RA 10173 (Data Privacy Act)"
  - the separator is two ASCII hyphens in the source, not an em dash
- badge (red pill, top right of the heading row): "CRITICAL"
- body: "Any app or website collecting user data (emails, passwords, phone numbers, addresses, financial logs) must comply:"
- bullet: "Appoint an official Data Protection Officer (DPO)."
- bullet (thresholds): "Register with the NPC if processing sensitive personal information of 1,000+ individuals or employing 250+ personnel."
- bullet: "Display a clear, accessible Privacy Notice and cookie/data consent banners on your website/app."
- bullet (deadline): "Maintain a strict 72-hour notification protocol to the NPC in the event of a security data breach."

**Block 2, NTC** (bordered panel)

- block heading (accent, bold): "National Telecommunications Commission (NTC) -- VAS License"
- body: "If your tech platform provides messaging services, SMS gateways, VoIP calls, premium digital content delivery, or integrates direct telecom transmission, you must secure an NTC Value-Added Service (VAS) Certificate of Registration before public rollout."

**Block 3, Internet Transactions Act** (bordered panel)

- block heading (accent, bold): "Internet Transactions Act of 2023 (RA 11967) & DTI E-Commerce Bureau"
- body: "Applies to all digital marketplaces, online merchants, and social commerce sellers:"
- bullet: "Must display registered business name, DTI/SEC number, geographic address, and active contact channels."
- bullet: "Online platforms are solidarily liable with merchants if they knowingly allow illegal, counterfeit, or hazardous products."
- bullet: "Registration with the Philippine Online Business Registry is mandated."

**Block 4, three sectoral tiles** (`grid`, 1 column on mobile, 3 on sm)

- tile heading: "Fintech & Payments"
  - tile body: "BSP Operator of Payment System (OPS) registration is required for payment aggregators, escrow wallets, or digital money remitters."
- tile heading: "Lending & BNPL"
  - tile body: "Strict SEC Certificate of Authority under the Lending Company Regulation Act is required to offer digital credit or installments."
- tile heading: "Health & Food"
  - tile body: "FDA License to Operate (LTO) and Certificate of Product Registration (CPR) are required before listing cosmetics or ingestibles online."

Phase 6 is the last phase; the roadmap tab ends at line 983.

---

# 2. ENTITIES TAB (`activeTab === 'entities'`, lines 986 to 1297)

Order on screen: the quiz card first, then the recommendation result (conditional), then the
four entity comparison cards.

## 2.1 Interactive quiz (lines 988 to 1137)

- card heading (with `Sparkles` icon): "Interactive Entity Matcher: Which Structure Fits Your Business?"
- card body (muted): "Answer 3 simple operational questions to get a personalized recommendation from our Philippine Corporate Advisory Council."

There are THREE questions on screen. The state object has FOUR keys
(`owners`, `liability`, `funding`, `compliance`); `compliance` is never set by any control.

### Question 1, sets state key `owners`

- label: "1. How many founders or co-owners will start the business?"
- option 1
  - label: "Just me (Solo Founder)"
  - sets: `owners: 'single'`
- option 2
  - label: "2 or more Partners / Co-founders"
  - sets: `owners: 'multiple'`

### Question 2, sets state key `liability`

- label: "2. What is your requirement regarding personal asset liability?"
- option 1
  - label: "Shield personal assets (Limited Liability)"
  - sets: `liability: 'protected'`
- option 2
  - label: "Low commercial risk / Simplicity first"
  - sets: `liability: 'low_risk'`

### Question 3, sets state key `funding`

- label: "3. Do you plan to raise venture capital or issue shares to outside investors?"
- option 1
  - label: "Yes, will raise funding / issue shares"
  - sets: `funding: 'investors'`
- option 2
  - label: "No, self-funded / client revenue"
  - sets: `funding: 'bootstrapped'`

### State key `compliance`

- declared in `quizAnswers` (line 252, initial value `''`)
- never written by any control and never read by `getEntityRecommendation`
- there is no question 4 on screen

### Selection affordance

Each selected option renders a `Check` icon at its right edge; the selected button flips to
the accent background.

## 2.2 Recommendation result card (lines 1103 to 1137)

Rendered only when `recommendation` is non-null (that is, when `owners` has been answered).
Animated in with `motion.div` (fade and 10px rise).

- kicker (small uppercase, accent): "Recommended Match"
- then `recommendation.title` as the card heading
- then `recommendation.summary` as the body paragraph
- then `recommendation.reasons` as a list, each row prefixed with a `Check` icon

## 2.3 Recommendation decision tree (`getEntityRecommendation`, lines 286 to 334)

The function reads only `quizAnswers.owners`, `quizAnswers.liability` and
`quizAnswers.funding`. It never reads `compliance`. There are FOUR reachable branches plus
one null guard.

### Branch 0, null guard

- condition: `!quizAnswers.owners` (question 1 unanswered)
- result: `null`, so no recommendation card is rendered at all

### Branch 1, OPC

- condition: `owners === 'single'` AND (`liability === 'protected'` OR `funding === 'investors'`)
- title: "One Person Corporation (OPC)"
- summary: "Ideal for solo entrepreneurs who demand complete operational autonomy while securing limited liability protection to safeguard personal assets."
- reasons, in order:
  1. "Only 1 stockholder required under Revised Corporation Code (RA 11232)."
  2. "Personal properties (home, family savings) are shielded from corporate debt."
  3. "No statutory minimum capital requirement (unless in regulated industries)."
  4. "Must appoint Nominee and Alternate Nominee to guarantee continuity."

### Branch 2, Sole Proprietorship (fallback inside the `single` arm)

- condition: `owners === 'single'` AND NOT (`liability === 'protected'` OR `funding === 'investors'`)
  - in practice: solo founder who picked "Low commercial risk / Simplicity first" or left
    liability blank, and who picked "No, self-funded / client revenue" or left funding blank
  - note: this branch is reached even when questions 2 and 3 are both unanswered
- title: "Sole Proprietorship"
- summary: "Best for low-capital, solo freelancers, home-based traders, or small retail businesses needing rapid, low-cost registration."
- reasons, in order:
  1. "Registered simply with DTI (no complex corporate bylaws or board meetings)."
  2. "Lowest formation fees (₱200-₱2,000 DTI registration fee)."
  3. "Pass-through taxation: eligible for simplified 8% gross income tax under TRAIN law if revenue is under ₱3M."
  4. "Trade-off: Unlimited personal liability for business debts and obligations."

### Branch 3, Regular Stock Corporation

- condition: `owners !== 'single'` (the `else` arm, in practice `owners === 'multiple'`) AND (`funding === 'investors'` OR `liability === 'protected'`)
- title: "Regular Stock Corporation"
- summary: "The gold standard for scalable startups, tech ventures, and businesses with multiple co-founders planning to raise venture capital."
- reasons, in order:
  1. "Can have 2 to 15 incorporators under the Revised Corporation Code."
  2. "Can issue multiple share classes (common, preferred) to angel investors and venture funds."
  3. "Limited liability for all shareholders up to their capital subscriptions."
  4. "Subject to Corporate Income Tax (20% under CREATE for small-medium firms with taxable income under ₱5M and assets under ₱100M)."

### Branch 4, Partnership (final fallback / else)

- condition: `owners !== 'single'` AND NOT (`funding === 'investors'` OR `liability === 'protected'`)
- title: "General or Limited Partnership"
- summary: "Suited for two or more professional partners (consultants, designers, agencies) co-owning an enterprise under a joint agreement."
- reasons, in order (only THREE reasons, the other branches have four):
  1. "Registered with SEC via Articles of Partnership."
  2. "Clear contractual profit/loss distribution between co-owners."
  3. "Trade-off: In general partnerships, partners carry joint and several personal liability."

### Branch condition ordering, for the port

Within the `single` arm the disjunction is tested as `liability === 'protected' || funding === 'investors'`.
Within the `else` arm the same two clauses are tested in the OPPOSITE order,
`funding === 'investors' || liability === 'protected'`. The result is logically identical
(both are plain `||` with no side effects), but the source ordering is preserved here
because it is what the file says.

## 2.4 Entity comparison cards (lines 1139 to 1295)

Four cards in a `grid`, 1 column on mobile, 2 on md. Each card has a title, a right-aligned
registrar badge, a description paragraph, and five attribute rows (label on the left, value on
the right). Some values carry a semantic colour; that is noted because it is meaningful.

### Card 1, Sole Proprietorship

- title: "Sole Proprietorship"
- registrar badge (neutral grey): "Registered via DTI"
- description: "Owned entirely by one individual. The owner and the business are treated as a single legal person."
- attribute rows:
  - "Liability:" -> "Unlimited (personal assets at risk)"  (rendered RED)
  - "Capital Requirement:" -> "No minimum statutory capital"
  - "Taxation Model:" -> "Pass-through (8% flat or graduated)"
  - "Setup Timeline:" -> "Fastest (1-3 business days for DTI)"
  - "Investor Feasibility:" -> "Cannot sell equity shares"  (rendered muted grey)

### Card 2, One Person Corporation (OPC)

- title: "One Person Corporation (OPC)"
- registrar badge (accent): "Registered via SEC"
- description: "A modern corporate vehicle created under RA 11232 for solo founders who want corporate limited liability without needing a board of directors."
- attribute rows:
  - "Liability:" -> "Limited to corporate assets"  (rendered EMERALD / green)
  - "Mandatory Officers:" -> "Nominee & Alternate Nominee"
  - "Taxation Model:" -> "Corporate Income Tax (CIT - 20%/25%)"
  - "Corporate Governance:" -> "No Board or By-Laws required"
  - "Investor Feasibility:" -> "Must convert to regular corp to add owners"

### Card 3, Regular Stock Corporation

- title: "Regular Stock Corporation"
- registrar badge (accent): "Registered via SEC"
- description: "Formed by 2 to 15 incorporators. Issues shares of capital stock and is governed by an elected Board of Directors."
- attribute rows:
  - "Liability:" -> "Limited to subscribed capital"  (rendered EMERALD / green)
  - "Governance:" -> "Board of Directors, President, CorpSec, Treasurer"
  - "Taxation Model:" -> "CIT (20% under CREATE if taxable income <= ₱5M)"
    - the source writes `&lt;=`, so the rendered character is "<=" (two characters, not the ≤ glyph)
  - "Reporting:" -> "Annual GIS (General Information Sheet) & AFS"
  - "Investor Feasibility:" -> "Highest (preferred by angels & VCs)"  (rendered EMERALD / green)

### Card 4, Partnership

- title: "Partnership (General & Limited)"
- registrar badge (neutral grey): "Registered via SEC"
- description: "Two or more persons bind themselves to contribute money, property, or industry to a common fund, with the intention of dividing profits."
- attribute rows:
  - "Liability:" -> "Joint & several for general partners"  (rendered AMBER)
  - "Formation Document:" -> "Articles of Partnership"
  - "General Professional Partnership (GPP):" -> "Tax-exempt entity (partners taxed individually)"
  - "Commercial Partnership:" -> "Taxed like a regular corporation (CIT)"
  - "Continuity:" -> "Dissolved upon death or withdrawal of partner"  (rendered muted grey)

### Entity filter

`entityFilter` state exists (line 223, `'all' | 'sole_prop' | 'opc' | 'corp' | 'partnership'`)
but there is NO filter control and no card is ever filtered. All four cards always render.

---

# 3. EXPERTS TAB (`activeTab === 'experts'`, lines 1381 to 1485)

## Tab intro card

- heading: "Expert Council Warnings: Common Philippine Startup Mistakes"
- body (muted): "Real-world advice from Philippine CPAs, corporate attorneys, and business advisors to save your venture from penalties, lawsuits, and closure."

## The six traps

Each trap is one card. The card header is two inline pieces: an uppercase accent kicker
naming the expert persona, then the bold trap title. The body is a single paragraph. There
are no icons and no sub-bullets anywhere in this tab.

### Trap 1

- kicker: "BIR Compliance Expert"
- title: "Trap 1: Thinking DTI Registration is Enough to Start Selling"
- body: "Many beginner entrepreneurs register with DTI online, open an online shop, and begin trading without ever visiting the BIR. Under Section 258 of the Tax Code, conducting business without a BIR Certificate of Registration (Form 2303) and without issuing official sales invoices is a criminal tax offense carrying heavy fines (₱10,000 to ₱50,000+) and potential establishment closure under Oplan Kandado."

### Trap 2

- kicker: "CPA & Tax Accountant"
- title: "Trap 2: Forgetting to File Zero-Income (Nil) Tax Returns"
- body: "Once registered with the BIR, you must submit all tax returns listed on your Form 2303 (quarterly income tax, percentage tax, withholding tax) even if your business generated zero income during the quarter. Filing a zero or nil return is free, but failing to file results in a compromise penalty of ₱1,000 per unfiled return, which quickly balloons into tens of thousands of pesos in hidden open cases."

### Trap 3

- kicker: "E-Commerce Specialist"
- title: "Trap 3: The 1% Withholding Tax on Marketplace Sellers (RR 16-2023)"
- body: "Under BIR Revenue Regulations No. 16-2023, electronic marketplace operators (Shopee, Lazada, TikTok Shop) and digital financial service providers (GCash, Maya) are mandated to withhold a 1% creditable withholding tax on one-half (0.5% effective) of gross remittances to online sellers whose annual gross remittances exceed ₱500,000. All marketplace sellers must be BIR-registered to avoid account suspension."

### Trap 4

- kicker: "Legal & IP Counsel"
- title: "Trap 4: Missing the 3-Year Declaration of Actual Use (DAU) for Trademarks"
- body: "Filing an IPOPHL trademark application is only the first step. You must submit a formal Declaration of Actual Use (DAU) accompanied by actual proof of use in Philippine commerce (sales receipts, website screenshots, product photos) within 3 years from the filing date. Missing this deadline causes the automatic refusal or cancellation of your registered mark."

### Trap 5

- kicker: "Mobile & App Store Specialist"
- title: "Trap 5: App Store Review Rejection -- Bypassing IAP or Missing In-App Account Deletion"
  - the separator is two ASCII hyphens in the source
- body: "Under Apple App Store Guideline 3.1.1, all digital subscriptions and digital feature unlocks on iOS must go through StoreKit In-App Purchases; attempting to link to an external web checkout will cause an immediate rejection. Furthermore, Guideline 5.1.1(v) requires any app with account creation to include a fully functional in-app account deletion mechanism that permanently purges user data."

### Trap 6

- kicker: "SaaS Business & Tax Strategist"
- title: "Trap 6: The Global Sales Tax Trap -- Using Raw Stripe Instead of an MoR"
  - the separator is two ASCII hyphens in the source
- body: "When selling a Web SaaS to customers in Europe, the UK, or the US, using raw Stripe makes your Philippine company directly liable for registering and remitting local VAT and state sales tax across dozens of jurisdictions. Using a Merchant of Record (Paddle or Lemon Squeezy) delegates all global sales tax compliance to the MoR, leaving you with one clean, zero-rated B2B invoice per month."

## Questions, answers and tips in this tab

There are none. The tab is labelled "Expert Pitfalls & Q&A" in the tab bar, but the tab body
contains only the intro card and the six trap cards. No FAQ list, no question/answer pairs,
no tip callouts exist in this section. Flagged under SUSPECT.

---

# ICONS

`lucide-react` icons that actually RENDER inside the three extracted sections, and what each
sits next to.

| Icon | Where it appears | What it sits next to |
| --- | --- | --- |
| `ChevronUp` | Roadmap, every phase header (lines 475, 558, 636, 737, 825, 902) | Right edge of the phase header button when that phase is EXPANDED |
| `ChevronDown` | Roadmap, every phase header (same lines) | Right edge of the phase header button when that phase is COLLAPSED |
| `Sparkles` | Roadmap Phase 1, line 521 | Leading icon of the "Consultant Insight: Business Name vs. Trademark Warning" tip callout |
| `Info` | Roadmap Phase 2, line 598 | Leading icon of the "Legal Counsel Pro-Tip:" callout |
| `Sparkles` | Entities, line 991 | Left of the heading "Interactive Entity Matcher: Which Structure Fits Your Business?" |
| `Check` | Entities, lines 1017, 1029, 1050, 1062, 1083, 1095 | Right edge of each SELECTED quiz option button (size 14) |
| `Check` | Entities, line 1122 | Leading bullet marker on each reason row in the recommendation card (size 14, accent colour) |

Experts tab: NO icons at all.

Icons that appear elsewhere in the file but NOT in the three extracted sections:
`AlertTriangle` (line 373, shared header disclaimer, outside all tabs), `Sparkles`
(line 385, shared header Expert Advisory Council row, outside all tabs), `Check`
(line 1349, checklist tab), and the tab-bar icons `Compass` (Registration Roadmap tab),
`Smartphone` (SaaS & App Stores tab), `Building2` (Entity Comparison tab), `CheckSquare`
(Readiness Tracker tab), `HelpCircle` (Expert Pitfalls & Q&A tab).

Imported but never used anywhere in the file: `Briefcase`, `Scale`, `FileText`,
`FileCheck`, `ShieldAlert`, `Layers`, `Globe`, `ExternalLink`, `ShieldCheck`, `ArrowRight`,
`RotateCcw`, `CreditCard`, `Laptop`, `Calculator`. Also `AnimatePresence` from `motion/react`
is imported and never used.

---

# NUMBERS

Every peso figure, percentage, day/month/year count, form number, statute reference and
numeric threshold in the three extracted sections, with the sentence it sits in.

## Roadmap, Phase 1

| Value | Sentence |
| --- | --- |
| ₱200, ₱30 | "Barangay: ₱200 fee (+ ₱30 documentary stamp)" |
| ₱500, ₱30 | "City / Municipality: ₱500 fee (+ ₱30 doc stamp)" |
| ₱1,000, ₱30 | "Regional: ₱1,000 fee (+ ₱30 doc stamp)" |
| ₱2,000, ₱30 | "National: ₱2,000 fee (+ ₱30 doc stamp)" |
| 5 years | "*Valid for 5 years. DTI certificates alone do not authorize you to operate; LGU and BIR registrations remain mandatory." |
| ₱2,000 to ₱5,000+ | "*Filing fees are calculated based on authorized capital stock (minimum approx. ₱2,000 to ₱5,000+)." |

## Roadmap, Phase 2

| Value | Sentence |
| --- | --- |
| Republic Act No. 8293 | "Under the Intellectual Property Code of the Philippines (Republic Act No. 8293), trademarks operate under the First-to-File principle." |
| Class 9, Class 35, Class 42 | "Identify applicable Nice Classes (e.g., Class 9 for software, Class 35 for retail, Class 42 for SaaS)." |
| 3-6 months | "Examination takes 3-6 months." |
| 30-day | "Once cleared, it is published in the IPOPHL e-Gazette for a 30-day public opposition period." |
| 10 years | "Certificate is valid for 10 years." |
| 3 years, 5 years | "Crucial: You MUST file a Declaration of Actual Use (DAU) with proof of commerce within 3 years and 5 years to maintain the mark." |
| Day 1 | "If building a digital product, app, or consumer brand, file your IPOPHL application on Day 1 before public launch." |

## Roadmap, Phase 3

| Value | Sentence |
| --- | --- |
| ₱300 - ₱1,500 | "Obtain from the barangay hall of your address. Requires DTI/SEC certificate, contract of lease, and proof of address. Fee: ₱300 - ₱1,500." |
| January 1, January 20, 25%, 2% | "Note: Mayor\'s Permits must be renewed annually between January 1 and January 20 to avoid a 25% surcharge plus 2% monthly interest." |

## Roadmap, Phase 4

| Value | Sentence |
| --- | --- |
| RA 11976 | "Recent Law: Ease of Paying Taxes (EOPT) Act (RA 11976)" |
| ₱500, Form 0605 | "The annual ₱500 BIR Registration Fee (Form 0605) has been permanently abolished." |
| BIR Form 1901 | "BIR Form 1901: Sole Proprietorship / Professionals" |
| BIR Form 1903 | "BIR Form 1903: Corporations & Partnerships" |
| Form 2303 | "Form 2303 (COR)" (card heading) |
| 2551Q, 2550Q, 1701Q, 1702Q, 1601C | "The Certificate of Registration lists all your mandatory tax returns (e.g. 2551Q Percentage Tax or 2550Q VAT, 1701Q/1702Q Income Tax, 1601C Withholding Tax on Compensation)." |
| BIR Form 1906 | "*Submit BIR Form 1906 for Authority to Print (ATP) with an accredited BIR printer for your physical sales invoices." |
| BIR Form 2303 | also in the Phase 4 agency line: "BIR Form 2303 & Invoicing" |

## Roadmap, Phase 5

| Value | Sentence |
| --- | --- |
| Form R-1, Form R-1A | "Submit Form R-1 (Employer Registration) and Form R-1A (Employment Report). Mandatory for retirement, sickness, maternity, disability, and death benefits." |
| Form ER1 | "Submit Form ER1 (Employer Data Record) to receive your PhilHealth Employer Number (PEN)." |
| Form HQP-PFF-002 | "Submit Form HQP-PFF-002 for employer registration. Provides national housing loan facilities and savings funds for employees." |
| Rule 1020 | "DOLE Rule 1020 Registration" (card heading) |
| 30 days | "File establishment notice with the Department of Labor and Employment within 30 days of commercial operations for workplace safety compliance." |

## Roadmap, Phase 6

| Value | Sentence |
| --- | --- |
| RA 10173 | "National Privacy Commission (NPC) -- RA 10173 (Data Privacy Act)" |
| 1,000+, 250+ | "Register with the NPC if processing sensitive personal information of 1,000+ individuals or employing 250+ personnel." |
| 72-hour | "Maintain a strict 72-hour notification protocol to the NPC in the event of a security data breach." |
| 2023, RA 11967 | "Internet Transactions Act of 2023 (RA 11967) & DTI E-Commerce Bureau" |

## Entities tab, quiz and options

| Value | Sentence |
| --- | --- |
| 3 | "Answer 3 simple operational questions to get a personalized recommendation from our Philippine Corporate Advisory Council." |
| 1 | "1. How many founders or co-owners will start the business?" |
| 2 | "2 or more Partners / Co-founders" |
| 2 | "2. What is your requirement regarding personal asset liability?" |
| 3 | "3. Do you plan to raise venture capital or issue shares to outside investors?" |

## Entities tab, recommendation branches

| Value | Sentence |
| --- | --- |
| 1, RA 11232 | "Only 1 stockholder required under Revised Corporation Code (RA 11232)." |
| ₱200-₱2,000 | "Lowest formation fees (₱200-₱2,000 DTI registration fee)." |
| 8%, ₱3M | "Pass-through taxation: eligible for simplified 8% gross income tax under TRAIN law if revenue is under ₱3M." |
| 2 to 15 | "Can have 2 to 15 incorporators under the Revised Corporation Code." |
| 20%, ₱5M, ₱100M | "Subject to Corporate Income Tax (20% under CREATE for small-medium firms with taxable income under ₱5M and assets under ₱100M)." |

## Entities tab, comparison cards

| Value | Sentence |
| --- | --- |
| 8% | "Taxation Model: Pass-through (8% flat or graduated)" (Sole Proprietorship) |
| 1-3 business days | "Setup Timeline: Fastest (1-3 business days for DTI)" (Sole Proprietorship) |
| RA 11232 | "A modern corporate vehicle created under RA 11232 for solo founders who want corporate limited liability without needing a board of directors." (OPC) |
| 20%/25% | "Taxation Model: Corporate Income Tax (CIT - 20%/25%)" (OPC) |
| 2 to 15 | "Formed by 2 to 15 incorporators. Issues shares of capital stock and is governed by an elected Board of Directors." (Regular Stock Corporation) |
| 20%, ₱5M | "Taxation Model: CIT (20% under CREATE if taxable income <= ₱5M)" (Regular Stock Corporation) |

## Experts tab

| Value | Sentence |
| --- | --- |
| Section 258, Form 2303, ₱10,000 to ₱50,000+ | "Under Section 258 of the Tax Code, conducting business without a BIR Certificate of Registration (Form 2303) and without issuing official sales invoices is a criminal tax offense carrying heavy fines (₱10,000 to ₱50,000+) and potential establishment closure under Oplan Kandado." |
| Form 2303 | "Once registered with the BIR, you must submit all tax returns listed on your Form 2303 (quarterly income tax, percentage tax, withholding tax) even if your business generated zero income during the quarter." |
| ₱1,000 | "Filing a zero or nil return is free, but failing to file results in a compromise penalty of ₱1,000 per unfiled return, which quickly balloons into tens of thousands of pesos in hidden open cases." |
| 1%, RR 16-2023 | "Trap 3: The 1% Withholding Tax on Marketplace Sellers (RR 16-2023)" |
| No. 16-2023, 1%, one-half, 0.5%, ₱500,000 | "Under BIR Revenue Regulations No. 16-2023, electronic marketplace operators (Shopee, Lazada, TikTok Shop) and digital financial service providers (GCash, Maya) are mandated to withhold a 1% creditable withholding tax on one-half (0.5% effective) of gross remittances to online sellers whose annual gross remittances exceed ₱500,000." |
| 3-Year | "Trap 4: Missing the 3-Year Declaration of Actual Use (DAU) for Trademarks" |
| 3 years | "You must submit a formal Declaration of Actual Use (DAU) accompanied by actual proof of use in Philippine commerce (sales receipts, website screenshots, product photos) within 3 years from the filing date." |
| Guideline 3.1.1 | "Under Apple App Store Guideline 3.1.1, all digital subscriptions and digital feature unlocks on iOS must go through StoreKit In-App Purchases; attempting to link to an external web checkout will cause an immediate rejection." |
| Guideline 5.1.1(v) | "Furthermore, Guideline 5.1.1(v) requires any app with account creation to include a fully functional in-app account deletion mechanism that permanently purges user data." |

---

# SUSPECT

Reported, not fixed.

1. **Literal backslashes rendered to the user.** Five JSX TEXT nodes contain `\'` where a
   plain `'` was intended. In JSX text children a backslash is a literal character, so the
   screen actually shows "Mayor\'s Permit" and "Treasurer\'s Affidavit". Lines 511, 632,
   643, 698 and 705. (Lines 60 and 66 contain the same sequence but inside JavaScript string
   literals, where `\'` is correct and renders as an apostrophe; those are in the checklist
   tab, out of scope.)

2. **The Experts tab has no Q&A and no tips.** The tab bar labels it "Expert Pitfalls & Q&A"
   (line 409) and the extraction brief asked for "every pitfall, question, answer and tip".
   The tab body contains only an intro card and six trap paragraphs. There are no questions,
   no answers and no tip callouts anywhere in it.

3. **Quiz says "3 simple operational questions"; state carries four keys.** `quizAnswers`
   declares `compliance` (line 252) and the brief expects a `compliance` question, but no
   control ever sets it and `getEntityRecommendation` never reads it. A compliance question
   appears to have been planned and dropped, or lost.

4. **`quizStep` is dead state.** Declared at line 247 with a setter, never read, never set.
   Suggests the quiz was once a stepper and is now a single page.

5. **`entityFilter` is dead state.** Declared at line 223 as
   `'all' | 'sole_prop' | 'opc' | 'corp' | 'partnership'`, never read and never set. No
   filter control exists; all four entity cards always render.

6. **Fourteen unused icon imports plus `AnimatePresence`.** `Briefcase`, `Scale`,
   `FileText`, `FileCheck`, `ShieldAlert`, `Layers`, `Globe`, `ExternalLink`, `ShieldCheck`,
   `ArrowRight`, `RotateCcw`, `CreditCard`, `Laptop`, `Calculator` are imported and never
   used anywhere in the file. Symptom of content having been cut, so some of the material
   this extraction is porting may be an incomplete remnant.

7. **Trademark DAU deadline stated two different ways.** Phase 2 step card 3 says the DAU
   must be filed "within 3 years and 5 years to maintain the mark" (two separate filings,
   the 3rd-year DAU and the 5th-year DAU). Experts Trap 4 says only "within 3 years from the
   filing date" and calls the 3-year one the deadline whose miss causes cancellation. Not
   contradictory in law, but a reader gets two different pictures of how many filings there
   are, and Phase 2's phrasing ("within 3 years and 5 years") is ambiguous as written.

8. **The OPC card and the Regular Corporation card give different CIT figures.** OPC says
   "Corporate Income Tax (CIT - 20%/25%)"; Regular Stock Corporation says "CIT (20% under
   CREATE if taxable income <= ₱5M)". The OPC row never states the threshold that decides
   between 20% and 25%, so the same tax regime is described with and without its condition
   in two cards sitting side by side.

9. **CREATE thresholds stated inconsistently.** The Regular Stock Corporation recommendation
   reason says "20% under CREATE for small-medium firms with taxable income under ₱5M and
   assets under ₱100M" (two conditions). The comparison card for the same entity gives only
   "if taxable income <= ₱5M" (one condition), and also switches from "under" to "<=". Worth
   fact-checking which is right before the port hard-codes either.

10. **Marketplace withholding sentence is self-contradicting as written.** "mandated to
    withhold a 1% creditable withholding tax on one-half (0.5% effective) of gross
    remittances". A 1% rate applied to one-half of gross is 0.5% effective, so the arithmetic
    is internally consistent, but the plain reading of "withhold a 1% ... tax" in the same
    sentence as "0.5% effective" will read as a contradiction to a beginner. Fact-check the
    actual RR 16-2023 mechanic before porting the wording.

11. **Date-sensitive claims with no "as of" marker.** Several statements are live-law claims
    that rot: the EOPT Act abolishing the ₱500 annual registration fee, the ₱500,000 annual
    remittance threshold in RR 16-2023, the 8% / ₱3M TRAIN threshold, the CREATE 20% / ₱5M /
    ₱100M thresholds, the DTI BNRS fee ladder, the Apple Guideline numbers 3.1.1 and
    5.1.1(v), and the barangay clearance range "₱300 - ₱1,500". None of them carries a date
    or a source citation anywhere in the component. The component's own header disclaimer
    says these change frequently ("Laws, municipal ordinances, BIR tax regulations (such as
    the Ease of Paying Taxes Act), and agency filing procedures change frequently."), which
    is the code effectively flagging its own uncertainty.

12. **Phase 1 fee ladder vs recommendation reason disagree in framing.** Phase 1 lists DTI
    scope fees of ₱200 / ₱500 / ₱1,000 / ₱2,000 plus a ₱30 documentary stamp each. The Sole
    Proprietorship recommendation reason says "Lowest formation fees (₱200-₱2,000 DTI
    registration fee)" and omits the documentary stamp entirely. Same facts, two totals.

13. **No `key` warning risk and no source URLs.** None of the roadmap or experts content
    links out. Agency portals are given as bare text (`bnrs.dti.gov.ph`, `esparc.sec.gov.ph`)
    rather than as links, and `ExternalLink` is imported but unused, so an outbound-link
    treatment was likely planned. If the Flutter port wants official-source URLs, none exist
    in this file to carry over, and the repository rule on Money Courses official-source URLs
    would require a real search before any are added.

14. **`--` used as a sentence separator in four headings.** "National Privacy Commission
    (NPC) -- RA 10173", "National Telecommunications Commission (NTC) -- VAS License",
    "Trap 5: App Store Review Rejection -- Bypassing IAP ...", "Trap 6: The Global Sales Tax
    Trap -- Using Raw Stripe Instead of an MoR". These are two ASCII hyphens, consistent with
    the repository's no-em-dash rule, but they read as a stand-in for an em dash and will
    need a deliberate decision (comma, colon or period) in the Flutter copy.
