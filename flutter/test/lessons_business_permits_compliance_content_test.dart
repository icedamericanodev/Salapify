// Money Courses Phase 15 content contract: "Build Your Business" learning
// path's FOURTH course, "Permits, People, and Compliance" (course id
// 'business_permits_and_compliance'). Proves this course is registered
// correctly, stays fully isolated from the core 22 lessons and every other
// expansion course, passes the house rules (no em/en dash, no eligibility
// or approval promise, no sensitive-data collection, no implied government
// affiliation), the Phase 4 content policy validator, and this course's own
// house rules: no static fee, processing time, renewal date, deadline,
// document list, form number, contribution rate, portal step, or penalty
// anywhere; no local requirement presented as universal; no employer
// calculation or worker classification; no industry interaction that makes
// a licensing decision.
//
// Mirrors test/lessons_bir_local_permits_content_test.dart's own structure
// on purpose, the established shape for a Money Courses content contract
// test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/learning_path.dart';
import 'package:salapify/content/learning_paths.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons.dart' as core;
import 'package:salapify/content/lessons_bir_local_permits.dart';
import 'package:salapify/content/lessons_bir_tax_setup.dart';
import 'package:salapify/content/lessons_business_permits_compliance.dart';
import 'package:salapify/content/lessons_business_registration.dart';
import 'package:salapify/content/lessons_crypto.dart';
import 'package:salapify/content/lessons_deposits_pooled_funds.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/content/lessons_insurance.dart';
import 'package:salapify/content/lessons_pagibig.dart';
import 'package:salapify/content/lessons_ph_government_securities.dart';
import 'package:salapify/content/lessons_sss_philhealth.dart';
import 'package:salapify/content/lessons_stocks_bonds.dart';
import 'package:salapify/money/expansion_content_policy.dart';
import 'package:salapify/money/expansion_progress.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/interaction_block_views.dart';

import 'screens_shot.dart' show loadRealFonts;

final _ref = DateTime.utc(2026, 8, 5);

const _stableLessonIds = [
  bpccLocationChangesTheChecklist,
  bpccMapTheLocalPermitFlow,
  bpccRenewalsAndLocalCompliance,
  bpccWhenYouHirePeople,
  bpccIndustrySpecificRegulators,
  bpccBuildYourComplianceMap,
];

void main() {
  group('registration', () {
    test('build_your_business carries this course as its fourth group, after '
        'its three sibling courses', () {
      final path = learningPaths.firstWhere(
        (p) => p.id == 'build_your_business',
      );
      expect(path.status, LearningPathStatus.published);
      expect(path.isAvailable, isTrue);
      expect(path.groups.length, 4);
      expect(path.groups[0].id, 'start_a_business_legally');
      expect(path.groups[1].id, 'bir_registration_and_local_permits');
      expect(path.groups[2].id, 'bir_registration_tax_setup');
      final group = path.groups[3];
      expect(group.id, 'business_permits_and_compliance');
      expect(group.title, 'Permits, People, and Compliance');
      expect(group.lessonIds, _stableLessonIds);
      expect(group.recommendedPriorGroupIds, [
        'start_a_business_legally',
        'bir_registration_and_local_permits',
        'bir_registration_tax_setup',
      ]);
      // 6 + 6 + 6 lessons from the three sibling courses, then this
      // course's own six, leading the path's full lessonIds list.
      expect(path.lessonIds.sublist(18, 24), _stableLessonIds);
      expect(path.lessonIds.length, 24);
    });

    test('the course is not registered under grow_your_money, '
        'protect_your_future, or any of its three sibling '
        'build_your_business courses', () {
      for (final path in learningPaths) {
        for (final group in path.groups) {
          if (group.id == 'business_permits_and_compliance') continue;
          for (final id in _stableLessonIds) {
            expect(
              group.lessonIds.contains(id),
              isFalse,
              reason: '$id leaked into ${path.id}/${group.id}',
            );
          }
        }
      }
    });

    test('publishedLearningPaths still shows exactly three real paths', () {
      expect(publishedLearningPaths.map((p) => p.id), [
        'grow_your_money',
        'protect_your_future',
        'build_your_business',
      ]);
    });

    test('six stable lesson ids, in reading order, exactly as specified', () {
      expect(
        businessPermitsAndComplianceLessons.map((l) => l.id).toList(),
        _stableLessonIds,
      );
      expect(_stableLessonIds, [
        'location_changes_the_checklist',
        'map_the_local_permit_flow',
        'renewals_and_local_compliance',
        'when_you_hire_people',
        'industry_specific_regulators',
        'build_your_compliance_map',
      ]);
    });

    test('course and lesson ids are unique', () {
      expect(_stableLessonIds.toSet().length, 6);
      expect(
        _stableLessonIds.contains('business_permits_and_compliance'),
        isFalse,
      );
    });

    test('every lesson is registered under the '
        'business_permits_and_compliance trackId', () {
      for (final l in businessPermitsAndComplianceLessons) {
        expect(l.trackId, 'business_permits_and_compliance');
      }
    });

    test('expansionLessonById resolves a lesson from this course to the '
        'build_your_business path', () {
      final found = expansionLessonById(bpccLocationChangesTheChecklist);
      expect(found, isNotNull);
      expect(found!.pathId, 'build_your_business');
      expect(found.lesson.id, bpccLocationChangesTheChecklist);
    });
  });

  group('isolation from the core 22 and from every other expansion '
      'course', () {
    test('core lesson list is untouched: still 22 lessons, four courses', () {
      expect(core.lessons.length, 22);
      expect(core.courseTracks.length, 4);
    });

    test('every earlier expansion course is untouched', () {
      expect(growYourMoneyLessons.length, 5);
      expect(stocksAndBondsLessons.length, 6);
      expect(depositsAndPooledFundsLessons.length, 6);
      expect(cryptoWithoutHypeLessons.length, 6);
      expect(phGovernmentSecuritiesLessons.length, 6);
      expect(insuranceDecodedLessons.length, 6);
      expect(sssPhilhealthBenefitsLessons.length, 6);
      expect(pagibigSavingsMp2HousingLessons.length, 6);
      expect(startABusinessLegallyLessons.length, 6);
      expect(birRegistrationAndLocalPermitsLessons.length, 6);
      expect(birRegistrationTaxSetupLessons.length, 6);
    });

    test('Phase 13 and Phase 14 courses are unchanged, lesson by lesson '
        'id', () {
      expect(startABusinessLegallyLessons.map((l) => l.id).toList(), [
        'before_you_register',
        'compare_business_structures',
        'match_structure_to_agency',
        'business_name_and_brand',
        'registration_is_not_permission',
        'build_registration_roadmap',
      ]);
      expect(birRegistrationAndLocalPermitsLessons.map((l) => l.id).toList(), [
        'bir-local-order-that-matters',
        'bir-local-get-your-tin',
        'bir-local-books-and-invoices',
        'bir-local-barangay-and-mayor',
        'bir-local-taxpayer-size',
        'bir-local-compliance-calendar',
      ]);
    });

    test('none of the new ids appear in the core flat lesson list', () {
      final coreIds = core.lessons.map((l) => l['id']).toSet();
      for (final id in _stableLessonIds) {
        expect(coreIds.contains(id), isFalse, reason: '$id leaked into core');
      }
    });

    test('none of the new ids collide with any other expansion lesson '
        'id', () {
      final otherIds = {
        ...growYourMoneyLessons.map((l) => l.id),
        ...stocksAndBondsLessons.map((l) => l.id),
        ...depositsAndPooledFundsLessons.map((l) => l.id),
        ...cryptoWithoutHypeLessons.map((l) => l.id),
        ...phGovernmentSecuritiesLessons.map((l) => l.id),
        ...insuranceDecodedLessons.map((l) => l.id),
        ...sssPhilhealthBenefitsLessons.map((l) => l.id),
        ...pagibigSavingsMp2HousingLessons.map((l) => l.id),
        ...startABusinessLegallyLessons.map((l) => l.id),
        ...birRegistrationAndLocalPermitsLessons.map((l) => l.id),
        ...birRegistrationTaxSetupLessons.map((l) => l.id),
      };
      for (final id in _stableLessonIds) {
        expect(otherIds.contains(id), isFalse);
      }
    });

    test('none of the new ids appear more than once inside '
        'businessPermitsAndComplianceLessons', () {
      final ids = businessPermitsAndComplianceLessons.map((l) => l.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('expansion progress stays separate from core progress and from '
      'every other path\'s or course\'s own progress', () {
    test('writing progress for this course never touches an unrelated '
        'entry, including its own sibling courses', () {
      final existing = {
        'grow_your_money': {
          gsLendingToGovernment: {'state': 'completed'},
        },
        'build_your_business': {
          brBeforeYouRegister: {'state': 'completed'},
          birlOrderThatMatters: {'state': 'completed'},
        },
      };
      final out = withExpansionLessonState(
        existing,
        'build_your_business',
        bpccLocationChangesTheChecklist,
        LessonState.completed,
      );
      final parsed = parseExpansionProgress(out);
      expect(
        parsed['grow_your_money']?[gsLendingToGovernment],
        LessonState.completed,
        reason:
            'an unrelated path\'s existing progress must survive '
            'untouched',
      );
      expect(
        parsed['build_your_business']?[brBeforeYouRegister],
        LessonState.completed,
        reason:
            'a sibling course\'s own existing progress must survive '
            'untouched',
      );
      expect(
        parsed['build_your_business']?[birlOrderThatMatters],
        LessonState.completed,
        reason:
            'a second sibling course\'s own existing progress must '
            'survive untouched',
      );
      expect(
        parsed['build_your_business']?[bpccLocationChangesTheChecklist],
        LessonState.completed,
      );
    });

    test('pathProgressFor counts across all four courses in the '
        'flattened path total', () {
      final progress = parseExpansionProgress({
        'build_your_business': {
          brBeforeYouRegister: {'state': 'completed'},
          birlOrderThatMatters: {'state': 'completed'},
          bpccLocationChangesTheChecklist: {'state': 'completed'},
          bpccMapTheLocalPermitFlow: {'state': 'viewed'},
        },
      });
      final pp = pathProgressFor(
        pathId: 'build_your_business',
        lessonIds: [
          ...startABusinessLegallyLessons.map((l) => l.id),
          ...birRegistrationAndLocalPermitsLessons.map((l) => l.id),
          ...birRegistrationTaxSetupLessons.map((l) => l.id),
          ..._stableLessonIds,
        ],
        progress: progress['build_your_business'] ?? const {},
      );
      expect(pp.total, 24);
      expect(pp.done, 3);
    });
  });

  group('content policy validator (Phase 4)', () {
    test('every lesson has zero validation errors', () {
      for (final lesson in businessPermitsAndComplianceLessons) {
        final result = validateExpansionLesson(lesson, referenceDate: _ref);
        expect(
          isPublishable(result),
          isTrue,
          reason: '${lesson.id}: ${result.errors.join('; ')}',
        );
      }
    });

    test('every lesson carries a businessTaxOrPermitCompliance topic, '
        'making it regulated content under the validator\'s own '
        'definition', () {
      for (final lesson in businessPermitsAndComplianceLessons) {
        expect(
          lesson.topics,
          contains(ContentTopic.businessTaxOrPermitCompliance),
          reason: '${lesson.id} carries no matching ContentTopic',
        );
      }
    });

    test('every lesson is classified ContentVolatility.annual, never '
        'high, since this course states no volatile figure anywhere', () {
      for (final lesson in businessPermitsAndComplianceLessons) {
        expect(
          lesson.governance.volatility,
          ContentVolatility.annual,
          reason: '${lesson.id} is not classified annual',
        );
      }
    });
  });

  // Eight, not the ten the task originally listed: the legal-review pass
  // could not independently confirm two of the original ten URLs as real,
  // currently-live pages at those exact paths (a DILG "barangay clearance
  // integration" circular and a Pag-IBIG Fund employer-registration
  // checklist PDF), so both were dropped from this course's sources rather
  // than shipped unverified. A later independent re-search then found that
  // the eBOSS circular URL that review DID keep, a DILG-hosted PDF, could
  // not itself be confirmed either, and replaced it with the Anti-Red Tape
  // Authority's own hosted copy of the same circular, confirmed directly.
  // See the content file's own header comment.
  group('official-source metadata', () {
    const allowedUrls = {
      'https://business.gov.ph/business-application-process',
      'https://bnrs.dti.gov.ph/faq',
      'https://arta.gov.ph/wp-content/uploads/2021/08/Memorandum-Circular-No.-2021-02-Automation-of-their-Buisness-Permitting-and-Licensing-Systems-or-eBOSS.pdf',
      'https://www.sss.gov.ph/employer-er/',
      'https://www.philhealth.gov.ph/partners/employers/registration.php',
      'https://www.fda.gov.ph/',
      'https://pcab.construction.gov.ph/',
      'https://www.tourism.gov.ph/',
    };

    test(
      'every lesson cites at least one structured, HTTPS official source',
      () {
        for (final lesson in businessPermitsAndComplianceLessons) {
          expect(
            lesson.sources,
            isNotEmpty,
            reason: '${lesson.id} has no sources',
          );
          for (final s in lesson.sources) {
            final uri = Uri.tryParse(s.canonicalUrl);
            expect(uri != null && uri.scheme == 'https', isTrue);
            expect(s.agency, isNotEmpty);
            expect(s.title, isNotEmpty);
          }
        }
      },
    );

    test('every lesson renders an OfficialSourceBlock', () {
      for (final lesson in businessPermitsAndComplianceLessons) {
        expect(
          lesson.blocks.whereType<OfficialSourceBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no OfficialSourceBlock',
        );
      }
    });

    test('every source is one of the eight confirmed official pages, '
        'never a blog, accounting firm, or law firm', () {
      for (final lesson in businessPermitsAndComplianceLessons) {
        for (final s in lesson.sources) {
          expect(
            allowedUrls.contains(s.canonicalUrl),
            isTrue,
            reason:
                '${lesson.id} cites an unexpected source: '
                '${s.canonicalUrl}',
          );
        }
      }
    });

    test('every one of the eight official sources is cited by at least one '
        'lesson', () {
      final cited = {
        for (final l in businessPermitsAndComplianceLessons)
          for (final s in l.sources) s.canonicalUrl,
      };
      expect(cited, allowedUrls);
    });

    test('every source agency exactly matches its own URL\'s domain', () {
      const expectedAgencyByHost = {
        'business.gov.ph': 'Philippine Business Hub',
        'bnrs.dti.gov.ph': 'Department of Trade and Industry (DTI)',
        'arta.gov.ph': 'Anti-Red Tape Authority (ARTA)',
        'www.sss.gov.ph': 'Social Security System (SSS)',
        'www.philhealth.gov.ph':
            'Philippine Health Insurance Corporation (PhilHealth)',
        'www.fda.gov.ph': 'Food and Drug Administration (FDA)',
        'pcab.construction.gov.ph':
            'Philippine Contractors Accreditation Board (PCAB)',
        'www.tourism.gov.ph': 'Department of Tourism (DOT)',
      };
      for (final lesson in businessPermitsAndComplianceLessons) {
        for (final s in lesson.sources) {
          final host = Uri.parse(s.canonicalUrl).host;
          expect(
            expectedAgencyByHost[host],
            s.agency,
            reason: '${lesson.id}: ${s.canonicalUrl} agency mismatch',
          );
        }
      }
    });

    test('verified and review-due dates are present and sane on every '
        'lesson', () {
      for (final lesson in businessPermitsAndComplianceLessons) {
        final g = lesson.governance;
        expect(g.lastVerifiedDate, isNotNull);
        expect(g.reviewDueDate, isNotNull);
        final verified = parseGovernanceDate(g.lastVerifiedDate!);
        final due = parseGovernanceDate(g.reviewDueDate!);
        expect(verified, isNotNull);
        expect(due, isNotNull);
        expect(due!.isAfter(verified!), isTrue);
      }
    });
  });

  group('high-volatility facts are absent: no fee, processing time, '
      'renewal date, deadline, document list, form number, contribution '
      'rate, portal step, or penalty anywhere', () {
    test('no lesson states a peso figure or a percentage anywhere', () {
      final banned = RegExp(
        r'\d+(\.\d+)?\s?%|(₱|php)\s?\d',
        caseSensitive: false,
      );
      for (final l in businessPermitsAndComplianceLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} states a peso figure or percentage',
        );
      }
    });

    test('no lesson states a form number', () {
      final banned = RegExp(
        r'\bform\s?\d{3,4}\b|\bBIR\s?form\b',
        caseSensitive: false,
      );
      for (final l in businessPermitsAndComplianceLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });

    test('no lesson states a specific calendar date or deadline', () {
      final banned = RegExp(
        r'\bJanuary \d|\bFebruary \d|\bMarch \d|\bApril \d|\bMay \d\d?|'
        r'\bJune \d|\bJuly \d|\bAugust \d|\bSeptember \d|\bOctober \d|'
        r'\bNovember \d|\bDecember \d|\bwithin \d+ days\b',
        caseSensitive: false,
      );
      for (final l in businessPermitsAndComplianceLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });
  });

  group('local requirements are not presented as universal', () {
    test('no lesson claims one fixed sequence or checklist applies to '
        'every business or every LGU', () {
      final banned = RegExp(
        r'\bevery LGU\b|\ball LGUs\b|\bevery barangay\b|\ball barangays\b|'
        r'\bevery city\b|\ball cities\b|\bthe same in every\b|'
        r'\bany municipality\b',
        caseSensitive: false,
      );
      for (final l in businessPermitsAndComplianceLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });

    test('lesson 1 explicitly teaches that location changes the '
        'checklist, via its own key takeaway', () {
      final l = businessPermitsAndComplianceLessons.firstWhere(
        (x) => x.id == bpccLocationChangesTheChecklist,
      );
      expect(l.keyTakeaway.toLowerCase().contains('depends on'), isTrue);
    });

    test('lesson 2 never presents one exact sequence as universal', () {
      final l = businessPermitsAndComplianceLessons.firstWhere(
        (x) => x.id == bpccMapTheLocalPermitFlow,
      );
      expect(_allText(l).toLowerCase().contains('generally'), isTrue);
    });

    test('lesson 2 sequences BIR registration AFTER barangay clearance '
        'and the Business Permit, never before: a real ordering error '
        'caught by the Phase 15 legal review (independently confirmed '
        'sources put entity registration, then barangay clearance, then '
        'the Business Permit and other local checks, then BIR '
        'registration, then permission to operate)', () {
      final l = businessPermitsAndComplianceLessons.firstWhere(
        (x) => x.id == bpccMapTheLocalPermitFlow,
      );
      final sorting = l.interactionBlocks.whereType<SortingBlock>().first;
      final order = sorting.items.map((i) => i.id).toList();
      final birIndex = order.indexOf('bir-registration');
      final barangayIndex = order.indexOf('barangay-clearance');
      final permitIndex = order.indexOf('mayors-permit');
      expect(birIndex, greaterThan(barangayIndex));
      expect(birIndex, greaterThan(permitIndex));
    });
  });

  group('employer content contains no calculations or worker '
      'classification', () {
    MoneyLesson employerLesson() => businessPermitsAndComplianceLessons
        .firstWhere((x) => x.id == bpccWhenYouHirePeople);

    test('no contribution amount or percentage is calculated', () {
      final banned = RegExp(
        r'\d+(\.\d+)?\s?%|(₱|php)\s?\d',
        caseSensitive: false,
      );
      expect(banned.hasMatch(_allText(employerLesson())), isFalse);
    });

    test('no real worker is classified as an employee, contractor, '
        'intern, or partner', () {
      final banned = RegExp(
        r'\byou are (an? )?(employee|contractor|intern|partner)\b|'
        r'\bthis (worker|person) is (an? )?(employee|contractor|intern)\b',
        caseSensitive: false,
      );
      expect(banned.hasMatch(_allText(employerLesson())), isFalse);
    });

    test('the lesson explicitly says it never calculates or classifies, '
        'in its own risk warning', () {
      final l = employerLesson();
      final warning = l.blocks.whereType<RiskWarningBlock>().first;
      expect(
        warning.text.toLowerCase().contains('never calculates') ||
            warning.text.toLowerCase().contains('never classifies'),
        isTrue,
      );
    });
  });

  group('industry interactions do not make licensing decisions', () {
    test('every categorize-item explanation in the industry lesson names '
        'that the result is not a licensing decision', () {
      final l = businessPermitsAndComplianceLessons.firstWhere(
        (x) => x.id == bpccIndustrySpecificRegulators,
      );
      final block = l.interactionBlocks.whereType<CategorizeBlock>().first;
      for (final item in block.items) {
        expect(
          item.explanation.toLowerCase().contains(
            'not a licensing '
            'decision',
          ),
          isTrue,
          reason: '${item.id} omits the licensing-decision disclaimer',
        );
      }
    });

    test('the industry lesson never says a reader definitely needs, '
        'qualifies for, or will receive a license', () {
      final l = businessPermitsAndComplianceLessons.firstWhere(
        (x) => x.id == bpccIndustrySpecificRegulators,
      );
      final banned = RegExp(
        r"\byou (definitely )?(need|qualify for|will receive) a "
        r"license\b",
        caseSensitive: false,
      );
      expect(banned.hasMatch(_allText(l)), isFalse);
    });

    test('only the three verified regulators (FDA, PCAB, DOT) are ever '
        'assigned to a specific category; every other bucket falls back '
        'to checking with the LGU and the responsible national agency', () {
      final l = businessPermitsAndComplianceLessons.firstWhere(
        (x) => x.id == bpccIndustrySpecificRegulators,
      );
      final block = l.interactionBlocks.whereType<CategorizeBlock>().first;
      final bucketIds = block.buckets.map((b) => b.id).toSet();
      expect(bucketIds, {
        'bucket-fda',
        'bucket-pcab',
        'bucket-dot',
        'bucket-check',
      });
    });
  });

  group('no sensitive fields are requested', () {
    test('no TIN, permit or registration number, government ID, employee '
        'name or identification number, salary, contribution amount, '
        'payroll file, certificate, application reference, password, or '
        'OTP is ever requested', () {
      // Directional, not a bare noun ban: this course legitimately teaches
      // "a change in business address" as a compliance-calendar concept
      // (Lesson 3), never as a field it asks the reader to fill in. A bare
      // ban on "business address" would flag that legitimate teaching
      // content, the same "check the request shape, not the topic" reason
      // the course's own KnowledgeCheck wrong-choices are excluded from the
      // universality and guarantee scans below.
      final banned = RegExp(
        r'\benter your TIN\b|\btype your TIN\b|\byour TIN number\b|'
        r'\bgovernment ID number\b|\bpermit number\b|\bregistration '
        r'number\b|\bemployee name\b|\byour salary\b|\bpassword\b|\bOTP\b|'
        r'\bhome address\b|\bdate of birth\b|'
        r'\b(enter|type|provide|share) your (business |home )?address\b',
        caseSensitive: false,
      );
      for (final l in businessPermitsAndComplianceLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });

    test('no interaction in this course carries a free-text field', () {
      for (final l in businessPermitsAndComplianceLessons) {
        for (final b in l.interactionBlocks) {
          if (b is ReflectionPromptBlock) {
            expect(b.allowFreeText, isFalse, reason: l.id);
          }
        }
      }
    });
  });

  group('feature deep links target existing routes', () {
    test('every action route is a known, pushable Salapify screen', () {
      const knownRoutes = {
        'goals',
        'debts',
        'budget',
        'mindset',
        'accounts',
        'recurring',
        'notifications',
      };
      for (final l in businessPermitsAndComplianceLessons) {
        for (final block
            in l.interactionBlocks.whereType<SalapifyActionsBlock>()) {
          for (final action in block.actions) {
            expect(
              knownRoutes.contains(action.route),
              isTrue,
              reason: 'unknown route "${action.route}"',
            );
            expect(action.description, isNotEmpty);
          }
        }
      }
    });

    test('the renewal reminder action opens Notifications and security '
        'only, never an automatic write', () {
      final l = businessPermitsAndComplianceLessons.firstWhere(
        (x) => x.id == bpccRenewalsAndLocalCompliance,
      );
      final block = l.interactionBlocks.whereType<SalapifyActionsBlock>().first;
      expect(block.actions.map((a) => a.route).toSet(), {'notifications'});
    });

    test('lesson 6 offers goals, budget, recurring, and notifications '
        'only, never an automatic write', () {
      final l = businessPermitsAndComplianceLessons.firstWhere(
        (x) => x.id == bpccBuildYourComplianceMap,
      );
      final block = l.interactionBlocks.whereType<SalapifyActionsBlock>().first;
      expect(block.actions.map((a) => a.route).toSet(), {
        'goals',
        'budget',
        'recurring',
        'notifications',
      });
      for (final action in block.actions) {
        expect(action.route, isNotEmpty);
      }
    });
  });

  group('risk warnings and educational boundary', () {
    test('every lesson carries a risk-warning block', () {
      for (final lesson in businessPermitsAndComplianceLessons) {
        expect(
          lesson.blocks.whereType<RiskWarningBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no RiskWarningBlock',
        );
      }
    });

    test('every lesson carries the educational-boundary block', () {
      for (final lesson in businessPermitsAndComplianceLessons) {
        expect(
          lesson.blocks.whereType<EducationalBoundaryBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no EducationalBoundaryBlock',
        );
      }
    });
  });

  group('required interactions', () {
    test('every lesson has at least one required interaction block', () {
      for (final lesson in businessPermitsAndComplianceLessons) {
        expect(
          lesson.interactionBlocks.where((b) => b.requiredForCompletion),
          isNotEmpty,
          reason: '${lesson.id} has no required interaction',
        );
      }
    });

    test('every lesson has unique interaction block ids', () {
      for (final lesson in businessPermitsAndComplianceLessons) {
        final ids = lesson.interactionBlocks.map((b) => b.blockId).toList();
        expect(
          ids.toSet().length,
          ids.length,
          reason: '${lesson.id} has duplicate interaction block ids',
        );
      }
    });

    test('every lesson has a scenario-based knowledge check with an '
        'explanation', () {
      for (final lesson in businessPermitsAndComplianceLessons) {
        final check = lesson.check;
        expect(check, isNotNull, reason: '${lesson.id} has no check');
        expect(check!.isValid, isTrue);
        expect(check.explanation, isNotEmpty);
      }
    });
  });

  group('safety requirements: never an eligibility verdict, approval, or '
      'affiliation claim', () {
    test('no em or en dashes anywhere, content blocks or interactions', () {
      for (final l in businessPermitsAndComplianceLessons) {
        final all = _allText(l);
        expect(all.contains('—'), isFalse, reason: '${l.id} em dash');
        expect(all.contains('–'), isFalse, reason: '${l.id} en dash');
      }
    });

    test('never guarantees approval or completeness, and never says '
        'risk-free, in its own informational text (its knowledge check '
        'is allowed to state the wrong answer out loud in order to '
        'debunk it)', () {
      final banned = RegExp(
        r'\bis guaranteed\b|\brisk[\s-]?free\b|\bwill be approved\b|'
        r'\bapproved instantly\b|\bguarantees (full )?compliance\b',
        caseSensitive: false,
      );
      for (final l in businessPermitsAndComplianceLessons) {
        expect(
          banned.hasMatch(_informationalText(l)),
          isFalse,
          reason: '${l.id} reads as a guarantee',
        );
      }
    });

    test('never implies Salapify is affiliated with BIR, DTI, DILG, a '
        'barangay, an agency, or any city or municipality', () {
      final banned = RegExp(
        r'\bSalapify (is|works with|partners with|is affiliated with|is '
        r'part of)\b[^.]{0,60}\b(BIR|DTI|DILG|SSS|PhilHealth|Pag-IBIG|FDA|'
        r'PCAB|DOT|barangay|city|municipal|government)\b',
        caseSensitive: false,
      );
      for (final l in businessPermitsAndComplianceLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });

    test('never recommends bypassing an agency, and never files, '
        'submits, or transmits anything on the reader\'s behalf', () {
      final banned = RegExp(
        r'\bwe will (file|submit|register|apply) for you\b|'
        r'\bautomatically (files|submits|registers)\b|'
        r'\bskip (checking with|the) (LGU|barangay|agency|regulator)\b',
        caseSensitive: false,
      );
      for (final l in businessPermitsAndComplianceLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });
  });

  group('the expansion-content validator passes for the whole course', () {
    test('isPublishable is true for every lesson at the reference date', () {
      for (final lesson in businessPermitsAndComplianceLessons) {
        expect(
          isPublishable(validateExpansionLesson(lesson, referenceDate: _ref)),
          isTrue,
        );
      }
    });
  });

  group('widget rendering: interactions render and update', () {
    testWidgets(
      'the industry-triage CategorizeBlock renders and assigning every '
      'item to its correct bucket completes it',
      (tester) async {
        final l = businessPermitsAndComplianceLessons.firstWhere(
          (x) => x.id == bpccIndustrySpecificRegulators,
        );
        final block = l.interactionBlocks.whereType<CategorizeBlock>().first;
        final completed = <String>[];
        await loadRealFonts(tester);
        tester.view.physicalSize = const Size(390, 4000) * 3.0;
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);
        Barako.current = Barako.currentTheme.resolve(Brightness.dark);
        await tester.pumpWidget(
          MaterialApp(
            theme: salapifyTheme(Barako.current),
            home: Scaffold(
              body: SingleChildScrollView(
                child: CategorizeView(block, onComplete: completed.add),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(completed, isEmpty);
        for (var i = 0; i < block.items.length; i++) {
          final item = block.items[i];
          final bucketId = block.correctBucketByItemId[item.id]!;
          final bucketLabel = block.buckets
              .firstWhere((b) => b.id == bucketId)
              .label;
          await tester.tap(find.text(bucketLabel).at(i));
          await tester.pumpAndSettle();
        }
        expect(completed, [block.blockId]);
      },
    );

    testWidgets(
      'the employer-agency-awareness CategorizeBlock renders and updates',
      (tester) async {
        final l = businessPermitsAndComplianceLessons.firstWhere(
          (x) => x.id == bpccWhenYouHirePeople,
        );
        final block = l.interactionBlocks.whereType<CategorizeBlock>().first;
        final completed = <String>[];
        await loadRealFonts(tester);
        tester.view.physicalSize = const Size(390, 4000) * 3.0;
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);
        Barako.current = Barako.currentTheme.resolve(Brightness.dark);
        await tester.pumpWidget(
          MaterialApp(
            theme: salapifyTheme(Barako.current),
            home: Scaffold(
              body: SingleChildScrollView(
                child: CategorizeView(block, onComplete: completed.add),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('SSS'), findsWidgets);
        expect(find.text('PhilHealth'), findsWidgets);
        expect(find.text('Pag-IBIG Fund'), findsWidgets);
        for (var i = 0; i < block.items.length; i++) {
          final item = block.items[i];
          final bucketId = block.correctBucketByItemId[item.id]!;
          final bucketLabel = block.buckets
              .firstWhere((b) => b.id == bucketId)
              .label;
          await tester.tap(find.text(bucketLabel).at(i));
          await tester.pumpAndSettle();
        }
        expect(completed, [block.blockId]);
      },
    );
  });
}

// The lesson's own title, summary, objective, takeaway, and authored/derived
// prose blocks, deliberately EXCLUDING interaction blocks and the knowledge
// check: a MythOrFactBlock's own `statement` has to say a false claim out
// loud in order to debunk it, so a "never claims X" scan needs to skip that
// text or it flags the deliberately wrong myth sentence as if it were this
// lesson's own claim.
String _informationalText(MoneyLesson l) {
  final buf = StringBuffer()
    ..write(l.title)
    ..write(' ')
    ..write(l.summary)
    ..write(' ')
    ..write(l.objective)
    ..write(' ')
    ..write(l.keyTakeaway);
  for (final b in l.blocks) {
    switch (b) {
      case ProseBlock(:final heading, :final paragraphs):
        buf.writeAll([heading, ...paragraphs], ' ');
      case NuggetsBlock(:final items):
        buf.writeAll(items, ' ');
      case RiskWarningBlock(:final title, :final text):
        buf.writeAll([title, text], ' ');
      case OfficialSourceBlock(:final agency, :final sourceTitle):
        buf.writeAll([agency, sourceTitle], ' ');
      case EducationalBoundaryBlock():
        break;
      case RulesBlock(:final passages):
        buf.writeAll(passages, ' ');
      case DiscoveryBlock(:final question, :final reveal):
        buf.writeAll([question, reveal], ' ');
      case StoryBlock(:final who, :final text):
        buf.writeAll([who, text], ' ');
      case DiagramBlock(:final steps, :final caption):
        buf.writeAll([...steps, caption], ' ');
      case TrapBlock(:final mostPeople, :final worksBetter):
        buf.writeAll([mostPeople, worksBetter], ' ');
      case ChallengeBlock(:final prompt, :final compare):
        buf.writeAll([prompt, compare], ' ');
      case ReflectionBlock(:final line):
        buf.write(line);
    }
  }
  return buf.toString();
}

String _allText(MoneyLesson l) {
  final buf = StringBuffer()..write(_informationalText(l));
  final check = l.check;
  if (check != null) {
    buf.writeAll([
      check.question,
      ...check.choices,
      check.explanation,
      check.whyWrong ?? '',
    ], ' ');
  }
  for (final b in l.interactionBlocks) {
    buf.write(' ${b.prompt} ${b.instructions}');
    switch (b) {
      case ScenarioChoiceBlock(:final situation, :final options):
        buf.write(' $situation');
        for (final o in options) {
          buf.write(' ${o.label} ${o.explanation}');
        }
      case MythOrFactBlock(:final statement, :final explanation):
        buf.write(' $statement $explanation');
      case ComparisonBlock(:final items):
        for (final i in items) {
          buf.write(' ${i.name}');
          for (final v in i.valuesByCriterionId.values) {
            buf.write(' $v');
          }
          buf.write(' ${i.caution ?? ''}');
        }
      case ChecklistBlock(:final items):
        for (final i in items) {
          buf.write(' ${i.label} ${i.explanation ?? ''}');
        }
      case SortingBlock(:final items):
        for (final i in items) {
          buf.write(' ${i.label} ${i.explanation ?? ''}');
        }
      case ReflectionPromptBlock(:final choices):
        for (final c in choices) {
          buf.write(' ${c.label}');
        }
      case CategorizeBlock(:final buckets, :final items):
        for (final bkt in buckets) {
          buf.write(' ${bkt.label}');
        }
        for (final i in items) {
          buf.write(' ${i.label} ${i.explanation}');
        }
      case ReadinessCardBlock(:final fields):
        for (final f in fields) {
          buf.write(' ${f.label}');
          for (final o in f.options) {
            buf.write(' ${o.label}');
          }
        }
      case SalapifyActionsBlock(:final actions):
        for (final a in actions) {
          buf.write(' ${a.label} ${a.description}');
        }
      case LossImpactSimulatorBlock():
      case RiskReviewChecklistBlock():
        break;
    }
  }
  return buf.toString();
}
