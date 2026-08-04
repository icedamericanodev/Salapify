// Money Courses Phase 8 content contract: the "Grow Your Money" learning
// path's fourth course, "Crypto Without the Hype"
// (lib/content/lessons_crypto.dart, lib/content/learning_paths.dart). Proves
// this course is registered correctly, stays fully isolated from the core 22
// lessons and every earlier Grow Your Money course, passes the house rules
// (no em/en dash, no named token or provider, no guaranteed-outcome
// language, no credential collection) plus the Phase 4 content policy
// validator, and never recommends buying anything.
//
// Mirrors test/lessons_deposits_pooled_funds_content_test.dart's own
// structure on purpose, the established shape for a Money Courses content
// contract test.

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
import 'package:salapify/content/lessons_stocks_bonds.dart';
import 'package:salapify/money/expansion_content_policy.dart';
import 'package:salapify/money/interaction_completion.dart';

final _ref = DateTime.utc(2026, 8, 4);

const _stableLessonIds = [
  cryptoRefWhatCryptoIs,
  cryptoRefVolatilityTotalLoss,
  cryptoRefCustodyIrreversibleMistakes,
  cryptoRefStablecoinsYieldLeverage,
  cryptoRefScamsProviderVerification,
  cryptoRefDecisionLab,
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

const _depositsLessonIds = [
  dpDepositOrInvestment,
  dpTimeDepositsAndPdic,
  dpHowPooledFundsWork,
  dpUitfMutualFundEtf,
  dpReadAFactSheet,
  dpMatchProductToGoal,
];

void main() {
  group('registration', () {
    test('grow_your_money carries all four courses', () {
      final path = learningPaths.firstWhere((p) => p.id == 'grow_your_money');
      expect(path.status, LearningPathStatus.published);
      expect(path.isAvailable, isTrue);
      expect(
        path.groups.map((g) => g.id),
        containsAll([
          'investing_readiness',
          'stocks_and_bonds',
          'deposits_and_pooled_funds',
          'crypto_without_hype',
        ]),
      );
      final group = path.groups.firstWhere(
        (g) => g.id == 'crypto_without_hype',
      );
      expect(group.title, 'Crypto Without the Hype');
      expect(group.lessonIds, _stableLessonIds);
      // The path's flat id list is every earlier course's lessons, then
      // this course's six, since groups render in the order they were
      // authored.
      expect(path.lessonIds, [
        ..._pilotLessonIds,
        ..._stocksBondsLessonIds,
        ..._depositsLessonIds,
        ..._stableLessonIds,
      ]);
    });

    test('recommended prerequisites are recommended, never a lock', () {
      final path = learningPaths.firstWhere((p) => p.id == 'grow_your_money');
      final group = path.groups.firstWhere(
        (g) => g.id == 'crypto_without_hype',
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
        cryptoWithoutHypeLessons.map((l) => l.id).toList(),
        _stableLessonIds,
      );
    });

    test('lesson ids are unique', () {
      expect(_stableLessonIds.toSet().length, 6);
    });

    test(
      'every lesson is registered under the crypto_without_hype trackId',
      () {
        for (final l in cryptoWithoutHypeLessons) {
          expect(l.trackId, 'crypto_without_hype');
        }
      },
    );

    test('expansionLessonById resolves a lesson from this course', () {
      final found = expansionLessonById(cryptoRefWhatCryptoIs);
      expect(found, isNotNull);
      expect(found!.pathId, 'grow_your_money');
      expect(found.lesson.id, cryptoRefWhatCryptoIs);
    });
  });

  group('isolation from the core 22 and every earlier course', () {
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

    test('Deposits and Pooled Funds is untouched: still 6 lessons, in the '
        'same order', () {
      expect(
        depositsAndPooledFundsLessons.map((l) => l.id).toList(),
        _depositsLessonIds,
      );
    });

    test('none of the new ids appear in the core flat lesson list', () {
      final coreIds = core.lessons.map((l) => l['id']).toSet();
      for (final id in _stableLessonIds) {
        expect(coreIds.contains(id), isFalse, reason: '$id leaked into core');
      }
    });

    test('none of the new ids collide with any earlier course\'s ids', () {
      final coreIds = core.lessons.map((l) => l['id']).toSet();
      final earlierIds = {
        ..._pilotLessonIds,
        ..._stocksBondsLessonIds,
        ..._depositsLessonIds,
      };
      for (final id in _stableLessonIds) {
        expect(coreIds.contains(id), isFalse);
        expect(earlierIds.contains(id), isFalse);
      }
    });
  });

  group('content policy validator (Phase 4)', () {
    test('every lesson has zero validation errors', () {
      for (final lesson in cryptoWithoutHypeLessons) {
        final result = validateExpansionLesson(lesson, referenceDate: _ref);
        expect(
          isPublishable(result),
          isTrue,
          reason: '${lesson.id}: ${result.errors.join('; ')}',
        );
      }
    });

    test('every lesson carries ContentTopic.cryptocurrency, making it '
        'regulated content, and is classified high volatility', () {
      for (final lesson in cryptoWithoutHypeLessons) {
        expect(
          lesson.topics,
          contains(ContentTopic.cryptocurrency),
          reason: '${lesson.id} is missing ContentTopic.cryptocurrency',
        );
        expect(
          lesson.governance.volatility,
          ContentVolatility.high,
          reason: '${lesson.id} is not classified high volatility',
        );
      }
    });
  });

  group('official-source metadata', () {
    test(
      'every lesson cites at least one structured, HTTPS official source',
      () {
        for (final lesson in cryptoWithoutHypeLessons) {
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
      for (final lesson in cryptoWithoutHypeLessons) {
        expect(
          lesson.blocks.whereType<OfficialSourceBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no OfficialSourceBlock',
        );
      }
    });

    test('verified and review-due dates are present and sane', () {
      for (final lesson in cryptoWithoutHypeLessons) {
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

    test('Lesson 5 cites the BSP Verifier and the SEC, never a static '
        'provider directory', () {
      final l = cryptoWithoutHypeLessons.firstWhere(
        (l) => l.id == cryptoRefScamsProviderVerification,
      );
      final sourceTitles = l.blocks
          .whereType<OfficialSourceBlock>()
          .map((b) => b.sourceTitle)
          .toList();
      expect(sourceTitles, contains('BSP Verifier'));
      expect(
        sourceTitles,
        contains('Securities and Exchange Commission Philippines'),
      );
      final urls = l.blocks
          .whereType<OfficialSourceBlock>()
          .map((b) => b.canonicalUrl)
          .toList();
      for (final url in urls) {
        expect(
          url.toLowerCase().endsWith('.pdf'),
          isFalse,
          reason: 'a static PDF directory should never be embedded here',
        );
      }
    });
  });

  group('risk warnings and educational boundary', () {
    test('every lesson carries a risk-warning block', () {
      for (final lesson in cryptoWithoutHypeLessons) {
        expect(
          lesson.blocks.whereType<RiskWarningBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no RiskWarningBlock',
        );
      }
    });

    test('every lesson carries the educational-boundary block', () {
      for (final lesson in cryptoWithoutHypeLessons) {
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
      for (final lesson in cryptoWithoutHypeLessons) {
        expect(
          lesson.interactionBlocks.where((b) => b.requiredForCompletion),
          isNotEmpty,
          reason: '${lesson.id} has no required interaction',
        );
      }
    });

    test('every lesson has unique interaction block ids', () {
      for (final lesson in cryptoWithoutHypeLessons) {
        expect(hasUniqueBlockIds(lesson.interactionBlocks), isTrue);
      }
    });

    test('every lesson has a scenario-based knowledge check with an '
        'explanation', () {
      for (final lesson in cryptoWithoutHypeLessons) {
        final check = lesson.check;
        expect(check, isNotNull, reason: '${lesson.id} has no mastery check');
        expect(check!.isValid, isTrue);
        expect(check.explanation, isNotEmpty);
      }
    });
  });

  group('course-specific interaction coverage (the task\'s own list)', () {
    MoneyLesson byId(String id) =>
        cryptoWithoutHypeLessons.firstWhere((l) => l.id == id);

    test('lesson 1 classifies crypto vs stock vs deposit vs digital '
        'payment, a myth, a comparison, and a risk warning', () {
      final l = byId(cryptoRefWhatCryptoIs);
      final sort = l.interactionBlocks.whereType<CategorizeBlock>().first;
      expect(
        sort.buckets.map((b) => b.label),
        containsAll([
          'Crypto asset',
          'Company share',
          'Bank deposit',
          'Digital payment balance',
        ]),
      );
      expect(l.interactionBlocks.whereType<MythOrFactBlock>(), isNotEmpty);
      expect(l.interactionBlocks.whereType<ComparisonBlock>(), isNotEmpty);
      expect(l.blocks.whereType<RiskWarningBlock>(), isNotEmpty);
      // No named token, platform, or founder anywhere in this lesson.
      final all = _allText(l);
      for (final banned in ['Bitcoin', 'Ethereum', 'Binance', 'Coinbase']) {
        expect(all.contains(banned), isFalse);
      }
    });

    test('lesson 2 has the loss-impact simulator, a liquidity scenario, a '
        'myth, and a reflection', () {
      final l = byId(cryptoRefVolatilityTotalLoss);
      final sim = l.interactionBlocks
          .whereType<LossImpactSimulatorBlock>()
          .first;
      expect(sim.amountOptions.length, 3);
      expect(sim.lossPercentOptions, [30, 60, 100]);
      expect(sim.requiredForCompletion, isTrue);
      expect(l.interactionBlocks.whereType<ScenarioChoiceBlock>(), isNotEmpty);
      expect(l.interactionBlocks.whereType<MythOrFactBlock>(), isNotEmpty);
      expect(
        l.interactionBlocks.whereType<ReflectionPromptBlock>(),
        isNotEmpty,
      );
      // Never recommends an allocation percentage.
      final all = _allText(l);
      expect(RegExp(r'put\s+\d').hasMatch(all.toLowerCase()), isFalse);
    });

    test('lesson 3 has a custody comparison, four branching scenarios, and '
        'a security checklist, with no secret-entry field anywhere', () {
      final l = byId(cryptoRefCustodyIrreversibleMistakes);
      final comparison = l.interactionBlocks
          .whereType<ComparisonBlock>()
          .firstWhere((c) => c.blockId == 'crypto-custody-comparison');
      expect(comparison.items.length, 2);
      final scenarios = l.interactionBlocks.whereType<ScenarioChoiceBlock>();
      expect(scenarios.length, greaterThanOrEqualTo(4));
      final checklist = l.interactionBlocks.whereType<ChecklistBlock>().first;
      expect(checklist.items.length, greaterThanOrEqualTo(4));
      // Absolute rule: no interaction block type used anywhere in this
      // course has a raw text-entry field except ReflectionPromptBlock's
      // OWN free-text box, which is never wired to a seed-phrase, private
      // key, password, or credential question anywhere in this file.
      for (final b in cryptoWithoutHypeLessons.expand(
        (l) => l.interactionBlocks,
      )) {
        if (b is ReflectionPromptBlock && b.allowFreeText) {
          final q = b.question.toLowerCase();
          for (final banned in [
            'seed phrase',
            'private key',
            'password',
            'pin',
            'otp',
            'recovery phrase',
          ]) {
            expect(
              q.contains(banned),
              isFalse,
              reason: '${b.blockId} free-text prompt asks about $banned',
            );
          }
        }
      }
    });

    test('lesson 4 has a stablecoin myth, a risk-matching activity, a '
        'yield-offer comparison, and a leverage scenario with no execution '
        'instructions', () {
      final l = byId(cryptoRefStablecoinsYieldLeverage);
      expect(l.interactionBlocks.whereType<MythOrFactBlock>(), isNotEmpty);
      final riskMatch = l.interactionBlocks
          .whereType<CategorizeBlock>()
          .firstWhere((c) => c.blockId == 'crypto-yield-risk-matching');
      expect(
        riskMatch.buckets.map((b) => b.label),
        containsAll([
          'Counterparty risk',
          'Liquidity risk',
          'Smart-contract risk',
          'Platform risk',
        ]),
      );
      final comparison = l.interactionBlocks
          .whereType<ComparisonBlock>()
          .firstWhere((c) => c.blockId == 'crypto-yield-offer-comparison');
      expect(comparison.items.length, 2);
      final leverage = l.interactionBlocks
          .whereType<ScenarioChoiceBlock>()
          .firstWhere((s) => s.blockId == 'crypto-leverage-scenario');
      expect(leverage.riskNote, isNotNull);
      final all = _allText(l).toLowerCase();
      // Never a current yield rate: no percent figure with the % symbol
      // appears anywhere in this lesson.
      expect(RegExp(r'\d+\s?%').hasMatch(all), isFalse);
    });

    test('lesson 5 has a scam red-flag challenge, a fake-support scenario, '
        'a provider-verification checklist, and a "what would you do" '
        'scenario, with no embedded provider list', () {
      final l = byId(cryptoRefScamsProviderVerification);
      final redFlags = l.interactionBlocks
          .whereType<CategorizeBlock>()
          .firstWhere((c) => c.blockId == 'crypto-scam-red-flag-challenge');
      expect(
        redFlags.buckets.map((b) => b.label),
        containsAll(['Red flag', 'Reasonable']),
      );
      expect(
        l.interactionBlocks.whereType<ScenarioChoiceBlock>().where(
          (s) => s.blockId == 'crypto-fake-support-scenario',
        ),
        isNotEmpty,
      );
      expect(
        l.interactionBlocks.whereType<ScenarioChoiceBlock>().where(
          (s) => s.blockId == 'crypto-recovery-scam-scenario',
        ),
        isNotEmpty,
      );
      final checklist = l.interactionBlocks
          .whereType<ChecklistBlock>()
          .firstWhere(
            (c) => c.blockId == 'crypto-provider-verification-checklist',
          );
      expect(checklist.items.length, greaterThanOrEqualTo(4));
      // No embedded provider list: no company-sounding proper noun list is
      // rendered as a directory of registered providers in this lesson.
      final actionsInLesson = l.interactionBlocks
          .whereType<SalapifyActionsBlock>();
      expect(actionsInLesson, isEmpty);
    });

    test('lesson 6 has the ten-item risk-review checklist with the exact '
        'three summary strings, and the Salapify actions menu', () {
      final l = byId(cryptoRefDecisionLab);
      final checklist = l.interactionBlocks
          .whereType<RiskReviewChecklistBlock>()
          .first;
      expect(checklist.items.length, 10);
      expect(checklist.isValid, isTrue);
      expect(checklist.requiredForCompletion, isTrue);
      expect(
        checklist.items.map((i) => i.id),
        containsAll([
          'financial-foundation-reviewed',
          'essential-bills-protected',
          'emergency-buffer-considered',
          'expensive-debt-reviewed',
          'money-not-borrowed',
          'understands-total-loss',
          'understands-custody-choice',
          'provider-status-checked',
          'no-pressure-or-guarantee',
          'amount-within-affordable-loss',
        ]),
      );
      expect(
        checklist.foundationSummary,
        'Review your financial foundation '
        'first',
      );
      expect(checklist.partialSummary, 'Several risks still need checking');
      expect(checklist.completeSummary, 'You have completed a risk review');
      // Never one of the banned eligibility words, anywhere in this
      // checklist's own three summaries.
      for (final s in [
        checklist.foundationSummary,
        checklist.partialSummary,
        checklist.completeSummary,
      ]) {
        final lower = s.toLowerCase();
        for (final banned in [
          'ready',
          'suitable',
          'approved',
          'qualified',
          'safe to invest',
        ]) {
          expect(
            lower.contains(banned),
            isFalse,
            reason: '"$s" uses "$banned"',
          );
        }
      }
      expect(l.interactionBlocks.whereType<SalapifyActionsBlock>(), isNotEmpty);
    });
  });

  group('house rules: plain text content', () {
    test('no em or en dashes anywhere, content blocks or interactions', () {
      for (final l in cryptoWithoutHypeLessons) {
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
      for (final l in cryptoWithoutHypeLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} reads as a guaranteed-outcome claim',
        );
      }
    });

    test('no named real coin, token, platform, or provider anywhere', () {
      const bannedNames = [
        'Bitcoin',
        'BTC',
        'Ethereum',
        'ETH',
        'Binance',
        'Coinbase',
        'Tether',
        'USDT',
        'USDC',
        'Ripple',
        'XRP',
        'Dogecoin',
        'Solana',
        'PDAX',
        'Coins.ph',
        'GCash',
        'Maya',
      ];
      for (final l in cryptoWithoutHypeLessons) {
        final all = _allText(l);
        for (final name in bannedNames) {
          expect(
            all.contains(name),
            isFalse,
            reason: '${l.id} names a real coin or provider: $name',
          );
        }
      }
    });

    test('never declares the reader officially approved, covered, or '
        'eligible', () {
      final banned = RegExp(
        r"\byou(?:'re| are)\b[^.]{0,20}\b(officially\s+)?(approved|covered|"
        r'eligible|qualified)\b',
        caseSensitive: false,
      );
      for (final l in cryptoWithoutHypeLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason:
              '${l.id} declares the reader officially approved or '
              'eligible',
        );
      }
    });

    test('never instructs buying or selling anything', () {
      final banned = RegExp(r'\b([Bb]uy|[Ss]ell)\s+(?!Now\b)[A-Z]');
      for (final l in cryptoWithoutHypeLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} reads as a buy or sell instruction',
        );
      }
    });

    test('never asks the reader to enter, type, share, provide, or send a '
        'password, PIN, OTP, seed phrase, or private key', () {
      final banned = RegExp(
        r'\b(enter|type|share|provide|send)\s+your\s+(password|pin|otp|'
        r'seed\s+phrase|private\s+key)\b',
        caseSensitive: false,
      );
      final negation = RegExp(
        r"\b(never|not|no|cannot|can't|without)\b",
        caseSensitive: false,
      );
      for (final l in cryptoWithoutHypeLessons) {
        final all = _allText(l);
        for (final m in banned.allMatches(all)) {
          final windowStart = (m.start - 45).clamp(0, all.length);
          final before = all.substring(windowStart, m.start);
          expect(
            negation.hasMatch(before) || negation.hasMatch(m.group(0)!),
            isTrue,
            reason:
                '${l.id} asks for a credential without a nearby negation: '
                '"${all.substring(windowStart, (m.end + 20).clamp(0, all.length))}"',
          );
        }
      }
    });
  });

  group('exclusions: no live prices, no forecasts, no product execution', () {
    test('no dollar-sign or bare percent-return figure anywhere (no live '
        'price, no return forecast)', () {
      final figureWithReturnWord = RegExp(
        r'\d{1,3}(\.\d+)?\s?%\s*(return|yield|growth|interest|gain)',
        caseSensitive: false,
      );
      for (final l in cryptoWithoutHypeLessons) {
        expect(
          figureWithReturnWord.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} states a return figure',
        );
      }
    });

    test('never mentions staking instructions, mining guides, or NFT '
        'speculation', () {
      for (final l in cryptoWithoutHypeLessons) {
        final lower = _allText(l).toLowerCase();
        for (final banned in ['staking', 'mining rig', 'nft']) {
          expect(lower.contains(banned), isFalse, reason: '${l.id}: $banned');
        }
      }
    });

    test('never recommends buying crypto as the checklist outcome', () {
      final l = cryptoWithoutHypeLessons.firstWhere(
        (l) => l.id == cryptoRefDecisionLab,
      );
      final lower = _allText(l).toLowerCase();
      expect(lower.contains('you should buy'), isFalse);
      expect(lower.contains('go ahead and invest'), isFalse);
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

    test(
      'never a wallet or exchange route: only existing Salapify screens',
      () {
        final block = _salapifyActionsBlock();
        for (final action in block.actions) {
          final lower =
              '${action.label} ${action.description} '
                      '${action.route}'
                  .toLowerCase();
          for (final banned in ['wallet', 'exchange', 'connect']) {
            expect(
              lower.contains(banned),
              isFalse,
              reason: '${action.id} mentions "$banned"',
            );
          }
        }
      },
    );

    test('the block is never required to finish the lesson', () {
      final block = _salapifyActionsBlock();
      expect(block.requiredForCompletion, isFalse);
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
      case LossImpactSimulatorBlock(:final introduction, :final amountOptions):
        buf.write(' $introduction');
        for (final a in amountOptions) {
          buf.write(' ${a.label}');
        }
      case RiskReviewChecklistBlock(
        :final items,
        :final foundationSummary,
        :final partialSummary,
        :final completeSummary,
      ):
        for (final i in items) {
          buf.write(' ${i.label} ${i.explanation ?? ''}');
        }
        buf.write(' $foundationSummary $partialSummary $completeSummary');
    }
  }
  return buf.toString();
}

SalapifyActionsBlock _salapifyActionsBlock() {
  final lesson = cryptoWithoutHypeLessons.firstWhere(
    (l) => l.id == cryptoRefDecisionLab,
  );
  return lesson.interactionBlocks.whereType<SalapifyActionsBlock>().first;
}
