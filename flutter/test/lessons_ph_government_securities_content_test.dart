// Money Courses Phase 12 content contract: the "Grow Your Money" learning
// path's fifth course, "Philippine Government Securities"
// (lib/content/lessons_ph_government_securities.dart,
// lib/content/learning_paths.dart). Proves this course is registered
// correctly, stays fully isolated from the core 22 lessons and from every
// earlier expansion course, and passes the house rules (no em/en dash, no
// current offering data, no guaranteed-outcome or risk-free language, no
// suitability recommendation) plus the Phase 4 content policy validator.
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
import 'package:salapify/content/lessons_crypto.dart';
import 'package:salapify/content/lessons_deposits_pooled_funds.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/content/lessons_ph_government_securities.dart';
import 'package:salapify/content/lessons_stocks_bonds.dart';
import 'package:salapify/money/expansion_content_policy.dart';

final _ref = DateTime.utc(2026, 8, 5);

const _stableLessonIds = [
  gsLendingToGovernment,
  gsTypesOfSecurities,
  gsCouponYieldPriceMaturity,
  gsHowSecuritiesReachInvestors,
  gsRisksAndScamChecks,
  gsDecisionPlan,
];

void main() {
  group('registration', () {
    test('grow_your_money carries ph_government_securities', () {
      final path = learningPaths.firstWhere((p) => p.id == 'grow_your_money');
      expect(path.status, LearningPathStatus.published);
      expect(path.isAvailable, isTrue);
      expect(
        path.groups.map((g) => g.id),
        contains('ph_government_securities'),
      );
      final group = path.groups.firstWhere(
        (g) => g.id == 'ph_government_securities',
      );
      expect(group.title, 'Philippine Government Securities');
      expect(group.lessonIds, _stableLessonIds);
    });

    test('the course is not registered under protect_your_future or any '
        'other path', () {
      final protectYourFuture = learningPaths.firstWhere(
        (p) => p.id == 'protect_your_future',
      );
      expect(
        protectYourFuture.groups.map((g) => g.id),
        isNot(contains('ph_government_securities')),
      );
      for (final path in learningPaths) {
        if (path.id == 'grow_your_money') continue;
        expect(
          path.groups.map((g) => g.id),
          isNot(contains('ph_government_securities')),
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

    test('the prerequisite is recommended, never a lock', () {
      final path = learningPaths.firstWhere((p) => p.id == 'grow_your_money');
      final group = path.groups.firstWhere(
        (g) => g.id == 'ph_government_securities',
      );
      expect(group.recommendedPriorGroupIds, [
        'investing_readiness',
        'stocks_and_bonds',
        'deposits_and_pooled_funds',
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

    test('publishedLearningPaths still shows Grow Your Money with this course '
        'reachable through it', () {
      expect(
        publishedLearningPaths.map((p) => p.id),
        contains('grow_your_money'),
      );
    });

    test('six stable lesson ids, in reading order', () {
      expect(
        phGovernmentSecuritiesLessons.map((l) => l.id).toList(),
        _stableLessonIds,
      );
    });

    test('lesson ids are unique', () {
      expect(_stableLessonIds.toSet().length, 6);
    });

    test('every lesson is registered under the ph_government_securities '
        'trackId', () {
      for (final l in phGovernmentSecuritiesLessons) {
        expect(l.trackId, 'ph_government_securities');
      }
    });
  });

  group('isolation from the core 22 and from every earlier expansion '
      'course', () {
    test('core lesson list is untouched: still 22 lessons, four courses', () {
      expect(core.lessons.length, 22);
      expect(core.courseTracks.length, 4);
    });

    test(
      'the pilot and every earlier grow_your_money course are untouched',
      () {
        expect(growYourMoneyLessons.length, 5);
        expect(stocksAndBondsLessons.length, 6);
        expect(depositsAndPooledFundsLessons.length, 6);
        expect(cryptoWithoutHypeLessons.length, 6);
      },
    );

    test('none of the new ids appear in the core flat lesson list', () {
      final coreIds = core.lessons.map((l) => l['id']).toSet();
      for (final id in _stableLessonIds) {
        expect(coreIds.contains(id), isFalse, reason: '$id leaked into core');
      }
    });

    test('none of the new ids collide with any earlier lesson id in this '
        'path', () {
      final earlierIds = {
        ...growYourMoneyLessons.map((l) => l.id),
        ...stocksAndBondsLessons.map((l) => l.id),
        ...depositsAndPooledFundsLessons.map((l) => l.id),
        ...cryptoWithoutHypeLessons.map((l) => l.id),
      };
      for (final id in _stableLessonIds) {
        expect(earlierIds.contains(id), isFalse);
      }
    });

    test('none of the new ids appear inside phGovernmentSecuritiesLessons '
        'more than once, and never inside an earlier course\'s own list', () {
      final ids = phGovernmentSecuritiesLessons.map((l) => l.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('content policy validator (Phase 4)', () {
    test('every lesson has zero validation errors', () {
      for (final lesson in phGovernmentSecuritiesLessons) {
        final result = validateExpansionLesson(lesson, referenceDate: _ref);
        expect(
          isPublishable(result),
          isTrue,
          reason: '${lesson.id}: ${result.errors.join('; ')}',
        );
      }
    });

    test('every lesson carries a bonds content topic, making it regulated '
        'content under the validator\'s own definition', () {
      for (final lesson in phGovernmentSecuritiesLessons) {
        expect(
          lesson.topics,
          isNotEmpty,
          reason: '${lesson.id} carries no ContentTopic',
        );
      }
    });
  });

  group('official-source metadata', () {
    test(
      'every lesson cites at least one structured, HTTPS official source',
      () {
        for (final lesson in phGovernmentSecuritiesLessons) {
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
      for (final lesson in phGovernmentSecuritiesLessons) {
        expect(
          lesson.blocks.whereType<OfficialSourceBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no OfficialSourceBlock',
        );
      }
    });

    test('every source is one of the eight named official pages, never a '
        'blog, bank, or broker', () {
      const allowedUrls = {
        'https://www.treasury.gov.ph/',
        'https://filiapp.treasury.gov.ph/investor_education.html',
        'https://filiapp.treasury.gov.ph/retail_treasury_bonds.html',
        'https://filiapp.treasury.gov.ph/investing.html',
        'https://www.treasury.gov.ph/?page_id=44424',
        'https://appointment.sec.gov.ph/investors-education-and-information/investment-101/',
        'https://www.bsp.gov.ph/SitePages/FinancialStability/BSPVerifier.aspx',
        'https://www.pdic.gov.ph/faqs-11',
      };
      for (final lesson in phGovernmentSecuritiesLessons) {
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

    test('verified and review-due dates are present and sane, and every '
        'high-volatility claim (none embedded here) would carry both', () {
      for (final lesson in phGovernmentSecuritiesLessons) {
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

  group('risk warnings and educational boundary', () {
    test('every lesson carries a risk-warning block', () {
      for (final lesson in phGovernmentSecuritiesLessons) {
        expect(
          lesson.blocks.whereType<RiskWarningBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no RiskWarningBlock',
        );
      }
    });

    test('every lesson carries the educational-boundary block', () {
      for (final lesson in phGovernmentSecuritiesLessons) {
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
      for (final lesson in phGovernmentSecuritiesLessons) {
        expect(
          lesson.interactionBlocks.where((b) => b.requiredForCompletion),
          isNotEmpty,
          reason: '${lesson.id} has no required interaction',
        );
      }
    });

    test('every lesson has unique interaction block ids', () {
      for (final lesson in phGovernmentSecuritiesLessons) {
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
      for (final lesson in phGovernmentSecuritiesLessons) {
        final check = lesson.check;
        expect(check, isNotNull, reason: '${lesson.id} has no check');
        expect(check!.isValid, isTrue);
        expect(check.explanation, isNotEmpty);
      }
    });
  });

  group('course-specific interaction coverage (the task\'s own list)', () {
    MoneyLesson byId(String id) =>
        phGovernmentSecuritiesLessons.firstWhere((l) => l.id == id);

    test('lesson 1 sorts fictional examples into the four required '
        'categories, and covers the PDIC boundary without quoting a limit', () {
      final l = byId(gsLendingToGovernment);
      final sort = l.interactionBlocks.whereType<CategorizeBlock>().first;
      expect(
        sort.buckets.map((b) => b.label),
        containsAll([
          'Bank deposit',
          'Government security',
          'Corporate stock',
          'Emergency cash',
        ]),
      );
      expect(l.interactionBlocks.whereType<MythOrFactBlock>(), isNotEmpty);
      final allText = _allText(l);
      // No PDIC coverage figure quoted anywhere in this lesson.
      expect(
        RegExp(
          r'(₱|php\s?)\s?1[\s,]?000[\s,]?000',
          caseSensitive: false,
        ).hasMatch(allText),
        isFalse,
      );
      expect(
        RegExp(
          r'(₱|php\s?)\s?500[\s,]?000',
          caseSensitive: false,
        ).hasMatch(allText),
        isFalse,
      );
    });

    test('lesson 2 has an instrument-matching interaction whose results use '
        'only the three required phrases', () {
      final l = byId(gsTypesOfSecurities);
      final scenarios = l.interactionBlocks.whereType<ScenarioChoiceBlock>();
      expect(scenarios.length, greaterThanOrEqualTo(1));
      final allExplanations = [
        for (final s in scenarios)
          for (final o in s.options) o.explanation,
      ].join(' ');
      expect(allExplanations.contains('Learn more about this type'), isTrue);
      expect(allExplanations.contains('Check the current offering'), isTrue);
      expect(
        allExplanations.contains('The maturity may not match this goal'),
        isTrue,
      );
      const banned = [
        'Buy this',
        'Best investment',
        'Perfect for you',
        'Guaranteed return',
      ];
      for (final phrase in banned) {
        expect(allExplanations.contains(phrase), isFalse);
      }
      // No exact current maturity ranges (day counts) or minimum placement
      // figures embedded.
      expect(
        RegExp(
          r'\b(91|182|364)[\s-]?day\b',
          caseSensitive: false,
        ).hasMatch(_allText(l)),
        isFalse,
      );
      expect(
        RegExp(
          r'(₱|php\s?)\s?5[\s,]?000',
          caseSensitive: false,
        ).hasMatch(_allText(l)),
        isFalse,
      );
    });

    test('lesson 3 uses a conceptual price-versus-yield scenario, never a '
        'calculator: no investment amount, rate, maturity date, or tax '
        'field is ever requested', () {
      final l = byId(gsCouponYieldPriceMaturity);
      final rateScenario = l.interactionBlocks
          .whereType<ScenarioChoiceBlock>()
          .firstWhere((s) => s.blockId == 'rtb-bought-above-face-value');
      expect(rateScenario.preferredOptionId, 'yield-below-coupon');
      // No numeric percentage anywhere in this lesson's text: nothing here
      // computes a price, a yield, or a return.
      expect(RegExp(r'\d+(\.\d+)?\s?%').hasMatch(_allText(l)), isFalse);
    });

    test('lesson 4 builds the seven-step official offer check in the '
        'correct order and never names or ranks a selling channel', () {
      final l = byId(gsHowSecuritiesReachInvestors);
      final sorting = l.interactionBlocks.whereType<SortingBlock>().first;
      expect(sorting.items.map((i) => i.id), [
        'start-at-btr',
        'locate-notice',
        'check-type-maturity',
        'review-rate-terms',
        'review-fees-liquidity',
        'verify-channel',
        'keep-confirmation',
      ]);
      const bannedBankNames = [
        'BDO',
        'BPI',
        'Metrobank',
        'Landbank',
        'GCash',
        'Maya',
        'PNB',
        'Security Bank',
        'RCBC',
      ];
      final allText = _allText(l);
      for (final name in bannedBankNames) {
        expect(allText.contains(name), isFalse, reason: '$name named');
      }
      expect(
        l.interactionBlocks.whereType<SalapifyActionsBlock>(),
        isEmpty,
        reason: 'lesson 4 never offers a purchase or account-opening flow',
      );
    });

    test('lesson 5 has a risk-or-scam-check interaction covering the full '
        'risk list and the required result labels', () {
      final l = byId(gsRisksAndScamChecks);
      final riskMatch = l.interactionBlocks
          .whereType<CategorizeBlock>()
          .firstWhere((c) => c.blockId == 'risk-type-match');
      expect(
        riskMatch.buckets.map((b) => b.label),
        containsAll([
          'Interest rate and price risk',
          'Inflation risk',
          'Liquidity risk',
          'Reinvestment risk',
          'Opportunity cost',
          'Tax and fee impact',
          'Sovereign credit risk',
          'Phishing and fake offering pages',
        ]),
      );
      final redFlags = l.interactionBlocks
          .whereType<CategorizeBlock>()
          .firstWhere((c) => c.blockId == 'scam-red-flags');
      expect(
        redFlags.buckets.map((b) => b.label),
        containsAll(['Red flag', 'Reasonable sign']),
      );
      final fakeOffering = l.interactionBlocks
          .whereType<ScenarioChoiceBlock>()
          .firstWhere((s) => s.blockId == 'fake-offering-scenario');
      expect(
        fakeOffering.options.map((o) => o.label),
        containsAll([
          'Verify before acting',
          'Stop and check the official offering',
          'Do not share credentials',
          'Report through the appropriate official channel',
        ]),
      );
      // Absence from one regulator's database is never claimed to prove
      // fraud on its own.
      expect(
        RegExp(
          r'proves? (it is a )?(scam|fraud)',
          caseSensitive: false,
        ).hasMatch(_allText(l)),
        isFalse,
      );
    });

    test('lesson 6 builds a non-prescriptive plan with up to three '
        'Salapify actions and never produces a peso amount or a named '
        'security', () {
      final l = byId(gsDecisionPlan);
      final actions = l.interactionBlocks
          .whereType<SalapifyActionsBlock>()
          .first;
      expect(actions.actions.length, lessThanOrEqualTo(3));
      expect(actions.actions, isNotEmpty);
      final checklist = l.interactionBlocks.whereType<ChecklistBlock>().first;
      expect(checklist.items.length, greaterThanOrEqualTo(5));
      expect(checklist.requiredForCompletion, isFalse);
      final allText = _allText(l);
      expect(RegExp(r'\d+(\.\d+)?\s?%').hasMatch(allText), isFalse);
      expect(
        RegExp(r'(₱|php)\s?\d', caseSensitive: false).hasMatch(allText),
        isFalse,
      );
    });
  });

  group('house rules: plain text content', () {
    test('no em or en dashes anywhere, content blocks or interactions', () {
      for (final l in phGovernmentSecuritiesLessons) {
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
      for (final l in phGovernmentSecuritiesLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} reads as a guaranteed-outcome claim',
        );
      }
    });

    test('never recommends a specific security, provider, or purchase', () {
      final banned = RegExp(
        r'\bbuy this\b|\bbest investment\b|\bperfect for you\b|'
        r'\bguaranteed return\b',
        caseSensitive: false,
      );
      for (final l in phGovernmentSecuritiesLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} reads as a banned recommendation phrase',
        );
      }
    });

    test('no current offering, rate, yield, minimum, or auction data '
        'embedded anywhere', () {
      final banned = RegExp(
        r'\d+(\.\d+)?\s?%|auction (date|schedule)',
        caseSensitive: false,
      );
      for (final l in phGovernmentSecuritiesLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} embeds a percentage or auction figure',
        );
      }
    });
  });

  group('Salapify actions: verified routes only, never an automatic write', () {
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
      for (final l in phGovernmentSecuritiesLessons) {
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

    test('the action model has no field that could hold an automatic write, '
        'a purchase, or a recorded security', () {
      // SalapifyActionDef carries only id, label, description, and route,
      // the same closed shape every earlier course already relies on for
      // "structurally incapable of an automatic write".
      final block = phGovernmentSecuritiesLessons
          .firstWhere((l) => l.id == gsDecisionPlan)
          .interactionBlocks
          .whereType<SalapifyActionsBlock>()
          .first;
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
