// The two Android home screen widgets, drawn with the widget library's own
// primitives (FlexWidget and TextWidget render to real Android widget
// views, not React Native views). Colors are hard coded to the dark brand
// palette because widgets cannot read the app's theme context.

import React from 'react';
import { FlexWidget, TextWidget } from 'react-native-android-widget';

const BG = '#101E15';
const BORDER = '#33503D';
const MINT = '#FFA45C';
const TEXT = '#FBF7EF';
const MUTED = '#9DAF9D';
const WARN = '#E8785A';

function money(n, symbol = '₱') {
  const v = Math.round(Number(n) || 0);
  const sign = v < 0 ? '-' : '';
  return sign + symbol + Math.abs(v).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

// Budget widget: how much of this month's limit is left to spend.
export function BudgetWidget({ spent = 0, limit = 0, symbol = '₱' }) {
  const left = limit - spent;
  const over = spent > limit && limit > 0;
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
      <TextWidget
        text="SALAPIFY BUDGET"
        style={{ fontSize: 10, color: MINT, letterSpacing: 0.1 }}
      />
      <TextWidget
        text={over ? money(-left, symbol) + ' over' : limit > 0 ? money(left, symbol) + ' left' : money(spent, symbol) + ' spent'}
        style={{ fontSize: 24, fontWeight: 'bold', color: over ? WARN : TEXT, marginTop: 4 }}
      />
      <TextWidget
        text={limit > 0 ? 'of ' + money(limit, symbol) + ' this month' : 'Set a monthly budget in the app'}
        style={{ fontSize: 11, color: MUTED, marginTop: 2 }}
      />
    </FlexWidget>
  );
}

// Net worth widget: the headline number, always one tap from home.
export function NetWorthWidget({ netWorth = 0, symbol = '₱' }) {
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
      <TextWidget text="NET WORTH" style={{ fontSize: 10, color: MINT, letterSpacing: 0.1 }} />
      <TextWidget
        text={money(netWorth, symbol)}
        style={{ fontSize: 24, fontWeight: 'bold', color: netWorth >= 0 ? TEXT : WARN, marginTop: 4 }}
      />
      <TextWidget text="Tap to open Salapify" style={{ fontSize: 11, color: MUTED, marginTop: 2 }} />
    </FlexWidget>
  );
}
