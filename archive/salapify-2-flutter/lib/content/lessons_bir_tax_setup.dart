// Money Courses: "Build Your Business" learning path's THIRD course, "BIR
// Setup for New Businesses" (course id 'bir_registration_tax_setup'). Built
// the same way every earlier expansion course was: the already shipped
// architecture only (governance metadata, official-source and risk-warning
// blocks, Phase 5 interaction blocks), nothing new added to the core model.
//
// This course sits after both "Start Your Business Legally" (structure and
// name registration) and "BIR Registration and Local Permits" (the TIN,
// Certificate of Registration, books, and local permits): it teaches WHICH
// obligations a registration actually carries, the control purpose of
// invoices and books, a filing routine, and a general tax-money habit. It
// never calculates a tax, never chooses a tax regime, never prepares a
// return, and never determines a reader's own obligations.
//
// UNLIKE "BIR Registration and Local Permits", this course states NO
// current rate, threshold, deadline, penalty, fee, or complete form list
// anywhere: every one of those categories (registration channels,
// documentary requirements, taxpayer classifications, tax types, rates and
// thresholds, forms, filing and payment deadlines, invoicing rules,
// books-of-account requirements, penalties, portal availability) is
// classified ContentVolatility.high and pointed at the official source
// instead of stated as a static fact, the same discipline every course
// before "BIR Registration and Local Permits" already followed.
//
// Sources: the eight official BIR pages named for this course (BIR's own
// site, EOPT, Registration Requirements, Primary Registration, Secondary
// Registration, the NewBizReg portal, ORUS, and Tax Reminder). Every one of
// these eight was independently confirmed to exist and to cover the topic
// cited, through WebSearch against its own domain (gov.ph fetches return a
// uniform 403 in this environment, the same limitation every earlier
// expansion course's own header notes), per this repository's rule that a
// Money Courses official-source URL needs a real search, not just a cite.
// No accounting blog, law-firm article, social post, video, or unofficial
// tax site was used as a source. No lookalike domain (such as "orus.ph")
// appears anywhere in this file.

import 'interaction_blocks.dart';
import 'lesson_blocks.dart';
import 'lesson_model.dart';

const _birAgency = 'Bureau of Internal Revenue (BIR)';

const _mainTitle = 'BIR Official Website';
const _mainUrl = 'https://www.bir.gov.ph/';
const _mainVerified = '2026-08';
const _main = LessonSourceInfo(
  agency: _birAgency,
  title: _mainTitle,
  canonicalUrl: _mainUrl,
  lastVerifiedDate: _mainVerified,
);

const _eoptTitle = 'BIR Ease of Paying Taxes';
const _eoptUrl = 'https://www.bir.gov.ph/EOPT';
const _eoptVerified = '2026-08';
const _eopt = LessonSourceInfo(
  agency: _birAgency,
  title: _eoptTitle,
  canonicalUrl: _eoptUrl,
  lastVerifiedDate: _eoptVerified,
);

const _regReqTitle = 'BIR Registration Requirements';
const _regReqUrl = 'https://www.bir.gov.ph/registration-requirements-details';
const _regReqVerified = '2026-08';
const _regReq = LessonSourceInfo(
  agency: _birAgency,
  title: _regReqTitle,
  canonicalUrl: _regReqUrl,
  lastVerifiedDate: _regReqVerified,
);

const _primaryRegTitle = 'BIR Primary Registration';
const _primaryRegUrl = 'https://www.bir.gov.ph/primary-registration';
const _primaryRegVerified = '2026-08';
const _primaryReg = LessonSourceInfo(
  agency: _birAgency,
  title: _primaryRegTitle,
  canonicalUrl: _primaryRegUrl,
  lastVerifiedDate: _primaryRegVerified,
);

const _secondaryRegTitle = 'BIR Secondary Registration';
const _secondaryRegUrl = 'https://www.bir.gov.ph/secondary-registration';
const _secondaryRegVerified = '2026-08';
const _secondaryReg = LessonSourceInfo(
  agency: _birAgency,
  title: _secondaryRegTitle,
  canonicalUrl: _secondaryRegUrl,
  lastVerifiedDate: _secondaryRegVerified,
);

const _newBizRegTitle = 'BIR NewBizReg';
const _newBizRegUrl = 'https://web-services.bir.gov.ph/newbizreg/';
const _newBizRegVerified = '2026-08';
const _newBizReg = LessonSourceInfo(
  agency: _birAgency,
  title: _newBizRegTitle,
  canonicalUrl: _newBizRegUrl,
  lastVerifiedDate: _newBizRegVerified,
);

const _orusTitle = 'BIR ORUS';
const _orusUrl = 'https://orus.bir.gov.ph/home';
const _orusVerified = '2026-08';
const _orus = LessonSourceInfo(
  agency: _birAgency,
  title: _orusTitle,
  canonicalUrl: _orusUrl,
  lastVerifiedDate: _orusVerified,
);

const _taxReminderTitle = 'BIR Tax Reminder';
const _taxReminderUrl = 'https://www.bir.gov.ph/tax-reminder';
const _taxReminderVerified = '2026-08';
const _taxReminder = LessonSourceInfo(
  agency: _birAgency,
  title: _taxReminderTitle,
  canonicalUrl: _taxReminderUrl,
  lastVerifiedDate: _taxReminderVerified,
);

// Every category this course touches (registration channels, documentary
// requirements, taxpayer classifications, tax types, rates and thresholds,
// forms, filing and payment deadlines, invoicing rules, books-of-account
// requirements, penalties, portal availability) is classified high, with a
// review window shorter than this repository's usual annual default,
// because this course's own subject matter is exactly the kind of thing
// that changes.
const _governanceHigh = LessonGovernance(
  volatility: ContentVolatility.high,
  reviewStatus: ReviewStatus.verified,
  lastVerifiedDate: '2026-08',
  reviewDueDate: '2027-02',
  reviewerId: 'TAX',
);

const _boundary = EducationalBoundaryBlock(
  sourceLabel: 'the Bureau of Internal Revenue',
  examplesAreFictional: true,
);

/// Lesson ids, stable and free-form, the same "never reused once a learner
/// has real progress recorded" convention every earlier expansion course's
/// own ids follow.
const btaxStartWithProfile = 'bir-tax-start-with-your-profile';
const btaxPrimarySecondary = 'bir-tax-primary-and-secondary-registration';
const btaxKnowWhatYouRegisteredFor = 'bir-tax-know-what-you-registered-for';
const btaxInvoicesBooksProof = 'bir-tax-invoices-books-and-proof';
const btaxFilingRoutine = 'bir-tax-build-a-filing-routine';
const btaxMoneySystem = 'bir-tax-create-your-tax-money-system';

/// The six lessons, in reading order. Never added to lessons.dart's flat
/// list, and never merged into either sibling course's own list: see
/// test/lessons_bir_tax_setup_content_test.dart's own isolation checks.
const List<MoneyLesson> birRegistrationTaxSetupLessons = [
  _startWithYourProfile,
  _primaryAndSecondaryRegistration,
  _knowWhatYouRegisteredFor,
  _invoicesBooksAndProof,
  _buildAFilingRoutine,
  _createYourTaxMoneySystem,
];

// ---------------------------------------------------------------------------
// Lesson 1: Start With Your BIR Profile
// ---------------------------------------------------------------------------

const _startWithYourProfile = MoneyLesson(
  id: btaxStartWithProfile,
  trackId: 'bir_registration_tax_setup',
  title: 'Start With Your BIR Profile',
  icon: 'checklist',
  minutes: 3,
  summary:
      'BIR registration is separate from DTI, SEC, or CDA registration, '
      'and an existing taxpayer usually needs to update, not repeat, it.',
  objective:
      'Identify what to verify first for a given situation, without '
      'determining a specific tax type or filing obligation.',
  sections: [],
  governance: _governanceHigh,
  sources: [_main, _eopt],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'BIR registration is a separate system from DTI, SEC, or CDA '
            'registration, even though it commonly follows one of them. A '
            'person or business already registered somewhere with BIR, '
            'for example as an employee with an existing Taxpayer '
            'Identification Number (TIN), generally needs to UPDATE that '
            'registration for a new activity, not apply for a second TIN. '
            'A single person is only ever meant to hold one TIN.',
        'What actually applies depends on the taxpayer, the business '
            'structure, the activities involved, what is already on '
            'record with BIR, and the current rules, none of which this '
            'course can know for any specific reader. The official BIR '
            'website is the right starting point for confirming any of '
            'this directly, before assuming an outcome.',
        'It is also worth starting from the real site: bir.gov.ph. '
            'Unofficial agents who offer to create or verify a TIN for a '
            'fee, or a look-alike site with a similar name, are worth '
            'being cautious of; BIR\'s own registration channels are '
            'free to use directly.',
      ],
    ),
    NuggetsBlock([
      'BIR registration is a separate system from DTI, SEC, or CDA '
          'registration.',
      'An existing taxpayer generally updates their registration for a '
          'new activity, rather than applying for a second TIN.',
      'What applies depends on the taxpayer, structure, activities, '
          'existing records, and current rules, none of which this '
          'course determines for any specific reader.',
      'Starting from the official bir.gov.ph site, rather than an '
          'unofficial agent or a look-alike site, is worth doing from '
          'the very first step.',
    ]),
    RiskWarningBlock(
      title: 'This course never determines your obligations',
      text:
          'What applies to a specific person or business depends on '
          'details only BIR\'s own records, and the current rules, can '
          'confirm. This course names what is worth checking; '
          'professional advice may help, and verifying directly with BIR '
          'always outranks a general lesson.',
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _mainTitle,
      canonicalUrl: _mainUrl,
      lastVerifiedDate: _mainVerified,
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
    CategorizeBlock(
      blockId: 'profile-first-step',
      categorizePrompt:
          'Match each fictional profile to what they should verify '
          'first.',
      buckets: [
        CategorizeBucket(
          id: 'check-existing',
          label: 'Check your existing registration',
        ),
        CategorizeBucket(
          id: 'confirm-process',
          label: 'Confirm the correct registration process',
        ),
        CategorizeBucket(
          id: 'review-requirements',
          label: 'Review the applicable official requirements',
        ),
        CategorizeBucket(
          id: 'professional-advice',
          label: 'Professional advice may help',
        ),
      ],
      items: [
        CategorizeItemDef(
          id: 'employee-freelance',
          label:
              'A fictional employee who just started freelance work on '
              'the side',
          explanation:
              'An employee with an existing TIN generally needs to '
              'confirm the correct process for adding a new activity, '
              'not assume a second TIN is needed.',
        ),
        CategorizeItemDef(
          id: 'online-seller',
          label: 'A fictional online seller beginning regular operations',
          explanation:
              'Starting regular operations for the first time generally '
              'means confirming the correct registration process before '
              'assuming what applies.',
        ),
        CategorizeItemDef(
          id: 'registered-sole-prop',
          label: 'A fictional sole proprietor already registered with BIR',
          explanation:
              'Someone already registered should check their existing '
              'registration first, rather than assuming it needs '
              'redoing.',
        ),
        CategorizeItemDef(
          id: 'newly-incorporated',
          label: 'A fictional newly incorporated business',
          explanation:
              'A new corporate entity generally has its own applicable '
              'requirements worth reviewing directly, distinct from a '
              'sole proprietor\'s.',
        ),
        CategorizeItemDef(
          id: 'first-worker',
          label: 'A fictional business hiring its first worker',
          explanation:
              'Hiring introduces employer-related obligations on top of '
              'everything else; professional advice may help sort out '
              'what changes.',
        ),
      ],
      correctBucketByItemId: {
        'employee-freelance': 'confirm-process',
        'online-seller': 'confirm-process',
        'registered-sole-prop': 'check-existing',
        'newly-incorporated': 'review-requirements',
        'first-worker': 'professional-advice',
      },
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'second-tin-myth',
      statement:
          'Starting a new business activity always means applying for a '
          'brand new TIN.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'A person is only ever meant to hold one TIN. A new activity '
          'generally means updating an existing registration, not '
          'applying for a second one; confirming the correct process '
          'directly with BIR is worth doing rather than assuming.',
      requiredForCompletion: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'According to this lesson, what does a person with an existing '
        'TIN generally do when starting a new business activity?',
    choices: [
      'Apply for a second TIN for the new activity',
      'Update their existing registration, generally without applying '
          'for a second TIN',
      'Nothing; BIR registration only applies to corporations',
    ],
    correctIndex: 1,
    explanation:
        'A single person is only ever meant to hold one TIN. This lesson '
        'names updating an existing registration as the general path, '
        'not a second TIN.',
    whyWrong:
        'Neither applying for a second TIN, nor assuming registration '
        'never applies to an individual, matches what this lesson says.',
  ),
  keyTakeaway:
      'BIR registration is separate from DTI, SEC, or CDA registration, '
      'an existing taxpayer generally updates rather than repeats it, and '
      'what applies to a specific reader depends on details only BIR\'s '
      'own records and current rules can confirm.',
);

// ---------------------------------------------------------------------------
// Lesson 2: Primary and Secondary Registration
// ---------------------------------------------------------------------------

const _primaryAndSecondaryRegistration = MoneyLesson(
  id: btaxPrimarySecondary,
  trackId: 'bir_registration_tax_setup',
  title: 'Primary and Secondary Registration',
  icon: 'document',
  minutes: 4,
  summary:
      'BIR registration is a general map, not one form: identification, '
      'business details, proof of registration, books, and invoicing all '
      'have their own place.',
  objective:
      'Order the general BIR registration map correctly, without '
      'memorizing current form numbers or document lists.',
  sections: [],
  governance: _governanceHigh,
  sources: [_regReq, _primaryReg, _secondaryReg, _newBizReg, _orus],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'BIR registration generally covers several things, not one '
            'single form: taxpayer identification, registering or '
            'updating business details, a certificate or proof of '
            'registration, books of accounts, and authority or '
            'registration related to invoicing. A business using an '
            'accounting system, loose-leaf books, or a POS-type system '
            'may also need a separate approval for that, when '
            'applicable.',
        'Available channels can include BIR\'s own online services, such '
            'as ORUS or the NewBizReg portal, or the Revenue District '
            'Office (RDO) that covers the business, depending on the '
            'transaction and current rules. Starting from the correct, '
            'official channel matters: ORUS is reached through '
            'orus.bir.gov.ph, and NewBizReg through BIR\'s own site, '
            'never through a look-alike domain or an unofficial agent '
            'offering to register on someone\'s behalf.',
      ],
    ),
    NuggetsBlock([
      'BIR registration generally covers identification, business '
          'details, proof of registration, books, and invoicing '
          'authority, not one single form.',
      'A business using an accounting system, loose-leaf books, or a '
          'POS-type system may need a separate approval for that, when '
          'applicable.',
      'Available channels can include BIR\'s own online services or the '
          'covering Revenue District Office, depending on the '
          'transaction.',
      'The official channels are reached through bir.gov.ph itself, '
          'never a look-alike domain or an unofficial paid agent.',
    ]),
    RiskWarningBlock(
      title: 'Start from the official channel, every time',
      text:
          'Exact document lists, form numbers, and channel availability '
          'can change, and paying an unofficial agent or using a '
          'look-alike site to register carries real risk. Confirming the '
          'current process and channel directly on bir.gov.ph, or with '
          'the covering Revenue District Office, is worth doing before '
          'registering anything.',
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _regReqTitle,
      canonicalUrl: _regReqUrl,
      lastVerifiedDate: _regReqVerified,
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _primaryRegTitle,
      canonicalUrl: _primaryRegUrl,
      lastVerifiedDate: _primaryRegVerified,
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _secondaryRegTitle,
      canonicalUrl: _secondaryRegUrl,
      lastVerifiedDate: _secondaryRegVerified,
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _newBizRegTitle,
      canonicalUrl: _newBizRegUrl,
      lastVerifiedDate: _newBizRegVerified,
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
    SortingBlock(
      blockId: 'registration-map-sequence',
      sortingPrompt: 'Put this general sequence in the order it should happen.',
      items: [
        SortingItemDef(
          id: 'verify-existing-tin',
          label: 'Verify whether the taxpayer already has a TIN',
        ),
        SortingItemDef(
          id: 'identify-transaction',
          label: 'Identify the correct BIR registration transaction',
        ),
        SortingItemDef(
          id: 'review-documentary-requirements',
          label: 'Review the current documentary requirements',
        ),
        SortingItemDef(
          id: 'complete-primary',
          label: 'Complete applicable primary registration',
        ),
        SortingItemDef(
          id: 'complete-secondary',
          label: 'Complete applicable secondary registration',
        ),
        SortingItemDef(
          id: 'save-confirmations',
          label: 'Save official confirmations',
        ),
        SortingItemDef(
          id: 'review-registered-obligations',
          label: 'Review the registered tax types and obligations',
        ),
      ],
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'orus-domain-myth',
      statement:
          'Any website with "orus" in its name is a safe place to '
          'register with BIR.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'BIR\'s own Online Registration and Update System is only '
          'reached through orus.bir.gov.ph. A look-alike domain, even '
          'one that looks similar, is not the official channel and is '
          'worth being cautious of.',
      requiredForCompletion: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'According to this lesson, is BIR registration generally '
        'completed with one single form?',
    choices: [
      'Yes, one form covers identification, books, and invoicing '
          'together',
      'No, it generally covers several separate pieces: identification, '
          'business details, proof of registration, books, and '
          'invoicing authority',
      'Only for a corporation; a sole proprietor only needs a TIN',
    ],
    correctIndex: 1,
    explanation:
        'This lesson\'s own map names several separate pieces, not one '
        'form, and notes an additional approval may apply for certain '
        'accounting or POS-type systems.',
    whyWrong:
        'Neither treating it as a single form, nor assuming it only '
        'applies to one structure type, matches what this lesson says.',
  ),
  keyTakeaway:
      'BIR registration generally covers identification, business '
      'details, proof of registration, books, and invoicing authority, '
      'reached through BIR\'s own official channels such as ORUS or the '
      'covering Revenue District Office, never a look-alike site or an '
      'unofficial paid agent.',
);

// ---------------------------------------------------------------------------
// Lesson 3: Know What You Registered For
// ---------------------------------------------------------------------------

const _knowWhatYouRegisteredFor = MoneyLesson(
  id: btaxKnowWhatYouRegisteredFor,
  trackId: 'bir_registration_tax_setup',
  title: 'Know What You Registered For',
  icon: 'balance',
  minutes: 3,
  summary:
      'A registration can carry several possible obligation categories, '
      'and not every one applies to every taxpayer.',
  objective:
      'Name the general obligation categories a registration can carry, '
      'without determining which apply to any specific reader.',
  sections: [],
  governance: _governanceHigh,
  sources: [_eopt, _regReq],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A BIR registration can carry several possible obligation '
            'categories: income tax, VAT or another applicable business '
            'tax, withholding obligations, employer-related obligations '
            'if workers are hired, and any other tax the business is '
            'registered for. Not every category applies to every '
            'taxpayer, and this course cannot determine which ones apply '
            'to any specific reader.',
        'Filing and payment responsibilities can also sit on different '
            'schedules from each other, and a return can still need '
            'attention even when no payment is expected, depending on '
            'the registered obligation and the current rules. The only '
            'reliable way to know which categories, forms, and schedules '
            'apply is to review the official registration record '
            'directly and check the current BIR rules, or ask a '
            'qualified tax professional.',
      ],
    ),
    NuggetsBlock([
      'A registration can carry several possible obligation categories: '
          'income tax, VAT or another business tax, withholding, and '
          'employer-related obligations.',
      'Not every category applies to every taxpayer, and this course '
          'never determines which ones apply to any specific reader.',
      'Filing and payment can sit on different schedules, and a return '
          'can still be due even when no payment is expected.',
    ]),
    RiskWarningBlock(
      title: 'No comparison, no recommendation, no determination',
      text:
          'This lesson never compares or recommends between VAT and '
          'non-VAT registration, optional tax rates, graduated versus '
          'flat-rate treatment, itemized versus optional deductions, or '
          'corporate tax regimes, and never determines which obligation '
          'category applies to a specific reader. Reviewing the official '
          'registration record and current BIR rules, or asking a '
          'qualified tax professional, is the reliable way to know.',
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _eoptTitle,
      canonicalUrl: _eoptUrl,
      lastVerifiedDate: _eoptVerified,
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _regReqTitle,
      canonicalUrl: _regReqUrl,
      lastVerifiedDate: _regReqVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ChecklistBlock(
      blockId: 'obligation-verify-questions',
      checklistPrompt:
          'Questions worth verifying, privately. Nothing here is saved '
          'or shared, and none of it asks for real tax details.',
      items: [
        ChecklistItemDef(
          id: 'which-tax-types',
          label:
              'Which tax types appear in the official registration '
              'record',
          required: false,
        ),
        ChecklistItemDef(
          id: 'which-returns',
          label: 'Which returns are required',
          required: false,
        ),
        ChecklistItemDef(
          id: 'how-often',
          label: 'How often each return must be filed',
          required: false,
        ),
        ChecklistItemDef(
          id: 'where-to-file',
          label: 'Where filing and payment should happen',
          required: false,
        ),
        ChecklistItemDef(
          id: 'withholding-applicable',
          label: 'Whether withholding is applicable',
          required: false,
        ),
      ],
      allRequiredMustBeChecked: false,
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'no-payment-no-return-myth',
      statement:
          'If no payment is expected for a period, no return needs to '
          'be filed either.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'A return can still need attention even when no payment is '
          'expected, depending on the registered obligation and the '
          'current rules. Filing and payment are not always the same '
          'action.',
      requiredForCompletion: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'According to this lesson, does this course determine which '
        'obligation categories apply to a specific reader?',
    choices: [
      'Yes, based on the structure the reader chose earlier in this '
          'path',
      'No, that depends on the official registration record and '
          'current rules, which this course does not have',
      'Only for VAT; every other category is assumed to apply',
    ],
    correctIndex: 1,
    explanation:
        'This lesson names the possible categories but explicitly never '
        'determines which apply to any specific reader; that depends on '
        'the official record and current rules.',
    whyWrong:
        'Neither guessing from an earlier structure choice, nor '
        'assuming most categories apply by default, matches what this '
        'lesson actually does.',
  ),
  keyTakeaway:
      'A registration can carry several possible obligation categories, '
      'not every one applies to every taxpayer, filing and payment can '
      'sit on different schedules, and only the official registration '
      'record and current rules, or a qualified tax professional, can '
      'say which categories actually apply.',
);

// ---------------------------------------------------------------------------
// Lesson 4: Invoices, Books, and Proof
// ---------------------------------------------------------------------------

const _invoicesBooksAndProof = MoneyLesson(
  id: btaxInvoicesBooksProof,
  trackId: 'bir_registration_tax_setup',
  title: 'Invoices, Books, and Proof',
  icon: 'flow',
  minutes: 4,
  summary:
      'Compliant invoices, complete books, and saved confirmations are '
      'the control system behind every filing.',
  objective:
      'Sort fictional records by type, without deciding whether any '
      'expense is deductible.',
  sections: [],
  governance: _governanceHigh,
  sources: [_eopt, _secondaryReg],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A compliant invoice or receipt, a complete set of books, and '
            'saved filing and payment confirmations together form the '
            'control system behind every return. Recording every sale, '
            'recording supported business expenses, keeping business and '
            'personal money separate, and reconciling records regularly '
            'all feed into that same system.',
        'Under the current Ease of Paying Taxes rules, invoicing and '
            'receipt requirements have changed in recent years; the '
            'current rule is worth checking directly on BIR\'s own site '
            'rather than relying on an older description. This lesson '
            'never generates an invoice template, an official form, or a '
            'book-of-accounts format, and never decides whether a '
            'specific expense is deductible.',
      ],
    ),
    NuggetsBlock([
      'A compliant invoice or receipt, complete books, and saved '
          'confirmations together are the control system behind every '
          'filing.',
      'Keeping business and personal money separate makes every other '
          'record easier to trust.',
      'Invoicing and receipt requirements have changed under current '
          'Ease of Paying Taxes rules; checking the current rule '
          'directly is worth doing.',
      'This lesson never decides whether a specific expense is '
          'deductible; that depends on current rules and the details of '
          'the expense.',
    ]),
    RiskWarningBlock(
      title: 'Record quality, not a deductibility ruling',
      text:
          'This lesson teaches why good records matter and never '
          'decides whether a specific expense is deductible, generates '
          'an invoice template, or produces an official form or a '
          'book-of-accounts format. A qualified tax professional and the '
          'current BIR rules are the reliable sources for those '
          'questions.',
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _eoptTitle,
      canonicalUrl: _eoptUrl,
      lastVerifiedDate: _eoptVerified,
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _secondaryRegTitle,
      canonicalUrl: _secondaryRegUrl,
      lastVerifiedDate: _secondaryRegVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    CategorizeBlock(
      blockId: 'record-sorting',
      categorizePrompt: 'Sort each fictional record by what it actually is.',
      buckets: [
        CategorizeBucket(id: 'customer-invoice', label: 'Customer invoice'),
        CategorizeBucket(id: 'supplier-invoice', label: 'Supplier invoice'),
        CategorizeBucket(id: 'business-expense', label: 'Business expense'),
        CategorizeBucket(id: 'personal-expense', label: 'Personal expense'),
        CategorizeBucket(
          id: 'filing-confirmation',
          label: 'Filing confirmation',
        ),
        CategorizeBucket(
          id: 'payment-confirmation',
          label: 'Payment confirmation',
        ),
        CategorizeBucket(
          id: 'unsupported-transfer',
          label: 'Bank transfer without supporting documentation',
        ),
      ],
      items: [
        CategorizeItemDef(
          id: 'sale-slip',
          label:
              'A fictional printed slip a business gave a customer after '
              'a sale',
          explanation:
              'A record given to a customer for a sale is a customer '
              'invoice or receipt.',
        ),
        CategorizeItemDef(
          id: 'wholesale-bill',
          label:
              'A fictional bill a business received from a wholesale '
              'supplier',
          explanation: 'A bill received from a supplier is a supplier invoice.',
        ),
        CategorizeItemDef(
          id: 'office-supplies-receipt',
          label:
              'A fictional receipt for office supplies used for the '
              'business',
          explanation:
              'A supported cost incurred for the business is a business '
              'expense record, though whether it is deductible still '
              'depends on current rules, not this lesson.',
        ),
        CategorizeItemDef(
          id: 'family-dinner-receipt',
          label: 'A fictional receipt for a family dinner',
          explanation:
              'A cost with no business purpose is a personal expense, '
              'not a business record.',
        ),
        CategorizeItemDef(
          id: 'efps-acknowledgment',
          label:
              'A fictional emailed acknowledgment after submitting a '
              'return online',
          explanation:
              'An acknowledgment that a return was submitted is a filing '
              'confirmation, worth saving on its own.',
        ),
        CategorizeItemDef(
          id: 'payment-receipt',
          label:
              'A fictional bank receipt showing a tax payment went '
              'through',
          explanation:
              'A record that a payment was made is a payment '
              'confirmation, and filing and paying are separate steps '
              'worth confirming separately.',
        ),
        CategorizeItemDef(
          id: 'unexplained-transfer',
          label:
              'A fictional bank transfer between two accounts with no '
              'attached receipt or explanation',
          explanation:
              'A transfer with no supporting documentation is exactly '
              'the kind of gap that makes reconciling records harder '
              'later; this is the example worth avoiding, not '
              'following.',
        ),
      ],
      correctBucketByItemId: {
        'sale-slip': 'customer-invoice',
        'wholesale-bill': 'supplier-invoice',
        'office-supplies-receipt': 'business-expense',
        'family-dinner-receipt': 'personal-expense',
        'efps-acknowledgment': 'filing-confirmation',
        'payment-receipt': 'payment-confirmation',
        'unexplained-transfer': 'unsupported-transfer',
      },
      requiredForCompletion: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'According to this lesson, does it ever decide whether a '
        'specific fictional expense is tax deductible?',
    choices: [
      'Yes, every business-expense record in the exercise is marked '
          'deductible',
      'No, it sorts records by type and teaches record quality, never a '
          'deductibility decision',
      'Only personal expenses are marked non-deductible; everything '
          'else is deductible',
    ],
    correctIndex: 1,
    explanation:
        'This lesson\'s own explanations sort records by type and note '
        'that deductibility still depends on current rules, never '
        'stating a deductibility conclusion itself.',
    whyWrong:
        'Neither marking every business record deductible, nor drawing '
        'a blanket line at personal expenses, matches what this lesson '
        'actually does.',
  ),
  keyTakeaway:
      'A compliant invoice, complete books, and saved filing and '
      'payment confirmations are the control system behind every '
      'return; sorting records by type is worth doing regularly, and '
      'whether any specific expense is deductible always depends on '
      'current rules, never on this lesson.',
);

// ---------------------------------------------------------------------------
// Lesson 5: Build a Filing Routine
// ---------------------------------------------------------------------------

const _buildAFilingRoutine = MoneyLesson(
  id: btaxFilingRoutine,
  trackId: 'bir_registration_tax_setup',
  title: 'Build a Filing Routine',
  icon: 'plan',
  minutes: 3,
  summary:
      'Filing and paying are separate actions, and a routine that treats '
      'them that way catches gaps before a deadline does.',
  objective:
      'Build a general filing-readiness routine, without hardcoding a '
      'tax-calendar date.',
  sections: [],
  governance: _governanceHigh,
  sources: [_taxReminder, _eopt],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A general filing routine looks like this: review registered '
            'obligations, find the current official deadline, prepare '
            'records before that deadline, use the applicable official '
            'filing channel, use an authorized payment channel when '
            'payment is due, save filing and payment confirmations, '
            'reconcile the transaction in the business\'s own records, '
            'and resolve any error through official channels.',
        'Filing and paying are separate actions, and treating them as '
            'the same step is a common gap. BIR\'s own Tax Reminder page '
            'is a useful place to check the current deadline calendar, '
            'rather than relying on a date remembered from a previous '
            'year or an unofficial source.',
      ],
    ),
    NuggetsBlock([
      'Filing and paying are separate actions; treating them as one '
          'step is a common gap.',
      'The current official deadline is worth checking directly, not '
          'assumed from a previous year.',
      'Saving both filing and payment confirmations, and reconciling '
          'them in the business\'s own records, closes the loop.',
      'Any error is worth resolving through an official BIR channel, '
          'not an unofficial shortcut.',
    ]),
    RiskWarningBlock(
      title: 'A routine, not a completed filing',
      text:
          'This lesson never treats a filing as completed without an '
          'official confirmation, and never states a current deadline as '
          'a fixed date. Checking BIR\'s own current Tax Reminder or '
          'official resource for the real date is worth doing every '
          'time, since deadlines can change.',
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _taxReminderTitle,
      canonicalUrl: _taxReminderUrl,
      lastVerifiedDate: _taxReminderVerified,
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
      blockId: 'deadline-readiness-checklist',
      checklistPrompt:
          'A general readiness checklist. Nothing here creates a real '
          'deadline or files anything.',
      items: [
        ChecklistItemDef(
          id: 'obligation-identified',
          label: 'Obligation identified',
          required: false,
        ),
        ChecklistItemDef(
          id: 'official-deadline-checked',
          label: 'Official deadline checked',
          required: false,
        ),
        ChecklistItemDef(
          id: 'records-prepared',
          label: 'Records prepared',
          required: false,
        ),
        ChecklistItemDef(
          id: 'return-reviewed',
          label: 'Return reviewed',
          required: false,
        ),
        ChecklistItemDef(
          id: 'filing-confirmed',
          label: 'Filing confirmed',
          required: false,
        ),
        ChecklistItemDef(
          id: 'payment-confirmed',
          label: 'Payment confirmed when applicable',
          required: false,
        ),
        ChecklistItemDef(
          id: 'proof-stored',
          label: 'Proof stored securely',
          required: false,
        ),
      ],
      allRequiredMustBeChecked: false,
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'filed-and-paid-are-same-myth',
      statement:
          'Filing a return and paying what is owed are the same '
          'single action.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Filing and payment can be separate actions, sometimes through '
          'different channels. Confirming both separately is part of a '
          'real filing routine.',
      requiredForCompletion: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'According to this lesson, are filing a return and paying what '
        'is owed always the same action?',
    choices: [
      'Yes, submitting a return automatically completes the payment too',
      'No, they can be separate actions, sometimes through different '
          'channels, and both are worth confirming',
      'Only for a corporation; a sole proprietor files and pays in one '
          'step',
    ],
    correctIndex: 1,
    explanation:
        'This lesson explicitly separates filing and paying as two '
        'confirmable steps, not one automatic action.',
    whyWrong:
        'Neither assuming payment happens automatically, nor limiting '
        'the distinction to one structure type, matches this lesson.',
  ),
  keyTakeaway:
      'A general filing routine reviews the obligation, checks the '
      'current official deadline, prepares records, files and pays '
      'through official channels, saves both confirmations, and '
      'reconciles the result; filing and paying are separate actions '
      'worth confirming separately.',
);

// ---------------------------------------------------------------------------
// Lesson 6: Create Your Tax Money System
// ---------------------------------------------------------------------------

const _createYourTaxMoneySystem = MoneyLesson(
  id: btaxMoneySystem,
  trackId: 'bir_registration_tax_setup',
  title: 'Create Your Tax Money System',
  icon: 'plan',
  minutes: 3,
  summary:
      'A short, personal routine tying registration, records, and '
      'filing together, and a few real next steps in Salapify if any of '
      'them fit.',
  objective:
      'Build a general tax-money routine and pick next steps, without '
      'creating anything automatically.',
  sections: [],
  governance: _governanceHigh,
  sources: [_taxReminder, _main],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A tax-money system ties this course together: keeping business '
            'and personal money separate, categorizing income and '
            'supported expenses, reviewing records weekly, reconciling '
            'monthly, estimating a tax reserve with a qualified '
            'professional or a verified method, and moving that reserve '
            'into a separate budget or account. Reviewing official '
            'filing dates and keeping a compliance buffer round out a '
            'realistic system.',
        'None of this is calculated or decided by this lesson. Every '
            'step here points at an official source, a real Salapify '
            'screen, or a qualified professional, never a number this '
            'course invents.',
      ],
    ),
    NuggetsBlock([
      'Keeping business and personal money separate makes every other '
          'step easier.',
      'A tax reserve is worth estimating with a qualified professional '
          'or a verified method, never guessed at.',
      'Reviewing official filing dates and keeping a compliance buffer '
          'are both worth building into a routine, not left to memory.',
      'Registration details can change; updating this routine when they '
          'do is part of keeping it real.',
    ]),
    RiskWarningBlock(
      title: 'A routine to build, not a number this lesson gives',
      text:
          'This lesson never estimates a tax reserve amount, a deadline, '
          'or a filing status for any specific reader. It only names '
          'what a realistic routine includes and, where a real Salapify '
          'feature already exists, offers to open it.',
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _taxReminderTitle,
      canonicalUrl: _taxReminderUrl,
      lastVerifiedDate: _taxReminderVerified,
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _mainTitle,
      canonicalUrl: _mainUrl,
      lastVerifiedDate: _mainVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ChecklistBlock(
      blockId: 'tax-money-system-checklist',
      checklistPrompt:
          'A personal system to build at your own pace. Offline, and '
          'yours to keep.',
      items: [
        ChecklistItemDef(
          id: 'money-separated',
          label: 'Business and personal money are kept separate',
          required: false,
        ),
        ChecklistItemDef(
          id: 'categorized',
          label: 'Income and supported expenses are categorized',
          required: false,
        ),
        ChecklistItemDef(
          id: 'weekly-review',
          label: 'Records are reviewed weekly',
          required: false,
        ),
        ChecklistItemDef(
          id: 'monthly-reconcile',
          label: 'Records are reconciled monthly',
          required: false,
        ),
        ChecklistItemDef(
          id: 'reserve-estimated',
          label:
              'A tax reserve has been estimated with a qualified '
              'professional or a verified method',
          required: false,
        ),
        ChecklistItemDef(
          id: 'reserve-moved',
          label:
              'The chosen reserve is moved into a separate budget or '
              'account',
          required: false,
        ),
        ChecklistItemDef(
          id: 'filing-dates-reviewed',
          label: 'Official filing dates are reviewed regularly',
          required: false,
        ),
        ChecklistItemDef(
          id: 'buffer-kept',
          label: 'A compliance buffer is kept on hand',
          required: false,
        ),
        ChecklistItemDef(
          id: 'plan-updated',
          label: 'The plan is updated when registration details change',
          required: false,
        ),
      ],
      allRequiredMustBeChecked: false,
      requiredForCompletion: false,
    ),
    MythOrFactBlock(
      blockId: 'system-auto-creates-myth',
      statement:
          'Working through this checklist automatically creates a '
          'budget, an account, a goal, or a reminder.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Nothing here creates or changes a financial record '
          'automatically. Each destination named in this lesson still '
          'needs your own confirmation inside that screen before '
          'anything is saved.',
      requiredForCompletion: true,
    ),
    SalapifyActionsBlock(
      blockId: 'tax-money-system-actions',
      menuPrompt:
          'A few real next steps, if any of them fit. Choose up to '
          'three.',
      actions: [
        SalapifyActionDef(
          id: 'start-tax-reserve-goal',
          label: 'Start a tax-reserve savings goal',
          description:
              'Opens Goals to check or start a goal for a tax reserve. '
              'Nothing is created or changed until something is saved '
              'there.',
          route: 'goals',
        ),
        SalapifyActionDef(
          id: 'review-budget-for-reserve',
          label: 'Review Budget for a tax-reserve line',
          description:
              'Opens Budget to check what is already spoken for this '
              'period before setting money aside for a tax reserve. '
              'Nothing changes automatically.',
          route: 'budget',
        ),
        SalapifyActionDef(
          id: 'track-reserve-as-recurring',
          label: 'Track a periodic tax reserve as a recurring set-aside',
          description:
              'Opens Recurring, where a periodic set-aside like a '
              'quarterly tax reserve can already be tracked if you '
              'choose to add one. Nothing is created automatically.',
          route: 'recurring',
        ),
        SalapifyActionDef(
          id: 'open-filing-reminders',
          label: 'Open reminders',
          description:
              'Opens Notifications and security, where reminders can be '
              'turned on. There is no filing-specific reminder type yet, '
              'so nothing is scheduled automatically; this is the '
              'closest real screen for building a periodic filing '
              'check-in by hand.',
          route: 'notifications',
        ),
      ],
    ),
  ],
  check: KnowledgeCheck(
    question:
        'Does completing this tax-money system checklist automatically '
        'create a goal, budget line, recurring set-aside, or reminder?',
    choices: [
      'Yes, automatically, once the checklist is complete',
      'No, each screen still needs your own confirmation before '
          'anything is created or changed',
      'Only the reminder is created automatically',
    ],
    correctIndex: 1,
    explanation:
        'Every action offered here only opens a real Salapify screen; '
        'nothing is created or changed until it is confirmed there.',
    whyWrong:
        'No action in this lesson creates or changes anything '
        'automatically, the reminder included.',
  ),
  keyTakeaway:
      'A tax-money system separates business and personal money, '
      'categorizes and reconciles regularly, estimates a reserve with a '
      'qualified professional or a verified method, and reviews '
      'official filing dates; turning any of it into a real goal, '
      'budget line, recurring set-aside, or reminder in Salapify still '
      'needs your own confirmation inside that screen.',
);
