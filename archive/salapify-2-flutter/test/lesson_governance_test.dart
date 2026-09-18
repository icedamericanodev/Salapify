// The additive Phase 2 data model: structured source citations and content
// governance metadata on MoneyLesson, plus the two new renderable blocks
// (OfficialSourceBlock, RiskWarningBlock) that display them.
//
// The one thing every test here has to prove, one way or another: none of
// this changes what the existing 22 lessons already are. Every new field is
// optional or defaulted, none of the 22 lesson maps in lessons.dart set the
// new keys, so lessonFromMap must keep producing exactly the same lessons it
// always has.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons.dart';

// The exact id order the 22 core lessons ship in today. A change here is a
// reorder or a rewrite of the core catalog, which this phase must never do.
const _coreLessonIdsInOrder = [
  'see-it-first',
  'needs-wants',
  'fifty-thirty-twenty',
  'pay-yourself-first',
  'emergency-fund',
  'health-is-wealth',
  'card-interest',
  'bnpl',
  'snowball-avalanche',
  'cushion-or-debt',
  'extra-payment',
  'utang-friends',
  'steady-salary',
  'lean-month-plan',
  'freelancer-setaside',
  'tax-forms',
  'own-your-benefits',
  'windfall-rule',
  'thirteenth-month',
  'year-end-refund',
  'raise-rule',
  'savings-circles',
];

void main() {
  group('the core 22 lessons are untouched by the new model', () {
    test('lesson count and id order are exactly what they were', () {
      expect(lessons.length, 22);
      expect(lessons.map((l) => l['id']).toList(), _coreLessonIdsInOrder);
    });

    test('every core lesson gets the default governance and no sources', () {
      for (final raw in lessons) {
        final l = lessonFromMap(raw);
        expect(
          l.governance.volatility,
          ContentVolatility.evergreen,
          reason: '${l.id} should default to evergreen',
        );
        expect(l.governance.reviewStatus, ReviewStatus.verified);
        expect(l.governance.contentVersion, 1);
        expect(l.governance.lastVerifiedDate, isNull);
        expect(l.governance.reviewDueDate, isNull);
        expect(l.governance.reviewerId, isNull);
        expect(
          l.sources,
          isEmpty,
          reason: '${l.id} has no authored sources yet',
        );
        // factCheckedOn stays exactly as it was: untouched, not migrated.
        expect(l.factCheckedOn, raw['factCheckedOn']);
      }
    });

    test('the core completion calculation is unaffected', () {
      // trackProgress and the "X of 22" header both fold over lessons.length
      // and MoneyLesson.isDone; neither reads governance or sources. This
      // pins the input shape they depend on, matching the audit's finding
      // that isDone / lessons.length are the load bearing facts here.
      expect(lessons.length, 22);
      for (final raw in lessons) {
        final l = lessonFromMap(raw);
        expect(l.id, isNotEmpty);
        expect(l.trackId, isNotEmpty);
      }
    });
  });

  group('LessonSourceInfo and LessonGovernance are authorable', () {
    test('a lesson can carry multiple official sources', () {
      final l = lessonFromMap({
        'id': 'x',
        'track': 't',
        'title': 'T',
        'body': ['prose'],
        'sources': [
          {
            'agency': 'Bangko Sentral ng Pilipinas',
            'title': 'Circular No. 1133',
            'canonicalUrl': 'https://www.bsp.gov.ph/circular-1133',
            'issuanceOrCircularNumber': 'Circular 1133',
            'effectiveDate': '2022-03',
            'lastVerifiedDate': '2026-07',
          },
          {
            'agency': 'Securities and Exchange Commission',
            'title': 'Investor Protection Guide',
            'canonicalUrl': 'https://www.sec.gov.ph/investor-guide',
          },
        ],
      });
      expect(l.sources.length, 2);
      expect(l.sources.first.agency, 'Bangko Sentral ng Pilipinas');
      expect(l.sources.first.issuanceOrCircularNumber, 'Circular 1133');
      expect(l.sources.last.issuanceOrCircularNumber, isNull);
      expect(l.sources.last.effectiveDate, isNull);
    });

    test(
      'a source missing a required field is dropped, not shown half blank',
      () {
        final l = lessonFromMap({
          'id': 'x',
          'track': 't',
          'title': 'T',
          'body': ['prose'],
          'sources': [
            {'agency': 'BSP', 'title': 'No link'},
            {'agency': '', 'title': 'No agency', 'canonicalUrl': 'https://x'},
          ],
        });
        expect(l.sources, isEmpty);
      },
    );

    test('governance metadata can be authored and overrides the defaults', () {
      final l = lessonFromMap({
        'id': 'x',
        'track': 't',
        'title': 'T',
        'body': ['prose'],
        'governance': {
          'volatility': 'high',
          'reviewStatus': 'reviewDue',
          'contentVersion': 3,
          'lastVerifiedDate': '2026-06',
          'reviewDueDate': '2026-12',
          'reviewerId': 'cpa-1',
        },
      });
      expect(l.governance.volatility, ContentVolatility.high);
      expect(l.governance.reviewStatus, ReviewStatus.reviewDue);
      expect(l.governance.contentVersion, 3);
      expect(l.governance.lastVerifiedDate, '2026-06');
      expect(l.governance.reviewDueDate, '2026-12');
      expect(l.governance.reviewerId, 'cpa-1');
    });

    test('an unrecognized volatility or review status falls back safely', () {
      final l = lessonFromMap({
        'id': 'x',
        'track': 't',
        'title': 'T',
        'body': ['prose'],
        'governance': {
          'volatility': 'not a real value',
          'reviewStatus': 'nope',
        },
      });
      expect(l.governance.volatility, ContentVolatility.evergreen);
      expect(l.governance.reviewStatus, ReviewStatus.verified);
    });
  });

  group('OfficialSourceBlock and RiskWarningBlock construction', () {
    test('a well formed official source block parses', () {
      final b = blockFromMap({
        'kind': 'officialSource',
        'agency': 'Bureau of Internal Revenue',
        'sourceTitle': 'Revenue Regulations No. 8-2018',
        'canonicalUrl': 'https://www.bir.gov.ph/rr-8-2018',
        'issuanceOrCircularNumber': 'RR 8-2018',
        'effectiveDate': '2018-01',
        'lastVerifiedDate': '2026-01',
      });
      expect(b, isA<OfficialSourceBlock>());
      final s = b as OfficialSourceBlock;
      expect(s.agency, 'Bureau of Internal Revenue');
      expect(s.canonicalUrl, 'https://www.bir.gov.ph/rr-8-2018');
      expect(s.issuanceOrCircularNumber, 'RR 8-2018');
    });

    test('an official source with only the required fields still parses', () {
      final b = blockFromMap({
        'kind': 'officialSource',
        'agency': 'BSP',
        'sourceTitle': 'A circular',
        'canonicalUrl': 'https://bsp.gov.ph/c',
      });
      expect(b, isA<OfficialSourceBlock>());
      final s = b as OfficialSourceBlock;
      expect(s.lastVerifiedDate, isNull);
      expect(s.effectiveDate, isNull);
      expect(s.issuanceOrCircularNumber, isNull);
    });

    test(
      'a half built official source block is dropped, never rendered empty',
      () {
        expect(
          blockFromMap({'kind': 'officialSource', 'agency': 'BSP'}),
          isNull,
        );
        expect(
          blockFromMap({
            'kind': 'officialSource',
            'agency': 'BSP',
            'sourceTitle': 'T',
            'canonicalUrl': '',
          }),
          isNull,
        );
      },
    );

    test('a well formed risk warning block parses, defaulting to notice', () {
      final b = blockFromMap({
        'kind': 'riskWarning',
        'title': 'Not a guaranteed return',
        'text': 'Every investment can lose value, including this one.',
      });
      expect(b, isA<RiskWarningBlock>());
      final w = b as RiskWarningBlock;
      expect(w.severity, RiskSeverity.notice);
    });

    test(
      'severity "caution" is honored, anything else falls back to notice',
      () {
        final caution =
            blockFromMap({
                  'kind': 'riskWarning',
                  'title': 'T',
                  'text': 'W',
                  'severity': 'caution',
                })
                as RiskWarningBlock;
        expect(caution.severity, RiskSeverity.caution);

        final unknown =
            blockFromMap({
                  'kind': 'riskWarning',
                  'title': 'T',
                  'text': 'W',
                  'severity': 'not a real severity',
                })
                as RiskWarningBlock;
        expect(unknown.severity, RiskSeverity.notice);
      },
    );

    test(
      'a half built risk warning block is dropped, never rendered empty',
      () {
        expect(
          blockFromMap({'kind': 'riskWarning', 'title': 'Only a title'}),
          isNull,
        );
        expect(
          blockFromMap({'kind': 'riskWarning', 'text': 'Only text'}),
          isNull,
        );
      },
    );

    test('both new kinds are authorable inside a lesson\'s blocks list', () {
      final l = lessonFromMap({
        'id': 'x',
        'track': 't',
        'title': 'T',
        'body': ['old prose, unused once blocks are authored'],
        'blocks': [
          {
            'kind': 'officialSource',
            'agency': 'BSP',
            'sourceTitle': 'A circular',
            'canonicalUrl': 'https://bsp.gov.ph/c',
          },
          {
            'kind': 'riskWarning',
            'title': 'Caution',
            'text': 'This can change.',
          },
        ],
      });
      expect(l.blocks.length, 2);
      expect(l.blocks[0], isA<OfficialSourceBlock>());
      expect(l.blocks[1], isA<RiskWarningBlock>());
    });
  });
}
