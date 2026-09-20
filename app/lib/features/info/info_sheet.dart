import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/type.dart';
import '../shared/sheet_scaffold.dart';

/// The explainer behind every circled "i", ported from the prototype's
/// src/components/SectionInfoModal.tsx.
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
  performance,
  ratios,
  runRate,
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
  claimableExpenses,
  bonusSplit,
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

  InfoTopic.ratios: InfoContent(
    title: 'The two ratios',
    subtitle: 'The quickest read on whether a month went well',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.percent,
        title: 'Savings rate',
        body:
            'The share of what came in that you did not spend. Twenty percent '
            'is a common target and is a guide, not a rule: a month with '
            'tuition or a hospital bill will be lower and that is the point of '
            'having savings.',
      ),
      InfoPoint(
        icon: Icons.account_balance_outlined,
        title: 'Debt servicing',
        body:
            'The share of your income going to loan and card repayments. '
            'Lenders here commonly want to see this under about a third '
            'before approving more, so it is worth watching before you apply '
            'rather than after.',
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

  InfoTopic.runRate: InfoContent(
    title: 'The month-end projection',
    subtitle: 'A direction, not a forecast',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.show_chart,
        title: 'How it is worked out',
        body:
            'Your total so far divided by the days elapsed, multiplied by the '
            'days in the month. A straight line, nothing cleverer.',
      ),
      InfoPoint(
        icon: Icons.warning_amber_outlined,
        title: 'Why to distrust it early',
        body:
            'On the 3rd of the month it is dividing by three days, so one '
            'large purchase makes it predict a catastrophe. It settles down '
            'as the month fills in.',
      ),
      InfoPoint(
        icon: Icons.event_outlined,
        title: 'It does not know your calendar',
        body:
            'Rent, tuition or an annual premium landing later in the month is '
            'invisible to it until it is logged.',
      ),
    ],
  ),

  InfoTopic.cashFlow: InfoContent(
    title: 'Cash flow',
    subtitle: 'The same money, sorted by what it was for',
    points: <InfoPoint>[
      InfoPoint(
        icon: Icons.restaurant_outlined,
        title: 'Operating',
        body:
            'Everyday living. Your salary coming in, your food, transport, '
            'bills and shopping going out. For most people this is the whole '
            'report.',
      ),
      InfoPoint(
        icon: Icons.trending_up,
        title: 'Investing',
        body:
            'Money put into things meant to grow, and anything they pay back. '
            'MP2 top-ups, dividends, interest.',
      ),
      InfoPoint(
        icon: Icons.account_balance_outlined,
        title: 'Financing',
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
    ],
    formula: 'Net change = operating + investing + financing',
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
            'A bill you missed goes on reminding you and says how late it is, '
            'until it is paid or removed. The prototype went silent the day '
            'after a due date, which is the moment it matters most.',
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
      InfoPoint(
        icon: Icons.check_box_outlined,
        title: 'Three ways an expense lands here',
        body:
            'You ticked it as tax deductible when you logged it, or you '
            'filed it under Business & Freelance Ops, or you tagged it. '
            'Scanning a receipt that carries a TIN ticks it for you, and you '
            'can always untick it.',
      ),
      InfoPoint(
        icon: Icons.receipt_long,
        title: 'A tick is not a receipt',
        body:
            'The BIR can disallow a deduction with no adequate record behind '
            'it, which in practice means the official receipt or sales '
            'invoice with the supplier TIN on it. That is why this card '
            'splits what you have marked from what you could actually show, '
            'and the second number is the one that matters.',
      ),
      InfoPoint(
        icon: Icons.calculate_outlined,
        title: 'Whether it saves you anything depends on how you file',
        body:
            'On the 8% election there are no itemised deductions at all, so '
            'these receipts change nothing. On the 40% standard deduction '
            'the amount is fixed whatever you spent. Only graduated rates '
            'with itemised deductions turn a receipt into a smaller tax '
            'bill, and how much depends on your income band.',
      ),
      InfoPoint(
        icon: Icons.info_outline,
        title: 'Salapify does not file anything',
        body:
            'Nothing here is sent anywhere and none of it is a tax return. '
            'It is your own records, sorted so you can find them, and it is '
            'general information rather than tax advice. Your accountant '
            'decides what is claimable.',
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
};
