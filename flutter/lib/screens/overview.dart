// Overview: the first real screen of the Flutter rebuild. Net worth from the
// same golden-verified netWorthParts the Reports use, the accounts list, and
// this month's income statement. Empty state offers the backup import (paste
// the text the RN Backup screen shows), so the founder's data carries over
// with zero extra plugins.

import 'dart:convert' show jsonDecode;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../data/backup.dart';
import '../data/backup_file.dart';
import '../data/store.dart';
import '../money/coach.dart' as coach;
import '../money/commitments.dart' show upcomingCommitments;
import '../money/cycle.dart';
import '../money/greeting.dart';
import '../money/pan_mood.dart';
import '../money/statements.dart';
import '../theme.dart';
import '../widgets/screen_header.dart' show MenuAction;
import '../widgets/section.dart';
import '../widgets/bills_before_payday.dart';
import '../widgets/spoken_for_bar.dart';
import '../widgets/pan_mascot.dart';
import '../widgets/pressable_scale.dart';
import 'debts.dart';
import 'goals.dart';
import 'log_sheet.dart';
import 'pan.dart';
import 'search.dart';
import 'shell.dart';

String formatMoney(num value) {
  // A backup can smuggle near-max doubles whose SUMS overflow to Infinity.
  // round() throws on non-finite, which would take down the whole screen,
  // so render the raw word instead (the RN app shows the same garbage but
  // stays alive, and staying alive is the contract here).
  if (!value.isFinite) return '₱$value';
  final negative = value < 0;
  // A FINITE value near max double still overflows when scaled by 100 for
  // centavo rounding, and round() throws on the resulting Infinity. Same
  // contract: render the raw number, stay alive.
  final scaled = value.abs() * 100;
  if (!scaled.isFinite) return '₱$value';
  final rounded = scaled.round() / 100;
  var whole = rounded.floor();
  final cents = ((rounded - whole) * 100).round();
  final digits = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  final centsPart = cents > 0 ? '.${cents.toString().padLeft(2, '0')}' : '';
  return '${negative ? '-' : ''}₱$buf$centsPart';
}

/// An ISO date as a short human day, "Jul 27".
///
/// Hoisted out of _yourNumberCard, where it was a local closure, the moment a
/// second card needed the same format. Two copies of a date formatter drift
/// the same way two copies of a money formatter do, and the bills list sits
/// directly under the card that used to own this one.
///
/// Junk in, junk out ON PURPOSE: an unparseable date returns unchanged rather
/// than throwing, so a hand-edited backup cannot take Home down.
String prettyDay(String iso) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (iso.length < 10) return iso;
  final m = int.tryParse(iso.substring(5, 7));
  final day = int.tryParse(iso.substring(8, 10));
  if (m == null || day == null || m < 1 || m > 12) return iso;
  return '${months[m - 1]} $day';
}

class OverviewScreen extends StatelessWidget {
  final SalapifyStore store;
  final void Function(Destination)? onSwitchTab;

  /// Opens Menu. Home keeps its wordmark instead of adopting ScreenHeader, so
  /// it wires MenuAction into its own row rather than getting it for free.
  final VoidCallback? onMenu;
  const OverviewScreen({
    super.key,
    required this.store,
    this.onSwitchTab,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final data = store.data;
    // One clock for the whole build, so a midnight straddle can never show
    // the check-in for one day and the number for the next in the same frame.
    final now = DateTime.now();
    final parts = netWorthParts(data);
    final istmt = incomeStatement(data, now);
    final accounts = (data['accounts'] as List).cast<Map<String, dynamic>>();
    // The one thing to do about money right now, seen the moment Home opens.
    // Reuses the same coach decision layer Insights renders, so the two can
    // never disagree. Only once there is real data to reason about.
    final transactions = data['transactions'];
    final hasStarted =
        accounts.isNotEmpty ||
        (transactions is List && transactions.isNotEmpty);
    final checkIn = hasStarted ? coach.weeklyCheckIn(data, now) : null;
    // Your Number: the one figure to carry until payday, from the same
    // safeToSpend the coach and Insights read, so the three never disagree.
    final cycle = cycleStatus(data, now);
    // The bills and the payday date, from the SAME engine call safeToSpend
    // builds the per-day number on. Computed once here and shared by the
    // countdown and the bills list, so the two can never name different days.
    final dues = upcomingCommitments(data, now);
    final bills = ((dues['bills'] as List?) ?? const [])
        .whereType<Map>()
        .map((b) => b.cast<String, dynamic>())
        .toList();
    // When the check-in itself is the payday warning, its message already
    // carries the pace and easing figures; repeating them on the card below
    // (with different rounding) would put two versions of one number on
    // screen, so the card goes quiet on its pace line.
    final checkInIsPayday = checkIn != null && checkIn['kind'] == 'payday';
    // Payday morning: the three-minute ritual card, fully derived from the
    // ledger (the salary-logged state IS the data, no stored flag exists to
    // drift). Only when writes are open, since both its actions write.
    final ritual = store.canWrite
        ? paydayRitual(data, now)
        : const PaydayRitual(isPayday: false, salaryLogged: false);

    // A body now, not a Scaffold. The shell owns the one Scaffold, the nav bar
    // and the Log button, so Home is just its content.
    //
    // The Log button used to live here, which is where it was invented rather
    // than where it belongs. Logging is the thing people open this app to do,
    // and it was reachable from one tab out of six. It is on every destination
    // now, and the store's canWrite gate moved with it: after a failed read,
    // saving would overwrite data we could not read, so the door stays hidden.
    //
    // 96 of bottom padding, not 20, so the last card clears the Log button.
    // Home has had a FAB and 20 of padding all along, which means its final
    // card has been sitting under that button since the day it was added.
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [
          SizedBox(height: 8),
          Row(
            children: [
              Text(
                '₱',
                style: TextStyle(
                  color: Barako.primary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: 10),
              // Flexible + scaleDown: on a very narrow phone the wordmark
              // shrinks a touch instead of pushing the search button off the
              // edge (the old fixed Text overflowed by ~30px at 330 wide).
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SALAPIFY',
                    style: TextStyle(
                      color: Barako.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.search, color: Barako.text),
                tooltip: 'Search',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SearchScreen(store: store, onSwitchTab: onSwitchTab),
                  ),
                ),
              ),
              // Home keeps the wordmark rather than adopting ScreenHeader, so
              // the same MenuAction the other four get from their header is
              // placed by hand here. One widget, one tooltip, one tap target,
              // five screens.
              if (onMenu != null) MenuAction(onTap: onMenu!),
            ],
          ),
          // The greeting sits under the wordmark rather than replacing it,
          // so the app still says what it is on the screen a new user opens
          // first. It reads fine with no name, which is the DEFAULT: the
          // ask is skippable and every existing user has none.
          const SizedBox(height: 4),
          Text(
            // The build's own clock, not a second DateTime.now(). One frame
            // must never mix two readings of the time, which is the same
            // reason `now` is captured once at the top of build.
            greetingFor(now, name: store.displayName),
            style: TextStyle(
              color: Barako.textSecondary,
              fontSize: 15,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          if (store.loadError != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Your saved data could not be read, so nothing was overwritten. ${store.loadError}',
                  style: TextStyle(color: Barako.warning),
                ),
              ),
            ),
          if (ritual.isPayday) ...[
            _paydayCard(context, ritual, numberShows: cycle.show),
            const SizedBox(height: 12),
          ],
          if (checkIn != null) ...[
            _checkInCard(context, checkIn),
            const SizedBox(height: 12),
          ],
          if (cycle.show) ...[
            _yourNumberCard(context, cycle, hidePace: checkInIsPayday),
            const SizedBox(height: 12),
          ] else if (hasStarted && dues['daysLeft'] is int) ...[
            // The countdown used to live ONLY inside Your Number, which
            // hides whenever there is nothing positive to spend. So the
            // answer to "how long do I have to hold out" disappeared exactly
            // when money was tight, which is the one time anybody asks it.
            // Shown only in that gap: when Your Number renders, it already
            // says how many days are left, and two countdowns on one screen
            // is worse than none.
            _daysToPaydayCard(dues),
            const SizedBox(height: 12),
          ],
          // What the committed money is actually FOR. The bar above says how
          // much is spoken for; this says to whom. Both read the same
          // upcomingCommitments call, so they cannot disagree.
          if (hasStarted && bills.isNotEmpty) ...[
            BillsBeforePayday(
              bills: bills,
              total: (dues['total'] as num?)?.toDouble() ?? 0,
              format: formatMoney,
              formatDay: prettyDay,
            ),
            const SizedBox(height: 12),
          ],
          // On a brand-new device the ₱0 hero would just compete with the
          // welcome card, so the hero only appears once there is data.
          if (hasStarted) ...[_netWorthHero(parts), const SizedBox(height: 16)],
          // Only invite a fresh start when the store really is empty. After a
          // failed read the data looks empty but is not, writes are blocked,
          // and the error banner above already explains it, so the welcome
          // lanes (which would be dead or misleading) are suppressed.
          if (!hasStarted) ...[
            if (store.loadError == null) _welcomeCard(context),
          ] else ...[
            if (accounts.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Kicker('MY MONEY'),
                      const SizedBox(height: 6),
                      for (final a in accounts)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  a['name'] as String? ?? 'Account',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Barako.text,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // A big balance scales down instead of
                              // overflowing the row on a narrow phone.
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    formatMoney(amount(a['balance'])),
                                    style: TextStyle(
                                      color: Barako.textSecondary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Kicker('THIS MONTH'),
                    const SizedBox(height: 6),
                    // The ANSWER first, its two parts underneath. This was
                    // three equal rows and a divider, which made the reader
                    // do the subtraction with their eyes before learning
                    // whether the month was up or down. The net is the only
                    // figure most people want, so it gets the headline.
                    Builder(
                      builder: (context) {
                        final net = istmt['netIncome'] as double;
                        return Text(
                          // The sign is explicit on a gain. Without it a
                          // good month and a bad month look identical until
                          // you notice the minus.
                          '${net > 0 ? '+' : ''}${formatMoney(net)}',
                          style: TextStyle(
                            fontFamily: Barako.displayFont,
                            color: net >= 0 ? Barako.primary : Barako.warning,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: Gap.md),
                    StatPair(
                      leftLabel: 'Money in',
                      leftValue: formatMoney(istmt['income'] as double),
                      leftColor: Barako.primary,
                      rightLabel: 'Money out',
                      rightValue: formatMoney(istmt['expenses'] as double),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double amount(dynamic v) => v is num ? v.toDouble() : 0;

  // The bottom tabs a check-in action can jump straight to. Routes that are
  // not tabs (/debts, /goals) are handled by a push in _checkInCard; /learn is
  // simply not tappable from here.
  //
  // Named rather than numbered, because this map is exactly where a tab
  // reorder used to go wrong: '/budget': 1 was correct only for as long as
  // Budget happened to be second, and nothing would have failed if it moved.
  static const Map<String, Destination> _routeTabs = {
    '/': Destination.home,
    '/budget': Destination.budget,
    '/receivables': Destination.utang,
    '/insights': Destination.insights,
  };

  /// The single most important money decision right now, or a calm all-clear,
  /// rendered at the top of Home. Mirrors the Insights decision card so the two
  /// read the same; tapping goes where the action points, a bottom tab or the
  /// Debts screen.
  Widget _checkInCard(BuildContext context, Map<String, dynamic> c) {
    final tone = c['tone'] as String;
    final action = c['action'];
    final route = action is Map ? action['route'] as String? : null;
    final tab = route != null ? _routeTabs[route] : null;
    VoidCallback? onTap;
    if (tab != null && onSwitchTab != null) {
      onTap = () => onSwitchTab!(tab);
    } else if (route == '/debts') {
      // Debts is not a bottom tab; a due-soon decision is prio 92, so it must
      // not be a dead end. Push the screen Home already imports.
      onTap = () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => DebtsScreen(store: store)));
    } else if (route == '/goals') {
      // Goals is a pushable screen now, so an "open goals" decision is a real
      // tap instead of an inert card.
      onTap = () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => GoalsScreen(store: store)));
    }
    final good = tone == 'good';
    // Same mapping as the Insights decision card: urgent and watch read as
    // "act", a nudge reads dimmer as "FYI".
    final titleColor = tone == 'urgent'
        ? Barako.warning
        : good
        ? Barako.primaryText
        : tone == 'watch'
        ? Barako.text
        : Barako.textSecondary;
    final dotColor = tone == 'urgent'
        ? Barako.warning
        : tone == 'nudge'
        ? Barako.muted
        : Barako.primary;
    // When the coach has somewhere specific to send you, the card goes there.
    // When it does NOT (the calm all-clear), the card used to be completely
    // inert: Pan says something friendly and tapping it does nothing at all,
    // which is the moment a character stops feeling like someone you can talk
    // to. Falling through to Ask Pan continues the conversation he just
    // started, and it can never shadow a real decision because it only
    // applies where there was no destination in the first place.
    onTap ??= () => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PanScreen(store: store, onSwitchTab: onSwitchTab),
      ),
    );
    final Widget card = Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pan sits with the check-in, reflecting its mood, so the same cup
              // face reacts to the top coach item here and to chat replies in
              // Ask Pan. Same widget, same mood engine.
              // Bare, NOT Flexible. It used to share a Row with Pan, where
              // Flexible stopped it overflowing at the largest font scale. It
              // now sits alone on its own line inside a Column, and a flex
              // child in a vertical Column of unbounded height (this is inside
              // a ListView) throws instead of laying out.
              Kicker('MONEY CHECK-IN'),
              const SizedBox(height: Gap.md),
              // Pan STANDS BESIDE what he says, rather than sitting in the
              // corner as an ornament over text the app narrates. The bubble
              // and its tail are what make the words his; a panel of text next
              // to a picture reads as the app talking with a mascot stuck on
              // the side, which is what this was.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tapping Pan opens Ask Pan. He was decoration until now,
                  // and a character who reacts to your money but does nothing
                  // when you reach for him teaches that he is scenery.
                  //
                  // He is NO LONGER hidden from the screen reader. He used to
                  // be, correctly, because a purely decorative image that
                  // repeats what the card already says is noise. The moment he
                  // became tappable that reversed: an interactive target that
                  // announces nothing is a control a blind user cannot find or
                  // know exists.
                  //
                  // The label names the DESTINATION rather than the mood. The
                  // mood is already spoken by the card's own title underneath,
                  // so repeating it here would be the noise the old
                  // ExcludeSemantics was avoiding.
                  Semantics(
                    // container: true is load-bearing. Without it this widget
                    // only ANNOTATES the nearest semantics node, and the
                    // ExcludeSemantics below removes the only candidate, so
                    // the label attached to nothing and the button was
                    // invisible to a screen reader while looking correct in
                    // the code.
                    container: true,
                    button: true,
                    label: 'Ask Pan',
                    child: InkResponse(
                      radius: 32,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PanScreen(store: store, onSwitchTab: onSwitchTab),
                        ),
                      ),
                      child: ExcludeSemantics(
                        // A reaction to what the user JUST did wins over the
                        // ambient coach mood, briefly. Logging an expense is
                        // the most common thing anyone does in this app and it
                        // used to change Pan's face not at all.
                        //
                        // The override expires by itself, so Pan cannot end up
                        // grinning about an old log while the coach is trying
                        // to say a bill is due. That would read as a bug, not
                        // as warmth.
                        child: PanMascot(
                          mood:
                              panMoodForRecentAction(
                                store.lastActionKind,
                                store.lastActionAt,
                                DateTime.now(),
                              ) ??
                              panMoodForCoachKind(c['kind'] as String?),
                          size: 80,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      decoration: ShapeDecoration(
                        color: Barako.background,
                        shape: _BubbleBorder(border: Barako.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // The all-clear wears a quiet check, not the
                              // attention dot, so calm reads softer than a
                              // real decision.
                              if (good)
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Barako.primary,
                                  size: 16,
                                )
                              else
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c['title'] as String,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              // Always shown now, because the card always has
                              // somewhere to go: the coach's destination, or
                              // Ask Pan when there is not one.
                              Icon(
                                Icons.chevron_right,
                                color: Barako.faint,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c['message'] as String,
                            style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    // Every state gets the press feel now, because every state is genuinely
    // tappable. The old rule (press feel only where there was an action) was
    // right for as long as the calm card was a dead end, and keeping it after
    // that changed would make the press feedback lie in the opposite
    // direction: a card that responds to a tap but looks like it will not.
    return PressableScale(child: card);
  }

  /// Payday morning, the three-minute ritual: log the salary (one tap to the
  /// income sheet), move savings first (one tap to Goals), then Your Number
  /// below carries the cycle. The done state is detected from the ledger
  /// itself: a real income logged today flips the copy, and receivable
  /// collections do not count as salary. On purpose there is no checkbox to
  /// tick and no stored flag; the data is the state.
  Widget _paydayCard(
    BuildContext context,
    PaydayRitual r, {
    required bool numberShows,
  }) {
    return Card(
      color: Barako.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payments_outlined, color: Barako.primary, size: 18),
                const SizedBox(width: 8),
                Kicker('PAYDAY'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              r.salaryLogged
                  ? 'Salary logged. Your cycle is set.'
                  : 'It is payday. Three minutes sets your whole cycle.',
              style: TextStyle(
                color: Barako.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              // Never point at a card that is not there: when available is
              // still <= 0 (salary logged to no account, or smaller than the
              // committed bills), the number card below does not render, so
              // the sentence points at what IS true instead.
              r.salaryLogged
                  ? numberShows
                        ? 'Your number below is fresh from the new balance. '
                              'Moving a little to savings first, before the '
                              'spending starts, is what makes it honest.'
                        : 'Your number appears below once the salary sits in '
                              'an account with room past the upcoming bills.'
                  : 'Log your salary, move a little to savings first, and '
                        'carry your number until the next payday.',
              style: TextStyle(
                color: Barako.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!r.salaryLogged) ...[
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          showLogSheet(context, store, initialType: 'income'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Barako.primary,
                        foregroundColor: Barako.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Log salary',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GoalsScreen(store: store),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Barako.primaryText,
                      side: BorderSide(color: Barako.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Savings first',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The countdown on its own, for the case where Your Number stays quiet.
  ///
  /// Deliberately says the number of days and nothing else. Your Number is
  /// silent precisely when there is no positive figure to show, which means
  /// money is tight, and that is the wrong moment to add a second card with
  /// an opinion in it. The coach's check-in above already owns the message;
  /// this only answers "how long".
  Widget _daysToPaydayCard(Map<String, dynamic> dues) {
    final days = dues['daysLeft'] as int;
    final payday = (dues['payday'] ?? '').toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kicker('DAYS TO PAYDAY'),
            const SizedBox(height: 6),
            Text(
              '$days ${days == 1 ? 'day' : 'days'}',
              style: TextStyle(
                fontFamily: Barako.displayFont,
                color: Barako.text,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (payday.length >= 10) ...[
              const SizedBox(height: 2),
              Text(
                'Until ${prettyDay(payday)}.',
                style: TextStyle(color: Barako.textSecondary, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Your Number: the daily figure to carry until payday, straight from
  /// safeToSpend's perDay via the cycle composer. Shows only when positive
  /// (crunch belongs to the check-in above). The pace line speaks only when
  /// paydayProjection does; after three quiet days the sub greets the
  /// comeback kindly instead of scolding. Tap opens Insights, where the full
  /// safe-to-spend breakdown lives.
  Widget _yourNumberCard(
    BuildContext context,
    CycleStatus s, {
    bool hidePace = false,
  }) {
    final sub = s.comeback
        ? 'Welcome back, life happens. Fresh from your real balances: '
              '${s.daysLeft} ${s.daysLeft == 1 ? 'day' : 'days'} to your '
              '${prettyDay(s.payday)} payday.'
        : 'until your ${prettyDay(s.payday)} payday, ${s.daysLeft} '
              '${s.daysLeft == 1 ? 'day' : 'days'} away.';
    // Whole pesos, matching the coach's formatter, so the check-in and this
    // line can never show two roundings of the same engine figure. A sub-peso
    // easing would render "Easing ₱0 a day", which is nonsense, so a pace
    // that close to fitting reads as fitting.
    final easeWhole = s.easeOff.round();
    final paceFits = s.onTrack == true || easeWhole < 1;
    final String? paceLine = hidePace || s.onTrack == null
        ? null
        : paceFits
        ? 'Your recent pace fits. Keep going.'
        : 'Recent pace is about ${formatMoney(s.dailyPace.roundToDouble())} '
              'a day. Easing ${formatMoney(easeWhole)} a day keeps you '
              'covered to payday.';

    return PressableScale(
      child: Semantics(
        button: onSwitchTab != null,
        hint: onSwitchTab != null ? 'Opens Insights' : null,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onSwitchTab == null
                ? null
                : () => onSwitchTab!(Destination.insights),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Kicker('YOUR NUMBER'),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: Barako.faint, size: 18),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatMoney(s.perDay),
                          style: TextStyle(
                            fontFamily: 'Fraunces',
                            color: Barako.text,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '  a day',
                          style: TextStyle(
                            color: Barako.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(
                      color: Barako.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  // What is already spoken for, drawn rather than described.
                  // Both figures come from the SAME safeToSpend call that
                  // produced the per-day number above, so the bar can never
                  // disagree with the headline; committed is simply the part
                  // of the cash that is not free.
                  //
                  // Only when there is something committed. A full-width bar
                  // labelled "committed ₱0" is a chart of nothing, and it
                  // would appear for every user with no bills at all.
                  if (s.liquid > s.available) ...[
                    const SizedBox(height: Gap.md),
                    SpokenForBar(
                      committed: s.liquid - s.available,
                      free: s.available,
                      format: formatMoney,
                    ),
                  ],
                  if (paceLine != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      paceLine,
                      style: TextStyle(
                        color: paceFits
                            ? Barako.primaryText
                            : Barako.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The dashboard hero. Now that the clutter moved to Menu, net worth is the
  /// headline: raised surface, bigger figure, and a negative total reads in the
  /// warning color so the sign lands instantly. Numbers come straight from the
  /// golden-locked netWorthParts, this only restyles them.
  Widget _netWorthHero(Map<String, dynamic> parts) {
    final nw = parts['netWorth'] as double;
    return Card(
      color: Barako.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kicker('NET WORTH'),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMoney(nw),
                maxLines: 1,
                style: TextStyle(
                  fontFamily: Barako.displayFont,
                  // A negative net worth is honest, not an emergency. It
                  // stays in plain ink, not alarm red, so a user who owes
                  // more than they hold is not shamed by the biggest number
                  // on the screen. Red is reserved for urgent, time-bound
                  // things like an overdue utang.
                  color: nw < 0 ? Barako.text : Barako.primary,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  // No tabularFigures here, deliberately. theme.dart records
                  // that Fraunces has NO tnum table, which the font file
                  // confirms (it ships liga and rvrn only), so asking for
                  // tabular figures on the display family was a silent no op
                  // pretending to be an alignment guarantee. The StatPair
                  // below inherits Jakarta, which does have tnum, and that is
                  // where digit alignment actually matters: a lone hero
                  // number has no column to line up with.
                ),
              ),
            ),
            const SizedBox(height: Gap.md),
            // Net worth is one number made of two, so both halves get a name
            // and a column. This was a single 13pt muted caption reading
            // "Assets X  ·  Owed Y": present, and unreadable, because a middle
            // dot is not a column and grey is not a label.
            StatPair(
              leftLabel: 'Total assets',
              leftValue: formatMoney(parts['assets'] as double),
              leftColor: Barako.primary,
              rightLabel: 'Total owed',
              rightValue: formatMoney(parts['liabilities'] as double),
              // Warning ONLY when something is actually owed. Owing nothing is
              // good news, and rendering "₱0" in the alarm colour makes the
              // best possible state look like a problem. Same rule the
              // headline above already follows: colour is reserved for a fact
              // that warrants attention, not for a category of number.
              rightColor: (parts['liabilities'] as double) > 0
                  ? Barako.warning
                  : Barako.text,
            ),
            if (nw < 0) ...[
              const SizedBox(height: 8),
              Text(
                'You owe more than you hold right now. That is common early on, and the steps in Insights are how you turn it around.',
                style: TextStyle(
                  color: Barako.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// First-run card, shown in place of MY MONEY and THIS MONTH when there is no
  /// data yet. It leads with a real first action for a brand-new user (log, or
  /// jump to the one thing they came for), and keeps the "bring your data over"
  /// path as a quiet link for the tester migrating from the old app, rather
  /// than as the loud primary button a new user cannot use.
  Widget _nameAsk(BuildContext context) => _NameAsk(store: store);

  Widget _welcomeCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker('WELCOME'),
          const SizedBox(height: 8),
          Text(
            'Nothing here yet, and that is okay.',
            style: TextStyle(
              color: Barako.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'What do you want to start with?',
            style: TextStyle(
              color: Barako.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _lane(
            context,
            Icons.receipt_long_outlined,
            'Track my spending',
            'Log what you spend and see where it goes',
            () {
              if (store.canWrite) showLogSheet(context, store);
            },
          ),
          const SizedBox(height: 10),
          _lane(
            context,
            Icons.handshake_outlined,
            'See who owes me',
            'Keep a who-owes-you list that adds itself up',
            () => onSwitchTab?.call(Destination.utang),
          ),
          const SizedBox(height: 10),
          _lane(
            context,
            Icons.trending_down,
            'Pay off a debt, formal or between friends',
            'A payoff date and the cheapest way there',
            () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DebtsScreen(store: store)),
            ),
          ),
          // The name ask lives INSIDE the welcome card, not on a screen of its
          // own in front of the app. A first-run wall asking for personal
          // details before showing anything is the highest-friction thing a
          // finance app can do, and this one genuinely does not need the
          // answer: everything works without it.
          //
          // It sits BELOW the three lanes on purpose. "What do you want to
          // start with?" is a question and the lanes are its answers, so a
          // text field wedged between the two reads as though the field is
          // the answer. Optional and secondary, placed like it.
          //
          // It disappears once answered, and never appears again once there
          // is data, so it cannot become a nag.
          if (store.displayName == null) ...[
            const SizedBox(height: 16),
            _nameAsk(context),
          ],
          const SizedBox(height: 16),
          // Quiet migration path for a tester bringing data from the old app.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: Barako.muted,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ImportScreen(store: store)),
              ),
              child: const Text('Coming from the old app? Import a backup'),
            ),
          ),
        ],
      ),
    ),
  );

  // A tappable first-run lane: an icon, a title, and a one-line why, routing to
  // the screen that user came for.
  Widget _lane(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => PressableScale(
    child: Material(
      color: Barako.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Barako.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: Barako.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Barako.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: Barako.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Barako.faint, size: 18),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The optional "what should we call you" ask, shown once inside the welcome
/// card and never again after that.
///
/// Its own widget because a text field needs a controller with a real
/// lifecycle, and OverviewScreen is stateless. Keeping it here rather than in
/// a first-run flow is the point: Salapify works completely without a name,
/// so it must never stand between someone and the app.
class _NameAsk extends StatefulWidget {
  final SalapifyStore store;
  const _NameAsk({required this.store});

  @override
  State<_NameAsk> createState() => _NameAskState();
}

class _NameAskState extends State<_NameAsk> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final typed = _controller.text;
    // normalizeDisplayName turns whitespace into null, so tapping Save on an
    // empty field quietly does nothing rather than storing a blank.
    if (normalizeDisplayName(typed) == null) return;
    await widget.store.setDisplayName(typed);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Barako.background,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: Barako.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What should Pan call you?',
            style: TextStyle(
              color: Barako.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            // Said plainly because this is a money app asking for a personal
            // detail, and "it stays on this phone" is both the honest answer
            // and the reassuring one. Salapify has no server to send it to.
            'Optional, and it never leaves this phone.',
            style: TextStyle(
              color: Barako.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.words,
                  maxLength: displayNameMaxLength,
                  onSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    hintText: 'Your name',
                    isDense: true,
                    // The character counter is noise on a name field: the cap
                    // is a layout guard, not a rule the reader needs told.
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Barako.primary,
                  foregroundColor: Barako.onPrimary,
                ),
                onPressed: _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A rounded speech bubble with a tail pointing left, at Pan.
///
/// A ShapeBorder rather than a Stack with a triangle in it, because the tail
/// has to be part of the SAME path as the body: drawn as two overlapping
/// shapes, the border stroke runs straight through the join and the seam is
/// visible on any theme with a border colour.
///
/// The tail is what turns a panel into speech. Without it this is just a box
/// of text sitting next to a picture, and the whole point is that the words
/// are Pan's rather than the app's.
class _BubbleBorder extends ShapeBorder {
  final double radius;
  final double tail;

  final Color border;

  /// Distance from the top of the bubble to the tail's point.
  ///
  /// Measured from the TOP rather than centred, so it lands beside Pan's face.
  /// Centring it would drift the tail down to the middle of a bubble whose
  /// height depends entirely on how much the coach had to say, and on a long
  /// message it would end up pointing at his handle.
  ///
  /// Tuned against a render: Pan's eyes sit about this far below the top of
  /// his box, so at 20 the tail pointed at his rim and the steam above it.
  static const double tailTop = 34;

  const _BubbleBorder({required this.border, this.radius = 16, this.tail = 7});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(left: tail);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final body = Rect.fromLTRB(
      rect.left + tail,
      rect.top,
      rect.right,
      rect.bottom,
    );
    // Clamped so a very short bubble cannot put the tail outside its own body.
    final y = rect.top + tailTop.clamp(radius + tail, body.height - tail);
    return Path.combine(
      PathOperation.union,
      Path()..addRRect(RRect.fromRectAndRadius(body, Radius.circular(radius))),
      Path()..addPolygon([
        Offset(rect.left, y),
        Offset(body.left + 1, y - tail),
        Offset(body.left + 1, y + tail),
      ], true),
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    canvas.drawPath(
      getOuterPath(rect, textDirection: textDirection),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
  }

  @override
  ShapeBorder scale(double t) =>
      _BubbleBorder(border: border, radius: radius * t, tail: tail * t);
}

class ExportScreen extends StatefulWidget {
  final SalapifyStore store;
  const ExportScreen({super.key, required this.store});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  // Built ONCE when the screen opens (a big store makes a big string, and
  // re-encoding it on every rebuild would jank). The store is never written
  // to from this screen.
  late final String text = widget.store.exportBackupText();
  bool _sharing = false;
  bool _saving = false;

  Future<void> _shareFile() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sharing = true);
    try {
      await shareBackupFile(widget.store, DateTime.now());
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not open the share sheet, nothing was lost. $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _saveToPhone() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final saved = await saveBackupFileToDevice(widget.store, DateTime.now());
      if (saved) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Backup saved. Check your Downloads or the folder you picked.',
            ),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save the file, nothing was lost. $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final txns = (store.data['transactions'] as List).length;
    final accounts = (store.data['accounts'] as List).length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: const Text('Export backup'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Everything in this app: $accounts ${accounts == 1 ? 'account' : 'accounts'}, $txns ${txns == 1 ? 'entry' : 'entries'}, IOUs, goals, settings. Save it as a file to your phone, Google Drive, or email, or copy the text. Salapify imports either one unchanged.',
                style: TextStyle(
                  color: Barako.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Barako.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Barako.border),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text,
                      style: TextStyle(
                        color: Barako.textSecondary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // The save dialog, share sheet, and temp file need a native
              // platform; on the web preview only the copy button works.
              if (!kIsWeb) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Barako.primary,
                      foregroundColor: Barako.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _saving ? null : _saveToPhone,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: Text(
                      _saving ? 'Saving...' : 'Save to this phone',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Barako.border),
                      foregroundColor: Barako.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _sharing ? null : _shareFile,
                    icon: _sharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share),
                    label: Text(
                      _sharing ? 'Preparing...' : 'Share a file',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Barako.border),
                    foregroundColor: Barako.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: text));
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Copied. Paste it somewhere safe, like a note or an email to yourself.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text(
                    'Copy backup text',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImportScreen extends StatefulWidget {
  final SalapifyStore store;
  const ImportScreen({super.key, required this.store});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final controller = TextEditingController();
  String? error;
  bool busy = false;

  /// Pick a backup file from the phone or Drive, then run the same validated
  /// import the paste path uses. A cancelled pick or an unreadable file is
  /// reported, never a silent no-op. The file text is NOT mirrored into the
  /// paste field: a multi-megabyte backup in an editable field would jank.
  Future<void> _pickFile() async {
    final messenger = ScaffoldMessenger.of(context);
    String? text;
    try {
      text = await pickBackupFileText();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not read that file. $e')),
      );
      return;
    }
    if (text == null) return; // cancelled
    if (!mounted) return;
    await _runImport(text.trim());
  }

  Future<void> _import() => _runImport(controller.text.trim());

  Future<void> _runImport(String text) async {
    // Validate BEFORE the scary dialog, like the RN app: garbage should get
    // the JSON error, never a replace-everything confirm.
    try {
      parseBackupObject(jsonDecode(text));
    } on NewerBackupException catch (e) {
      setState(() => error = e.message);
      return;
    } on NotABackupException catch (e) {
      setState(() => error = e.message);
      return;
    } on FormatException {
      setState(
        () => error =
            'That text is not valid JSON. Copy the whole backup from the Backup screen and paste it unchanged.',
      );
      return;
    } catch (e) {
      // Anything else (a StackOverflowError from a deeply nested file, an
      // int overflow deep in a migration) must not escape and red-screen the
      // tab. Fail closed with a friendly message, before any confirm.
      setState(
        () => error =
            'That file could not be read as a Salapify backup. Try exporting a fresh backup.',
      );
      return;
    }
    // Importing over existing data replaces EVERYTHING in one tap, the most
    // destructive action in the app, so it confirms first, the same standard
    // the RN app holds for replaceAll. A snapshot of the outgoing data is
    // kept on disk by the store, but a stray tap should never need it.
    if (widget.store.hasData) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Barako.card,
          title: Text(
            'Replace everything?',
            style: TextStyle(color: Barako.text),
          ),
          content: Text(
            'Everything currently in this preview app will be replaced by '
            'the backup you chose. Salapify keeps a copy of what is here now, '
            'and Menu has a way to put it back if this was a mistake.',
            style: TextStyle(color: Barako.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel', style: TextStyle(color: Barako.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Replace', style: TextStyle(color: Barako.warning)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.importBackupText(text);
      if (mounted) Navigator.of(context).pop();
    } on NewerBackupException catch (e) {
      if (mounted) setState(() => error = e.message);
    } on NotABackupException catch (e) {
      if (mounted) setState(() => error = e.message);
    } on FormatException {
      if (mounted) {
        setState(
          () => error =
              'That text is not valid JSON. Copy the whole backup from the Backup screen and paste it unchanged.',
        );
      }
    } catch (e) {
      // The snapshot or save failed; the store aborted or rolled back, so
      // nothing was replaced. Say so instead of failing silently.
      if (mounted) {
        setState(() => error = 'Could not import, so nothing was changed. $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: const Text('Import backup'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a backup file (from your phone, Google Drive, or Files), or paste the backup text. Importing replaces everything currently in this app with the backup.',
                style: TextStyle(
                  color: Barako.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Barako.primary,
                    foregroundColor: Barako.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: busy ? null : _pickFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text(
                    'Choose a backup file',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Or paste the backup text',
                style: TextStyle(
                  color: Barako.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(
                    color: Barako.text,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: '{"app":"salapify", ...}',
                    hintStyle: TextStyle(color: Barako.faint),
                    filled: true,
                    fillColor: Barako.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Barako.border),
                    ),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: TextStyle(color: Barako.warning, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Barako.primary,
                    foregroundColor: Barako.onPrimary,
                  ),
                  onPressed: busy ? null : _import,
                  child: Text(busy ? 'Importing...' : 'Import'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
