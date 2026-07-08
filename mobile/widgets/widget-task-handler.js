// The widget task handler runs whenever Android asks for a widget to be
// drawn or refreshed. It reads the same saved data the app uses (the
// salapify_data_v2 key in AsyncStorage), computes the numbers, and renders
// the matching widget. It runs headless, outside the app's React tree, so it
// must never assume the app is open, and it must never crash the launcher, so
// every path is guarded and falls back to safe zeros.

import React from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { nextPayday, daysUntilPayday } from '../lib/format';
import {
  BudgetWidget,
  NetWorthWidget,
  SpentMonthWidget,
  SweldoWidget,
  OwedToYouWidget,
  YouOweWidget,
  SavedMonthWidget,
  TopCategoryWidget,
  GoalWidget,
  StreakWidget,
} from './SalapifyWidgets';

const STORAGE_KEY = 'salapify_data_v2';
const DAY = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const isoLocal = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const num = (x) => Number(x) || 0;

// Everything the ten widgets could need, computed once from the blob.
async function readNumbers() {
  const out = {
    symbol: '₱',
    spent: 0, spentLast: 0, hasLast: false, limit: 0, income: 0, netWorth: 0,
    owed: 0, owedCount: 0, youOwe: 0, debtCount: 0,
    topName: '', topAmount: 0, topPct: 0,
    goalName: '', goalPct: 0, goalLeft: 0,
    totalLogged: 0, weekCount: 0, loggedToday: false,
    sweldoDays: null, sweldoLabel: '',
  };
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    if (!raw) return out;
    const data = JSON.parse(raw);
    const settings = (data && data.settings) || {};
    if (typeof settings.currency === 'string' && settings.currency) out.symbol = settings.currency;
    out.limit = num(settings.monthlyLimit);

    const now = new Date();
    const thisPrefix = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    const lm = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const lastPrefix = `${lm.getFullYear()}-${String(lm.getMonth() + 1).padStart(2, '0')}`;

    const txns = Array.isArray(data.transactions) ? data.transactions : [];
    const catNames = new Map((Array.isArray(data.categories) ? data.categories : []).map((c) => [c && c.id, c && c.name]));
    const cat = Object.create(null);
    const logDates = new Set();
    for (const t of txns) {
      if (!t) continue;
      const d = String(t.date || '');
      if (d) logDates.add(d.slice(0, 10));
      const mp = d.slice(0, 7);
      if (t.type === 'income' && mp === thisPrefix) out.income += num(t.amount);
      if (t.type === 'expense') {
        if (mp === thisPrefix) {
          out.spent += num(t.amount);
          const name = (t.categoryId && catNames.get(t.categoryId)) || (t.label || 'Other').trim() || 'Other';
          const key = name.toLowerCase();
          if (!cat[key]) cat[key] = { name, amount: 0 };
          cat[key].amount += num(t.amount);
        } else if (mp === lastPrefix) {
          out.spentLast += num(t.amount);
        }
        if (mp < thisPrefix) out.hasLast = true;
      }
    }

    // Top spending category this month.
    let top = null;
    for (const k in cat) if (!top || cat[k].amount > top.amount) top = cat[k];
    if (top && out.spent > 0) {
      out.topName = top.name;
      out.topAmount = top.amount;
      out.topPct = Math.round((top.amount / out.spent) * 100);
    }

    // Net worth: liquid accounts plus assets minus debts.
    const sum = (arr, key) => (Array.isArray(arr) ? arr : []).reduce((t, x) => t + num(x && x[key]), 0);
    out.netWorth = sum(data.accounts, 'balance') + sum(data.assets, 'value') - sum(data.debts, 'remaining');

    // You owe: outstanding debt across debts with a balance.
    const debts = Array.isArray(data.debts) ? data.debts : [];
    for (const d of debts) {
      const rem = num(d && d.remaining);
      if (rem > 0) { out.youOwe += rem; out.debtCount += 1; }
    }

    // Owed to you: receivables not paid, netted of partial payments.
    const recv = Array.isArray(data.receivables) ? data.receivables : [];
    for (const r of recv) {
      if (!r || r.paid) continue;
      const paidSoFar = (Array.isArray(r.payments) ? r.payments : []).reduce((t, p) => t + Math.max(0, num(p && p.amount)), 0);
      const bal = num(r.amount) - paidSoFar;
      if (bal > 0) { out.owed += bal; out.owedCount += 1; }
    }

    // Closest goal by percent complete.
    const goals = Array.isArray(data.goals) ? data.goals : [];
    let best = null;
    for (const g of goals) {
      const target = num(g && g.target);
      if (target <= 0) continue;
      const pct = Math.min(Math.round((num(g.saved) / target) * 100), 100);
      if (!best || pct > best.pct) best = { name: g.name || 'Goal', pct, left: Math.max(target - num(g.saved), 0) };
    }
    if (best) { out.goalName = best.name; out.goalPct = best.pct; out.goalLeft = best.left; }

    // Logging habit: a lifetime count of distinct days logged that never
    // resets, plus how many of the last 7 days have an entry. No consecutive
    // streak that a single miss can wipe, matching the app's recovery model.
    out.loggedToday = logDates.has(isoLocal(now));
    out.totalLogged = logDates.size;
    for (let i = 0; i < 7; i++) {
      const d = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      d.setDate(d.getDate() - i);
      if (logDates.has(isoLocal(d))) out.weekCount += 1;
    }

    // Next sweldo, only when a schedule is actually set.
    if (settings.paydaySchedule) {
      try {
        out.sweldoDays = daysUntilPayday(now, settings.paydaySchedule);
        const nd = nextPayday(now, settings.paydaySchedule);
        if (nd) out.sweldoLabel = `${DAY[nd.getDay()]}, ${MON[nd.getMonth()]} ${nd.getDate()}`;
      } catch (e) {
        out.sweldoDays = null;
      }
    }
  } catch (e) {
    // A widget must never crash the launcher; fall back to safe zeros.
  }
  return out;
}

export async function widgetTaskHandler(props) {
  const { widgetInfo, renderWidget } = props;
  const n = await readNumbers();
  switch (widgetInfo.widgetName) {
    case 'NetWorthWidget':
      renderWidget(<NetWorthWidget netWorth={n.netWorth} symbol={n.symbol} />);
      break;
    case 'SpentMonthWidget':
      renderWidget(<SpentMonthWidget spent={n.spent} spentLast={n.spentLast} hasLast={n.hasLast} symbol={n.symbol} />);
      break;
    case 'SweldoWidget':
      renderWidget(<SweldoWidget days={n.sweldoDays} dateLabel={n.sweldoLabel} />);
      break;
    case 'OwedToYouWidget':
      renderWidget(<OwedToYouWidget amount={n.owed} count={n.owedCount} symbol={n.symbol} />);
      break;
    case 'YouOweWidget':
      renderWidget(<YouOweWidget amount={n.youOwe} count={n.debtCount} symbol={n.symbol} />);
      break;
    case 'SavedMonthWidget':
      renderWidget(<SavedMonthWidget income={n.income} spent={n.spent} symbol={n.symbol} />);
      break;
    case 'TopCategoryWidget':
      renderWidget(<TopCategoryWidget name={n.topName} amount={n.topAmount} pct={n.topPct} symbol={n.symbol} />);
      break;
    case 'GoalWidget':
      renderWidget(<GoalWidget name={n.goalName} pct={n.goalPct} left={n.goalLeft} symbol={n.symbol} />);
      break;
    case 'StreakWidget':
      renderWidget(<StreakWidget totalLogged={n.totalLogged} weekCount={n.weekCount} loggedToday={n.loggedToday} />);
      break;
    case 'BudgetWidget':
    default:
      renderWidget(<BudgetWidget spent={n.spent} limit={n.limit} symbol={n.symbol} />);
      break;
  }
}
