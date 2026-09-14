// The parser's RULES, as opposed to its vocabulary.
//
// fastlog_golden_test.dart holds the table of what specific lines mean. This
// file holds the promises that must survive any change to that table, and all
// three of them are about being wrong LESS OFTEN rather than right more often.
//
// The asymmetry matters and is worth stating once. A category the person taps
// themselves costs one tap. A WRONG category they never notice quietly poisons
// every budget and every report that reads it, for months, and nobody goes
// looking for it because nothing looks broken.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/data/backup.dart';
import 'package:salapify/core/money/fastlog.dart';

/// The eight the app ships with, as they exist in a real ledger.
final _defaults = defaultCategories.map((c) => {...c}).toList();

void main() {
  group('rule 1: no keyword match means no guess', () {
    test('an unknown merchant gets no category at all', () {
      final p = parseLogLine('zorbtronic 450', categories: _defaults);
      expect(p.amount, 450.0);
      expect(p.label, 'Zorbtronic');
      expect(
        p.categoryId,
        isNull,
        reason:
            'the parser invented a category for a word it has never seen. '
            'Silence is the correct answer here.',
      );
    });

    test('so does a line of pure numbers', () {
      expect(parseLogLine('500', categories: _defaults).categoryId, isNull);
    });
  });

  group('the words a Filipino actually types', () {
    test('the everyday meal words, including the verb', () {
      // Found on a real phone, not in a test. The founder typed "kain 120" on
      // an emulator and got an untagged entry, while "kainan" was already in
      // the table. A vocabulary gap is invisible to every rule test in this
      // file, because the rules were all working perfectly.
      for (final line in [
        'kain 120',
        'pagkain 250',
        'almusal 80',
        'tanghalian 150',
        'hapunan 200',
        // Both spellings. Salapify's own copy writes it "meryenda", so the app
        // would not have understood a word it puts on its own screens.
        'meryenda 60',
        'merienda 60',
      ]) {
        expect(
          parseLogLine(line, categories: _defaults).categoryId,
          'cat_food',
          reason: '"$line" is food and the parser did not know it',
        );
      }
    });

    test('a longer word is not swallowed by a shorter one', () {
      // Matching is whole token, so "kain" cannot reach into a word that
      // merely contains it. Worth pinning: switching to a substring match
      // would look like an improvement and would start tagging by accident.
      expect(
        parseLogLine('kaingin 300', categories: _defaults).categoryId,
        isNull,
        reason: 'a substring match leaked: kaingin is not a meal',
      );
    });
  });

  group('rule 2: a guess must point at a category that still exists', () {
    test('a deleted category is never guessed', () {
      // The person deleted Food. The keyword table still knows the word, and
      // that is exactly the trap: without this rule the transaction would be
      // tagged with an id nothing in the ledger can resolve, and it would show
      // up as a blank in every report that groups by category.
      final withoutFood = _defaults
          .where((c) => c['id'] != 'cat_food')
          .toList();

      expect(
        parseLogLine('jollibee 250', categories: _defaults).categoryId,
        'cat_food',
        reason: 'the setup is wrong if this does not match to begin with',
      );
      expect(
        parseLogLine('jollibee 250', categories: withoutFood).categoryId,
        isNull,
        reason: 'guessed a category id that is not in the ledger any more',
      );
    });

    test('the rest of the line still parses when the guess is dropped', () {
      final withoutFood = _defaults
          .where((c) => c['id'] != 'cat_food')
          .toList();
      final p = parseLogLine('jollibee 250', categories: withoutFood);
      // Losing the category must not lose the entry. This is the difference
      // between a downgraded guess and a broken parse.
      expect(p.amount, 250.0);
      expect(p.label, 'Jollibee');
      expect(p.type, 'expense');
    });
  });

  group('rule 3: never a category for income or a transfer', () {
    test('income takes no category even when a keyword is present', () {
      // "refund" makes this income, and "jollibee" would otherwise tag it
      // Food. Tagging money COMING IN with a spending category would put it
      // on the wrong side of every budget that reads it.
      final p = parseLogLine('jollibee refund 250', categories: _defaults);
      expect(p.type, 'income');
      expect(p.categoryId, isNull);
    });

    test('a transfer takes no category either', () {
      // A transfer is the person's own money moving between their own
      // accounts. Nothing was spent, so a spending category would double
      // count it.
      final p = parseLogLine('transfer to grab 500', categories: _defaults);
      expect(p.type, 'transfer');
      expect(p.categoryId, isNull);
    });
  });

  group('transfer beats income, deliberately', () {
    test('a deposit is a transfer and not money earned', () {
      // The dangerous reading. "deposit 5000" is almost always the person
      // moving their own cash into a bank, and calling it income would invent
      // five thousand pesos of earnings that never happened.
      expect(parseLogLine('deposit 5000').type, 'transfer');
    });
  });

  group('the label keeps the spelling a person will read back', () {
    test('a word with interior capitals is left alone', () {
      // Flattening this to "Gcash" would be the app correcting the user's own
      // spelling of a brand they see every day.
      expect(parseLogLine('GCash 200').label, 'GCash');
    });

    test(
      'the label is cut from the raw text, never from the folded tokens',
      () {
        // normalize() lowercases, strips punctuation and folds Taglish to
        // English, which is right for matching keywords and wrong for a name.
        // "sweldo" must not come back as "payday".
        expect(parseLogLine('sweldo 42000').label, 'Sweldo');
      },
    );
  });

  group('understood', () {
    test('is false for an empty line, so the sheet shows nothing', () {
      expect(parseLogLine('').understood, isFalse);
      expect(parseLogLine('   ').understood, isFalse);
    });

    test('is true as soon as there is a word or a number', () {
      expect(parseLogLine('j').understood, isTrue);
      expect(parseLogLine('50').understood, isTrue);
    });
  });

  test('every keyword points at a category the app actually ships', () {
    // A typo in the table would otherwise produce a guess that rule 2 silently
    // drops for every user forever, which looks exactly like the keyword
    // simply not being there.
    final shipped = {for (final c in defaultCategories) c['id'] as String};
    final pointed = categoryKeywords.values.toSet();
    expect(
      pointed.difference(shipped),
      isEmpty,
      reason: 'these keywords point at category ids that do not exist',
    );
  });
}
