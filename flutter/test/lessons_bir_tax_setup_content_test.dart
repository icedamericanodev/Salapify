// "Build Your Business" learning path's THIRD course content contract,
// "BIR Setup for New Businesses" (lib/content/lessons_bir_tax_setup.dart).
// Focused tests per the phase's own 17-item list: registration, exact
// lesson count and order, stable/unique ids, core count, expansion progress
// isolation (this course and its Phase 13 sibling), official-source
// metadata, high-volatility review dates, official bir.gov.ph domain-only
// sources with lookalike-domain rejection, no current rate/threshold/
// deadline/penalty/form-table anywhere, no tax calculation or regime
// recommendation or deductibility decision, no sensitive-data input, the
// registration-sequence and filing-routine interactions, deep-link routes,
// and the existing content-policy validator. Mirrors
// test/lessons_bir_local_permits_content_test.dart's own structure, the
// established shape for a Money Courses content contract test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/learning_paths.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons.dart' as core;
import 'package:salapify/content/lessons_bir_local_permits.dart';
import 'package:salapify/content/lessons_bir_tax_setup.dart';
import 'package:salapify/content/lessons_business_registration.dart';
import 'package:salapify/money/expansion_content_policy.dart';
import 'package:salapify/money/expansion_progress.dart';
import 'package:salapify/money/lesson_progress.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/interaction_block_views.dart';

import 'screens_shot.dart' show loadRealFonts;

final _ref = DateTime.utc(2026, 8, 5);

const _stableLessonIds = [
  btaxStartWithProfile,
  btaxPrimarySecondary,
  btaxKnowWhatYouRegisteredFor,
  btaxInvoicesBooksProof,
  btaxFilingRoutine,
  btaxMoneySystem,
];

const _officialUrls = {
  'https://www.bir.gov.ph/',
  'https://www.bir.gov.ph/EOPT',
  'https://www.bir.gov.ph/registration-requirements-details',
  'https://www.bir.gov.ph/primary-registration',
  'https://www.bir.gov.ph/secondary-registration',
  'https://web-services.bir.gov.ph/newbizreg/',
  'https://orus.bir.gov.ph/home',
  'https://www.bir.gov.ph/tax-reminder',
};

void main() {
  // ---- 1, 2, 3: registration, exact lesson order, stable and unique ids
  group('registration', () {
    test('1: bir_registration_tax_setup exists under build_your_business', () {
      final path = learningPaths.firstWhere(
        (p) => p.id == 'build_your_business',
      );
      final group = path.groups.firstWhere(
        (g) => g.id == 'bir_registration_tax_setup',
      );
      expect(group.title, 'BIR Setup for New Businesses');
    });

    test('2: exactly six lessons, in the required order', () {
      expect(
        birRegistrationTaxSetupLessons.map((l) => l.id).toList(),
        _stableLessonIds,
      );
    });

    test('3: lesson ids are stable and unique', () {
      expect(_stableLessonIds.toSet().length, 6);
      expect(_stableLessonIds.contains('bir_registration_tax_setup'), isFalse);
    });

    test('expansionLessonById resolves a lesson from this course to '
        'build_your_business', () {
      final found = expansionLessonById(btaxStartWithProfile);
      expect(found, isNotNull);
      expect(found!.pathId, 'build_your_business');
    });
  });

  // ---- 4: core count remains 22
  group('4: core count remains 22', () {
    test('core lessons and course tracks are unchanged', () {
      expect(core.lessons.length, 22);
      expect(core.courseTracks.length, 4);
    });

    test('none of the new ids leaked into the core flat lesson list', () {
      final coreIds = core.lessons.map((l) => l['id']).toSet();
      for (final id in _stableLessonIds) {
        expect(coreIds.contains(id), isFalse);
      }
    });

    test('none of the new ids collide with either sibling course', () {
      final siblingIds = {
        ...startABusinessLegallyLessons.map((l) => l.id),
        ...birRegistrationAndLocalPermitsLessons.map((l) => l.id),
      };
      for (final id in _stableLessonIds) {
        expect(siblingIds.contains(id), isFalse);
      }
    });
  });

  // ---- 5, 6: expansion progress separate; Phase 13 progress unchanged
  group('5 and 6: expansion progress stays separate, and Phase 13 progress '
      'is unchanged', () {
    test('writing progress for this course never touches an unrelated '
        'entry, including its sibling courses', () {
      final existing = {
        'build_your_business': {
          brBeforeYouRegister: {'state': 'completed'},
          birlOrderThatMatters: {'state': 'completed'},
        },
      };
      final out = withExpansionLessonState(
        existing,
        'build_your_business',
        btaxStartWithProfile,
        LessonState.completed,
      );
      final parsed = parseExpansionProgress(out);
      expect(
        parsed['build_your_business']?[brBeforeYouRegister],
        LessonState.completed,
        reason: 'Phase 13 progress must survive untouched',
      );
      expect(
        parsed['build_your_business']?[birlOrderThatMatters],
        LessonState.completed,
        reason: 'Phase 14 progress must survive untouched',
      );
      expect(
        parsed['build_your_business']?[btaxStartWithProfile],
        LessonState.completed,
      );
    });

    test('pathProgressFor counts across all three courses in the '
        'flattened path total', () {
      final progress = parseExpansionProgress({
        'build_your_business': {
          brBeforeYouRegister: {'state': 'completed'},
          btaxStartWithProfile: {'state': 'completed'},
        },
      });
      final allIds = [
        ...startABusinessLegallyLessons.map((l) => l.id),
        ...birRegistrationAndLocalPermitsLessons.map((l) => l.id),
        ..._stableLessonIds,
      ];
      final pp = pathProgressFor(
        pathId: 'build_your_business',
        lessonIds: allIds,
        progress: progress['build_your_business'] ?? const {},
      );
      expect(pp.total, 18);
      expect(pp.done, 2);
    });
  });

  // ---- 7, 8: official-source metadata; verification/review-due dates
  group('7 and 8: official-source metadata and review dates', () {
    test('every lesson cites at least one structured, HTTPS official '
        'source', () {
      for (final lesson in birRegistrationTaxSetupLessons) {
        expect(lesson.sources, isNotEmpty, reason: lesson.id);
        for (final s in lesson.sources) {
          final uri = Uri.tryParse(s.canonicalUrl);
          expect(uri != null && uri.scheme == 'https', isTrue);
          expect(s.agency, isNotEmpty);
          expect(s.title, isNotEmpty);
        }
      }
    });

    test('every lesson renders an OfficialSourceBlock', () {
      for (final lesson in birRegistrationTaxSetupLessons) {
        expect(
          lesson.blocks.whereType<OfficialSourceBlock>(),
          isNotEmpty,
          reason: lesson.id,
        );
      }
    });

    test('every high-volatility lesson carries a verification date and a '
        'review-due date after it', () {
      for (final lesson in birRegistrationTaxSetupLessons) {
        expect(lesson.governance.volatility, ContentVolatility.high);
        final g = lesson.governance;
        expect(g.lastVerifiedDate, isNotNull);
        expect(g.reviewDueDate, isNotNull);
        final verified = parseGovernanceDate(g.lastVerifiedDate!);
        final due = parseGovernanceDate(g.reviewDueDate!);
        expect(due!.isAfter(verified!), isTrue);
      }
    });
  });

  // ---- 9, 10: official domain only, lookalike domains rejected
  group('9 and 10: only official bir.gov.ph sources, lookalikes rejected', () {
    test('every source URL host is bir.gov.ph or an official subdomain', () {
      const allowedHosts = {
        'www.bir.gov.ph',
        'web-services.bir.gov.ph',
        'orus.bir.gov.ph',
      };
      for (final lesson in birRegistrationTaxSetupLessons) {
        for (final s in lesson.sources) {
          final host = Uri.parse(s.canonicalUrl).host;
          expect(
            allowedHosts.contains(host),
            isTrue,
            reason: '${lesson.id}: unexpected host $host',
          );
        }
      }
    });

    test('every source is one of the eight named official pages', () {
      for (final lesson in birRegistrationTaxSetupLessons) {
        for (final s in lesson.sources) {
          expect(
            _officialUrls.contains(s.canonicalUrl),
            isTrue,
            reason: s.canonicalUrl,
          );
        }
      }
    });

    test('every named official page is cited by at least one lesson', () {
      final cited = {
        for (final l in birRegistrationTaxSetupLessons)
          for (final s in l.sources) s.canonicalUrl,
      };
      expect(cited, _officialUrls);
    });

    test('no lookalike domain (orus.ph, or anything off bir.gov.ph) '
        'appears anywhere in this course\'s text', () {
      final banned = RegExp(
        r'\borus\.ph\b|\bbir-gov\.ph\b|\bbirgov\.ph\b',
        caseSensitive: false,
      );
      for (final l in birRegistrationTaxSetupLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });
  });

  // ---- 11: no current rate, threshold, deadline, penalty, or form table
  group('11: no current rate, threshold, deadline, penalty, or complete '
      'form table anywhere', () {
    test('no percentage or peso figure anywhere in this course', () {
      final banned = RegExp(
        r'\d+(\.\d+)?\s?%|(₱|php)\s?\d',
        caseSensitive: false,
      );
      for (final l in birRegistrationTaxSetupLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });

    test('no deadline, processing-time, or period word paired with a '
        'number anywhere', () {
      final banned = RegExp(
        r'\d+\s?(day|days|business day|business days|week|weeks|month|'
        r'months|year|years)\b',
        caseSensitive: false,
      );
      for (final l in birRegistrationTaxSetupLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });

    test('no BIR form number appears anywhere', () {
      final banned = RegExp(r'\bBIR Form \d|\bForm \d{4}\b');
      for (final l in birRegistrationTaxSetupLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });
  });

  // ---- 12: no tax calculation, regime recommendation, or deductibility
  group('12: no tax calculation, tax-regime recommendation, or '
      'deductibility decision', () {
    test('never recommends VAT vs non-VAT, graduated vs flat rate, or a '
        'tax regime', () {
      final banned = RegExp(
        r'\b(VAT registration|the (8%|graduated) (option|rate)) is (the '
        r'best|better|recommended)\b',
        caseSensitive: false,
      );
      for (final l in birRegistrationTaxSetupLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });

    test('the record-sorting lesson never declares an expense '
        'deductible outright, and its own hedge is actually present', () {
      // Directional, not blanket: this lesson's own item explanation
      // correctly says "whether it is deductible still depends on current
      // rules", which contains the words "is deductible" precisely
      // because it is hedging, not declaring. A bare match on "is
      // deductible" would flag that correct sentence as if it were the
      // defect it is guarding against, so this checks for the AFFIRMATIVE
      // shape only, and separately proves the correct hedge is present.
      final l = birRegistrationTaxSetupLessons.firstWhere(
        (x) => x.id == btaxInvoicesBooksProof,
      );
      final text = _allText(l).toLowerCase();
      expect(
        text.contains(
          'whether it is deductible still depends on current '
          'rules',
        ),
        isTrue,
        reason: 'the hedge itself must actually be present',
      );
      final banned = RegExp(
        r'\bthis (expense|record) is (tax )?deductible\b|'
        r'\bdefinitely (tax )?deductible\b|\bqualifies as a deduction\b',
        caseSensitive: false,
      );
      expect(banned.hasMatch(text), isFalse);
    });

    test('never guarantees BIR approval or promises a filing is complete '
        'without confirmation', () {
      final banned = RegExp(
        r'\bguaranteed to be approved\b|\byour filing is complete\b|'
        r'\bapproved instantly\b',
        caseSensitive: false,
      );
      for (final l in birRegistrationTaxSetupLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });
  });

  // ---- 13: no sensitive-data input
  group('13: no sensitive-data input exists', () {
    test('no interaction carries a free-text field', () {
      for (final l in birRegistrationTaxSetupLessons) {
        for (final b in l.interactionBlocks) {
          if (b is ReflectionPromptBlock) {
            expect(b.allowFreeText, isFalse, reason: l.id);
          }
        }
      }
    });

    test('no TIN, RDO, address, birth date, income, or credential word '
        'ever asks for a real value', () {
      final banned = RegExp(
        r'\benter your TIN\b|\btype your TIN\b|\byour real TIN\b|'
        r'\bRDO number\b|\bhome address\b|\bbirth date\b|\bdate of '
        r'birth\b|\byour gross sales\b|\byour income\b|\bpassword\b|'
        r'\bOTP\b|\bportal credentials\b',
        caseSensitive: false,
      );
      for (final l in birRegistrationTaxSetupLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });
  });

  // ---- 14: registration-sequence interaction works
  group('14: at least one registration-sequence interaction works', () {
    test('lesson 2\'s sorting interaction covers the seven registration '
        'steps', () {
      final l = birRegistrationTaxSetupLessons.firstWhere(
        (x) => x.id == btaxPrimarySecondary,
      );
      final sorting = l.interactionBlocks.whereType<SortingBlock>().first;
      expect(sorting.items.length, 7);
    });

    testWidgets('lesson 1\'s profile-matching CategorizeBlock renders and '
        'completes', (tester) async {
      final l = birRegistrationTaxSetupLessons.firstWhere(
        (x) => x.id == btaxStartWithProfile,
      );
      final block = l.interactionBlocks.whereType<CategorizeBlock>().first;
      final completed = <String>[];
      await loadRealFonts(tester);
      tester.view.physicalSize = const Size(390, 4200) * 3.0;
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
    });
  });

  // ---- 15: filing-routine interaction works
  group('15: at least one filing-routine interaction works', () {
    test('lesson 5\'s readiness checklist covers all seven generic '
        'labels', () {
      final l = birRegistrationTaxSetupLessons.firstWhere(
        (x) => x.id == btaxFilingRoutine,
      );
      final checklist = l.interactionBlocks.whereType<ChecklistBlock>().first;
      expect(checklist.items.length, 7);
      expect(checklist.items.map((i) => i.label), [
        'Obligation identified',
        'Official deadline checked',
        'Records prepared',
        'Return reviewed',
        'Filing confirmed',
        'Payment confirmed when applicable',
        'Proof stored securely',
      ]);
    });
  });

  // ---- 16: Salapify deep links resolve to existing routes
  group('16: Salapify deep links resolve to existing routes', () {
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
      for (final l in birRegistrationTaxSetupLessons) {
        for (final block
            in l.interactionBlocks.whereType<SalapifyActionsBlock>()) {
          for (final action in block.actions) {
            expect(
              knownRoutes.contains(action.route),
              isTrue,
              reason: action.route,
            );
            expect(action.description, isNotEmpty);
          }
        }
      }
    });

    test('lesson 6 offers goals, budget, recurring, and notifications '
        'only, never an automatic write', () {
      final l = birRegistrationTaxSetupLessons.firstWhere(
        (x) => x.id == btaxMoneySystem,
      );
      final block = l.interactionBlocks.whereType<SalapifyActionsBlock>().first;
      expect(block.actions.map((a) => a.route).toSet(), {
        'goals',
        'budget',
        'recurring',
        'notifications',
      });
    });
  });

  // ---- 17: existing content-validator tests pass
  group('17: the existing content-policy validator passes for the whole '
      'course', () {
    test('isPublishable is true for every lesson', () {
      for (final lesson in birRegistrationTaxSetupLessons) {
        final result = validateExpansionLesson(lesson, referenceDate: _ref);
        expect(
          isPublishable(result),
          isTrue,
          reason: '${lesson.id}: ${result.errors.join('; ')}',
        );
      }
    });

    test('every lesson carries a businessTaxOrPermitCompliance topic', () {
      for (final lesson in birRegistrationTaxSetupLessons) {
        expect(
          lesson.topics,
          contains(ContentTopic.businessTaxOrPermitCompliance),
        );
      }
    });

    test('every lesson carries a risk-warning block and the '
        'educational-boundary block', () {
      for (final lesson in birRegistrationTaxSetupLessons) {
        expect(lesson.blocks.whereType<RiskWarningBlock>(), isNotEmpty);
        expect(lesson.blocks.whereType<EducationalBoundaryBlock>(), isNotEmpty);
      }
    });

    test('every lesson has at least one required interaction and a '
        'scenario-based knowledge check', () {
      for (final lesson in birRegistrationTaxSetupLessons) {
        expect(
          lesson.interactionBlocks.where((b) => b.requiredForCompletion),
          isNotEmpty,
          reason: lesson.id,
        );
        final check = lesson.check;
        expect(check, isNotNull, reason: lesson.id);
        expect(check!.isValid, isTrue);
      }
    });

    test('no em or en dashes anywhere', () {
      for (final l in birRegistrationTaxSetupLessons) {
        final all = _allText(l);
        expect(all.contains('—'), isFalse, reason: '${l.id} em dash');
        expect(all.contains('–'), isFalse, reason: '${l.id} en dash');
      }
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
