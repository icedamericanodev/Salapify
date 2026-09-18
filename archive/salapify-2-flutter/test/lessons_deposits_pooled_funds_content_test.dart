// Money Courses Phase 7B content contract: the "Grow Your Money" learning
// path's third course, "Deposits and Pooled Funds"
// (lib/content/lessons_deposits_pooled_funds.dart, lib/content/learning_paths.dart).
// Proves this course is registered correctly, stays fully isolated from the
// core 22 lessons AND from the Investing Readiness pilot AND from Phase 7A's
// "Stocks and Bonds Without the Hype", and passes the house rules (no
// em/en dash, no product names, no guaranteed-outcome language) plus the
// Phase 4 content policy validator.
//
// Mirrors test/lessons_stocks_bonds_content_test.dart's own structure on
// purpose, the established shape for a Money Courses content contract test.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/learning_path.dart';
import 'package:salapify/content/learning_paths.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons.dart' as core;
import 'package:salapify/content/lessons_deposits_pooled_funds.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/content/lessons_stocks_bonds.dart';
import 'package:salapify/money/expansion_content_policy.dart';

final _ref = DateTime.utc(2026, 8, 3);

const _stableLessonIds = [
  dpDepositOrInvestment,
  dpTimeDepositsAndPdic,
  dpHowPooledFundsWork,
  dpUitfMutualFundEtf,
  dpReadAFactSheet,
  dpMatchProductToGoal,
];

const _pilotLessonIds = [
  investRefMoneyJob,
  investRefProtectBase,
  investRefGoalTimeAccess,
  investRefRiskComfortCapacity,
  investRefCard,
];

const _stocksBondsLessonIds = [
  sbOwnerOrLender,
  sbStockReturnsAndLosses,
  sbPriceIsNotValue,
  sbDiversificationAndConcentration,
  sbHowBondsWork,
  sbVerifyBeforeYouInvest,
];

void main() {
  group('registration', () {
    test('grow_your_money carries all three courses', () {
      final path = learningPaths.firstWhere((p) => p.id == 'grow_your_money');
      expect(path.status, LearningPathStatus.published);
      expect(path.isAvailable, isTrue);
      expect(
        path.groups.map((g) => g.id),
        containsAll([
          'investing_readiness',
          'stocks_and_bonds',
          'deposits_and_pooled_funds',
        ]),
      );
      final group = path.groups.firstWhere(
        (g) => g.id == 'deposits_and_pooled_funds',
      );
      expect(group.title, 'Deposits and Pooled Funds');
      expect(group.lessonIds, _stableLessonIds);
      // The path's flat id list is investing_readiness's five lessons,
      // then stocks_and_bonds's six, then this course's six, since groups
      // render in the order they were authored. Phase 8 added a fourth
      // group ("Crypto Without the Hype") after this one, so the flat list
      // no longer ends here; this test only asserts that this course's own
      // six still appear as a contiguous run right after stocks_and_bonds's,
      // not that they are the whole list. See
      // test/lessons_crypto_content_test.dart for the full, four-course
      // assertion.
      expect(
        path.lessonIds.sublist(
          0,
          _pilotLessonIds.length +
              _stocksBondsLessonIds.length +
              _stableLessonIds.length,
        ),
        [..._pilotLessonIds, ..._stocksBondsLessonIds, ..._stableLessonIds],
      );
    });

    test('both prerequisites are recommended, never a lock', () {
      final path = learningPaths.firstWhere((p) => p.id == 'grow_your_money');
      final group = path.groups.firstWhere(
        (g) => g.id == 'deposits_and_pooled_funds',
      );
      expect(group.recommendedPriorGroupIds, [
        'investing_readiness',
        'stocks_and_bonds',
      ]);
      // Nothing in LearningPath/LearningPathGroup carries a lock, gate, or
      // required-completion field for a group's own lessons: lessonsForPath
      // returns every lesson regardless of any other group's progress, which
      // is what makes "recommended, not locked" true by construction.
      final allLessons = lessonsForPath('grow_your_money');
      for (final id in _stableLessonIds) {
        expect(allLessons.map((l) => l.id), contains(id));
      }
    });

    test('publishedLearningPaths still shows Grow Your Money (Phase 9 adds '
        'a second published path, Protect Your Future, alongside it)', () {
      expect(
        publishedLearningPaths.map((p) => p.id),
        contains('grow_your_money'),
      );
    });

    test('six stable lesson ids, in reading order', () {
      expect(
        depositsAndPooledFundsLessons.map((l) => l.id).toList(),
        _stableLessonIds,
      );
    });

    test('lesson ids are unique', () {
      expect(_stableLessonIds.toSet().length, 6);
    });

    test('every lesson is registered under the deposits_and_pooled_funds '
        'trackId', () {
      for (final l in depositsAndPooledFundsLessons) {
        expect(l.trackId, 'deposits_and_pooled_funds');
      }
    });

    test('expansionLessonById resolves a lesson from this course', () {
      final found = expansionLessonById(dpDepositOrInvestment);
      expect(found, isNotNull);
      expect(found!.pathId, 'grow_your_money');
      expect(found.lesson.id, dpDepositOrInvestment);
    });
  });

  group('isolation from the core 22, the pilot, and Stocks and Bonds', () {
    test('core lesson list is untouched: still 22 lessons, four courses', () {
      expect(core.lessons.length, 22);
      expect(core.courseTracks.length, 4);
    });

    test('the pilot is untouched: still 5 lessons, in the same order', () {
      expect(growYourMoneyLessons.map((l) => l.id).toList(), _pilotLessonIds);
    });

    test(
      'Stocks and Bonds is untouched: still 6 lessons, in the same order',
      () {
        expect(
          stocksAndBondsLessons.map((l) => l.id).toList(),
          _stocksBondsLessonIds,
        );
      },
    );

    test('none of the new ids appear in the core flat lesson list', () {
      final coreIds = core.lessons.map((l) => l['id']).toSet();
      for (final id in _stableLessonIds) {
        expect(coreIds.contains(id), isFalse, reason: '$id leaked into core');
      }
    });

    test('none of the new ids collide with a core id, a pilot id, or a Stocks '
        'and Bonds id', () {
      final coreIds = core.lessons.map((l) => l['id']).toSet();
      final pilotIds = _pilotLessonIds.toSet();
      final sbIds = _stocksBondsLessonIds.toSet();
      for (final id in _stableLessonIds) {
        expect(coreIds.contains(id), isFalse);
        expect(pilotIds.contains(id), isFalse);
        expect(sbIds.contains(id), isFalse);
      }
    });

    test('none of the new ids appear in growYourMoneyLessons or '
        'stocksAndBondsLessons themselves', () {
      final pilotIds = growYourMoneyLessons.map((l) => l.id).toSet();
      final sbIds = stocksAndBondsLessons.map((l) => l.id).toSet();
      for (final id in _stableLessonIds) {
        expect(pilotIds.contains(id), isFalse);
        expect(sbIds.contains(id), isFalse);
      }
    });
  });

  group('content policy validator (Phase 4)', () {
    test('every lesson has zero validation errors', () {
      for (final lesson in depositsAndPooledFundsLessons) {
        final result = validateExpansionLesson(lesson, referenceDate: _ref);
        expect(
          isPublishable(result),
          isTrue,
          reason: '${lesson.id}: ${result.errors.join('; ')}',
        );
      }
    });

    test('every lesson carries at least one ContentTopic, making it '
        'regulated content under the validator\'s own definition', () {
      for (final lesson in depositsAndPooledFundsLessons) {
        expect(
          lesson.topics,
          isNotEmpty,
          reason: '${lesson.id} carries no ContentTopic',
        );
      }
    });

    test('the deposit lessons carry ContentTopic.bankDeposits and the fund '
        'lessons carry ContentTopic.fundsAndEtfs', () {
      MoneyLesson byId(String id) =>
          depositsAndPooledFundsLessons.firstWhere((l) => l.id == id);
      expect(
        byId(dpTimeDepositsAndPdic).topics,
        contains(ContentTopic.bankDeposits),
      );
      expect(
        byId(dpHowPooledFundsWork).topics,
        contains(ContentTopic.fundsAndEtfs),
      );
      expect(
        byId(dpUitfMutualFundEtf).topics,
        contains(ContentTopic.fundsAndEtfs),
      );
    });
  });

  group('official-source metadata', () {
    test(
      'every lesson cites at least one structured, HTTPS official source',
      () {
        for (final lesson in depositsAndPooledFundsLessons) {
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
      for (final lesson in depositsAndPooledFundsLessons) {
        expect(
          lesson.blocks.whereType<OfficialSourceBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no OfficialSourceBlock',
        );
      }
    });

    test('verified and review-due dates are present and sane', () {
      for (final lesson in depositsAndPooledFundsLessons) {
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

    test('Lesson 2 cites PDIC\'s own page and its calculator', () {
      final l = depositsAndPooledFundsLessons.firstWhere(
        (l) => l.id == dpTimeDepositsAndPdic,
      );
      final sourceTitles = l.blocks
          .whereType<OfficialSourceBlock>()
          .map((b) => b.sourceTitle)
          .toList();
      expect(sourceTitles, contains('Maximum Deposit Insurance Coverage'));
      expect(sourceTitles, contains('Deposit Insurance Calculator'));
    });
  });

  group('risk warnings and educational boundary', () {
    test('every lesson carries a risk-warning block', () {
      for (final lesson in depositsAndPooledFundsLessons) {
        expect(
          lesson.blocks.whereType<RiskWarningBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no RiskWarningBlock',
        );
      }
    });

    test('every lesson carries the educational-boundary block', () {
      for (final lesson in depositsAndPooledFundsLessons) {
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
      for (final lesson in depositsAndPooledFundsLessons) {
        expect(
          lesson.interactionBlocks.where((b) => b.requiredForCompletion),
          isNotEmpty,
          reason: '${lesson.id} has no required interaction',
        );
      }
    });

    test('every lesson has unique interaction block ids', () {
      for (final lesson in depositsAndPooledFundsLessons) {
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
      for (final lesson in depositsAndPooledFundsLessons) {
        final check = lesson.check;
        expect(check, isNotNull, reason: '${lesson.id} has no mastery check');
        expect(check!.isValid, isTrue);
        expect(check.explanation, isNotEmpty);
      }
    });
  });

  group('course-specific interaction coverage (the task\'s own list)', () {
    MoneyLesson byId(String id) =>
        depositsAndPooledFundsLessons.firstWhere((l) => l.id == id);

    test('lesson 1 sorts fictional products into deposit or investment, '
        'includes the required myth, and a scenario', () {
      final l = byId(dpDepositOrInvestment);
      final sort = l.interactionBlocks.whereType<CategorizeBlock>().first;
      expect(
        sort.buckets.map((b) => b.label),
        containsAll(['Bank deposit', 'Investment product']),
      );
      expect(sort.items.length, greaterThanOrEqualTo(7));
      final myth = l.interactionBlocks.whereType<MythOrFactBlock>().firstWhere(
        (m) => m.blockId == 'bank-offers-it-myth',
      );
      expect(
        myth.statement,
        'If a bank offers it, PDIC automatically covers it.',
      );
      expect(myth.correctAnswer, MythOrFactAnswer.myth);
      expect(l.interactionBlocks.whereType<ScenarioChoiceBlock>(), isNotEmpty);
    });

    test('lesson 2 has a fictional account-classification scenario, a '
        'basic coverage illustration, and a maturity checklist', () {
      final l = byId(dpTimeDepositsAndPdic);
      expect(l.interactionBlocks.whereType<ScenarioChoiceBlock>(), isNotEmpty);
      final illustration = l.interactionBlocks
          .whereType<ComparisonBlock>()
          .firstWhere((c) => c.blockId == 'basic-coverage-illustration');
      expect(illustration.items.length, 2);
      final checklist = l.interactionBlocks.whereType<ChecklistBlock>().first;
      expect(checklist.items.length, greaterThanOrEqualTo(4));
      // Never gates completion: no in-app route can resolve a real PDIC
      // coverage determination, so the checklist stays optional.
      expect(checklist.requiredForCompletion, isFalse);
      // Never a complete legal-entitlement calculator: the illustration
      // stays to exactly two simplified, labeled scenarios.
      for (final item in illustration.items) {
        expect(item.name.toLowerCase().contains('you'), isFalse);
      }
    });

    test('lesson 3 has a pooled-fund diagram and a labeling interaction', () {
      final l = byId(dpHowPooledFundsWork);
      expect(l.blocks.whereType<DiagramBlock>(), isNotEmpty);
      final labels = l.interactionBlocks
          .whereType<CategorizeBlock>()
          .firstWhere((c) => c.blockId == 'pooled-fund-diagram-labels');
      expect(labels.buckets.length, 5);
      expect(l.interactionBlocks.whereType<MythOrFactBlock>(), isNotEmpty);
      expect(l.interactionBlocks.whereType<ScenarioChoiceBlock>(), isNotEmpty);
    });

    test('lesson 4 compares UITF, mutual fund, and ETF with no product '
        'labeled best or ranked', () {
      final l = byId(dpUitfMutualFundEtf);
      final comparison = l.interactionBlocks
          .whereType<ComparisonBlock>()
          .firstWhere((c) => c.blockId == 'uitf-mutual-fund-etf-comparison');
      expect(comparison.items.length, 3);
      expect(
        comparison.criteria.map((c) => c.label),
        containsAll([
          'General structure',
          'How you participate',
          'Pricing or valuation',
          'Where it is traded',
          'Liquidity and redemption',
          'Fees and expenses',
          'Supervising authority',
          'Main risks',
        ]),
      );
      for (final item in comparison.items) {
        expect(item.name.toLowerCase().contains('best'), isFalse);
        for (final v in item.valuesByCriterionId.values) {
          expect(v.toLowerCase().contains('best'), isFalse);
        }
      }
    });

    test('lesson 5 has a fictional fact-sheet activity identifying what is '
        'answered and what is missing, plus the fee-impact illustration', () {
      final l = byId(dpReadAFactSheet);
      final scavenger = l.interactionBlocks
          .whereType<CategorizeBlock>()
          .firstWhere((c) => c.blockId == 'fact-sheet-scavenger');
      expect(
        scavenger.buckets.map((b) => b.label),
        containsAll(['Answered in the fact sheet', 'Missing, investigate']),
      );
      expect(
        scavenger.correctBucketByItemId.values.contains('investigate'),
        isTrue,
        reason: 'at least one item must be missing information',
      );
      final allText = _allText(l);
      expect(allText.contains('1,500 pesos'), isTrue);
      expect(allText.contains('7,500 pesos'), isTrue);
      expect(allText.contains('92,500 pesos'), isTrue);
      // Never a forecast of what the fund would return: no percentage
      // return figure appears anywhere in this lesson's text.
      expect(RegExp(r'\d+\s?%').hasMatch(allText), isFalse);
    });

    test('lesson 6 matches fictional situations to product-appropriate next '
        'steps without forcing every scenario toward investing', () {
      final l = byId(dpMatchProductToGoal);
      final match = l.interactionBlocks.whereType<CategorizeBlock>().firstWhere(
        (c) => c.blockId == 'product-to-goal-match',
      );
      expect(
        match.buckets.map((b) => b.label),
        containsAll([
          'Keep the money accessible',
          'Review the financial foundation first',
          'Investigate an appropriate product category',
          'Do not invest this money yet',
        ]),
      );
      // Not every situation resolves to "invest": at least one item maps to
      // each of the two non-investment buckets.
      final buckets = match.correctBucketByItemId.values.toSet();
      expect(buckets.contains('keep-accessible'), isTrue);
      expect(buckets.contains('do-not-invest-yet'), isTrue);
      expect(l.interactionBlocks.whereType<ComparisonBlock>(), isNotEmpty);
      expect(
        l.interactionBlocks.whereType<ChecklistBlock>().where(
          (c) => c.blockId == 'readiness-checklist',
        ),
        isNotEmpty,
      );
      expect(
        l.interactionBlocks.whereType<ScenarioChoiceBlock>().where(
          (s) => s.blockId == 'mastery-scenario',
        ),
        isNotEmpty,
      );
      final redFlags = l.interactionBlocks
          .whereType<CategorizeBlock>()
          .firstWhere((c) => c.blockId == 'scam-pressure-signs');
      expect(
        redFlags.buckets.map((b) => b.label),
        containsAll(['Red flag', 'Reasonable sign']),
      );
    });
  });

  group('house rules: plain text content', () {
    test('no em or en dashes anywhere, content blocks or interactions', () {
      for (final l in depositsAndPooledFundsLessons) {
        final all = _allText(l);
        expect(all.contains('—'), isFalse, reason: '${l.id} em dash');
        expect(all.contains('–'), isFalse, reason: '${l.id} en dash');
      }
    });

    test('no guaranteed-outcome or risk-free language', () {
      final banned = RegExp(
        r'\bguarantee[ds]?\s+(a\s+|an\s+)?(profit|return|income|growth)\b|'
        r'\brisk[\s-]?free\b',
        caseSensitive: false,
      );
      for (final l in depositsAndPooledFundsLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} reads as a guaranteed-outcome claim',
        );
      }
    });

    test('no named real bank, UITF, mutual fund, or ETF: only fictional or '
        'generic references', () {
      const bannedNames = [
        'Jollibee',
        'SM Investments',
        'Ayala',
        'BDO',
        'BPI',
        'PLDT',
        'Meralco',
        'San Miguel',
        'GCash',
        'Maya',
        'Metrobank',
        'Landbank',
        'UnionBank',
      ];
      for (final l in depositsAndPooledFundsLessons) {
        final all = _allText(l);
        for (final name in bannedNames) {
          expect(
            all.contains(name),
            isFalse,
            reason: '${l.id} names a real company: $name',
          );
        }
      }
    });

    test('the fictional fund is labeled fictional', () {
      final l = depositsAndPooledFundsLessons.firstWhere(
        (l) => l.id == dpReadAFactSheet,
      );
      final all = _allText(l);
      for (final match in RegExp(
        r'Example [\w ]*?(Fund|Growth)',
      ).allMatches(all)) {
        final windowStart = (match.start - 20).clamp(0, all.length);
        final windowEnd = (match.end + 60).clamp(0, all.length);
        final window = all.substring(windowStart, windowEnd);
        expect(
          window.toLowerCase().contains('fictional'),
          isTrue,
          reason:
              '"${match.group(0)}" is not marked fictional nearby: '
              '"$window"',
        );
      }
    });

    test('never declares a depositor\'s coverage officially settled', () {
      final banned = RegExp(
        r"\byou(?:'re| are)\b[^.]{0,20}\b(officially\s+)?(approved|covered|"
        r'eligible|qualified)\b',
        caseSensitive: false,
      );
      for (final l in depositsAndPooledFundsLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason:
              '${l.id} declares the reader officially covered or '
              'eligible',
        );
      }
    });
  });

  group('Salapify actions: verified routes only, never an automatic write', () {
    test('every action route is a known, pushable Salapify screen', () {
      const knownRoutes = {'goals', 'debts', 'budget', 'mindset', 'accounts'};
      final block = _salapifyActionsBlock();
      for (final action in block.actions) {
        expect(
          knownRoutes.contains(action.route),
          isTrue,
          reason: 'unknown route "${action.route}"',
        );
        expect(action.description, isNotEmpty);
      }
    });

    test('the four required actions are all present', () {
      final block = _salapifyActionsBlock();
      final ids = block.actions.map((a) => a.id).toSet();
      expect(ids, {
        'review-goal',
        'review-budget',
        'open-mindset',
        'review-investment-account',
      });
    });

    test('never labels an investment as a bank deposit, never records a '
        'market gain as a contribution: the action model has no field that '
        'could hold either', () {
      final block = _salapifyActionsBlock();
      for (final action in block.actions) {
        expect(action.route, isNotEmpty);
      }
    });
  });
}

String _allText(MoneyLesson l) {
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
          if (i.caution != null) buf.write(' ${i.caution}');
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
      // Added for Money Courses Phase 8 ("Crypto Without the Hype"); this
      // course never registers either kind, so there is nothing extra to
      // capture beyond the prompt/instructions already written above.
      case LossImpactSimulatorBlock():
      case RiskReviewChecklistBlock():
        break;
    }
  }
  return buf.toString();
}

SalapifyActionsBlock _salapifyActionsBlock() {
  final lesson = depositsAndPooledFundsLessons.firstWhere(
    (l) => l.id == dpMatchProductToGoal,
  );
  return lesson.interactionBlocks.whereType<SalapifyActionsBlock>().first;
}
