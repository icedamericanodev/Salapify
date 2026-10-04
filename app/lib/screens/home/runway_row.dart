import 'package:flutter/material.dart';

import '../../core/money/daily_projection.dart';
import '../../core/money/format.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../state/financial_state.dart';
import 'home_kit.dart';

/// The Sweldo Runway, on Home.
///
/// EVERY OTHER FIGURE IN SALAPIFY IS AN AMOUNT. This one is a DATE, and that
/// is the whole reason it exists: "you run short on Monday 12 Oct" is
/// something a person can act on today, by moving a bill or bringing money
/// back from an account they set aside. "Safe to Spend is 15,173" is
/// something they can only obey.
///
/// IT IS A ROW, NEVER A HERO, and that was a decision rather than a default.
/// Home already has one hero and it is Safe to Spend. Two large figures about
/// the same money on one screen means the person has to referee them, which
/// is exactly the two-readings-of-one-ledger problem the engine's own header
/// warns about, except now both opinions are visible at once. So this is
/// fixed height and fixed position, and it goes loud by COLOUR and ICON,
/// never by size.
///
/// It is also not a card that appears only in a crisis. A card nobody has
/// ever seen, turning up at the worst possible moment in an unfamiliar place
/// and asking to be trusted, is how an alarm gets ignored. Nine quiet visits
/// are how somebody learns where the line lives.
class RunwayRow extends StatelessWidget {
  const RunwayRow({
    super.key,
    required this.state,
    required this.onSeeDue,
    required this.onSetPayday,
    required this.onInfo,
  });

  final FinancialState state;
  final VoidCallback onSeeDue;
  final VoidCallback onSetPayday;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(state.theme);
    final DailyProjection proj = state.dailyProjection;
    final _Runway? r = _read(proj, state);

    // S0, a ten second old install. THE ROW DOES NOT RENDER, and this is a
    // stated exception rather than an oversight. There is no figure to show,
    // and the only two doors it could offer are already open directly above
    // it: the Today row's "Log one" and the hero's "Payday not set". A third
    // ask stacked under those two is a nag, and Home deleted its standing
    // banners once already for exactly that.
    if (r == null) return const SizedBox.shrink();

    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        onTap: onSeeDue,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: r.border(p)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconTile(
                palette: p,
                icon: r.icon,
                background: r.tile(p),
                foreground: r.ink(p),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        // A FIGURE, not a lesson. It answers "why does it stop
                        // there" without spending a sentence on it.
                        //
                        // FLEXIBLE AND WRAPPING, in that order, and the second
                        // half was learned by getting it wrong. At 320dp this
                        // kicker beside a 44dp info dot overflowed by four
                        // pixels, and the dot cannot shrink without dropping
                        // under the touch-target floor, so the label is what
                        // gives. Ellipsis was the first fix and the
                        // readability sweep rejected it at 1.5x system font:
                        // "NEXT 45 DAYS is cut off". Trading an overflow for
                        // a truncation is not a fix. Wrapping costs a line at
                        // a font size somebody chose, and loses no words.
                        Flexible(
                          child: Text('NEXT 45 DAYS', style: AppType.kicker(p)),
                        ),
                        const Spacer(),
                        InfoDot(
                          color: p.textMuted,
                          semanticLabel: 'How the runway is worked out',
                          onTap: onInfo,
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text.rich(
                      // Text.rich, NOT RichText. RichText renders its span
                      // style verbatim, and a style with no family falls back
                      // to the platform face, which in the shot harness is a
                      // row of solid boxes. AppType names the family.
                      TextSpan(
                        style: AppType.rowTitle(p),
                        children: <InlineSpan>[
                          TextSpan(text: r.lead),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: r.read,
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (r.paydayNote != null) ...<Widget>[
                      const SizedBox(height: Spacing.sm),
                      Text(r.paydayNote!, style: AppType.caption(p)),
                      const SizedBox(height: Spacing.xs),
                      _Pill(
                        palette: p,
                        label: 'Set payday',
                        onTap: onSetPayday,
                      ),
                    ],
                    // ONE divider for all the notices, never one each.
                    // Three dividers turn a card into a form.
                    if (r.hasNotice) ...<Widget>[
                      const SizedBox(height: Spacing.sm),
                      Divider(height: 1, color: p.border),
                      const SizedBox(height: Spacing.sm),
                    ],
                    if (r.notCounted != null)
                      _Notice(
                        palette: p,
                        noticeKey: const Key('runway-not-counted'),
                        label: 'Not counted: ',
                        body: r.notCounted!,
                      ),
                    // ITS OWN LINE, not appended to the one above, and the
                    // reason is logical rather than spatial: a duplicated
                    // outflow IS counted, twice. Hanging it off a sentence
                    // that opens with the words "Not counted" would make
                    // that sentence lie about its own subject, and that holds
                    // however short the clause is.
                    if (r.countedOnce != null) ...<Widget>[
                      if (r.notCounted != null)
                        const SizedBox(height: Spacing.xs),
                      _Notice(
                        palette: p,
                        noticeKey: const Key('runway-counted-once'),
                        label: 'Counted once: ',
                        body: r.countedOnce!,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Spacing.xs),
              Icon(Icons.chevron_right, size: 18, color: p.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the row says, worked out once.
class _Runway {
  const _Runway({
    required this.lead,
    required this.read,
    required this.icon,
    required this.tone,
    this.paydayNote,
    this.notCounted,
    this.countedOnce,
  });

  /// The bold clause: the ANSWER, which is a day.
  final String lead;

  /// The plain clause: the figure needed to read it.
  final String read;

  final IconData icon;
  final _Tone tone;

  /// Only where a missing payday rule could cause a WRONG decision.
  final String? paydayNote;

  /// What is real, owed, and deliberately not in the figure above.
  final String? notCounted;

  /// Income left out because the payday rule already described it.
  final String? countedOnce;

  bool get hasNotice => notCounted != null || countedOnce != null;

  Color border(Palette p) => tone == _Tone.bad ? p.negative : p.border;
  Color tile(Palette p) => switch (tone) {
    _Tone.bad => p.negativeSoft,
    _Tone.warn => p.warningSoft,
    _Tone.quiet => p.surfaceAlt,
    _Tone.ok => p.iconTile,
  };
  Color ink(Palette p) => switch (tone) {
    _Tone.bad => p.negative,
    _Tone.warn => p.warning,
    _Tone.quiet => p.textMuted,
    _Tone.ok => p.accent,
  };
}

enum _Tone { bad, warn, ok, quiet }

/// The state machine. FIRST MATCH WINS, and the order is the design.
_Runway? _read(DailyProjection p, FinancialState state) {
  final bool nothingDated = p.days.every((ProjectedDay d) => d.events.isEmpty);
  final bool nothingAtAll =
      nothingDated &&
      p.openingBalance.isZero &&
      p.overdueOutflowCount == 0 &&
      p.undatedOutflowCount == 0;

  // S0: a brand new install. No row at all.
  if (nothingAtAll) return null;

  final String? aside = _notCounted(p);
  final String? once = _countedOnce(p);
  final String? payday = state.payday.hasRule
      ? null
      : 'Only one payday is counted, because Salapify does not know your '
            'payday days yet.';

  // S1: money, or things it could not place, but nothing on the calendar.
  if (nothingDated) {
    return _Runway(
      lead: 'Nothing is dated yet.',
      read:
          'Put a due date on a bill and this will name the day that gets '
          'tight.',
      icon: Icons.event_busy_outlined,
      // No accent. A blank state drawn in the alert colour reads as an alert.
      tone: _Tone.quiet,
      notCounted: aside,
      countedOnce: once,
    );
  }

  // S2: already short TODAY. No payday qualifier here, deliberately: a
  // missing rule cannot change what is due today, so it would be noise in
  // the one state that has to be clean.
  final ProjectedDay first = p.days.first;
  if (first.balanceAfter.isNegative) {
    return _Runway(
      lead: 'Short today.',
      read:
          "Today's dated bills come to "
          '${formatPeso(first.balanceAfter.pesos.abs(), showDecimals: false)} '
          'more than your spendable cash.',
      icon: Icons.priority_high,
      tone: _Tone.bad,
      notCounted: aside,
      countedOnce: once,
    );
  }

  // S3: runs short later. The date is the FIRST crossing, never the tightest
  // day: the lowest point may come after a payment has already bounced, and
  // the first crossing is the day somebody has to act before.
  final ProjectedDay? short = p.firstShortfall;
  if (short != null) {
    return _Runway(
      lead:
          'You run short on '
          '${formatDayAndDate(short.date, now: p.days.first.date)}.',
      read:
          '${formatPeso(short.balanceAfter.pesos.abs(), showDecimals: false)}'
          ' short that day.',
      icon: Icons.priority_high,
      tone: _Tone.bad,
      // THE ONE STATE WHERE THIS STAYS ON THE CARD. With no stored rule the
      // projection places a single payday, so it is systematically
      // pessimistic, and a shortfall it predicts may be a FALSE ALARM about
      // money. Telling somebody they run out on the 12th when two more
      // sweldos land first is the worst thing this card can do. In the
      // comfortable states below the same pessimism errs safely, so there it
      // goes behind the dot.
      paydayNote: payday,
      notCounted: aside,
      countedOnce: once,
    );
  }

  final ProjectedDay? tight = p.tightestDay;
  if (tight == null) return null;

  // S4: a REAL trough, where the balance climbs back after the low point.
  //
  // The discriminator is the whole reason this state exists separately. The
  // first version of this card said "tightest day" in every comfortable case,
  // and on a ledger with no income after its last outflow that sentence is a
  // fake insight: tightestDay uses a strict less-than, so it returns the
  // EARLIEST day at the minimum, which on a line that only falls is simply
  // the last day anything was scheduled. "You still have 73,081 on the 26th"
  // was "at the end of your projection you have 73,081" with a date stapled
  // to it.
  if (p.closingBalance > tight.balanceAfter) {
    return _Runway(
      lead:
          'Tightest day: '
          '${formatDayAndDate(tight.date, now: p.days.first.date)}.',
      read:
          'You still have '
          '${formatPeso(tight.balanceAfter.pesos, showDecimals: false)} then, '
          'and it climbs back after.',
      icon: Icons.trending_down,
      // Warning, not alert. Nothing is wrong, and a red block on a screen
      // with nothing wrong with it teaches people to ignore the red block
      // that matters.
      tone: _Tone.warn,
      notCounted: aside,
      countedOnce: once,
    );
  }

  // S5: flat or declining to the end. The claim is about the whole window, so
  // the window's end is the honest date: naming the 26th here would invite
  // "and then what?" when the answer is "nothing".
  return _Runway(
    lead: 'Nothing dated runs you short.',
    read:
        '${formatPeso(p.closingBalance.pesos, showDecimals: false)} left on '
        '${formatDayAndDate(p.days.last.date, now: p.days.first.date)}, and '
        'that is the lowest it gets.',
    icon: Icons.check_circle_outline,
    tone: _Tone.ok,
    notCounted: aside,
    countedOnce: once,
  );
}

/// The line that keeps a comfortable figure from misleading.
///
/// Under the founder rule of 2026-09-18 a lesson goes behind the dot, with one
/// exception: anything a person needs in order to avoid a WRONG CONCLUSION
/// stays on the screen. This is that exception, and the reason is sharper than
/// "the number is big". It is that these pesos are EXCLUDED from the figure
/// beside them and the card gives no other sign of it. "73,082 left, and that
/// is the lowest it gets" is a complete, confident sentence with real unpaid
/// bills sitting outside it.
///
/// NO TOTAL IS PRINTED. Each figure comes straight off the engine, because a
/// screen that adds money is a screen doing arithmetic.
String? _notCounted(DailyProjection p) {
  final List<String> parts = <String>[];
  if (p.overdueOutflowCount > 0) {
    parts.add(
      '${formatPeso(p.overdueOutflow.pesos)} overdue across '
      '${p.overdueOutflowCount} '
      '${p.overdueOutflowCount == 1 ? "item" : "items"}',
    );
  }
  if (p.undatedOutflowCount > 0) {
    // "Salapify could read" was cut on 2026-10-04. Those four words bought
    // the entire third line of this block on the founder's own ledger, and
    // the lesson they carry is already written in full behind the "i" dot,
    // under "Only dates Salapify can read". The card was paying a line to
    // repeat its own explainer, which is exactly what the 2026-09-18 rule
    // says to stop doing: a figure and the line needed to READ it stay, what
    // TEACHES goes behind the dot.
    parts.add('${formatPeso(p.undatedOutflow.pesos)} with no due date');
  }

  if (parts.isEmpty) return null;
  return 'Not counted: ${parts.join(', and ')}.';
}

/// D27's other half: the income this projection deliberately left out of a
/// total because something else already described it.
///
/// THE FIGURE LEADS, and that is the correction rather than a style choice.
/// This sentence used to carry no peso amount at all. Judge it on the case it
/// exists for: somebody genuinely paid 32,500 twice in one month, hunting for
/// a missing 32,500. The one line standing between them and silence did not
/// contain a number, while every other exclusion on this card leads with its
/// figure.
///
/// "COMING UP", NOT "UPCOMING". It said "in Upcoming" for a day, and no
/// screen in Salapify is called Upcoming: the Home card is "Coming Up" and
/// the sheet is "Bills". `UpcomingItem` is a class name, and printing a class
/// name at somebody sends them nowhere.
///
/// NAMES ARE DE-DUPLICATED. A day-of-month income date recurs, so one sweldo
/// written down twice produces two suppressed occurrences carrying the SAME
/// label, and the two-item wording would have read "Sweldo and Sweldo". The
/// count comes from the occurrences, the names from the distinct set.
String? _countedOnce(DailyProjection p) {
  if (!p.suppressedIncome.isPositive) return null;

  final List<String> names = p.duplicateIncomeLabels.toSet().toList();
  final String figure = formatPeso(p.suppressedIncome.pesos);
  const String places = 'in Coming Up and in your payday rule';

  if (names.length == 1 && p.duplicateIncomeLabels.length == 1) {
    return 'Counted once: $figure. ${names.first} is $places.';
  }
  if (names.length == 2) {
    return 'Counted once: $figure. ${names.first} and ${names[1]} are $places.';
  }
  // One name arriving several times, or more than two names: lean on the
  // total and the count rather than listing.
  return 'Counted once: $figure across ${p.duplicateIncomeLabels.length} '
      'items that are $places.';
}

/// One exclusion notice: a bold label, then the figures.
///
/// THE SPLIT COSTS NOTHING AND BUYS EVERYTHING. A user panel read the old
/// single grey paragraph and two of three archetypes said they would never
/// read it, at any visit. It was three lines of the faintest text on Home,
/// under a divider, below a bold sentence that already sounded like a
/// complete answer, so it was formatted like fine print and treated like
/// fine print. The same words with a bold lead scan in a second.
///
/// DELIBERATELY NOT TAPPABLE. There is nowhere to send anybody: `BillsSheet`
/// reads `state.upcoming` and nothing else, so a tap on a notice about a
/// debt minimum or an instalment lands on a sheet that shows ONE HALF of what
/// the notice named. The person counts one row and concludes the app is
/// wrong, which is a manufactured wrong conclusion bought with a tap target.
/// It becomes tappable when a day view exists.
///
/// NO WARNING TINT. Nothing here is wrong, and a warning colour on a screen
/// with nothing wrong with it teaches people to ignore the warning colour
/// that matters. Both tokens used here are already on this card, so the
/// palette contrast sweep covers them in all sixteen moods with no new pair.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.palette,
    required this.noticeKey,
    required this.label,
    required this.body,
  });

  final Palette palette;
  final Key noticeKey;
  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    // The body arrives carrying its own label, because the engine-facing
    // helpers build whole sentences. Strip it so the label can be drawn
    // bold without being printed twice.
    final String rest = body.startsWith(label)
        ? body.substring(label.length)
        : body;
    return Text.rich(
      // Text.rich, never RichText: RichText renders a style with no family
      // and draws boxes in the shot harness. See the headline above.
      TextSpan(
        style: AppType.caption(palette),
        children: <InlineSpan>[
          TextSpan(
            text: label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: palette.textSecondary,
            ),
          ),
          TextSpan(text: rest),
        ],
      ),
      key: noticeKey,
    );
  }
}

/// A small tappable pill, 44 tall so it clears the touch-target floor.
class _Pill extends StatelessWidget {
  const _Pill({required this.palette, required this.label, this.onTap});

  final Palette palette;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppType.rowTitle(
              palette,
            ).copyWith(fontSize: 13, color: palette.accent),
          ),
        ),
      ),
    );
  }
}
