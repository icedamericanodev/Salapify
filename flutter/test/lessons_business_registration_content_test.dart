// Money Courses Phase 13 content contract: a THIRD learning path, "Build
// Your Business" (lib/content/learning_paths.dart), carrying its first
// course, "Start Your Business Legally"
// (lib/content/lessons_business_registration.dart). Proves this course is
// registered correctly, stays fully isolated from the core 22 lessons and
// every grow_your_money and protect_your_future course, passes the house
// rules (no em/en dash, no structure recommendation, no sensitive-data
// collection, no fee/deadline/document tables, no implied government
// affiliation) plus the Phase 4 content policy validator, and that its
// structure-comparison and agency-matching interactions actually render and
// update.
//
// Mirrors test/lessons_ph_government_securities_content_test.dart's own
// structure on purpose, the established shape for a Money Courses content
// contract test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/learning_path.dart';
import 'package:salapify/content/learning_paths.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons.dart' as core;
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
  brBeforeYouRegister,
  brCompareBusinessStructures,
  brMatchStructureToAgency,
  brBusinessNameAndBrand,
  brRegistrationIsNotPermission,
  brBuildRegistrationRoadmap,
];

void main() {
  group('registration', () {
    test('build_your_business is published, with Start Your Business '
        'Legally as its first course', () {
      final path = learningPaths.firstWhere(
        (p) => p.id == 'build_your_business',
      );
      expect(path.status, LearningPathStatus.published);
      expect(path.isAvailable, isTrue);
      // Not asserted as the ONLY group: Phase 14 added a second course
      // ("BIR Registration and Local Permits") to this same path. See
      // test/lessons_bir_local_permits_content_test.dart for that course's
      // own full registration coverage.
      final group = path.groups.first;
      expect(group.id, 'start_a_business_legally');
      expect(group.title, 'Start Your Business Legally');
      expect(group.lessonIds, _stableLessonIds);
      // Narrowed from an exact-list assertion to a prefix check, the same
      // pattern used every time a path legitimately grows a second course
      // (see grow_your_money and protect_your_future's own earlier fixes):
      // this course's own lessons still lead the path, in order, but the
      // path's own full lessonIds list is no longer just this course's.
      expect(path.lessonIds.sublist(0, 6), _stableLessonIds);
    });

    test('the course is not registered under grow_your_money, '
        'protect_your_future, or any other path', () {
      for (final path in learningPaths) {
        if (path.id == 'build_your_business') continue;
        expect(
          path.groups.map((g) => g.id),
          isNot(contains('start_a_business_legally')),
          reason: '${path.id} should not carry this course',
        );
        for (final id in _stableLessonIds) {
          expect(
            path.lessonIds.contains(id),
            isFalse,
            reason: '$id leaked into ${path.id}',
          );
        }
      }
    });

    test('publishedLearningPaths now shows all three real paths', () {
      expect(publishedLearningPaths.map((p) => p.id), [
        'grow_your_money',
        'protect_your_future',
        'build_your_business',
      ]);
    });

    test('six stable lesson ids, in reading order, exactly as specified', () {
      expect(
        startABusinessLegallyLessons.map((l) => l.id).toList(),
        _stableLessonIds,
      );
      expect(_stableLessonIds, [
        'before_you_register',
        'compare_business_structures',
        'match_structure_to_agency',
        'business_name_and_brand',
        'registration_is_not_permission',
        'build_registration_roadmap',
      ]);
    });

    test('course and lesson ids are unique', () {
      expect(_stableLessonIds.toSet().length, 6);
      expect(_stableLessonIds.contains('start_a_business_legally'), isFalse);
    });

    test('every lesson is registered under the start_a_business_legally '
        'trackId', () {
      for (final l in startABusinessLegallyLessons) {
        expect(l.trackId, 'start_a_business_legally');
      }
    });

    test('expansionLessonById resolves a lesson from this course to the '
        'build_your_business path', () {
      final found = expansionLessonById(brBeforeYouRegister);
      expect(found, isNotNull);
      expect(found!.pathId, 'build_your_business');
      expect(found.lesson.id, brBeforeYouRegister);
    });
  });

  group('isolation from the core 22 and from every earlier expansion '
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
    });

    test('none of the new ids appear in the core flat lesson list', () {
      final coreIds = core.lessons.map((l) => l['id']).toSet();
      for (final id in _stableLessonIds) {
        expect(coreIds.contains(id), isFalse, reason: '$id leaked into core');
      }
    });

    test('none of the new ids collide with any earlier expansion lesson '
        'id', () {
      final earlierIds = {
        ...growYourMoneyLessons.map((l) => l.id),
        ...stocksAndBondsLessons.map((l) => l.id),
        ...depositsAndPooledFundsLessons.map((l) => l.id),
        ...cryptoWithoutHypeLessons.map((l) => l.id),
        ...phGovernmentSecuritiesLessons.map((l) => l.id),
        ...insuranceDecodedLessons.map((l) => l.id),
        ...sssPhilhealthBenefitsLessons.map((l) => l.id),
        ...pagibigSavingsMp2HousingLessons.map((l) => l.id),
      };
      for (final id in _stableLessonIds) {
        expect(earlierIds.contains(id), isFalse);
      }
    });

    test('none of the new ids appear more than once inside '
        'startABusinessLegallyLessons', () {
      final ids = startABusinessLegallyLessons.map((l) => l.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('the core Learn count stays exactly 22', () {
    test('core lessons and course tracks are unchanged by this phase', () {
      expect(core.lessons.length, 22);
      expect(core.courseTracks.length, 4);
    });
  });

  group('expansion progress stays separate from core progress and from '
      'every earlier path\'s own progress', () {
    test('writing progress for build_your_business never touches an '
        'unrelated path\'s stored entry', () {
      final existing = {
        'grow_your_money': {
          gsLendingToGovernment: {'state': 'completed'},
        },
        'protect_your_future': {
          insuranceRefWhatItsFor: {'state': 'completed'},
        },
      };
      final out = withExpansionLessonState(
        existing,
        'build_your_business',
        brBeforeYouRegister,
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
        parsed['protect_your_future']?[insuranceRefWhatItsFor],
        LessonState.completed,
        reason:
            'a second unrelated path\'s existing progress must survive '
            'untouched',
      );
      expect(
        parsed['build_your_business']?[brBeforeYouRegister],
        LessonState.completed,
      );
    });

    test('pathProgressFor counts only this path\'s own lesson ids', () {
      final progress = parseExpansionProgress({
        'build_your_business': {
          brBeforeYouRegister: {'state': 'completed'},
          brCompareBusinessStructures: {'state': 'viewed'},
        },
        'grow_your_money': {
          gsLendingToGovernment: {'state': 'completed'},
        },
      });
      final pp = pathProgressFor(
        pathId: 'build_your_business',
        lessonIds: _stableLessonIds,
        progress: progress['build_your_business'] ?? const {},
      );
      expect(pp.total, 6);
      expect(
        pp.done,
        1,
        reason:
            'only before_you_register reached '
            'completed/applied',
      );
    });
  });

  group('content policy validator (Phase 4)', () {
    test('every lesson has zero validation errors', () {
      for (final lesson in startABusinessLegallyLessons) {
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
      for (final lesson in startABusinessLegallyLessons) {
        expect(
          lesson.topics,
          contains(ContentTopic.businessTaxOrPermitCompliance),
          reason: '${lesson.id} carries no matching ContentTopic',
        );
      }
    });
  });

  group('official-source metadata (test item 8: every factual lesson has '
      'valid official-source metadata)', () {
    test(
      'every lesson cites at least one structured, HTTPS official source',
      () {
        for (final lesson in startABusinessLegallyLessons) {
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
      for (final lesson in startABusinessLegallyLessons) {
        expect(
          lesson.blocks.whereType<OfficialSourceBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no OfficialSourceBlock',
        );
      }
    });

    test('every source is one of the eight named official pages, never a '
        'blog, accounting firm, law firm, or private registrar', () {
      const allowedUrls = {
        'https://business.gov.ph/business-application-process',
        'https://bnrs.dti.gov.ph/faq',
        'https://bnrs.dti.gov.ph/resources/registration-guide',
        'https://esparc.sec.gov.ph/application/selection',
        'https://cda.gov.ph/services/regulatory-services/registration/',
        'https://www.ipophil.gov.ph/trademark/',
        'https://www.ipophil.gov.ph/trademark/filing/',
        'https://www.bir.gov.ph/',
      };
      for (final lesson in startABusinessLegallyLessons) {
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

    test('every official source used by the task is cited by at least one '
        'lesson', () {
      final cited = {
        for (final l in startABusinessLegallyLessons)
          for (final s in l.sources) s.canonicalUrl,
      };
      expect(cited, {
        'https://business.gov.ph/business-application-process',
        'https://bnrs.dti.gov.ph/faq',
        'https://bnrs.dti.gov.ph/resources/registration-guide',
        'https://esparc.sec.gov.ph/application/selection',
        'https://cda.gov.ph/services/regulatory-services/registration/',
        'https://www.ipophil.gov.ph/trademark/',
        'https://www.ipophil.gov.ph/trademark/filing/',
        'https://www.bir.gov.ph/',
      });
    });

    test('DTI, SEC, CDA, IPOPHL, BIR, and Philippine Business Hub mappings '
        'are verified: every source agency exactly matches its own URL\'s '
        'domain', () {
      const expectedAgencyByHost = {
        'business.gov.ph': 'Philippine Business Hub',
        'bnrs.dti.gov.ph': 'Department of Trade and Industry (DTI)',
        'esparc.sec.gov.ph':
            'Securities and Exchange Commission Philippines '
            '(SEC)',
        'cda.gov.ph': 'Cooperative Development Authority (CDA)',
        'www.ipophil.gov.ph':
            'Intellectual Property Office of the '
            'Philippines (IPOPHL)',
        'www.bir.gov.ph': 'Bureau of Internal Revenue (BIR)',
      };
      for (final lesson in startABusinessLegallyLessons) {
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
        'lesson (test item 9: high-volatility facts carry review dates, or '
        'are omitted entirely, which this course does)', () {
      for (final lesson in startABusinessLegallyLessons) {
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

  group('no static fee, deadline, processing-time, or document-requirement '
      'tables (test item 11)', () {
    test('no percentage or peso figure anywhere in this course', () {
      final banned = RegExp(
        r'\d+(\.\d+)?\s?%|(₱|php)\s?\d',
        caseSensitive: false,
      );
      for (final l in startABusinessLegallyLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} embeds a percentage or peso figure',
        );
      }
    });

    test('no capital-requirement, processing-time, or validity-period word '
        'paired with a number anywhere', () {
      final banned = RegExp(
        r'\d+\s?(day|days|business day|business days|week|weeks|month|'
        r'months|year|years)\b',
        caseSensitive: false,
      );
      for (final l in startABusinessLegallyLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} embeds a processing time or validity period',
        );
      }
    });
  });

  group('risk warnings and educational boundary', () {
    test('every lesson carries a risk-warning block', () {
      for (final lesson in startABusinessLegallyLessons) {
        expect(
          lesson.blocks.whereType<RiskWarningBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no RiskWarningBlock',
        );
      }
    });

    test('every lesson carries the educational-boundary block', () {
      for (final lesson in startABusinessLegallyLessons) {
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
      for (final lesson in startABusinessLegallyLessons) {
        expect(
          lesson.interactionBlocks.where((b) => b.requiredForCompletion),
          isNotEmpty,
          reason: '${lesson.id} has no required interaction',
        );
      }
    });

    test('every lesson has unique interaction block ids', () {
      for (final lesson in startABusinessLegallyLessons) {
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
      for (final lesson in startABusinessLegallyLessons) {
        final check = lesson.check;
        expect(check, isNotNull, reason: '${lesson.id} has no check');
        expect(check!.isValid, isTrue);
        expect(check.explanation, isNotEmpty);
      }
    });
  });

  group('safety requirements: never a structure recommendation or '
      'guarantee', () {
    test('never calls one structure the best, cheapest, safest, easiest, '
        'or most tax-efficient', () {
      // Scoped to an actual ranking shape ("a structure IS the best/
      // cheapest/...") rather than a bare word match: lesson 1's own
      // reflection question ("Which of these best describes...") uses
      // "best" idiomatically and is not a structure ranking.
      final banned = RegExp(
        r'\b(sole proprietorship|partnership|one person corporation|'
        r'corporation|cooperative)\b[^.]{0,60}\bis\b[^.]{0,30}\b(the )?'
        r'(best|cheapest|safest|easiest|most tax-efficient|'
        r'most tax efficient)\b',
        caseSensitive: false,
      );
      for (final l in startABusinessLegallyLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} reads as ranking a structure',
        );
      }
    });

    test('no em or en dashes anywhere, content blocks or interactions', () {
      for (final l in startABusinessLegallyLessons) {
        final all = _allText(l);
        expect(all.contains('—'), isFalse, reason: '${l.id} em dash');
        expect(all.contains('–'), isFalse, reason: '${l.id} en dash');
      }
    });

    test('never guarantees registration approval or a processing time, and '
        'never says risk-free', () {
      final banned = RegExp(
        r'\bguarantee[ds]?\b|\brisk[\s-]?free\b|\bapproved instantly\b',
        caseSensitive: false,
      );
      for (final l in startABusinessLegallyLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} reads as a guarantee',
        );
      }
    });

    test('never treats a registered name as trademark protection, and '
        'never claims a name registration alone is a completed legal '
        'requirement', () {
      final l = startABusinessLegallyLessons.firstWhere(
        (x) => x.id == brBusinessNameAndBrand,
      );
      // Scoped to this lesson's own informational prose, never the myth
      // statement itself: a MythOrFactBlock's `statement` field has to say
      // the false claim out loud in order to debunk it, so scanning the
      // full interaction text for this exact shape would flag the
      // deliberately wrong myth sentence, not a real content defect.
      final informational = _informationalText(l);
      // "grants"/"means"/"is a trademark" catch the actual violation shape;
      // a bare "is" would also match this lesson's own correct disclaimer
      // ("it IS NOT a trademark search"), so that negated form is excluded.
      expect(
        RegExp(
          r'(registration|registered name)[^.]{0,40}\b(grants|means|is a '
          r'trademark|is trademark protection)\b',
          caseSensitive: false,
        ).hasMatch(informational),
        isFalse,
      );
    });

    test('never implies Salapify is affiliated with a government agency', () {
      final banned = RegExp(
        r'\bSalapify (is|works with|partners with|is affiliated with|is '
        r'part of)\b[^.]{0,60}\b(DTI|SEC|CDA|IPOPHL|BIR|government)\b',
        caseSensitive: false,
      );
      for (final l in startABusinessLegallyLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });

    test('never recommends a paid intermediary or registration service', () {
      final banned = RegExp(
        r'\bhire a (fixer|filer|registration service)\b|'
        r'\buse this (agent|provider|company) to register\b',
        caseSensitive: false,
      );
      for (final l in startABusinessLegallyLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });
  });

  group('privacy requirements: no interaction requests sensitive business '
      'or identity data (test item 13)', () {
    test('lesson 1\'s checklist never asks for a real business name, '
        'address, income, or government id', () {
      final l = startABusinessLegallyLessons.firstWhere(
        (x) => x.id == brBeforeYouRegister,
      );
      final checklist = l.interactionBlocks.whereType<ChecklistBlock>().first;
      final banned = RegExp(
        r'\benter your\b|\btype your\b|\byour (tin|address|business name|'
        r'capital amount|government id)\b',
        caseSensitive: false,
      );
      for (final item in checklist.items) {
        expect(banned.hasMatch(item.label), isFalse, reason: item.id);
      }
    });

    test('no interaction in this course carries a free-text field for a '
        'real proposed business name', () {
      for (final l in startABusinessLegallyLessons) {
        for (final b in l.interactionBlocks) {
          if (b is ReflectionPromptBlock) {
            expect(
              b.question.toLowerCase().contains('what would you name'),
              isFalse,
            );
          }
        }
      }
    });

    test('no TIN, government ID, date of birth, address, capital amount, '
        'or credential word appears anywhere', () {
      final banned = RegExp(
        r'\bTIN\b|\bgovernment ID\b|\bdate of birth\b|\bhome address\b|'
        r'\bpassword\b|\bOTP\b|\bincorporation document\b|'
        r'\breference number\b',
        caseSensitive: false,
      );
      for (final l in startABusinessLegallyLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });
  });

  group('feature deep links target existing routes (test item 16)', () {
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
      for (final l in startABusinessLegallyLessons) {
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

    test('lesson 6 offers goals, budget, accounts, and reminders only, '
        'never an automatic write', () {
      final l = startABusinessLegallyLessons.firstWhere(
        (x) => x.id == brBuildRegistrationRoadmap,
      );
      final block = l.interactionBlocks.whereType<SalapifyActionsBlock>().first;
      expect(block.actions.map((a) => a.route).toSet(), {
        'goals',
        'budget',
        'accounts',
        'notifications',
      });
      for (final action in block.actions) {
        expect(action.route, isNotEmpty);
      }
    });
  });

  group('course-specific interaction coverage', () {
    MoneyLesson byId(String id) =>
        startABusinessLegallyLessons.firstWhere((l) => l.id == id);

    test('lesson 1 has a non-sensitive checklist and a reflection covering '
        'the four possible outcomes', () {
      final l = byId(brBeforeYouRegister);
      final checklist = l.interactionBlocks.whereType<ChecklistBlock>().first;
      expect(checklist.items.length, greaterThanOrEqualTo(6));
      final reflection = l.interactionBlocks
          .whereType<ReflectionPromptBlock>()
          .first;
      expect(reflection.choices.map((c) => c.label), [
        'Clarify the business model first',
        'Ownership needs discussion',
        'Check whether the activity is regulated',
        'Ready to compare structures',
      ]);
    });

    test('lesson 2\'s comparison never labels an option "Best" and covers '
        'only the allowed criteria', () {
      final l = byId(brCompareBusinessStructures);
      final cmp = l.interactionBlocks.whereType<ComparisonBlock>().first;
      expect(cmp.items.length, 5);
      expect(
        cmp.criteria.map((c) => c.id),
        containsAll([
          'owners',
          'legal-personality',
          'liability',
          'governance',
          'continuity',
          'recordkeeping',
          'funding',
          'agency',
        ]),
      );
      final allText = _allText(l);
      expect(RegExp(r'\bBest\b').hasMatch(allText), isFalse);
      final scenarios = l.interactionBlocks.whereType<ScenarioChoiceBlock>();
      final allExplanations = [
        for (final s in scenarios)
          for (final o in s.options) o.explanation,
      ].join(' ');
      expect(allExplanations.contains('Structure to investigate'), isTrue);
      expect(
        allExplanations.contains('Discuss ownership and liability first'),
        isTrue,
      );
      expect(
        allExplanations.contains('Professional advice may be useful'),
        isTrue,
      );
    });

    test('lesson 3\'s agency-matching interaction covers DTI, SEC, and '
        'CDA, and never launches a real registration flow', () {
      final l = byId(brMatchStructureToAgency);
      final match = l.interactionBlocks.whereType<CategorizeBlock>().first;
      expect(
        match.buckets.map((b) => b.label),
        containsAll(['DTI', 'SEC', 'CDA']),
      );
      expect(l.interactionBlocks.whereType<SalapifyActionsBlock>(), isEmpty);
      // The affirmative claim is banned; this lesson's own disclaimer
      // ("not a promise that every business type is supported") uses the
      // same words to deny it, which is exactly what this checks for.
      expect(
        RegExp(
          r'\b(hub|it) supports every business type\b',
          caseSensitive: false,
        ).hasMatch(_allText(l)),
        isFalse,
        reason: 'must never promise the Hub supports every business type',
      );
      expect(
        _allText(l).toLowerCase().contains(
          'not a promise that every business type is supported',
        ),
        isTrue,
        reason: 'the disclaimer itself must actually be present',
      );
    });

    test('lesson 4 never asks for a real proposed business name, and never '
        'gives a trademark clearance conclusion', () {
      final l = byId(brBusinessNameAndBrand);
      for (final b in l.interactionBlocks) {
        if (b is ReflectionPromptBlock) {
          expect(b.allowFreeText, isFalse);
        }
      }
      final banned = RegExp(
        r'\byour trademark is (available|clear|approved)\b|'
        r'\bno one else has (registered|filed) this\b',
        caseSensitive: false,
      );
      expect(banned.hasMatch(_allText(l)), isFalse);
    });

    test('lesson 5\'s sequence never includes detailed tax forms, '
        'deadlines, permit checklists, or industry-specific procedures, '
        'and never generalizes a permit step across every LGU', () {
      final l = byId(brRegistrationIsNotPermission);
      final sorting = l.interactionBlocks.whereType<SortingBlock>().first;
      expect(sorting.items.length, 8);
      final banned = RegExp(
        r'\bBIR Form \d|\bevery LGU\b|\ball LGUs\b|\bevery barangay\b|'
        r'\ball barangays\b',
        caseSensitive: false,
      );
      expect(banned.hasMatch(_allText(l)), isFalse);
    });

    test('lesson 6 builds a checklist covering the ten roadmap areas and '
        'offers verified actions, never a peso amount', () {
      final l = byId(brBuildRegistrationRoadmap);
      final checklist = l.interactionBlocks.whereType<ChecklistBlock>().first;
      expect(checklist.items.length, greaterThanOrEqualTo(10));
      expect(checklist.requiredForCompletion, isFalse);
      final actions = l.interactionBlocks
          .whereType<SalapifyActionsBlock>()
          .first;
      expect(actions.actions, isNotEmpty);
      expect(
        RegExp(r'(₱|php)\s?\d', caseSensitive: false).hasMatch(_allText(l)),
        isFalse,
      );
    });
  });

  group('the expansion-content validator passes for the whole course '
      '(test item 17)', () {
    test('isPublishable is true for every lesson at the reference date', () {
      for (final lesson in startABusinessLegallyLessons) {
        expect(
          isPublishable(validateExpansionLesson(lesson, referenceDate: _ref)),
          isTrue,
        );
      }
    });
  });

  group('widget rendering: the structure-comparison and agency-matching '
      'interactions render and update (test items 14 and 15)', () {
    testWidgets(
      'the structure-comparison ComparisonBlock renders and marking it '
      'reviewed completes it',
      (tester) async {
        final l = startABusinessLegallyLessons.firstWhere(
          (x) => x.id == brCompareBusinessStructures,
        );
        final block = l.interactionBlocks.whereType<ComparisonBlock>().first;
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
                child: ComparisonView(block, onComplete: completed.add),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sole proprietorship'), findsOneWidget);
        expect(find.text('Cooperative'), findsOneWidget);
        expect(completed, isEmpty);
        await tester.tap(find.text('Mark as reviewed'));
        await tester.pumpAndSettle();
        expect(completed, [block.blockId]);
      },
    );

    testWidgets(
      'the agency-matching CategorizeBlock renders and assigning every '
      'item to its correct bucket completes it',
      (tester) async {
        final l = startABusinessLegallyLessons.firstWhere(
          (x) => x.id == brMatchStructureToAgency,
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
        expect(find.text('DTI'), findsWidgets);
        expect(find.text('SEC'), findsWidgets);
        expect(find.text('CDA'), findsWidgets);
        expect(completed, isEmpty);
        // Every row renders all three bucket chips in the same order, so
        // the i-th occurrence of a bucket's label text is always that
        // bucket's chip on row i (see CategorizeView's own build order:
        // one Wrap of every bucket, per item, in list order).
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
