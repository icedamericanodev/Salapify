/// What Salapify may never say in its own voice, checked at RUNTIME.
///
/// ## Why this is a function and not a test
///
/// The four bans used to be a test that read two source files. That worked
/// for as long as every word Pan could say was typed into those two files.
/// The moment Pan could quote the Academy, the guard was still green and no
/// longer true: asking "what is an emergency fund" came back with three named
/// banks, a quoted rate of four to six percent per annum, and an instruction
/// to store money there. A securities review found it; the test could not,
/// because the test was looking at the wrong files.
///
/// So the rule moved from "which file was it typed in" to "what is about to
/// be shown to a person". Every passage Pan lifts from the curriculum goes
/// through [bannedPhraseIn] before it is emitted, and the same function backs
/// the test, over Pan's OUTPUT rather than its source.
///
/// ## The line, and why a government programme is not on the list
///
/// Under the Philippine rules on investment advice, what matters is whether
/// something advised on the ADVISABILITY of putting money into a product, not
/// whether a product was mentioned. So naming Pag-IBIG MP2, SSS or PhilHealth
/// when somebody asked about them by name is education and stays. Quoting
/// what MP2 pays, calling it the safest, or telling the reader to opt for
/// compounded dividends is advice, and goes.
///
/// A private company is different again: there is no version of Salapify
/// naming a particular bank as the place to keep savings that is not an
/// endorsement, so those names never appear in Salapify's own sentences. A
/// name the USER typed into their own account list is untouched by any of
/// this, and must be, or the assistant cannot say what they hold.
library;

/// Rates of return, and the words that turn a percentage into one.
///
/// A percentage is not banned on its own, deliberately. "A 10% to 20% final
/// withholding tax" is a fact about tax and a person is better off knowing
/// it; "4% to 6% per annum" is a forecast of what their money would earn.
/// Phrases that only ever introduce a quoted rate.
const List<String> _returnPhrases = <String>[
  'per annum',
  'p.a.',
  'apy',
  'dividend yield',
  'dividend yields',
  'annual return',
  'annual returns',
  'returns of',
  'rate of return',
  // NOT bare 'averaging'. The prototype writes "dividends averaging 6.5% to
  // 7%", which is the thing being banned, and the percentage-near-a-noun
  // rule below catches it on the figure. Banning the word itself also bans
  // cost averaging, which is the name of a technique and has no rate in it.
  'dividends averaging',
  'returns averaging',
];

/// Words that make a nearby PERCENTAGE a claim about what money earns.
///
/// The bare nouns used to be banned outright, and that was too blunt in a way
/// that cost the founder a round. "MP2 pays a dividend, and the rate is
/// declared once a year out of the Fund's net income, so it is not fixed when
/// you join" is education, it is the single most useful sentence about how
/// MP2 works, and the old rule made it unsayable. Meanwhile the thing the ban
/// exists for is a FIGURE: "often 5.5% to 7.5%".
///
/// So the noun is free and the number is not. A percentage within reach of
/// one of these is a quoted return; a percentage next to the word tax is a
/// fact about tax, and a person is better off knowing it.
const List<String> _returnNouns = <String>[
  'dividend',
  'dividends',
  'yield',
  'yields',
  'return',
  'returns',
  'earning',
  'earns',
  'interest rate',
  'grows',
  'growth',
];

/// How close a percentage has to sit to one of [_returnNouns] to be reading
/// as a quoted return rather than as an unrelated figure in the same
/// paragraph.
const int _nearby = 60;

/// A percentage presented as what money earns, or null.
String? _quotedReturn(String t) {
  for (final String phrase in _returnPhrases) {
    if (t.contains(phrase)) return phrase;
  }

  final RegExp percent = RegExp(r'\d+(?:\.\d+)?\s*(?:%|percent\b)');
  for (final RegExpMatch m in percent.allMatches(t)) {
    final int from = (m.start - _nearby).clamp(0, t.length);
    final int to = (m.end + _nearby).clamp(0, t.length);
    final String around = t.substring(from, to);
    for (final String noun in _returnNouns) {
      if (around.contains(noun)) return '${m.group(0)} near "$noun"';
    }
  }
  return null;
}

/// Private companies. Salapify never names one as somewhere to put money.
///
/// Kept apart from [_productClasses] below because of where each one may
/// appear. A company name is never acceptable in Salapify's own sentence. A
/// product CLASS is unacceptable in a claim and unavoidable in a citation:
/// one of the courses is called "High-Yield Digital Banking", and a rule that
/// forbade saying so would stop Pan naming the source of its own answer,
/// which is the thing that keeps the answer on the education side in the
/// first place. Naming a chapter is a reference. Telling somebody to open one
/// is a recommendation.
const List<String> _companies = <String>[
  'maribank',
  'gotyme',
  'seabank',
  'tonik',
  'komo',
  'cimb',
  'maya',
  'gcash',
  'bpi',
  'bdo',
  'unionbank',
  'union bank',
  'metrobank',
  'security bank',
  'rcbc',
  'landbank',
  'chinabank',
  'china bank',
  'eastwest',
  'east west',
  'atome',
  'billease',
  'home credit',
  'cashalo',
  'shopee',
  'lazada',
  'grab',
  'foodpanda',
  'jollibee',
  'starbucks',
];

/// Kinds of product. Banned in a claim, allowed inside a course's own name.
const List<String> _productClasses = <String>[
  'digital bank',
  'digital banks',
  'digital savings',
  'high-yield',
  'high yield',
  'index fund',
  'index funds',
  'mutual fund',
  'mutual funds',
  'uitf',
  'uitfs',
  'vul',
  'crypto',
];

/// Telling somebody where to put their money, or what to buy with it.
///
/// Scoped to instructions about a PLACE or a PRODUCT. A general norm is not
/// on this list on purpose: "freelancers should aim for six to nine months"
/// is a rule of thumb about the size of a fund, which the reader can weigh,
/// and stripping it would leave the curriculum unable to teach anything.
const List<String> _productImperatives = <String>[
  'store it in',
  'store them in',
  'park it',
  'park your',
  'park savings',
  'put your money in',
  'invest in',
  'invest your',
  'you must own',
  'must be deployed',
  'deploy',
  'opt for',
  'choose the best',
  'choose compounded',
  'switch to',
  'open an account with',
  'buy insurance',
  'buy term',
  'never invest',
  'keep savings',
  'keep spending money',
  'keep emergency funds',
  'maximize',
];

/// Saying a thing is good, which is the shortest possible recommendation.
const List<String> _endorsements = <String>[
  'safest',
  'highest-yielding',
  'highest yielding',
  'ideal for',
  'savvy savers prefer',
  'beat active',
  'guaranteed by the',
  'government guaranteed',
  'one of the best',
  'the best place',
  'the best way',
];

/// Professional standing Salapify has not got.
const List<String> _professionalTitles = <String>[
  'financial coach',
  'financial adviser',
  'financial advisor',
  'investment adviser',
  'investment advisor',
  'our cpa',
  'certified public accountant',
  'tax advisory',
  'we recommend',
  'our experts',
];

/// The offending phrase in [text], or null when it is safe for Pan to say.
///
/// Case-insensitive, and it returns the phrase rather than a bool so a
/// failing test names what it found instead of leaving somebody to diff two
/// paragraphs by eye.
String? bannedPhraseIn(String text, {bool asCitation = false}) {
  final String t = text.toLowerCase();

  // A citation is a NAME. Everything below this line is about what a
  // sentence asserts, and a name asserts nothing, so a citation is checked
  // for company names alone. Anything Pan writes itself goes through all of
  // it, which is every call that leaves asCitation at its default.
  for (final String w in _companies) {
    if (t.contains(w)) return w;
  }
  if (asCitation) return null;

  final String? rate = _quotedReturn(t);
  if (rate != null) return rate;
  for (final String w in _productClasses) {
    if (t.contains(w)) return w;
  }
  for (final String w in _productImperatives) {
    if (t.contains(w)) return w;
  }
  for (final String w in _endorsements) {
    if (t.contains(w)) return w;
  }
  for (final String w in _professionalTitles) {
    if (t.contains(w)) return w;
  }
  return null;
}

/// Whether a passage is safe to put in front of somebody in Pan's voice.
bool safeForPan(String text) => bannedPhraseIn(text) == null;

/// Whether a NAME is safe to quote as the source of an answer.
bool safeToCite(String name) => bannedPhraseIn(name, asCitation: true) == null;
