// Money Courses Phase 6 pilot content contract: the "Grow Your Money"
// learning path and its "Are You Ready to Invest?" course
// (lib/content/lessons_grow.dart, lib/content/learning_paths.dart). Proves
// this pilot is registered correctly, stays fully isolated from the core 22
// lessons, and passes the house rules (no em/en dash, no product names, no
// guaranteed-outcome language) plus the Phase 4 content policy validator.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/learning_path.dart';
import 'package:salapify/content/learning_paths.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons.dart' as core;
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/money/expansion_content_policy.dart';

final _ref = DateTime.utc(2026, 8, 3);

const _stableLessonIds = [
  investRefMoneyJob,
  investRefProtectBase,
  investRefGoalTimeAccess,
  investRefRiskComfortCapacity,
  investRefCard,
];

// Never rendered by the readiness card or anywhere else in this pilot: see
// content/interaction_blocks.dart's ReadinessCardBlock.resultStyleFor.
const _bannedReadinessLabels = ['Ready', 'Approved', 'Qualified', 'Suitable'];

void main() {
  group('registration', () {
    test(
      'grow_your_money is published with the investing_readiness course',
      () {
        final path = learningPaths.firstWhere((p) => p.id == 'grow_your_money');
        expect(path.status, LearningPathStatus.published);
        expect(path.isAvailable, isTrue);
        expect(path.groups.map((g) => g.id), contains('investing_readiness'));
        // Checked against the investing_readiness GROUP's own lessonIds,
        // not the whole path's flattened list: Phase 7A registered a
        // second course, "Stocks and Bonds Without the Hype", in the same
        // path, so path.lessonIds now has 11 entries. This scopes the
        // check to exactly what this test is named for, the pilot's own
        // five lesson ids, unaffected by any sibling course.
        final investingGroup = path.groups.firstWhere(
          (g) => g.id == 'investing_readiness',
        );
        expect(investingGroup.lessonIds, _stableLessonIds);
      },
    );

    test('publishedLearningPaths shows only Grow Your Money', () {
      expect(publishedLearningPaths.map((p) => p.id), ['grow_your_money']);
    });

    test('no Protect or Business path exists to accidentally render', () {
      expect(learningPaths.any((p) => p.id.contains('protect')), isFalse);
      expect(learningPaths.any((p) => p.id.contains('business')), isFalse);
    });

    test('five stable pilot lesson ids, in reading order', () {
      expect(growYourMoneyLessons.map((l) => l.id).toList(), _stableLessonIds);
    });

    test('lesson ids are unique', () {
      expect(_stableLessonIds.toSet().length, 5);
    });
  });

  group('isolation from the core 22', () {
    test('core lesson list is untouched: still 22 lessons, four courses', () {
      expect(core.lessons.length, 22);
      expect(core.courseTracks.length, 4);
    });

    test('none of the pilot ids appear in the core flat lesson list', () {
      final coreIds = core.lessons.map((l) => l['id']).toSet();
      for (final id in _stableLessonIds) {
        expect(coreIds.contains(id), isFalse, reason: '$id leaked into core');
      }
    });

    test('none of the core ids collide with a pilot id', () {
      final coreIds = core.lessons.map((l) => l['id']).toSet();
      for (final id in _stableLessonIds) {
        expect(coreIds.contains(id), isFalse);
      }
    });
  });

  group('content policy validator (Phase 4)', () {
    test('every pilot lesson has zero validation errors', () {
      for (final lesson in growYourMoneyLessons) {
        final result = validateExpansionLesson(lesson, referenceDate: _ref);
        expect(
          isPublishable(result),
          isTrue,
          reason: '${lesson.id}: ${result.errors.join('; ')}',
        );
      }
    });
  });

  group(
    'official-source metadata (the task requires this on every lesson)',
    () {
      test(
        'every lesson cites at least one structured, HTTPS official source',
        () {
          for (final lesson in growYourMoneyLessons) {
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
        for (final lesson in growYourMoneyLessons) {
          expect(
            lesson.blocks.whereType<OfficialSourceBlock>(),
            isNotEmpty,
            reason: '${lesson.id} has no OfficialSourceBlock',
          );
        }
      });

      test('verified and review-due dates are present and sane', () {
        for (final lesson in growYourMoneyLessons) {
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
    },
  );

  group('risk warnings and educational boundary', () {
    test('every lesson carries a risk-warning block', () {
      for (final lesson in growYourMoneyLessons) {
        expect(
          lesson.blocks.whereType<RiskWarningBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no RiskWarningBlock',
        );
      }
    });

    test('every lesson carries the educational-boundary block', () {
      for (final lesson in growYourMoneyLessons) {
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
      for (final lesson in growYourMoneyLessons) {
        expect(
          lesson.interactionBlocks.where((b) => b.requiredForCompletion),
          isNotEmpty,
          reason: '${lesson.id} has no required interaction',
        );
      }
    });

    test('every lesson has unique interaction block ids', () {
      for (final lesson in growYourMoneyLessons) {
        final ids = lesson.interactionBlocks.map((b) => b.blockId).toList();
        expect(
          ids.toSet().length,
          ids.length,
          reason: '${lesson.id} has duplicate interaction block ids',
        );
      }
    });

    test(
      'every lesson has a scenario-based knowledge check with an explanation',
      () {
        for (final lesson in growYourMoneyLessons) {
          final check = lesson.check;
          expect(check, isNotNull, reason: '${lesson.id} has no mastery check');
          expect(check!.isValid, isTrue);
          expect(check.explanation, isNotEmpty);
        }
      },
    );
  });

  group('house rules: plain text content', () {
    String allText(MoneyLesson l) {
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

    test('no em or en dashes anywhere, content blocks or interactions', () {
      for (final l in growYourMoneyLessons) {
        final all = allText(l);
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
      for (final l in growYourMoneyLessons) {
        expect(
          banned.hasMatch(allText(l)),
          isFalse,
          reason: '${l.id} reads as a guaranteed-outcome claim',
        );
      }
    });

    test('never labels a reader Ready, Approved, Qualified, or Suitable', () {
      for (final l in growYourMoneyLessons) {
        final all = allText(l);
        for (final banned in _bannedReadinessLabels) {
          expect(
            RegExp(
              '\\byou (are|\'re) $banned\\b',
              caseSensitive: false,
            ).hasMatch(all),
            isFalse,
            reason: '${l.id} labels the reader "$banned"',
          );
        }
      }
    });

    test(
      'the readiness card result style is never one of the banned labels',
      () {
        final card = _investmentReadinessCardBlock();
        // Every combination of needsReview counts, worst case (all flagged)
        // to best case (none flagged), to prove the three real result
        // strings, never a banned eligibility word.
        for (final reviewCount in [0, 1, 2, card.fields.length]) {
          final answers = <String, ReadinessCardOption>{};
          var flagged = 0;
          for (final field in card.fields) {
            final needsReview = flagged < reviewCount;
            final option = needsReview
                ? field.options.firstWhere((o) => o.needsReview)
                : field.options.firstWhere((o) => !o.needsReview);
            answers[field.id] = option;
            if (option.needsReview) flagged++;
          }
          final style = ReadinessCardBlock.resultStyleFor(answers);
          expect([
            'Foundation needs attention',
            'Review these areas first',
            'You have defined a starting plan',
          ], contains(style));
          for (final banned in _bannedReadinessLabels) {
            expect(style.contains(banned), isFalse);
          }
        }
      },
    );
  });

  group('Salapify actions: verified routes only, never an automatic write', () {
    test('every action route is a known, pushable Salapify screen', () {
      const knownRoutes = {'goals', 'debts', 'budget'};
      final block = _salapifyActionsBlock();
      for (final action in block.actions) {
        expect(
          knownRoutes.contains(action.route),
          isTrue,
          reason: 'unknown route "${action.route}"',
        );
        // The action carries only a label, a description, and a route
        // string; there is no field here that could hold a store mutation,
        // which is what makes "never creates or modifies a record
        // automatically" true by construction, not just by convention.
        expect(action.description, isNotEmpty);
      }
    });

    test('the four required actions are all present on the pilot', () {
      final block = _salapifyActionsBlock();
      final ids = block.actions.map((a) => a.id).toSet();
      expect(ids, {
        'review-emergency-fund',
        'review-debt',
        'review-budget',
        'create-investment-goal',
      });
    });
  });
}

ReadinessCardBlock _investmentReadinessCardBlock() {
  final lesson = growYourMoneyLessons.firstWhere((l) => l.id == investRefCard);
  return lesson.interactionBlocks.whereType<ReadinessCardBlock>().first;
}

SalapifyActionsBlock _salapifyActionsBlock() {
  final lesson = growYourMoneyLessons.firstWhere((l) => l.id == investRefCard);
  return lesson.interactionBlocks.whereType<SalapifyActionsBlock>().first;
}
