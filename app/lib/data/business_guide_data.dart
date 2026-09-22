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

// ===========================================================================
// THE ROADMAP: the order these things have to happen in.
// ===========================================================================
//
// Ported 2026-09-22 from the prototype's `roadmap` tab, which is hand written
// JSX rather than data, so the content was extracted into
// docs/migration/startup-guide-extract.md first and this file is built from
// that. The extraction is faithful; the CORRECTIONS below are not, and each
// one is named where it applies.
//
// Unlike the checklist, the order here is the point. Several steps will not
// accept you without the paper from an earlier one, which is why this is a
// sequence of phases rather than a second filterable list.

/// How a block of a phase should read.
enum BlockTone {
  /// Ordinary body copy.
  plain,

  /// Worth knowing, tinted in the accent.
  tip,

  /// A deadline or a penalty. Tinted in the warning colour.
  caution,
}

/// One block inside a phase: an optional heading, an optional paragraph, and
/// any number of bullets. Deliberately one shape rather than a hierarchy of
/// panels, cards, tiles and callouts: the prototype draws six different
/// containers that all say "here is a heading and some lines under it", and
/// porting the containers rather than the content would have carried a web
/// layout into a phone for no reader benefit.
class PhaseBlock {
  const PhaseBlock({
    this.heading,
    this.body,
    this.bullets = const <String>[],
    this.tone = BlockTone.plain,
  });

  final String? heading;
  final String? body;
  final List<String> bullets;
  final BlockTone tone;
}

/// One phase of getting registered.
class RoadmapPhase {
  const RoadmapPhase({
    required this.number,
    required this.kicker,
    required this.agency,
    required this.title,
    required this.blocks,
  });

  final int number;

  /// The small uppercase label, for instance "Initial Formation".
  final String kicker;

  /// Who this phase deals with.
  final String agency;
  final String title;
  final List<PhaseBlock> blocks;
}

const List<RoadmapPhase> businessRoadmap = <RoadmapPhase>[
  RoadmapPhase(
    number: 1,
    kicker: 'Initial Formation',
    agency: 'DTI or SEC',
    title: 'Register the name and the entity',
    blocks: <PhaseBlock>[
      PhaseBlock(
        heading: 'Sole proprietor: DTI BNRS',
        body:
            'Register your trade name at bnrs.dti.gov.ph and pick how wide a '
            'territory you want it protected in. Each fee adds a P30 '
            'documentary stamp.',
        bullets: <String>[
          'Barangay, P200',
          'City or municipality, P500',
          'Regional, P1,000',
          'National, P2,000',
        ],
      ),
      PhaseBlock(
        heading: 'Corporation, OPC or partnership: SEC eSPARC',
        body:
            'File online at esparc.sec.gov.ph. Fees are based on your '
            'authorised capital stock.',
        bullets: <String>[
          'Name verification slip',
          "Articles of Incorporation and By-Laws, or OPC Articles",
          "Treasurer's Affidavit",
          'Nominee and Alternate Nominee acceptance, OPC only',
        ],
      ),
      PhaseBlock(
        tone: BlockTone.caution,
        heading: 'A DTI or SEC name is not a trademark',
        body:
            'Registering the business name does not give you ownership of the '
            'brand or the logo. Somebody else can still register your name '
            'with IPOPHL if you have not. A DTI certificate also does not let '
            'you trade on its own: the LGU and BIR steps are still required.',
      ),
    ],
  ),
  RoadmapPhase(
    number: 2,
    kicker: 'Intellectual property',
    agency: 'IPOPHL',
    title: 'Protect the brand',
    blocks: <PhaseBlock>[
      PhaseBlock(
        body:
            'Under RA 8293 trademarks go to whoever FILES first, not whoever '
            'used the name first in business.',
      ),
      PhaseBlock(
        heading: 'Search first',
        body:
            'Check IPOPHL e-Search and the WIPO Global Brand Database, and '
            'work out your Nice classes. Class 9 covers software, 35 retail, '
            '42 SaaS.',
      ),
      PhaseBlock(
        heading: 'File and wait',
        body:
            'Apply through IPOPHL eTMfile. Examination takes three to six '
            'months, then it is published for a 30 day opposition period.',
      ),
      PhaseBlock(
        heading: 'Registration and the DAU',
        // The prototype said "within 3 years and 5 years", which the review
        // flagged as ambiguous: it reads as one deadline spanning both, or as
        // two filings, and elsewhere the same component named only the three
        // year one. Neither reviewer could open the rule, so this names the
        // first deadline (which is the one that cancels a mark if missed) and
        // says there are more, rather than printing a number nobody checked.
        body:
            'The certificate runs ten years. You must file a Declaration of '
            'Actual Use with proof you are really using the mark, the first '
            'within three years of filing, and again later to keep it. Miss '
            'the first and the mark is cancelled.',
      ),
      PhaseBlock(
        tone: BlockTone.tip,
        heading: 'File before you launch',
        body:
            'If you are building an app or a consumer brand, file on day one. '
            'Somebody watching your early traction can register your name and '
            'leave you rebranding or buying it back.',
      ),
    ],
  ),
  RoadmapPhase(
    number: 3,
    kicker: 'Local government',
    agency: 'Barangay and City Hall',
    title: "Clearances and the Mayor's Permit",
    blocks: <PhaseBlock>[
      PhaseBlock(
        body:
            "You cannot legally operate without a Mayor's Permit from the "
            'city or municipality your business address is in, including a '
            'home address.',
      ),
      PhaseBlock(
        heading: 'A. Barangay business clearance',
        body:
            'From the barangay hall of your address. Bring your DTI or SEC '
            'certificate, your lease, and proof of address. Roughly P300 to '
            'P1,500.',
      ),
      PhaseBlock(
        heading: 'B. Locational or zoning clearance',
        body:
            'Confirms your activity is allowed where you are. A purely '
            'residential zone may not permit customers coming to the address.',
      ),
      PhaseBlock(
        heading: 'C. Fire safety and sanitary',
        body:
            'The Bureau of Fire Protection checks extinguishers, exits and '
            'wiring. The health office issues sanitary permits and staff '
            'health cards.',
      ),
      PhaseBlock(
        heading: 'D. BPLO assessment',
        body:
            'Hand in every clearance. The Business Permit and Licensing '
            "Office works out your local business tax, then releases the "
            'permit and your business plate.',
      ),
      PhaseBlock(
        tone: BlockTone.caution,
        heading: 'Renew every January',
        body:
            'Between 1 and 20 January. After that it is a 25% surcharge plus '
            '2% a month.',
      ),
    ],
  ),
  RoadmapPhase(
    number: 4,
    kicker: 'National taxation',
    agency: 'BIR',
    title: 'Registration, books and invoices',
    blocks: <PhaseBlock>[
      PhaseBlock(
        tone: BlockTone.tip,
        heading: 'What the Ease of Paying Taxes Act changed',
        bullets: <String>[
          'The P500 annual registration fee is gone for good.',
          'The Invoice is now the main document for goods AND services. '
              'Official Receipts are supplementary.',
          // CORRECTED. The prototype said you can now "register and file at
          // any authorised RDO". Only the FILING half is true: the wrong
          // venue surcharge was deleted. Registration still goes to the RDO
          // covering your address, online through ORUS.
          'You can file and pay anywhere with no wrong venue penalty. '
              'Registering still goes to the RDO for your address.',
        ],
      ),
      PhaseBlock(
        heading: 'The form you file',
        bullets: <String>[
          'Form 1901 for a sole proprietor or professional',
          'Form 1903 for a corporation or partnership',
        ],
      ),
      PhaseBlock(
        heading: 'Form 2303, your Certificate of Registration',
        body:
            'It lists every return you are now required to file, for example '
            '2551Q percentage tax or 2550Q VAT, 1701Q or 1702Q income tax, '
            'and 1601C withholding on wages.',
      ),
      PhaseBlock(
        heading: 'Books of accounts',
        body: 'Every business registers its official books before using them.',
        bullets: <String>[
          'General Journal',
          'General Ledger',
          'Cash Receipts',
          'Cash Disbursements',
        ],
      ),
      PhaseBlock(
        // CORRECTED. The prototype offered "Permit to Use (PTU) or
        // Computerized Accounting System (CAS)" as if they were two
        // alternatives. They are not: CAS is the system, and the paper it
        // needs stopped being a PTU in 2021. A point of sale or cash register
        // machine is the thing that still takes a Permit to Use.
        heading: 'Printing invoices',
        body:
            'File Form 1906 for an Authority to Print and use a BIR '
            'accredited printer. A computerised accounting system needs its '
            'own clearance instead, and a point of sale machine needs a '
            'Permit to Use.',
      ),
    ],
  ),
  RoadmapPhase(
    number: 5,
    kicker: 'Hiring anyone',
    agency: 'SSS, PhilHealth, Pag-IBIG, DOLE',
    title: 'Employer registrations',
    blocks: <PhaseBlock>[
      PhaseBlock(
        body:
            'The moment you hire your first employee you are an employer in '
            'law, and all four of these apply.',
      ),
      PhaseBlock(
        heading: 'SSS',
        body:
            'Form R-1 to register as an employer and R-1A to report who you '
            'have hired. Covers retirement, sickness, maternity, disability '
            'and death benefits.',
      ),
      PhaseBlock(
        heading: 'PhilHealth',
        body:
            'Form ER1 gets your Employer Number. Report staff separately with '
            'ER2 or a PMRF each, then remit monthly.',
      ),
      PhaseBlock(
        heading: 'Pag-IBIG',
        body:
            'Form HQP-PFF-002. Gives employees the housing loan facility and '
            'the savings fund.',
      ),
      PhaseBlock(
        // THE SAME INVERSION the checklist carried, and it is corrected the
        // same way. The prototype said "within 30 days of commercial
        // operations". Rule 1020 says thirty days BEFORE operating.
        tone: BlockTone.caution,
        heading: 'DOLE Rule 1020',
        body:
            'File the establishment notice with your DOLE Regional Office '
            'BEFORE you start operating, within the 30 days beforehand. It is '
            'free, and it is a workplace safety requirement rather than a tax '
            'one.',
      ),
    ],
  ),
  RoadmapPhase(
    number: 6,
    kicker: 'Digital and online',
    agency: 'NPC, NTC, DTI, BSP',
    title: 'If you sell software or sell online',
    blocks: <PhaseBlock>[
      PhaseBlock(
        body:
            'Apps, websites, SaaS and online shops pick up a second set of '
            'requirements on top of everything above.',
      ),
      PhaseBlock(
        tone: BlockTone.caution,
        heading: 'Data privacy, RA 10173',
        body:
            'Applies the moment you collect emails, passwords, phone numbers, '
            'addresses or financial records.',
        bullets: <String>[
          'Name a Data Protection Officer.',
          'Publish a clear privacy notice, and ask for consent where you '
              'need it.',
          'Register with the NPC only above the thresholds, for example '
              'sensitive data on 1,000 people or 250 staff.',
          'Report a data breach to the NPC within 72 hours.',
        ],
      ),
      PhaseBlock(
        heading: 'Telecoms, NTC',
        body:
            'Messaging, SMS gateways, VoIP, premium content or anything '
            'routed through a telecom needs an NTC Certificate of '
            'Registration before you go live.',
      ),
      PhaseBlock(
        // CORRECTED, and this is the claim with the shortest shelf life on
        // the screen. The prototype said registration with the online
        // business registry "is mandated". The E-Commerce Philippine
        // Trustmark was voluntary in July 2025, mandatory that September,
        // reverted weeks later, and DTI has extended the voluntary phase to
        // the end of 2026. The Act's own duties are live; registering is not.
        heading: 'Selling online, RA 11967',
        body:
            'The Internet Transactions Act has been enforceable since 20 June '
            '2025.',
        bullets: <String>[
          'Show your registered business name, your DTI or SEC number, your '
              'address and a real way to contact you.',
          'A platform shares liability with a merchant if it knowingly '
              'allows illegal or counterfeit goods.',
          'The DTI Trustmark is separate and stays voluntary until the end '
              'of 2026.',
        ],
      ),
      PhaseBlock(
        heading: 'If you touch money, lending or health',
        bullets: <String>[
          'Payments: BSP Operator of Payment System registration for '
              'aggregators, escrow wallets and remitters.',
          'Lending or buy now pay later: an SEC Certificate of Authority, '
              'and it is strictly enforced.',
          'Cosmetics or anything ingestible: an FDA Licence to Operate and '
              'product registration before you list it.',
        ],
      ),
    ],
  ),
];

// ===========================================================================
// WHICH STRUCTURE: the comparison, and the three question matcher.
// ===========================================================================

/// What an attribute row is saying about an entity, so the screen can colour
/// it. The prototype colours these and the colour carries meaning: red on
/// "unlimited liability" is the single most consequential word on the screen.
enum EntityTone { plain, good, bad, warn, muted }

/// One label and value on a comparison card.
typedef EntityRow = (String label, String value, EntityTone tone);

/// One way of structuring a business.
class EntityCard {
  const EntityCard({
    required this.title,
    required this.registrar,
    required this.description,
    required this.rows,
  });

  final String title;

  /// "Registered via DTI" or "Registered via SEC".
  final String registrar;
  final String description;
  final List<EntityRow> rows;
}

const List<EntityCard> businessEntities = <EntityCard>[
  EntityCard(
    title: 'Sole Proprietorship',
    registrar: 'Registered via DTI',
    description:
        'Owned entirely by one person. You and the business are the same '
        'legal person.',
    rows: <EntityRow>[
      ('Liability', 'Unlimited, your own assets are at risk', EntityTone.bad),
      ('Capital needed', 'No minimum', EntityTone.plain),
      // "Pass-through (8% flat or graduated)" in the prototype. "Flat" is the
      // wrong word for an election you have to make on time and cannot undo.
      ('Tax', '8% option or the graduated rates', EntityTone.plain),
      ('Setup', 'Fastest, one to three days at DTI', EntityTone.plain),
      ('Investors', 'Cannot sell shares', EntityTone.muted),
    ],
  ),
  EntityCard(
    title: 'One Person Corporation (OPC)',
    registrar: 'Registered via SEC',
    description:
        'Created under RA 11232 for solo founders who want limited liability '
        'without needing a board.',
    rows: <EntityRow>[
      ('Liability', 'Limited to what the company owns', EntityTone.good),
      ('Officers needed', 'Nominee and Alternate Nominee', EntityTone.plain),
      // CORRECTED. The prototype gave "20%/25%" here and never said what
      // picks between them, while the corporation card two cards down gave
      // one of the two conditions. Both cards now carry the same full test.
      (
        'Tax',
        '20% if income is 5M or less AND assets 100M or less, else 25%',
        EntityTone.plain,
      ),
      ('Governance', 'No board or by-laws required', EntityTone.plain),
      ('Investors', 'Must convert to add owners', EntityTone.plain),
    ],
  ),
  EntityCard(
    title: 'Regular Stock Corporation',
    registrar: 'Registered via SEC',
    description:
        'Two to fifteen incorporators, issuing shares, run by an elected '
        'board.',
    rows: <EntityRow>[
      ('Liability', 'Limited to subscribed capital', EntityTone.good),
      ('Governance', 'Board, President, CorpSec, Treasurer', EntityTone.plain),
      // CORRECTED. The prototype gave only the 5M income test. The asset test
      // is conjunctive and the land exclusion is in the statute, so a company
      // that owns its office is not knocked out of the lower rate by it.
      (
        'Tax',
        '20% if income is 5M or less AND assets 100M or less, '
            'not counting the land, else 25%',
        EntityTone.plain,
      ),
      ('Reporting', 'Annual GIS and audited statements', EntityTone.plain),
      ('Investors', 'Highest, what angels and VCs expect', EntityTone.good),
    ],
  ),
  EntityCard(
    title: 'Partnership',
    registrar: 'Registered via SEC',
    description:
        'Two or more people putting in money, property or work toward a '
        'common fund, and splitting the profit.',
    rows: <EntityRow>[
      ('Liability', 'Joint and several for general partners', EntityTone.warn),
      ('Formation', 'Articles of Partnership', EntityTone.plain),
      (
        'Professional partnership',
        'The firm is exempt, the partners are taxed',
        EntityTone.plain,
      ),
      ('Commercial partnership', 'Taxed like a corporation', EntityTone.plain),
      ('Continuity', 'Dissolves if a partner dies or leaves', EntityTone.muted),
    ],
  ),
];

/// One question in the matcher.
class EntityQuestion {
  const EntityQuestion({
    required this.key,
    required this.label,
    required this.options,
  });

  /// `owners`, `liability` or `funding`.
  final String key;
  final String label;

  /// Each option is what it says and what it sets.
  final List<(String label, String value)> options;
}

/// THREE questions, not four.
///
/// The prototype's state carries a fourth key, `compliance`, which no control
/// ever sets and the recommendation never reads. It is dead, so it is not
/// ported: carrying a question across that answers nothing would be inventing
/// a step for somebody to fill in.
const List<EntityQuestion> entityQuestions = <EntityQuestion>[
  EntityQuestion(
    key: 'owners',
    label: 'How many of you are starting this?',
    options: <(String, String)>[
      ('Just me', 'single'),
      ('Two or more of us', 'multiple'),
    ],
  ),
  EntityQuestion(
    key: 'liability',
    label: 'If the business owed money it could not pay, what then?',
    options: <(String, String)>[
      ('My own house and savings must be safe', 'protected'),
      ('Low risk business, keep it simple', 'low_risk'),
    ],
  ),
  EntityQuestion(
    key: 'funding',
    label: 'Will you raise money from outside investors?',
    options: <(String, String)>[
      ('Yes, I will issue shares', 'investors'),
      ('No, my own money or what customers pay', 'bootstrapped'),
    ],
  ),
];

/// What the matcher recommends.
class EntityMatch {
  const EntityMatch({
    required this.title,
    required this.summary,
    required this.reasons,
  });

  final String title;
  final String summary;
  final List<String> reasons;
}

/// The prototype's own decision tree, branch for branch.
///
/// Four reachable outcomes and one null guard, and the null guard matters:
/// with question one unanswered there is no recommendation at all, rather
/// than a default that somebody might act on.
///
/// The two fallback branches are reachable with questions two and three left
/// blank, which is the prototype's behaviour and is kept. It is defensible:
/// somebody who has said "just me" and answered nothing else is being shown
/// the simplest structure, which is the right default to show and the wrong
/// one to hide.
EntityMatch? matchEntity({String? owners, String? liability, String? funding}) {
  if (owners == null || owners.isEmpty) return null;

  final bool wantsShield = liability == 'protected';
  final bool wantsInvestors = funding == 'investors';

  if (owners == 'single') {
    if (wantsShield || wantsInvestors) {
      return const EntityMatch(
        title: 'One Person Corporation (OPC)',
        summary:
            'For a solo founder who wants to stay in sole control but keep '
            'their own assets out of reach of business debts.',
        reasons: <String>[
          'Only one stockholder needed, under RA 11232.',
          'Your home and family savings are shielded from company debt.',
          'No minimum capital, unless you are in a regulated industry.',
          'You must name a Nominee and an Alternate Nominee.',
        ],
      );
    }
    return const EntityMatch(
      title: 'Sole Proprietorship',
      summary:
          'For a freelancer, a home based trader or a small shop that wants '
          'to be registered quickly and cheaply.',
      reasons: <String>[
        'Registered at DTI, with no bylaws or board meetings.',
        'Cheapest to form, P200 to P2,000 at DTI plus the documentary stamp.',
        // THE MOST EXPENSIVE CORRECTION IN THIS PORT.
        //
        // The prototype said "eligible for simplified 8% gross income tax
        // under TRAIN law if revenue is under P3M". Three things wrong, and
        // the first costs money.
        //
        // The 8% is on GROSS SALES, not gross income. Gross income in the Tax
        // Code is sales less cost of sales, so a reader applying 8% the way
        // that sentence describes underpays, and on 2,000,000 of sales with
        // 1,200,000 of costs the gap is roughly 96,000 plus surcharge and
        // interest.
        //
        // It also omitted that you must be non-VAT to elect it, and that the
        // election has a deadline and cannot be undone for the year. A missed
        // deadline is as expensive as a wrong rate.
        'If you are non-VAT and sales are 3M or less you may elect 8% on '
            'gross sales above 250,000, instead of the graduated rates and '
            'percentage tax. Elect it on your first quarter return; it is '
            'locked for the year.',
        'The trade off: unlimited personal liability for business debts.',
      ],
    );
  }

  if (wantsInvestors || wantsShield) {
    return const EntityMatch(
      title: 'Regular Stock Corporation',
      summary:
          'The usual choice for a startup with several founders that plans to '
          'raise money.',
      reasons: <String>[
        'Two to fifteen incorporators under the Revised Corporation Code.',
        'Can issue different classes of share to angels and funds.',
        'Limited liability for every shareholder, up to what they subscribed.',
        'Corporate income tax of 20% where taxable income is 5M or less and '
            'assets are 100M or less, otherwise 25%.',
      ],
    );
  }

  return const EntityMatch(
    title: 'General or Limited Partnership',
    summary:
        'For two or more professionals, consultants or designers running '
        'something together under an agreement.',
    reasons: <String>[
      'Registered with SEC through Articles of Partnership.',
      'The agreement sets out how profit and loss are split.',
      'The trade off: in a general partnership each partner is personally '
          'liable for the whole debt.',
    ],
  );
}

// ===========================================================================
// THE TRAPS: what people get wrong, from the prototype's Experts tab.
// ===========================================================================
//
// Ported 2026-09-22. The prototype's tab bar calls this "Expert Pitfalls &
// Q&A" and there are no questions, no answers and no tips anywhere in it,
// only six warnings. The name is not ported with the emptiness: this is
// called Traps, which is what it contains.
//
// Five of the six needed a correction, and they are the reason the factual
// review ran before this tab was built rather than after.

/// One thing people get wrong, and what it costs.
class StartupTrap {
  const StartupTrap({
    required this.expert,
    required this.title,
    required this.body,
  });

  /// Whose warning it is, as a small kicker.
  final String expert;
  final String title;
  final String body;
}

const List<StartupTrap> startupTraps = <StartupTrap>[
  StartupTrap(
    expert: 'BIR compliance',
    title: 'Thinking a DTI registration is enough to start selling',
    // CORRECTED, and the numbers were wrong in both directions.
    //
    // The prototype said "heavy fines (P10,000 to P50,000+)". Section 258 is
    // a fine of 5,000 to 20,000 plus six months to two years. The 30,000 to
    // 50,000 band in that section exists, but it applies to businesses
    // distilling, rectifying, repacking, compounding or manufacturing
    // articles subject to excise tax, which no reader of this app is. So the
    // prototype took a band that does not apply and raised the floor as well.
    //
    // It also merged two offences under one citation: not issuing an invoice
    // is Section 264, not 258. Verified against the Tax Code text here, not
    // taken on a reviewer's word, because a penalty figure is exactly the
    // sort of number somebody repeats to a business partner.
    body:
        'Plenty of people register with DTI, open a shop and start trading '
        'without ever going to the BIR. Trading without a Certificate of '
        'Registration is a criminal offence under Section 258: a fine of '
        '5,000 to 20,000 and six months to two years. Not issuing an invoice '
        'is a separate offence under Section 264. The BIR can also close the '
        'business under Oplan Kandado.',
  ),
  StartupTrap(
    expert: 'CPA and tax accountant',
    title: 'Forgetting to file zero-income returns',
    // The substance survived the review. What is added is the 8% point: an
    // elector no longer files 2551Q at all, so "the returns on your 2303" is
    // not a fixed list and somebody filing a return they do not owe is as
    // confused as somebody missing one.
    body:
        'Once you are registered you must file every return listed on your '
        'Form 2303, even in a quarter where you earned nothing. A nil return '
        'is free. Not filing one is a compromise penalty from 1,000 per '
        'return, and they stack quietly into open cases. The list is not '
        'fixed: electing the 8% means you stop filing percentage tax '
        'returns.',
  ),
  StartupTrap(
    expert: 'E-commerce',
    title: 'The withholding tax on marketplace sellers',
    // The mechanic survived, and the review confirmed the arithmetic the
    // extraction had flagged as looking self-contradictory: 1% of one half
    // really is how RR 16-2023 is drafted, and it really is 0.5% of gross.
    //
    // Two changes. The e-wallets are no longer named, because whether a given
    // wallet is acting as a covered operator depends on the transaction, and
    // the marketplaces are not in doubt. And the last sentence is new: people
    // routinely read a creditable withholding as money burned.
    body:
        'Marketplace operators like Shopee, Lazada and TikTok Shop withhold '
        '1% on half of what they remit you, so 0.5% of the gross, once your '
        'remittances pass 500,000 in a year. It is CREDITABLE against your '
        'income tax rather than an extra tax, so claim it. You also have to '
        'be BIR-registered to keep selling on them.',
  ),
  StartupTrap(
    expert: 'Legal and IP',
    title: 'Missing the three year Declaration of Actual Use',
    body:
        'Filing the trademark application is only the start. You must file a '
        'Declaration of Actual Use with real proof you are using the mark, '
        'receipts, website screenshots, product photos, within three years of '
        'filing. Miss it and the mark is refused or cancelled automatically.',
  ),
  StartupTrap(
    expert: 'App stores',
    title: 'Assuming you can bill however you like inside an app',
    // CORRECTED. The prototype said linking to an external web checkout
    // "will cause an immediate rejection", full stop. That was true when it
    // was written and is no longer true everywhere: a US court injunction in
    // 2025 changed what Apple permits on the US storefront, and Google began
    // opening billing choice in 2026, starting with the US, EEA and UK.
    //
    // The correction is deliberately NOT a list of which storefront allows
    // what this month, because that list would be wrong again by the time
    // anybody reads it. It says the rule is the platform's, varies by
    // country, and is the thing to check. Naming the account deletion
    // requirement stays, and Google's web link half is added.
    body:
        'Selling digital things inside an iOS or Android app usually means '
        "using the store's own billing, not your own checkout. What is "
        'allowed has been moving and differs by country, so check the current '
        'rule for your storefront rather than assuming. Separately, if your '
        'app lets people create an account, Apple requires in-app deletion '
        'and Google also wants a web link that works without reinstalling.',
  ),
  StartupTrap(
    expert: 'SaaS and tax',
    title: 'The global sales tax trap',
    // CORRECTED, and it is the same defect as the checklist's zero-rated
    // invoice step: the prototype promised "one clean, zero-rated B2B invoice
    // per month" with no mention that zero rating needs VAT registration. A
    // bootstrapped Philippine company under the threshold is non-VAT, issues
    // an ordinary invoice, and still owes percentage tax on those receipts.
    //
    // Lemon Squeezy is also no longer named. It was acquired in 2024 and is
    // migrating into its acquirer's own product, so pointing a beginner at it
    // by name is pointing them at something mid-move.
    body:
        'Selling SaaS to customers in Europe, the UK or the US with a plain '
        'payment gateway makes your Philippine company responsible for '
        'registering and remitting sales tax across dozens of places. A '
        'merchant of record takes that on instead and bills you once. Just '
        'note that a single invoice is not a zero-rated one unless you are '
        'VAT-registered, and it is never tax free.',
  ),
];
