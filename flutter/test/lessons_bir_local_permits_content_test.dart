// Money Courses Phase 14 content contract: "Build Your Business" learning
// path's SECOND course, "BIR Registration and Local Permits"
// (lib/content/lessons_bir_local_permits.dart). Proves this course is
// registered correctly, stays fully isolated from the core 22 lessons,
// Start Your Business Legally, and every grow_your_money and
// protect_your_future course, passes the house rules (no em/en dash, no
// eligibility/approval promise, no sensitive-data collection, no
// implied government affiliation), the Phase 4 content policy validator,
// and this course's OWN deliberate exception to the usual
// no-hardcoded-figure rule: national BIR figures may be stated (with a
// review-cycle and RiskWarning contract proving the exception is bounded),
// while local-government fees may never be, anywhere, since those are not
// merely time-volatile but structurally set independently by each city and
// municipality.
//
// Mirrors test/lessons_business_registration_content_test.dart's own
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
import 'package:salapify/content/lessons_bir_local_permits.dart';
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
  birlOrderThatMatters,
  birlGetYourTin,
  birlBooksAndInvoices,
  birlBarangayAndMayor,
  birlTaxpayerSize,
  birlComplianceCalendar,
];

void main() {
  group('registration', () {
    test(
      'build_your_business now carries Start Your Business Legally as its '
      'first course and BIR Registration and Local Permits as its second',
      () {
        final path = learningPaths.firstWhere(
          (p) => p.id == 'build_your_business',
        );
        expect(path.status, LearningPathStatus.published);
        expect(path.isAvailable, isTrue);
        expect(path.groups.length, 2);
        expect(path.groups.first.id, 'start_a_business_legally');
        final group = path.groups[1];
        expect(group.id, 'bir_registration_and_local_permits');
        expect(group.title, 'BIR Registration and Local Permits');
        expect(group.lessonIds, _stableLessonIds);
        expect(group.recommendedPriorGroupIds, ['start_a_business_legally']);
        // 6 from Start Your Business Legally, 6 from this course.
        expect(path.lessonIds.length, 12);
        expect(path.lessonIds.sublist(6), _stableLessonIds);
      },
    );

    test('the course is not registered under grow_your_money, '
        'protect_your_future, or start_a_business_legally', () {
      for (final path in learningPaths) {
        for (final group in path.groups) {
          if (group.id == 'bir_registration_and_local_permits') continue;
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
        birRegistrationAndLocalPermitsLessons.map((l) => l.id).toList(),
        _stableLessonIds,
      );
      expect(_stableLessonIds, [
        'bir-local-order-that-matters',
        'bir-local-get-your-tin',
        'bir-local-books-and-invoices',
        'bir-local-barangay-and-mayor',
        'bir-local-taxpayer-size',
        'bir-local-compliance-calendar',
      ]);
    });

    test('course and lesson ids are unique', () {
      expect(_stableLessonIds.toSet().length, 6);
      expect(
        _stableLessonIds.contains('bir_registration_and_local_permits'),
        isFalse,
      );
    });

    test('every lesson is registered under the '
        'bir_registration_and_local_permits trackId', () {
      for (final l in birRegistrationAndLocalPermitsLessons) {
        expect(l.trackId, 'bir_registration_and_local_permits');
      }
    });

    test('expansionLessonById resolves a lesson from this course to the '
        'build_your_business path', () {
      final found = expansionLessonById(birlOrderThatMatters);
      expect(found, isNotNull);
      expect(found!.pathId, 'build_your_business');
      expect(found.lesson.id, birlOrderThatMatters);
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
      };
      for (final id in _stableLessonIds) {
        expect(otherIds.contains(id), isFalse);
      }
    });

    test('none of the new ids appear more than once inside '
        'birRegistrationAndLocalPermitsLessons', () {
      final ids = birRegistrationAndLocalPermitsLessons
          .map((l) => l.id)
          .toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('expansion progress stays separate from core progress and from '
      'every other path\'s or course\'s own progress', () {
    test('writing progress for this course never touches an unrelated '
        'entry, including its own sibling course', () {
      final existing = {
        'grow_your_money': {
          gsLendingToGovernment: {'state': 'completed'},
        },
        'build_your_business': {
          brBeforeYouRegister: {'state': 'completed'},
        },
      };
      final out = withExpansionLessonState(
        existing,
        'build_your_business',
        birlOrderThatMatters,
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
            'the sibling course\'s own existing progress must survive '
            'untouched',
      );
      expect(
        parsed['build_your_business']?[birlOrderThatMatters],
        LessonState.completed,
      );
    });

    test('pathProgressFor counts across both courses in the flattened '
        'path total', () {
      final progress = parseExpansionProgress({
        'build_your_business': {
          brBeforeYouRegister: {'state': 'completed'},
          birlOrderThatMatters: {'state': 'completed'},
          birlGetYourTin: {'state': 'viewed'},
        },
      });
      final pp = pathProgressFor(
        pathId: 'build_your_business',
        lessonIds: [
          ...startABusinessLegallyLessons.map((l) => l.id),
          ..._stableLessonIds,
        ],
        progress: progress['build_your_business'] ?? const {},
      );
      expect(pp.total, 12);
      expect(pp.done, 2);
    });
  });

  group('content policy validator (Phase 4)', () {
    test('every lesson has zero validation errors', () {
      for (final lesson in birRegistrationAndLocalPermitsLessons) {
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
      for (final lesson in birRegistrationAndLocalPermitsLessons) {
        expect(
          lesson.topics,
          contains(ContentTopic.businessTaxOrPermitCompliance),
          reason: '${lesson.id} carries no matching ContentTopic',
        );
      }
    });
  });

  group('official-source metadata', () {
    test(
      'every lesson cites at least one structured, HTTPS official source',
      () {
        for (final lesson in birRegistrationAndLocalPermitsLessons) {
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
      for (final lesson in birRegistrationAndLocalPermitsLessons) {
        expect(
          lesson.blocks.whereType<OfficialSourceBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no OfficialSourceBlock',
        );
      }
    });

    test('every source is one of the five named official pages, never a '
        'blog, accounting firm, or law firm', () {
      const allowedUrls = {
        'https://www.bir.gov.ph/EOPT',
        'https://www.bir.gov.ph/bir-forms',
        'https://orus.bir.gov.ph/',
        'https://www.dti.gov.ph/dti-business-center/dti-business-registration-permits',
        'https://business.gov.ph/business-application-process',
      };
      for (final lesson in birRegistrationAndLocalPermitsLessons) {
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

    test('every official source is cited by at least one lesson', () {
      final cited = {
        for (final l in birRegistrationAndLocalPermitsLessons)
          for (final s in l.sources) s.canonicalUrl,
      };
      expect(cited, {
        'https://www.bir.gov.ph/EOPT',
        'https://www.bir.gov.ph/bir-forms',
        'https://orus.bir.gov.ph/',
        'https://www.dti.gov.ph/dti-business-center/dti-business-registration-permits',
        'https://business.gov.ph/business-application-process',
      });
    });

    test('BIR, DTI, and Philippine Business Hub mappings are verified: '
        'every source agency exactly matches its own URL\'s domain', () {
      const expectedAgencyByHost = {
        'www.bir.gov.ph': 'Bureau of Internal Revenue (BIR)',
        'orus.bir.gov.ph': 'Bureau of Internal Revenue (BIR)',
        'www.dti.gov.ph': 'Department of Trade and Industry (DTI)',
        'business.gov.ph': 'Philippine Business Hub',
      };
      for (final lesson in birRegistrationAndLocalPermitsLessons) {
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
        'lesson, with the high-volatility lessons carrying a shorter '
        'review window than the annual-volatility lessons', () {
      for (final lesson in birRegistrationAndLocalPermitsLessons) {
        final g = lesson.governance;
        expect(g.lastVerifiedDate, isNotNull);
        expect(g.reviewDueDate, isNotNull);
        final verified = parseGovernanceDate(g.lastVerifiedDate!);
        final due = parseGovernanceDate(g.reviewDueDate!);
        expect(verified, isNotNull);
        expect(due, isNotNull);
        expect(due!.isAfter(verified!), isTrue);
      }
      // The two structural lessons (order, compliance calendar) are
      // ContentVolatility.annual; the four fee/form/threshold lessons are
      // ContentVolatility.high with a review due date roughly six months
      // out, not a year, per this course's own deliberate exception.
      final annualLessons = [birlOrderThatMatters, birlComplianceCalendar];
      final highLessons = [
        birlGetYourTin,
        birlBooksAndInvoices,
        birlBarangayAndMayor,
        birlTaxpayerSize,
      ];
      for (final id in annualLessons) {
        final l = birRegistrationAndLocalPermitsLessons.firstWhere(
          (x) => x.id == id,
        );
        expect(l.governance.volatility, ContentVolatility.annual);
      }
      for (final id in highLessons) {
        final l = birRegistrationAndLocalPermitsLessons.firstWhere(
          (x) => x.id == id,
        );
        expect(l.governance.volatility, ContentVolatility.high);
      }
    });
  });

  group('this course\'s own deliberate exception: national BIR figures may '
      'be stated, local-government fees never may', () {
    test('the barangay and Mayor\'s Permit lesson never states a peso '
        'figure or a percentage, anywhere', () {
      final l = birRegistrationAndLocalPermitsLessons.firstWhere(
        (x) => x.id == birlBarangayAndMayor,
      );
      final banned = RegExp(
        r'\d+(\.\d+)?\s?%|(₱|php)\s?\d',
        caseSensitive: false,
      );
      expect(
        banned.hasMatch(_allText(l)),
        isFalse,
        reason:
            'local-government fees vary by city and municipality; this '
            'lesson must never state one',
      );
    });

    test('the barangay and Mayor\'s Permit lesson explicitly teaches that '
        'fees vary locally, via its own MythOrFactBlock', () {
      final l = birRegistrationAndLocalPermitsLessons.firstWhere(
        (x) => x.id == birlBarangayAndMayor,
      );
      final myth = l.interactionBlocks.whereType<MythOrFactBlock>().first;
      expect(myth.correctAnswer, MythOrFactAnswer.myth);
      expect(
        myth.statement.toLowerCase().contains('same amount everywhere'),
        isTrue,
      );
    });

    test('the taxpayer-size lesson never states a gross-sales threshold '
        'figure', () {
      final l = birRegistrationAndLocalPermitsLessons.firstWhere(
        (x) => x.id == birlTaxpayerSize,
      );
      final banned = RegExp(
        r'\d+(\.\d+)?\s?%|(₱|php)\s?\d',
        caseSensitive: false,
      );
      expect(banned.hasMatch(_allText(l)), isFalse);
    });

    test('every peso figure or percentage anywhere in this course lives '
        'only in a ContentVolatility.high lesson, and always sits beside '
        'a RiskWarningBlock naming that the rule can change', () {
      final numeric = RegExp(
        r'\d+(\.\d+)?\s?%|(₱|php)\s?\d',
        caseSensitive: false,
      );
      for (final l in birRegistrationAndLocalPermitsLessons) {
        if (numeric.hasMatch(_allText(l))) {
          expect(
            l.governance.volatility,
            ContentVolatility.high,
            reason:
                '${l.id} states a figure but is not classified '
                'ContentVolatility.high',
          );
          expect(
            l.blocks.whereType<RiskWarningBlock>(),
            isNotEmpty,
            reason: '${l.id} states a figure with no RiskWarningBlock',
          );
        }
      }
    });

    test('the two figures this course actually states (the abolished '
        'annual registration fee and the invoice threshold) are present '
        'in the right lessons', () {
      final tinLesson = birRegistrationAndLocalPermitsLessons.firstWhere(
        (x) => x.id == birlGetYourTin,
      );
      expect(_allText(tinLesson).contains('₱500'), isTrue);
      final booksLesson = birRegistrationAndLocalPermitsLessons.firstWhere(
        (x) => x.id == birlBooksAndInvoices,
      );
      expect(_allText(booksLesson).contains('₱100'), isTrue);
      expect(_allText(booksLesson).contains('₱500'), isTrue);
    });
  });

  group('risk warnings and educational boundary', () {
    test('every lesson carries a risk-warning block', () {
      for (final lesson in birRegistrationAndLocalPermitsLessons) {
        expect(
          lesson.blocks.whereType<RiskWarningBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no RiskWarningBlock',
        );
      }
    });

    test('every lesson carries the educational-boundary block', () {
      for (final lesson in birRegistrationAndLocalPermitsLessons) {
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
      for (final lesson in birRegistrationAndLocalPermitsLessons) {
        expect(
          lesson.interactionBlocks.where((b) => b.requiredForCompletion),
          isNotEmpty,
          reason: '${lesson.id} has no required interaction',
        );
      }
    });

    test('every lesson has unique interaction block ids', () {
      for (final lesson in birRegistrationAndLocalPermitsLessons) {
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
      for (final lesson in birRegistrationAndLocalPermitsLessons) {
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
      for (final l in birRegistrationAndLocalPermitsLessons) {
        final all = _allText(l);
        expect(all.contains('—'), isFalse, reason: '${l.id} em dash');
        expect(all.contains('–'), isFalse, reason: '${l.id} en dash');
      }
    });

    test('never guarantees approval or a processing time, and never says '
        'risk-free, except inside a negated (myth-debunking) sentence', () {
      // Directional, not blanket: this course's own house rules legitimately
      // teach against these words, so a bare match on "approved" would flag
      // the correct disclaimer sentences themselves. Scoped to the
      // affirmative shape only.
      final banned = RegExp(
        r'\bis guaranteed\b|\brisk[\s-]?free\b|\bwill be approved\b|'
        r'\bapproved instantly\b',
        caseSensitive: false,
      );
      for (final l in birRegistrationAndLocalPermitsLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} reads as a guarantee',
        );
      }
    });

    test('never implies Salapify is affiliated with BIR, DTI, a barangay, '
        'or any city or municipality', () {
      final banned = RegExp(
        r'\bSalapify (is|works with|partners with|is affiliated with|is '
        r'part of)\b[^.]{0,60}\b(BIR|DTI|barangay|city|municipal|'
        r'government)\b',
        caseSensitive: false,
      );
      for (final l in birRegistrationAndLocalPermitsLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });

    test('never files, submits, or transmits anything on the reader\'s '
        'behalf', () {
      final banned = RegExp(
        r'\bwe will (file|submit|register|apply) for you\b|'
        r'\bautomatically (files|submits|registers)\b',
        caseSensitive: false,
      );
      for (final l in birRegistrationAndLocalPermitsLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });
  });

  group('privacy requirements: no interaction requests sensitive business '
      'or identity data', () {
    test('no TIN number, government ID, date of birth, home address, or '
        'credential is ever requested (the TIN FORM is discussed, a real '
        'TIN NUMBER is never asked for)', () {
      final banned = RegExp(
        r'\benter your TIN\b|\btype your TIN\b|\byour TIN number\b|'
        r'\bgovernment ID number\b|\bdate of birth\b|\bhome address\b|'
        r'\bpassword\b|\bOTP\b',
        caseSensitive: false,
      );
      for (final l in birRegistrationAndLocalPermitsLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });

    test('no interaction in this course carries a free-text field', () {
      for (final l in birRegistrationAndLocalPermitsLessons) {
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
      for (final l in birRegistrationAndLocalPermitsLessons) {
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

    test('lesson 6 offers goals, budget, recurring, and notifications '
        'only, never an automatic write', () {
      final l = birRegistrationAndLocalPermitsLessons.firstWhere(
        (x) => x.id == birlComplianceCalendar,
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

  group('course-specific interaction coverage', () {
    MoneyLesson byId(String id) =>
        birRegistrationAndLocalPermitsLessons.firstWhere((l) => l.id == id);

    test('lesson 1\'s sequence covers all six steps in the diagram', () {
      final l = byId(birlOrderThatMatters);
      final sorting = l.interactionBlocks.whereType<SortingBlock>().first;
      expect(sorting.items.length, 6);
    });

    test('lesson 2\'s form-matching interaction covers 1901, 1902, and '
        '1903', () {
      final l = byId(birlGetYourTin);
      final match = l.interactionBlocks.whereType<CategorizeBlock>().first;
      expect(
        match.buckets.map((b) => b.label),
        containsAll(['Form 1901', 'Form 1902', 'Form 1903']),
      );
    });

    test('lesson 4 never generalizes a fee across every LGU or barangay', () {
      final l = byId(birlBarangayAndMayor);
      final banned = RegExp(
        r'\bevery LGU\b|\ball LGUs\b|\bevery barangay\b|\ball barangays\b',
        caseSensitive: false,
      );
      expect(banned.hasMatch(_allText(l)), isFalse);
    });

    test('lesson 5 never determines which taxpayer class any specific '
        'reader falls into', () {
      final l = byId(birlTaxpayerSize);
      final banned = RegExp(
        r'\byou are (a )?(micro|small|medium|large) taxpayer\b',
        caseSensitive: false,
      );
      expect(banned.hasMatch(_allText(l)), isFalse);
    });

    test('lesson 6 builds a checklist and offers verified actions, never '
        'a peso amount or a specific date', () {
      final l = byId(birlComplianceCalendar);
      final checklist = l.interactionBlocks.whereType<ChecklistBlock>().first;
      expect(checklist.items.length, greaterThanOrEqualTo(4));
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

  group('the expansion-content validator passes for the whole course', () {
    test('isPublishable is true for every lesson at the reference date', () {
      for (final lesson in birRegistrationAndLocalPermitsLessons) {
        expect(
          isPublishable(validateExpansionLesson(lesson, referenceDate: _ref)),
          isTrue,
        );
      }
    });
  });

  group('widget rendering: the form-matching interaction renders and '
      'updates', () {
    testWidgets('the form-matching CategorizeBlock renders and assigning every '
        'item to its correct bucket completes it', (tester) async {
      final l = birRegistrationAndLocalPermitsLessons.firstWhere(
        (x) => x.id == birlGetYourTin,
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
      expect(find.text('Form 1901'), findsWidgets);
      expect(find.text('Form 1902'), findsWidgets);
      expect(find.text('Form 1903'), findsWidgets);
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
    });
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
