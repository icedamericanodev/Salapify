// The widget task handler runs whenever Android asks for a widget to be
// drawn or refreshed. It reads the same saved data the app uses (the
// salapify_data_v2 key in AsyncStorage), computes the numbers, and renders
// the matching widget. It runs headless, outside the app's React tree, so
// it must never assume the app is open.

import React from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { BudgetWidget, NetWorthWidget } from './SalapifyWidgets';

const STORAGE_KEY = 'salapify_data_v2';

async function readNumbers() {
  const out = { spent: 0, limit: 0, netWorth: 0 };
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    if (!raw) return out;
    const data = JSON.parse(raw);
    // This month prefix like "2026-07", built from local date parts.
    const now = new Date();
    const prefix = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    const list = Array.isArray(data.transactions) ? data.transactions : [];
    out.spent = list
      .filter((t) => t && t.type === 'expense' && String(t.date || '').slice(0, 7) === prefix)
      .reduce((t, e) => t + (Number(e.amount) || 0), 0);
    out.limit = Number(data.settings && data.settings.monthlyLimit) || 0;
    const sum = (arr, key) =>
      (Array.isArray(arr) ? arr : []).reduce((t, x) => t + (Number(x && x[key]) || 0), 0);
    out.netWorth =
      sum(data.accounts, 'balance') + sum(data.assets, 'value') - sum(data.debts, 'remaining');
  } catch (e) {
    // A widget must never crash the launcher; fall back to zeros.
  }
  return out;
}

export async function widgetTaskHandler(props) {
  const { widgetInfo, renderWidget } = props;
  const n = await readNumbers();
  switch (widgetInfo.widgetName) {
    case 'NetWorthWidget':
      renderWidget(<NetWorthWidget netWorth={n.netWorth} />);
      break;
    case 'BudgetWidget':
    default:
      renderWidget(<BudgetWidget spent={n.spent} limit={n.limit} />);
      break;
  }
}
