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
    // "via eSPARC" sat at the end of a sentence covering BOTH routes, so it
    // read as covering both. It does not: eSPARC is the SEC's portal, and a
    // sole proprietor registers a business name with DTI through BNRS. The
    // most common reader of this app is a sole proprietor, so the one portal
    // named was the one they do not use.
    description:
        'Sole proprietor: register your business name with DTI through BNRS. '
        'Corporation, OPC or partnership: register with SEC through eSPARC.',
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
        // "or home address" added on the review. There is no size-based
        // exemption from LGU permitting, so a home-based freelancer or online
        // seller needs this at their home address, and the old wording
        // (office, co-working space, facility) read as though it did not
        // reach them.
        'Required clearance from the specific barangay where the business '
        'operates, including a home address.',
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
    // "Display publicly at place of business" was the prototype's ending, and
    // it is replaced rather than merely dropped, on the 2026-09-22 factual
    // review. Two reasons, and the second is the one that matters.
    //
    // Whether the EOPT Act removed the duty to DISPLAY the certificate could
    // not be settled: the reviewing tax professional says RR 7-2024 removed
    // it, an independent search returned several sources still saying it must
    // be posted, and neither could be confirmed against the regulation text
    // from here. So the sentence no longer asserts either position.
    //
    // What IS settled, and was missing, is the NIRI. The Notice to Issue
    // Receipt/Invoice replaced the old "Ask for Receipt" notice and must be
    // displayed by every registered business, online sellers included. That
    // omission carried real exposure where the display question does not: a
    // reader who posts their certificate unnecessarily loses nothing, and a
    // reader who never heard of the NIRI is missing a required notice.
    description:
        'Register via Form 1901 (Sole Prop) or Form 1903 (Corp/Partnership). '
        'Post the Notice to Issue Receipt/Invoice (NIRI) where customers can '
        'see it.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_books',
    category: StepCategory.tax,
    // "Stamp" dropped from the title on the 2026-09-22 review. Registering
    // books of accounts is beyond doubt and stays; the physical RDO stamp is
    // no longer the defining act now that registration runs through ORUS,
    // which issues a QR confirmation instead. Some RDOs still stamp, so the
    // word was not false everywhere, and that is exactly why it was worth
    // removing rather than reversing: dropping it is correct whether or not
    // your RDO still reaches for the stamp, where keeping it sends somebody
    // queueing for a counter they may not need.
    title: 'Register Official Books of Accounts',
    agency: 'Bureau of Internal Revenue (RDO)',
    description:
        'Register manual, loose-leaf, or computerized journals and ledgers '
        '(Cash Receipts, Disbursements, General Journal, Ledger).',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_atp_invoice',
    category: StepCategory.tax,
    // "Official Invoices" was a term collision and is gone. Under the EOPT
    // Act the INVOICE is the principal document for both goods and services
    // and the Official Receipt was demoted to a supplementary one, so
    // "Official Invoice" names a document that does not exist.
    //
    // The Authority to Print itself SURVIVES, which is worth recording
    // because it was doubted during this review and the doubt was wrong. The
    // EOPT Act removed the FEE for securing an ATP, not the authority.
    title: 'Authority to Print (ATP) Sales Invoices',
    agency: 'Bureau of Internal Revenue (RDO)',
    description:
        'File Form 1906 and print with a BIR-accredited printer. Issuing from '
        'a point of sale or accounting system instead needs that system '
        'permitted, not an ATP.',
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
        // ER1 gets the employer number; staff are reported on ER2 or a PMRF
        // each. The old sentence put both under the ER1 heading.
        'Secure your PhilHealth Employer Number (PEN) with Form ER1, then '
        'report staff with ER2 or a PMRF each.',
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
    // THE WORST DEFECT THE 2026-09-22 REVIEW FOUND, and the only one where
    // following the app put somebody past a deadline they could no longer
    // meet.
    //
    // The prototype said "within 30 days of opening". Rule 1020 says new
    // establishments register within thirty days BEFORE operation. The
    // sentence was not stale, it was INVERTED: it told a reader they had a
    // month of grace after opening, when the duty had already matured before
    // their first day of trading. Confirmed independently against the OSHS
    // text, not taken on one reviewer's word.
    description:
        'Register the workplace with the DOLE Regional Office BEFORE you '
        'start operating, within the 30 days beforehand. Rule 1020, now under '
        'DO 252-25.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_npc',
    category: StepCategory.digital,
    title: 'National Privacy Commission (NPC) Compliance',
    agency: 'National Privacy Commission',
    description:
        // The DPO really is mandatory for everyone, with no size threshold,
        // and that part survived the review. What was MISSING is that
        // REGISTERING with the NPC is threshold based, and a reader who
        // assumed the two went together would either register needlessly or,
        // worse, assume neither applied to a business their size.
        'Name a Data Protection Officer and publish their contact details, '
        'and write a Privacy Notice and Manual. Registering with the NPC is '
        'only required above set thresholds, such as 250 staff.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_ntc',
    category: StepCategory.digital,
    // NTC issues a Certificate of Registration, not a licence, and the
    // difference is not pedantry: somebody searching for a "VAS licence"
    // finds the wrong pages, and a licence implies a franchise, which a VAS
    // provider does not need unless it builds its own network.
    title: 'NTC Value-Added Service (VAS) Certificate of Registration',
    agency: 'National Telecommunications Commission',
    description:
        'Only if you offer messaging, VoIP, premium content or telecom-routed '
        'data. The certificate runs five years.',
    importance: StepImportance.conditional,
  ),
  BusinessStep(
    id: 'chk_ecommerce',
    category: StepCategory.digital,
    title: 'Internet Transactions Act (RA 11967) Trust Compliance',
    agency: 'DTI E-Commerce Bureau',
    description:
        // TWO obligations that are NOT the same, and the prototype ran them
        // together as one mandatory instruction.
        //
        // The Act's own duties (transparency, terms, refunds) are live and
        // mandatory: the 18 month transitory period ended on 20 June 2025.
        // REGISTERING is a different thing, and it is the claim with the
        // shortest shelf life on this whole screen. The E-Commerce Philippine
        // Trustmark was voluntary in July 2025, made mandatory that
        // September, reverted weeks later after sellers objected, and DTI has
        // extended the voluntary phase to 31 December 2026 with a review at
        // the end of it.
        //
        // An earlier draft of THIS correction said "file your details with
        // the DTI E-Commerce Bureau" inside a step marked Mandatory, which
        // would have told every online seller to register for something that
        // is optional. Caught by a second reviewer before it shipped.
        'Its rules have been enforceable since 20 June 2025: show who you '
        'are, your terms and your refund policy. The DTI Trustmark is '
        'separate and stays voluntary until the end of 2026.',
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
    // Conditional, not mandatory. It is needed to publish under a COMPANY
    // name; a solo developer on an individual account never needs one, and
    // the description says so while the old chip said "Mandatory" over the
    // top of it.
    importance: StepImportance.conditional,
  ),
  BusinessStep(
    id: 'chk_apple_org',
    category: StepCategory.digital,
    title: 'Apple Developer Program (Organization Account)',
    agency: 'Apple Inc. (Apple Developer)',
    // The 15% line was a NON SEQUITUR and is corrected rather than dropped,
    // because the programme is real and worth knowing about. Eligibility for
    // the Small Business Program turns on PROCEEDS, under a million US
    // dollars a year, and an individual account qualifies on exactly the same
    // test. The old sentence told a solo developer that going Organization
    // was how they got 15%, which cost them a D-U-N-S number and weeks of
    // lead time for a benefit they already had.
    description:
        'Optional: it lets you publish under the company name rather than '
        'your own, and adds team seats. The 15% Small Business Program is '
        'separate, and any developer under \$1M a year can apply.',
    importance: StepImportance.conditional,
  ),
  BusinessStep(
    id: 'chk_google_play',
    category: StepCategory.digital,
    title: 'Google Play Console Developer Account',
    agency: 'Google LLC (Play Console)',
    // TWENTY became TWELVE in December 2024, when Google cut the minimum
    // after individual developers could not find enough testers. The 14 days
    // did not change. Verified independently, not taken on one report.
    //
    // The organisation exemption is real and survives the review, but it is
    // no longer sold as a $25 shortcut: an organisation account needs a
    // D-U-N-S number, which Google itself warns can take 30 days or more, so
    // presenting it as the cheap way round a 14 day wait had the lead times
    // backwards.
    description:
        'A Play Console account costs \$25 once. New personal accounts must '
        'run a closed test with 12 testers for 14 straight days before going '
        'live. Organization accounts skip that, but need a D-U-N-S number '
        'first, which can take weeks.',
    importance: StepImportance.mandatory,
  ),
  BusinessStep(
    id: 'chk_mor_billing',
    category: StepCategory.digital,
    // Rewritten on the 2026-09-22 review, and it was the step most likely to
    // get somebody's app REJECTED.
    //
    // It sat two rows below "set up your Apple and Google accounts" and read,
    // in sequence, as "and to take payments in your app, integrate Paddle".
    // Selling digital goods inside an iOS or Android app still generally
    // requires the platform's own billing. The exceptions are narrow and
    // regional and a Philippine storefront is in none of them by default.
    //
    // Two smaller faults went with it. The `agency` field is documented above
    // as who you actually have to go to, and every other step puts a
    // government body there; four private vendors in that slot borrow the
    // authority of the format. And the copy used the imperative, naming two
    // products, one of which (Lemon Squeezy) was acquired by Stripe in 2024
    // and is mid-migration into Stripe's own product.
    title: 'Merchant of Record (MoR) or Payment Gateway Setup',
    agency: 'Merchant of record or payment gateway',
    description:
        'Selling from your own website? A merchant of record (for example '
        'Paddle) handles global VAT, and a local gateway (for example '
        'PayMongo) handles GCash and Maya. Selling INSIDE an iOS or Android '
        'app usually means the store\'s own billing instead.',
    importance: StepImportance.conditional,
  ),
  BusinessStep(
    id: 'chk_account_delete',
    category: StepCategory.digital,
    title: 'In-App Account & Data Deletion Mechanism',
    agency: 'App Store Guideline 5.1.1(v), Play User data policy, RA 10173',
    // Google was MISSING, and naming only Apple left a developer thinking one
    // in-app button was enough. Play requires that AND a web link somebody
    // can use without reinstalling the app and signing back in.
    //
    // Conditional, not mandatory, because the sentence already said "with
    // account creation" while the chip over it said Mandatory. Salapify
    // itself has no accounts, so the founder reading their own checklist was
    // being told to build something their app does not need.
    description:
        'Only if people can create an account. Both stores then require an '
        'in-app way to delete it, and Play also wants a web link that works '
        'without reinstalling.',
    importance: StepImportance.conditional,
  ),
  BusinessStep(
    id: 'chk_zero_vat_invoice',
    category: StepCategory.digital,
    // THE MOST CONSEQUENTIAL CORRECTION of the 2026-09-22 factual review, and
    // the only one where the prototype's version could have cost a reader
    // money rather than a wasted trip.
    //
    // Zero rating under Section 108(B)(2) is available to a VAT-REGISTERED
    // seller. Somebody under the 3,000,000 threshold who never registered for
    // VAT has no output VAT and therefore no zero-rated sale at all: they
    // issue an ordinary invoice. Marking this step Mandatory pointed every
    // such reader at a document they cannot lawfully issue.
    //
    // Worse, it implied their income from abroad was untaxed. It is not.
    // Zero-rated for VAT is not tax free, and a non-VAT person still owes
    // percentage tax on those receipts. A reader who followed the old wording
    // and filed nothing would have an open case, which is why the sentence
    // now says so out loud rather than leaving it to be inferred.
    //
    // The citation itself was right and is kept.
    title: 'Zero-Rated Invoice for Income from Abroad',
    agency: 'Bureau of Internal Revenue',
    description:
        'Only if you are VAT-registered: services to a customer outside the '
        'Philippines, paid in foreign currency through the banking system, '
        'can be zero-rated under Section 108(B)(2). If you are not VAT-'
        'registered, issue an ordinary invoice. Either way this income is not '
        'tax free.',
    importance: StepImportance.conditional,
  ),
];

/// Every step id, for counting progress against the list as it stands today.
List<String> get businessChecklistIds => <String>[
  for (final BusinessStep s in businessChecklist) s.id,
];
