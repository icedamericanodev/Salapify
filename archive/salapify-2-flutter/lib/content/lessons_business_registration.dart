// Money Courses Phase 13: "Build Your Business", a new learning path's first
// course, "Start Your Business Legally" (course id
// 'start_a_business_legally'). Uses the same expansion architecture every
// course from Phase 6 onward already ships: content/learning_path.dart's
// LearningPath/LearningPathGroup model, content/lesson_model.dart's
// governance and source metadata, content/lesson_blocks.dart's risk-warning
// and educational-boundary blocks, and content/interaction_blocks.dart's
// Phase 5 interactions. Separate content file, separate lesson ids, never
// touching the core 22 lessons or any earlier expansion course.
//
// This course teaches ORIENTATION, never a filing. It never names which
// structure to choose, never promises a registration will be approved or
// how long it will take, never treats business-name or entity-name
// registration as trademark protection, and never implies Salapify is
// affiliated with any government agency. House rules, same as every earlier
// expansion course: plain English, no em or en dashes, no fictional example
// presented as a real business, no personal recommendation. No fee,
// processing time, validity period, required document, portal procedure,
// capital requirement, foreign-ownership rule, or industry-specific
// requirement is embedded anywhere in this file; those are exactly the
// high-volatility facts this phase's own instructions say to omit from a
// foundations course rather than pin to a date that will go stale.
//
// Sources: the Philippine Business Hub's own business-application-process
// page, DTI's Business Name Registration System FAQ and registration guide,
// SEC's eSPARC company-registration selection page, the Cooperative
// Development Authority's own registration page, IPOPHL's trademark and
// trademark-filing pages, and the Bureau of Internal Revenue's own site.
// Every one of these eight official pages was independently confirmed to
// exist and to cover the topic cited, through WebSearch against its own
// domain (gov.ph fetches return a uniform 403 in this environment, the same
// limitation every earlier expansion course's own header notes), per this
// repository's rule that a Money Courses official-source URL needs a real
// search, not just a cite. Reviewed by the legal-compliance-counsel persona
// in read-only mode before this course shipped (see governance.reviewerId
// below).

import 'interaction_blocks.dart';
import 'lesson_blocks.dart';
import 'lesson_model.dart';

// Plain string constants, not fields on a shared object: see
// lessons_ph_government_securities.dart's own comment on why a const
// OfficialSourceBlock call needs these as top-level identifiers rather than
// reading them off a const LessonSourceInfo instance's field.
const _pbhAgency = 'Philippine Business Hub';
const _pbhTitle = 'Business Application Process';
const _pbhUrl = 'https://business.gov.ph/business-application-process';
const _pbhVerified = '2026-08';

const _pbh = LessonSourceInfo(
  agency: _pbhAgency,
  title: _pbhTitle,
  canonicalUrl: _pbhUrl,
  lastVerifiedDate: _pbhVerified,
);

const _dtiAgency = 'Department of Trade and Industry (DTI)';
const _dtiFaqTitle =
    'Business Name Registration System, Frequently Asked '
    'Questions';
const _dtiFaqUrl = 'https://bnrs.dti.gov.ph/faq';
const _dtiFaqVerified = '2026-08';

const _dtiFaq = LessonSourceInfo(
  agency: _dtiAgency,
  title: _dtiFaqTitle,
  canonicalUrl: _dtiFaqUrl,
  lastVerifiedDate: _dtiFaqVerified,
);

const _dtiGuideTitle =
    'Business Name Registration System, Registration '
    'Guide';
const _dtiGuideUrl = 'https://bnrs.dti.gov.ph/resources/registration-guide';
const _dtiGuideVerified = '2026-08';

const _dtiGuide = LessonSourceInfo(
  agency: _dtiAgency,
  title: _dtiGuideTitle,
  canonicalUrl: _dtiGuideUrl,
  lastVerifiedDate: _dtiGuideVerified,
);

const _secAgency = 'Securities and Exchange Commission Philippines (SEC)';
const _secTitle = 'eSPARC, Company Registration Application Selection';
const _secUrl = 'https://esparc.sec.gov.ph/application/selection';
const _secVerified = '2026-08';

const _sec = LessonSourceInfo(
  agency: _secAgency,
  title: _secTitle,
  canonicalUrl: _secUrl,
  lastVerifiedDate: _secVerified,
);

const _cdaAgency = 'Cooperative Development Authority (CDA)';
const _cdaTitle = 'Registration';
const _cdaUrl = 'https://cda.gov.ph/services/regulatory-services/registration/';
const _cdaVerified = '2026-08';

const _cda = LessonSourceInfo(
  agency: _cdaAgency,
  title: _cdaTitle,
  canonicalUrl: _cdaUrl,
  lastVerifiedDate: _cdaVerified,
);

const _ipophlAgency =
    'Intellectual Property Office of the Philippines '
    '(IPOPHL)';
const _ipophlInfoTitle = 'Trademark';
const _ipophlInfoUrl = 'https://www.ipophil.gov.ph/trademark/';
const _ipophlInfoVerified = '2026-08';

const _ipophlInfo = LessonSourceInfo(
  agency: _ipophlAgency,
  title: _ipophlInfoTitle,
  canonicalUrl: _ipophlInfoUrl,
  lastVerifiedDate: _ipophlInfoVerified,
);

const _ipophlFilingTitle = 'Trademark Filing';
const _ipophlFilingUrl = 'https://www.ipophil.gov.ph/trademark/filing/';
const _ipophlFilingVerified = '2026-08';

const _ipophlFiling = LessonSourceInfo(
  agency: _ipophlAgency,
  title: _ipophlFilingTitle,
  canonicalUrl: _ipophlFilingUrl,
  lastVerifiedDate: _ipophlFilingVerified,
);

const _birAgency = 'Bureau of Internal Revenue (BIR)';
const _birTitle = 'Bureau of Internal Revenue';
const _birUrl = 'https://www.bir.gov.ph/';
const _birVerified = '2026-08';

const _bir = LessonSourceInfo(
  agency: _birAgency,
  title: _birTitle,
  canonicalUrl: _birUrl,
  lastVerifiedDate: _birVerified,
);

const _governance = LessonGovernance(
  volatility: ContentVolatility.annual,
  reviewStatus: ReviewStatus.verified,
  lastVerifiedDate: '2026-08',
  reviewDueDate: '2027-08',
  reviewerId: 'LCC',
);

const _boundary = EducationalBoundaryBlock(
  sourceLabel:
      'the Department of Trade and Industry, the Securities and Exchange '
      'Commission, the Cooperative Development Authority, the Intellectual '
      'Property Office of the Philippines, and the Bureau of Internal '
      'Revenue',
  examplesAreFictional: true,
);

/// Lesson ids, exactly as specified for this course, stable and free-form,
/// the same "never reused once a learner has real progress recorded"
/// convention every earlier expansion course's own ids follow (see
/// money/expansion_progress.dart).
const brBeforeYouRegister = 'before_you_register';
const brCompareBusinessStructures = 'compare_business_structures';
const brMatchStructureToAgency = 'match_structure_to_agency';
const brBusinessNameAndBrand = 'business_name_and_brand';
const brRegistrationIsNotPermission = 'registration_is_not_permission';
const brBuildRegistrationRoadmap = 'build_registration_roadmap';

/// The six lessons, in reading order. Never added to lessons.dart's flat
/// `lessons` list, and never merged into any other course's own list: see
/// test/lessons_business_registration_content_test.dart's own isolation
/// checks.
const List<MoneyLesson> startABusinessLegallyLessons = [
  _beforeYouRegister,
  _compareBusinessStructures,
  _matchStructureToAgency,
  _businessNameAndBrand,
  _registrationIsNotPermission,
  _buildRegistrationRoadmap,
];

// ---------------------------------------------------------------------------
// Lesson 1: Before You Register
// ---------------------------------------------------------------------------

const _beforeYouRegister = MoneyLesson(
  id: brBeforeYouRegister,
  trackId: 'start_a_business_legally',
  title: 'Before You Register',
  icon: 'checklist',
  minutes: 3,
  summary:
      'A short, private checklist to work through before comparing business '
      'structures or looking into a registration agency.',
  objective:
      'Clarify the basics of a business idea honestly before comparing '
      'structures or agencies.',
  sections: [],
  governance: _governance,
  sources: [_pbh],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A few basics are worth naming honestly before comparing business '
            'structures or looking into a specific registration agency. '
            'None of this needs to be shared or saved anywhere outside '
            'this device; it is simply worth thinking through first.',
        'What the business would actually sell or do, how many owners or '
            'partners are involved, whether outside investors might come '
            'in later, and personal comfort with financial risk all shape '
            'which structure is even worth investigating. So does whether '
            'the activity might be a regulated one, a general planned '
            'location, and whether workers might be hired.',
        'Clarifying these does not require a business name, an address, '
            'an income figure, an owner\'s name, or anything filed with a '
            'government agency. It is a private starting point, not a '
            'form.',
      ],
    ),
    NuggetsBlock([
      'Ownership and outside investors change which structures are worth '
          'investigating, so clarifying that first saves rework later.',
      'A regulated activity can add its own requirements on top of the '
          'usual registration steps, so checking whether that might apply '
          'is worth doing early.',
      'None of this needs a real business name, address, or government '
          'detail; it stays private to this device.',
    ]),
    RiskWarningBlock(
      title: 'Clarify before comparing structures',
      text:
          'Structure and registration choices are generally easier to '
          'change before registering than after. Taking a moment to '
          'clarify the basics first can avoid redoing paperwork later.',
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
      blockId: 'before-you-register-checklist',
      checklistPrompt:
          'Work through this privately. Nothing here is saved or shared.',
      items: [
        ChecklistItemDef(
          id: 'product-or-service',
          label: 'What the business would actually sell or do is clear',
          required: false,
        ),
        ChecklistItemDef(
          id: 'owners-named',
          label: 'How many owners or partners are involved is clear',
          required: false,
        ),
        ChecklistItemDef(
          id: 'outside-investors',
          label:
              'Whether outside investors might be involved has been '
              'considered',
          required: false,
        ),
        ChecklistItemDef(
          id: 'personal-risk',
          label: 'Personal comfort with financial risk has been considered',
          required: false,
        ),
        ChecklistItemDef(
          id: 'regulated-check',
          label:
              'Whether the activity might be a regulated one has been '
              'considered',
          required: false,
        ),
        ChecklistItemDef(
          id: 'planned-location',
          label: 'A general planned location has been considered',
          required: false,
        ),
        ChecklistItemDef(
          id: 'hiring-workers',
          label: 'Whether workers might be hired has been considered',
          required: false,
        ),
      ],
      allRequiredMustBeChecked: false,
      requiredForCompletion: true,
    ),
    ReflectionPromptBlock(
      blockId: 'readiness-outcome-reflect',
      question:
          'Which of these best describes where the business idea stands '
          'right now?',
      choices: [
        ReflectionChoice(
          id: 'clarify-model',
          label: 'Clarify the business model first',
        ),
        ReflectionChoice(
          id: 'ownership-discuss',
          label: 'Ownership needs discussion',
        ),
        ReflectionChoice(
          id: 'check-regulated',
          label: 'Check whether the activity is regulated',
        ),
        ReflectionChoice(
          id: 'ready-compare',
          label: 'Ready to compare structures',
        ),
      ],
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'According to this lesson, what is worth doing before comparing '
        'business structures or agencies?',
    choices: [
      'Clarifying the basics honestly, like ownership, risk comfort, and '
          'whether the activity is regulated',
      'Registering a business name first, then figuring out the rest',
      'Picking whichever structure is fastest to register',
    ],
    correctIndex: 0,
    explanation:
        'This lesson\'s own checklist is exactly this: naming the basics '
        'honestly before comparing structures or looking into an agency.',
    whyWrong:
        'Registering first, or picking based on speed alone, skips the '
        'clarifying step this lesson is built around.',
  ),
  keyTakeaway:
      'A few honest basics, product or service, ownership, outside '
      'investors, personal-risk comfort, whether the activity is '
      'regulated, location, and hiring, are worth clarifying privately '
      'before comparing business structures or agencies.',
);

// ---------------------------------------------------------------------------
// Lesson 2: Compare Business Structures
// ---------------------------------------------------------------------------

const _compareBusinessStructures = MoneyLesson(
  id: brCompareBusinessStructures,
  trackId: 'start_a_business_legally',
  title: 'Compare Business Structures',
  icon: 'balance',
  minutes: 4,
  summary:
      'A high-level look at five business structures, across ownership, '
      'liability, governance, continuity, recordkeeping, funding, and '
      'registration agency. No structure is called the best.',
  objective:
      'Describe how five business structures differ at a high level, '
      'without naming one as the best, cheapest, safest, or easiest.',
  sections: [],
  governance: _governance,
  sources: [_dtiFaq, _sec, _cda],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A sole proprietorship, a partnership, a One Person Corporation, '
            'a corporation with multiple owners, and a cooperative are '
            'five different ways to structure a business in the '
            'Philippines. They differ in who owns them, whether the '
            'business has a legal identity separate from its owners, how '
            'liability generally works, how decisions are governed, how '
            'the business continues, how much recordkeeping and reporting '
            'it carries, how it is generally funded, and which agency '
            'generally registers it.',
        'None of these differences makes one structure universally best, '
            'cheapest, safest, easiest, or most tax efficient. What fits '
            'depends on the owners, the activity, and circumstances this '
            'lesson does not know. Professional legal, accounting, or tax '
            'advice may be useful before deciding.',
      ],
    ),
    NuggetsBlock([
      'A sole proprietorship and a One Person Corporation both fit a '
          'single owner, but they differ in legal personality and are '
          'registered with different agencies.',
      'A partnership and a corporation both fit more than one owner, but '
          'they differ in governance and in how liability is generally '
          'shared.',
      'A cooperative is organized around its members rather than around '
          'shareholders, with its own governance and its own registration '
          'agency.',
    ]),
    RiskWarningBlock(
      title: 'No structure is universally best',
      text:
          'Every structure trades one thing for another, and the right '
          'one depends on circumstances only the owners know. Nothing in '
          'this course ranks these structures against each other; '
          'professional legal, accounting, or tax advice may be useful '
          'before deciding.',
    ),
    OfficialSourceBlock(
      agency: _dtiAgency,
      sourceTitle: _dtiFaqTitle,
      canonicalUrl: _dtiFaqUrl,
      lastVerifiedDate: _dtiFaqVerified,
    ),
    OfficialSourceBlock(
      agency: _secAgency,
      sourceTitle: _secTitle,
      canonicalUrl: _secUrl,
      lastVerifiedDate: _secVerified,
    ),
    OfficialSourceBlock(
      agency: _cdaAgency,
      sourceTitle: _cdaTitle,
      canonicalUrl: _cdaUrl,
      lastVerifiedDate: _cdaVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ComparisonBlock(
      blockId: 'structure-comparison',
      title: 'A high-level comparison, not a recommendation',
      criteria: [
        ComparisonCriterion(id: 'owners', label: 'Owners'),
        ComparisonCriterion(
          id: 'legal-personality',
          label: 'Separate legal personality',
        ),
        ComparisonCriterion(id: 'liability', label: 'Liability'),
        ComparisonCriterion(id: 'governance', label: 'Governance'),
        ComparisonCriterion(id: 'continuity', label: 'Continuity'),
        ComparisonCriterion(
          id: 'recordkeeping',
          label: 'Recordkeeping and reporting',
        ),
        ComparisonCriterion(id: 'funding', label: 'Funding'),
        ComparisonCriterion(id: 'agency', label: 'Registration agency'),
      ],
      items: [
        ComparisonItem(
          id: 'sole-prop',
          name: 'Sole proprietorship',
          valuesByCriterionId: {
            'owners': 'One individual owner.',
            'legal-personality':
                'No separate legal personality; the owner and the '
                'business are the same in law.',
            'liability':
                'The owner is generally personally liable for the '
                'business\'s obligations, with no legal separation.',
            'governance': 'Decisions rest with the individual owner.',
            'continuity':
                'Generally tied to the owner, unlike a structure with its '
                'own separate legal personality.',
            'recordkeeping':
                'Generally simpler recordkeeping, though basic '
                'bookkeeping and tax filing still apply.',
            'funding':
                'Generally funded from the owner\'s own resources or '
                'personal borrowing.',
            'agency':
                'A business name is generally registered with the '
                'Department of Trade and Industry.',
          },
          caution:
              'A sole proprietor\'s personal assets are not automatically '
              'separated from the business\'s obligations.',
        ),
        ComparisonItem(
          id: 'partnership',
          name: 'Partnership',
          valuesByCriterionId: {
            'owners': 'Two or more partners.',
            'legal-personality':
                'Generally has a separate legal personality from its '
                'partners once registered.',
            'liability':
                'Generally depends on the type of partnership and each '
                'partner\'s own role.',
            'governance':
                'Generally governed by an agreement among the partners.',
            'continuity':
                'Can be affected by a change among the partners, '
                'depending on that agreement.',
            'recordkeeping':
                'Generally more recordkeeping than a sole proprietorship, '
                'including its own filings.',
            'funding': 'Generally funded by the partners, or by borrowing.',
            'agency':
                'Generally registered with the Securities and Exchange '
                'Commission.',
          },
          caution:
              'How liability is shared among partners is worth '
              'understanding clearly before agreeing to anything.',
        ),
        ComparisonItem(
          id: 'opc',
          name: 'One Person Corporation',
          valuesByCriterionId: {
            'owners': 'One individual owner, structured as a corporation.',
            'legal-personality':
                'Generally has a separate legal personality from its '
                'single owner once registered.',
            'liability':
                'Generally limits the owner\'s liability to what was '
                'invested in the corporation, subject to the rules that '
                'generally apply to corporations.',
            'governance':
                'Governed by the single stockholder, under corporate '
                'rules built for one owner.',
            'continuity':
                'Generally continues independently of the owner, subject '
                'to corporate requirements such as naming a nominee.',
            'recordkeeping':
                'Generally more formal recordkeeping and reporting than a '
                'sole proprietorship.',
            'funding':
                'Can raise funds as a corporation, subject to the rules '
                'that apply to it.',
            'agency':
                'Generally registered with the Securities and Exchange '
                'Commission.',
          },
          caution:
              'Separate legal personality is not automatic protection in '
              'every circumstance; how liability actually works deserves '
              'its own careful reading.',
        ),
        ComparisonItem(
          id: 'corp-multi',
          name: 'Corporation with multiple owners',
          valuesByCriterionId: {
            'owners': 'Two or more shareholders.',
            'legal-personality':
                'Generally has a separate legal personality from its '
                'shareholders once registered.',
            'liability':
                'Generally limits each shareholder\'s liability to what '
                'was invested, subject to the rules that generally apply '
                'to corporations.',
            'governance':
                'Governed by a board of directors and its shareholders, '
                'under corporate rules.',
            'continuity':
                'Generally continues independently of any one '
                'shareholder.',
            'recordkeeping':
                'Generally the most formal recordkeeping and reporting '
                'among these structures.',
            'funding':
                'Can raise funds from multiple shareholders, subject to '
                'the rules that apply to it.',
            'agency':
                'Generally registered with the Securities and Exchange '
                'Commission.',
          },
          caution:
              'More owners generally means more governance to agree on, '
              'worth discussing before registering.',
        ),
        ComparisonItem(
          id: 'cooperative',
          name: 'Cooperative',
          valuesByCriterionId: {
            'owners':
                'Formed by members, generally organized around a shared '
                'purpose.',
            'legal-personality':
                'Generally has a separate legal personality from its '
                'members once registered.',
            'liability':
                'Generally depends on the cooperative\'s own bylaws and '
                'the rules that apply to cooperatives.',
            'governance':
                'Generally governed democratically by its own members.',
            'continuity':
                'Generally continues independently of any one member, '
                'subject to its own bylaws.',
            'recordkeeping':
                'Generally has its own recordkeeping and reporting '
                'requirements as a cooperative.',
            'funding': 'Generally funded by member contributions.',
            'agency':
                'Generally registered with the Cooperative Development '
                'Authority.',
          },
          caution:
              'A cooperative\'s member-driven governance is a different '
              'fit than a corporation\'s, worth understanding before '
              'choosing it.',
        ),
      ],
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'solo-earner-scenario',
      scenarioTitle: 'A fictional single earner',
      situation:
          'A fictional single earner wants to try selling a product '
          'alone, with no partners or outside investors yet, and has not '
          'thought much about what happens if something goes wrong.',
      options: [
        ScenarioChoiceOption(
          id: 'sole-prop-investigate',
          label: 'A sole proprietorship',
          explanation:
              'Structure to investigate. A sole proprietorship is '
              'generally built for a single owner, though it does not '
              'separate personal liability from the business the way '
              'some other structures can.',
        ),
        ScenarioChoiceOption(
          id: 'opc-investigate',
          label: 'A One Person Corporation',
          explanation:
              'Structure to investigate. An OPC is also built for a '
              'single owner, with a different liability and governance '
              'shape worth reading further before deciding.',
        ),
        ScenarioChoiceOption(
          id: 'discuss-risk-first',
          label: 'Neither yet, think through personal risk first',
          explanation:
              'Discuss ownership and liability first. Since personal-risk '
              'comfort has not been thought through yet, that is worth '
              'doing before comparing structures further.',
        ),
      ],
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'cofounders-scenario',
      scenarioTitle: 'A fictional pair of co-founders',
      situation:
          'Two fictional co-founders want to start together. They have '
          'not yet discussed how they would split control, what happens '
          'if one wants to leave, or whether an outside investor might '
          'join later.',
      options: [
        ScenarioChoiceOption(
          id: 'partnership-investigate',
          label: 'A partnership',
          explanation:
              'Structure to investigate. A partnership is generally built '
              'for two or more owners, though how liability is shared '
              'still depends on the type of partnership and the '
              'agreement between them.',
        ),
        ScenarioChoiceOption(
          id: 'corp-investigate',
          label: 'A corporation with multiple owners',
          explanation:
              'Structure to investigate. A corporation is also built for '
              'more than one owner, with a different governance and '
              'liability shape worth reading further.',
        ),
        ScenarioChoiceOption(
          id: 'discuss-ownership-first',
          label: 'Discuss ownership, control, and exit first',
          explanation:
              'Discuss ownership and liability first. Neither structure '
              'removes the need to agree on control and what happens if '
              'one co-founder wants to leave; that is worth settling '
              'honestly before registering either one.',
        ),
        ScenarioChoiceOption(
          id: 'ask-professional',
          label: 'Ask a professional before deciding',
          explanation:
              'Professional advice may be useful. Once outside investors '
              'or more complex ownership questions are in play, '
              'professional legal or accounting advice may be useful '
              'before choosing a structure.',
        ),
      ],
      requiredForCompletion: false,
    ),
    MythOrFactBlock(
      blockId: 'opc-equals-sole-prop-myth',
      statement:
          'A One Person Corporation and a sole proprietorship are legally '
          'the same thing, just with a different name.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'They are different registrations with different agencies, and '
          'generally a different liability and continuity shape. An OPC '
          'is generally registered with the SEC as a corporation; a sole '
          'proprietorship\'s business name is generally registered with '
          'the DTI, with no separate legal personality from its owner.',
      requiredForCompletion: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'Based on this lesson, what should a comparison between business '
        'structures never do?',
    choices: [
      'Call one structure the best, cheapest, safest, easiest, or most '
          'tax-efficient for everyone',
      'Describe differences in ownership, liability, governance, '
          'continuity, recordkeeping, funding, and registration agency',
      'Mention that professional advice may be useful for a specific '
          'situation',
    ],
    correctIndex: 0,
    explanation:
        'This lesson compares structures across several dimensions '
        'without ever ranking one as universally best; that judgment '
        'depends on circumstances this lesson does not know.',
    whyWrong:
        'Describing differences and mentioning that professional advice '
        'may help are both exactly what this comparison is meant to do.',
  ),
  keyTakeaway:
      'Sole proprietorships, partnerships, One Person Corporations, '
      'corporations with multiple owners, and cooperatives differ in '
      'ownership, liability, governance, continuity, recordkeeping, '
      'funding, and registration agency, and no structure is universally '
      'best; professional legal, accounting, or tax advice may be useful '
      'before choosing one.',
);

// ---------------------------------------------------------------------------
// Lesson 3: Match the Structure to the Agency
// ---------------------------------------------------------------------------

const _matchStructureToAgency = MoneyLesson(
  id: brMatchStructureToAgency,
  trackId: 'start_a_business_legally',
  title: 'Match the Structure to the Agency',
  icon: 'bank',
  minutes: 3,
  summary:
      'DTI, SEC, and CDA each register a different kind of structure, and '
      'the Philippine Business Hub can route a registration to the right '
      'one where it currently supports that path.',
  objective:
      'Match a business structure to the agency that generally registers '
      'it, without launching a real registration.',
  sections: [],
  governance: _governance,
  sources: [_dtiFaq, _dtiGuide, _sec, _cda, _pbh],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A sole proprietor operating under a business name generally '
            'registers that name with the Department of Trade and '
            'Industry. A partnership, a One Person Corporation, and a '
            'corporation with multiple owners are generally registered '
            'with the Securities and Exchange Commission. A cooperative '
            'is generally registered with the Cooperative Development '
            'Authority.',
        'The Philippine Business Hub is a government gateway that can '
            'route an application to the matching agency, where it '
            'currently supports that path. It is not a promise that every '
            'business type is supported there yet, and using it does not, '
            'by itself, complete every legal requirement to operate.',
      ],
    ),
    NuggetsBlock([
      'DTI generally handles a business name for a sole proprietor, not a '
          'partnership, an OPC, or a corporation.',
      'SEC generally handles partnerships, One Person Corporations, and '
          'corporations with multiple owners.',
      'CDA generally handles cooperatives.',
      'The Philippine Business Hub is a routing gateway to these '
          'agencies, not a fourth registering body on its own, and it '
          'does not yet support every business type.',
    ]),
    RiskWarningBlock(
      title: 'One registration is not the whole picture',
      text:
          'Matching a structure to its registering agency is one step. '
          'It does not, by itself, complete every legal requirement to '
          'operate, and requirements can change; confirm current details '
          'directly with the responsible agency.',
    ),
    OfficialSourceBlock(
      agency: _dtiAgency,
      sourceTitle: _dtiFaqTitle,
      canonicalUrl: _dtiFaqUrl,
      lastVerifiedDate: _dtiFaqVerified,
    ),
    OfficialSourceBlock(
      agency: _dtiAgency,
      sourceTitle: _dtiGuideTitle,
      canonicalUrl: _dtiGuideUrl,
      lastVerifiedDate: _dtiGuideVerified,
    ),
    OfficialSourceBlock(
      agency: _secAgency,
      sourceTitle: _secTitle,
      canonicalUrl: _secUrl,
      lastVerifiedDate: _secVerified,
    ),
    OfficialSourceBlock(
      agency: _cdaAgency,
      sourceTitle: _cdaTitle,
      canonicalUrl: _cdaUrl,
      lastVerifiedDate: _cdaVerified,
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
    CategorizeBlock(
      blockId: 'agency-match',
      categorizePrompt:
          'Match each fictional business idea to the agency it would '
          'generally register with first.',
      buckets: [
        CategorizeBucket(id: 'dti', label: 'DTI'),
        CategorizeBucket(id: 'sec', label: 'SEC'),
        CategorizeBucket(id: 'cda', label: 'CDA'),
      ],
      items: [
        CategorizeItemDef(
          id: 'food-seller',
          label:
              'A fictional food seller planning to register as a single '
              'owner, using a business name',
          explanation:
              'A sole proprietor\'s business name is generally registered '
              'with the Department of Trade and Industry.',
        ),
        CategorizeItemDef(
          id: 'freelancer-bn',
          label:
              'A fictional freelancer planning to operate under a '
              'business name different from their own',
          explanation:
              'Operating under a business name other than one\'s own is '
              'generally registered with the Department of Trade and '
              'Industry.',
        ),
        CategorizeItemDef(
          id: 'corp-founders',
          label:
              'A fictional group of co-founders planning to register a '
              'corporation with several shareholders',
          explanation:
              'A corporation with multiple shareholders is generally '
              'registered with the Securities and Exchange Commission.',
        ),
        CategorizeItemDef(
          id: 'opc-founder',
          label:
              'A fictional single founder planning to register a One '
              'Person Corporation',
          explanation:
              'A One Person Corporation is generally registered with the '
              'Securities and Exchange Commission.',
        ),
        CategorizeItemDef(
          id: 'farmers-coop',
          label:
              'A fictional group of farmers planning to register a '
              'cooperative to jointly market their produce',
          explanation:
              'A cooperative is generally registered with the '
              'Cooperative Development Authority.',
        ),
      ],
      correctBucketByItemId: {
        'food-seller': 'dti',
        'freelancer-bn': 'dti',
        'corp-founders': 'sec',
        'opc-founder': 'sec',
        'farmers-coop': 'cda',
      },
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'pbh-extra-step-myth',
      statement:
          'The Philippine Business Hub is a separate registration in '
          'addition to registering with DTI, SEC, or CDA, so a business '
          'would need to register there too.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'The Philippine Business Hub is an integrated government '
          'gateway that can route an application to the matching agency '
          'where it currently supports that path, not a separate '
          'registration on top of DTI, SEC, or CDA. It also does not '
          'support every business type yet, and using it does not, by '
          'itself, complete every legal requirement to operate.',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'According to this lesson, does registering with the matching '
        'agency, by itself, complete every legal requirement to operate a '
        'business?',
    choices: [
      'Yes, once DTI, SEC, or CDA approves the registration, nothing '
          'else is required',
      'No, other steps such as BIR registration and local requirements '
          'generally still apply',
      'Only if the registration was filed through the Philippine '
          'Business Hub',
    ],
    correctIndex: 1,
    explanation:
        'Matching a structure to its registering agency is one step. '
        'Other requirements, covered in a later lesson and a later '
        'course, generally still apply on top of it.',
    whyWrong:
        'Neither the agency alone nor the channel used to reach it '
        'completes every legal requirement by itself.',
  ),
  keyTakeaway:
      'DTI, SEC, and CDA each register a different kind of structure, the '
      'Philippine Business Hub can route a registration to the right one '
      'where it currently supports that path, and no single agency '
      'registration, by itself, completes every legal requirement to '
      'operate.',
);

// ---------------------------------------------------------------------------
// Lesson 4: Business Name Is Not the Whole Brand
// ---------------------------------------------------------------------------

const _businessNameAndBrand = MoneyLesson(
  id: brBusinessNameAndBrand,
  trackId: 'start_a_business_legally',
  title: 'Business Name Is Not the Whole Brand',
  icon: 'document',
  minutes: 3,
  summary:
      'Registering a business or entity name and protecting that name as '
      'a trademark are two different systems, run by different agencies.',
  objective:
      'Tell business or entity name registration apart from trademark '
      'protection, without offering any trademark clearance.',
  sections: [],
  governance: _governance,
  sources: [_dtiFaq, _ipophlInfo, _ipophlFiling],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Registering a business name or entity name and protecting that '
            'name as a trademark are two different systems, run by '
            'different agencies, and finishing one does not finish the '
            'other.',
        'A business or entity name registered with DTI, SEC, or CDA '
            'gives a business a legal identity to operate under. That '
            'registration checks whether the exact name is already taken '
            'within that agency\'s own records; it is not a trademark '
            'search and does not, by itself, establish trademark '
            'ownership.',
        'Trademark protection is handled separately, through the '
            'Intellectual Property Office of the Philippines. '
            'Investigating IPOPHL\'s own trademark resources, generally '
            'before committing to a name, is a separate and worthwhile '
            'step, distinct from checking name availability with the '
            'registering agency.',
      ],
    ),
    NuggetsBlock([
      'Name availability at DTI, SEC, or CDA answers one question: is '
          'this exact name already taken in that agency\'s own records.',
      'Trademark ownership is a different question, handled by the '
          'Intellectual Property Office of the Philippines, not by the '
          'agency that registers the business or entity name.',
      'Investigating both, generally before committing to a name, avoids '
          'discovering a conflict only after a name is already in use.',
    ]),
    RiskWarningBlock(
      title: 'A registered name is not a trademark',
      text:
          'An approved business or entity name registration does not, by '
          'itself, establish trademark ownership or protection over that '
          'name. A separate trademark search and filing through the '
          'Intellectual Property Office of the Philippines is a '
          'different step worth investigating on its own.',
    ),
    OfficialSourceBlock(
      agency: _dtiAgency,
      sourceTitle: _dtiFaqTitle,
      canonicalUrl: _dtiFaqUrl,
      lastVerifiedDate: _dtiFaqVerified,
    ),
    OfficialSourceBlock(
      agency: _ipophlAgency,
      sourceTitle: _ipophlInfoTitle,
      canonicalUrl: _ipophlInfoUrl,
      lastVerifiedDate: _ipophlInfoVerified,
    ),
    OfficialSourceBlock(
      agency: _ipophlAgency,
      sourceTitle: _ipophlFilingTitle,
      canonicalUrl: _ipophlFilingUrl,
      lastVerifiedDate: _ipophlFilingVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    SortingBlock(
      blockId: 'name-and-brand-sequence',
      sortingPrompt: 'Put this general sequence in the order it should happen.',
      items: [
        SortingItemDef(id: 'brainstorm', label: 'Brainstorm a few name ideas'),
        SortingItemDef(
          id: 'check-name-availability',
          label:
              'Check name availability with the matching registering '
              'agency, DTI, SEC, or CDA',
        ),
        SortingItemDef(
          id: 'investigate-ipophl',
          label:
              'Investigate whether a similar mark is already registered '
              'with IPOPHL',
        ),
        SortingItemDef(
          id: 'register-name',
          label:
              'Register the business or entity name with the matching '
              'agency',
        ),
        SortingItemDef(
          id: 'consider-trademark-filing',
          label:
              'Consider filing a trademark application with IPOPHL if '
              'trademark protection matters',
        ),
      ],
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'name-equals-trademark-myth',
      statement:
          'Once a business or entity name is approved by DTI, SEC, or '
          'CDA, that approval also grants trademark protection over the '
          'name.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Business or entity name registration and trademark protection '
          'are handled by different systems. Name availability at the '
          'registering agency does not automatically establish trademark '
          'ownership; that is a separate step through the Intellectual '
          'Property Office of the Philippines.',
      requiredForCompletion: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'Does an approved business or entity name registration also mean '
        'the name is protected as a trademark?',
    choices: [
      'Yes, automatically, once the name is approved',
      'No, name registration and trademark protection are different '
          'systems, and trademark protection is a separate step to '
          'investigate through IPOPHL',
      'Only for a corporation, never for a sole proprietorship',
    ],
    correctIndex: 1,
    explanation:
        'Name registration and trademark protection are run by different '
        'agencies and answer different questions; one never automatically '
        'grants the other.',
    whyWrong:
        'Neither an automatic grant, nor a structure-specific exception, '
        'describes how these two separate systems actually work.',
  ),
  keyTakeaway:
      'A business or entity name registration and trademark protection '
      'are different systems: name availability at DTI, SEC, or CDA '
      'answers whether the exact name is taken in that agency\'s own '
      'records, and trademark ownership is a separate question worth '
      'investigating through the Intellectual Property Office of the '
      'Philippines before committing to a name.',
);

// ---------------------------------------------------------------------------
// Lesson 5: Registration Is Not Permission to Operate
// ---------------------------------------------------------------------------

const _registrationIsNotPermission = MoneyLesson(
  id: brRegistrationIsNotPermission,
  trackId: 'start_a_business_legally',
  title: 'Registration Is Not Permission to Operate',
  icon: 'flow',
  minutes: 4,
  summary:
      'A business name or entity registration is one step in a longer '
      'sequence, not complete authority to operate.',
  objective:
      'Place business-name registration inside the fuller sequence of '
      'what generally follows it, without memorizing forms or deadlines.',
  sections: [],
  governance: _governance,
  sources: [_pbh, _bir],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Registering a business name or entity is one step in a longer '
            'sequence, not the finish line. A Department of Trade and '
            'Industry business name certificate, on its own, is not '
            'complete legal authority to operate a business.',
        'What applies on top of that registration depends on the '
            'structure chosen, the location, who owns the business, '
            'whether workers will be hired, and the industry itself. Two '
            'businesses that look similar on paper can face a different '
            'set of requirements once these details differ.',
        'An online-only business is not automatically exempt from these '
            'requirements either. Selling only through a website or a '
            'social media page does not, by itself, remove the '
            'registration and compliance obligations that would '
            'otherwise apply.',
      ],
    ),
    DiagramBlock(
      steps: [
        'Clarify the business and who owns it',
        'Investigate the appropriate structure',
        'Register the business name or entity',
        'Complete applicable BIR registration',
        'Check barangay and LGU requirements',
        'Check employer registrations if workers will be hired',
        'Check industry-specific licenses or regulators',
        'Maintain ongoing filing and compliance responsibilities',
      ],
      caption: 'A general sequence, not a countdown of deadlines',
    ),
    NuggetsBlock([
      'A business name or entity registration is a step, not a finish '
          'line.',
      'BIR registration is generally a separate, additional step from '
          'registering the business name or entity.',
      'Requirements can vary by location, so checking directly with the '
          'relevant barangay or LGU is worth doing rather than assuming.',
      'Operating only online does not, by itself, remove these '
          'obligations.',
    ]),
    RiskWarningBlock(
      title: 'A certificate is a step, not a finish line',
      text:
          'Treating a business name or entity certificate as complete '
          'authority to operate can leave real requirements unmet. What '
          'applies further depends on the structure, location, '
          'ownership, employees, and industry, and confirming these '
          'directly with the responsible agency is worth doing rather '
          'than assuming.',
    ),
    OfficialSourceBlock(
      agency: _pbhAgency,
      sourceTitle: _pbhTitle,
      canonicalUrl: _pbhUrl,
      lastVerifiedDate: _pbhVerified,
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _birTitle,
      canonicalUrl: _birUrl,
      lastVerifiedDate: _birVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    SortingBlock(
      blockId: 'registration-sequence-order',
      sortingPrompt: 'Put this general sequence in the order it should happen.',
      items: [
        SortingItemDef(
          id: 'clarify-ownership',
          label: 'Clarify the business and who owns it',
        ),
        SortingItemDef(
          id: 'investigate-structure',
          label: 'Investigate the appropriate structure',
        ),
        SortingItemDef(
          id: 'register-name-entity',
          label: 'Register the business name or entity',
        ),
        SortingItemDef(
          id: 'bir-registration',
          label: 'Complete applicable BIR registration',
        ),
        SortingItemDef(
          id: 'barangay-lgu-check',
          label: 'Check barangay and LGU requirements',
        ),
        SortingItemDef(
          id: 'employer-registration-check',
          label: 'Check employer registrations if workers will be hired',
        ),
        SortingItemDef(
          id: 'industry-license-check',
          label: 'Check industry-specific licenses or regulators',
        ),
        SortingItemDef(
          id: 'ongoing-compliance',
          label: 'Maintain ongoing filing and compliance responsibilities',
        ),
      ],
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'certificate-is-full-authority-myth',
      statement:
          'A DTI business name certificate, by itself, is complete legal '
          'authority to operate a business in the Philippines.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'A business name certificate is one step. BIR registration, '
          'barangay and LGU requirements, employer registrations if '
          'workers are hired, and any industry-specific license '
          'generally still apply on top of it, depending on the specifics '
          'of the business.',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'According to this lesson, does registering a business name, by '
        'itself, give complete legal authority to operate?',
    choices: [
      'Yes, once the certificate is issued, nothing else is required',
      'No, other steps generally still apply, depending on the '
          'structure, location, ownership, employees, and industry',
      'Only for a business that operates entirely online',
    ],
    correctIndex: 1,
    explanation:
        'A business name or entity registration is one step in a longer '
        'sequence; what else applies depends on several factors this '
        'lesson names but does not resolve for any one business.',
    whyWrong:
        'Neither treating the certificate as final, nor assuming an '
        'online business is exempt, matches what this lesson actually '
        'says.',
  ),
  keyTakeaway:
      'Registering a business name or entity is one step in a longer '
      'sequence, BIR registration and barangay, LGU, employer, and '
      'industry-specific requirements generally still apply on top of it '
      'depending on the specifics of the business, and operating only '
      'online does not, by itself, remove these obligations.',
);

// ---------------------------------------------------------------------------
// Lesson 6: Build Your Registration Roadmap
// ---------------------------------------------------------------------------

const _buildRegistrationRoadmap = MoneyLesson(
  id: brBuildRegistrationRoadmap,
  trackId: 'start_a_business_legally',
  title: 'Build Your Registration Roadmap',
  icon: 'plan',
  minutes: 4,
  summary:
      'A short, personal list of what is worth investigating next, and a '
      'few real next steps in Salapify if any of them fit.',
  objective:
      'Build a generic action plan covering what to investigate next, '
      'without landing on a specific structure, agency, or amount.',
  sections: [],
  governance: _governance,
  sources: [_pbh, _bir],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A registration roadmap is a short, personal list of what is '
            'worth investigating next, built from everything covered in '
            'this course so far. It never names which structure to '
            'choose, which agency to register with first, or how much to '
            'set aside; it is a plan to investigate, not a decision '
            'already made.',
        'BIR registration is deliberately not covered in detail here. '
            'That is worth its own course, next in this series, once a '
            'structure and an agency have actually been investigated.',
      ],
    ),
    NuggetsBlock([
      'Owner roles, a structure to investigate, and the matching '
          'registration agency are worth naming first.',
      'Business-name research and trademark research are separate '
          'checks, both worth planning before committing to a name.',
      'BIR registration, barangay and LGU requirements, and any '
          'industry-specific regulator are worth investigating once a '
          'structure and agency are clearer.',
      'A registration and ongoing compliance budget, and a way to '
          'remember ongoing compliance, round out a realistic plan.',
    ]),
    RiskWarningBlock(
      title: 'A roadmap is a plan, not a decision',
      text:
          'This lesson never tells anyone which structure to choose, '
          'which agency to register with first, or how much to set '
          'aside. It only names what is worth investigating and, where a '
          'real Salapify feature already exists, offers to open it.',
    ),
    OfficialSourceBlock(
      agency: _pbhAgency,
      sourceTitle: _pbhTitle,
      canonicalUrl: _pbhUrl,
      lastVerifiedDate: _pbhVerified,
    ),
    OfficialSourceBlock(
      agency: _birAgency,
      sourceTitle: _birTitle,
      canonicalUrl: _birUrl,
      lastVerifiedDate: _birVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ChecklistBlock(
      blockId: 'registration-roadmap-checklist',
      checklistPrompt:
          'A personal roadmap to work through at your own pace. Offline, '
          'and yours to keep.',
      items: [
        ChecklistItemDef(
          id: 'owner-role-discussion',
          label:
              'Owner roles have been discussed, if there is more than '
              'one owner',
          required: false,
        ),
        ChecklistItemDef(
          id: 'structure-to-investigate',
          label: 'A structure to investigate further has been identified',
          required: false,
        ),
        ChecklistItemDef(
          id: 'registration-agency-to-check',
          label:
              'The matching registration agency to check has been '
              'identified',
          required: false,
        ),
        ChecklistItemDef(
          id: 'business-name-research',
          label: 'Business name research is planned',
          required: false,
        ),
        ChecklistItemDef(
          id: 'trademark-research',
          label: 'Trademark research through IPOPHL is planned, if relevant',
          required: false,
        ),
        ChecklistItemDef(
          id: 'bir-next-course',
          label:
              'BIR registration is understood as the next course in this '
              'series',
          required: false,
        ),
        ChecklistItemDef(
          id: 'lgu-requirements-to-investigate',
          label:
              'Barangay and LGU requirements to investigate have been '
              'noted',
          required: false,
        ),
        ChecklistItemDef(
          id: 'industry-regulator-check',
          label:
              'A possible industry-specific regulator has been '
              'considered',
          required: false,
        ),
        ChecklistItemDef(
          id: 'registration-compliance-budget',
          label:
              'A registration and ongoing compliance budget has been '
              'considered',
          required: false,
        ),
        ChecklistItemDef(
          id: 'compliance-reminders',
          label:
              'A way to remember ongoing compliance has been '
              'considered',
          required: false,
        ),
      ],
      allRequiredMustBeChecked: false,
      requiredForCompletion: false,
    ),
    MythOrFactBlock(
      blockId: 'roadmap-auto-creates-myth',
      statement:
          'Working through this roadmap automatically creates a goal, a '
          'budget line, an account, or a reminder.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Nothing here creates or changes a financial record '
          'automatically. Each destination named in this lesson still '
          'needs your own confirmation inside that screen before '
          'anything is saved.',
      requiredForCompletion: true,
    ),
    SalapifyActionsBlock(
      blockId: 'business-roadmap-actions',
      menuPrompt: 'A few real next steps, if any of them fit.',
      actions: [
        SalapifyActionDef(
          id: 'start-registration-goal',
          label: 'Start a business-registration savings goal',
          description:
              'Opens Goals to check or start a goal for registration '
              'costs or an ongoing compliance fund. Nothing is created '
              'or changed until something is saved there.',
          route: 'goals',
        ),
        SalapifyActionDef(
          id: 'review-budget-for-registration',
          label: 'Review Budget for a registration-cost line',
          description:
              'Opens Budget to check what is already spoken for this '
              'period before setting money aside for registration costs. '
              'Nothing changes automatically.',
          route: 'budget',
        ),
        SalapifyActionDef(
          id: 'review-accounts-business-expenses',
          label: 'Review your Accounts',
          description:
              'Opens Accounts, where a business-expense account or '
              'category can already be tracked if you choose to use one. '
              'Nothing is created automatically, and nothing here '
              'registers a business anywhere.',
          route: 'accounts',
        ),
        SalapifyActionDef(
          id: 'open-compliance-reminders',
          label: 'Open reminders',
          description:
              'Opens Notifications and security, where reminders can be '
              'turned on. There is no registration or compliance '
              'specific reminder type yet, so nothing is scheduled '
              'automatically; this is the closest real screen for '
              'building a periodic check-in habit by hand.',
          route: 'notifications',
        ),
      ],
    ),
  ],
  check: KnowledgeCheck(
    question:
        'Does completing this roadmap checklist automatically create a '
        'goal, budget line, account, or reminder?',
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
      'A registration roadmap names what is worth investigating next, '
      'from ownership and structure to BIR, LGU, and industry checks, '
      'and a compliance budget, and turning any of it into a real goal, '
      'budget line, account, or reminder in Salapify still needs your '
      'own confirmation inside that screen.',
);
