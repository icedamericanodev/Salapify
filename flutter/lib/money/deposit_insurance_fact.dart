// A single versioned fact for Money Courses Phase 7B ("Deposits and Pooled
// Funds"): the PDIC maximum deposit insurance coverage limit.
//
// PDIC's Board can revise this figure under its own charter (Republic Act
// 3591, as amended) without a new law each time, and it last did exactly
// that: the limit moved from five hundred thousand pesos to one million
// pesos, effective 2025-03-15. A lesson that states that peso figure as a
// bare fact would go stale the same way an unversioned tax bracket does, and
// the task's own instruction is explicit: "Do not encode the current limit
// as a permanent business rule."
//
// So the figure lives here as data with its own dates, not as a string typed
// into lesson prose. content/lessons_deposits_pooled_funds.dart reads
// [currentDepositInsuranceLimit] to render the "as of" line, and
// [depositInsuranceFactIssues] is what a test (or, one day, a real content
// pipeline) uses to catch a missing or overdue date before it ships, the
// same discipline money/expansion_content_policy.dart already applies to a
// whole lesson's governance, kept here as its own small, single-purpose
// check for this one figure specifically.
//
// Pure Dart, no Flutter import, no system clock read: [referenceDate] is
// always injected, matching the rest of lib/money's own convention.

import 'expansion_content_policy.dart' show parseGovernanceDate;

/// One versioned statement of the current PDIC maximum deposit insurance
/// coverage. Dates stay as plain 'YYYY-MM' or 'YYYY-MM-DD' strings, the same
/// convention content/lesson_model.dart's LessonGovernance and
/// LessonSourceInfo already use.
class DepositInsuranceFact {
  /// The coverage limit itself, in whole pesos, per depositor per bank.
  final int maxCoveragePhp;

  /// When this limit took effect.
  final String effectiveDate;

  /// When this figure was last checked against PDIC's own page.
  final String lastVerifiedDate;

  /// When this figure is due to be checked again.
  final String reviewDueDate;

  /// PDIC's own page stating the current limit.
  final String sourceUrl;

  /// PDIC's own deposit-insurance calculator, for account ownership and
  /// joint/trust cases this course never tries to resolve itself.
  final String calculatorUrl;

  const DepositInsuranceFact({
    required this.maxCoveragePhp,
    required this.effectiveDate,
    required this.lastVerifiedDate,
    required this.reviewDueDate,
    required this.sourceUrl,
    required this.calculatorUrl,
  });
}

/// What can be wrong with a [DepositInsuranceFact], catching exactly the
/// two failure modes the task asks a test to reject: a missing date, and a
/// figure that is now stale (its own review-due date has passed).
enum DepositInsuranceFactIssue {
  missingEffectiveDate,
  missingLastVerifiedDate,
  missingReviewDueDate,
  invalidDateFormat,
  implausibleDate,
  reviewOverdue,
}

/// Every problem found with [fact], relative to [referenceDate]. Empty means
/// the figure is safe to show as current. Never throws; a caller decides
/// what to do with a non-empty list, the same contract
/// money/expansion_content_policy.dart's ValidationResult already follows.
List<DepositInsuranceFactIssue> depositInsuranceFactIssues(
  DepositInsuranceFact fact, {
  required DateTime referenceDate,
}) {
  final issues = <DepositInsuranceFactIssue>[];

  DateTime? parsed(String raw, DepositInsuranceFactIssue missing) {
    if (raw.trim().isEmpty) {
      issues.add(missing);
      return null;
    }
    final dt = parseGovernanceDate(raw);
    if (dt == null) issues.add(DepositInsuranceFactIssue.invalidDateFormat);
    return dt;
  }

  final effective = parsed(
    fact.effectiveDate,
    DepositInsuranceFactIssue.missingEffectiveDate,
  );
  final verified = parsed(
    fact.lastVerifiedDate,
    DepositInsuranceFactIssue.missingLastVerifiedDate,
  );
  final due = parsed(
    fact.reviewDueDate,
    DepositInsuranceFactIssue.missingReviewDueDate,
  );

  if (effective != null && verified != null && verified.isBefore(effective)) {
    // Verifying a limit before it took effect makes no sense: the figure
    // being confirmed did not exist yet on that date.
    issues.add(DepositInsuranceFactIssue.implausibleDate);
  }
  if (verified != null && due != null && due.isBefore(verified)) {
    issues.add(DepositInsuranceFactIssue.implausibleDate);
  }
  if (due != null && referenceDate.isAfter(due)) {
    issues.add(DepositInsuranceFactIssue.reviewOverdue);
  }

  return issues;
}

/// Whether [fact] is safe to show as the current figure: no missing date, no
/// nonsense date ordering, and its own review has not lapsed.
bool isCurrentDepositInsuranceFact(
  DepositInsuranceFact fact, {
  required DateTime referenceDate,
}) => depositInsuranceFactIssues(fact, referenceDate: referenceDate).isEmpty;
