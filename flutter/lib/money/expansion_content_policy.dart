// The Phase 4 content policy validator for Money Courses expansion content
// (Grow Your Money, Protect Your Future, Build Your Business, and whatever
// comes after). Pure Dart, no Flutter import, no system clock read, and no
// network call, matching the discipline the rest of lib/money already
// follows.
//
// This validates a typed MoneyLesson (lesson_model.dart), reusing exactly
// the structured metadata Phase 2 already added: LessonGovernance,
// LessonSourceInfo, OfficialSourceBlock, RiskWarningBlock, plus the two
// small additions this phase makes on top (ContentTopic, ReviewedMythExample,
// EducationalBoundaryBlock). It never throws for a normal validation
// failure: every problem is a structured ValidationIssue in the returned
// list, and isPublishable is a pure fold over that list, not a second copy
// of the rules.
//
// None of the existing 22 core lessons carry a ContentTopic, so none of them
// are ever "regulated" by this validator's own definition and this file
// changes nothing about how they render or score. It exists for lessons that
// have not been written yet.

import '../content/lesson_blocks.dart';
import '../content/lesson_model.dart';

enum ValidationSeverity { error, warning }

enum ValidationIssueCode {
  missingOfficialSource,
  invalidSourceUrl,
  missingVerifiedDate,
  missingReviewDueDate,
  invalidDateFormat,

  /// A date that parses fine but makes no sense in context: a last-verified
  /// date after the reference date, or a review-due date before the
  /// last-verified date.
  implausibleDate,
  reviewOverdue,
  unverifiedContent,
  withdrawnContent,
  missingRiskWarning,
  guaranteedOutcomeLanguage,
  personalRecommendationLanguage,
  unsupportedEligibilityClaim,
  unsafeCredentialRequest,
  missingEducationalDisclaimer,

  /// A return figure or benefit amount stated with no "as of" or effective
  /// date, so a reader cannot tell how current it is.
  missingContextForFigure,

  /// Historical or past performance mentioned with no accompanying risk
  /// explanation.
  missingRiskContext,

  /// A comparison between products or options with no mention of fees or
  /// liquidity, the two considerations a bare comparison usually hides.
  missingComparisonContext,

  /// A process (permit, registration, benefit step) described as if it were
  /// identical everywhere, when it usually is not.
  overgeneralizedProcessClaim,
}

/// One thing the validator found, structured so a test or a future
/// publishing pipeline can inspect it without parsing a message string.
class ValidationIssue {
  final ValidationIssueCode code;
  final ValidationSeverity severity;
  final String lessonId;
  final String message;

  /// The block index (e.g. "blocks[2]") or field name (e.g.
  /// "governance.reviewDueDate") this issue is about, when it is about one
  /// specific place rather than the lesson as a whole.
  final String? field;

  const ValidationIssue({
    required this.code,
    required this.severity,
    required this.lessonId,
    required this.message,
    this.field,
  });

  @override
  String toString() =>
      '${severity.name} ${code.name} ($lessonId${field == null ? '' : '.$field'}): $message';
}

/// Every issue found for one lesson. Never thrown, always returned, so a
/// caller decides what to do with a failure rather than catching an
/// exception.
class ValidationResult {
  final String lessonId;
  final List<ValidationIssue> issues;

  const ValidationResult({required this.lessonId, this.issues = const []});

  List<ValidationIssue> get errors =>
      issues.where((i) => i.severity == ValidationSeverity.error).toList();

  List<ValidationIssue> get warnings =>
      issues.where((i) => i.severity == ValidationSeverity.warning).toList();

  bool get hasErrors =>
      issues.any((i) => i.severity == ValidationSeverity.error);
}

/// Whether a lesson is safe to publish, purely from its validation issues:
/// zero errors. Warnings never block publishing on their own. This is the
/// one place that rule lives; a screen or a future publishing script should
/// call this rather than re-deriving "no errors" itself.
bool isPublishable(ValidationResult result) => !result.hasErrors;

// ---------------------------------------------------------------------------
// Date handling. The caller injects referenceDate; nothing here reads the
// system clock, so the same lesson and the same referenceDate always
// produce the same result.
// ---------------------------------------------------------------------------

/// Parses 'YYYY-MM' or 'YYYY-MM-DD', rejecting anything that is not a real
/// calendar date (month 13, day 32, a February 30, and so on). Returns null
/// for anything that does not parse, rather than throwing.
DateTime? parseGovernanceDate(String raw) {
  final ymd = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
  final ym = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(raw);
  final int year;
  final int month;
  final int day;
  if (ymd != null) {
    year = int.parse(ymd.group(1)!);
    month = int.parse(ymd.group(2)!);
    day = int.parse(ymd.group(3)!);
  } else if (ym != null) {
    year = int.parse(ym.group(1)!);
    month = int.parse(ym.group(2)!);
    day = 1;
  } else {
    return null;
  }
  if (month < 1 || month > 12) return null;
  final dt = DateTime.utc(year, month, day);
  // DateTime.utc silently rolls an out-of-range day into the next month
  // (e.g. 2026-02-30 becomes March 2). Reject that instead of accepting an
  // impossible date.
  if (dt.year != year || dt.month != month || dt.day != day) return null;
  return dt;
}

// ---------------------------------------------------------------------------
// Source requirements.
// ---------------------------------------------------------------------------

const _placeholderHosts = {
  'example.com',
  'example.org',
  'example.net',
  'test.com',
  'localhost',
  'yourdomain.com',
  'placeholder.com',
  'sample.com',
  'foo.com',
};

bool _isPlaceholderHost(String host) {
  final h = host.toLowerCase();
  if (_placeholderHosts.contains(h)) return true;
  return h.startsWith('example.') || h.contains('.example.');
}

ValidationIssue? _sourceUrlIssue(String lessonId, LessonSourceInfo source) {
  final uri = Uri.tryParse(source.canonicalUrl);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return ValidationIssue(
      code: ValidationIssueCode.invalidSourceUrl,
      severity: ValidationSeverity.error,
      lessonId: lessonId,
      message: 'Source URL "${source.canonicalUrl}" is not a valid URL.',
      field: 'sources.canonicalUrl',
    );
  }
  if (uri.scheme != 'https') {
    return ValidationIssue(
      code: ValidationIssueCode.invalidSourceUrl,
      severity: ValidationSeverity.error,
      lessonId: lessonId,
      message: 'Source URL must be HTTPS: ${source.canonicalUrl}',
      field: 'sources.canonicalUrl',
    );
  }
  if (_isPlaceholderHost(uri.host)) {
    return ValidationIssue(
      code: ValidationIssueCode.invalidSourceUrl,
      severity: ValidationSeverity.error,
      lessonId: lessonId,
      message: 'Source URL uses a placeholder domain: ${uri.host}',
      field: 'sources.canonicalUrl',
    );
  }
  return null;
}

// ---------------------------------------------------------------------------
// Unsafe-language checks. Narrowly scoped patterns, not a giant blacklist:
// each one names a specific claim shape the audit and the founder's own
// house rule ("no product, investment, loan, or stock recommendations")
// already forbid. No named product, provider, stock, or coin appears here;
// the buy/sell and "universally best" patterns match the SHAPE of a
// recommendation, not a list of specific names.
// ---------------------------------------------------------------------------

class _LanguagePattern {
  final ValidationIssueCode code;
  final RegExp pattern;
  final String message;
  const _LanguagePattern(this.code, this.pattern, this.message);
}

final List<_LanguagePattern> _hardErrorPatterns = [
  _LanguagePattern(
    ValidationIssueCode.guaranteedOutcomeLanguage,
    RegExp(
      r'\bguarantee[ds]?\s+(a\s+|an\s+)?(profit|return|income|growth)',
      caseSensitive: false,
    ),
    'Reads as a guaranteed-profit or guaranteed-return claim.',
  ),
  _LanguagePattern(
    ValidationIssueCode.guaranteedOutcomeLanguage,
    RegExp(r'\brisk[\s-]?free\b', caseSensitive: false),
    'Reads as a risk-free investment claim.',
  ),
  _LanguagePattern(
    ValidationIssueCode.guaranteedOutcomeLanguage,
    RegExp(
      r'regulat\w*[^.]{0,50}(guarantees?|ensures?)[^.]{0,30}(safe|safety|profit|no\s+loss)',
      caseSensitive: false,
    ),
    'Reads as a claim that regulation guarantees safety or profitability.',
  ),
  _LanguagePattern(
    ValidationIssueCode.personalRecommendationLanguage,
    RegExp(r'\b([Bb]uy|[Ss]ell)\s+([A-Z][\w&.\-]*(?:\s+[A-Z][\w&.\-]*){0,3})'),
    'Reads as an instruction to buy or sell a specific stock, coin, fund, or policy.',
  ),
  _LanguagePattern(
    ValidationIssueCode.personalRecommendationLanguage,
    RegExp(
      r'\bbest\s+(investment|fund|stock|policy|choice|option)\s+for\s+(everyone|every\s+filipino|all\s+filipinos)\b',
      caseSensitive: false,
    ),
    'Reads as a claim that one product is universally best.',
  ),
  _LanguagePattern(
    ValidationIssueCode.unsupportedEligibilityClaim,
    RegExp(
      r"\byou(?:'re| are)\b[^.]{0,20}\b(officially\s+)?(approved|covered|eligible|qualified)\b",
      caseSensitive: false,
    ),
    'Reads as a claim that the reader personally is approved, covered, or eligible.',
  ),
  _LanguagePattern(
    ValidationIssueCode.unsafeCredentialRequest,
    RegExp(
      r'\b(enter|type|share|provide|send)\s+your\s+(password|pin|otp|seed\s+phrase|private\s+key|government[\s-]?(id|account)\s*credentials?)\b',
      caseSensitive: false,
    ),
    'Asks the reader to enter a password, OTP, seed phrase, private key, or government-account credential.',
  ),
];

bool _hasAny(String haystack, List<String> needles) =>
    needles.any(haystack.contains);

void _checkFigureContext(
  String text,
  String field,
  void Function(ValidationIssueCode, String, {String? field}) warn,
) {
  final lower = text.toLowerCase();
  final hasReturnFigure =
      RegExp(r'\d{1,3}(\.\d+)?\s?%').hasMatch(text) &&
      RegExp(
        r'\b(return|yield|growth|interest)\b',
        caseSensitive: false,
      ).hasMatch(text);
  if (hasReturnFigure && !lower.contains('as of')) {
    warn(
      ValidationIssueCode.missingContextForFigure,
      'A return figure is stated without an "as of" date.',
      field: field,
    );
    return;
  }
  final hasBenefitAmount =
      RegExp(r'(₱|php\s?)\s?\d', caseSensitive: false).hasMatch(text) &&
      RegExp(
        r'\b(benefit|pension|allowance)\b',
        caseSensitive: false,
      ).hasMatch(text);
  if (hasBenefitAmount &&
      !lower.contains('as of') &&
      !lower.contains('effective')) {
    warn(
      ValidationIssueCode.missingContextForFigure,
      'A benefit amount is stated without an effective date.',
      field: field,
    );
  }
}

void _checkRiskContext(
  String text,
  String field,
  void Function(ValidationIssueCode, String, {String? field}) warn,
) {
  if (!RegExp(
    r'\b(historically|past performance)\b',
    caseSensitive: false,
  ).hasMatch(text)) {
    return;
  }
  final lower = text.toLowerCase();
  final hasRiskWord = _hasAny(lower, [
    'risk',
    'lose value',
    'losing value',
    'can go down',
    'not guaranteed',
    'no guarantee',
  ]);
  if (!hasRiskWord) {
    warn(
      ValidationIssueCode.missingRiskContext,
      'Historical or past performance is mentioned with no risk explanation nearby.',
      field: field,
    );
  }
}

void _checkComparisonContext(
  String text,
  String field,
  void Function(ValidationIssueCode, String, {String? field}) warn,
) {
  if (!RegExp(
    r'\b(compared to|versus|vs\.?)\b',
    caseSensitive: false,
  ).hasMatch(text)) {
    return;
  }
  final lower = text.toLowerCase();
  final hasCostWord = _hasAny(lower, ['fee', 'liquidity', 'withdraw']);
  if (!hasCostWord) {
    warn(
      ValidationIssueCode.missingComparisonContext,
      'A product or option comparison does not mention fees or liquidity.',
      field: field,
    );
  }
}

const _universalProcessPhrases = [
  'every lgu',
  'all lgus',
  'any municipality',
  'all cities',
  'every city',
  'all barangays',
  'the same in every',
];

void _checkProcessUniversality(
  String text,
  String field,
  void Function(ValidationIssueCode, String, {String? field}) warn,
) {
  final lower = text.toLowerCase();
  if (_hasAny(lower, _universalProcessPhrases)) {
    warn(
      ValidationIssueCode.overgeneralizedProcessClaim,
      'Presents a permit or registration step as identical across every LGU or industry.',
      field: field,
    );
  }
}

/// The renderable text carried by one block, in reading order. Structural
/// blocks (a citation card, a risk-warning card, or the educational-boundary
/// card itself) carry no free prose written by an author trying to make a
/// point, so they are not scanned.
List<String> _scannableTexts(LessonBlock block) => switch (block) {
  ProseBlock() => block.paragraphs,
  NuggetsBlock() => block.items,
  DiscoveryBlock() => [block.question, block.reveal],
  StoryBlock() => [block.text],
  DiagramBlock() => [
    ...block.steps,
    if (block.caption.isNotEmpty) block.caption,
  ],
  TrapBlock() => [block.mostPeople, block.worksBetter],
  ChallengeBlock() => [
    block.prompt,
    if (block.compare.isNotEmpty) block.compare,
  ],
  RulesBlock() => block.passages,
  ReflectionBlock() => [block.line],
  OfficialSourceBlock() => const [],
  RiskWarningBlock() => const [],
  EducationalBoundaryBlock() => const [],
};

// ---------------------------------------------------------------------------
// Main entry point.
// ---------------------------------------------------------------------------

/// Validates one lesson against the expansion content policy. Deterministic:
/// the only external input besides the lesson is [referenceDate], never the
/// system clock.
///
/// This never throws for a normal content problem; every problem becomes a
/// [ValidationIssue] in the result. A lesson with [ContentTopic]s set is
/// treated as regulated content and held to the source, governance, risk
/// warning, and educational-boundary requirements; a lesson with no topics
/// is only checked for review status, date sanity, and unsafe language.
ValidationResult validateExpansionLesson(
  MoneyLesson lesson, {
  required DateTime referenceDate,
}) {
  final issues = <ValidationIssue>[];
  void err(ValidationIssueCode code, String message, {String? field}) {
    issues.add(
      ValidationIssue(
        code: code,
        severity: ValidationSeverity.error,
        lessonId: lesson.id,
        message: message,
        field: field,
      ),
    );
  }

  void warn(ValidationIssueCode code, String message, {String? field}) {
    issues.add(
      ValidationIssue(
        code: code,
        severity: ValidationSeverity.warning,
        lessonId: lesson.id,
        message: message,
        field: field,
      ),
    );
  }

  final g = lesson.governance;
  final isRegulated = lesson.topics.isNotEmpty;
  final isTimeSensitive = g.volatility == ContentVolatility.high;

  switch (g.reviewStatus) {
    case ReviewStatus.withdrawn:
      err(
        ValidationIssueCode.withdrawnContent,
        'Withdrawn content can never be published.',
        field: 'governance.reviewStatus',
      );
    case ReviewStatus.reviewDue:
      err(
        ValidationIssueCode.unverifiedContent,
        'Content pending review is not publishable until it is reviewed.',
        field: 'governance.reviewStatus',
      );
    case ReviewStatus.verified:
      break;
  }

  DateTime? lastVerified;
  if (g.lastVerifiedDate == null) {
    if (isRegulated) {
      err(
        ValidationIssueCode.missingVerifiedDate,
        'Regulated content needs a last-verified date.',
        field: 'governance.lastVerifiedDate',
      );
    }
  } else {
    lastVerified = parseGovernanceDate(g.lastVerifiedDate!);
    if (lastVerified == null) {
      err(
        ValidationIssueCode.invalidDateFormat,
        'governance.lastVerifiedDate "${g.lastVerifiedDate}" is not an ISO-compatible date.',
        field: 'governance.lastVerifiedDate',
      );
    } else if (lastVerified.isAfter(referenceDate)) {
      err(
        ValidationIssueCode.implausibleDate,
        'governance.lastVerifiedDate is after the reference date.',
        field: 'governance.lastVerifiedDate',
      );
    }
  }

  DateTime? reviewDue;
  if (g.reviewDueDate == null) {
    if (isTimeSensitive) {
      err(
        ValidationIssueCode.missingReviewDueDate,
        'High-volatility content needs a review-due date.',
        field: 'governance.reviewDueDate',
      );
    }
  } else {
    reviewDue = parseGovernanceDate(g.reviewDueDate!);
    if (reviewDue == null) {
      err(
        ValidationIssueCode.invalidDateFormat,
        'governance.reviewDueDate "${g.reviewDueDate}" is not an ISO-compatible date.',
        field: 'governance.reviewDueDate',
      );
    } else {
      if (lastVerified != null && reviewDue.isBefore(lastVerified)) {
        err(
          ValidationIssueCode.implausibleDate,
          'governance.reviewDueDate is earlier than governance.lastVerifiedDate.',
          field: 'governance.reviewDueDate',
        );
      }
      if (referenceDate.isAfter(reviewDue)) {
        err(
          ValidationIssueCode.reviewOverdue,
          'governance.reviewDueDate has passed the injected reference date.',
          field: 'governance.reviewDueDate',
        );
      }
    }
  }

  if (isRegulated) {
    if (lesson.sources.isEmpty) {
      err(
        ValidationIssueCode.missingOfficialSource,
        'Regulated content needs at least one structured official source.',
        field: 'sources',
      );
    } else {
      for (final source in lesson.sources) {
        final issue = _sourceUrlIssue(lesson.id, source);
        if (issue != null) issues.add(issue);
      }
    }
    final hasBoundary = lesson.blocks.any((b) => b is EducationalBoundaryBlock);
    if (!hasBoundary) {
      err(
        ValidationIssueCode.missingEducationalDisclaimer,
        'Regulated content needs an educational-boundary block.',
        field: 'blocks',
      );
    }
  }

  if (isRegulated) {
    final hasRiskWarning = lesson.blocks.any((b) => b is RiskWarningBlock);
    if (!hasRiskWarning) {
      err(
        ValidationIssueCode.missingRiskWarning,
        'This topic needs at least one risk-warning block.',
        field: 'blocks',
      );
    }
  }

  final reviewedTexts = lesson.reviewedMythExamples
      .map((r) => r.text.trim())
      .toSet();
  var blockIndex = 0;
  for (final block in lesson.blocks) {
    final field = 'blocks[$blockIndex]';
    blockIndex++;
    for (final text in _scannableTexts(block)) {
      if (reviewedTexts.contains(text.trim())) continue;
      for (final pattern in _hardErrorPatterns) {
        if (pattern.pattern.hasMatch(text)) {
          err(pattern.code, pattern.message, field: field);
        }
      }
      _checkFigureContext(text, field, warn);
      _checkRiskContext(text, field, warn);
      _checkComparisonContext(text, field, warn);
      _checkProcessUniversality(text, field, warn);
    }
  }

  return ValidationResult(lessonId: lesson.id, issues: issues);
}
