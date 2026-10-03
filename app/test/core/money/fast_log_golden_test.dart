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

  group('the category is either known or admitted to be unknown', () {
    // The founder typed "Electricity" on the emulator and the sheet selected
    // Food & Dining. The parser's fallback IS 'Food & Dining', so every word
    // it had never seen produced that answer with full confidence. Measured
    // at the time: 37 of 60 common English money words behaved this way.
    //
    // These are NOT prototype vectors. The prototype has the same defect, and
    // the block below is the divergence, which is why it is grouped and
    // labelled separately from everything above.

    test('"Electricity 1500" is a utility bill, not lunch', () {
      final FastLogResult r = parseFastLog('Electricity 1500');
      expect(r.category, 'Bills & Utilities');
      expect(r.categoryMatched, isTrue);
    });

    test('a word the parser does not know admits it', () {
      final FastLogResult r = parseFastLog('Xylophone 1500');
      expect(
        r.categoryMatched,
        isFalse,
        reason: 'nothing in the line named a category, so nothing chose one',
      );
      // The engine still RETURNS the prototype's fallback, deliberately. The
      // port stays faithful in what it computes; the flag is what lets the
      // sheet decline to apply it. If this ever stops being 'Food & Dining'
      // the divergence has leaked from the UI into the engine.
      expect(r.category, 'Food & Dining');
    });

    test('the plain English words the founder would actually type', () {
      const Map<String, String> expected = <String, String>{
        'electricity': 'Bills & Utilities',
        'water': 'Bills & Utilities',
        'internet': 'Bills & Utilities',
        'mortgage': 'Housing & Rent',
        'groceries': 'Groceries',
        'dentist': 'Health & Medical',
        'pharmacy': 'Health & Medical',
        'hospital': 'Health & Medical',
        'haircut': 'Shopping & Personal',
        'cinema': 'Entertainment & Leisure',
        'installment': 'Debt & Loan Servicing',
      };
      final List<String> wrong = <String>[];
      expected.forEach((String word, String category) {
        final FastLogResult r = parseFastLog('$word 500');
        if (r.category != category || !r.categoryMatched) {
          wrong.add('$word -> ${r.category} (matched ${r.categoryMatched})');
        }
      });
      expect(wrong, isEmpty, reason: 'these landed somewhere else: $wrong');
    });

    test('the deliberately ambiguous words are left unmatched', () {
      // Each of these names no category on its own: a restaurant bill and an
      // electricity bill are both "the bill". Guessing is the defect being
      // fixed, so they must fall through rather than be quietly added later.
      for (final String word in <String>[
        'bill',
        'payment',
        'phone',
        'power',
        'refund',
      ]) {
        final FastLogResult r = parseFastLog('$word 500');
        expect(
          r.categoryMatched,
          isFalse,
          reason:
              '"$word" cannot be read without context, so it must not '
              'claim a category',
        );
      }
    });
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
