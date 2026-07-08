// The Salapify Android home screen widgets, drawn with the widget library's
// own primitives (FlexWidget and TextWidget render to real Android widget
// views, not React Native views). Colors are hard coded to the Barako dark
// brand palette because widgets cannot read the app's theme context.
//
// Every widget is one compact card: a small orange kicker, a big number, and
// a plain sub line. The handler (widget-task-handler.js) computes the numbers
// from the saved blob and passes them in as props. Ten widgets total, so the
// user can pin whichever matters to them.

import React from 'react';
import { FlexWidget, TextWidget } from 'react-native-android-widget';

const BG = '#1A130E'; // dark-roast espresso base
const BORDER = '#3A2A20';
const ORANGE = '#FF8A3D'; // roasted orange, the brand accent
const TEXT = '#FBF3E9'; // steamed-milk cream
const MUTED = '#A99182';
const WARN = '#FF5D73'; // rose-crimson
const GOOD = '#7FD1A0'; // calm green for positive saved money

function money(n, symbol = '₱') {
  const v = Math.round(Number(n) || 0);
  const sign = v < 0 ? '-' : '';
  return sign + symbol + Math.abs(v).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

// The shared card shell. Keeps all ten widgets visually identical so a home
// screen full of them looks like one designed set.
function Card({ kicker, big, bigColor = TEXT, sub, bigSize = 22 }) {
  return (
    <FlexWidget
      clickAction="OPEN_APP"
      style={{
        width: 'match_parent',
        height: 'match_parent',
        backgroundColor: BG,
        borderRadius: 20,
        borderWidth: 1,
        borderColor: BORDER,
        padding: 14,
        flexDirection: 'column',
        justifyContent: 'center',
      }}
    >
      <TextWidget text={kicker} style={{ fontSize: 10, color: ORANGE, letterSpacing: 0.1 }} />
      <TextWidget text={big} style={{ fontSize: bigSize, fontWeight: 'bold', color: bigColor, marginTop: 4 }} />
      <TextWidget text={sub} style={{ fontSize: 11, color: MUTED, marginTop: 2 }} />
    </FlexWidget>
  );
}

// 1. How much of this month's budget is left to spend.
export function BudgetWidget({ spent = 0, limit = 0, symbol = '₱' }) {
  const left = limit - spent;
  const over = spent > limit && limit > 0;
  return (
    <Card
      kicker="SALAPIFY BUDGET"
      big={over ? money(-left, symbol) + ' over' : limit > 0 ? money(left, symbol) + ' left' : money(spent, symbol) + ' spent'}
      bigColor={over ? WARN : TEXT}
      sub={limit > 0 ? 'of ' + money(limit, symbol) + ' this month' : 'Set a monthly budget in the app'}
    />
  );
}

// 2. The net worth headline, always one tap from home.
export function NetWorthWidget({ netWorth = 0, symbol = '₱' }) {
  return (
    <Card
      kicker="NET WORTH"
      big={money(netWorth, symbol)}
      bigColor={netWorth >= 0 ? TEXT : WARN}
      sub="Tap to open Salapify"
    />
  );
}

// 3. Spending so far this month, against the same point last month.
export function SpentMonthWidget({ spent = 0, spentLast = 0, symbol = '₱', hasLast = false }) {
  const diff = spent - spentLast;
  let sub = 'First month of tracking';
  if (hasLast) {
    if (diff > 0) sub = 'Up ' + money(diff, symbol) + ' vs last month';
    else if (diff < 0) sub = 'Down ' + money(-diff, symbol) + ' vs last month';
    else sub = 'Same as last month';
  }
  return <Card kicker="SPENT THIS MONTH" big={money(spent, symbol)} sub={sub} />;
}

// 4. Days until the next payday, from the saved payday schedule.
export function SweldoWidget({ days = null, dateLabel = '' }) {
  let big = 'Set your sweldo';
  let sub = 'Add a payday schedule in More';
  if (days != null) {
    big = days <= 0 ? 'Sweldo today' : days === 1 ? '1 day' : days + ' days';
    sub = days <= 0 ? 'Payday has arrived' : dateLabel ? 'Next: ' + dateLabel : 'until your next sweldo';
  }
  return <Card kicker="NEXT SWELDO" big={big} bigColor={days === 0 ? ORANGE : TEXT} sub={sub} />;
}

// 5. Total money other people owe you, so you remember to follow up.
export function OwedToYouWidget({ amount = 0, count = 0, symbol = '₱' }) {
  return (
    <Card
      kicker="OWED TO YOU"
      big={money(amount, symbol)}
      bigColor={amount > 0 ? ORANGE : TEXT}
      sub={count > 0 ? 'from ' + count + (count === 1 ? ' person' : ' people') : 'No utang to collect'}
    />
  );
}

// 6. Total debt you still owe, across all your debts.
export function YouOweWidget({ amount = 0, count = 0, symbol = '₱' }) {
  return (
    <Card
      kicker="YOU OWE"
      big={money(amount, symbol)}
      bigColor={amount > 0 ? WARN : GOOD}
      sub={amount > 0 ? 'across ' + count + (count === 1 ? ' debt' : ' debts') : 'Debt free, nice'}
    />
  );
}

// 7. Money kept this month (income minus spending), and how much of income.
export function SavedMonthWidget({ income = 0, spent = 0, symbol = '₱' }) {
  const saved = income - spent;
  const rate = income > 0 ? Math.round((saved / income) * 100) : null;
  // A tight month is not a failure. Show the number honestly, but keep the
  // over-spend calm (no alarm red, no "short") so the widget never shames.
  return (
    <Card
      kicker="SAVED THIS MONTH"
      big={saved >= 0 ? money(saved, symbol) : money(-saved, symbol) + ' over'}
      bigColor={saved >= 0 ? GOOD : TEXT}
      sub={
        rate != null
          ? saved >= 0
            ? rate + '% of income kept'
            : 'A tight month. A fresh start tomorrow.'
          : 'Log income to see your rate'
      }
    />
  );
}

// 8. The biggest spending category this month, the lever to pull.
export function TopCategoryWidget({ name = '', amount = 0, pct = 0, symbol = '₱' }) {
  return (
    <Card
      kicker="TOP SPENDING"
      big={name ? name : 'Nothing yet'}
      sub={name ? money(amount, symbol) + ' . ' + pct + '% of spend' : 'Log an expense to see this'}
      bigSize={20}
    />
  );
}

// 9. The savings goal closest to done, with what is left.
export function GoalWidget({ name = '', pct = 0, left = 0, symbol = '₱' }) {
  return (
    <Card
      kicker="CLOSEST GOAL"
      big={name ? name + ' ' + pct + '%' : 'No goals yet'}
      bigColor={pct >= 100 ? GOOD : TEXT}
      sub={name ? (pct >= 100 ? 'Funded, treat yourself' : money(left, symbol) + ' to go') : 'Add a goal in the app'}
      bigSize={20}
    />
  );
}

// 10. The logging habit. A lifetime days-logged total that never resets, plus
// the rolling last-7 count, so a missed day never wipes progress or shames.
export function StreakWidget({ totalLogged = 0, weekCount = 0, loggedToday = false }) {
  return (
    <Card
      kicker="DAYS LOGGED"
      big={totalLogged > 0 ? totalLogged + (totalLogged === 1 ? ' day' : ' days') : 'Start today'}
      bigColor={totalLogged > 0 ? ORANGE : TEXT}
      sub={
        totalLogged <= 0
          ? 'Log once to begin your chain'
          : loggedToday
          ? `Logged today. ${weekCount} of the last 7.`
          : `${weekCount} of the last 7 days. A miss changes nothing.`
      }
    />
  );
}
