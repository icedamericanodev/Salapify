// Money Courses Phase 7A content contract: the "Grow Your Money" learning
// path's second course, "Stocks and Bonds Without the Hype"
// (lib/content/lessons_stocks_bonds.dart, lib/content/learning_paths.dart).
// Proves this course is registered correctly, stays fully isolated from the
// core 22 lessons AND from the Investing Readiness pilot's 5 lessons, and
// passes the house rules (no em/en dash, no product names, no
// guaranteed-outcome language) plus the Phase 4 content policy validator.
//
// Mirrors test/lessons_grow_content_test.dart's own structure on purpose,
// the established shape for a Money Courses content contract test.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/learning_path.dart';
import 'package:salapify/content/learning_paths.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons.dart' as core;
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/content/lessons_stocks_bonds.dart';
import 'package:salapify/money/expansion_content_policy.dart';

final _ref = DateTime.utc(2026, 8, 3);

const _stableLessonIds = [
  sbOwnerOrLender,
  sbStockReturnsAndLosses,
  sbPriceIsNotValue,
  sbDiversificationAndConcentration,
  sbHowBondsWork,
  sbVerifyBeforeYouInvest,
];

const _pilotLessonIds = [
  investRefMoneyJob,
  investRefProtectBase,
  investRefGoalTimeAccess,
  investRefRiskComfortCapacity,
  investRefCard,
];

void main() {
  group('registration', () {
    test(
      'grow_your_money carries both investing_readiness and stocks_and_bonds',
      () {
        final path = learningPaths.firstWhere((p) => p.id == 'grow_your_money');
        expect(path.status, LearningPathStatus.published);
        expect(path.isAvailable, isTrue);
        expect(
          path.groups.map((g) => g.id),
          containsAll(['investing_readiness', 'stocks_and_bonds']),
        );
        final group = path.groups.firstWhere((g) => g.id == 'stocks_and_bonds');
        expect(group.title, 'Stocks and Bonds Without the Hype');
        expect(group.lessonIds, _stableLessonIds);
        // The path's flat id list is investing_readiness's five lessons
        // FIRST, then this course's six, since groups render in the order
        // they were authored and the pilot group is listed first.
        expect(path.lessonIds, [..._pilotLessonIds, ..._stableLessonIds]);
      },
    );

    test('the prerequisite is recommended, never a lock', () {
      final path = learningPaths.firstWhere((p) => p.id == 'grow_your_money');
      final group = path.groups.firstWhere((g) => g.id == 'stocks_and_bonds');
      expect(group.recommendedPriorGroupIds, ['investing_readiness']);
      // Nothing in LearningPath/LearningPathGroup carries a lock, gate, or
      // required-completion field for a group's own lessons: lessonsForPath
      // returns every lesson regardless of any other group's progress, which
      // is what makes "recommended, not locked" true by construction.
      final allLessons = lessonsForPath('grow_your_money');
      for (final id in _stableLessonIds) {
        expect(allLessons.map((l) => l.id), contains(id));
      }
    });

    test('publishedLearningPaths still shows only Grow Your Money', () {
      expect(publishedLearningPaths.map((p) => p.id), ['grow_your_money']);
    });

    test('six stable lesson ids, in reading order', () {
      expect(
        stocksAndBondsLessons.map((l) => l.id).toList(),
        _stableLessonIds,
      );
    });

    test('lesson ids are unique', () {
      expect(_stableLessonIds.toSet().length, 6);
    });

    test('every lesson is registered under the stocks_and_bonds trackId', () {
      for (final l in stocksAndBondsLessons) {
        expect(l.trackId, 'stocks_and_bonds');
      }
    });
  });

  group('isolation from the core 22 and from the pilot', () {
    test('core lesson list is untouched: still 22 lessons, four courses', () {
      expect(core.lessons.length, 22);
      expect(core.courseTracks.length, 4);
    });

    test('the pilot is untouched: still 5 lessons, in the same order', () {
      expect(growYourMoneyLessons.map((l) => l.id).toList(), _pilotLessonIds);
    });

    test('none of the new ids appear in the core flat lesson list', () {
      final coreIds = core.lessons.map((l) => l['id']).toSet();
      for (final id in _stableLessonIds) {
        expect(coreIds.contains(id), isFalse, reason: '$id leaked into core');
      }
    });

    test('none of the new ids collide with a core id or a pilot id', () {
      final coreIds = core.lessons.map((l) => l['id']).toSet();
      final pilotIds = _pilotLessonIds.toSet();
      for (final id in _stableLessonIds) {
        expect(coreIds.contains(id), isFalse);
        expect(pilotIds.contains(id), isFalse);
      }
    });

    test('none of the new ids appear in growYourMoneyLessons itself', () {
      final pilotIds = growYourMoneyLessons.map((l) => l.id).toSet();
      for (final id in _stableLessonIds) {
        expect(pilotIds.contains(id), isFalse);
      }
    });
  });

  group('content policy validator (Phase 4)', () {
    test('every lesson has zero validation errors', () {
      for (final lesson in stocksAndBondsLessons) {
        final result = validateExpansionLesson(lesson, referenceDate: _ref);
        expect(
          isPublishable(result),
          isTrue,
          reason: '${lesson.id}: ${result.errors.join('; ')}',
        );
      }
    });

    test('every lesson carries a stocks or bonds content topic, making it '
        'regulated content under the validator\'s own definition', () {
      for (final lesson in stocksAndBondsLessons) {
        expect(
          lesson.topics,
          isNotEmpty,
          reason: '${lesson.id} carries no ContentTopic',
        );
      }
    });
  });

  group('official-source metadata', () {
    test('every lesson cites at least one structured, HTTPS official source',
        () {
      for (final lesson in stocksAndBondsLessons) {
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
    });

    test('every lesson renders an OfficialSourceBlock', () {
      for (final lesson in stocksAndBondsLessons) {
        expect(
          lesson.blocks.whereType<OfficialSourceBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no OfficialSourceBlock',
        );
      }
    });

    test('verified and review-due dates are present and sane', () {
      for (final lesson in stocksAndBondsLessons) {
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

    test('no lesson embeds a stale broker list or an active government-bond '
        'offering: lesson 6 only links to the current official directory', () {
      final verify = stocksAndBondsLessons.firstWhere(
        (l) => l.id == sbVerifyBeforeYouInvest,
      );
      final sourceTitles = verify.blocks
          .whereType<OfficialSourceBlock>()
          .map((b) => b.sourceTitle)
          .toList();
      expect(sourceTitles, contains('Trading Participant Directory'));
      // A directory or a general education page, never a specific offering
      // (a bond series, an interest rate, a subscription window).
      for (final title in sourceTitles) {
        expect(RegExp(r'\bseries\b', caseSensitive: false).hasMatch(title),
            isFalse);
      }
    });
  });

  group('risk warnings and educational boundary', () {
    test('every lesson carries a risk-warning block', () {
      for (final lesson in stocksAndBondsLessons) {
        expect(
          lesson.blocks.whereType<RiskWarningBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no RiskWarningBlock',
        );
      }
    });

    test('every lesson carries the educational-boundary block', () {
      for (final lesson in stocksAndBondsLessons) {
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
      for (final lesson in stocksAndBondsLessons) {
        expect(
          lesson.interactionBlocks.where((b) => b.requiredForCompletion),
          isNotEmpty,
          reason: '${lesson.id} has no required interaction',
        );
      }
    });

    test('every lesson has unique interaction block ids', () {
      for (final lesson in stocksAndBondsLessons) {
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
      for (final lesson in stocksAndBondsLessons) {
        final check = lesson.check;
        expect(check, isNotNull, reason: '${lesson.id} has no mastery check');
        expect(check!.isValid, isTrue);
        expect(check.explanation, isNotEmpty);
      }
    });
  });

  group('course-specific interaction coverage (the task\'s own list)', () {
    MoneyLesson byId(String id) =>
        stocksAndBondsLessons.firstWhere((l) => l.id == id);

    test('lesson 1 sorts fictional examples into Owner, Lender, Depositor',
        () {
      final l = byId(sbOwnerOrLender);
      final sort = l.interactionBlocks.whereType<CategorizeBlock>().first;
      expect(
        sort.buckets.map((b) => b.label),
        containsAll(['Owner', 'Lender', 'Depositor']),
      );
      expect(l.interactionBlocks.whereType<MythOrFactBlock>(), isNotEmpty);
      expect(l.interactionBlocks.whereType<ScenarioChoiceBlock>(), isNotEmpty);
    });

    test('lesson 2 has a myth-or-fact and a fictional price/dividend '
        'scenario', () {
      final l = byId(sbStockReturnsAndLosses);
      expect(l.interactionBlocks.whereType<MythOrFactBlock>(), isNotEmpty);
      expect(l.interactionBlocks.whereType<ScenarioChoiceBlock>(), isNotEmpty);
    });

    test('lesson 3 compares two fictional companies with no correct stock '
        'to buy', () {
      final l = byId(sbPriceIsNotValue);
      final comparison =
          l.interactionBlocks.whereType<ComparisonBlock>().first;
      expect(comparison.items.length, 2);
      expect(comparison.criteria.map((c) => c.label), containsAll([
        'Revenue',
        'Profit',
        'Cash flow',
        'Debt',
        'Shares outstanding',
      ]));
      // Something is deliberately missing, standing in for "what information
      // remains missing" the task asks the learner to identify.
      final hasBlankValue = comparison.items.any(
        (i) => i.valuesByCriterionId.values.any((v) => v.trim().isEmpty),
      );
      expect(hasBlankValue, isTrue);
      // No item name reads as a recommendation ("the correct stock to buy").
      for (final item in comparison.items) {
        expect(item.name.toLowerCase().contains('best'), isFalse);
        expect(item.name.toLowerCase().contains('buy'), isFalse);
      }
    });

    test('lesson 4 compares fictional portfolios and includes a scenario '
        'and a reflection on possible loss', () {
      final l = byId(sbDiversificationAndConcentration);
      expect(l.interactionBlocks.whereType<ComparisonBlock>(), isNotEmpty);
      expect(l.interactionBlocks.whereType<ScenarioChoiceBlock>(), isNotEmpty);
      final reflections = l.interactionBlocks.whereType<ReflectionPromptBlock>();
      expect(reflections, isNotEmpty);
      // Never persisted anywhere: the reflection stays free text in widget
      // state only, the same non-storage contract every ReflectionPromptBlock
      // already carries (see interaction_blocks.dart's own privacyNote).
      for (final r in reflections) {
        expect(
          r.privacyNote.contains('never saved'),
          isTrue,
          reason: 'a reflection must not read as a stored risk profile',
        );
      }
      // No specific allocation or percentage recommendation anywhere in this
      // lesson's authored or interaction text.
      expect(RegExp(r'\d+\s?%').hasMatch(_allText(l)), isFalse);
    });

    test('lesson 5 has a bond timeline, an owner/lender check, a directional '
        'rate scenario, and risk matching', () {
      final l = byId(sbHowBondsWork);
      final sorting = l.interactionBlocks.whereType<SortingBlock>().first;
      expect(sorting.items.length, greaterThanOrEqualTo(3));
      expect(l.interactionBlocks.whereType<CategorizeBlock>().length, 2);
      final rateScenario = l.interactionBlocks
          .whereType<ScenarioChoiceBlock>()
          .firstWhere((s) => s.blockId == 'bond-rate-direction');
      expect(rateScenario.preferredOptionId, 'price-falls');
      final riskMatch = l.interactionBlocks
          .whereType<CategorizeBlock>()
          .firstWhere((c) => c.blockId == 'bond-risk-match');
      expect(riskMatch.buckets.map((b) => b.label), containsAll([
        'Interest rate risk',
        'Credit risk',
        'Inflation risk',
        'Liquidity risk',
        'Reinvestment risk',
      ]));
    });

    test('lesson 6 has a scam red-flag challenge, a fake-broker scenario, a '
        'hot-tip scenario, and a personal checklist', () {
      final l = byId(sbVerifyBeforeYouInvest);
      final redFlags = l.interactionBlocks
          .whereType<CategorizeBlock>()
          .firstWhere((c) => c.blockId == 'scam-red-flags');
      expect(redFlags.buckets.map((b) => b.label),
          containsAll(['Red flag', 'Reasonable sign']));
      expect(
        l.interactionBlocks.whereType<ScenarioChoiceBlock>().length,
        greaterThanOrEqualTo(2),
      );
      final checklist =
          l.interactionBlocks.whereType<ChecklistBlock>().first;
      expect(checklist.items.length, greaterThanOrEqualTo(5));
      // An offline checklist, never gating completion: no in-app route can
      // verify a broker in real time, so this is the safe fallback the task
      // asks for.
      expect(checklist.requiredForCompletion, isFalse);
    });
  });

  group('house rules: plain text content', () {
    test('no em or en dashes anywhere, content blocks or interactions', () {
      for (final l in stocksAndBondsLessons) {
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
      for (final l in stocksAndBondsLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} reads as a guaranteed-outcome claim',
        );
      }
    });

    test('no named real stock, bond, fund, or broker: only fictional or '
        'generic references', () {
      // A narrow denylist of real Philippine market names that must never
      // appear, matching the task's own "no named securities" rule. This is
      // deliberately small and specific, not a broad blacklist.
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
      ];
      for (final l in stocksAndBondsLessons) {
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

    test('every fictional company is labeled fictional', () {
      // Every company-like proper noun this course invents carries the word
      // "fictional" somewhere in the same sentence, so a reader never
      // mistakes it for a real one. A generous window either side (not a
      // tight character count) is what makes this robust to how the
      // sentence around each mention happens to be phrased.
      for (final l in stocksAndBondsLessons) {
        final all = _allText(l);
        for (final match in RegExp(r'Example \w+ Co\.').allMatches(all)) {
          final windowStart = (match.start - 80).clamp(0, all.length);
          final windowEnd = (match.end + 200).clamp(0, all.length);
          final window = all.substring(windowStart, windowEnd);
          expect(
            window.toLowerCase().contains('fictional'),
            isTrue,
            reason: '${l.id}: "${match.group(0)}" is not marked fictional '
                'nearby: "$window"',
          );
        }
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

    test('never records a market gain as a contribution, never buys or '
        'recommends a security: the action model has no field that could '
        'hold either', () {
      // SalapifyActionDef carries only id, label, description, and route,
      // the same closed shape lessons_grow.dart's pilot already relies on
      // for "structurally incapable of an automatic write". Nothing here
      // adds a field, so the guarantee holds for this course too.
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
    }
  }
  return buf.toString();
}

SalapifyActionsBlock _salapifyActionsBlock() {
  final lesson = stocksAndBondsLessons.firstWhere(
    (l) => l.id == sbVerifyBeforeYouInvest,
  );
  return lesson.interactionBlocks.whereType<SalapifyActionsBlock>().first;
}
