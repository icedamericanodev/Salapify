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
import '../data/qr_vault.dart';
import '../data/store.dart';
import '../money/coach.dart' as coach;
import '../money/commitments.dart' show upcomingCommitments;
import '../money/cycle.dart';
import '../money/greeting.dart';
import '../money/pan_mood.dart';
import '../money/statements.dart';
import '../theme.dart';
import '../typography.dart';
import '../widgets/treat_card.dart';
import '../widgets/week_chain.dart';
import '../widgets/screen_header.dart' show HeaderAction, MenuAction;
import '../widgets/section.dart';
import '../widgets/bills_before_payday.dart';
import '../widgets/spoken_for_bar.dart';
import '../widgets/pan_mascot.dart';
import '../money/format.dart' show formatMoney, formatMoneyAbout, prettyDay;
import '../money/base_currency_scope.dart' show baseCurrencyOf;
import '../money/currencies.dart' show formatForeign;
import '../money/fx_totals.dart' show resolveRate;
import '../money/fxrates.dart' show convertAmount;
import '../money/sample_data.dart' show hasSampleData;
import '../money/timeline.dart' show sweldoTimeline, freeHorizonDays;
import '../widgets/amount_text.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/timeline_sparkline.dart';
import 'cashflow.dart';
import 'debts.dart';
import 'goals.dart';
import 'log_sheet.dart';
import 'pan.dart';
import 'accounts.dart';
import 'search.dart';
import 'shell.dart';
import '../content/course_sequences.dart';
import 'learn.dart';
import '../widgets/salapify_icon.dart';

// formatMoney moved to money/format.dart so the home screen tile, which must
// stay free of Flutter imports, can use the SAME function rather than the
// whole-peso one. It is re-exported here because thirty-odd screens already
// import it from this file, and because the alternative, a second copy, is
// precisely the bug that forced the move: the tile printed 413 where Home
// printed 412.50, for the same number, at the same instant.
export '../money/format.dart' show formatMoney, formatMoneyAbout, prettyDay;

/// An ISO date as a short human day, "Jul 27".
///
/// Hoisted out of _yourNumberCard, where it was a local closure, the moment a
/// second card needed the same format. Two copies of a date formatter drift
/// the same way two copies of a money formatter do, and the bills list sits
/// directly under the card that used to own this one.
///
/// Junk in, junk out ON PURPOSE: an unparseable date returns unchanged rather
/// than throwing, so a hand-edited backup cannot take Home down.

class OverviewScreen extends StatelessWidget {
  final SalapifyStore store;
  final void Function(Destination)? onSwitchTab;

  /// Opens Menu. Home keeps its wordmark instead of adopting ScreenHeader, so
  /// it wires MenuAction into its own row rather than getting it for free.
  final VoidCallback? onMenu;

  /// Jumps to the Utang tab with the "Owed to me" segment showing. A check-in
  /// like "Follow up Migs" is about money owed TO the user, and plain
  /// onSwitchTab would land it on the default "I owe" segment, a screen with
  /// no Migs anywhere on it. Falls back to onSwitchTab when absent.
  final VoidCallback? onOpenReceivables;

  /// The mirror jump: the Utang tab with "I owe" showing, for a due-soon
  /// debt check-in. Falls back to pushing the standalone screen when absent.
  final VoidCallback? onOpenPayables;

  /// The clock, injectable so a test can pin the date.
  ///
  /// This seam exists because three fixture rewrites in a row failed to make a
  /// Home test hold on every calendar date through the LIVE clock, and each
  /// failure was legitimate app behaviour: recurring bills get posted and
  /// stamped on load, and banking adjustment can push a due date past a
  /// weekend payday. Some real dates genuinely have no committed money, so a
  /// test that needs committed money must pick its date rather than inherit
  /// whatever day the suite runs. The app never passes this; it defaults to
  /// the real clock.
  final DateTime Function() clock;
  const OverviewScreen({
    super.key,
    required this.store,
    this.onSwitchTab,
    this.onMenu,
    this.onOpenReceivables,
    this.onOpenPayables,
    this.clock = DateTime.now,
  });

  @override
  Widget build(BuildContext context) {
    final data = store.data;
    // One clock for the whole build, so a midnight straddle can never show
    // the check-in for one day and the number for the next in the same frame.
    final now = clock();
    final parts = netWorthParts(data, fx: store.fxTable);
    final istmt = incomeStatement(data, now);
    final accounts = (data['accounts'] as List).cast<Map<String, dynamic>>();
    // The Home tail PREVIEWS accounts, the top three by balance, and the card
    // opens the full Accounts screen. Comparison only, never a widget-side
    // sum: the money math for totals lives in the engines. Original order is
    // the tiebreak so equal balances keep the user's own arrangement.
    //
    // A foreign balance ranks by its CONVERTED value when a rate exists
    // (resolveRate and convertAmount are the engines' own golden-locked
    // helpers), and at face value when none does; otherwise a dollar account
    // that is really the biggest would hide behind the fold. The same
    // foreign-or-not answer drives the row's label below, so a dollar
    // balance is never printed behind a peso sign.
    final fx = store.fxTable;
    final baseCode = baseCurrencyOf(data);
    String? foreignCodeOf(Map<String, dynamic> a) {
      final c = a['currencyCode'];
      if (c is! String || c.isEmpty) return null;
      return c.toUpperCase() == baseCode ? null : c.toUpperCase();
    }

    double rankOf(Map<String, dynamic> a) {
      final raw = amount(a['balance']);
      final code = foreignCodeOf(a);
      if (code == null || fx == null) return raw;
      return convertAmount(raw, resolveRate(fx, code).basePerUnit) ?? raw;
    }

    final accountsPreview = () {
      final idx = [for (final (i, a) in accounts.indexed) (i, a)];
      idx.sort((x, y) {
        final c = rankOf(y.$2).compareTo(rankOf(x.$2));
        return c != 0 ? c : x.$1.compareTo(y.$1);
      });
      return [for (final e in idx.take(3)) e.$2];
    }();
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
    // One pulse per screen: when the calm check-in row is showing its
    // all-clear, the hero does not also say its fitting pace line. The two
    // were the same reassurance twice. The over-pace warning is never
    // suppressed; it is information, not reassurance.
    final checkInIsGood = checkIn != null && checkIn['tone'] == 'good';
    // Payday morning: the three-minute ritual card, fully derived from the
    // ledger (the salary-logged state IS the data, no stored flag exists to
    // drift). Only when writes are open, since both its actions write.
    final ritual = store.canWrite
        ? paydayRitual(data, now)
        : const PaydayRitual(isPayday: false, salaryLogged: false);

    // Whether Your Number's bar is about to print the committed figure. This
    // is deliberately ONE expression rather than two that happen to agree:
    // it is the guard on the bar itself (overview.dart, `s.liquid > s.available`)
    // conjoined with the guard on the card that contains it. Computed apart,
    // the two would drift the first time either condition changed and the
    // duplicate would come back silently.
    final committedShown = cycle.show && cycle.liquid > cycle.available;

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
    //
    // The wordmark row (Search and Menu keys) is PINNED above the list, the
    // same shape as every other tab since the founder's call. Only the 48dp
    // key row pins; the greeting scrolls with the content, which keeps the
    // fixed band as short as it can be.
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Gap.gutter,
              Gap.gutter,
              Gap.gutter,
              0,
            ),
            child: Row(
              children: [
                Text(
                  '₱',
                  style: AppText.title
                      .copyWith(fontSize: 30)
                      .tint(Barako.primary),
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
                      style: AppText.title.copyWith(
                        fontSize: 26,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
                // Search wears the same raised key as Menu so the pair reads as
                // one set of controls; a bare glyph next to a bordered square
                // would look like one button and one leftover.
                HeaderAction(
                  icon: 'search',
                  tooltip: 'Search',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SearchScreen(
                        store: store,
                        onSwitchTab: onSwitchTab,
                        onOpenReceivables: onOpenReceivables,
                        onOpenPayables: onOpenPayables,
                      ),
                    ),
                  ),
                ),
                // An explicit gap: two bordered containers must not touch the
                // way two padded IconButtons could.
                if (onMenu != null) ...[
                  const SizedBox(width: Gap.sm),
                  // Home keeps the wordmark rather than adopting ScreenHeader,
                  // so the same MenuAction the other four get from their header
                  // is placed by hand here. One widget, one tooltip, one tap
                  // target, five screens.
                  MenuAction(onTap: onMenu!),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: Insets.tabScreen.copyWith(top: Gap.xs),
              children: [
                // The greeting sits under the wordmark rather than replacing it,
                // so the app still says what it is on the screen a new user opens
                // first. It reads fine with no name, which is the DEFAULT: the
                // ask is skippable and every existing user has none. It scrolls
                // with the content on purpose: the pinned band stays 48dp.
                Text(
                  // The build's own clock, not a second DateTime.now(). One frame
                  // must never mix two readings of the time, which is the same
                  // reason `now` is captured once at the top of build.
                  greetingFor(now, name: store.displayName),
                  style: AppText.bodyMuted.copyWith(height: 1.3),
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
                // The sample-data banner keeps the onboarding promise: the
                // seeded rows are clearly marked and leave in one tap. It sits
                // above everything because every figure below it is partly
                // fiction while sample rows exist, and it must never be
                // mistakable for a card about the user's own money.
                if (store.canWrite && hasSampleData(data))
                  _sampleBanner(context),
                // Home answers one question above the fold: how much can I safely
                // spend. Everything below is ordered around protecting that.
                //
                // The payday ritual comes first ONLY while the salary is unlogged,
                // because logging it changes every number underneath. Once logged it
                // drops below, since it is then a receipt rather than a task. It was
                // unconditionally first, and on payday that pushed Your Number to
                // roughly 530 logical pixels down a 800pt screen, right at the fold.
                if (ritual.isPayday && !ritual.salaryLogged) ...[
                  _paydayCard(context, ritual, numberShows: cycle.show),
                  const SizedBox(height: Gap.lg),
                ],
                // An URGENT check-in outranks the number.
                //
                // Worth writing down, because it looks like dead code and is not:
                // the coach's only urgent tone is 'crunch', fired when
                // liquid > 0 && available <= 0, and cycleStatus hides Your Number on
                // exactly that condition. So in practice this card sits above
                // _daysToPaydayCard, never above Your Number, and the two can never
                // both be on screen. Deleting this branch would still look correct
                // right up until the coach grows a second urgent kind.
                if (checkIn != null && checkIn['tone'] == 'urgent') ...[
                  _checkInCard(context, checkIn, now),
                  const SizedBox(height: Gap.lg),
                ],
                if (cycle.show) ...[
                  _yourNumberCard(
                    context,
                    cycle,
                    hidePace: checkInIsPayday,
                    hideFittingPace: checkInIsGood,
                  ),
                  const SizedBox(height: Gap.lg),
                ] else if (hasStarted && dues['daysLeft'] is int) ...[
                  // The countdown used to live ONLY inside Your Number, which
                  // hides whenever there is nothing positive to spend. So the
                  // answer to "how long do I have to hold out" disappeared exactly
                  // when money was tight, which is the one time anybody asks it.
                  // Shown only in that gap: when Your Number renders, it already
                  // says how many days are left, and two countdowns on one screen
                  // is worse than none.
                  _daysToPaydayCard(dues),
                  const SizedBox(height: Gap.lg),
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
                    committedShownAbove: committedShown,
                    onMore: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CashFlowScreen(store: store),
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.lg),
                ],
                // The payday ritual once the salary IS logged: below the number it
                // just refreshed, because at that point it reports rather than asks.
                if (ritual.isPayday && ritual.salaryLogged) ...[
                  _paydayCard(context, ritual, numberShows: cycle.show),
                  const SizedBox(height: Gap.lg),
                ],
                // A normal, positive or informational check-in, AFTER the number.
                //
                // This is the change that actually moves Your Number up the screen.
                // weeklyCheckIn always returns something, falling back to a cheerful
                // "You are on track this week", so this card was an unconditional
                // 180 to 210 logical pixels paid BEFORE the number on every populated
                // Home. A user in perfect financial health read two hundred pixels of
                // good news before reaching the figure they opened the app for.
                if (checkIn != null && checkIn['tone'] != 'urgent') ...[
                  _checkInCard(context, checkIn, now),
                  const SizedBox(height: Gap.lg),
                ],
                // The road ahead at a glance: the Sweldo Timeline's free
                // window as a sparkline, with the tightest day named. Only
                // once something is projectable (a recurring item or a debt
                // schedule); an empty projection is a flat line that says
                // nothing. Tapping opens the full Cash flow screen. BELOW the
                // check-in on purpose: a glance at the future must not push
                // today's one decision out of the first viewport, which is
                // exactly what happened when this card sat above it (caught
                // by the smoke test, not by an eye).
                if (hasStarted)
                  ..._timelineCard(context, data.cast<String, dynamic>(), now),
                // Only invite a fresh start when the store really is empty. After a
                // failed read the data looks empty but is not, writes are blocked,
                // and the error banner above already explains it, so the welcome
                // lanes (which would be dead or misleading) are suppressed.
                if (!hasStarted) ...[
                  if (store.loadError == null) ...[
                    _welcomeCard(context),
                    const SizedBox(height: Gap.lg),
                    // Offered to a brand new user too, and that is the whole
                    // point rather than an afterthought: someone who has
                    // logged nothing yet is exactly who a two minute lesson
                    // helps most, and the first draft of this card lived
                    // only in the started branch, so the people who most
                    // needed the door never saw it.
                    ..._nextLessonCard(context, now),
                  ],
                ] else ...[
                  // The habit layer, RN's Home order: the chain, then the
                  // treat, then the month numbers. Habits sit above the
                  // stats because the stats only improve when the habit
                  // holds.
                  WeekChainCard(
                    transactions: data['transactions'],
                    clock: clock,
                  ),
                  const SizedBox(height: Gap.lg),
                  TreatCard(store: store, clock: clock),
                  const SizedBox(height: Gap.lg),
                  // From here down is the TAIL: the lesson offer, the month,
                  // what it is made of, and the whole picture. Borderless
                  // tinted surfaces at a tighter rhythm, so the footer reads
                  // as one quiet band instead of four more bordered
                  // headlines competing with the money cards above (the
                  // audit's Phase 3).
                  ..._nextLessonCard(context, now),
                  // Tappable: THIS MONTH is made of Activity's rows, so the
                  // card leads there. It was a dead surface between two
                  // tappable siblings, the last cards on Home that informed
                  // without leading anywhere.
                  Semantics(
                    button: true,
                    label: 'This month, open Activity',
                    child: _tailCard(
                      onTap: onSwitchTab == null
                          ? null
                          : () => onSwitchTab!(Destination.history),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Kicker('THIS MONTH'),
                              const Spacer(),
                              if (onSwitchTab != null)
                                ExcludeSemantics(
                                  child: Icon(
                                    salapifyIcon('forward'),
                                    size: 18,
                                    color: Barako.muted,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // The ANSWER first, its two parts underneath. This was
                          // three equal rows and a divider, which made the reader
                          // do the subtraction with their eyes before learning
                          // whether the month was up or down. The net is the only
                          // figure most people want, so it gets the headline.
                          Builder(
                            builder: (context) {
                              final net = istmt['netIncome'] as double;
                              // The sign is explicit on a gain. Without it a
                              // good month and a bad month look identical
                              // until you notice the minus.
                              return AmountText(
                                net,
                                role: AmountRole.lg,
                                signed: true,
                                tint: net >= 0
                                    ? Barako.primary
                                    : Barako.warning,
                              );
                            },
                          ),
                          const SizedBox(height: Gap.md),
                          StatPair(
                            leftLabel: 'Money in',
                            leftValue: formatMoney(istmt['income'] as double),
                            leftColor: Barako.primary,
                            rightLabel: 'Money out',
                            rightValue: formatMoney(
                              istmt['expenses'] as double,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.sm),
                  if (accounts.isNotEmpty) ...[
                    // Tappable for the same reason: the rows ARE accounts, so
                    // the card opens the Accounts screen.
                    Semantics(
                      button: true,
                      label: 'Accounts, open Accounts',
                      child: _tailCard(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AccountsScreen(
                              store: store,
                              onOpenPayables: onOpenPayables,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // 'ACCOUNTS', matching the Menu row and the
                                // screen this card opens: one name per
                                // destination teaches navigation for free,
                                // and 'MY MONEY' overlapped NET WORTH below.
                                Kicker('ACCOUNTS'),
                                const Spacer(),
                                ExcludeSemantics(
                                  child: Icon(
                                    salapifyIcon('forward'),
                                    size: 18,
                                    color: Barako.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Flat rows with hairline separators, the same content
                            // treatment as Utang's people list. Rows in a card, not
                            // a card per row.
                            for (final (i, a) in accountsPreview.indexed) ...[
                              if (i > 0)
                                Divider(height: 1, color: Barako.border),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        a['name'] as String? ?? 'Account',
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.bodyLg,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // A big balance scales down instead of
                                    // overflowing the row on a narrow phone
                                    // (AmountText and the foreign FittedBox
                                    // both scale, never clip). A foreign
                                    // account keeps its own symbol; the
                                    // converted figure and its provenance
                                    // live on the Accounts screen this card
                                    // opens. Both branches wear the plain
                                    // row face: the old w6-at-16 fork was
                                    // exactly the drift amountRow's strict
                                    // rule exists to end.
                                    Flexible(
                                      child: foreignCodeOf(a) == null
                                          ? AmountText(
                                              amount(a['balance']),
                                              role: AmountRole.row,
                                              tint: Barako.textSecondary,
                                              textAlign: TextAlign.right,
                                            )
                                          : FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                formatForeign(
                                                  amount(a['balance']),
                                                  foreignCodeOf(a)!,
                                                ),
                                                maxLines: 1,
                                                style: AmountText.styleFor(
                                                  AmountRole.row,
                                                ).tint(Barako.textSecondary),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // Past three, a caption names the fold. No peso
                            // figure here on purpose: a widget-side sum is
                            // forbidden, and the engines' totals (liquid,
                            // net worth) exclude kinds this list includes.
                            if (accounts.length > 3) ...[
                              Divider(height: 1, color: Barako.border),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Text(
                                  'and ${accounts.length - 3} more accounts',
                                  style: AppText.caption.tint(
                                    Barako.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Gap.sm),
                  ],
                  // The month, then what it is made of, then the whole picture.
                  // Net worth is the least urgent figure on Home and the slowest
                  // to change, so it reads as a footer rather than a headline.
                  _netWorthFooter(parts),
                ],
              ],
            ),
          ),
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
  /// The clearly-marked flag over seeded rows, and the one tap that removes
  /// them all. Accent border, not the warning color: sample data is an
  /// invitation, not a problem.
  Widget _sampleBanner(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: Gap.lg),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Barako.card,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: Barako.primary),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker('SAMPLE DATA'),
        const SizedBox(height: 6),
        Text(
          'These accounts, debts, and entries are examples so you can look '
          'around. Your own money is untouched, and none of this feeds your '
          'chain.',
          style: AppText.label.w4
              .tint(Barako.textSecondary)
              .copyWith(height: 1.4),
        ),
        const SizedBox(height: Gap.md),
        OutlinedButton(
          onPressed: () => store.removeSampleData(),
          style: OutlinedButton.styleFrom(
            foregroundColor: Barako.primaryText,
            side: BorderSide(color: Barako.primary),
          ),
          child: const Text(
            'Remove sample data',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _checkInCard(
    BuildContext context,
    Map<String, dynamic> c,
    DateTime now,
  ) {
    final tone = c['tone'] as String;
    final action = c['action'];
    final route = action is Map ? action['route'] as String? : null;
    final tab = route != null ? _routeTabs[route] : null;
    VoidCallback? onTap;
    if (route == '/receivables' && onOpenReceivables != null) {
      // Receivables means the "Owed to me" segment specifically, and the
      // shell knows how to land there. Plain onSwitchTab is the fallback
      // below, for hosts that do not wire the richer callback.
      onTap = onOpenReceivables;
    } else if (tab != null && onSwitchTab != null) {
      onTap = () => onSwitchTab!(tab);
    } else if (route == '/debts' && onOpenPayables != null) {
      // A due-soon decision means the user's own debts: the "I owe" segment
      // of the Utang tab, where the bottom bar still works. Pushing the
      // standalone DebtsScreen here stranded the user on a copy of the tab.
      onTap = onOpenPayables;
    } else if (route == '/debts') {
      // Fallback for hosts that do not wire the richer callback: still not a
      // dead end.
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
    // The all-clear earns one quiet row, not 80dp of Pan and a bubble every
    // single day. Pan stays big where he has something to SAY (watch, nudge,
    // urgent); the good tone is a check, one line, and the same tap through
    // to Ask Pan. This is also half of the one-pulse rule: the slim row and
    // the hero's pace line stop stacking two all-clears.
    if (good) {
      return PressableScale(
        child: Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.card),
            // The hint keeps the door audible: the full Pan card announced
            // "Ask Pan", and a sighted-only slim row would have silently
            // dropped that for screen reader users.
            child: Semantics(
              button: true,
              hint: 'Opens Ask Pan',
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      salapifyIcon('check'),
                      size: 20,
                      color: Barako.primary,
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Text(
                        c['title'] as String,
                        style: AppText.bodyStrong.tint(Barako.primaryText),
                      ),
                    ),
                    Icon(
                      salapifyIcon('forward'),
                      size: 18,
                      color: Barako.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final Widget card = Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
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
                          // The build's one clock, threaded in, never a second
                          // DateTime.now(): the comment at the top of build
                          // exists precisely so a midnight straddle cannot
                          // split the frame, and a second clock here also broke
                          // the injectable-clock seam for tests.
                          mood:
                              panMoodForRecentAction(
                                store.lastActionKind,
                                store.lastActionAt,
                                now,
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
                                  salapifyIcon('done'),
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
                                  style: AppText.bodyStrong
                                      .tint(titleColor)
                                      .copyWith(height: 1.25),
                                ),
                              ),
                              // Always shown now, because the card always has
                              // somewhere to go: the coach's destination, or
                              // Ask Pan when there is not one.
                              Icon(
                                salapifyIcon('forward'),
                                color: Barako.faint,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c['message'] as String,
                            style: AppText.small.copyWith(height: 1.4),
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
    // The RECEIPT state: salary logged and the fresh number is visible right
    // below. At that point three sentences and two buttons were repeating
    // what the hero already shows, ~170dp of told-you-so. One row keeps the
    // one action still worth taking (savings first) and gets out of the way.
    // When the number is NOT showing, the full card stays: its explanation of
    // why is the only truth on screen.
    if (r.salaryLogged && numberShows) {
      return Card(
        color: Barako.surfaceRaised,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Icon(salapifyIcon('cash'), color: Barako.primary, size: 18),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  'Salary logged. Your cycle is set.',
                  style: AppText.bodyStrong,
                ),
              ),
              const SizedBox(width: Gap.md),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => GoalsScreen(store: store)),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Barako.primaryText,
                  side: BorderSide(color: Barako.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.md,
                    vertical: Gap.sm,
                  ),
                ),
                child: Text('Savings first', style: AppText.small.w7),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      color: Barako.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(salapifyIcon('cash'), color: Barako.primary, size: 18),
                const SizedBox(width: 8),
                Kicker('PAYDAY'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              r.salaryLogged
                  ? 'Salary logged. Your cycle is set.'
                  : 'It is payday. Three minutes sets your whole cycle.',
              style: AppText.bodyLg.w7,
            ),
            const SizedBox(height: 4),
            Text(
              // Never point at a card that is not there: when available is
              // still <= 0 (salary logged to no account, or smaller than the
              // committed bills), the number card below does not render, so
              // the sentence points at what IS true instead.
              r.salaryLogged
                  ? numberShows
                        ? 'Your safe-to-spend below is fresh from the new '
                              'balance. Moving a little to savings first, '
                              'before the spending starts, is what makes it '
                              'honest.'
                        : 'Your safe-to-spend appears below once the salary '
                              'sits in an account with room past the upcoming '
                              'bills.'
                  : 'Log your salary, move a little to savings first, and '
                        'carry your safe-to-spend until the next payday.',
              style: AppText.small.copyWith(height: 1.4),
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
  /// The Sweldo Timeline glance card: the free window's balance line as a
  /// sparkline plus one sentence naming the tightest day. Returns an empty
  /// list when nothing is projectable yet, so Home pays no pixels for a
  /// flat line that says nothing.
  List<Widget> _timelineCard(
    BuildContext context,
    Map<String, dynamic> data,
    DateTime ref,
  ) {
    final tl = sweldoTimeline(
      data,
      ref,
      horizonDays: freeHorizonDays(data, ref),
    );
    final assumptions = (tl['assumptions'] as Map).cast<String, dynamic>();
    if ((assumptions['recurringCount'] as int) == 0 &&
        (assumptions['debtCount'] as int) == 0) {
      return const [];
    }
    final days = (tl['days'] as List).cast<Map<String, dynamic>>();
    final lowest = tl['lowest'] as Map;
    final lowBal = (lowest['balance'] as num).toDouble();
    final lowDate = lowest['date'].toString();
    final start = (tl['startBalance'] as num).toDouble();
    final anyNegative = tl['anyNegative'] == true;
    final hasPayday = (tl['paydays'] as List).isNotEmpty;
    final String caption;
    if (anyNegative) {
      // The day cash FIRST crosses zero, matching the decision card and the
      // lookahead reminder; naming the lowest day here showed a different
      // date for the same event.
      final runOut = (tl['firstNegativeDate'] as String?) ?? lowDate;
      caption =
          'Cash is projected to run short around ${prettyDay(runOut)}. '
          'Tap to see the tight days.';
    } else if (lowBal < start) {
      caption =
          'Tightest around ${prettyDay(lowDate)} at ${formatMoney(lowBal)}, '
          'then it recovers.';
    } else {
      caption = hasPayday
          ? 'Steady to payday at this pace.'
          : 'Steady to the end of the month at this pace.';
    }
    return [
      // PressableScale, the house rule for every tappable Home card: a card
      // that navigates but does not press reads as static and never gets
      // tapped.
      PressableScale(
        child: Card(
          child: Semantics(
            button: true,
            label: 'Cash ahead. $caption',
            child: ExcludeSemantics(
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.card),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CashFlowScreen(store: store),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              // 'CASH AHEAD', not 'THE ROAD AHEAD': the
                              // sparkline plots projected cash, so the kicker
                              // names the money, not a metaphor.
                              'CASH AHEAD',
                              style: Barako.kickerStyle,
                            ),
                          ),
                          Icon(
                            salapifyIcon('forward'),
                            size: 18,
                            color: Barako.faint,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TimelineSparkline(
                        days: days,
                        anyNegative: anyNegative,
                        lowDate: lowDate,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        caption,
                        style: AppText.caption
                            .tint(
                              anyNegative
                                  ? Barako.warningStrong
                                  : Barako.textSecondary,
                            )
                            .copyWith(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: Gap.lg),
    ];
  }

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
            // NOT an AmountText, deliberately: this is a count of days, not
            // money, so it stays a plain Text on the amount face. Feeding it
            // through the money widget would wrap it in formatMoney and print
            // a peso sign on a duration.
            Text(
              '$days ${days == 1 ? 'day' : 'days'}',
              style: AppText.amount.w7.copyWith(fontFeatures: const []),
            ),
            if (payday.length >= 10) ...[
              const SizedBox(height: 2),
              Text('Until ${prettyDay(payday)}.', style: AppText.small),
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
    // Suppresses only the FITTING branch (the reassurance), never the
    // over-pace warning: when the calm check-in row is already saying all
    // clear, a second all-clear here is the double pulse the panel flagged,
    // but a warning is information and always speaks.
    bool hideFittingPace = false,
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
        // Says the finish line, so the praise is verifiable: the pace is
        // measured against the payday projection, and the over-pace branch
        // below already names it. The two branches are symmetric now.
        ? (hideFittingPace ? null : 'This pace holds to payday. Keep going.')
        : 'Recent pace is about ${formatMoneyAbout(s.dailyPace)} '
              'a day. Easing ${formatMoney(easeWhole)} a day keeps you '
              'covered to payday.';

    return PressableScale(
      child: Semantics(
        button: onSwitchTab != null,
        hint: onSwitchTab != null ? 'Opens Insights' : null,
        // The one raised surface on Home. surfaceRaised used to belong to net
        // worth, which made the calmest, slowest-moving figure on the screen
        // look like the headline. The hero treatment follows the question the
        // screen exists to answer.
        child: Card(
          color: Barako.surfaceRaised,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.card),
            onTap: onSwitchTab == null
                ? null
                : () => onSwitchTab!(Destination.insights),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 'SAFE TO SPEND', not 'YOUR NUMBER': the old kicker
                      // failed the stranger test (a number of what?), and with
                      // the amount line ending in "a day" the card now teaches
                      // itself: SAFE TO SPEND, PX a day.
                      Kicker('SAFE TO SPEND'),
                      const Spacer(),
                      Icon(
                        salapifyIcon('forward'),
                        color: Barako.faint,
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatMoney(s.perDay),
                          // The ladder face for an xl amount, via the shared
                          // resolver so the hero and every other figure make
                          // one decision about weight and tabular digits. A
                          // span, not an AmountText, because the "a day"
                          // suffix must wrap WITH the number as one line.
                          style: AmountText.styleFor(AmountRole.xl),
                        ),
                        TextSpan(
                          text: '  a day',
                          style: AppText.label.tint(Barako.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(sub, style: AppText.small.copyWith(height: 1.4)),
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
                      style: AppText.caption
                          .tint(
                            paceFits
                                ? Barako.primaryText
                                : Barako.textSecondary,
                          )
                          .copyWith(height: 1.4),
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

  /// The tail's closing row. Net worth is the least urgent figure on Home and
  /// the slowest to change, so it wears the same quiet tinted surface as its
  /// tail neighbours rather than a bordered card, let alone the raised hero
  /// it once was (that surface belongs to Your Number now). Numbers come
  /// straight from the golden-locked netWorthParts, this only restyles them.
  Widget _netWorthFooter(Map<String, dynamic> parts) {
    final nw = parts['netWorth'] as double;
    return _tailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker('NET WORTH'),
          const SizedBox(height: 6),
          // Colour: a negative net worth is honest, not an emergency. It
          // stays in plain ink, not alarm red, so a user who owes more
          // than they hold is not shamed by the biggest number on the
          // screen. Red is reserved for urgent, time-bound things like
          // an overdue utang.
          //
          // The ladder's tabular digits now apply here too. The old literal
          // cleared them on the grounds that a lone number has no column to
          // line up with, which was true and also not a reason to keep a
          // second face: tnum on a lone figure changes nothing visible, and
          // one shared style is the whole point of the ladder.
          AmountText(
            nw,
            role: AmountRole.lg,
            tint: nw < 0 ? Barako.text : Barako.primary,
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
              style: AppText.small.copyWith(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  /// One surface of the tail band: borderless, tinted, the card radius.
  ///
  /// De-bordered on purpose (the audit's Phase 3): the tail is a footer, and
  /// four hairline boxes at the bottom of Home competed with the bordered
  /// money cards above them. The tint is ink at the wash level rather than
  /// the card fill, because a white card without its border disappears
  /// entirely on light palettes; a 6 percent ink wash reads as a soft panel
  /// on every one of the sixteen.
  ///
  /// The InkWell takes the surface's own radius, so the tap ripple clips at
  /// the corner the eye already sees (P1-5). Callers keep their own
  /// Semantics wrappers: THIS MONTH lets its figures announce themselves,
  /// the lesson row replaces its content with one spoken sentence, and this
  /// helper has no business deciding which is right.
  Widget _tailCard({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsetsGeometry padding = const EdgeInsets.all(Gap.lg),
  }) {
    final card = Material(
      color: Barako.text.withValues(alpha: BarakoAlpha.wash),
      borderRadius: const BorderRadius.all(Radius.circular(Radii.card)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    // The house press dip, exactly when the card is tappable. Gated here so
    // THIS MONTH, ACCOUNTS and the lesson row all dip the same way, and a
    // quiet informational card (NET WORTH) never pretends to be a button.
    return onTap == null ? card : PressableScale(child: card);
  }

  /// First-run card, shown in place of MY MONEY and THIS MONTH when there is no
  /// data yet. It leads with a real first action for a brand-new user (log, or
  /// jump to the one thing they came for), and keeps the "bring your data over"
  /// path as a quiet link for the tester migrating from the old app, rather
  /// than as the loud primary button a new user cannot use.
  Widget _nameAsk(BuildContext context) => _NameAsk(store: store);

  /// The one lesson offered on Home, or nothing at all.
  ///
  /// A list rather than a widget so "there is nothing to offer" costs no
  /// SizedBox and no spacing, the same spread pattern _timelineCard uses.
  ///
  /// Deliberately quiet: a tinted tail row, not a coloured hero. It is an
  /// offer, and an offer that shouts competes with the money the user
  /// actually opened the app for. It disappears entirely once every core
  /// lesson is finished, rather than degrading into a card that congratulates
  /// itself forever.
  List<Widget> _nextLessonCard(BuildContext context, DateTime now) {
    final lesson = nextCoreLesson(
      data: store.data,
      progress: store.lessonProgress,
      now: now,
    );
    if (lesson == null) return const [];
    return [
      Semantics(
        button: true,
        label:
            'Next money lesson, ${lesson.title}, '
            '${lesson.minutes} minutes. Opens Money courses.',
        child: ExcludeSemantics(
          child: _tailCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LearnScreen(
                  store: store,
                  focusId: lesson.id,
                  onSwitchTab: onSwitchTab,
                ),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  salapifyIcon('spotlight'),
                  size: 18,
                  color: Barako.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${lesson.minutes} MIN LESSON',
                        style: Barako.kickerStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(lesson.title, style: AppText.label.w7),
                    ],
                  ),
                ),
                Icon(salapifyIcon('forward'), size: 18, color: Barako.faint),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: Gap.sm),
    ];
  }

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
            style: AppText.heading.w8,
          ),
          const SizedBox(height: 6),
          Text(
            'What do you want to start with?',
            style: AppText.label.w4
                .tint(Barako.textSecondary)
                .copyWith(height: 1.4),
          ),
          const SizedBox(height: 14),
          _lane(
            context,
            salapifyIcon('receipt'),
            'Track my spending',
            'Log what you spend and see where it goes',
            () {
              if (store.canWrite) showLogSheet(context, store);
            },
          ),
          const SizedBox(height: 10),
          _lane(
            context,
            salapifyIcon('handshake'),
            'See who owes me',
            'Names and amounts, totaled for you.',
            // Money owed TO the user is the "Owed to me" segment of the Utang
            // tab. Plain onSwitchTab lands on the default "I owe" segment, a
            // screen with none of their receivables on it. Falls back to the
            // plain tab switch only where the shell did not wire the richer
            // jump.
            onOpenReceivables ?? () => onSwitchTab?.call(Destination.utang),
          ),
          const SizedBox(height: 10),
          _lane(
            context,
            salapifyIcon('decline'),
            'Pay off a debt, formal or between friends',
            'A payoff date and the cheapest way there',
            // The user's own debts live on the "I owe" segment of the Utang
            // tab, where the bottom bar still works. Pushing the standalone
            // DebtsScreen stranded the user on a copy of the tab with no way
            // back to the rest of the app; it is only the fallback for a host
            // that did not wire the segment jump.
            onOpenPayables ??
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
                // Left-aligned and quiet, but never small. This was 36 with a
                // shrinkwrapped target, below both platform floors, on the one
                // link every migrating tester has to hit. Zero horizontal
                // padding keeps the quiet left-aligned look; the height does
                // the accessibility work.
                padding: const EdgeInsets.symmetric(horizontal: 0),
                foregroundColor: Barako.muted,
                minimumSize: const Size(0, 48),
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
      borderRadius: BorderRadius.circular(Radii.control),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.control),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.control),
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
                    Text(title, style: AppText.bodyStrong),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppText.caption.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(salapifyIcon('forward'), color: Barako.faint, size: 18),
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
          Text('What should Pan call you?', style: AppText.bodyStrong),
          const SizedBox(height: 4),
          Text(
            // Said plainly because this is a money app asking for a personal
            // detail, and "it stays on this phone" is both the honest answer
            // and the reassuring one. Salapify has no server to send it to.
            'Optional, and it never leaves this phone.',
            style: AppText.small.copyWith(height: 1.4),
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
                style: AppText.label.w4
                    .tint(Barako.textSecondary)
                    .copyWith(height: 1.4),
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
                        : Icon(salapifyIcon('download')),
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
                        : Icon(salapifyIcon('share')),
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
                  icon: Icon(salapifyIcon('copy')),
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
      // A restore replaces the data, so QR files the OLD data referenced are now
      // orphans. Sweep them against the freshly imported keep-set here, rather
      // than leaving them until the next launch.
      await QrVault.inAppDocuments()
          .then((v) => v.cleanupOrphans(qrRefsInData(widget.store.data)))
          .catchError((_) => 0);
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
                style: AppText.label.w4
                    .tint(Barako.textSecondary)
                    .copyWith(height: 1.4),
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
                  icon: Icon(salapifyIcon('folder')),
                  label: const Text(
                    'Choose a backup file',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Or paste the backup text',
                style: AppText.caption.w7.copyWith(letterSpacing: 1),
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
                Text(error!, style: AppText.small.tint(Barako.warning)),
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
