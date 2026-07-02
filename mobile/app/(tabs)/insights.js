// Insights screen. Simple, readable charts built from plain views (no chart
// library yet, so nothing extra to install): income vs spending, spending by
// category, net worth by category, and a net worth trend. Sample data for now.

import { useMemo } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { spacing, radius, fontSize, fontWeight } from '../../theme';
import { useTheme } from '../../context/Theme';
import { useAppData } from '../../context/AppData';
import { formatMoney, isThisMonth, monthLabel } from '../../lib/format';
import { sampleNetWorthHistory } from '../../lib/sampleData';

export default function Insights() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const { data } = useAppData(); // live data from the store

  const sum = (list, fn) => list.reduce((t, x) => t + fn(x), 0);

  // Income vs spending, this month only.
  const thisMonth = data.transactions.filter((t) => isThisMonth(t.date));
  const moneyIn = sum(thisMonth.filter((t) => t.type === 'income'), (t) => t.amount);
  const moneyOut = sum(thisMonth.filter((t) => t.type === 'expense'), (t) => t.amount);

  // Spending by category (using the expense label as the category), this month only.
  const byCategory = thisMonth
    .filter((t) => t.type === 'expense')
    .map((t) => ({ label: t.label, amount: t.amount }))
    .sort((a, b) => b.amount - a.amount);

  // Net worth by category.
  const cash = sum(data.accounts.filter((a) => a.kind === 'cash'), (a) => a.balance);
  const bank = sum(
    data.accounts.filter((a) => ['savings', 'checking', 'ewallet'].includes(a.kind)),
    (a) => a.balance
  );
  const investments = sum(data.assets, (a) => a.value);
  const debt = sum(data.debts, (d) => d.remaining);
  const worthRows = [
    { label: 'Cash', amount: cash, color: colors.primary },
    { label: 'Bank', amount: bank, color: colors.primary },
    { label: 'Investments', amount: investments, color: colors.primary },
    { label: 'Debt', amount: debt, color: colors.warning },
  ];

  // A horizontal bar: label, a filled track sized by share of max, and amount.
  const HBar = ({ label, amount, max, color }) => (
    <View style={styles.hbarRow}>
      <Text style={styles.hbarLabel}>{label}</Text>
      <View style={styles.hbarTrack}>
        <View
          style={[
            styles.hbarFill,
            { width: `${max ? Math.max((amount / max) * 100, 2) : 0}%`, backgroundColor: color },
          ]}
        />
      </View>
      <Text style={styles.hbarValue}>{formatMoney(amount)}</Text>
    </View>
  );

  const catMax = Math.max(...byCategory.map((c) => c.amount), 1);
  const worthMax = Math.max(...worthRows.map((w) => w.amount), 1);
  const inOutMax = Math.max(moneyIn, moneyOut, 1);

  // Net worth trend as small vertical bars.
  const trendMax = Math.max(...sampleNetWorthHistory.map((p) => p.value), 1);

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.pageTitle}>Insights</Text>

        <View style={styles.card}>
          <Text style={styles.kicker}>INCOME VS SPENDING ({monthLabel().toUpperCase()})</Text>
          <View style={styles.cardBody}>
            <HBar label="In" amount={moneyIn} max={inOutMax} color={colors.primary} />
            <HBar label="Out" amount={moneyOut} max={inOutMax} color={colors.warning} />
          </View>
        </View>

        <View style={styles.card}>
          <Text style={styles.kicker}>SPENDING BY CATEGORY</Text>
          <View style={styles.cardBody}>
            {byCategory.map((c) => (
              <HBar key={c.label} label={c.label} amount={c.amount} max={catMax} color={colors.primary} />
            ))}
          </View>
        </View>

        <View style={styles.card}>
          <Text style={styles.kicker}>NET WORTH BY CATEGORY</Text>
          <View style={styles.cardBody}>
            {worthRows.map((w) => (
              <HBar key={w.label} label={w.label} amount={w.amount} max={worthMax} color={w.color} />
            ))}
          </View>
        </View>

        <View style={styles.card}>
          <Text style={styles.kicker}>NET WORTH TREND</Text>
          <View style={styles.trend}>
            {sampleNetWorthHistory.map((p) => (
              <View key={p.month} style={styles.trendCol}>
                <View
                  style={[
                    styles.trendBar,
                    { height: Math.max((p.value / trendMax) * 120, 4) },
                  ]}
                />
                <Text style={styles.trendLabel}>{p.month}</Text>
              </View>
            ))}
          </View>
          <Text style={styles.trendNow}>Now: {formatMoney(sampleNetWorthHistory[sampleNetWorthHistory.length - 1].value)}</Text>
        </View>

        <Text style={styles.footnote}>Charts show {monthLabel()}. The net worth trend is sample data for now.</Text>
      </ScrollView>
    </SafeAreaView>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },
    pageTitle: {
      color: colors.text,
      fontSize: fontSize.title,
      fontWeight: fontWeight.bold,
      marginBottom: spacing.md,
    },

    card: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.lg,
      padding: spacing.xl,
      marginBottom: spacing.lg,
    },
    kicker: {
      color: colors.softGreen,
      fontSize: fontSize.caption,
      fontWeight: fontWeight.medium,
      letterSpacing: 2,
    },
    cardBody: { marginTop: spacing.md, gap: spacing.md },

    hbarRow: { flexDirection: 'row', alignItems: 'center' },
    hbarLabel: { color: colors.textSecondary, fontSize: fontSize.small, width: 92 },
    hbarTrack: {
      flex: 1,
      height: 12,
      borderRadius: radius.pill,
      backgroundColor: colors.border,
      overflow: 'hidden',
      marginHorizontal: spacing.sm,
    },
    hbarFill: { height: '100%', borderRadius: radius.pill },
    hbarValue: {
      color: colors.text,
      fontSize: fontSize.small,
      fontWeight: fontWeight.bold,
      width: 72,
      textAlign: 'right',
    },

    trend: {
      flexDirection: 'row',
      alignItems: 'flex-end',
      justifyContent: 'space-between',
      height: 140,
      marginTop: spacing.md,
    },
    trendCol: { alignItems: 'center', flex: 1 },
    trendBar: {
      width: 22,
      borderRadius: radius.sm,
      backgroundColor: colors.primary,
    },
    trendLabel: { color: colors.muted, fontSize: fontSize.caption, marginTop: spacing.xs },
    trendNow: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.md },

    footnote: {
      color: colors.faint,
      fontSize: fontSize.small,
      textAlign: 'center',
      marginTop: spacing.sm,
    },
  });
}
