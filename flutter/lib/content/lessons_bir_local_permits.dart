// Money Courses Phase 14: "Build Your Business" learning path's second
// course, "BIR Registration and Local Permits" (course id
// 'bir_registration_and_local_permits'). Built the same way every earlier
// expansion course was: the already shipped architecture only (governance
// metadata, official-source and risk-warning blocks, Phase 5 interaction
// blocks), nothing new added to the core model.
//
// This course picks up exactly where "Start Your Business Legally" (Phase
// 13, lessons_business_registration.dart) left off: a business or entity
// name is already registered with DTI, SEC, or CDA. This course walks
// through what comes next, IN ORDER: BIR registration (TIN and Certificate
// of Registration), setting up books and invoices, barangay clearance, the
// Mayor's or Business Permit, understanding taxpayer size classification,
// and a closing compliance calendar. It never files anything, never
// calculates a specific tax due, never promises approval or a processing
// time, and never claims Salapify is affiliated with BIR, any barangay, or
// any city or municipality.
//
// UNLIKE every earlier expansion course, this one DOES state some current
// figures (a peso amount, a threshold, a fee), rather than only pointing at
// the official source. That is a deliberate, founder-approved exception to
// this repository's usual "never hardcode a volatile figure" rule, made
// only where a fact is genuinely national and stable enough to be worth
// stating plainly, never where it structurally cannot be. Two things follow
// from that:
//
// 1. Every genuinely NATIONAL figure this course states (the BIR Annual
//    Registration Fee's abolition under RA 11976, the Documentary Stamp Tax
//    on the Certificate of Registration, the Authority to Print now being
//    free, the invoice-issuance threshold) is independently confirmed
//    against bir.gov.ph's own EOPT page and cross-checked against multiple
//    independent secondary sources before being stated, carries an
//    explicit "as of" date, and sits inside a RiskWarningBlock naming that
//    tax law can change these figures. Every one of these lessons is
//    classified ContentVolatility.high with a SHORTER review cycle than
//    this repository's usual annual default, specifically because these
//    are exactly the kind of fact that can move.
// 2. Business Permit and barangay-clearance fees are the one place this
//    course deliberately does NOT state a peso figure, on purpose, because
//    that fee is not merely time-volatile the way a national tax rule is,
//    it is STRUCTURALLY set independently by each of the country's more
//    than 1,600 cities and municipalities, so no single number or range
//    could ever be accurate nationwide even at a single point in time.
//    Stating one would not be an eventually-stale fact, it would be wrong
//    for most readers the moment it was written. This is the one place the
//    course explicitly teaches that fact instead of guessing past it (see
//    'bir-local-barangay-and-mayor' lesson's own MythOrFactBlock).
//
// Sources: BIR's own Ease of Paying Taxes page, BIR's own forms directory,
// BIR's own Online Registration and Update System (ORUS), DTI's own
// business-registration-and-permits page, and the Philippine Business Hub
// (already cited by Phase 13, reused here for the LGU-routing lesson).
// Every one of these five official pages was independently confirmed to
// exist and to cover the topic cited, through WebSearch against its own
// domain (gov.ph fetches return a uniform 403 in this environment, the same
// limitation every earlier expansion course's own header notes), per this
// repository's rule that a Money Courses official-source URL needs a real
// search, not just a cite. No blog, accounting-firm summary, or unofficial
// calculator was used as the source for any figure stated in this file;
// each was cross-checked against at least one such secondary source only
// to confirm the official page's own claim, never as the source itself.

import 'interaction_blocks.dart';
import 'lesson_blocks.dart';
import 'lesson_model.dart';

const _birAgency = 'Bureau of Internal Revenue (BIR)';
const _dtiAgency = 'Department of Trade and Industry (DTI)';
const _pbhAgency = 'Philippine Business Hub';

const _eoptTitle = 'Ease of Paying Taxes (EOPT)';
const _eoptUrl = 'https://www.bir.gov.ph/EOPT';
const _eoptVerified = '2026-08';
const _eopt = LessonSourceInfo(
  agency: _birAgency,
  title: _eoptTitle,
  canonicalUrl: _eoptUrl,
  lastVerifiedDate: _eoptVerified,
);

const _formsTitle = 'BIR Forms';
const _formsUrl = 'https://www.bir.gov.ph/bir-forms';
const _formsVerified = '2026-08';
const _forms = LessonSourceInfo(
  agency: _birAgency,
  title: _formsTitle,
  canonicalUrl: _formsUrl,
  lastVerifiedDate: _formsVerified,
);

const _orusTitle = 'Online Registration and Update System (ORUS)';
const _orusUrl = 'https://orus.bir.gov.ph/';
const _orusVerified = '2026-08';
const _orus = LessonSourceInfo(
  agency: _birAgency,
  title: _orusTitle,
  canonicalUrl: _orusUrl,
  lastVerifiedDate: _orusVerified,
);

const _dtiPermitsTitle = 'Business Registration and Permits';
const _dtiPermitsUrl =
    'https://www.dti.gov.ph/dti-business-center/dti-business-registration-permits';
const _dtiPermitsVerified = '2026-08';
const _dtiPermits = LessonSourceInfo(
  agency: _dtiAgency,
  title: _dtiPermitsTitle,
  canonicalUrl: _dtiPermitsUrl,
  lastVerifiedDate: _dtiPermitsVerified,
);

const _pbhTitle = 'Business Application Process';
const _pbhUrl = 'https://business.gov.ph/business-application-process';
const _pbhVerified = '2026-08';
const _pbh = LessonSourceInfo(
  agency: _pbhAgency,
  title: _pbhTitle,
  canonicalUrl: _pbhUrl,
  lastVerifiedDate: _pbhVerified,
);

// General, structural governance: annual review, for lessons that only
// describe a stable sequence or structure, not a fee or a threshold.
const _governanceAnnual = LessonGovernance(
  volatility: ContentVolatility.annual,
  reviewStatus: ReviewStatus.verified,
  lastVerifiedDate: '2026-08',
  reviewDueDate: '2027-08',
  reviewerId: 'LCC',
);

// Fee, form, and threshold content: a much shorter review window than this
// repository's usual high-volatility default, because this course states
// real current national figures rather than only pointing at the source,
// the one deliberate exception this course's own header comment explains.
const _governanceHigh = LessonGovernance(
  volatility: ContentVolatility.high,
  reviewStatus: ReviewStatus.verified,
  lastVerifiedDate: '2026-08',
  reviewDueDate: '2027-02',
  reviewerId: 'LCC',
);

const _boundary = EducationalBoundaryBlock(
  sourceLabel:
      'the Bureau of Internal Revenue, the Department of Trade and '
      'Industry, and your own city, municipality, or barangay',
  examplesAreFictional: true,
);

/// Lesson ids, stable and free-form, the same "never reused once a learner
/// has real progress recorded" convention every earlier expansion course's
/// own ids follow.
const birlOrderThatMatters = 'bir-local-order-that-matters';
const birlGetYourTin = 'bir-local-get-your-tin';
const birlBooksAndInvoices = 'bir-local-books-and-invoices';
const birlBarangayAndMayor = 'bir-local-barangay-and-mayor';
const birlTaxpayerSize = 'bir-local-taxpayer-size';
const birlComplianceCalendar = 'bir-local-compliance-calendar';

/// The six lessons, in reading order. Never added to lessons.dart's flat
/// list, and never merged into Start Your Business Legally's own list: see
/// test/lessons_bir_local_permits_content_test.dart's own isolation checks.
const List<MoneyLesson> birRegistrationAndLocalPermitsLessons = [
  _orderThatMatters,
  _getYourTin,
  _booksAndInvoices,
  _barangayAndMayor,
  _taxpayerSize,
  _complianceCalendar,
];

// ---------------------------------------------------------------------------
// Lesson 1: The Order That Actually Matters
// ---------------------------------------------------------------------------

const _orderThatMatters = MoneyLesson(
  id: birlOrderThatMatters,
  trackId: 'bir_registration_and_local_permits',
  title: 'The Order That Actually Matters',
  icon: 'flow',
  minutes: 3,
  summary:
      'Once a business or entity name is registered, six more steps '
      'generally follow, in a general order worth knowing before starting '
      'any of them.',
  objective:
      'Name the general order that follows business or entity name '
      'registration, without memorizing any single step\'s own '
      'requirements yet.',
  sections: [],
  governance: _governanceAnnual,
  sources: [_pbh, _dtiPermits],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A business or entity name registered with DTI, SEC, or CDA is a '
            'step, not a finish line, exactly as the "Start Your Business '
            'Legally" course covered. This course picks up from there: '
            'BIR registration, setting up books and invoices, barangay '
            'clearance, a city or municipal Business Permit, and '
            'understanding how taxpayer size affects what applies, '
            'generally in that order.',
        'This general order is not a strict law that applies identically '
            'to every business. Some steps can move depending on the '
            'industry, the location, or whether a permit or license is '
            'needed first for a specific activity. What stays true across '
            'nearly every case is that BIR registration generally comes '
            'before local permits, since a Certificate of Registration is '
            'commonly asked for during the local permit process.',
      ],
    ),
    DiagramBlock(
      steps: [
        'Business or entity name already registered (DTI, SEC, or CDA)',
        'BIR registration: TIN and Certificate of Registration',
        'Books of accounts and invoices or receipts set up',
        'Barangay clearance',
        'City or municipal Business Permit (Mayor\'s Permit)',
        'Ongoing filing and renewal, based on taxpayer size and industry',
      ],
      caption: 'A general order, not a strict rule for every business',
    ),
    NuggetsBlock([
      'BIR registration generally comes before local permits, since a '
          'Certificate of Registration is commonly asked for during the '
          'local permit process.',
      'Barangay clearance generally comes before the city or municipal '
          'Business Permit, since it is a commonly required supporting '
          'document for that permit.',
      'This general order can shift for a specific industry, location, or '
          'activity; confirming directly with each office is worth doing '
          'rather than assuming.',
    ]),
    RiskWarningBlock(
      title: 'A general order, not a guarantee for every business',
      text:
          'What generally comes next can differ by industry, location, or '
          'activity. This course names the common order to give a sense '
          'of where to start, not a promise that every business follows '
          'it identically.',
    ),
    OfficialSourceBlock(
      agency: _pbhAgency,
      sourceTitle: _pbhTitle,
      canonicalUrl: _pbhUrl,
      lastVerifiedDate: _pbhVerified,
    ),
    OfficialSourceBlock(
      agency: _dtiAgency,
      sourceTitle: _dtiPermitsTitle,
      canonicalUrl: _dtiPermitsUrl,
      lastVerifiedDate: _dtiPermitsVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    SortingBlock(
      blockId: 'order-that-matters-sequence',
      sortingPrompt: 'Put this general sequence in the order it should happen.',
      items: [
        SortingItemDef(
          id: 'name-registered',
          label: 'Business or entity name registered (DTI, SEC, or CDA)',
        ),
        SortingItemDef(
          id: 'bir-registration',
          label: 'BIR registration: TIN and Certificate of Registration',
        ),
        SortingItemDef(
          id: 'books-invoices',
          label: 'Books of accounts and invoices or receipts set up',
        ),
        SortingItemDef(id: 'barangay', label: 'Barangay clearance'),
        SortingItemDef(
          id: 'mayors-permit',
          label: 'City or municipal Business Permit (Mayor\'s Permit)',
        ),
        SortingItemDef(
          id: 'ongoing-filing',
          label: 'Ongoing filing and renewal',
        ),
      ],
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'order-is-fixed-law-myth',
      statement:
          'The order in this lesson is a fixed legal requirement that '
          'applies identically to every business in the Philippines.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'It is the common general order, not a fixed rule. Industry, '
          'location, and the specific activity can all change what comes '
          'next; confirming directly with each office remains worth doing.',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'According to this lesson, what generally comes right after BIR '
        'registration in this sequence?',
    choices: [
      'Setting up books of accounts and invoices or receipts',
      'The city or municipal Business Permit, skipping barangay clearance',
      'Nothing else; BIR registration is generally the last step',
    ],
    correctIndex: 0,
    explanation:
        'This lesson\'s own diagram places books and invoices right after '
        'BIR registration, before barangay clearance and the Business '
        'Permit.',
    whyWrong:
        'Skipping barangay clearance, or treating BIR registration as the '
        'last step, both contradict the sequence this lesson names.',
  ),
  keyTakeaway:
      'After a business or entity name is registered, BIR registration, '
      'books and invoices, barangay clearance, and a city or municipal '
      'Business Permit generally follow in that order, though the exact '
      'order can shift for a specific industry, location, or activity.',
);

// ---------------------------------------------------------------------------
// Lesson 2: Get Your TIN and Certificate of Registration
// ---------------------------------------------------------------------------

const _getYourTin = MoneyLesson(
  id: birlGetYourTin,
  trackId: 'bir_registration_and_local_permits',
  title: 'Get Your TIN and Certificate of Registration',
  icon: 'document',
  minutes: 4,
  summary:
      'BIR Form 1901, 1902, or 1903 registers a taxpayer and produces a '
      'Certificate of Registration. The old yearly ₱500 fee is gone as of '
      '2024.',
  objective:
      'Match a taxpayer type to the right BIR registration form, and '
      'describe what a Certificate of Registration actually shows.',
  sections: [],
  governance: _governanceHigh,
  sources: [_eopt, _forms, _orus],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'BIR registration generally uses one of three forms, depending on '
            'who is registering: Form 1901 for a self-employed individual, '
            'a professional, or someone with mixed income; Form 1902 for '
            'an employee registering only for a Taxpayer Identification '
            'Number (TIN); and Form 1903 for a corporation, partnership, '
            'or similar entity. A successful registration produces a '
            'Certificate of Registration, BIR Form 2303, listing the TIN, '
            'the registered name, the Revenue District Office (RDO), and '
            'the tax types and filing frequencies that apply.',
        'As of this course\'s own last verification date, Republic Act No. '
            '11976, the Ease of Paying Taxes Act, remains in effect: '
            'effective January 22, 2024, it abolished the old ₱500 yearly '
            'Annual Registration Fee that businesses used to pay every '
            'January. A Documentary Stamp Tax of around ₱30 still '
            'generally applies '
            'to the Certificate of Registration itself, a one-time cost at '
            'registration, not a recurring yearly fee.',
        'Registration can generally be completed online through BIR\'s own '
            'Online Registration and Update System (ORUS), or in person at '
            'the Revenue District Office that covers the business address. '
            'Exact document lists and processing details can change; '
            'confirming directly with BIR before applying is worth doing.',
      ],
    ),
    NuggetsBlock([
      'Form 1901 is generally for a self-employed individual, a '
          'professional, or someone with mixed income.',
      'Form 1902 is generally for an employee registering only for a TIN.',
      'Form 1903 is generally for a corporation, partnership, or similar '
          'entity.',
      'The old ₱500 yearly Annual Registration Fee no longer applies, as '
          'of Republic Act No. 11976; a smaller, one-time Documentary '
          'Stamp Tax (around ₱30) still generally applies to the '
          'Certificate of Registration itself.',
    ]),
    RiskWarningBlock(
      title: 'A tax rule that can change again',
      text:
          'Republic Act No. 11976 changed a fee that had applied for '
          'years, and tax rules can change again. The figures in this '
          'lesson are current as of this course\'s own last verification '
          'date; confirming the current rule directly with BIR before '
          'registering or paying anything is worth doing.',
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _eoptTitle,
      canonicalUrl: _eoptUrl,
      lastVerifiedDate: _eoptVerified,
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _formsTitle,
      canonicalUrl: _formsUrl,
      lastVerifiedDate: _formsVerified,
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _orusTitle,
      canonicalUrl: _orusUrl,
      lastVerifiedDate: _orusVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    CategorizeBlock(
      blockId: 'bir-form-match',
      categorizePrompt:
          'Match each fictional taxpayer to the BIR form they would '
          'generally use.',
      buckets: [
        CategorizeBucket(id: 'form-1901', label: 'Form 1901'),
        CategorizeBucket(id: 'form-1902', label: 'Form 1902'),
        CategorizeBucket(id: 'form-1903', label: 'Form 1903'),
      ],
      items: [
        CategorizeItemDef(
          id: 'freelance-designer',
          label:
              'A fictional freelance graphic designer registering as '
              'self-employed',
          explanation: 'A self-employed individual generally uses Form 1901.',
        ),
        CategorizeItemDef(
          id: 'new-employee',
          label: 'A fictional new employee who only needs a TIN for payroll',
          explanation:
              'An employee registering only for a TIN generally uses Form '
              '1902.',
        ),
        CategorizeItemDef(
          id: 'sideline-seller',
          label:
              'A fictional employee who also sells products on the side, '
              'earning mixed income',
          explanation:
              'Mixed income, both compensation and business income, '
              'generally uses Form 1901.',
        ),
        CategorizeItemDef(
          id: 'new-corporation',
          label: 'A fictional newly registered corporation',
          explanation: 'A corporation generally uses Form 1903.',
        ),
      ],
      correctBucketByItemId: {
        'freelance-designer': 'form-1901',
        'new-employee': 'form-1902',
        'sideline-seller': 'form-1901',
        'new-corporation': 'form-1903',
      },
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'annual-fee-still-applies-myth',
      statement:
          'A business must still pay a ₱500 Annual Registration Fee to '
          'BIR every January.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'That yearly fee was abolished under Republic Act No. 11976, '
          'the Ease of Paying Taxes Act, effective January 22, 2024. A '
          'smaller, one-time Documentary Stamp Tax still generally applies '
          'to the Certificate of Registration itself, not a recurring '
          'yearly fee.',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'registration-channel-scenario',
      scenarioTitle: 'A fictional new registrant',
      situation:
          'A fictional self-employed individual wants to register with '
          'BIR and would rather not visit an office in person if possible.',
      options: [
        ScenarioChoiceOption(
          id: 'orus-investigate',
          label: 'Investigate registering through ORUS online',
          explanation:
              'Worth investigating. BIR\'s own Online Registration and '
              'Update System generally allows registration without an '
              'in-person visit, subject to its own current requirements.',
        ),
        ScenarioChoiceOption(
          id: 'rdo-investigate',
          label:
              'Investigate registering in person at the Revenue '
              'District Office',
          explanation:
              'Also a real option. Registering in person at the RDO that '
              'covers the business address remains available alongside '
              'ORUS.',
        ),
        ScenarioChoiceOption(
          id: 'assume-fee-first',
          label:
              'Set aside ₱500 for the annual registration fee before '
              'starting',
          explanation:
              'Not needed. That yearly fee no longer applies as of '
              'Republic Act No. 11976; setting it aside is based on an '
              'outdated rule.',
        ),
      ],
      requiredForCompletion: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'According to this lesson, is the old ₱500 yearly Annual '
        'Registration Fee still required?',
    choices: [
      'Yes, every business must still pay it every January',
      'No, it was abolished under Republic Act No. 11976, though a '
          'smaller one-time fee can still apply to the Certificate of '
          'Registration itself',
      'Only corporations still pay it; sole proprietors do not',
    ],
    correctIndex: 1,
    explanation:
        'Republic Act No. 11976, the Ease of Paying Taxes Act, abolished '
        'the old yearly fee, though a smaller one-time cost can still '
        'apply to the Certificate of Registration itself.',
    whyWrong:
        'Neither treating the old fee as still required for everyone, '
        'nor limiting the myth to one structure type, matches what this '
        'lesson actually explains.',
  ),
  keyTakeaway:
      'BIR registration generally uses Form 1901, 1902, or 1903 depending '
      'on the taxpayer, produces a Certificate of Registration (Form '
      '2303), and no longer carries the old ₱500 yearly Annual '
      'Registration Fee, abolished under Republic Act No. 11976, though a '
      'smaller one-time cost can still apply to the certificate itself.',
);

// ---------------------------------------------------------------------------
// Lesson 3: Books, Receipts, and Invoices
// ---------------------------------------------------------------------------

const _booksAndInvoices = MoneyLesson(
  id: birlBooksAndInvoices,
  trackId: 'bir_registration_and_local_permits',
  title: 'Books, Receipts, and Invoices',
  icon: 'checklist',
  minutes: 4,
  summary:
      'A Certificate of Registration is not the end of BIR setup: books of '
      'accounts and invoices or receipts still need to be ready.',
  objective:
      'Describe what generally still needs setting up after a Certificate '
      'of Registration is issued, without memorizing exact document '
      'formats.',
  sections: [],
  governance: _governanceHigh,
  sources: [_eopt],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A Certificate of Registration is not the finish line either. '
            'Books of accounts, generally manual, loose-leaf, or '
            'computerized, need to be set up to record transactions, and '
            'invoices or receipts generally need to be ready before '
            'selling anything. As of this course\'s own last verification '
            'date, businesses generally have a window of about 30 days '
            'after the Certificate of Registration is issued to have '
            'invoices or receipts printed or configured.',
        'Under Republic Act No. 11976, Authority to Print, the approval '
            'previously needed before printing official receipts or '
            'invoices, is now free of charge, where it used to carry its '
            'own fee. The threshold for when a seller must issue a '
            'receipt or invoice for a sale also rose, from ₱100 to ₱500, '
            'as of this course\'s own last verification date, though a '
            'VAT-registered seller generally still needs to issue one for '
            'every sale regardless of amount.',
        'Exact book formats, thresholds, and windows can change with '
            'future tax rules; confirming the current requirement directly '
            'with BIR before setting anything up or paying anything is '
            'worth doing.',
      ],
    ),
    NuggetsBlock([
      'Books of accounts generally come in three types: manual, '
          'loose-leaf, or computerized.',
      'Invoices or receipts generally need to be ready within about 30 '
          'days of the Certificate of Registration being issued.',
      'Authority to Print is now generally free of charge, where it used '
          'to carry its own fee.',
      'The receipt or invoice issuance threshold rose from ₱100 to ₱500, '
          'though a VAT-registered seller generally still issues one for '
          'every sale.',
    ]),
    RiskWarningBlock(
      title: 'Figures that can change again',
      text:
          'Thresholds, fees, and windows like these are exactly the kind '
          'of tax detail that can change. The figures in this lesson are '
          'current as of this course\'s own last verification date; '
          'confirming the current requirement directly with BIR before '
          'setting anything up is worth doing.',
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _eoptTitle,
      canonicalUrl: _eoptUrl,
      lastVerifiedDate: _eoptVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ChecklistBlock(
      blockId: 'books-and-invoices-readiness',
      checklistPrompt:
          'A private readiness checklist. Nothing here is saved or '
          'shared.',
      items: [
        ChecklistItemDef(
          id: 'books-type-chosen',
          label:
              'Which type of books of accounts to use, manual, '
              'loose-leaf, or computerized, has been considered',
          required: false,
        ),
        ChecklistItemDef(
          id: 'invoice-plan',
          label:
              'A plan for invoices or receipts, printed or computerized, '
              'is in progress',
          required: false,
        ),
        ChecklistItemDef(
          id: 'thirty-day-window',
          label:
              'The general window after the Certificate of Registration '
              'is issued has been noted',
          required: false,
        ),
        ChecklistItemDef(
          id: 'confirm-current-rule',
          label:
              'Current thresholds and fees have been confirmed directly '
              'with BIR rather than assumed from this lesson alone',
          required: false,
        ),
      ],
      allRequiredMustBeChecked: false,
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'authority-to-print-costs-myth',
      statement:
          'Authority to Print, the approval needed before printing '
          'official receipts or invoices, still carries its own separate '
          'fee.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'As of this course\'s own last verification date, Authority to '
          'Print is generally free of charge, where it used to carry its '
          'own fee, under Republic Act No. 11976.',
      requiredForCompletion: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'According to this lesson, is a Certificate of Registration '
        'generally the last step before a business can start issuing '
        'receipts or invoices?',
    choices: [
      'Yes, nothing else is generally needed once it is issued',
      'No, books of accounts and invoices or receipts generally still '
          'need to be set up within a general window afterward',
      'Only for a corporation; a sole proprietor can skip this step',
    ],
    correctIndex: 1,
    explanation:
        'This lesson names books of accounts and invoice or receipt '
        'setup as steps that generally still follow the Certificate of '
        'Registration, within a general window.',
    whyWrong:
        'Neither treating the certificate as the final step, nor '
        'exempting one structure type, matches what this lesson actually '
        'says.',
  ),
  keyTakeaway:
      'After a Certificate of Registration is issued, books of accounts '
      'and invoices or receipts generally still need to be set up, within '
      'a general window; Authority to Print is now generally free, and '
      'the receipt or invoice issuance threshold rose from ₱100 to ₱500, '
      'both current as of this course\'s own last verification date.',
);

// ---------------------------------------------------------------------------
// Lesson 4: Barangay Clearance and the Mayor's Permit
// ---------------------------------------------------------------------------

const _barangayAndMayor = MoneyLesson(
  id: birlBarangayAndMayor,
  trackId: 'bir_registration_and_local_permits',
  title: 'Barangay Clearance and the Mayor\'s Permit',
  icon: 'bank',
  minutes: 4,
  summary:
      'Barangay clearance generally comes before the city or municipal '
      'Business Permit. Neither has one fee nationwide; each local '
      'government sets its own.',
  objective:
      'Describe the general order and purpose of barangay clearance and '
      'the Business Permit, without stating a fee for either.',
  sections: [],
  governance: _governanceHigh,
  sources: [_dtiPermits, _pbh],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A barangay clearance generally certifies that a business follows '
            'that barangay\'s own rules, and is commonly asked for before '
            'applying for a city or municipal Business Permit, sometimes '
            'called a Mayor\'s Permit. That permit is issued by the city '
            'or municipality where the business is located, generally '
            'through its own Business Permits and Licensing Office.',
        'Neither of these carries one fee that applies nationwide. Each '
            'of the country\'s cities and municipalities sets its own '
            'fees, forms, and specific document requirements, and each '
            'barangay can differ too. That is not a gap in this lesson, '
            'it reflects how local government actually works: the only '
            'reliable way to know the current fee or exact requirement is '
            'to check directly with the barangay and the city or '
            'municipal office where the business will operate.',
        'Common supporting documents generally include proof of the '
            'business or entity registration (from DTI, SEC, or CDA), '
            'proof of the business address, and the BIR Certificate of '
            'Registration. A barangay clearance and Business Permit are '
            'also generally location-specific: operating in a different '
            'city or municipality later generally means applying again '
            'there.',
      ],
    ),
    NuggetsBlock([
      'Barangay clearance generally comes before the city or municipal '
          'Business Permit.',
      'Neither carries one fee nationwide; each barangay and each city or '
          'municipality sets its own.',
      'Common supporting documents generally include the business or '
          'entity registration and the BIR Certificate of Registration.',
      'Both are generally location-specific to where the business '
          'operates.',
    ]),
    RiskWarningBlock(
      title: 'No single fee applies everywhere',
      text:
          'Barangay clearance and Business Permit fees are set locally, '
          'not nationally, so no single figure in this lesson could ever '
          'be accurate for every reader. Checking directly with the '
          'barangay and the city or municipal Business Permits and '
          'Licensing Office where the business operates is the only '
          'reliable way to know the current fee and exact requirements.',
    ),
    OfficialSourceBlock(
      agency: _dtiAgency,
      sourceTitle: _dtiPermitsTitle,
      canonicalUrl: _dtiPermitsUrl,
      lastVerifiedDate: _dtiPermitsVerified,
    ),
    OfficialSourceBlock(
      agency: _pbhAgency,
      sourceTitle: _pbhTitle,
      canonicalUrl: _pbhUrl,
      lastVerifiedDate: _pbhVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    MythOrFactBlock(
      blockId: 'same-fee-everywhere-myth',
      statement:
          'The Business Permit fee is the same amount everywhere in the '
          'Philippines.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Each city and municipality sets its own Business Permit fees '
          'and requirements. There is no single nationwide figure, which '
          'is exactly why this lesson never states one; checking directly '
          'with the local Business Permits and Licensing Office is the '
          'only reliable way to know the current amount.',
      requiredForCompletion: true,
    ),
    ChecklistBlock(
      blockId: 'barangay-mayor-readiness',
      checklistPrompt:
          'A general readiness check before applying. Nothing here is '
          'saved or shared, and none of it is filed anywhere from this '
          'app.',
      items: [
        ChecklistItemDef(
          id: 'barangay-first',
          label:
              'Barangay clearance is planned before the city or '
              'municipal Business Permit',
          required: false,
        ),
        ChecklistItemDef(
          id: 'documents-gathered',
          label:
              'Common supporting documents (business registration, '
              'proof of address, BIR Certificate of Registration) are '
              'being gathered',
          required: false,
        ),
        ChecklistItemDef(
          id: 'checked-local-office',
          label:
              'The current fee and exact requirements have been checked '
              'directly with the barangay and the local Business Permits '
              'and Licensing Office',
          required: true,
        ),
      ],
      allRequiredMustBeChecked: true,
      requiredForCompletion: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'According to this lesson, why does it never state a specific '
        'peso amount for the Business Permit fee?',
    choices: [
      'Because each city and municipality sets its own fee, so no single '
          'nationwide figure would be accurate',
      'Because the fee is always free',
      'Because the fee only applies to corporations, never to sole '
          'proprietors',
    ],
    correctIndex: 0,
    explanation:
        'Business Permit fees are set locally by each city or '
        'municipality, not by one national rule, which is exactly why '
        'this lesson points to checking directly with the local office '
        'instead of stating a figure.',
    whyWrong:
        'Neither claiming the fee is always free, nor limiting it to one '
        'structure type, explains why this lesson deliberately omits a '
        'peso figure here.',
  ),
  keyTakeaway:
      'Barangay clearance generally comes before the city or municipal '
      'Business Permit, both generally need common supporting documents '
      'like the business registration and BIR Certificate of '
      'Registration, and neither carries one nationwide fee; the current '
      'fee and exact requirements always need checking directly with the '
      'local barangay and Business Permits and Licensing Office.',
);

// ---------------------------------------------------------------------------
// Lesson 5: Micro, Small, or Something Else
// ---------------------------------------------------------------------------

const _taxpayerSize = MoneyLesson(
  id: birlTaxpayerSize,
  trackId: 'bir_registration_and_local_permits',
  title: 'Micro, Small, or Something Else',
  icon: 'balance',
  minutes: 3,
  summary:
      'BIR generally classifies taxpayers by size, which can change which '
      'forms and rules apply. This lesson never guesses which class a '
      'reader falls into.',
  objective:
      'Explain why taxpayer size classification matters, without '
      'determining which class any specific reader falls into.',
  sections: [],
  governance: _governanceHigh,
  sources: [_eopt],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Under Republic Act No. 11976, BIR generally classifies taxpayers '
            'as micro, small, medium, or large, generally based on gross '
            'sales. This classification can generally affect which forms '
            'apply, such as a shorter income tax return for a smaller '
            'taxpayer, and can generally affect penalties for late filing.',
        'This lesson does not state the exact gross-sales thresholds '
            'that separate these classes: those are exactly the kind of '
            'figure that can be adjusted, and a single reader\'s actual '
            'classification depends on their own numbers, which this '
            'lesson does not know. What matters here is knowing this '
            'classification exists and that it is worth checking directly '
            'with BIR or a tax professional, not guessing at from general '
            'reading.',
      ],
    ),
    NuggetsBlock([
      'BIR generally classifies taxpayers as micro, small, medium, or '
          'large, generally based on gross sales.',
      'A smaller classification can generally mean a shorter income tax '
          'return form and reduced penalties for late filing.',
      'This lesson never determines which class any specific reader '
          'falls into; that depends on real numbers this lesson does not '
          'have.',
    ]),
    RiskWarningBlock(
      title: 'Classification is not calculated here',
      text:
          'This lesson names that taxpayer size classification exists '
          'and generally affects some requirements. It never calculates '
          'or states which class applies to any specific reader; '
          'confirming that directly with BIR or a tax professional is '
          'worth doing.',
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _eoptTitle,
      canonicalUrl: _eoptUrl,
      lastVerifiedDate: _eoptVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ScenarioChoiceBlock(
      blockId: 'taxpayer-size-scenario',
      scenarioTitle: 'A fictional new business owner',
      situation:
          'A fictional new business owner heard that "small taxpayers" '
          'get a shorter tax form and wants to know if that applies to '
          'them.',
      options: [
        ScenarioChoiceOption(
          id: 'ask-bir-or-professional',
          label: 'Check directly with BIR or a tax professional',
          explanation:
              'The right next step. Classification depends on real gross '
              'sales figures this course does not have and should not '
              'guess at.',
        ),
        ScenarioChoiceOption(
          id: 'assume-small',
          label:
              'Assume they are automatically a small taxpayer since '
              'the business is new',
          explanation:
              'Not reliable. Classification generally depends on gross '
              'sales, not how new the business is, and assuming it '
              'without checking can lead to using the wrong form.',
        ),
        ScenarioChoiceOption(
          id: 'ignore-classification',
          label:
              'Ignore classification entirely since it sounds '
              'complicated',
          explanation:
              'Worth understanding, not ignoring. Classification can '
              'generally affect which form and which penalties apply, so '
              'it is worth a real check rather than skipping it.',
        ),
      ],
      requiredForCompletion: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'Does this lesson state the exact gross-sales thresholds that '
        'separate micro, small, medium, and large taxpayers?',
    choices: [
      'Yes, with a specific peso figure for each class',
      'No, because those thresholds can change and a reader\'s own '
          'classification depends on numbers this lesson does not have',
      'Only for corporations, never for sole proprietors',
    ],
    correctIndex: 1,
    explanation:
        'This lesson deliberately never states the thresholds, since '
        'they can change and any specific reader\'s classification '
        'depends on numbers only they, or BIR, or a tax professional, '
        'would know.',
    whyWrong:
        'Neither stating a figure, nor limiting the concept to one '
        'structure type, matches what this lesson actually does.',
  ),
  keyTakeaway:
      'BIR generally classifies taxpayers as micro, small, medium, or '
      'large, generally based on gross sales, which can generally affect '
      'which forms and penalties apply; this lesson never determines '
      'which class fits any specific reader, since that depends on real '
      'numbers only BIR or a tax professional can confirm.',
);

// ---------------------------------------------------------------------------
// Lesson 6: Build Your Compliance Calendar
// ---------------------------------------------------------------------------

const _complianceCalendar = MoneyLesson(
  id: birlComplianceCalendar,
  trackId: 'bir_registration_and_local_permits',
  title: 'Build Your Compliance Calendar',
  icon: 'plan',
  minutes: 4,
  summary:
      'A short, personal checklist tying BIR registration, books, and '
      'local permits together, and a few real next steps in Salapify if '
      'any of them fit.',
  objective:
      'Build a generic compliance checklist covering what to investigate '
      'and track next, without landing on a specific amount or deadline.',
  sections: [],
  governance: _governanceAnnual,
  sources: [_eopt, _pbh],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A compliance calendar is a short, personal list tying together '
            'everything this course covered: BIR registration, books and '
            'invoices, barangay clearance, the Business Permit, and '
            'ongoing filing. It never states which amount to set aside or '
            'which exact date something is due; it is a plan to track, '
            'not a decision or a deadline already set.',
        'Barangay clearances and Business Permits are also generally '
            'renewed periodically, not registered once and forgotten. A '
            'reminder to check renewal timing directly with the local '
            'office, before it lapses, is worth building into a real '
            'routine.',
      ],
    ),
    NuggetsBlock([
      'BIR registration, books and invoices, barangay clearance, and the '
          'Business Permit are all worth tracking, not just registering '
          'once.',
      'Renewal timing for local permits is generally periodic and set '
          'locally; checking directly with the local office before it '
          'lapses is worth building into a routine.',
      'A compliance and registration budget, and a way to remember '
          'ongoing filing, round out a realistic plan.',
    ]),
    RiskWarningBlock(
      title: 'A calendar is a plan, not a decision',
      text:
          'This lesson never tells anyone which amount to set aside or '
          'which exact date something is due. It only names what is '
          'worth tracking and, where a real Salapify feature already '
          'exists, offers to open it.',
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _eoptTitle,
      canonicalUrl: _eoptUrl,
      lastVerifiedDate: _eoptVerified,
    ),
    OfficialSourceBlock(
      agency: _pbhAgency,
      sourceTitle: _pbhTitle,
      canonicalUrl: _pbhUrl,
      lastVerifiedDate: _pbhVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ChecklistBlock(
      blockId: 'compliance-calendar-checklist',
      checklistPrompt:
          'A personal calendar to work through at your own pace. '
          'Offline, and yours to keep.',
      items: [
        ChecklistItemDef(
          id: 'bir-registration-tracked',
          label: 'BIR registration status is tracked',
          required: false,
        ),
        ChecklistItemDef(
          id: 'books-invoices-tracked',
          label:
              'Books of accounts and invoice or receipt setup is '
              'tracked',
          required: false,
        ),
        ChecklistItemDef(
          id: 'barangay-tracked',
          label:
              'Barangay clearance status and renewal timing is '
              'tracked',
          required: false,
        ),
        ChecklistItemDef(
          id: 'mayors-permit-tracked',
          label: 'Business Permit status and renewal timing is tracked',
          required: false,
        ),
        ChecklistItemDef(
          id: 'compliance-budget',
          label:
              'A registration and ongoing compliance budget has been '
              'considered',
          required: false,
        ),
        ChecklistItemDef(
          id: 'compliance-reminders',
          label:
              'A way to remember renewal and filing deadlines has '
              'been considered',
          required: false,
        ),
      ],
      allRequiredMustBeChecked: false,
      requiredForCompletion: false,
    ),
    MythOrFactBlock(
      blockId: 'calendar-auto-creates-myth',
      statement:
          'Working through this compliance calendar automatically '
          'creates a goal, a budget line, a recurring cost, or a '
          'reminder.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Nothing here creates or changes a financial record '
          'automatically. Each destination named in this lesson still '
          'needs your own confirmation inside that screen before '
          'anything is saved.',
      requiredForCompletion: true,
    ),
    SalapifyActionsBlock(
      blockId: 'compliance-calendar-actions',
      menuPrompt: 'A few real next steps, if any of them fit.',
      actions: [
        SalapifyActionDef(
          id: 'start-compliance-goal',
          label: 'Start a compliance savings goal',
          description:
              'Opens Goals to check or start a goal for registration or '
              'renewal costs. Nothing is created or changed until '
              'something is saved there.',
          route: 'goals',
        ),
        SalapifyActionDef(
          id: 'review-budget-for-compliance',
          label: 'Review Budget for a compliance line',
          description:
              'Opens Budget to check what is already spoken for this '
              'period before setting money aside for registration or '
              'permit costs. Nothing changes automatically.',
          route: 'budget',
        ),
        SalapifyActionDef(
          id: 'track-renewals-as-recurring',
          label: 'Track a permit renewal as a recurring cost',
          description:
              'Opens Recurring, where a periodic cost like an annual '
              'permit renewal can already be tracked if you choose to add '
              'one. Nothing is created automatically.',
          route: 'recurring',
        ),
        SalapifyActionDef(
          id: 'open-compliance-reminders',
          label: 'Open reminders',
          description:
              'Opens Notifications and security, where reminders can be '
              'turned on. There is no compliance-specific reminder type '
              'yet, so nothing is scheduled automatically; this is the '
              'closest real screen for building a periodic check-in habit '
              'by hand.',
          route: 'notifications',
        ),
      ],
    ),
  ],
  check: KnowledgeCheck(
    question:
        'Does completing this compliance calendar checklist automatically '
        'create a goal, budget line, recurring cost, or reminder?',
    choices: [
      'Yes, automatically, once the checklist is complete',
      'No, each screen still needs your own confirmation before '
          'anything is created or changed',
      'Only the recurring cost is created automatically',
    ],
    correctIndex: 1,
    explanation:
        'Every action offered here only opens a real Salapify screen; '
        'nothing is created or changed until it is confirmed there.',
    whyWrong:
        'No action in this lesson creates or changes anything '
        'automatically, the recurring cost included.',
  ),
  keyTakeaway:
      'A compliance calendar tracks BIR registration, books and '
      'invoices, barangay clearance, and the Business Permit together, '
      'including their periodic renewal timing, and turning any of it '
      'into a real goal, budget line, recurring cost, or reminder in '
      'Salapify still needs your own confirmation inside that screen.',
);
