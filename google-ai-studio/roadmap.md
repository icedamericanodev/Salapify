# Salapify 3 - Product Roadmap & Queue

This roadmap tracks feature execution based on the Salapify 3 specification (`docs/revamp/`) and domain expert reviews.

---

## Phase 1: Core Foundation (Completed)
- [x] Initialized Vite + React + Tailwind v4 project with Hapon & Gabi theme tokens.
- [x] Implemented core domain models (`types.ts`, `FinancialContext.tsx`) with local storage persistence.
- [x] Built the Safe-to-Spend Hero Panel with the 5dp Sweldo Rail.
- [x] Built the 5dp Debt Beam Card and dedicated Debt Manager screen (with 1.2s celebratory settlement).
- [x] Built the Day-grouped Ledger with live search, filters, and In vs Out visual insights.
- [x] Built the Plan screen with Budget limits, Sweldo Bill Timeline, and Ipon Goals.
- [x] Built Accounts screen with Net Worth overview, Monograms, and Credit Card utilization.
- [x] Built Fast-Log natural language parser and 250ms glide-up transaction sheet.
- [x] Fixed light mode class-based custom variant in Tailwind v4.

---

## Phase 2: First-Run Experience & Starter Packs (Active)
- [ ] **First-Run Onboarding Flow**:
  - Screen 1: Welcome banner with "Start fresh" or "Restore a backup".
  - Screen 2: First account and balance setup (presets for GCash, Maya, BPI, Cash).
  - Screen 3: Payday cycle selection (15th and 30th, monthly, weekly) introducing the Sweldo Rail.
- [ ] **Starter Category Packs**:
  - Curated category templates designed with CPA and Financial Coach input:
    - *Student Pack*: Allowance, Tuition, Books, Commute, Barkada Food, Treats.
    - *Young Professional / Employee Pack*: Sweldo, Groceries, Rent, Utilities, SSS/PhilHealth/Pag-IBIG, Weekend Treats.
    - *Freelancer / Remote Contractor Pack*: Client Invoices, 8% Gross Tax Reserve, Co-working/Internet, Equipment, Self-employed Contributions.
    - *OFW Family Pack*: Remittance Received, Padala Sent, Household Bills, Emergency Reserve, Savings.

---

## Phase 3: Financial Coach & Philippine Tax Utilities
- [ ] **Tax & 13th Month Calculator**:
  - TRAIN Law salary breakdown: Gross income, mandatory contributions (SSS, PhilHealth, Pag-IBIG), withholding tax.
  - 13th Month Pay tax-exempt threshold tracking (up to PHP 90,000 exempt under Philippine tax law).
- [ ] **High-Yield Digital Banking Guides & Credit Radar**:
  - Bank Officer insights on digital bank interest rates (e.g. Maya, SeaBank, GoTyme).
  - Credit utilization radar warning when spending exceeds 30% of card credit limits.

---

## Phase 4: Verification & QA
- [ ] Automated and manual journey tests for all flows.
- [ ] Zero-state edge cases verification.
- [ ] Verified clean builds on `google-aistudio-build`.
