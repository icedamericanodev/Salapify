/// The words Pan LISTENS for, kept apart from the words Pan SAYS.
///
/// This file exists because of a test failure, and the failure was the guard
/// working correctly on the wrong file. `pan_test.dart` forbids Salapify from
/// naming a financial product in its own voice, and it fired on `UITF`, which
/// was sitting in the list of phrases that RECOGNISE somebody asking for
/// investment advice.
///
/// Both things are right and they cannot live in one file. Pan has to know the
/// word in order to spot the question, and must never use the word in an
/// answer. So the trigger words live here, where nothing is ever shown to
/// anybody, and every string in `pan.dart` and `pan_knowledge.dart` stays
/// under the ban.
///
/// The split is the enforcement. Anything moved into this file to dodge the
/// guard would also stop being something Pan can say, because nothing here is
/// ever rendered.
library;

/// A question that is asking what to DO with money, rather than what the
/// figures ARE.
///
/// Checked before every other rule. "Where should I put my savings" contains
/// "savings", and answering it with a savings summary would be a confident
/// non-answer to the question actually being asked.
const List<String> adviceTriggers = <String>[
  'should i invest',
  'should i put',
  'where should i put',
  'where do i put',
  'where should i save',
  'best place',
  'best bank',
  'best fund',
  'which bank',
  'which fund',
  'is it worth buying',
  'should i buy',
  'should i borrow',
  'should i get a loan',
  'what should i do with',
  'recommend',
  'advice',
  'invest in',
  'crypto',
  'stocks',
  'mutual fund',
  'uitf',
  'insurance',
];

/// Which flavour of boundary answer to open with.
const List<String> investingWords = <String>[
  'invest',
  'stocks',
  'crypto',
  'fund',
];

const List<String> borrowingWords = <String>['borrow', 'loan'];
