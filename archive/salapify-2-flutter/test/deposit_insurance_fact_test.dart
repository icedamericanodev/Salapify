// Money Courses Phase 7B: proves money/deposit_insurance_fact.dart's own
// small validator does the one job the task asked for, catch a missing or
// stale PDIC limit before it ships, and proves the REAL figure this course
// uses (content/lessons_deposits_pooled_funds.dart's
// currentDepositInsuranceLimit) is current as of the reference date.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lessons_deposits_pooled_funds.dart';
import 'package:salapify/money/deposit_insurance_fact.dart';

final _ref = DateTime.utc(2026, 8, 3);

void main() {
  group('the real course figure', () {
    test('currentDepositInsuranceLimit is stored as dated content', () {
      expect(currentDepositInsuranceLimit.maxCoveragePhp, 1000000);
      expect(currentDepositInsuranceLimit.effectiveDate, '2025-03-15');
      expect(currentDepositInsuranceLimit.lastVerifiedDate, isNotEmpty);
      expect(currentDepositInsuranceLimit.reviewDueDate, isNotEmpty);
      expect(
        currentDepositInsuranceLimit.sourceUrl,
        'https://www.pdic.gov.ph/MDIC',
      );
      expect(
        currentDepositInsuranceLimit.calculatorUrl,
        'https://www.pdic.gov.ph/di_ecalculator',
      );
    });

    test('currentDepositInsuranceLimit has zero issues as of the reference '
        'date', () {
      expect(
        depositInsuranceFactIssues(
          currentDepositInsuranceLimit,
          referenceDate: _ref,
        ),
        isEmpty,
      );
      expect(
        isCurrentDepositInsuranceFact(
          currentDepositInsuranceLimit,
          referenceDate: _ref,
        ),
        isTrue,
      );
    });
  });

  group('missing metadata is rejected', () {
    test('a missing effective date is flagged', () {
      const fact = DepositInsuranceFact(
        maxCoveragePhp: 1000000,
        effectiveDate: '',
        lastVerifiedDate: '2026-08',
        reviewDueDate: '2027-02',
        sourceUrl: 'https://www.pdic.gov.ph/MDIC',
        calculatorUrl: 'https://www.pdic.gov.ph/di_ecalculator',
      );
      final issues = depositInsuranceFactIssues(fact, referenceDate: _ref);
      expect(issues, contains(DepositInsuranceFactIssue.missingEffectiveDate));
      expect(isCurrentDepositInsuranceFact(fact, referenceDate: _ref), isFalse);
    });

    test('a missing last-verified date is flagged', () {
      const fact = DepositInsuranceFact(
        maxCoveragePhp: 1000000,
        effectiveDate: '2025-03-15',
        lastVerifiedDate: '',
        reviewDueDate: '2027-02',
        sourceUrl: 'https://www.pdic.gov.ph/MDIC',
        calculatorUrl: 'https://www.pdic.gov.ph/di_ecalculator',
      );
      final issues = depositInsuranceFactIssues(fact, referenceDate: _ref);
      expect(
        issues,
        contains(DepositInsuranceFactIssue.missingLastVerifiedDate),
      );
    });

    test('a missing review-due date is flagged', () {
      const fact = DepositInsuranceFact(
        maxCoveragePhp: 1000000,
        effectiveDate: '2025-03-15',
        lastVerifiedDate: '2026-08',
        reviewDueDate: '',
        sourceUrl: 'https://www.pdic.gov.ph/MDIC',
        calculatorUrl: 'https://www.pdic.gov.ph/di_ecalculator',
      );
      final issues = depositInsuranceFactIssues(fact, referenceDate: _ref);
      expect(issues, contains(DepositInsuranceFactIssue.missingReviewDueDate));
    });

    test('an unparseable date is flagged as an invalid format', () {
      const fact = DepositInsuranceFact(
        maxCoveragePhp: 1000000,
        effectiveDate: 'March 2025',
        lastVerifiedDate: '2026-08',
        reviewDueDate: '2027-02',
        sourceUrl: 'https://www.pdic.gov.ph/MDIC',
        calculatorUrl: 'https://www.pdic.gov.ph/di_ecalculator',
      );
      final issues = depositInsuranceFactIssues(fact, referenceDate: _ref);
      expect(issues, contains(DepositInsuranceFactIssue.invalidDateFormat));
    });
  });

  group('stale metadata is rejected', () {
    test('a review-due date that has already passed is flagged as overdue', () {
      const stale = DepositInsuranceFact(
        maxCoveragePhp: 500000,
        effectiveDate: '2009-06-01',
        lastVerifiedDate: '2024-01',
        reviewDueDate: '2025-01',
        sourceUrl: 'https://www.pdic.gov.ph/MDIC',
        calculatorUrl: 'https://www.pdic.gov.ph/di_ecalculator',
      );
      final issues = depositInsuranceFactIssues(stale, referenceDate: _ref);
      expect(issues, contains(DepositInsuranceFactIssue.reviewOverdue));
      expect(
        isCurrentDepositInsuranceFact(stale, referenceDate: _ref),
        isFalse,
      );
    });

    test('a fact verified before it took effect is an implausible date', () {
      const nonsense = DepositInsuranceFact(
        maxCoveragePhp: 1000000,
        effectiveDate: '2025-03-15',
        lastVerifiedDate: '2024-01',
        reviewDueDate: '2027-02',
        sourceUrl: 'https://www.pdic.gov.ph/MDIC',
        calculatorUrl: 'https://www.pdic.gov.ph/di_ecalculator',
      );
      final issues = depositInsuranceFactIssues(nonsense, referenceDate: _ref);
      expect(issues, contains(DepositInsuranceFactIssue.implausibleDate));
    });

    test('a review-due date before the last-verified date is implausible', () {
      const nonsense = DepositInsuranceFact(
        maxCoveragePhp: 1000000,
        effectiveDate: '2025-03-15',
        lastVerifiedDate: '2026-08',
        reviewDueDate: '2026-01',
        sourceUrl: 'https://www.pdic.gov.ph/MDIC',
        calculatorUrl: 'https://www.pdic.gov.ph/di_ecalculator',
      );
      final issues = depositInsuranceFactIssues(nonsense, referenceDate: _ref);
      expect(issues, contains(DepositInsuranceFactIssue.implausibleDate));
    });

    test('a fully valid, current fact has no issues', () {
      const fresh = DepositInsuranceFact(
        maxCoveragePhp: 1000000,
        effectiveDate: '2025-03-15',
        lastVerifiedDate: '2026-08',
        reviewDueDate: '2027-02',
        sourceUrl: 'https://www.pdic.gov.ph/MDIC',
        calculatorUrl: 'https://www.pdic.gov.ph/di_ecalculator',
      );
      expect(depositInsuranceFactIssues(fresh, referenceDate: _ref), isEmpty);
      expect(isCurrentDepositInsuranceFact(fresh, referenceDate: _ref), isTrue);
    });
  });
}
