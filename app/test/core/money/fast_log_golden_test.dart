import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/fast_log.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

/// Golden vectors for the fast-log parser, produced by RUNNING
/// src/utils/fastlog.ts under bun on these exact lines. Every expectation
/// below is copied from that output. If Dart disagrees, the port is wrong.
void main() {
  void vector(
    String input, {
    required bool valid,
    required TransactionType type,
    required double amount,
    required String merchant,
    required String category,
    String? person,
    AccountKind? account,
    ProfileEntity? profile,
  }) {
    test('"$input"', () {
      final FastLogResult r = parseFastLog(input);
      expect(r.isValid, valid, reason: 'isValid');
      expect(r.type, type, reason: 'type');
      expect(r.amount, amount, reason: 'amount');
      expect(r.merchant, merchant, reason: 'merchant');
      expect(r.category, category, reason: 'category');
      expect(r.person, person, reason: 'person');
      expect(r.accountKind, account, reason: 'accountKind');
      if (profile != null) expect(r.profile, profile, reason: 'profile');
    });
  }

  group('the founder\'s own example', () {
    vector(
      'Jollibee 500',
      valid: true,
      type: TransactionType.expense,
      amount: 500,
      merchant: 'Jollibee',
      category: 'Food & Dining',
      profile: ProfileEntity.personal,
    );
  });

  group('amount shapes', () {
    vector(
      'shopee 1,250.50 maya',
      valid: true,
      type: TransactionType.expense,
      amount: 1250.5,
      merchant: 'Shopee',
      category: 'Shopping & Personal',
      account: AccountKind.maya,
    );
    vector(
      'lazada 999.99 cc',
      valid: true,
      type: TransactionType.expense,
      amount: 999.99,
      // "Cc" survives in the merchant: card and bank hints are NOT stripped
      // from the text, only the wallet ones are. Prototype behaviour.
      merchant: 'Lazada Cc',
      category: 'Shopping & Personal',
      account: AccountKind.credit,
    );
    vector(
      '500',
      valid: true,
      type: TransactionType.expense,
      amount: 500,
      merchant: 'Quick Entry',
      category: 'Food & Dining',
    );
    vector(
      'jollibee',
      valid: false,
      type: TransactionType.expense,
      amount: 0,
      merchant: 'Jollibee',
      category: 'Food & Dining',
    );
    vector(
      '   ',
      valid: false,
      type: TransactionType.expense,
      amount: 0,
      merchant: '',
      category: 'Food & Dining',
    );
  });

  group('account hints', () {
    vector(
      'jollibee 250 gcash',
      valid: true,
      type: TransactionType.expense,
      amount: 250,
      merchant: 'Jollibee',
      category: 'Food & Dining',
      account: AccountKind.gcash,
    );
    vector(
      'kape 180 cash',
      valid: true,
      type: TransactionType.expense,
      amount: 180,
      merchant: 'Kape',
      category: 'Food & Dining',
      account: AccountKind.cash,
    );
    vector(
      'meralco 2840 bpi',
      valid: true,
      type: TransactionType.expense,
      amount: 2840,
      merchant: 'Meralco Bpi',
      category: 'Bills & Utilities',
      account: AccountKind.bank,
    );
  });

  group('type detection', () {
    vector(
      'sweldo 32500',
      valid: true,
      type: TransactionType.income,
      amount: 32500,
      merchant: 'Sweldo',
      category: 'Salary & Compensation',
    );
    vector(
      'client retainer 18500',
      valid: true,
      type: TransactionType.income,
      amount: 18500,
      merchant: 'Client Retainer',
      category: 'Business Revenue',
      profile: ProfileEntity.business,
    );
    vector(
      'transfer 5000 gcash',
      valid: true,
      type: TransactionType.transfer,
      amount: 5000,
      merchant: 'Transfer',
      category: 'Transfer',
      account: AccountKind.gcash,
    );
  });

  group('Taglish', () {
    vector(
      'padala kay nanay 8000 palawan',
      valid: true,
      type: TransactionType.expense,
      amount: 8000,
      merchant: 'Padala Kay Nanay Palawan',
      category: 'Family Support & Remittance',
      person: 'Nanay',
    );
    vector(
      'baon ni kuya 300',
      valid: true,
      type: TransactionType.expense,
      amount: 300,
      merchant: 'Baon Ni Kuya',
      category: 'Family Support & Remittance',
      person: 'Kuya',
    );
    vector(
      'ambag kuryente 1500',
      valid: true,
      type: TransactionType.expense,
      amount: 1500,
      merchant: 'Ambag Kuryente',
      category: 'Bills & Utilities',
      profile: ProfileEntity.household,
    );
    vector(
      'upa 12000',
      valid: true,
      type: TransactionType.expense,
      amount: 12000,
      merchant: 'Upa',
      category: 'Housing & Rent',
    );
    vector(
      'angkas 85 gcash',
      valid: true,
      type: TransactionType.expense,
      amount: 85,
      merchant: 'Angkas',
      category: 'Transport & Commute',
      account: AccountKind.gcash,
    );
    vector(
      'watsons 500',
      valid: true,
      type: TransactionType.expense,
      amount: 500,
      merchant: 'Watsons',
      category: 'Health & Medical',
    );
  });

  group('a preserved oddity', () {
    // "mp2" maps to an INCOME category while no income word fired, so the
    // parser returns an expense in Investment & Passive Income. The engine
    // reproduces it; the sheet is what refuses to select a category that does
    // not belong to the chosen type, because the picker could not show it.
    vector(
      'mp2 2000',
      valid: true,
      type: TransactionType.expense,
      amount: 2000,
      merchant: 'Mp2',
      category: 'Investment & Passive Income',
    );
  });

  test('every category the parser can return really exists', () {
    // This is the guard that would have caught the drift that prompted all of
    // this: the parser hands back a category NAME, and if the app's list
    // paraphrases it the entry is filed under a category nothing can show.
    final Set<String> known = SeedData.categories
        .map((CategoryInfo c) => c.name)
        .toSet();
    final Set<String> produced = fastLogCategoryKeywords.values.toSet()
      ..addAll(<String>[
        'Food & Dining',
        'Salary & Compensation',
        'Business Revenue',
        'Transfer',
      ]);

    final List<String> missing =
        produced.where((String c) => !known.contains(c)).toList()..sort();

    expect(
      missing,
      isEmpty,
      reason:
          'The fast-log parser can file an entry under these, and the app has '
          'no such category, so the entry would be filed under nothing: '
          '$missing',
    );
  });
}
