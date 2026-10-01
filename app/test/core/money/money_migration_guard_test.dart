import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The P2.1 check, usable from the first day of the migration rather than the
/// last.
///
/// The sprint prompt's done-when for P2.1 is "a CI check or test that fails if
/// a money field is `double`". Written as a flat ban, that test is red from the
/// moment it is added until every one of the app's money fields has moved,
/// which is several sittings. A test that is red on purpose for a week gets
/// ignored, and then it is not there for the real thing.
///
/// So it is a SHRINKING LIST instead. Every `double` field still in the models
/// is named below. The test fails two ways:
///
///   - a field appears that is not on the list, which is a NEW double money
///     field, the thing the ban exists to stop; and
///   - a field on the list is gone, which means it migrated and the list is
///     now claiming work that is finished.
///
/// Both halves matter. Without the second the list would be a permanent
/// amnesty, and the count below would stop meaning anything.
void main() {
  /// Money fields still held as a double. THIS LIST ONLY SHRINKS.
  const Set<String> notYetMoney = <String>{
    'amount',
    'amountReserved',
    'balance',
    'creditLimit',
    'currentAmount',
    'emergencyBuffer',
    'expectedAmount',
    'expectedIncome',
    'installmentAmount',
    'interestRemaining',
    'limit',
    'monthlyTarget',
    'paidAmount',
    'principal',
    'principalRemaining',
    'reservedBills',
    'reservedDebtMinimums',
    'reservedInstallments',
    'runningBalance',
    'safeToSave',
    'safeToSpendToday',
    'safeToSpendUntilPayday',
    'targetAmount',
    'totalAmount',
    'totalExpectedInflow',
    'totalInterest',
    'totalLiquidCash',
    'totalPayable',
  };

  /// Doubles that are NOT money and never become [Money].
  ///
  /// A rate is a ratio and a count of months is a duration. Forcing either
  /// into a centavo type would be the same category error as holding a peso in
  /// a double, pointing the other way.
  const Set<String> notMoney = <String>{'interestRate', 'cashRunwayMonths'};

  Set<String> doubleFieldsInModels() {
    final String src = File('lib/models/models.dart').readAsStringSync();
    final RegExp decl = RegExp(
      r'^\s*final\s+double\??\s+(\w+)\s*;',
      multiLine: true,
    );
    return decl.allMatches(src).map((RegExpMatch m) => m.group(1)!).toSet();
  }

  test('no NEW money field arrives as a double', () {
    final Set<String> found = doubleFieldsInModels();
    final Set<String> unexpected = found.difference(
      notYetMoney.union(notMoney),
    );
    expect(
      unexpected,
      isEmpty,
      reason:
          'These double fields are not accounted for. If one holds money it '
          'belongs in Money (core/money/money.dart); if it is a rate or a '
          'duration, add it to notMoney with the reason.',
    );
  });

  test('and the list of remaining work does not claim finished work', () {
    final Set<String> found = doubleFieldsInModels();
    final Set<String> alreadyDone = notYetMoney.difference(found);
    expect(
      alreadyDone,
      isEmpty,
      reason:
          'These moved to Money, so take them off notYetMoney. The count in '
          'docs/PROGRESS.md is read off this list and has to stay true.',
    );
  });

  test('the migration is not silently finished or silently abandoned', () {
    // A number here so the progress note cannot drift from the code. When it
    // reaches zero, P2.1 is done and this file becomes the flat ban the sprint
    // prompt asked for.
    expect(
      notYetMoney.length,
      28,
      reason:
          'Fields left to migrate changed. Update this figure AND the P2.1 '
          'row in docs/PROGRESS.md in the same commit, so the two cannot '
          'disagree.',
    );
  });
}
