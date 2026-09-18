// Dumps the Dart seed fixture as JSON so the TypeScript vector generator can
// run the PROTOTYPE'S algorithm over OUR data.
//
// This exists because the two fixtures have diverged: app/ carries entries the
// prototype never had (a pending card charge, an excluded duplicate, a
// transfer) which were added precisely to exercise paths the prototype's
// fixture cannot reach. Generating vectors from the prototype's OWN data and
// comparing them to Dart computed over different data would compare two
// unrelated numbers and call the agreement proof.
//
// So the split is: the ALGORITHM comes from the prototype, the DATA is ours,
// and this file is the bridge. Run:
//   flutter test test/tool/dump_fixture_test.dart --plain-name dump
// then paste the printed JSON where gen_report_vectors.ts reads it.
//
// Named *_test.dart because flutter test collects nothing else, and it only
// prints, so joining a CI run costs one trivially passing test.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

String _kind(AccountKind k) => switch (k) {
  AccountKind.cash => 'cash',
  AccountKind.bank => 'bank',
  AccountKind.gcash => 'gcash',
  AccountKind.maya => 'maya',
  AccountKind.debit => 'debit',
  AccountKind.investment => 'investment',
  AccountKind.receivable => 'receivable',
  AccountKind.credit => 'credit',
  AccountKind.loan => 'loan',
  AccountKind.mortgage => 'mortgage',
};

String _profile(ProfileEntity p) => switch (p) {
  ProfileEntity.personal => 'personal',
  ProfileEntity.household => 'household',
  ProfileEntity.business => 'business',
  ProfileEntity.sideHustle => 'side_hustle',
};

String _type(TransactionType t) => switch (t) {
  TransactionType.income => 'income',
  TransactionType.expense => 'expense',
  TransactionType.transfer => 'transfer',
};

String _status(TransactionStatus s) => switch (s) {
  TransactionStatus.pending => 'pending',
  TransactionStatus.confirmed => 'confirmed',
  TransactionStatus.reconciled => 'reconciled',
  TransactionStatus.duplicate => 'duplicate',
  TransactionStatus.corrected => 'corrected',
  TransactionStatus.excluded => 'excluded',
};

void main() {
  test('dump', () {
    final Map<String, Object?> out = <String, Object?>{
      'accounts': SeedData.accounts
          .map(
            (Account a) => <String, Object?>{
              'id': a.id,
              'kind': _kind(a.kind),
              'balance': a.balance,
              'profile': a.profile == null ? null : _profile(a.profile!),
            },
          )
          .toList(),
      'transactions': SeedData.transactions()
          .map(
            (Transaction t) => <String, Object?>{
              'id': t.id,
              'date': t.date,
              'amount': t.amount,
              'type': _type(t.type),
              'category': t.category,
              'subcategory': t.subcategory,
              'profile': t.profile == null ? null : _profile(t.profile!),
              'status': _status(t.status),
            },
          )
          .toList(),
    };
    // One line, so it can be redirected into a file without reflowing.
    // ignore: avoid_print
    print('FIXTURE_JSON_BEGIN${jsonEncode(out)}FIXTURE_JSON_END');
  });
}
