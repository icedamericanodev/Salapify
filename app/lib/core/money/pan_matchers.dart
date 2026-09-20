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
/// PHRASES THAT ASK FOR A DECISION, not nouns.
///
/// This list used to hold bare product words: uitf, crypto, stocks,
/// insurance. That was too blunt, and the founder found the cost of it. "What
/// is MP2" is a question about what a thing IS, and deflecting it taught
/// somebody that the app will not explain anything, while a whole Academy
/// course on exactly that sat unreachable in the same build.
///
/// The line is not the topic, it is the ask. Pan explains any of these
/// freely, from the curriculum, and stops at the point where somebody wants
/// to be told what to do with their own money.
const List<String> adviceTriggers = <String>[
  'should i invest',
  'should i put',
  'should i save',
  'where should i put',
  'where do i put',
  'where should i save',
  'where should i keep',
  'best place',
  'best bank',
  'best fund',
  'best investment',
  'which bank',
  'which fund',
  'which is better',
  'is it worth buying',
  'should i buy',
  'should i borrow',
  'should i get a loan',
  'should i open',
  'what should i do with',
  'what should i invest',
  'recommend',
  'is it a good idea',
  // Not 'is it a good idea' but 'a good idea', because the thing being asked
  // about goes in the middle: "is MP2 a good idea" slipped straight past the
  // boundary and got taught, which is the one shape that matters now that
  // Pan will explain a savings programme on request.
  'good idea',
  'worth it',
  'bad idea',
  'would you invest',
  'help me choose',
  'help me decide',
];

/// Which flavour of boundary answer to open with.
const List<String> investingWords = <String>[
  'invest',
  'stocks',
  'crypto',
  'fund',
];

const List<String> borrowingWords = <String>['borrow', 'loan'];

/// Words that mean SALAPIFY when somebody types them, not a money concept.
///
/// Same shape of problem as [reservedWords] below, one level up. The Academy
/// ships a course called "Digital Startups: NPC Data Privacy, NTC & Sectoral
/// Licenses", so "is my data private" scored higher against the curriculum
/// than against the privacy answer, and Pan replied to a question about this
/// phone with a lecture on startup compliance.
///
/// A question containing one of these is about the app, so the feature
/// answer is tried first and the curriculum second. Concepts are unaffected:
/// "what is an emergency fund" contains none of these and still teaches.
const List<String> appOwnWords = <String>[
  'salapify',
  'this app',
  'the app',
  'privacy',
  'private',
  'data',
  'backup',
  'back up',
  'restore',
  'export',
  'import',
  'offline',
  'sync',
  'screen',
  'tab',
  'notification',
  'reminder',
  'log an',
  'log a',
  'logging',
  'entry',
  'entries',
  'undo',
  'delete',
  'wipe',
  'sample data',
];

/// Single words that belong to a QUESTION, not to an account.
///
/// An account match runs before every topic, because a name is the most
/// specific thing somebody can ask about. That is right until the name IS a
/// question word: an account called "Due" then answered "what bills are due",
/// and one called "Cash" always beat the question about total cash.
///
/// So a one-word account name that appears here loses to the topic. A longer
/// name containing one of these is unaffected, because "Due Payments Card" is
/// unambiguously a name.
const List<String> reservedWords = <String>[
  'cash',
  'money',
  'due',
  'bill',
  'bills',
  'budget',
  'limit',
  'goal',
  'target',
  'owe',
  'owed',
  'debt',
  'payday',
  'sweldo',
  'worth',
  'overall',
  'spending',
  'biggest',
  'receivable',
  'ipon',
  'lampas',
  'magkano',
  'bayarin',
  'upcoming',
  'save',
  'pay',
  'spend',
];
