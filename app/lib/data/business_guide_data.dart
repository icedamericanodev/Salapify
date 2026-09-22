/// The Philippine business registration checklist, ported from the prototype.
///
/// Source: `src/components/PHBusinessStartupGuide.tsx`, `CHECKLIST_ITEMS`.
/// Ported on founder direction, 2026-09-22 ("port this next"), from the card
/// on the Academy tab that had been promising it.
///
/// ## Every word here is the prototype's
///
/// Nothing in this file was rewritten, improved or brought up to date during
/// the port, deliberately. A port that edits its content as it goes cannot be
/// checked against its source, and this content makes specific claims about
/// Philippine law, agencies and forms that somebody may act on. It is
/// reviewed as a separate pass, by the people whose job that is, and any
/// correction lands as its own change with its own reason.
///
/// The one thing that IS ours is the [icon] on each category, because the
/// prototype draws lucide-react glyphs the Flutter app does not have. Names
/// resolve through `design/salapify_icon.dart`, and a name missing from its
/// map is caught by the content test rather than falling back silently.
///
/// ## The ids are a stored contract
///
/// [BusinessStep.id] is written into the person's saved file the moment they
/// tick a box, so renaming one silently unticks that step for everybody who
/// had done it. They are the prototype's own ids and they stay that way.
/// `guide_steps_test.dart` covers what happens to an id this build no longer
/// recognises: it is KEPT, not dropped.
library;

/// Which part of getting started a step belongs to.
enum StepCategory {
  /// Registering the business and protecting its name.
  legal('Legal', 'scale'),

  /// The Bureau of Internal Revenue.
  tax('Tax', 'document'),

  /// The city or municipality.
  lgu('Local government', 'building'),

  /// Only once somebody is hired.
  employer('Employer', 'people'),

  /// Selling software, taking payments, handling personal data.
  digital('Digital', 'laptop');

  const StepCategory(this.label, this.icon);

  /// What the filter chip says.
  final String label;

  /// The Salapify icon name, resolved by SalapifyIcon.
  final String icon;
}

/// How much choice somebody has about a step.
enum StepImportance {
  /// The law requires it.
  mandatory('Mandatory'),

  /// Worth doing, not required.
  recommended('Recommended'),

  /// Required only if the business does a particular thing.
  conditional('Only if it applies');

  const StepImportance(this.label);

  final String label;
}

/// One step, and the agency somebody has to deal with to finish it.
class BusinessStep {
  const BusinessStep({
    required this.id,
    required this.category,
    required this.title,
    required this.agency,
    required this.description,
    required this.importance,
  });

  /// STORED. See the library comment above before changing one of these.
  final String id;
  final StepCategory category;
  final String title;

  /// Who somebody actually has to go to. Kept as its own field rather than
  /// folded into the description, because it is the part people search for.
  final String agency;
  final String description;
  final StepImportance importance;
}

/// The checklist, in the prototype's order.
///
/// The order is not alphabetical and is not meant to be: it runs roughly in
/// the sequence somebody does them, which is why a filter chip narrows the
/// list rather than re-sorting it.
const List<BusinessStep> businessChecklist = <BusinessStep>[
  BusinessStep(
    id: 'chk_dti_sec',
    category: StepCategory.legal,
    title: 'Register Business Name & Entity',
    agency: 'DTI (Sole Prop) or SEC (Corp/OPC/Partnership)',
    description:
        'Secure DTI Business Name Registration Certificate or SEC Certificate '
        'of Incorporation/Partnership via eSPARC.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_trademark',
    category: StepCategory.legal,
    title: 'File Trademark Application for Brand & Logo',
    agency: 'IPOPHL (Bureau of Trademarks)',
    description:
        'Protect trade name and visual marks under RA 8293 first-to-file '
        'rule. DTI/SEC registration does not protect brand rights.',
    importance: StepImportance.recommended,
  ),
  BusinessStep(
    id: 'chk_brgy',
    category: StepCategory.lgu,
    title: 'Obtain Barangay Business Clearance',
    agency: 'Barangay Office of Location',
    description:
        'Required clearance from the specific barangay where the physical '
        'office, co-working space, or facility operates.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_locational',
    category: StepCategory.lgu,
    title: 'Secure Locational & Zoning Clearance',
    agency: 'City or Municipal Planning & Development Office',
    description:
        'Confirms that your commercial activity conforms to municipal zoning '
        'laws and land-use plans.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_fsic',
    category: StepCategory.lgu,
    title: 'Fire Safety Inspection Certificate (FSIC)',
    agency: 'Bureau of Fire Protection (BFP)',
    description:
        'Inspection proving compliance with the Fire Code of the Philippines '
        "prior to Mayor's Permit issuance.",
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_mayor_permit',
    category: StepCategory.lgu,
    title: "Obtain Mayor's Business Permit",
    agency: 'LGU Business Permit & Licensing Office (BPLO)',
    description:
        'The final local license allowing commercial operation within city or '
        'municipal boundaries.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_bir_cor',
    category: StepCategory.tax,
    title: 'Secure BIR Certificate of Registration (Form 2303)',
    agency: 'Bureau of Internal Revenue (RDO)',
    description:
        'Register via Form 1901 (Sole Prop) or Form 1903 (Corp/Partnership). '
        'Display publicly at place of business.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_books',
    category: StepCategory.tax,
    title: 'Register & Stamp Official Books of Accounts',
    agency: 'Bureau of Internal Revenue (RDO)',
    description:
        'Register manual, loose-leaf, or computerized journals and ledgers '
        '(Cash Receipts, Disbursements, General Journal, Ledger).',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_atp_invoice',
    category: StepCategory.tax,
    title: 'Authority to Print (ATP) Official Invoices',
    agency: 'Bureau of Internal Revenue (RDO)',
    description:
        'Print compliant sales invoices with an accredited printer under the '
        'Ease of Paying Taxes (EOPT) Act standards.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_sss',
    category: StepCategory.employer,
    title: 'Register as Employer with SSS',
    agency: 'Social Security System (SSS)',
    description:
        'Employer Form R-1 and Employee initial reporting Form R-1A. '
        'Mandatory even if employing only 1 staff member.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_philhealth',
    category: StepCategory.employer,
    title: 'Register Employer Account with PhilHealth',
    agency: 'Philippine Health Insurance Corporation',
    description:
        'Secure PhilHealth Employer Number (PEN) via Form ER1 and register '
        'enrolled staff.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_pagibig',
    category: StepCategory.employer,
    title: 'Register Employer Account with Pag-IBIG Fund',
    agency: 'Home Development Mutual Fund (HDMF)',
    description:
        'Secure Pag-IBIG Employer ID via Form HQP-PFF-002 for mandatory '
        'monthly housing fund remittances.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_dole',
    category: StepCategory.employer,
    title: 'File DOLE Rule 1020 Establishment Notice',
    agency: 'Department of Labor and Employment',
    description:
        'Mandatory registration of commercial establishment with DOLE '
        'Regional Office within 30 days of opening.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_npc',
    category: StepCategory.digital,
    title: 'National Privacy Commission (NPC) Compliance',
    agency: 'National Privacy Commission',
    description:
        'Appoint Data Protection Officer (DPO), draft Privacy Notice and '
        'Manual under RA 10173 (Data Privacy Act).',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_ntc',
    category: StepCategory.digital,
    title: 'NTC Value-Added Service (VAS) Provider License',
    agency: 'National Telecommunications Commission',
    description:
        'Required if offering messaging, VoIP, premium content, '
        'telecom-routed data, or wireless equipment services.',
    importance: StepImportance.conditional,
  ),
  BusinessStep(
    id: 'chk_ecommerce',
    category: StepCategory.digital,
    title: 'Internet Transactions Act (RA 11967) Trust Compliance',
    agency: 'DTI E-Commerce Bureau',
    description:
        'Post transparent merchant identity, terms of service, fair refund '
        'policies, and register with the online business registry.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_bsp_ops',
    category: StepCategory.digital,
    title: 'BSP Operator of Payment System (OPS) Registration',
    agency: 'Bangko Sentral ng Pilipinas',
    description:
        'Required if holding, routing, or processing electronic consumer '
        'payments, digital wallets, or payment gateways.',
    importance: StepImportance.conditional,
  ),
  BusinessStep(
    id: 'chk_duns',
    category: StepCategory.digital,
    title: 'Obtain Free D-U-N-S Number from Dun & Bradstreet',
    agency: 'Dun & Bradstreet / Apple D-U-N-S Lookup',
    description:
        'Required to enroll in the Apple Developer Program as an Organization '
        'and for Google Play enterprise verification using your '
        'SEC-registered company.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_apple_org',
    category: StepCategory.digital,
    title: 'Apple Developer Program (Organization Account)',
    agency: 'Apple Inc. (Apple Developer)',
    description:
        'Enables publishing under your corporate brand name instead of '
        'personal legal name, grants team seats, and qualifies for 15% Small '
        'Business Program.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_google_play',
    category: StepCategory.digital,
    title: 'Google Play Console Developer Account',
    agency: 'Google LLC (Play Console)',
    description:
        'Set up an Organization account (\$25 one-time) to bypass the '
        'mandatory 20-tester 14-day closed testing hurdle imposed on new '
        'personal accounts.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_mor_billing',
    category: StepCategory.digital,
    title: 'Merchant of Record (MoR) or Payment Gateway Setup',
    agency: 'Paddle / Lemon Squeezy / Stripe / PayMongo',
    description:
        'Integrate Lemon Squeezy or Paddle to automate global VAT/sales tax, '
        'or PayMongo for local Philippine GCash and Maya checkouts.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_account_delete',
    category: StepCategory.digital,
    title: 'In-App Account & Data Deletion Mechanism',
    agency: 'App Store Guideline 5.1.1(v) & RA 10173',
    description:
        'Mandatory for any mobile application with account creation: include '
        'an in-app button allowing users to initiate full account deletion.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_zero_vat_invoice',
    category: StepCategory.digital,
    title: 'BIR Zero-Rated Sales Invoice Setup for Global Remittances',
    agency: 'Bureau of Internal Revenue',
    description:
        'Create compliant sales invoice templates under the EOPT Act '
        'documenting inward USD wire transfers from Apple, Google, or MoRs '
        'under Section 108(B)(2).',
    importance: StepImportance.mandatory,
  ),
];

/// Every step id, for counting progress against the list as it stands today.
List<String> get businessChecklistIds => <String>[
  for (final BusinessStep s in businessChecklist) s.id,
];
