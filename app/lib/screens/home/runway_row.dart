import 'package:flutter/material.dart';

import '../../core/money/daily_projection.dart';
import '../../core/money/duplicate_obligations.dart';
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
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
                              child: Text(
                                'NEXT 45 DAYS',
                                style: AppType.kicker(p),
                              ),
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
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.xs),
                  Icon(Icons.chevron_right, size: 18, color: p.textMuted),
                ],
              ),
              // THE NOTICES SIT BELOW THE ROW, AT FULL CARD WIDTH, and that is
              // worth seventy logical pixels a line. Inside the Expanded column
              // above they were indented past the 36dp icon tile and its 12dp
              // gap, and stopped short of the 18dp chevron and its 4dp gap, so
              // every line of the smallest text on the card was laid out in
              // 256dp of a 326dp card. Twenty one percent of the width, thrown
              // away on furniture that belongs to the lead sentence alone.
              //
              // Measured at 320dp with the system font at 1.5x, which is the
              // worst case a person can actually set: nine lines of notice
              // become six. Nothing was cut to get that.
              if (r.hasNotice) ...<Widget>[
                // ONE divider for all the notices, never one each. Three
                // dividers turn a card into a form.
                const SizedBox(height: Spacing.sm),
                Divider(height: 1, color: p.border),
                const SizedBox(height: Spacing.sm),
                // NOW GENUINELY NOT TAPPABLE, which the comment on `_Notice`
                // claimed for a day while it was false. The notices sit inside
                // the card's own InkWell, so a tap on the words "Counted twice,
                // Home Credit Installment" opened BillsSheet, which reads
                // state.upcoming and nothing else and therefore shows exactly
                // ONE of the two rows the notice just named. That is the
                // manufactured wrong conclusion the comment warns about, bought
                // with a tap target nobody meant to create. Absorbing the
                // gesture here makes the stated intent true.
                //
                // AbsorbPointer is NOT the widget for this and was tried
                // first. It stops the pointer reaching its own DESCENDANTS,
                // which was never the problem: it still sits in the hit-test
                // path, so the ancestor InkWell kept firing and the test
                // that proves this caught it immediately. A GestureDetector
                // with an empty onTap wins the gesture arena against the
                // ancestor instead, which is what "nothing happens here"
                // actually requires.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
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
                      // that opens with the words "Not counted" would make that
                      // sentence lie about its own subject, and that holds
                      // however short the clause is.
                      if (r.countedOnce != null) ...<Widget>[
                        if (r.notCounted != null)
                          const SizedBox(height: Spacing.xs),
                        _Notice(
                          palette: p,
                          noticeKey: const Key('runway-counted-once'),
                          // "COUNTED ONCE" ALONE WAS MISREAD THREE WAYS, and
                          // by all three archetypes on a user panel, none of
                          // whom read it as the reassurance it is. One asked
                          // why a non-problem was on their home screen. One
                          // read it as the app taking credit for doing its
                          // job. The third, and the reason these four words
                          // exist, read "counted once" as an unfinished
                          // count and went looking for what happened to the
                          // other one.
                          //
                          // There is no other one. ", not twice" says so in
                          // three characters of line, keeps the pairing with
                          // the "Counted twice" line below it, and matches
                          // the explainer behind the dot word for word,
                          // which already read "is counted once, not twice".
                          //
                          // Founder decision of 2026-10-05, taken against a
                          // panel recommendation to delete the line
                          // outright: the line stays, because D27 records in
                          // writing that it is "not optional polish, it is
                          // the other half of this decision". It is what
                          // stops a genuine second income of the same amount
                          // in the same month being dropped in silence.
                          label: 'Counted once, not twice: ',
                          body: r.countedOnce!,
                        ),
                      ],
                      if (r.countedTwice != null) ...<Widget>[
                        if (r.notCounted != null || r.countedOnce != null)
                          const SizedBox(height: Spacing.xs),
                        _Notice(
                          palette: p,
                          noticeKey: const Key('runway-counted-twice'),
                          label: 'Counted twice: ',
                          body: r.countedTwice!,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
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
    this.countedTwice,
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

  /// Outflows that appear in two registers, so the figure above took them
  /// out twice. Nothing is dropped, the person is told.
  final String? countedTwice;

  bool get hasNotice =>
      notCounted != null || countedOnce != null || countedTwice != null;

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
  final String? twice = _countedTwice(p);
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
      countedTwice: twice,
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
      countedTwice: twice,
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
      countedTwice: twice,
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
      countedTwice: twice,
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
    countedTwice: twice,
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
    // "across N items" went the same way as "Salapify could read", and for
    // the same reason: measured, it bought a whole extra line at 390dp and
    // no wrong conclusion rests on it. The peso amount carries the risk.
    parts.add('${formatPeso(p.overdueOutflow.pesos)} overdue');
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
  // THE BODY ONLY. The label lives at the call site and nowhere else now.
  // It used to be written here as well and stripped back off in `_Notice`
  // with a `startsWith`, which is six producers and three consumers agreeing
  // on a punctuation mark with nothing checking they still do. One stray
  // character and the card rendered "Not counted: Not counted: ..." with no
  // test red.
  return '${parts.join(', ')}.';
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

  // "in Coming Up and in your payday rule" was cut on 2026-10-05. It is the
  // SAME TWO PLACES every time this line can fire, by construction: the
  // suppression only ever happens between a recorded income item and the
  // stored payday rule. A clause that cannot vary is not a figure, it is a
  // lesson, and that lesson is already written behind the "i" dot under "It
  // never invents income". The counted-twice line below KEEPS its places
  // clause for the opposite reason: there they genuinely vary per pair.
  if (names.length == 1 && p.duplicateIncomeLabels.length == 1) {
    return '$figure. ${names.first}, in two places.';
  }
  if (names.length == 2) {
    return '$figure. ${names.first} and ${names[1]}, each in two places.';
  }
  // One name arriving several times, or more than two names: lean on the
  // total and the count rather than listing.
  return '$figure across ${p.duplicateIncomeLabels.length} items, '
      'each in two places.';
}

/// The OPPOSITE of the line above, and the asymmetry is deliberate (D27).
///
/// Income written down twice is DROPPED and then named. An outflow written
/// down twice is KEPT, both copies, and then named. The reason is which way
/// the mistake cuts: an over-counted bill makes somebody cautious, and nobody
/// ever bounced a payment because an app was careful; an over-counted salary
/// hands them cash that is not coming. So this line never says a figure was
/// removed. It says the figure above took the same payment out twice and
/// leaves the person to decide which of the two rows is the real one.
///
/// IT NEVER CALLS THEM DUPLICATES. "Appears in two places" is a fact about
/// the ledger that the person can check in ten seconds. "This is a
/// duplicate" is a claim about their intent, and people genuinely do pay the
/// same amount to the same provider twice in a week.
///
/// THE FIGURE IS WHAT THE DOUBLE COUNTING COSTS: one copy of each pair,
/// which is the money taken out a second time.
String? _countedTwice(DailyProjection p) {
  final List<SuspectedDuplicate> found = p.duplicateOutflows;
  if (found.isEmpty) return null;

  final String figure = formatPeso(p.duplicateOutflowExtra.pesos);

  if (found.length == 1) {
    final SuspectedDuplicate d = found.first;
    // THE PLACES STAY HERE, and they were cut from the line above. The
    // difference is whether the clause can vary: income is always Coming Up
    // against the payday rule, so naming it teaches nothing, while an
    // outflow pair can be any two of four registers and the person cannot
    // guess which. Naming them is what turns the line into something to go
    // and do, so it is a figure by the 2026-09-18 test, not a lesson.
    //
    // One place means both rows sit in the same list on screen, which is
    // three of the four registers. "in Coming Up and Coming Up" was the
    // sentence this avoids.
    final String where = d.places.length == 1
        ? 'twice in ${d.places.first}'
        : 'in ${d.places.first} and ${d.places[1]}';
    return '$figure. ${d.label}, $where.';
  }

  if (found.length == 2) {
    // Named, not placed. Two pairs can sit in different registers, so one
    // shared "where" clause would be wrong about one of them, and the name
    // is what a person searches for anyway.
    return '$figure. ${found.first.label} and ${found[1].label}, '
        'each in two places.';
  }

  return '$figure across ${found.length} items, each in two places.';
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
    // NO STRIPPING. The body used to arrive carrying its own label and this
    // widget cut it back off with a `startsWith`, so the same sentence
    // opener lived at the call site AND inside the helper, six producers
    // against three consumers, with nothing checking they still matched.
    // Drift one character of punctuation and the card renders the label
    // twice, silently, with every test green. The helpers return the body
    // alone now and that bug is unrepresentable.
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
          TextSpan(text: body),
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
