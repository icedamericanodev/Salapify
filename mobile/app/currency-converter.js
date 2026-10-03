// Currency converter. A simple reference tool: type an amount, pick From and To,
// see what it is worth. It reuses the same live rate layer as logging a foreign
// expense (hooks/useFxRates), so rates are fetched when online and cached for
// offline, and only your base currency code is ever sent, never your data.
//
// Deliberately a CONVERTER, not an exchange: it shows what money is worth, it
// never moves, trades, or sends money. No dashes anywhere per house style.

import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View, Linking } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';
import { CURRENCIES, currencySymbol, formatConverted } from '../lib/currencies';
import { useFxRates } from '../hooks/useFxRates';
import { crossRate, roundRate } from '../lib/fxrates';

// Hoisted out of the screen so it keeps its identity across renders: defining it
// inline would remount both chip rows on every keystroke and snap them back to
// the start, hiding the currency the user picked.
function CurrencyRow({ label, value, onPick, styles }) {
  return (
    <>
      <Text style={styles.fieldLabel}>{label}</Text>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chips}>
        {CURRENCIES.map((c) => {
          const on = value === c.code;
          return (
            <Pressable key={c.code} onPress={() => onPick(c.code)} style={[styles.chip, on && styles.chipOn]}>
              <Text style={[styles.chipText, on && styles.chipTextOn]}>{c.symbol} {c.code}</Text>
            </Pressable>
          );
        })}
      </ScrollView>
    </>
  );
}

export default function CurrencyConverter() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data } = useAppData();

  const baseCode = (data.settings && data.settings.currencyCode) || 'PHP';
  const [amount, setAmount] = useState('');
  const [from, setFrom] = useState(baseCode);
  const [to, setTo] = useState(baseCode === 'USD' ? 'PHP' : 'USD');

  // One rates table (units per base currency); cross rates convert between any two.
  const fx = useFxRates(baseCode);
  const haveRates = fx.base === baseCode && fx.rates;
  const rate = haveRates ? crossRate(fx.rates, from, to) : null;

  const amountNum = Number(String(amount).replace(/[, ]/g, '')) || 0;
  const converted = rate != null ? amountNum * rate : null;

  // The rate table's date, so the user knows how fresh the numbers are.
  const asOf = (() => {
    if (!fx.fetchedAt) return '';
    try {
      const d = new Date(fx.fetchedAt);
      return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    } catch (e) {
      return '';
    }
  })();

  const swap = () => {
    setFrom(to);
    setTo(from);
  };

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back} accessibilityRole="button" accessibilityLabel="Go back">
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>Currency converter</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={styles.intro}>
          See what your money is worth in another currency. Rates come from the internet when you are online and are saved for offline use. This shows values only, it does not exchange or move money.
        </Text>

        <Text style={styles.fieldLabel}>Amount in {from}</Text>
        <View style={styles.inputWrap}>
          <Text style={styles.sym}>{currencySymbol(from)}</Text>
          <TextInput
            style={styles.input}
            value={amount}
            onChangeText={setAmount}
            keyboardType="numeric"
            placeholder="0"
            placeholderTextColor={colors.faint}
            autoFocus
          />
        </View>

        <CurrencyRow label="From" value={from} onPick={setFrom} styles={styles} />

        <Pressable onPress={swap} style={styles.swapBtn} accessibilityRole="button" accessibilityLabel="Swap currencies">
          <Ionicons name="swap-vertical" size={18} color={colors.primary} />
          <Text style={styles.swapText}>Swap</Text>
        </Pressable>

        <CurrencyRow label="To" value={to} onPick={setTo} styles={styles} />

        <View style={styles.resultCard}>
          {from === to ? (
            <Text style={styles.resultBig}>{formatConverted(amountNum, to)}</Text>
          ) : converted != null ? (
            <>
              <Text style={styles.resultBig}>{formatConverted(converted, to)}</Text>
              <Text style={styles.resultRate}>
                1 {from} = {roundRate(rate)} {to}
                {asOf ? ` · rates as of ${asOf}` : ''}
              </Text>
            </>
          ) : fx.loading ? (
            <Text style={styles.resultNote}>Getting today's rates…</Text>
          ) : (
            <Text style={styles.resultNote}>
              No rate for {from} to {to} yet. Connect to the internet once to download today's rates, then it works offline too.
            </Text>
          )}
        </View>

        <Pressable onPress={() => Linking.openURL('https://www.exchangerate-api.com').catch(() => {})}>
          <Text style={styles.attribution}>Rates by Exchange Rate API</Text>
        </Pressable>
      </ScrollView>
    </SafeAreaView>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: spacing.lg, paddingTop: spacing.md, paddingBottom: spacing.sm },
    back: { marginLeft: -4 },
    headerTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },
    intro: { color: colors.muted, fontSize: fontSize.small, marginBottom: spacing.lg, lineHeight: 19 },

    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs, marginTop: spacing.md },
    inputWrap: { flexDirection: 'row', alignItems: 'center', backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md },
    sym: { color: colors.textSecondary, fontSize: fontSize.body, marginRight: spacing.xs },
    input: { flex: 1, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },

    chips: { flexDirection: 'row', gap: spacing.sm, paddingVertical: 2 },
    chip: { paddingVertical: spacing.xs, paddingHorizontal: spacing.md, borderRadius: radius.pill, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.card },
    chipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    chipText: { color: colors.text, fontSize: fontSize.small },
    chipTextOn: { color: colors.onPrimary, fontWeight: fontWeight.bold },

    swapBtn: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs, alignSelf: 'center', marginTop: spacing.md, paddingVertical: spacing.xs, paddingHorizontal: spacing.md },
    swapText: { color: colors.primary, fontSize: fontSize.small, fontWeight: fontWeight.bold },

    resultCard: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.xl, marginTop: spacing.lg, alignItems: 'center' },
    resultBig: { color: colors.primary, fontSize: fontSize.title, fontWeight: fontWeight.heavy },
    resultRate: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.sm, textAlign: 'center' },
    resultNote: { color: colors.textSecondary, fontSize: fontSize.small, textAlign: 'center', lineHeight: 18 },

    attribution: { color: colors.faint, fontSize: fontSize.caption, textAlign: 'center', marginTop: spacing.lg, textDecorationLine: 'underline' },
  });
}
