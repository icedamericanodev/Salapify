// Ledger, Plan, Accounts and Debt.
//
// Every one of these is assembled from kit.dart and nothing else. If a screen
// here needs a shape the kit does not have, the kit grows once and all four
// get it; a screen never grows a private card of its own. That is what stops
// four screens becoming four design systems.
import 'package:flutter/material.dart';
import 'home.dart' show DebtBeam, Hero_;
import 'kit.dart';
import 'skin.dart';

// ---------------------------------------------------------------- ledger

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen(
      tab: 1,
      children: [
        const SizedBox(height: 8),
        const ScreenTitle(title: 'Ledger', action: 'Sep'),
        const SizedBox(height: 14),
        // The totals state the conclusion, so the list below does not have to
        // be added up by eye.
        Panel(
          pad: 16,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('In', style: ts(12.5, FontWeight.w400, skin.text3)),
                    const SizedBox(height: 4),
                    Text(
                      '₱42,000',
                      style: ts(19, FontWeight.w600, skin.good, ls: -0.4),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 34, color: skin.line),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Out', style: ts(12.5, FontWeight.w400, skin.text3)),
                    const SizedBox(height: 4),
                    Text(
                      '₱18,450',
                      style: ts(19, FontWeight.w600, skin.text, ls: -0.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Field(value: 'Search', hint: true, leading: Icons.search_rounded),
        const SizedBox(height: 12),
        const _ChipRow(
          labels: ['All', 'Spending', 'Income', 'Debt', 'Move'],
          on: 0,
        ),
        const SizedBox(height: 26),
        const _DayHead(day: 'Today, Sep 13', total: '₱430'),
        const SizedBox(height: 6),
        const Group(
          children: [
            Row_(
              icon: Icons.lunch_dining_outlined,
              title: 'Jollibee',
              sub: 'Food · GCash',
              amount: '₱250',
            ),
            Row_(
              icon: Icons.directions_bus_outlined,
              title: 'Grab',
              sub: 'Transport · Maya',
              amount: '₱180',
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _DayHead(day: 'Friday, Sep 12', total: '+₱78'),
        const SizedBox(height: 6),
        const Group(
          children: [
            Row_(
              icon: Icons.south_west_rounded,
              title: 'Kuya Jun paid back',
              sub: 'Debt · Cash',
              amount: '+₱1,000',
              tone: Tone.good,
            ),
            Row_(
              icon: Icons.local_cafe_outlined,
              title: 'Kopiko Blanca',
              sub: 'Food · Cash',
              amount: '₱75',
            ),
            Row_(
              icon: Icons.shopping_bag_outlined,
              title: 'Puregold',
              sub: 'Groceries · BPI',
              amount: '₱847',
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _DayHead(day: 'Thursday, Sep 11', total: '₱2,899'),
        const SizedBox(height: 6),
        const Group(
          children: [
            Row_(
              icon: Icons.local_gas_station_outlined,
              title: 'Shell Katipunan',
              sub: 'Transport · GCash',
              amount: '₱1,200',
            ),
            Row_(
              icon: Icons.wifi_outlined,
              title: 'Converge',
              sub: 'Bills · Maya',
              amount: '₱1,699',
            ),
            // A transfer is not a spend. It moves two balances and leaves one
            // record, so it must never read like money leaving.
            Row_(
              icon: Icons.swap_horiz_rounded,
              title: 'GCash to BPI',
              sub: 'Move · not a spend',
              amount: '₱5,000',
            ),
          ],
        ),
      ],
    );
  }
}

class _DayHead extends StatelessWidget {
  const _DayHead({required this.day, required this.total});
  final String day, total;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(day, style: ts(13.5, FontWeight.w600, skin.text2)),
      Text(total, style: ts(13.5, FontWeight.w500, skin.text3)),
    ],
  );
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.labels, required this.on});
  final List<String> labels;
  final int on;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: ListView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Chip_(label: labels[i], on: i == on),
          if (i != labels.length - 1) const SizedBox(width: 8),
        ],
      ],
    ),
  );
}

// ---------------------------------------------------------------- plan

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen(
      tab: 2,
      children: [
        const SizedBox(height: 8),
        const ScreenTitle(title: 'Plan', action: '+ Recurring'),
        const SizedBox(height: 16),
        const Segmented(options: ['Budget', 'Upcoming', 'Goals'], index: 0),
        const SizedBox(height: 20),
        const Hero_(
          kicker: 'LEFT TO SPEND THIS CYCLE',
          whole: '9,180',
          cents: '.00',
          sentence: 'Two categories need a look before Monday.',
          rail: false,
        ),
        const SizedBox(height: 30),
        const Head(title: 'Where it goes', action: 'Edit'),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            children: [
              // The caption names the SPENT figure, because the bar fills
              // with spending while the big number on the right counts down
              // what is left. Without it, "₱1,250 left" over a bar that is
              // 79 percent full invites reading the fill as the money you
              // still have. That is the opposite of the truth.
              _Budget(
                label: 'Food',
                right: '₱1,250 left',
                fraction: 0.79,
                note: '₱4,750 spent of ₱6,000',
              ),
              _Budget(
                label: 'Transport',
                right: '₱420 left',
                fraction: 0.86,
                note: '₱2,580 spent of ₱3,000',
              ),
              _Budget(
                label: 'Groceries',
                right: '₱2,153 left',
                fraction: 0.46,
                note: '₱1,847 spent of ₱4,000',
              ),
              _Budget(
                label: 'Bills',
                right: 'set aside',
                fraction: 1.0,
                note: 'All ₱5,200 already put aside',
                good: true,
              ),
              _Budget(
                label: 'Shopping',
                right: 'over by ₱320',
                fraction: 1.0,
                note: '₱1,820 spent of ₱1,500',
                bad: true,
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        const Head(title: 'Spent so far'),
        const SizedBox(height: 12),
        const _MiniBars(),
      ],
    );
  }
}

class _Budget extends StatelessWidget {
  const _Budget({
    required this.label,
    required this.right,
    required this.fraction,
    required this.note,
    this.good = false,
    this.bad = false,
    this.last = false,
  });
  final String label, right, note;
  final double fraction;
  final bool good, bad, last;

  @override
  Widget build(BuildContext context) {
    final fill = bad
        ? skin.bad
        : good
        ? skin.good
        : skin.accent;
    final rightColor = bad
        ? skin.bad
        : good
        ? skin.good
        : skin.text;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: ts(15, FontWeight.w500, skin.text)),
              ),
              Text(right, style: ts(14, FontWeight.w600, rightColor)),
            ],
          ),
          const SizedBox(height: 8),
          ThinBar(fraction: fraction, fill: fill, height: 5),
          const SizedBox(height: 6),
          Text(note, style: ts(12, FontWeight.w400, skin.text3)),
        ],
      ),
    );
  }
}

/// A chart states its own conclusion in a sentence with a number, or it is
/// decoration. Drawn by hand rather than by a library, per D9.
class _MiniBars extends StatelessWidget {
  const _MiniBars();
  @override
  Widget build(BuildContext context) {
    const heights = [0.52, 0.71, 0.44, 0.83, 0.61, 0.68];
    const labels = ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 92,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < heights.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i == heights.length - 1 ? 0 : 10,
                      ),
                      child: FractionallySizedBox(
                        heightFactor: heights[i],
                        child: Container(
                          decoration: BoxDecoration(
                            // Only the current cycle is the accent. Colouring
                            // every bar would say nothing.
                            color: i == heights.length - 1
                                ? skin.accent
                                : skin.line,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == labels.length - 1 ? 0 : 10,
                    ),
                    child: Text(
                      labels[i],
                      style: ts(11.5, FontWeight.w400, skin.text3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'You are spending ₱1,240 less than your six month average.',
            style: ts(13.5, FontWeight.w400, skin.text2, h: 1.45),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- accounts

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen(
      tab: 3,
      children: [
        const SizedBox(height: 8),
        const ScreenTitle(title: 'Accounts', action: '+ Add'),
        const SizedBox(height: 16),
        const Hero_(
          kicker: 'NET WORTH',
          whole: '164,300',
          cents: '.00',
          sentence: 'Assets ₱176,300. Debts ₱12,000.',
          rail: false,
        ),
        const SizedBox(height: 30),
        const Head(title: 'Cash and e-wallets'),
        const SizedBox(height: 6),
        const Group(
          children: [
            Row_(
              icon: Icons.payments_outlined,
              title: 'Cash on hand',
              sub: 'Wallet',
              amount: '₱3,200',
            ),
            Row_(
              icon: Icons.account_balance_wallet_outlined,
              title: 'GCash',
              sub: 'E-wallet',
              amount: '₱8,410',
            ),
            Row_(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Maya',
              sub: 'E-wallet',
              amount: '₱1,975',
            ),
          ],
        ),
        const SizedBox(height: 26),
        const Head(title: 'Bank'),
        const SizedBox(height: 6),
        const Group(
          children: [
            Row_(
              icon: Icons.account_balance_outlined,
              title: 'BPI Savings',
              sub: 'Savings · 4821',
              amount: '₱96,715',
            ),
            Row_(
              icon: Icons.account_balance_outlined,
              title: 'BDO Payroll',
              sub: 'Payroll · 1190',
              amount: '₱66,000',
            ),
          ],
        ),
        const SizedBox(height: 26),
        const Head(title: 'Credit'),
        const SizedBox(height: 6),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: skin.discOnCard,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.credit_card_outlined,
                      size: 19,
                      color: skin.text2,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BPI Gold Mastercard',
                          style: ts(15, FontWeight.w500, skin.text),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Due Oct 3',
                          style: ts(12.5, FontWeight.w400, skin.text3),
                        ),
                      ],
                    ),
                  ),
                  // The accent, not the plain ink. This is money OWED, and
                  // the first render drew it in exactly the same colour as
                  // the ₱96,715 sitting in savings two sections up. On a
                  // screen whose hero is net worth, a liability that looks
                  // like an asset is the worst possible ambiguity. Accent
                  // means "you owe" everywhere else in the app, so it means
                  // that here.
                  Text(
                    '₱4,000',
                    style: ts(15.5, FontWeight.w600, skin.accent, ls: -0.3),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const ThinBar(fraction: 0.10),
              const SizedBox(height: 7),
              Text(
                '10 percent of a ₱40,000 limit used.',
                style: ts(12.5, FontWeight.w400, skin.text3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const Head(title: 'Debt', action: 'Open'),
        const SizedBox(height: 6),
        const Group(
          inset: 0,
          children: [
            Row_(title: 'You owe', amount: '₱12,000', tone: Tone.owe),
            Row_(title: 'Owed to you', amount: '₱3,500', tone: Tone.good),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- debt

class DebtScreen extends StatelessWidget {
  const DebtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen(
      tab: 3,
      children: [
        const SizedBox(height: 8),
        const ScreenTitle(
          title: 'Debt',
          action: '+ Add',
          sub: 'Both ways: what you owe, and what is owed to you.',
        ),
        const SizedBox(height: 18),
        const DebtBeam(footer: false),
        const SizedBox(height: 20),
        const Segmented(options: ['I owe', 'Owed to me'], index: 0),
        const SizedBox(height: 24),
        const Head(title: 'Open'),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            children: const [
              _Debt(
                name: 'Home Credit',
                note: '3 of 6 paid · next Sep 18',
                amount: '₱2,000',
                fraction: 0.5,
              ),
              // No bar. A statement balance has no "3 of 6" to be part way
              // through, and the first render drew an EMPTY bar here, which
              // says "zero progress on a plan" rather than "there is no plan".
              // Those are different facts about someone's money.
              _Debt(
                name: 'BPI Gold Mastercard',
                note: 'Statement due Oct 3',
                amount: '₱4,000',
                fraction: null,
              ),
              _Debt(
                name: 'Tita Nena',
                note: 'Pay when you can',
                amount: '₱6,000',
                fraction: null,
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const Head(title: 'Settled'),
        const SizedBox(height: 6),
        const Group(
          inset: 0,
          children: [
            Row_(
              title: 'Kuya Jun',
              sub: 'Settled Sep 3, all paid',
              amount: '₱0',
              tone: Tone.good,
              strike: true,
            ),
          ],
        ),
        const SizedBox(height: 26),
        const PillButton(label: 'Pay Home Credit, ₱2,000'),
        const SizedBox(height: 10),
        const PillButton(label: 'Record a payment', secondary: true),
      ],
    );
  }
}

class _Debt extends StatelessWidget {
  const _Debt({
    required this.name,
    required this.note,
    required this.amount,
    required this.fraction,
    this.last = false,
  });
  final String name, note, amount;

  /// Null means the debt has no schedule, so there is no progress to draw.
  /// Drawing an empty bar there would imply a plan that does not exist.
  final double? fraction;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name, style: ts(15, FontWeight.w500, skin.text)),
              ),
              Text(
                amount,
                style: ts(15.5, FontWeight.w600, skin.text, ls: -0.3),
              ),
            ],
          ),
          if (fraction != null) ...[
            const SizedBox(height: 8),
            ThinBar(fraction: fraction!),
          ],
          const SizedBox(height: 6),
          Text(note, style: ts(12.5, FontWeight.w400, skin.text3)),
        ],
      ),
    );
  }
}
