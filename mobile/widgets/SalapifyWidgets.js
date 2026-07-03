// The two Android home screen widgets, drawn with the widget library's own
// primitives (FlexWidget and TextWidget render to real Android widget
// views, not React Native views). Colors are hard coded to the dark brand
// palette because widgets cannot read the app's theme context.

import React from 'react';
import { FlexWidget, TextWidget } from 'react-native-android-widget';

const BG = '#0B1210';
const BORDER = '#23372E';
const MINT = '#2FD48F';
const TEXT = '#F2FBF6';
const MUTED = '#8FA39A';
const WARN = '#F2A05F';

function money(n) {
  const v = Math.round(Number(n) || 0);
  const sign = v < 0 ? '-' : '';
  return sign + '₱' + Math.abs(v).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

// Budget widget: how much of this month's limit is left to spend.
export function BudgetWidget({ spent = 0, limit = 0 }) {
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
        text={over ? money(-left) + ' over' : money(left) + ' left'}
        style={{ fontSize: 24, fontWeight: 'bold', color: over ? WARN : TEXT, marginTop: 4 }}
      />
      <TextWidget
        text={limit > 0 ? 'of ' + money(limit) + ' this month' : 'Set a monthly budget in the app'}
        style={{ fontSize: 11, color: MUTED, marginTop: 2 }}
      />
    </FlexWidget>
  );
}

// Net worth widget: the headline number, always one tap from home.
export function NetWorthWidget({ netWorth = 0 }) {
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
        text={money(netWorth)}
        style={{ fontSize: 24, fontWeight: 'bold', color: netWorth >= 0 ? TEXT : WARN, marginTop: 4 }}
      />
      <TextWidget text="Tap to open Salapify" style={{ fontSize: 11, color: MUTED, marginTop: 2 }} />
    </FlexWidget>
  );
}
