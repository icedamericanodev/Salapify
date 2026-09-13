// The parse fixture: one line in, one reading out.
//
// This is here so the keyword vocabulary can GROW without anyone silently
// changing what an existing line already means. Adding "landers" to groceries
// should be a one-line diff; quietly turning "grab 250" from transport into
// food should be impossible to do by accident. A table makes both visible.
//
// It is the same contract .claude/skills/porting-money-logic uses for ported
// arithmetic, applied to new work: the expected values are written down by
// hand, not captured from the code's own output, because a fixture generated
// from the implementation only ever proves the implementation equals itself.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/fastlog.dart';
import 'package:salapify/core/money/taglish.dart';

/// One row: what somebody typed, and what it should mean.
typedef Case = (
  String line,
  String type,
  double? amount,
  String label,
  String? cat,
);

const _cases = <Case>[
  // The canonical example, from 01-vision.md principle 1 and the Log mockup.
  ('jollibee 250', 'expense', 250.0, 'Jollibee', 'cat_food'),

  // Amount forms. The value comes from extractAmount, which is golden locked,
  // so these guard the LABEL cut around each shape rather than the parsing.
  ('salary 42000', 'income', 42000.0, 'Salary', null),
  ('groceries 2,450.50', 'expense', 2450.5, 'Groceries', 'cat_groceries'),
  ('rent 12k', 'expense', 12000.0, 'Rent', 'cat_bills'),
  ('load 100', 'expense', 100.0, 'Load', 'cat_load'),

  // A currency mark must not survive into the label as its own word.
  ('grab ₱180', 'expense', 180.0, 'Grab', 'cat_transport'),

  // The number first, with a connective the label cut has to drop.
  ('250 for jollibee', 'expense', 250.0, 'Jollibee', 'cat_food'),

  // Taglish, folded by normalize's golden-locked table rather than by any
  // vocabulary of this file's own.
  ('sweldo 42000', 'income', 42000.0, 'Sweldo', null),
  ('sahod 38000', 'income', 38000.0, 'Sahod', null),
  ('pamasahe 45', 'expense', 45.0, 'Pamasahe', 'cat_transport'),
  ('kuryente 3200', 'expense', 3200.0, 'Kuryente', 'cat_bills'),
  ('gamot 850', 'expense', 850.0, 'Gamot', 'cat_health'),
  (
    'padala kay nanay 5000',
    'expense',
    5000.0,
    'Padala Kay Nanay',
    'cat_padala',
  ),

  // Transfer beats income. "deposit 5000" moves money the person already has;
  // reading it as income would invent money that does not exist.
  ('deposit 5000', 'transfer', 5000.0, 'Deposit', null),
  ('transfer 3000', 'transfer', 3000.0, 'Transfer', null),
  ('withdraw 2000', 'transfer', 2000.0, 'Withdraw', null),

  // No keyword match: an expense with no category, which is the honest answer.
  ('haircut 300', 'expense', 300.0, 'Haircut', null),
  ('random thing 99', 'expense', 99.0, 'Random Thing', null),

  // Multi-word merchants keep their real spelling and their capitals.
  ('mang inasal 320', 'expense', 320.0, 'Mang Inasal', 'cat_food'),

  // A number with no words at all. The amount is the whole of the meaning.
  ('500', 'expense', 500.0, '', null),

  // Words with no number: still worth reading, because the sheet shows the
  // label back while the person is mid-type.
  ('jollibee', 'expense', null, 'Jollibee', 'cat_food'),

  // Nothing at all.
  ('', 'expense', null, '', null),
  ('   ', 'expense', null, '', null),
];

void main() {
  group('the parse fixture', () {
    for (final (line, type, amount, label, cat) in _cases) {
      test('"$line"', () {
        final p = parseLogLine(line);
        expect(p.type, type, reason: 'type');
        expect(p.amount, amount, reason: 'amount');
        expect(p.label, label, reason: 'label');
        expect(p.categoryId, cat, reason: 'category');
      });
    }

    test('the fixture is not empty and covers all three types', () {
      // Without this the loop above passes perfectly over a truncated list,
      // and a table-driven test with no rows is the quietest possible pass.
      expect(_cases.length, greaterThanOrEqualTo(20));
      expect(_cases.map((c) => c.$2).toSet(), {
        'expense',
        'income',
        'transfer',
      });
    });
  });

  test('the label cut never disagrees with the golden amount reader', () {
    // The parser finds the number's POSITION with its own regex so it can cut
    // the label around it, while the VALUE always comes from extractAmount.
    // Two readers of the same text is a real risk, so it is checked rather
    // than trusted: for every fixture line, the amount the parser reports is
    // exactly what the golden-locked extractor reports on its own.
    for (final (line, _, _, _, _) in _cases) {
      expect(
        parseLogLine(line).amount,
        extractAmount(line),
        reason: '"$line": the parser and extractAmount read different numbers',
      );
    }
  });
}
