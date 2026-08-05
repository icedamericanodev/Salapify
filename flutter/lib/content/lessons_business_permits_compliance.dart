// Money Courses Phase 15: "Build Your Business" learning path's FOURTH
// course, "Permits, People, and Compliance" (course id
// 'business_permits_and_compliance'). Built the same way every earlier
// expansion course was: the already shipped architecture only (governance
// metadata, official-source and risk-warning blocks, Phase 5 interaction
// blocks), nothing new added to the core model.
//
// This course picks up where "BIR Registration and Local Permits" (Phase
// 14, lessons_bir_local_permits.dart) and "BIR Setup for New Businesses"
// (lessons_bir_tax_setup.dart) leave off: it never repeats BIR registration
// or tax setup. Instead it covers the piece those two courses deliberately
// left open, that a business's real checklist depends on WHERE it operates
// and WHO it hires, and that some activities need authorization from a
// regulator beyond the usual local permit. It walks through why location
// changes the checklist, the general local-permit flow, keeping permits and
// clearances current, what changes when a business becomes an employer, how
// to recognize an industry-specific regulator, and a closing roadmap tying
// all of it together.
//
// UNLIKE "BIR Registration and Local Permits", this course states NO peso
// figure, percentage, fee, threshold, form number, contribution rate,
// processing time, renewal date, submission deadline, document list, or
// penalty anywhere. Every one of those is exactly the kind of detail this
// course's own task treats as too volatile or too locally variable to state
// safely: a Business Permit fee differs by city and municipality, a
// contribution rate can change by law, and a processing time depends on the
// office. Where a regulator mapping cannot be independently verified from an
// official source, this course uses the same neutral fallback throughout:
// "Check with your LGU and the national agency responsible for your
// activity." Every lesson is classified ContentVolatility.annual, never
// ContentVolatility.high, because it never states the kind of figure that
// would need the shorter review cycle "BIR Registration and Local Permits"
// uses for its own fee and threshold lessons.
//
// This course never assigns a real, non-fictional worker a legal
// classification (employee, contractor, intern, partner), never calculates
// a contribution or a payroll figure, never determines which industry
// regulator applies to a specific reader's real business, and never
// requests or stores a business address, a permit or registration number, a
// TIN, a government ID, an employee name or identification number, a
// salary, a contribution amount, a payroll file, a certificate, or an
// application reference. Every scenario in every interaction is explicitly
// fictional.
//
// Sources: the Philippine Business Hub's own business-application-process
// page (already cited by "Start Your Business Legally" and "BIR
// Registration and Local Permits", reused here for the LGU-routing
// lessons), DTI's own Business Name Registration System FAQ, the DILG's own
// electronic Business One-Stop Shop guidelines, SSS's and PhilHealth's own
// employer-registration pages, and the FDA's, PCAB's, and DOT's own
// official sites for the three industry regulators this course names by
// verified example. A direct WebFetch to every one of these pages returns a
// uniform 403 in this environment, the same gov.ph fetch limitation every
// earlier expansion course's own header notes; per this repository's rule
// that a Money Courses official-source URL needs a real search, not just a
// cite, legal-compliance-counsel independently WebSearched each candidate
// URL as part of its Phase 15 review. Two of the ten URLs this course
// originally cited, a DILG "barangay clearance integration" circular and a
// Pag-IBIG Fund employer-registration checklist PDF, could not be
// independently confirmed as real, currently-live pages at those exact
// paths (the DILG one appears to be a different, misdated circular; the
// Pag-IBIG one only turned up on a third-party mirror), so both were
// dropped from this file's sources rather than shipped unverified; the
// general, well-known facts that DILG runs eBOSS and that Pag-IBIG has its
// own employer-registration process stay in the lessons' prose, but no
// citation card links to either unconfirmed document. The same review also
// caught a real ordering error in Lesson 2's original draft (BIR
// registration was sequenced before barangay clearance and the Business
// Permit; independently confirmed sources put it after, since BIR commonly
// asks for the Business Permit as a supporting document), corrected before
// this file shipped. No blog, accounting-firm summary, or unofficial
// calculator was used as a source for any claim in this file.

import 'interaction_blocks.dart';
import 'lesson_blocks.dart';
import 'lesson_model.dart';

const _pbhAgency = 'Philippine Business Hub';
const _dtiAgency = 'Department of Trade and Industry (DTI)';
const _dilgAgency = 'Department of the Interior and Local Government (DILG)';
const _sssAgency = 'Social Security System (SSS)';
const _philhealthAgency =
    'Philippine Health Insurance Corporation (PhilHealth)';
const _fdaAgency = 'Food and Drug Administration (FDA)';
const _pcabAgency = 'Philippine Contractors Accreditation Board (PCAB)';
const _dotAgency = 'Department of Tourism (DOT)';

const _pbhTitle = 'Business Application Process';
const _pbhUrl = 'https://business.gov.ph/business-application-process';
const _pbhVerified = '2026-08';
const _pbh = LessonSourceInfo(
  agency: _pbhAgency,
  title: _pbhTitle,
  canonicalUrl: _pbhUrl,
  lastVerifiedDate: _pbhVerified,
);

const _dtiBnrsTitle = 'Business Name Registration FAQ';
const _dtiBnrsUrl = 'https://bnrs.dti.gov.ph/faq';
const _dtiBnrsVerified = '2026-08';
const _dtiBnrs = LessonSourceInfo(
  agency: _dtiAgency,
  title: _dtiBnrsTitle,
  canonicalUrl: _dtiBnrsUrl,
  lastVerifiedDate: _dtiBnrsVerified,
);

const _dilgEbossTitle = 'Electronic Business One-Stop Shop Guidelines';
const _dilgEbossUrl =
    'https://www.dilg.gov.ph/PDF_File/issuances/joint_circulars/dilg-joincircular-2021728_41c62cd45a.pdf';
const _dilgEbossVerified = '2026-08';
const _dilgEboss = LessonSourceInfo(
  agency: _dilgAgency,
  title: _dilgEbossTitle,
  canonicalUrl: _dilgEbossUrl,
  lastVerifiedDate: _dilgEbossVerified,
);

const _sssTitle = 'Employer Guidance';
const _sssUrl = 'https://www.sss.gov.ph/employer-er/';
const _sssVerified = '2026-08';
const _sss = LessonSourceInfo(
  agency: _sssAgency,
  title: _sssTitle,
  canonicalUrl: _sssUrl,
  lastVerifiedDate: _sssVerified,
);

const _philhealthTitle = 'Employer Registration';
const _philhealthUrl =
    'https://www.philhealth.gov.ph/partners/employers/registration.php';
const _philhealthVerified = '2026-08';
const _philhealth = LessonSourceInfo(
  agency: _philhealthAgency,
  title: _philhealthTitle,
  canonicalUrl: _philhealthUrl,
  lastVerifiedDate: _philhealthVerified,
);

const _fdaTitle = 'FDA Philippines';
const _fdaUrl = 'https://www.fda.gov.ph/';
const _fdaVerified = '2026-08';
const _fda = LessonSourceInfo(
  agency: _fdaAgency,
  title: _fdaTitle,
  canonicalUrl: _fdaUrl,
  lastVerifiedDate: _fdaVerified,
);

const _pcabTitle = 'Philippine Contractors Accreditation Board';
const _pcabUrl = 'https://pcab.construction.gov.ph/';
const _pcabVerified = '2026-08';
const _pcab = LessonSourceInfo(
  agency: _pcabAgency,
  title: _pcabTitle,
  canonicalUrl: _pcabUrl,
  lastVerifiedDate: _pcabVerified,
);

const _dotTitle = 'Department of Tourism';
const _dotUrl = 'https://www.tourism.gov.ph/';
const _dotVerified = '2026-08';
const _dot = LessonSourceInfo(
  agency: _dotAgency,
  title: _dotTitle,
  canonicalUrl: _dotUrl,
  lastVerifiedDate: _dotVerified,
);

// This course never states a fee, threshold, deadline, or rate, so every
// lesson uses the same annual review cycle every structural, non-figure
// lesson in this course's sibling courses already uses.
const _governance = LessonGovernance(
  volatility: ContentVolatility.annual,
  reviewStatus: ReviewStatus.verified,
  lastVerifiedDate: '2026-08',
  reviewDueDate: '2027-08',
  reviewerId: 'LCC',
);

const _boundaryLocal = EducationalBoundaryBlock(
  sourceLabel:
      'the Department of Trade and Industry, the Department of the '
      'Interior and Local Government, and your own city, municipality, '
      'and barangay',
  examplesAreFictional: true,
);

const _boundaryEmployer = EducationalBoundaryBlock(
  sourceLabel:
      'the Social Security System, PhilHealth, the Pag-IBIG Fund, and the '
      'Department of Labor and Employment',
  examplesAreFictional: true,
);

const _boundaryIndustry = EducationalBoundaryBlock(
  sourceLabel:
      'the Food and Drug Administration, the Philippine Contractors '
      'Accreditation Board, the Department of Tourism, and the specific '
      'national agency responsible for a given activity',
  examplesAreFictional: true,
);

/// Lesson ids, exactly as specified for Phase 15, stable and free-form, the
/// same "never reused once a learner has real progress recorded" convention
/// every earlier expansion course's own ids follow.
const bpccLocationChangesTheChecklist = 'location_changes_the_checklist';
const bpccMapTheLocalPermitFlow = 'map_the_local_permit_flow';
const bpccRenewalsAndLocalCompliance = 'renewals_and_local_compliance';
const bpccWhenYouHirePeople = 'when_you_hire_people';
const bpccIndustrySpecificRegulators = 'industry_specific_regulators';
const bpccBuildYourComplianceMap = 'build_your_compliance_map';

/// The six lessons, in reading order. Never added to lessons.dart's flat
/// list, and never merged into any sibling course's own list: see
/// test/lessons_business_permits_compliance_content_test.dart's own
/// isolation checks.
const List<MoneyLesson> businessPermitsAndComplianceLessons = [
  _locationChangesTheChecklist,
  _mapTheLocalPermitFlow,
  _renewalsAndLocalCompliance,
  _whenYouHirePeople,
  _industrySpecificRegulators,
  _buildYourComplianceMap,
];

// ---------------------------------------------------------------------------
// Lesson 1: Your Location Changes the Checklist
// ---------------------------------------------------------------------------

const _locationChangesTheChecklist = MoneyLesson(
  id: bpccLocationChangesTheChecklist,
  trackId: 'business_permits_and_compliance',
  title: 'Your Location Changes the Checklist',
  icon: 'inspect',
  minutes: 3,
  summary:
      'What a business needs to check locally depends on where it '
      'operates, what it does, and whether it hires anyone, not on one '
      'nationwide list.',
  objective:
      'Name the factors that change a local permit checklist, without '
      'stating a specific requirement for any real address.',
  sections: [],
  governance: _governance,
  sources: [_pbh, _dilgEboss],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A local permit checklist is not one nationwide list. What '
            'actually applies generally depends on the city or '
            'municipality, the barangay, the business activity, whether '
            'the setup is physical or online, whether there is a '
            'dedicated workplace or facility, and whether the business '
            'will hire anyone at all. Two fictional businesses can look '
            'similar and still face a different local checklist, simply '
            'because they operate in different places.',
        'A city or municipal government generally runs the local permit '
            'process through its own Business Permits and Licensing '
            'Office (BPLO), the office most directly responsible for a '
            'city or municipal Business Permit. A barangay generally '
            'plays its own role too, most often through a barangay '
            'clearance step, and some local governments now run that '
            'step through an integrated one-stop process rather than as a '
            'separate visit. Which of these applies, and how, always '
            'needs checking with the specific local government where the '
            'business actually operates.',
      ],
    ),
    NuggetsBlock([
      'A local permit checklist can change with the city or municipality, '
          'the barangay, the business activity, and whether the setup is '
          'physical, online, or hires anyone.',
      'The city or municipal Business Permits and Licensing Office (BPLO) '
          'is generally the office most directly responsible for a '
          'Business Permit.',
      'A barangay generally plays its own role too, and some local '
          'governments integrate that step into one process rather than a '
          'separate visit.',
      'The only reliable way to know a real checklist is to check '
          'directly with the local government where the business '
          'operates.',
    ]),
    RiskWarningBlock(
      title: 'No single checklist fits every business',
      text:
          'Requirements vary by LGU and business activity. This lesson '
          'names the factors that change a checklist, never a finished '
          'checklist for any real business. Confirm current requirements '
          'with the issuing office before acting on anything here.',
    ),
    OfficialSourceBlock(
      agency: _pbhAgency,
      sourceTitle: _pbhTitle,
      canonicalUrl: _pbhUrl,
      lastVerifiedDate: _pbhVerified,
    ),
    OfficialSourceBlock(
      agency: _dilgAgency,
      sourceTitle: _dilgEbossTitle,
      canonicalUrl: _dilgEbossUrl,
      lastVerifiedDate: _dilgEbossVerified,
    ),
    _boundaryLocal,
  ],
  interactionBlocks: [
    ScenarioChoiceBlock(
      blockId: 'location-changes-checklist-scenario',
      scenarioTitle: 'Two fictional businesses, two different checklists',
      situation:
          'A fictional home-based online seller and a fictional business '
          'renting a storefront a few blocks away both want to know what '
          'local checklist applies to them.',
      options: [
        ScenarioChoiceOption(
          id: 'assume-same-checklist',
          label:
              'Assume both fictional businesses face the exact same '
              'local checklist',
          explanation:
              'Not reliable. Even close by, a home-based online setup and '
              'a physical storefront can face a different local '
              'checklist, since the activity and the facility both '
              'matter.',
        ),
        ScenarioChoiceOption(
          id: 'check-with-local-office',
          label:
              'Check with the local BPLO and barangay for each fictional '
              'setup separately',
          explanation:
              'The reliable option. Confirming with the local office for '
              'each specific setup is what actually reveals which parts '
              'of the checklist apply.',
        ),
        ScenarioChoiceOption(
          id: 'skip-because-online',
          label: 'Assume the online seller needs no local checklist at all',
          explanation:
              'Not reliable either. An online or home-based setup can '
              'still have local requirements to check; being online does '
              'not automatically remove every local step.',
        ),
      ],
      requiredForCompletion: true,
    ),
    ChecklistBlock(
      blockId: 'location-changes-checklist-results',
      checklistPrompt:
          'A general starting checklist. Nothing here is saved or '
          'shared, and it is not a finished checklist for any real '
          'address.',
      items: [
        ChecklistItemDef(
          id: 'start-city-office',
          label: 'Start with your city or municipal business office',
          required: false,
        ),
        ChecklistItemDef(
          id: 'check-barangay-integration',
          label: 'Check whether your barangay step is integrated',
          required: false,
        ),
        ChecklistItemDef(
          id: 'extra-clearances',
          label: 'Your activity may need extra clearances',
          required: false,
        ),
        ChecklistItemDef(
          id: 'prepare-local-checklist',
          label: 'Prepare a local permit checklist',
          required: false,
        ),
      ],
      allRequiredMustBeChecked: false,
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'According to this lesson, do two fictional businesses in the '
        'same general area always face the exact same local checklist?',
    choices: [
      'Yes, location within the same city always means the same '
          'checklist',
      'No, activity, setup, facility, and whether workers are hired can '
          'all change what applies, even close by',
      'No, only the barangay ever changes; the city checklist never does',
    ],
    correctIndex: 1,
    explanation:
        'This lesson names several factors, not only the barangay, that '
        'can change what a local checklist actually requires for a '
        'specific business.',
    whyWrong:
        'Neither treating the checklist as fixed by location alone, nor '
        'limiting change to the barangay only, matches what this lesson '
        'actually explains.',
  ),
  keyTakeaway:
      'A local permit checklist depends on the city or municipality, the '
      'barangay, the business activity, the physical or online setup, and '
      'whether workers are hired, so the only reliable way to know a real '
      'checklist is to check directly with the local BPLO and barangay '
      'where the business operates.',
);

// ---------------------------------------------------------------------------
// Lesson 2: Map the Local Permit Flow
// ---------------------------------------------------------------------------

const _mapTheLocalPermitFlow = MoneyLesson(
  id: bpccMapTheLocalPermitFlow,
  trackId: 'business_permits_and_compliance',
  title: 'Map the Local Permit Flow',
  icon: 'flow',
  minutes: 3,
  summary:
      'Entity registration, barangay clearance, a Business Permit, local '
      'checks, BIR registration, and permission to operate generally '
      'relate in that rough order, though not identically everywhere.',
  objective:
      'Describe how entity registration, BIR registration, barangay '
      'clearance, a Business Permit, and local checks generally relate, '
      'without presenting one exact sequence as universal.',
  sections: [],
  governance: _governance,
  sources: [_pbh, _dtiBnrs],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Six pieces generally relate to each other on the way to '
            'operating legally: business or entity registration (DTI, '
            'SEC, or CDA), a barangay-related clearance, the city or '
            'municipal Business Permit, whatever zoning, fire-safety, '
            'sanitary, occupancy, or other local checks apply, BIR '
            'registration, and finally permission to actually operate. A '
            'DTI, SEC, or CDA registration only registers the business or '
            'entity name itself. It is not, on its own, permission to '
            'operate.',
        'How these six pieces actually connect differs by LGU. Some '
            'local governments integrate the barangay-clearance step '
            'into the same process as the Business Permit application; '
            'others keep it as a separate stop. Not every local check '
            'applies to every business either, a home-based online seller '
            'and a business needing a physical facility can face a '
            'different set of local checks even in the same city. BIR '
            'registration generally follows the local permit steps, since '
            'the Business Permit is commonly asked for as a supporting '
            'document when registering with BIR.',
      ],
    ),
    DiagramBlock(
      steps: [
        'Business or entity registration (DTI, SEC, or CDA)',
        'Barangay-related clearance',
        'City or municipal Business Permit',
        'Applicable zoning, fire-safety, sanitary, occupancy, or other '
            'local checks',
        'BIR registration',
        'Permission to actually operate',
      ],
      caption: 'A general relationship, not one fixed sequence everywhere',
    ),
    NuggetsBlock([
      'LGU processes differ; some integrate barangay clearance into the '
          'Business Permit process, others keep it separate.',
      'Not every local clearance applies to every business.',
      'A DTI, SEC, or CDA registration alone is not permission to '
          'operate.',
      'BIR registration generally follows the local permit steps, since '
          'the Business Permit is commonly asked for when registering '
          'with BIR.',
    ]),
    RiskWarningBlock(
      title: 'A general relationship, not a universal sequence',
      text:
          'Requirements vary by LGU and business activity. This lesson '
          'names how these pieces generally relate, never a single fixed '
          'order that applies identically everywhere. Confirm current '
          'requirements with the issuing office.',
    ),
    OfficialSourceBlock(
      agency: _pbhAgency,
      sourceTitle: _pbhTitle,
      canonicalUrl: _pbhUrl,
      lastVerifiedDate: _pbhVerified,
    ),
    OfficialSourceBlock(
      agency: _dtiAgency,
      sourceTitle: _dtiBnrsTitle,
      canonicalUrl: _dtiBnrsUrl,
      lastVerifiedDate: _dtiBnrsVerified,
    ),
    _boundaryLocal,
  ],
  interactionBlocks: [
    SortingBlock(
      blockId: 'local-permit-flow-sequence',
      sortingPrompt:
          'Put this general relationship in the order it usually '
          'follows.',
      items: [
        SortingItemDef(
          id: 'entity-registration',
          label: 'Business or entity registration (DTI, SEC, or CDA)',
        ),
        SortingItemDef(
          id: 'barangay-clearance',
          label: 'Barangay-related clearance',
        ),
        SortingItemDef(
          id: 'mayors-permit',
          label: 'City or municipal Business Permit',
        ),
        SortingItemDef(
          id: 'local-checks',
          label:
              'Applicable zoning, fire-safety, sanitary, occupancy, or '
              'other local checks',
        ),
        SortingItemDef(id: 'bir-registration', label: 'BIR registration'),
        SortingItemDef(
          id: 'permission-to-operate',
          label: 'Permission to actually operate',
        ),
      ],
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'entity-registration-is-permission-myth',
      statement:
          'A DTI, SEC, or CDA registration is, by itself, permission to '
          'operate a business.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'It registers the business or entity name. Permission to '
          'operate generally still depends on the local permit steps and '
          'BIR registration that follow, which differ by LGU.',
      requiredForCompletion: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'According to this lesson, does one identical fixed sequence '
        'apply at each local government the same way?',
    choices: [
      'Yes, one identical fixed sequence applies at each local government',
      'No, some local governments integrate barangay clearance into the '
          'Business Permit process, and not every local check applies to '
          'every business',
      'No, barangay clearance is never required anywhere anymore',
    ],
    correctIndex: 1,
    explanation:
        'This lesson explicitly names that LGU processes differ, some '
        'integrate the barangay step, and not every local check applies '
        'to every business.',
    whyWrong:
        'Neither claiming one identical fixed sequence, nor claiming '
        'barangay clearance no longer applies anywhere, matches what this '
        'lesson actually says.',
  ),
  keyTakeaway:
      'Entity registration, barangay clearance, a Business Permit, '
      'applicable local checks, BIR registration, and permission to '
      'operate generally relate in that rough order, though LGU processes '
      'differ and not every clearance applies to every business; a DTI, '
      'SEC, or CDA registration alone is never permission to operate.',
);

// ---------------------------------------------------------------------------
// Lesson 3: Renewals and Ongoing Local Compliance
// ---------------------------------------------------------------------------

const _renewalsAndLocalCompliance = MoneyLesson(
  id: bpccRenewalsAndLocalCompliance,
  trackId: 'business_permits_and_compliance',
  title: 'Renewals and Ongoing Local Compliance',
  icon: 'calendar',
  minutes: 3,
  summary:
      'Permits and licenses generally need renewing, and business '
      'changes and inspections need following up, on a calendar worth '
      'building rather than assuming.',
  objective:
      'Name what belongs on a compliance calendar, using general timing '
      'labels rather than a specific date for any real permit.',
  sections: [],
  governance: _governance,
  sources: [_pbh, _dilgEboss],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A local permit or license is rarely a one-time step. Permit '
            'renewals, license renewals, a change in business address or '
            'activity, inspection follow-ups, employer reporting, and '
            'industry authorization reviews all generally need tracking '
            'over time, not only at the start.',
        'This lesson never states an exact renewal date, since the '
            'issuing office sets that, and it changes by LGU and by '
            'permit type. What it teaches instead is a small set of '
            'general timing labels worth building into a personal '
            'calendar: before expiry, when business details change, '
            'before expanding activities, and always to check with the '
            'issuing agency for the actual current timing.',
      ],
    ),
    NuggetsBlock([
      'Permit and license renewals, address or activity changes, '
          'inspection follow-ups, employer reporting, and industry '
          'authorization reviews all generally belong on a compliance '
          'calendar.',
      'General timing labels, before expiry, when business details '
          'change, before expanding activities, work better than '
          'guessing at a specific date.',
      'The issuing agency is always the source for the real current '
          'timing, never this lesson.',
    ]),
    RiskWarningBlock(
      title: 'No exact date is stated here',
      text:
          'Confirm current requirements with the issuing office. Renewal '
          'and reporting timing is set by each agency and can change; '
          'this lesson only names what is worth tracking, never a '
          'specific date.',
    ),
    OfficialSourceBlock(
      agency: _pbhAgency,
      sourceTitle: _pbhTitle,
      canonicalUrl: _pbhUrl,
      lastVerifiedDate: _pbhVerified,
    ),
    OfficialSourceBlock(
      agency: _dilgAgency,
      sourceTitle: _dilgEbossTitle,
      canonicalUrl: _dilgEbossUrl,
      lastVerifiedDate: _dilgEbossVerified,
    ),
    _boundaryLocal,
  ],
  interactionBlocks: [
    ChecklistBlock(
      blockId: 'compliance-calendar-planning',
      checklistPrompt:
          'A private calendar-planning checklist. Nothing here is saved '
          'or shared.',
      items: [
        ChecklistItemDef(
          id: 'permit-renewals-tracked',
          label: 'Permit renewals are being tracked',
          required: false,
        ),
        ChecklistItemDef(
          id: 'license-renewals-tracked',
          label: 'License renewals are being tracked',
          required: false,
        ),
        ChecklistItemDef(
          id: 'address-activity-changes-tracked',
          label:
              'A plan exists for reporting a change in business address '
              'or activity',
          required: false,
        ),
        ChecklistItemDef(
          id: 'inspection-followups-tracked',
          label: 'Inspection follow-ups are being tracked',
          required: false,
        ),
        ChecklistItemDef(
          id: 'employer-reporting-tracked',
          label: 'Employer reporting, if applicable, is being tracked',
          required: false,
        ),
        ChecklistItemDef(
          id: 'industry-review-tracked',
          label:
              'Industry authorization reviews, if applicable, are being '
              'tracked',
          required: false,
        ),
      ],
      allRequiredMustBeChecked: false,
      requiredForCompletion: false,
    ),
    MythOrFactBlock(
      blockId: 'calendar-knows-exact-date-myth',
      statement:
          'This compliance calendar can tell a reader the exact date '
          'their real permit or license is due for renewal.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'It never can. This lesson only names general timing labels '
          '(before expiry, when business details change, before '
          'expanding activities); the issuing agency is the only source '
          'for a real permit or license\'s actual renewal date.',
      requiredForCompletion: true,
    ),
    SalapifyActionsBlock(
      blockId: 'compliance-calendar-reminder-action',
      menuPrompt: 'A real next step, if it fits.',
      actions: [
        SalapifyActionDef(
          id: 'open-compliance-reminder',
          label: 'Open reminders',
          description:
              'Opens Notifications and security, where a reminder can be '
              'turned on by hand for a renewal or reporting check-in. '
              'Nothing is scheduled automatically; nothing is saved '
              'until it is confirmed on that screen.',
          route: 'notifications',
        ),
      ],
    ),
  ],
  check: KnowledgeCheck(
    question:
        'Does this lesson state an exact renewal date for any real '
        'permit or license?',
    choices: [
      'Yes, a specific date is given for permit renewals',
      'No, it uses general timing labels and always points to the '
          'issuing agency for the real date',
      'Yes, but only for licenses, never for permits',
    ],
    correctIndex: 1,
    explanation:
        'This lesson deliberately never states an exact date, since '
        'renewal timing is set by each issuing agency and can change.',
    whyWrong:
        'Neither claiming a specific date is given, nor limiting that to '
        'licenses only, matches what this lesson actually does.',
  ),
  keyTakeaway:
      'A compliance calendar tracks permit and license renewals, address '
      'or activity changes, inspection follow-ups, employer reporting, '
      'and industry authorization reviews using general timing labels, '
      'never a guessed date, and the issuing agency is always the real '
      'source for exact timing.',
);

// ---------------------------------------------------------------------------
// Lesson 4: When You Hire People
// ---------------------------------------------------------------------------

const _whenYouHirePeople = MoneyLesson(
  id: bpccWhenYouHirePeople,
  trackId: 'business_permits_and_compliance',
  title: 'When You Hire People',
  icon: 'group',
  minutes: 3,
  summary:
      'Becoming an employer can bring in SSS, PhilHealth, Pag-IBIG, '
      'payroll records, and labor standards, well before any contribution '
      'is calculated.',
  objective:
      'Name the kinds of responsibility becoming an employer can '
      'introduce, without calculating a contribution or classifying a '
      'real worker.',
  sections: [],
  governance: _governance,
  sources: [_sss, _philhealth],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Bringing someone on to help can quietly turn into becoming an '
            'employer, and that generally introduces responsibilities '
            'well beyond paying an agreed amount. SSS, PhilHealth, and '
            'the Pag-IBIG Fund each generally have their own '
            'employer-registration duties. Employee reporting, '
            'contribution remittance, payroll and employment records, '
            'labor standards, and workplace safety and health can all '
            'generally apply once an employer relationship exists.',
        'This lesson never calculates a contribution amount, and it '
            'never decides whether a specific real person is an employee, '
            'a contractor, an intern, or a partner. That distinction '
            'depends on the real facts of a specific working '
            'relationship, and getting it wrong can carry real '
            'consequences, so confirming the worker relationship itself, '
            'before anything else, is generally the right first step.',
      ],
    ),
    NuggetsBlock([
      'Becoming an employer can introduce duties involving SSS, '
          'PhilHealth, and the Pag-IBIG Fund.',
      'Employee reporting, contribution remittance, payroll and '
          'employment records, labor standards, and workplace safety and '
          'health can all generally apply.',
      'Confirming the worker relationship itself generally comes before '
          'anything else; this lesson never makes that determination for '
          'a real person.',
      'Professional HR or legal advice may be useful once a real '
          'employer relationship is confirmed.',
    ]),
    RiskWarningBlock(
      title: 'No calculation, no classification',
      text:
          'This lesson never calculates a contribution and never '
          'classifies a real worker as an employee, contractor, intern, '
          'or partner. Professional HR or legal advice may be useful for '
          'a real hiring decision.',
    ),
    OfficialSourceBlock(
      agency: _sssAgency,
      sourceTitle: _sssTitle,
      canonicalUrl: _sssUrl,
      lastVerifiedDate: _sssVerified,
    ),
    OfficialSourceBlock(
      agency: _philhealthAgency,
      sourceTitle: _philhealthTitle,
      canonicalUrl: _philhealthUrl,
      lastVerifiedDate: _philhealthVerified,
    ),
    _boundaryEmployer,
  ],
  interactionBlocks: [
    ScenarioChoiceBlock(
      blockId: 'when-you-hire-people-scenario',
      scenarioTitle: 'A fictional business about to bring on help',
      situation:
          'A fictional small business is about to bring someone on to '
          'help for the first time and wants to know what to check '
          'before anything else.',
      options: [
        ScenarioChoiceOption(
          id: 'confirm-worker-relationship',
          label: 'Confirm the worker relationship first',
          explanation:
              'Generally the right first step. Whether someone is an '
              'employee, contractor, intern, or partner shapes every '
              'duty that follows, and this course never makes that call '
              'for a real person.',
        ),
        ScenarioChoiceOption(
          id: 'check-employer-registration',
          label: 'Check employer-registration duties',
          explanation:
              'Worth checking once the working relationship is '
              'confirmed. SSS, PhilHealth, and Pag-IBIG each generally '
              'have their own employer-registration process.',
        ),
        ScenarioChoiceOption(
          id: 'prepare-payroll-records',
          label: 'Prepare payroll and compliance records',
          explanation:
              'Also worth preparing once the relationship and '
              'registration duties are clear, records generally need to '
              'be kept on an ongoing basis, not only at the start.',
        ),
        ScenarioChoiceOption(
          id: 'get-hr-or-legal-advice',
          label: 'Get professional HR or legal advice',
          explanation:
              'May be useful, especially where the working relationship '
              'or the duties that follow are not clear from general '
              'reading alone.',
        ),
      ],
      requiredForCompletion: true,
    ),
    CategorizeBlock(
      blockId: 'employer-agency-awareness',
      categorizePrompt:
          'Match each fictional employer action to the agency it '
          'generally involves.',
      buckets: [
        CategorizeBucket(id: 'bucket-sss', label: 'SSS'),
        CategorizeBucket(id: 'bucket-philhealth', label: 'PhilHealth'),
        CategorizeBucket(id: 'bucket-pagibig', label: 'Pag-IBIG Fund'),
      ],
      items: [
        CategorizeItemDef(
          id: 'retirement-disability',
          label:
              'A fictional employer registers a new hire for retirement '
              'and disability protection',
          explanation:
              'SSS generally covers retirement, disability, and related '
              'social security protection for employees.',
        ),
        CategorizeItemDef(
          id: 'health-coverage',
          label:
              'A fictional employer registers a new hire for health '
              'insurance coverage',
          explanation:
              'PhilHealth generally covers health insurance for '
              'employees.',
        ),
        CategorizeItemDef(
          id: 'savings-housing',
          label:
              'A fictional employer registers a new hire for a savings '
              'and housing program',
          explanation:
              'The Pag-IBIG Fund generally covers savings and housing '
              'related programs for employees.',
        ),
      ],
      correctBucketByItemId: {
        'retirement-disability': 'bucket-sss',
        'health-coverage': 'bucket-philhealth',
        'savings-housing': 'bucket-pagibig',
      },
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'Does this lesson calculate a contribution amount or decide '
        'whether a real worker is an employee, contractor, intern, or '
        'partner?',
    choices: [
      'Yes, it calculates a sample contribution amount',
      'No, it names the responsibilities that can apply and leaves both '
          'the calculation and the classification to the real agencies '
          'or a professional',
      'Yes, but only for the worker classification, never the '
          'contribution',
    ],
    correctIndex: 1,
    explanation:
        'This lesson deliberately never calculates a contribution and '
        'never classifies a real worker; both depend on real facts this '
        'lesson does not have.',
    whyWrong:
        'Neither claiming a calculation is shown, nor claiming only the '
        'classification is skipped, matches what this lesson actually '
        'does.',
  ),
  keyTakeaway:
      'Becoming an employer can introduce duties involving SSS, '
      'PhilHealth, the Pag-IBIG Fund, employee reporting, payroll and '
      'employment records, labor standards, and workplace safety and '
      'health; confirming the real worker relationship generally comes '
      'first, and this lesson never calculates a contribution or makes '
      'that classification itself.',
);

// ---------------------------------------------------------------------------
// Lesson 5: Check for Industry-Specific Regulators
// ---------------------------------------------------------------------------

const _industrySpecificRegulators = MoneyLesson(
  id: bpccIndustrySpecificRegulators,
  trackId: 'business_permits_and_compliance',
  title: 'Check for Industry-Specific Regulators',
  icon: 'search',
  minutes: 3,
  summary:
      'Some activities need authorization beyond the usual local permit. '
      'This lesson names three verified examples and points everything '
      'else back to the LGU and the responsible national agency.',
  objective:
      'Recognize that some activities may need a separate regulator, '
      'using only verified examples, without deciding a licensing '
      'outcome for any real business.',
  sections: [],
  governance: _governance,
  sources: [_fda, _pcab, _dot],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A city or municipal Business Permit does not automatically '
            'cover every activity. Some activities need authorization '
            'from a separate national regulator. Three verified examples: '
            'the Food and Drug Administration (FDA) for activities '
            'involving regulated health products, the Philippine '
            'Contractors Accreditation Board (PCAB) for construction '
            'contracting, and the Department of Tourism (DOT) for '
            'covered tourism enterprises.',
        'Other areas, financial services, transportation, education, '
            'environmental activities, telecommunications, and '
            'professional services, can also involve their own regulator, '
            'but this course never assigns a specific one to those '
            'generic categories, since that mapping was not independently '
            'verifiable from an official source within this course\'s own '
            'review. For any activity not covered by a verified example '
            'here, the safe next step is: check with your LGU and the '
            'national agency responsible for your activity.',
      ],
    ),
    NuggetsBlock([
      'The FDA generally applies to activities involving regulated '
          'health products.',
      'PCAB generally applies to construction contracting.',
      'The DOT generally applies to covered tourism enterprises.',
      'Financial services, transportation, education, environmental '
          'activities, telecommunications, and professional services can '
          'also involve a regulator, but this course never names one for '
          'those categories without a verified source.',
    ]),
    RiskWarningBlock(
      title: 'Never a licensing decision',
      text:
          'A separate industry authorization may apply. This lesson '
          'never determines whether a real business needs, qualifies '
          'for, or will receive a license from any regulator; verifying '
          'the activity with the official agency is always the real next '
          'step.',
    ),
    OfficialSourceBlock(
      agency: _fdaAgency,
      sourceTitle: _fdaTitle,
      canonicalUrl: _fdaUrl,
      lastVerifiedDate: _fdaVerified,
    ),
    OfficialSourceBlock(
      agency: _pcabAgency,
      sourceTitle: _pcabTitle,
      canonicalUrl: _pcabUrl,
      lastVerifiedDate: _pcabVerified,
    ),
    OfficialSourceBlock(
      agency: _dotAgency,
      sourceTitle: _dotTitle,
      canonicalUrl: _dotUrl,
      lastVerifiedDate: _dotVerified,
    ),
    _boundaryIndustry,
  ],
  interactionBlocks: [
    CategorizeBlock(
      blockId: 'industry-regulator-activity-triage',
      categorizePrompt:
          'For each fictional activity, choose the result that fits. '
          'This is not a licensing decision.',
      buckets: [
        CategorizeBucket(
          id: 'bucket-fda',
          label: 'A separate regulator may apply: FDA',
        ),
        CategorizeBucket(
          id: 'bucket-pcab',
          label: 'A separate regulator may apply: PCAB',
        ),
        CategorizeBucket(
          id: 'bucket-dot',
          label: 'A separate regulator may apply: DOT',
        ),
        CategorizeBucket(
          id: 'bucket-check',
          label: 'Check with your LGU and the responsible national agency',
        ),
      ],
      items: [
        CategorizeItemDef(
          id: 'health-product-retail',
          label:
              'A fictional business plans to sell a regulated health '
              'product',
          explanation:
              'A separate regulator, the FDA, may apply. Verify the '
              'activity with the official agency; this result is not a '
              'licensing decision.',
        ),
        CategorizeItemDef(
          id: 'construction-contracting',
          label:
              'A fictional business plans to take on construction '
              'contracting work',
          explanation:
              'A separate regulator, PCAB, may apply. Verify the '
              'activity with the official agency; this result is not a '
              'licensing decision.',
        ),
        CategorizeItemDef(
          id: 'tourism-enterprise',
          label:
              'A fictional business plans to run a covered tourism '
              'enterprise',
          explanation:
              'A separate regulator, the DOT, may apply. Verify the '
              'activity with the official agency; this result is not a '
              'licensing decision.',
        ),
        CategorizeItemDef(
          id: 'financial-services-idea',
          label: 'A fictional business plans to offer a financial service',
          explanation:
              'More than one regulator may be involved for an activity '
              'like this. Check with your LGU and the national agency '
              'responsible for your activity; this result is not a '
              'licensing decision.',
        ),
      ],
      correctBucketByItemId: {
        'health-product-retail': 'bucket-fda',
        'construction-contracting': 'bucket-pcab',
        'tourism-enterprise': 'bucket-dot',
        'financial-services-idea': 'bucket-check',
      },
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'business-permit-covers-everything-myth',
      statement:
          'A city or municipal Business Permit automatically covers '
          'every activity a business might do, with no separate '
          'regulator ever needed.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Some activities need authorization from a separate national '
          'regulator beyond the usual Business Permit; verifying the '
          'specific activity with the official agency is always worth '
          'doing.',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'According to this lesson, does completing the activity triage '
        'tell a reader they definitely need, qualify for, or will '
        'receive a license?',
    choices: [
      'Yes, a matched bucket is a final licensing decision',
      'No, every result points to verifying with the official agency and '
          'is explicitly not a licensing decision',
      'Yes, but only for the FDA example',
    ],
    correctIndex: 1,
    explanation:
        'Every result in this lesson explicitly says it is not a '
        'licensing decision and points back to verifying with the '
        'official agency.',
    whyWrong:
        'Neither treating any match as a final decision, nor limiting '
        'that disclaimer to one example, matches what this lesson '
        'actually does.',
  ),
  keyTakeaway:
      'The FDA, PCAB, and DOT are three verified examples of '
      'industry-specific regulators that can apply beyond the usual '
      'Business Permit; other categories can also involve a regulator, '
      'but this lesson never assigns one without a verified source, and '
      'no result here is ever a licensing decision.',
);

// ---------------------------------------------------------------------------
// Lesson 6: Build Your Compliance Map
// ---------------------------------------------------------------------------

const _buildYourComplianceMap = MoneyLesson(
  id: bpccBuildYourComplianceMap,
  trackId: 'business_permits_and_compliance',
  title: 'Build Your Compliance Map',
  icon: 'plan',
  minutes: 4,
  summary:
      'A generic roadmap tying together the LGU, barangay, permits, '
      'employer checks, industry regulators, renewals, and a compliance '
      'budget, with real Salapify screens to check when any of it fits.',
  objective:
      'Build a generic compliance roadmap covering what to check next, '
      'without generating a personalized checklist or creating any '
      'record automatically.',
  sections: [],
  governance: _governance,
  sources: [_pbh],
  topics: [ContentTopic.businessTaxOrPermitCompliance],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A compliance map ties this course together: the LGU office to '
            'check, the barangay step to confirm, the Business or '
            'Mayor\'s Permit, possible local clearances, employer '
            'registration checks, industry regulator checks, renewal '
            'reminders, a compliance budget, and the official-source '
            'review dates each course lesson already carries.',
        'This is a roadmap of what is worth investigating, never a '
            'finished checklist. It does not know a real address, a real '
            'activity\'s full detail, or whether a real business will '
            'hire anyone, so it never claims completeness, never '
            'guarantees approval, and never determines an employer or '
            'worker\'s real legal status.',
      ],
    ),
    DiagramBlock(
      steps: [
        'LGU office to check',
        'Barangay step to confirm',
        'Business or Mayor\'s Permit',
        'Possible local clearances',
        'Employer registration checks',
        'Industry regulator checks',
        'Renewal reminders',
        'Compliance budget',
        'Official-source review dates',
      ],
      caption:
          'A generic roadmap, not a finished checklist for any '
          'real business',
    ),
    NuggetsBlock([
      'This roadmap names what is worth checking, never a finished '
          'checklist for a real address or activity.',
      'It never guarantees approval and never determines a real '
          'employer or worker\'s legal status.',
      'A compliance budget and a way to remember renewals round out a '
          'realistic plan.',
    ]),
    RiskWarningBlock(
      title: 'A roadmap, never a finished checklist',
      text:
          'Requirements vary by LGU and business activity. Confirm '
          'current requirements with the issuing office. A separate '
          'industry authorization may apply. This roadmap never '
          'guarantees completeness or approval.',
    ),
    OfficialSourceBlock(
      agency: _pbhAgency,
      sourceTitle: _pbhTitle,
      canonicalUrl: _pbhUrl,
      lastVerifiedDate: _pbhVerified,
    ),
    _boundaryLocal,
  ],
  interactionBlocks: [
    ChecklistBlock(
      blockId: 'compliance-map-checklist',
      checklistPrompt:
          'A personal roadmap to work through at your own pace. '
          'Offline, and yours to keep.',
      items: [
        ChecklistItemDef(
          id: 'lgu-office-checked',
          label: 'The LGU office to check has been identified',
          required: false,
        ),
        ChecklistItemDef(
          id: 'barangay-step-confirmed',
          label: 'The barangay step has been confirmed',
          required: false,
        ),
        ChecklistItemDef(
          id: 'business-permit-tracked',
          label: 'The Business or Mayor\'s Permit is being tracked',
          required: false,
        ),
        ChecklistItemDef(
          id: 'local-clearances-considered',
          label: 'Possible local clearances have been considered',
          required: false,
        ),
        ChecklistItemDef(
          id: 'employer-checks-considered',
          label:
              'Employer registration checks have been considered, if '
              'applicable',
          required: false,
        ),
        ChecklistItemDef(
          id: 'industry-checks-considered',
          label:
              'Industry regulator checks have been considered, if '
              'applicable',
          required: false,
        ),
        ChecklistItemDef(
          id: 'compliance-budget-considered',
          label: 'A compliance budget has been considered',
          required: false,
        ),
      ],
      allRequiredMustBeChecked: false,
      requiredForCompletion: false,
    ),
    MythOrFactBlock(
      blockId: 'compliance-map-auto-creates-myth',
      statement:
          'Working through this compliance map automatically creates a '
          'goal, a budget line, a recurring cost, or a reminder.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Nothing here creates or changes a financial record '
          'automatically. Each destination named in this lesson still '
          'needs your own confirmation inside that screen before '
          'anything is saved.',
      requiredForCompletion: true,
    ),
    SalapifyActionsBlock(
      blockId: 'compliance-map-actions',
      menuPrompt: 'A few real next steps, if any of them fit.',
      actions: [
        SalapifyActionDef(
          id: 'start-compliance-sinking-fund',
          label: 'Start a compliance savings goal',
          description:
              'Opens Goals to check or start a business sinking fund for '
              'permits, clearances, or renewal costs. Nothing is created '
              'until something is saved there.',
          route: 'goals',
        ),
        SalapifyActionDef(
          id: 'review-compliance-budget',
          label: 'Review a compliance-cost budget',
          description:
              'Opens Budget, where a compliance-cost or business-expense '
              'category can already be checked or set aside for. Nothing '
              'changes automatically.',
          route: 'budget',
        ),
        SalapifyActionDef(
          id: 'track-renewal-as-recurring',
          label: 'Track a renewal as a recurring cost',
          description:
              'Opens Recurring, where a periodic cost like a permit or '
              'license renewal can already be tracked if you choose to '
              'add one. Nothing is created automatically.',
          route: 'recurring',
        ),
        SalapifyActionDef(
          id: 'open-compliance-map-reminders',
          label: 'Open reminders',
          description:
              'Opens Notifications and security, where a reminder can be '
              'turned on by hand. Nothing is scheduled automatically.',
          route: 'notifications',
        ),
      ],
    ),
  ],
  check: KnowledgeCheck(
    question:
        'Does this compliance map guarantee that following it means a '
        'real business has covered every requirement?',
    choices: [
      'Yes, completing the roadmap guarantees full compliance',
      'No, it names what is worth checking and never guarantees '
          'completeness or approval',
      'Yes, but only for businesses that do not hire anyone',
    ],
    correctIndex: 1,
    explanation:
        'This lesson explicitly never claims completeness or guarantees '
        'approval; it is a roadmap of what to check, not a finished '
        'result.',
    whyWrong:
        'Neither claiming a guarantee, nor limiting that guarantee to '
        'businesses with no employees, matches what this lesson actually '
        'says.',
  ),
  keyTakeaway:
      'A compliance map ties together the LGU office, the barangay step, '
      'the Business Permit, possible local clearances, employer and '
      'industry regulator checks, renewal reminders, and a compliance '
      'budget as a roadmap to investigate, never a finished checklist '
      'or a guarantee, and turning any of it into a real Salapify record '
      'still needs your own confirmation inside that screen.',
);
