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
                    if (r.notCounted != null) ...<Widget>[
                      const SizedBox(height: Spacing.sm),
                      Divider(height: 1, color: p.border),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        r.notCounted!,
                        key: const Key('runway-not-counted'),
                        style: AppType.caption(p),
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
    parts.add(
      '${formatPeso(p.undatedOutflow.pesos)} with no due date Salapify could '
      'read',
    );
  }

  // D27's other half. The founder's answer was count it once AND say so, and
  // this is the saying. Somebody with a genuine second income of the same
  // size in the same month has it dropped by that rule, and this sentence is
  // the only thing between that and silence.
  final String? doubled = p.duplicateIncomeLabels.isEmpty
      ? null
      : '${p.duplicateIncomeLabels.first} is in Upcoming and in your payday '
            'rule, so it is counted once.';

  if (parts.isEmpty) return doubled;
  final String line = 'Not counted: ${parts.join(', and ')}.';
  return doubled == null ? line : '$line $doubled';
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
