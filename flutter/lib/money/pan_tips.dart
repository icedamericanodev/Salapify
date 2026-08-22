// The tips Pan's floating helper shows, f4.65. Pure data, so a content test can
// assert every tip points at a real destination and says something true.
//
// The rule for a tip here: it describes a real Salapify feature in plain words
// and sends the person to the screen that actually does it, or opens Pan's
// canned Q&A. No tip claims a fact about the person's own money (that is what the
// coach and the cards on each screen do, from real figures); these are honest
// signposts, never invented numbers, and never an "AI" that makes things up.

/// Where a tip's button goes. Mapped to a shell Destination or to Pan by the
/// bubble; kept as its own enum here so this data file never imports the shell.
enum PanTipTarget { home, activity, insights, accounts, debts, askPan }

class PanTip {
  final String title;
  final String body;
  final String ctaLabel;
  final PanTipTarget target;

  /// For [PanTipTarget.askPan] only: the question to seed Pan with, or null to
  /// just open Pan. Ignored for every other target.
  final String? panQuestion;

  const PanTip({
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.target,
    this.panQuestion,
  });
}

/// The curated tips, in show order. Each is a true signpost to a shipped
/// feature, ending with the open door to Pan's plain-words Q&A.
const List<PanTip> panTips = [
  PanTip(
    title: 'What is safe to spend?',
    body:
        'On Accounts, your safe-to-spend buffer is the cash you can reach now, '
        'minus the bills and card minimums due in the next 14 days.',
    ctaLabel: 'Open Accounts',
    target: PanTipTarget.accounts,
  ),
  PanTip(
    title: 'How full are your cards?',
    body:
        'The Credit Radar on Debts shows how much of each card limit you are '
        'using, against the 30 percent healthy line.',
    ctaLabel: 'Open Debts',
    target: PanTipTarget.debts,
  ),
  PanTip(
    title: 'Which payoff order is cheaper?',
    body:
        'Compare Avalanche and Snowball on Debts and see the interest each one '
        'costs. They only differ once you pay above the minimums.',
    ctaLabel: 'Open Debts',
    target: PanTipTarget.debts,
  ),
  PanTip(
    title: 'Where did your money go?',
    body:
        'Insights breaks your spending down by category and shows the trend, so '
        'a heavy month is easy to spot.',
    ctaLabel: 'Open Insights',
    target: PanTipTarget.insights,
  ),
  PanTip(
    title: 'Ask Pan anything about your money',
    body:
        'Ask in plain words, even in Taglish, and Pan points you to the right '
        'screen. Pan reads only what is on your phone and never makes up a '
        'number.',
    ctaLabel: 'Ask Pan',
    target: PanTipTarget.askPan,
  ),
];
