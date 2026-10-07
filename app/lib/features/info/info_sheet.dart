import 'package:flutter/material.dart';

import '../../core/money/debt_ratio.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../shared/sheet_scaffold.dart';

/// The explainer behind every circled "i", ported from the prototype's
/// archive/prototype-google-ai-studio/src/components/SectionInfoModal.tsx.
///
/// WHY THIS EXISTS, in one sentence: a screen that explains itself in prose
/// stops being a dashboard. Founder direction, 2026-09-18, on reviewing the
/// first Reports build: "it seems too wordy, instead we can put the
/// explanation in the 'i' icon so the screens are still neat looking".
///
/// The rule that follows from it, and the one to apply to every future screen:
///
///   A FIGURE and the one line needed to READ it stay on the screen.
///   Everything that TEACHES goes behind the dot.
///
/// "₱26,725.25" stays. "That is 52.4% of what came in" stays, because it is
/// another figure. "A straight line from the days so far, so treat it as a
/// direction and not a forecast" goes here, because it is a lesson, and a
/// lesson is read once and then skipped forever while still taking up room.
///
/// It is NOT a place to hide something a person needs in order to avoid a
/// mistake. Anything that would cause a wrong decision if unread belongs on
/// the screen, however long it is.
class InfoSheet extends StatelessWidget {
  const InfoSheet({super.key, required this.topic, required this.palette});

  final InfoTopic topic;
  final Palette palette;

  static Future<void> show(
    BuildContext context,
    Palette palette,
    InfoTopic topic,
  ) {
    return SheetScaffold.show<void>(
      context: context,
      palette: palette,
      builder: (BuildContext context) =>
          InfoSheet(topic: topic, palette: palette),
    );
  }

  @override
  Widget build(BuildContext context) {
    final InfoContent c = infoContent[topic]!;

    return SheetScaffold(
      palette: palette,
      title: c.title,
      subtitle: c.subtitle,
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final InfoPoint p in c.points) ...<Widget>[
            _Point(palette: palette, point: p),
            const SizedBox(height: Spacing.md),
          ],
          if (c.formula != null) _Formula(palette: palette, text: c.formula!),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.palette, required this.point});

  final Palette palette;
  final InfoPoint point;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: palette.iconTile,
            borderRadius: BorderRadius.circular(Radii.control),
          ),
          // Salapify's own icons are Material glyphs in the accent. Emoji
          // belong to the user's own data and never appear here.
          child: Icon(point.icon, size: 15, color: palette.accent),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(point.title, style: AppType.rowTitle(palette)),
              const SizedBox(height: 2),
              Text(point.body, style: AppType.body(palette)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Formula extends StatelessWidget {
  const _Formula({required this.palette, required this.text});

  final Palette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('HOW IT IS WORKED OUT', style: AppType.kicker(palette)),
          const SizedBox(height: Spacing.xs),
          Text(
            text,
            style: AppType.rowTitle(palette).copyWith(color: palette.accent),
          ),
        ],
      ),
    );
  }
}

/// Every explainer the app can open. One value per dot.
enum InfoTopic {
  accounts,
  netWorth,
  countedTwice,
  performance,
  ratios,
  // `runRate` was here and is gone with the month-end forecast card it
  // explained, removed 2026-10-07. Its own text conceded the defect ("on the
  // 3rd of the month it is dividing by three days"), which is a lesson that
  // belonged in a fix rather than behind a dot.
  cashFlow,
  transfers,
  reconciliation,
  reportScope,
  debtBothWays,
  comingUp,
  budgets,
  bills,
  decisions,
  trackers,
  academy,
  reminders,
  cardCycle,
  addOnRate,
  claimableExpenses,
  bonusSplit,
  businessChecklist,
  openingBalance,
  runway,
  thisMonthVsLast,
  monthByMonth,
  cashByMonth,
  netWorthByMonth,
}

class InfoPoint {
  const InfoPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class InfoContent {
  const InfoContent({
    required this.title,
    required this.subtitle,
    required this.points,
    this.formula,
  });

  final String title;
  final String subtitle;
  final List<InfoPoint> points;
  final String? formula;
}

/// The content, in plain English rather than accountant English.
///
/// The prototype's own wording was the starting point and was rewritten where
/// it assumed knowledge: "True balance sheet for Philippine accounts" tells
/// somebody who does not know what a balance sheet is precisely nothing.
const Map<InfoTopic, InfoContent> infoContent = <InfoTopic, InfoContent>{
  InfoTopic.accounts: InfoContent(
    title: 'Accounts',
    subtitle: 'Every place your money sits, and every place it is owed from',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.account_balance_wallet_outlined,
        title: 'An account is a place, not a category',
        body:
            'Your pitaka, GCash, a payroll account, a digital savings app, an '
            'MP2 fund, a credit card, a car loan. If money can sit there or be '
            'owed from there, it belongs on this screen.',
      ),
      InfoPoint(
        icon: Icons.groups_outlined,
        title: 'The entity chips split business from personal',
        body:
            'An account you never classified shows under every entity, on '
            'purpose. A wallet that belongs nowhere in particular belongs '
            'everywhere, so it can never quietly disappear from a filter.',
      ),
      InfoPoint(
        icon: Icons.savings_outlined,
        title: 'Money set aside stops funding today',
        body:
            'Tick "Set aside" on an account and Safe to Spend stops counting '
            'it, which is what you want for an emergency fund or ipon kept in '
            'GSave, Maya or a digital bank. It still counts in your net '
            'worth, you can still pay from it, and it still counts toward how '
            'long you would last if your income stopped, because that is '
            'exactly the money that answers that question. Salapify never '
            'guesses this for you: a wallet called Savings may be the one you '
            'spend from every day.',
      ),
      InfoPoint(
        icon: Icons.credit_card_outlined,
        title: 'A credit card balance is what you OWE',
        body:
            'So it counts against you, and it is drawn with a minus. The '
            'limit is not money you have; it is how much the bank will let '
            'you borrow.',
      ),
      InfoPoint(
        icon: Icons.handshake_outlined,
        title: 'Debts are counted separately, below',
        body:
            'The total at the top is your accounts only. Money you lent a '
            'friend, and money a friend lent you, lives in the debt register '
            'underneath with its own two figures, so neither one hides inside '
            'the other.',
      ),
      InfoPoint(
        icon: Icons.public_outlined,
        title: 'Foreign balances are estimates',
        body:
            'Salapify works offline, so there is no live exchange rate. A '
            'peso figure under a dollar or Singapore dollar balance uses a '
            'fixed rate and is there for a rough sense of scale, never for a '
            'decision.',
      ),
    ],
  ),
  InfoTopic.netWorth: InfoContent(
    title: 'Net worth',
    subtitle: 'What you would have left if everything settled today',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.savings_outlined,
        title: 'What counts as yours',
        body:
            'Cash, your e-wallets, bank and digital savings, your debit card '
            'balance, investments like MP2, and money other people owe you.',
      ),
      InfoPoint(
        icon: Icons.credit_card_outlined,
        title: 'What counts against you',
        body:
            'Credit card balances, personal and gadget loans, and a mortgage. '
            'The full outstanding amount, not this month\'s payment.',
      ),
      // Money lent out is counted at its FULL remaining value, and nothing on
      // the screen says so. It is the one line in "What you own" whose figure
      // may never turn into cash, and in practice the one most often lent to
      // family. Salapify does not discount it, because only the person who
      // lent it knows whether it is coming back, so the judgement stays with
      // them. That is teaching, read once, so it belongs here and not on the
      // card: the figure itself is already on screen as "Owed to you",
      // directly above the total it feeds.
      InfoPoint(
        icon: Icons.handshake_outlined,
        title: 'Money owed to you counts in full',
        body:
            'A loan you made to somebody is counted at its full remaining '
            'amount, exactly like cash. Salapify does not guess at how likely '
            'it is to come back, because only you know that. If some of it '
            'never will, your real position is lower than the figure here.',
      ),
      InfoPoint(
        icon: Icons.trending_down,
        title: 'Below zero is common, and often fine',
        body:
            'A housing loan is large and long, so it can put this number deep '
            'into the red on its own while nothing is actually wrong. What '
            'matters is the direction it moves over months, not the sign.',
      ),
      InfoPoint(
        icon: Icons.photo_camera_outlined,
        title: 'It has no date range',
        body:
            'This is a photograph of right now, so the period buttons do not '
            'apply to it. Last month\'s net worth would need a history of '
            'past balances, which the app does not keep yet.',
      ),
    ],
    formula: 'Net worth = what you own - what you owe',
  ),

  // WHAT USED TO BE ON THE SCREEN, moved here on founder direction,
  // 2026-10-07: "it is too wordy and the users may feel flooded and
  // overwhelmed". The on-screen line keeps the names and the one clause that
  // stops a wrong reading of the headline; everything that explains lives
  // here, behind the dot beside that line.
  InfoTopic.countedTwice: InfoContent(
    title: 'Counted twice',
    subtitle: 'One balance, entered in two places',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.content_copy_outlined,
        title: 'What happened',
        body:
            'The same balance is on this page as an account and again on your '
            'Debt list. Salapify counts exactly what it is given, so it '
            'counted this one twice. Nothing is wrong with your money.',
      ),
      InfoPoint(
        icon: Icons.swap_vert,
        title: 'Why the figure is off by less than it looks',
        body:
            'A loan entered twice makes what you owe too high, which pulls the '
            'headline down. Money owed to you entered twice makes what you own '
            'too high, which pushes it up. When both happen they partly '
            'cancel, so the headline is out by the difference between them, '
            'not by the two added together.',
      ),
      InfoPoint(
        icon: Icons.groups_outlined,
        title: 'One account can match your whole list',
        body:
            'If an account holds the total of everything people owe you, it is '
            'the same money as the Owed to you side of your Debt list, just '
            'added up. That is why one account can be counted against several '
            'debts.',
      ),
      InfoPoint(
        icon: Icons.delete_outline,
        title: 'How to fix it',
        body:
            'Keep the one you use and delete the other. An account suits a '
            'balance you check, and a debt suits one you pay down or collect. '
            'Salapify will not choose for you, because only you know which you '
            'meant. The totals settle as soon as one copy is gone.',
      ),
      // CHECKED AGAINST duplicate_balances.dart, and the first draft of this
      // point was wrong. It said every match needs the two names to share a
      // word. Only the one-account-to-one-debt shape checks that; the
      // running-total shape deliberately does not ("The shared-word clause
      // does NOT apply here and must not be bolted on"), and that is the
      // receivables case on the sample ledger, the one this sheet opens on.
      InfoPoint(
        icon: Icons.rule,
        title: 'How Salapify spots it',
        body:
            'Only an exact match to the centavo, on the same side of the page. '
            'A single debt also has to share a word with the account name, '
            'because two different loans of the same round amount are common. '
            'Foreign currency accounts are never matched, because the exchange '
            'rate moves the figure.',
      ),
    ],
  ),

  InfoTopic.performance: InfoContent(
    title: 'Money in and out',
    subtitle: 'What actually happened over the period you picked',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.arrow_downward,
        title: 'Money in',
        body:
            'Everything logged as Received in this period. Salary, client '
            'payments, refunds, interest.',
      ),
      InfoPoint(
        icon: Icons.arrow_upward,
        title: 'Money out',
        body:
            'Everything logged as Spent. Moving money between your own '
            'accounts is not spending and is left out.',
      ),
      InfoPoint(
        icon: Icons.block,
        title: 'What is left out on purpose',
        body:
            'Entries you marked excluded or duplicate never reach these '
            'totals. They still show in Activity, struck through, so nothing '
            'silently disappears from your records.',
      ),
    ],
    formula: 'Kept = money in - money out',
  ),

  // THIS SHEET USED TO CONTRADICT THE CARD THAT OPENS IT, on both rows.
  //
  // The savings rate row on Reports deliberately removed a 20 percent pass
  // mark, and the comment explaining why asserted that the number "appeared
  // nowhere else in lib/". It was here, in lib/, on the sheet that same card
  // opens, still teaching 20 percent as the target. The debt row removed a
  // bare 35 sourced to what lenders commonly want, and this sheet still said
  // "about a third" sourced the same way, which is also not the canonical 30.
  //
  // So one tap apart, over one ledger, Salapify gave two answers twice. The
  // figures below now read the same constants the screen does.
  InfoTopic.ratios: InfoContent(
    title: 'The two ratios',
    subtitle: 'The quickest read on whether a month went well',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.percent,
        title: 'Savings rate',
        body:
            'The share of what you EARNED that you did not spend. Salapify '
            'sets no pass mark on this on purpose: on many salaries a fixed '
            'target after rent is simply not reachable, and a number that '
            'tells somebody doing their best that they are failing every '
            'month is worse than no number. Watch which way it moves.',
      ),
      InfoPoint(
        icon: Icons.savings_outlined,
        title: 'Money you put away still counts as saved',
        body:
            'Moving money into Pag-IBIG MP2 or any other investment leaves '
            'your wallet, so it shows under Money out. It has not gone out of '
            'your life though, so the savings rate counts it as saved. '
            'Without this, the act of saving lowered your savings rate.',
      ),
      InfoPoint(
        icon: Icons.south_west,
        title: 'Money repaid to you is left out of both',
        body:
            'When somebody pays back what they owed you, it arrives as money '
            'in, because it really did arrive. It is not something you '
            'earned, so both rates divide by what you earned instead. '
            'Otherwise a month where a friend paid you back would look like a '
            'month you did well.',
      ),
      InfoPoint(
        icon: Icons.account_balance_outlined,
        title: 'Debt servicing',
        body:
            'The share of what you earned going to loan and card repayments. '
            'Salapify treats up to $debtShareComfortable% as comfortable and '
            'past $debtShareStretched% as stretched, and uses those same two '
            'figures everywhere it says anything about debt.',
      ),
      InfoPoint(
        icon: Icons.label_outline,
        title: 'How an entry counts as debt',
        body:
            'By its category. Anything filed under a category or '
            'sub-category naming debt or a loan counts. If a repayment is '
            'filed somewhere else this number will read low.',
      ),
    ],
  ),

  InfoTopic.cashFlow: InfoContent(
    title: 'Cash flow',
    subtitle: 'The same money, sorted by what it was for',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.restaurant_outlined,
        title: 'Day to day (operating)',
        body:
            'Everyday living. Your salary coming in, your food, transport, '
            'bills and shopping going out. For most people this is the whole '
            'report.',
      ),
      InfoPoint(
        icon: Icons.trending_up,
        title: 'Investments (investing)',
        body:
            'Money put into things meant to grow, and anything they pay back. '
            'MP2 top-ups, dividends, interest.',
      ),
      InfoPoint(
        icon: Icons.account_balance_outlined,
        title: 'Loans and cards (financing)',
        body:
            'Loan and card repayments. Money borrowed would appear on the in '
            'side, and nothing in the app records taking a loan out yet, so '
            'that side reads zero.',
      ),
      InfoPoint(
        icon: Icons.calculate_outlined,
        title: 'Why sort it at all',
        body:
            'Spending 20,000 on groceries and putting 20,000 into savings '
            'both leave your wallet, and they are not the same event. The '
            'three sections keep them apart.',
      ),
      // The teaching half of the line that now appears on the headline card
      // when operating is positive and the total is not. The FIGURE stays on
      // the screen because a red headline over a good month misleads; this is
      // the part somebody learns once and then never needs again.
      InfoPoint(
        icon: Icons.remove_circle_outline,
        title: 'Cash going down is often progress',
        body:
            'Money leaving for MP2 and money leaving to kill a loan both show '
            'as out, so a month where you did both can show your cash going '
            'down. '
            'That is not the same as overspending. Read the day to day section '
            'first: that is the one that says whether day to day life paid '
            'for itself.',
      ),
    ],
    formula: 'Change in cash = day to day + investments + loans and cards',
  ),

  InfoTopic.transfers: InfoContent(
    title: 'Your own transfers',
    subtitle: 'Counted, shown, and deliberately not in the total',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.swap_horiz,
        title: 'Moving is not spending',
        body:
            'Sending 5,000 from your bank to GCash leaves one pocket and '
            'enters another. You are no richer and no poorer, so it changes '
            'no total on this screen.',
      ),
      InfoPoint(
        icon: Icons.visibility_outlined,
        title: 'Why show it anyway',
        body:
            'Because you moved real money and the report going quiet about it '
            'reads like the app lost it. The count and the amount are here so '
            'you can see it was noticed.',
      ),
    ],
  ),

  InfoTopic.reconciliation: InfoContent(
    title: 'Reconciliation',
    subtitle: 'Not built yet, and here is what it will do',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.rule,
        title: 'Checking the app against reality',
        body:
            'You open your banking app, read the real balance, and tell '
            'Salapify what it is. If the two differ, something was missed or '
            'double counted.',
      ),
      InfoPoint(
        icon: Icons.edit_note_outlined,
        title: 'Recording the difference',
        body:
            'It writes an adjustment entry for the gap, so the correction is '
            'visible in your Activity rather than a balance quietly changing '
            'behind your back.',
      ),
      InfoPoint(
        icon: Icons.science_outlined,
        title: 'Why it is a separate step',
        body:
            'It is the only part of Reports that CHANGES your data. Anything '
            'that writes needs testing that follows the money all the way to '
            'every screen that should mention it, so it is being built on its '
            'own rather than rushed in beside three read-only tabs.',
      ),
    ],
  ),

  InfoTopic.reportScope: InfoContent(
    title: 'What is being counted',
    subtitle: 'Which entries these figures were built from',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.filter_alt_outlined,
        title: 'The period you picked',
        body:
            'Only entries dated inside it. Position is the exception and '
            'always shows now.',
      ),
      InfoPoint(
        icon: Icons.people_outline,
        title: 'The entity you are viewing',
        body:
            'Personal, household, business or side hustle. An entry with no '
            'entity set counts as personal. An ACCOUNT with no entity set '
            'shows under all of them, because an unsorted wallet should not '
            'vanish from a report.',
      ),
      InfoPoint(
        icon: Icons.block,
        title: 'Never excluded or duplicate entries',
        body: 'Those stay visible in Activity and out of every total here.',
      ),
    ],
  ),

  InfoTopic.debtBothWays: InfoContent(
    title: 'Debt, both ways',
    subtitle: 'What you owe and what is owed to you',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.south_west,
        title: 'What you owe',
        body:
            'Credit cards, personal and gadget loans, instalment plans, and '
            'money borrowed from family or friends.',
      ),
      InfoPoint(
        icon: Icons.north_east,
        title: 'What is owed to you',
        body:
            'Money you lent, a split bill nobody has settled, groceries you '
            'paid for. Most apps ignore this half entirely, which quietly '
            'understates what you actually have.',
      ),
      InfoPoint(
        icon: Icons.balance,
        title: 'The beam',
        body:
            'The bar weighs the two against each other, so one glance says '
            'which way you are leaning rather than making you do the '
            'subtraction.',
      ),
      InfoPoint(
        icon: Icons.inventory_2_outlined,
        title: 'Taking a debt off the list',
        body:
            'A debt with nothing paid against it can be deleted outright, '
            'and that cannot be undone. Once money has been recorded against '
            'it there is no delete, because the payments stay in your '
            'Activity and deleting the debt would leave them explaining '
            'nothing. Mark it settled instead and you can archive it, which '
            'is reversible and changes no total. Archived debts sit at the '
            'bottom of this screen with a "Put it back".',
      ),
      InfoPoint(
        icon: Icons.event_repeat_outlined,
        title: 'And the same for a payment plan',
        body:
            'A plan you have never paid into can be deleted, which also '
            'stops Salapify holding its monthly amount back from Safe to '
            'Spend. A plan you have paid off can be archived, which changes '
            'no figure. For one in between, take its payments back first and '
            'then delete it.',
      ),
    ],
  ),

  InfoTopic.comingUp: InfoContent(
    title: 'Coming up',
    subtitle: 'Money that is already spoken for',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.event_outlined,
        title: 'Bills and payments due',
        body:
            'Anything with a date attached that has not been paid yet, '
            'nearest first.',
      ),
      InfoPoint(
        icon: Icons.shield_outlined,
        title: 'Held back from Safe to Spend',
        body:
            'These amounts are subtracted before Safe to Spend is worked out, '
            'so the figure you are given to spend is money that is genuinely '
            'free.',
      ),
    ],
  ),

  InfoTopic.budgets: InfoContent(
    title: 'Budgets',
    subtitle: 'A limit per category, reset every month',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.calendar_month_outlined,
        title: 'This month only',
        body:
            'Spending resets on the 1st. A limit that never resets is not a '
            'limit, it is a running total that creeps past every cap.',
      ),
      InfoPoint(
        icon: Icons.block,
        title: 'Excluded entries do not count',
        body:
            'An entry you marked excluded or duplicate stays visible in '
            'Activity and out of your budget. A charge you have already said '
            'is not yours should not eat your limit.',
      ),
      InfoPoint(
        icon: Icons.label_outline,
        title: 'Matched by category',
        body:
            'An expense counts against the budget whose category it carries. '
            'Something filed under the wrong category lands in the wrong '
            'budget, which is the usual reason a figure looks surprising.',
      ),
      InfoPoint(
        icon: Icons.warning_amber_outlined,
        title: 'Watch closely, and over',
        body:
            'A budget past 80 percent is one to watch. Past 100 it is marked '
            'over, outlined rather than just coloured, and the row tells you '
            'by how much.',
      ),
    ],
    formula: 'Left = limit - what you spent this month',
  ),

  InfoTopic.bills: InfoContent(
    title: 'Bills and payables',
    subtitle: 'Money already promised to somebody',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.north_east,
        title: 'Going out, and coming in, kept apart',
        body:
            'Payday sits in this list too, and it is NOT a bill. Adding them '
            'together makes a reassuring number that means nothing, so the '
            'two are shown separately.',
      ),
      InfoPoint(
        icon: Icons.shield_outlined,
        title: 'Held back from Safe to Spend',
        body:
            'These amounts are subtracted before Safe to Spend is worked out. '
            'That is the whole point of listing them: the money is spoken for '
            'even though it is still in your account.',
      ),
    ],
  ),

  InfoTopic.decisions: InfoContent(
    title: 'Before you spend',
    subtitle: 'The check worth doing on a big purchase',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.savings_outlined,
        title: 'Safe to spend',
        body:
            'What is left after every bill, minimum payment and buffer is set '
            'aside. Spending this does not break anything you have already '
            'committed to.',
      ),
      InfoPoint(
        icon: Icons.south_west,
        title: 'Income streams',
        body:
            'What you expect to come in before the next payday. The app '
            'counts on these arriving, so an optimistic one makes Safe to '
            'Spend optimistic too.',
      ),
    ],
  ),

  InfoTopic.trackers: InfoContent(
    title: 'Trackers',
    subtitle: 'Habits, and what quietly recurs',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.local_fire_department_outlined,
        title: 'Habits',
        body:
            'Logging every day is what makes every other number here true. '
            'The streak is there because it works, not because it is a game.',
      ),
      InfoPoint(
        icon: Icons.autorenew,
        title: 'Subscriptions, per month',
        body:
            'An annual plan is divided by twelve so it can be compared with a '
            'monthly one. Adding a yearly fee straight into a monthly total '
            'overstates it twelvefold.',
      ),
      InfoPoint(
        icon: Icons.warning_amber_outlined,
        title: 'The flags',
        body:
            'Unused, duplicate and trial-ending are recorded rather than '
            'guessed. Detecting "unused" properly needs usage the app does '
            'not have, and a guess dressed as a fact is worse than nothing.',
      ),
    ],
  ),

  InfoTopic.academy: InfoContent(
    title: 'The startup guides',
    subtitle: 'What is still to come here',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.storefront_outlined,
        title: 'Registering a business here',
        body:
            'DTI or SEC, barangay and mayor permits, BIR registration, and '
            'what each actually costs and takes.',
      ),
      InfoPoint(
        icon: Icons.cloud_outlined,
        title: 'Selling software and digital products',
        body: 'App store rules, billing, and how income from abroad is taxed.',
      ),
      InfoPoint(
        icon: Icons.schedule,
        title: 'Why they are not here yet',
        body:
            'Together they are about three thousand lines of written guidance '
            'and they deserve a proper pass rather than being rushed in '
            'beside everything else on this tab.',
      ),
    ],
  ),
  InfoTopic.businessChecklist: InfoContent(
    title: 'This checklist',
    subtitle: 'Where it came from and what it is not',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.checklist,
        title: 'Your ticks are saved on this phone',
        body:
            'They survive closing the app and they travel in your backup, so '
            'a phone you restore onto picks up where you left off. Nothing '
            'leaves the device.',
      ),
      InfoPoint(
        icon: Icons.sort,
        title: 'The order is roughly the order you do them',
        body:
            'Several steps will not accept you without the paper from an '
            'earlier one, which is why filtering narrows the list instead of '
            'rearranging it.',
      ),
      InfoPoint(
        icon: Icons.gavel_outlined,
        title: 'It is a map, not advice',
        body:
            'Requirements differ by city, by industry and over time, and fees '
            'change. Treat this as what to ask about, then confirm with the '
            'agency or an accountant before you file anything.',
      ),
    ],
  ),
  InfoTopic.reminders: InfoContent(
    title: 'How reminders work',
    subtitle: 'What raises one, and what it can and cannot do',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.phone_iphone,
        title: 'Salapify does not buzz your phone',
        body:
            'A real notification needs permission from Android and a rebuilt '
            'app, so for now a reminder is worked out and shown when you '
            'open Salapify. Nothing runs in the background and nothing is '
            'watching you between visits.',
      ),
      InfoPoint(
        icon: Icons.rule,
        title: 'Four rules, and you own all of them',
        body:
            'A nudge if nothing is logged by an evening hour you pick, and a '
            'warning ahead of a payment you owe, a bill, and a subscription '
            'renewal. Switch any of them off and it goes quiet for good.',
      ),
      InfoPoint(
        icon: Icons.repeat_one,
        title: 'The same thing is only said once a day',
        body:
            'Opening the app five times in an evening does not produce five '
            'copies. It can say it again tomorrow, which is the point.',
      ),
      InfoPoint(
        icon: Icons.warning_amber_outlined,
        title: 'Something late keeps being mentioned',
        body:
            // "The prototype went silent the day after a due date" was
            // here, in an explainer a user opens. The prototype is a
            // development artefact nobody outside this repository has heard
            // of, and a reader learns nothing from being told what some
            // other program did. The BEHAVIOUR it was contrasting with is
            // worth keeping, so it is stated as what Salapify does.
            'A bill you missed goes on reminding you and says how late it '
            'is, until it is paid or removed. Being overdue is the moment a '
            'reminder matters most, so that is not when it stops.',
      ),
      InfoPoint(
        icon: Icons.delete_outline,
        title: 'Removing a message is not paying it',
        body:
            'Clear one and it can come back, because the bill underneath it '
            'is still there. Nothing here changes your money.',
      ),
    ],
  ),
  InfoTopic.addOnRate: InfoContent(
    title: 'Why the real rate is higher than the one quoted',
    subtitle: 'Add-on interest, and what it costs on the money you still owe',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.price_change_outlined,
        title: 'Add-on interest is charged on the WHOLE amount, all the way',
        body:
            'Most instalment plans here quote an add-on rate. The interest is '
            'worked out once, on everything you borrowed, and spread over '
            'every month. So in the last month you are still paying interest '
            'calculated on the full original amount, even though almost all '
            'of it has been paid back.',
      ),
      InfoPoint(
        icon: Icons.calculate_outlined,
        title: 'A bank loan usually works the other way',
        body:
            'On a diminishing balance loan the interest each month is worked '
            'out on what is actually left. The same quoted rate therefore '
            'costs far less. Borrowing 24,500 for twelve months at a real 1.5 '
            'percent a month costs about 2,454 in interest; the same amount '
            'on a 1.5 percent add-on plan costs 4,410.',
      ),
      InfoPoint(
        icon: Icons.balance,
        title: 'What the second line on the card is',
        body:
            'Salapify works backwards from the payments themselves: the rate '
            'at which the money you hand over is worth exactly what you '
            'borrowed. It is the same arithmetic however the rate was '
            'described, which is why it can be compared between plans.',
      ),
      InfoPoint(
        icon: Icons.info_outline,
        title: 'The quoted rate is not wrong, and nobody is hiding it',
        body:
            'It is a normal way to price an instalment plan and it is printed '
            'openly. Both figures are shown because they answer different '
            'questions: what the plan is called, and what it costs you. The '
            'yearly figures here are the monthly ones times twelve, for both, '
            'so the comparison is about the rate and not about the method.',
      ),
    ],
  ),
  InfoTopic.cardCycle: InfoContent(
    title: 'The two dates on a credit card',
    subtitle: 'What closes the bill, and what pays it',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.event_busy,
        title: 'The closing day is not the payment day',
        body:
            'Your bank closes the month on one day and works out what you '
            'owe. That total is then payable on a different day, usually two '
            'or three weeks later. Most people only ever learn the second '
            'one, which is why the first one is on the card now.',
      ),
      InfoPoint(
        icon: Icons.schedule,
        title: 'Which bill today lands on',
        body:
            'Anything you spend before the closing day goes on the bill about '
            'to be handed to you. Anything after it waits for next month, so '
            'you get longer before you have to pay for it. Nothing here is '
            'free money, it is only later money.',
      ),
      InfoPoint(
        icon: Icons.verified_outlined,
        title: 'Paying the FULL amount is the part that matters',
        body:
            'Pay everything the statement says by the due date and the card '
            'costs you nothing. Pay the minimum and you are on time and still '
            'charged interest, on the whole balance, not just the bit you '
            'left. That is the most expensive misunderstanding a card holder '
            'can have.',
      ),
      InfoPoint(
        icon: Icons.edit_calendar_outlined,
        title: 'These are the dates YOU typed',
        body:
            'Salapify has no connection to your bank. Both dates come from '
            'the account you set up, so if a count looks wrong, edit the '
            'account and check them against your statement.',
      ),
    ],
  ),
  InfoTopic.claimableExpenses: InfoContent(
    title: 'Claimable expenses',
    subtitle: 'What Salapify counts, and what the BIR would',
    points: <InfoPoint>[
      // CORRECTED 2026-10-07, after a tax professional review and a check of
      // the code. The first point told people to "tick it as tax deductible
      // when you logged it", and the Log sheet has no such control: the flag
      // is set only by the scan receipt sheet's switch and by OCR. The routes
      // below are the three `isClaimable` in bir_claims.dart actually
      // accepts.
      InfoPoint(
        icon: Icons.check_box_outlined,
        title: 'Three ways an expense lands here',
        body:
            'You filed it under Business & Freelance Ops, or you tagged it '
            'tax-deductible, or you switched on Claimable business expense '
            'when you scanned its receipt. A receipt carrying a TIN or the '
            'words of an official BIR document switches that on for you, and '
            'you can switch it off before you save.',
      ),
      // "AN INVOICE", first. The Ease of Paying Taxes Act (RA 11976,
      // effective 22 January 2024) and RR 7-2024 made the invoice the primary
      // document for goods and services; the official receipt is now only
      // supplementary.
      InfoPoint(
        icon: Icons.receipt_long,
        title: 'A tick is not a receipt',
        body:
            'The BIR can disallow a deduction with no adequate record behind '
            'it, which in practice means the invoice (or official receipt) '
            'with the supplier TIN on it. This card counts an entry as backed '
            'up once it has a photo or a typed reference, but a typed number '
            'is not the document, so keep the paper or a scan of it.',
      ),
      InfoPoint(
        icon: Icons.calculate_outlined,
        title: 'Whether it saves you anything depends on how you file',
        body:
            'Only business or professional income, filed on graduated rates '
            'with itemised deductions, turns a receipt into lower income '
            'tax. On the 8% election there are no deductions at all. On the '
            '40% standard deduction the amount is fixed whatever you spent. '
            'An employee with only a salary has no itemised deductions, so '
            'these receipts change nothing for them.',
      ),
      // THE CEILING, explained. The card says "up to" because the figure is
      // the receipts times ONE rate, exact only while taxable income stays in
      // the chosen band after the deduction.
      InfoPoint(
        icon: Icons.trending_down,
        title: 'Why the saving says "up to"',
        body:
            'It is your backed up receipts multiplied by your band\'s rate. '
            'That is exact while your income stays in that band. If the '
            'deduction drops you into a lower band, part of it is taxed at '
            'the lower rate, so you save less. Itemising also only beats the '
            '40% standard deduction once your expenses are more than 40% of '
            'your gross.',
      ),
      // Moved here from the card, where the tax review ruled it safe to move:
      // "take nothing off" beside 0.00 cannot mislead, so this teaches rather
      // than prevents a wrong belief. "Taxable" and "a year" added, because
      // the band is annual taxable income and the card is usually a month.
      InfoPoint(
        icon: Icons.money_off_outlined,
        title: 'The 0% band',
        body:
            'Taxable income up to ₱250,000 a year pays no income tax, so a '
            'deduction saves nothing. The records are still worth keeping, in '
            'case your income rises or you are asked for them.',
      ),
      InfoPoint(
        icon: Icons.info_outline,
        title: 'Salapify does not file anything',
        body:
            'Nothing here is sent anywhere and none of it is a tax return. '
            'It is your own records, sorted so you can find them, and these '
            'figures are estimates on the 2023 rates, not tax advice. Ask a '
            'tax adviser what is claimable for you.',
      ),
    ],
  ),
  InfoTopic.bonusSplit: InfoContent(
    title: 'Your 13th month',
    subtitle: 'What is taxed, and a way to divide the rest',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.card_giftcard,
        title: 'The first ₱90,000 of benefits is tax free',
        body:
            'Under the TRAIN law your 13th month pay and other benefits are '
            'exempt from income tax up to ₱90,000. Only what goes over that '
            'is taxed, and only the excess, not the whole amount.',
      ),
      InfoPoint(
        icon: Icons.calendar_today_outlined,
        title: 'That ₱90,000 is for the whole YEAR',
        body:
            'It covers your 13th month and any other benefits added '
            'together, not each payment separately. A performance bonus in '
            'June has already used part of it, so the room left in December '
            'may be smaller than it looks.',
      ),
      InfoPoint(
        icon: Icons.percent,
        title: 'The tax shown here is rough',
        body:
            'Salapify uses 20% on the excess. What is actually withheld '
            'depends on the band the excess lands in, so treat the figure as '
            'close rather than exact, and check your payslip.',
      ),
      InfoPoint(
        icon: Icons.pie_chart_outline,
        title: 'Half, a third, and the rest',
        body:
            'Fifty percent to a cushion, thirty to whatever debt costs you '
            'most, twenty to Christmas. The last share is not an indulgence: '
            'a plan with nothing in it for Pamasko is the plan people give '
            'up on in the first week of December, and then the whole bonus '
            'goes.',
      ),
      InfoPoint(
        icon: Icons.pan_tool_outlined,
        title: 'Salapify does not tell you where to put it',
        body:
            'Each share says what the money is for and stops there. Which '
            'bank, fund or app you use is your decision, and an app that '
            'named one would be recommending a product rather than helping '
            'you plan.',
      ),
    ],
  ),
  InfoTopic.runway: InfoContent(
    title: 'Runway',
    subtitle: 'What your balance does between now and 45 days from now',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.calendar_today_outlined,
        title: 'It is a calendar, not a budget',
        body:
            'Safe to Spend answers how much you may spend. This answers which '
            'DAY gets tight. Same money, two questions, and they are worked '
            'out by two different engines on purpose so neither can quietly '
            'correct the other.',
      ),
      InfoPoint(
        icon: Icons.event_outlined,
        title: 'Only dates Salapify can read',
        body:
            'Due dates in Salapify are free text. "15", "Sep 25" and '
            '"2026-10-15" are all read. Anything else is counted in the '
            'not-counted line rather than dropped, because a clean projection '
            'that quietly left a bill out is worse than one that admits it.',
      ),
      InfoPoint(
        icon: Icons.history_toggle_off_outlined,
        title: 'Money already late is not on the calendar',
        body:
            'This card looks forward, so a bill whose due date has passed has '
            'no day left to sit on. It is not forgotten and it is not paid: '
            'it moves to the not-counted line, with its amount, so you can '
            'see that your real position is tighter than the day-by-day '
            'figure above. Give it a new due date and it rejoins the '
            'calendar.',
      ),
      InfoPoint(
        icon: Icons.account_balance_outlined,
        title: 'Bills wait for a banking day',
        body:
            'A payment due on a Sunday or a holiday leaves on the next '
            'banking day, because that is when the bank actually moves it. '
            'Salary is not shifted. Money credited on a Saturday is there on '
            'Saturday.',
      ),
      InfoPoint(
        icon: Icons.savings_outlined,
        title: 'It starts from spendable cash',
        body:
            'Money on an account you ticked "Set aside" is not counted here, '
            'the same way Safe to Spend does not count it. It is still yours '
            'and you can still pay from it.',
      ),
      InfoPoint(
        icon: Icons.payments_outlined,
        title: 'It never invents income',
        body:
            'If you have not told Salapify your payday days, only the one '
            'payday it already knows about appears, so the line reads tighter '
            'than your real life. Set your payday days and the window fills '
            'in properly. And a salary that sits in Coming Up AND in your '
            'payday rule is counted once, not twice.',
      ),
      InfoPoint(
        icon: Icons.content_copy_outlined,
        title: 'A bill in two places is counted twice, on purpose',
        body:
            'If the same payment is written down as a Bill and again as a '
            'Debt, Salapify takes it out twice and tells you so. It does not '
            'guess which one you meant. Counting a bill twice only makes the '
            'line look tighter than your life really is, and that is the '
            'safe direction to be wrong in. A salary counted twice would '
            'hand you money that is not coming, which is why that one is '
            'counted once instead.',
      ),
      InfoPoint(
        icon: Icons.visibility_off_outlined,
        title: '45 days is where it stops',
        body:
            'Anything dated after that is counted separately and is not in '
            'the figure. It is a cap on how far ahead the app will guess, not '
            'a claim about what happens next.',
      ),
    ],
  ),
  InfoTopic.openingBalance: InfoContent(
    title: 'The balance you start from',
    subtitle: 'Why Salapify asks for a figure it cannot check',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.flag_outlined,
        title: 'It is a starting line, not a claim',
        body:
            'Salapify has no connection to your bank and never will, so it '
            'cannot look this up. Whatever you type is taken as true and '
            'everything after it is counted from there. Type what the app or '
            'the passbook shows you right now, to the centavo if you can.',
      ),
      InfoPoint(
        icon: Icons.rule,
        title: 'You have just done a reconciliation',
        body:
            'Comparing what a record says against what the bank actually '
            'shows, and closing the gap, is the oldest control in '
            'bookkeeping. Salapify runs it again whenever you want under '
            'Reports, Check, and it is the thing this app does that most '
            'trackers skip. Today it is one number, because there is nothing '
            'yet to disagree with it.',
      ),
      InfoPoint(
        icon: Icons.edit_outlined,
        title: 'Getting it wrong costs you nothing',
        body:
            'You can correct the balance from the Accounts screen, and you '
            'can reconcile any time to bring it back in line. Nothing is '
            'locked by what you type here.',
      ),
    ],
  ),

  // The card under "In and out" on Performance. Its title used to be
  // "Spending pace", which the founder flagged on 2026-10-07 as a word users
  // would not understand; the title now says what the chart compares and the
  // reading lesson lives here.
  InfoTopic.thisMonthVsLast: InfoContent(
    title: 'This month vs last month',
    subtitle: 'Are you spending faster or slower than last month?',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.show_chart,
        title: 'The solid line is this month',
        body:
            'It adds up what you have spent, day by day, from the 1st to '
            'today. The dot is today.',
      ),
      InfoPoint(
        icon: Icons.more_horiz,
        title: 'The dotted line is last month',
        body:
            'All of it, so you can see both where last month stood on this '
            'same day and where it ended up.',
      ),
      InfoPoint(
        icon: Icons.compare_arrows,
        title: 'The sentence on top compares the same day',
        body:
            'Day 18 of this month against day 18 of last month. Both months '
            'have the same paydays, so it is a fair comparison while there is '
            'still time to slow down.',
      ),
      InfoPoint(
        icon: Icons.touch_app_outlined,
        title: 'Tap or drag to read any day',
        body:
            'The figures under the chart follow your finger and stay there '
            'when you let go.',
      ),
      InfoPoint(
        icon: Icons.event_outlined,
        title: 'Entries dated later are not on the line yet',
        body:
            'Rent logged in advance for the 30th counts in Money out, but the '
            'line only reaches today. When that happens the card says how '
            'much is waiting.',
      ),
    ],
  ),

  InfoTopic.monthByMonth: InfoContent(
    title: 'Month by month',
    subtitle: 'Your last six calendar months, side by side',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.bar_chart,
        title: 'Two bars per month',
        body:
            'Blue is money that came in, orange is money that went out. When '
            'orange is taller, that month cost more than it brought in.',
      ),
      InfoPoint(
        icon: Icons.touch_app_outlined,
        title: 'Tap a month to read it',
        body:
            'Its exact figures, and how much you kept or overspent, appear '
            'under the chart.',
      ),
      InfoPoint(
        icon: Icons.history,
        title: 'Why it opens on last month',
        body:
            'This month is already in the cards above and below, so the chart '
            'starts on the month you cannot see anywhere else.',
      ),
      InfoPoint(
        icon: Icons.calendar_month_outlined,
        title: 'Always calendar months',
        body:
            'The chips at the top change the cards, not this chart. A bonus or '
            '13th month pay shows up here as one tall blue bar, which is '
            'exactly what makes a normal month easy to spot.',
      ),
    ],
  ),

  InfoTopic.cashByMonth: InfoContent(
    title: 'Cash, month by month',
    subtitle: 'Did your cash grow or shrink each month?',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.bar_chart,
        title: 'Above the line, your cash grew',
        body:
            'A green bar above the middle line means that month left you with '
            'more cash than it started with. Orange below means less.',
      ),
      InfoPoint(
        icon: Icons.savings_outlined,
        title: 'Below the line is not always bad',
        body:
            'Money moved into MP2 or used to pay a loan down early also leaves '
            'your cash. Check the day to day section of that month before '
            'reading it as overspending.',
      ),
      InfoPoint(
        icon: Icons.touch_app_outlined,
        title: 'Tap a month to read it',
        body:
            'The exact amount appears under the chart. It opens on last month, '
            'because this month is the headline right above.',
      ),
      InfoPoint(
        icon: Icons.swap_horiz,
        title: 'Moving money between your own accounts does not count',
        body:
            'Bank to GCash is the same cash in a different pocket, so it never '
            'makes a bar taller.',
      ),
    ],
  ),

  InfoTopic.netWorthByMonth: InfoContent(
    title: 'Net worth, month by month',
    subtitle: 'What is really yours, and how it has moved',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.show_chart,
        title: 'One point a month',
        body:
            'Each point is what you owned less what you owed, as Salapify last '
            'saw it that month. This month\'s point is today\'s figure, the '
            'same as the headline above.',
      ),
      InfoPoint(
        icon: Icons.history,
        title: 'It starts when you start',
        body:
            'Salapify only began keeping these records with this update, so '
            'the line begins with your first month and grows by one point '
            'every month after. It never guesses the months before.',
      ),
      InfoPoint(
        icon: Icons.lock_clock_outlined,
        title: 'A past month stays as it was',
        body:
            'Fixing an old entry today does not redraw last month, the same '
            'way a bank statement already printed does not change.',
      ),
      // Founder decision, 2026-10-07: explain a clean-up jump here rather
      // than store the doubled amount on each record.
      InfoPoint(
        icon: Icons.content_copy_outlined,
        title: 'Fixing a "Counted twice" can look like a rise',
        body:
            'If a loan was recorded twice, the months before you fixed it '
            'include it twice. Removing the copy makes the line jump up by '
            'that amount. That jump is the clean-up, not new money.',
      ),
      InfoPoint(
        icon: Icons.science_outlined,
        title: 'Example data is never recorded',
        body:
            'While the example data is in the app, nothing is saved here, so '
            'your line starts with your own money.',
      ),
      InfoPoint(
        icon: Icons.groups_outlined,
        title: 'Your whole book only',
        body:
            'The records cover every profile together, so the chart shows '
            'when all entities are selected.',
      ),
    ],
  ),
};
