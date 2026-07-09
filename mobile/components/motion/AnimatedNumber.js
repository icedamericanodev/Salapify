// AnimatedNumber. The hero money figures (net worth, cash flow, safe to spend,
// the health score) used to snap in. This rolls them up to their value on mount
// and on change, so the number the whole screen is built around feels live.
//
// It uses the standard Reanimated "animated text" trick: a non editable
// TextInput whose text is driven by a worklet on the UI thread, so the count
// never touches the JS thread per frame. formatMoney's comma logic is ported to
// a worklet safe helper (no regex) and the currency symbol is captured on the
// JS side and passed in.
//
// Props:
//  - value: the number to show.
//  - symbol: currency symbol override; defaults to the app's current symbol.
//    Pass '' for a bare number (used by the health score, which is not money).
//  - money: when false, render a plain rounded number with no symbol or commas
//    stripping (used for the 0..100 score). Default true.
//  - signed: prepend a + for zero or positive money (used by cash flow, which
//    shows +12,000 vs -3,000). Default false.
//  - style: text style, applied to the number.
//  - accessibilityLabel: what a screen reader announces. Defaults to the final
//    formatted value, so a reader never hears a rolling number.
//
// Reduce motion aware: when the user has reduce motion on, it renders a plain
// Text at the final value with no tween and no TextInput.

import { useEffect } from 'react';
import { Text, TextInput } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedProps,
  withTiming,
  Easing,
  ReduceMotion,
} from 'react-native-reanimated';
import { formatMoney, getCurrencySymbol } from '../../lib/format';
import { duration } from '../../theme';
import { useReduceMotion } from '../../context/Motion';

const AnimatedTextInput = Animated.createAnimatedComponent(TextInput);

// Worklet safe money formatter: round, sign, and insert thousands commas with a
// plain loop (no regex, which is not reliable inside a worklet). money=false
// gives a bare rounded integer for non money figures like the health score.
function formatWorklet(n, symbol, money, signed) {
  'worklet';
  const rounded = Math.round(n);
  if (!money) return String(rounded);
  const sign = rounded < 0 ? '-' : signed ? '+' : '';
  const s = String(Math.abs(rounded));
  let out = '';
  let count = 0;
  for (let i = s.length - 1; i >= 0; i--) {
    out = s[i] + out;
    count += 1;
    if (count % 3 === 0 && i !== 0) out = ',' + out;
  }
  return sign + symbol + out;
}

export default function AnimatedNumber({
  value,
  symbol,
  money = true,
  signed = false,
  style,
  accessibilityLabel,
  ...rest
}) {
  const reduce = useReduceMotion();
  const v = Number(value) || 0;
  const sym = money ? (symbol != null ? symbol : getCurrencySymbol()) : '';
  const shared = useSharedValue(reduce ? v : 0);

  useEffect(() => {
    if (reduce) {
      shared.value = v;
      return;
    }
    shared.value = withTiming(v, {
      duration: duration.slow,
      easing: Easing.out(Easing.cubic),
      reduceMotion: ReduceMotion.System,
    });
  }, [v, reduce]);

  // useAnimatedProps must run on every render, before any early return, or the
  // hook count changes when reduce motion toggles at runtime (a hooks order
  // crash). It is harmless to compute when we end up rendering the plain Text.
  const animatedProps = useAnimatedProps(() => {
    const text = formatWorklet(shared.value, sym, money, signed);
    // text drives what shows; defaultValue keeps it defined for the first frame.
    return { text, defaultValue: text };
  });

  // The final, resting string. Used for the reduce motion render, the initial
  // TextInput value, and the screen reader label so a reader hears the real
  // number, never a mid roll value.
  const posSign = signed && Math.round(v) >= 0 ? '+' : '';
  const finalStr = money ? posSign + formatMoney(v, sym) : String(Math.round(v));
  const label = accessibilityLabel != null ? accessibilityLabel : finalStr;

  if (reduce) {
    return (
      <Text style={style} accessibilityLabel={label} {...rest}>
        {finalStr}
      </Text>
    );
  }

  return (
    <AnimatedTextInput
      editable={false}
      // Not a real input to the user: it is a live number display. The label
      // carries the final value so a screen reader stays on the real figure.
      accessible
      accessibilityLabel={label}
      importantForAccessibility="yes"
      underlineColorAndroid="transparent"
      // Strip the platform's default input chrome so it reads and aligns as
      // plain text next to sibling Text (includeFontPadding keeps the Android
      // baseline matching a neighbor like the score's "/ 100").
      style={[{ padding: 0, margin: 0, includeFontPadding: false }, style]}
      value={undefined}
      defaultValue={finalStr}
      animatedProps={animatedProps}
      {...rest}
    />
  );
}
