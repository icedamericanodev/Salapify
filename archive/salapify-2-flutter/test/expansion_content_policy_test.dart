// Focused test suite for the Phase 4 expansion content policy validator
// (lib/money/expansion_content_policy.dart). Every lesson here is a fixture
// built for this file, never a real Money Courses lesson: the validator
// applies only to future expansion content, and the existing 22 core
// lessons must never need to satisfy it (see the invariant group at the
// bottom, which proves that directly against the real catalog).

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons.dart';
import 'package:salapify/money/expansion_content_policy.dart';

/// A fixture reference date, deliberately distinct from any date the
/// fixtures below author, so a test that accidentally used the real system
/// clock instead of this value would behave differently and get caught.
final _ref = DateTime.utc(2026, 8, 3);

/// A regulated fixture that satisfies every requirement: one topic, one
/// verified https source, verified governance with sane dates, a risk
/// warning, and an educational boundary. Individual tests copy this and
/// break exactly one thing, so a passing "everything else" is never in
/// doubt.
Map<String, dynamic> _validLessonMap({
  List<dynamic>? topics,
  List<dynamic>? sources,
  Map<String, dynamic>? governance,
  List<dynamic>? blocks,
  List<dynamic>? reviewedMythExamples,
}) => {
  'id': 'grow-uitf-intro',
  'track': 'grow',
  'title': 'What a UITF actually is',
  'icon': 'growth',
  'minutes': 4,
  'summary': 'A UITF pools money from many investors into one fund.',
  'objective':
      'Explain what a UITF is before comparing it to a savings account.',
  'topics': topics ?? ['fundsAndEtfs'],
  'sources':
      sources ??
      [
        {
          'agency': 'Bangko Sentral ng Pilipinas',
          'title': 'Guidelines on Unit Investment Trust Funds',
          'canonicalUrl': 'https://www.bsp.gov.ph/uitf-guidelines',
          'lastVerifiedDate': '2026-06',
        },
      ],
  'governance':
      governance ??
      {
        'volatility': 'annual',
        'reviewStatus': 'verified',
        'lastVerifiedDate': '2026-06',
        'reviewDueDate': '2027-06',
      },
  'blocks':
      blocks ??
      [
        {
          'kind': 'nuggets',
          'items': ['A UITF pools money from many investors into one fund.'],
        },
        {
          'kind': 'riskWarning',
          'title': 'Value can go down',
          'text': 'A UITF unit price moves with the market and can lose value.',
        },
        {
          'kind': 'educationalBoundary',
          'sourceLabel': 'the Bangko Sentral ng Pilipinas',
        },
      ],
  'reviewedMythExamples': reviewedMythExamples ?? const [],
};

ValidationResult _validate(Map<String, dynamic> map) =>
    validateExpansionLesson(lessonFromMap(map), referenceDate: _ref);

bool _hasCode(ValidationResult r, ValidationIssueCode code) =>
    r.issues.any((i) => i.code == code);

void main() {
  group('a fully valid, verified expansion lesson', () {
    test('has no issues and is publishable', () {
      final r = _validate(_validLessonMap());
      expect(r.issues, isEmpty);
      expect(isPublishable(r), isTrue);
    });

    test('accepts multiple official sources', () {
      final r = _validate(
        _validLessonMap(
          sources: [
            {
              'agency': 'Bangko Sentral ng Pilipinas',
              'title': 'Guidelines on Unit Investment Trust Funds',
              'canonicalUrl': 'https://www.bsp.gov.ph/uitf-guidelines',
              'lastVerifiedDate': '2026-06',
            },
            {
              'agency': 'Securities and Exchange Commission',
              'title': 'Investor Protection Guide',
              'canonicalUrl': 'https://www.sec.gov.ph/investor-guide',
            },
          ],
        ),
      );
      expect(r.errors, isEmpty);
      expect(isPublishable(r), isTrue);
    });
  });

  group('source requirements', () {
    test('a regulated lesson with no sources fails', () {
      final r = _validate(_validLessonMap(sources: []));
      expect(_hasCode(r, ValidationIssueCode.missingOfficialSource), isTrue);
      expect(isPublishable(r), isFalse);
    });

    test('a plain HTTP source URL fails', () {
      final r = _validate(
        _validLessonMap(
          sources: [
            {
              'agency': 'BSP',
              'title': 'A circular',
              'canonicalUrl': 'http://www.bsp.gov.ph/circular',
            },
          ],
        ),
      );
      expect(_hasCode(r, ValidationIssueCode.invalidSourceUrl), isTrue);
      expect(isPublishable(r), isFalse);
    });

    test('a malformed source URL fails', () {
      final r = _validate(
        _validLessonMap(
          sources: [
            {
              'agency': 'BSP',
              'title': 'A circular',
              'canonicalUrl': 'not a url',
            },
          ],
        ),
      );
      expect(_hasCode(r, ValidationIssueCode.invalidSourceUrl), isTrue);
    });

    test('a placeholder domain fails even over HTTPS', () {
      final r = _validate(
        _validLessonMap(
          sources: [
            {
              'agency': 'BSP',
              'title': 'A circular',
              'canonicalUrl': 'https://example.com/circular',
            },
          ],
        ),
      );
      expect(_hasCode(r, ValidationIssueCode.invalidSourceUrl), isTrue);
    });
  });

  group(
    'governance dates, deterministic against the injected reference date',
    () {
      test('a regulated lesson with no last-verified date fails', () {
        final r = _validate(
          _validLessonMap(
            governance: {'volatility': 'annual', 'reviewDueDate': '2027-06'},
          ),
        );
        expect(_hasCode(r, ValidationIssueCode.missingVerifiedDate), isTrue);
      });

      test('high-volatility content with no review-due date fails', () {
        final r = _validate(
          _validLessonMap(
            governance: {'volatility': 'high', 'lastVerifiedDate': '2026-06'},
          ),
        );
        expect(_hasCode(r, ValidationIssueCode.missingReviewDueDate), isTrue);
      });

      test('a malformed date string is reported as an invalid format', () {
        final r = _validate(
          _validLessonMap(
            governance: {
              'volatility': 'annual',
              'lastVerifiedDate': '2026/06',
              'reviewDueDate': '2027-06',
            },
          ),
        );
        expect(_hasCode(r, ValidationIssueCode.invalidDateFormat), isTrue);
      });

      test(
        'high-volatility content is overdue once the reference date passes review-due, '
        'and the same lesson is not overdue for an earlier reference date',
        () {
          final map = _validLessonMap(
            governance: {
              'volatility': 'high',
              'lastVerifiedDate': '2025-01',
              'reviewDueDate': '2025-06',
            },
          );
          final overdue = validateExpansionLesson(
            lessonFromMap(map),
            referenceDate: DateTime.utc(2026, 8, 3),
          );
          expect(_hasCode(overdue, ValidationIssueCode.reviewOverdue), isTrue);
          expect(isPublishable(overdue), isFalse);

          final notYetDue = validateExpansionLesson(
            lessonFromMap(map),
            referenceDate: DateTime.utc(2025, 3, 1),
          );
          expect(
            _hasCode(notYetDue, ValidationIssueCode.reviewOverdue),
            isFalse,
          );
        },
      );
    },
  );

  group('review status', () {
    test(
      'withdrawn content is never publishable, even if everything else passes',
      () {
        final r = _validate(
          _validLessonMap(
            governance: {
              'volatility': 'annual',
              'reviewStatus': 'withdrawn',
              'lastVerifiedDate': '2026-06',
              'reviewDueDate': '2027-06',
            },
          ),
        );
        expect(_hasCode(r, ValidationIssueCode.withdrawnContent), isTrue);
        expect(isPublishable(r), isFalse);
      },
    );

    test('content pending review is not publishable', () {
      final r = _validate(
        _validLessonMap(
          governance: {
            'volatility': 'annual',
            'reviewStatus': 'reviewDue',
            'lastVerifiedDate': '2026-06',
            'reviewDueDate': '2027-06',
          },
        ),
      );
      expect(_hasCode(r, ValidationIssueCode.unverifiedContent), isTrue);
      expect(isPublishable(r), isFalse);
    });
  });

  group('required risk warning and educational boundary', () {
    test('a regulated lesson with no risk-warning block fails', () {
      final r = _validate(
        _validLessonMap(
          blocks: [
            {
              'kind': 'educationalBoundary',
              'sourceLabel': 'the Bangko Sentral ng Pilipinas',
            },
          ],
        ),
      );
      expect(_hasCode(r, ValidationIssueCode.missingRiskWarning), isTrue);
    });

    test('a regulated lesson with no educational-boundary block fails', () {
      final r = _validate(
        _validLessonMap(
          blocks: [
            {
              'kind': 'riskWarning',
              'title': 'Value can go down',
              'text':
                  'A UITF unit price moves with the market and can lose value.',
            },
          ],
        ),
      );
      expect(
        _hasCode(r, ValidationIssueCode.missingEducationalDisclaimer),
        isTrue,
      );
    });
  });

  group('unsafe-language hard errors', () {
    test('guaranteed-return wording fails', () {
      final r = _validate(
        _validLessonMap(
          blocks: [
            {
              'kind': 'nuggets',
              'items': ['This fund guarantees a profit every month.'],
            },
            {
              'kind': 'riskWarning',
              'title': 'Value can go down',
              'text':
                  'A UITF unit price moves with the market and can lose value.',
            },
            {'kind': 'educationalBoundary'},
          ],
        ),
      );
      expect(
        _hasCode(r, ValidationIssueCode.guaranteedOutcomeLanguage),
        isTrue,
      );
      expect(isPublishable(r), isFalse);
    });

    test('an instruction to buy a named fund fails', () {
      final r = _validate(
        _validLessonMap(
          blocks: [
            {
              'kind': 'nuggets',
              'items': ['Buy Fund XYZ today before the price goes up.'],
            },
            {
              'kind': 'riskWarning',
              'title': 'Value can go down',
              'text':
                  'A UITF unit price moves with the market and can lose value.',
            },
            {'kind': 'educationalBoundary'},
          ],
        ),
      );
      expect(
        _hasCode(r, ValidationIssueCode.personalRecommendationLanguage),
        isTrue,
      );
    });

    test('an unsupported government-benefit eligibility claim fails', () {
      final r = _validate(
        _validLessonMap(
          topics: ['governmentBenefitEligibility'],
          sources: [
            {
              'agency': 'Social Security System',
              'title': 'Retirement Benefit Guide',
              'canonicalUrl': 'https://www.sss.gov.ph/retirement-guide',
            },
          ],
          blocks: [
            {
              'kind': 'nuggets',
              'items': [
                'You are already eligible for the maximum SSS pension.',
              ],
            },
            {
              'kind': 'riskWarning',
              'title': 'Amounts vary',
              'text':
                  'Actual benefit amounts depend on your own contribution record.',
            },
            {'kind': 'educationalBoundary'},
          ],
        ),
      );
      expect(
        _hasCode(r, ValidationIssueCode.unsupportedEligibilityClaim),
        isTrue,
      );
    });

    test('a request to enter an OTP or credential fails', () {
      final r = _validate(
        _validLessonMap(
          blocks: [
            {
              'kind': 'nuggets',
              'items': [
                'Enter your OTP here to verify your account instantly.',
              ],
            },
            {
              'kind': 'riskWarning',
              'title': 'Value can go down',
              'text':
                  'A UITF unit price moves with the market and can lose value.',
            },
            {'kind': 'educationalBoundary'},
          ],
        ),
      );
      expect(_hasCode(r, ValidationIssueCode.unsafeCredentialRequest), isTrue);
    });
  });

  group(
    'unsafe-language patterns never flag the safe, negated phrasing they '
    'exist to protect (a qa-tester pass found five real false positives)',
    () {
      ValidationResult validateNugget(String text) => _validate(
        _validLessonMap(
          blocks: [
            {
              'kind': 'nuggets',
              'items': [text],
            },
            {
              'kind': 'riskWarning',
              'title': 'Value can go down',
              'text':
                  'A UITF unit price moves with the market and can lose value.',
            },
            {'kind': 'educationalBoundary'},
          ],
        ),
      );

      test('a myth-busting denial of a guaranteed return is not flagged', () {
        final r = validateNugget(
          'No provider can guarantee a return, no matter what they say.',
        );
        expect(
          _hasCode(r, ValidationIssueCode.guaranteedOutcomeLanguage),
          isFalse,
        );
        expect(isPublishable(r), isTrue);
      });

      test('an explicit risk disclosure ("not risk-free") is not flagged', () {
        final r = validateNugget('This account is not risk-free.');
        expect(
          _hasCode(r, ValidationIssueCode.guaranteedOutcomeLanguage),
          isFalse,
        );
      });

      test('a negated eligibility statement is not flagged', () {
        final r = validateNugget(
          'You are not eligible for the maximum pension unless you meet the '
          'contribution requirement.',
        );
        expect(
          _hasCode(r, ValidationIssueCode.unsupportedEligibilityClaim),
          isFalse,
        );
      });

      test('"not covered ... until" is not flagged as a coverage claim', () {
        final r = validateNugget(
          "You're not covered by this plan until the waiting period ends.",
        );
        expect(
          _hasCode(r, ValidationIssueCode.unsupportedEligibilityClaim),
          isFalse,
        );
      });

      test('anti-scam advice never to share an OTP is not flagged', () {
        final r = validateNugget(
          'A legitimate bank will never ask you to share your OTP with '
          'anyone.',
        );
        expect(
          _hasCode(r, ValidationIssueCode.unsafeCredentialRequest),
          isFalse,
        );
        expect(isPublishable(r), isTrue);
      });

      test('anti-scam advice never to enter a password is not flagged', () {
        final r = validateNugget(
          'Never enter your password on a site you do not trust.',
        );
        expect(
          _hasCode(r, ValidationIssueCode.unsafeCredentialRequest),
          isFalse,
        );
      });

      test(
        '"Buy Now, Pay Later" (a topic name, not a stock tip) is not flagged',
        () {
          final r = validateNugget(
            'Buy Now, Pay Later lets you split a purchase into installments.',
          );
          expect(
            _hasCode(r, ValidationIssueCode.personalRecommendationLanguage),
            isFalse,
          );
        },
      );

      test('"A Buy Now Pay Later loan" is not flagged', () {
        final r = validateNugget(
          'A Buy Now Pay Later loan still charges you if you miss a '
          'payment.',
        );
        expect(
          _hasCode(r, ValidationIssueCode.personalRecommendationLanguage),
          isFalse,
        );
      });

      test('the negation fix never suppresses a real violation earlier in the '
          'same lesson block', () {
        final r = validateNugget(
          'This fund has no annual fee, and guarantees a profit every '
          'month.',
        );
        expect(
          _hasCode(r, ValidationIssueCode.guaranteedOutcomeLanguage),
          isTrue,
        );
      });
    },
  );

  group('the reviewed myth example exemption', () {
    const mythText =
        'Some people believe this investment guarantees a profit every month.';

    test('an unreviewed myth phrase fails normally', () {
      final r = _validate(
        _validLessonMap(
          blocks: [
            {
              'kind': 'trap',
              'mostPeople': mythText,
              'worksBetter':
                  'Nothing in the market is promised, and returns move up and down.',
            },
            {
              'kind': 'riskWarning',
              'title': 'Value can go down',
              'text':
                  'A UITF unit price moves with the market and can lose value.',
            },
            {'kind': 'educationalBoundary'},
          ],
        ),
      );
      expect(
        _hasCode(r, ValidationIssueCode.guaranteedOutcomeLanguage),
        isTrue,
      );
    });

    test(
      'the same phrase, marked reviewed, is exempted and the lesson is publishable',
      () {
        final r = _validate(
          _validLessonMap(
            blocks: [
              {
                'kind': 'trap',
                'mostPeople': mythText,
                'worksBetter':
                    'Nothing in the market is promised, and returns move up and down.',
              },
              {
                'kind': 'riskWarning',
                'title': 'Value can go down',
                'text':
                    'A UITF unit price moves with the market and can lose value.',
              },
              {'kind': 'educationalBoundary'},
            ],
            reviewedMythExamples: [
              {'text': mythText, 'reviewedBy': 'cpa-1'},
            ],
          ),
        );
        expect(
          _hasCode(r, ValidationIssueCode.guaranteedOutcomeLanguage),
          isFalse,
        );
        expect(isPublishable(r), isTrue);
      },
    );

    test(
      'marking one phrase reviewed never suppresses an unsafe phrase elsewhere in the lesson',
      () {
        final r = _validate(
          _validLessonMap(
            blocks: [
              {
                'kind': 'trap',
                'mostPeople': mythText,
                'worksBetter':
                    'Nothing in the market is promised, and returns move up and down.',
              },
              {
                'kind': 'nuggets',
                'items': ['Buy Fund XYZ today before the price goes up.'],
              },
              {
                'kind': 'riskWarning',
                'title': 'Value can go down',
                'text':
                    'A UITF unit price moves with the market and can lose value.',
              },
              {'kind': 'educationalBoundary'},
            ],
            reviewedMythExamples: [
              {'text': mythText, 'reviewedBy': 'cpa-1'},
            ],
          ),
        );
        expect(
          _hasCode(r, ValidationIssueCode.guaranteedOutcomeLanguage),
          isFalse,
        );
        expect(
          _hasCode(r, ValidationIssueCode.personalRecommendationLanguage),
          isTrue,
        );
        expect(isPublishable(r), isFalse);
      },
    );
  });

  group('context-sensitive warnings never block publishing on their own', () {
    test(
      'a non-regulated lesson with a bare historical claim gets a warning, not an error',
      () {
        final r = _validate(
          _validLessonMap(
            topics: const [],
            sources: const [],
            governance: const {},
            blocks: [
              {
                'kind': 'prose',
                'heading': 'A quick note',
                'body': [
                  'Historically this account paid more interest than a regular savings account.',
                ],
              },
            ],
          ),
        );
        expect(r.errors, isEmpty);
        expect(_hasCode(r, ValidationIssueCode.missingRiskContext), isTrue);
        expect(isPublishable(r), isTrue);
      },
    );
  });

  group('isPublishable is pure and based only on validation results', () {
    test('any result with at least one error is not publishable', () {
      final withError = ValidationResult(
        lessonId: 'x',
        issues: const [
          ValidationIssue(
            code: ValidationIssueCode.withdrawnContent,
            severity: ValidationSeverity.error,
            lessonId: 'x',
            message: 'withdrawn',
          ),
        ],
      );
      expect(isPublishable(withError), isFalse);
    });

    test(
      'a result with only warnings, or no issues at all, is publishable',
      () {
        const withWarningOnly = ValidationResult(
          lessonId: 'x',
          issues: [
            ValidationIssue(
              code: ValidationIssueCode.missingRiskContext,
              severity: ValidationSeverity.warning,
              lessonId: 'x',
              message: 'warning',
            ),
          ],
        );
        const withNoIssues = ValidationResult(lessonId: 'x');
        expect(isPublishable(withWarningOnly), isTrue);
        expect(isPublishable(withNoIssues), isTrue);
      },
    );
  });

  group(
    'invariant: the existing 22 core lessons are untouched by this validator',
    () {
      test('the core catalog is still exactly 22 lessons', () {
        expect(lessons.length, 22);
      });

      test(
        'every core lesson carries no topics and no reviewed myth examples',
        () {
          for (final raw in lessons) {
            final l = lessonFromMap(raw);
            expect(
              l.topics,
              isEmpty,
              reason: '${l.id} should not be classified',
            );
            expect(
              l.reviewedMythExamples,
              isEmpty,
              reason: '${l.id} authors no exemptions',
            );
          }
        },
      );

      test('none of the 22 core lessons trip a validation error', () {
        for (final raw in lessons) {
          final l = lessonFromMap(raw);
          final r = validateExpansionLesson(l, referenceDate: _ref);
          expect(
            r.errors,
            isEmpty,
            reason:
                '${l.id} is not expansion content and must never be flagged',
          );
        }
      });

      test(
        'expansion content can never be marked publishable while an error is present',
        () {
          // A representative failure from every hard-error category proves the
          // rule generically, not just for one fixture.
          final failing = [
            _validLessonMap(sources: []),
            _validLessonMap(
              governance: {'volatility': 'annual', 'reviewDueDate': '2027-06'},
            ),
            _validLessonMap(
              governance: {
                'volatility': 'annual',
                'reviewStatus': 'withdrawn',
                'lastVerifiedDate': '2026-06',
                'reviewDueDate': '2027-06',
              },
            ),
          ];
          for (final map in failing) {
            final r = _validate(map);
            expect(r.hasErrors, isTrue);
            expect(isPublishable(r), isFalse);
          }
        },
      );
    },
  );
}
