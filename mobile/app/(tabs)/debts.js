// Debts screen. Shows total debt, a payoff strategy switch (Snowball vs
// Avalanche), the "focus debt" to attack first, and your debts grouped into
// short term and long term with subtotals. Sample data for now; logging
// payments and marking debts paid arrive in Phase 2.

import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { spacing, radius, fontSize, fontWeight } from '../../theme';
import { useTheme } from '../../context/Theme';
import { formatMoney } from '../../lib/format';
import { sampleDebts } from '../../lib/sampleData';

// Which debt types count as short term. The rest are long term.
const SHORT_TERM_TYPES = ['credit card', 'bnpl', 'short term', 'insurance'];
const termOf = (type) => (SHORT_TERM_TYPES.includes(type) ? 'short' : 'long');

// Monthly interest in pesos for a debt = remaining * (rate% / 100).
const monthlyInterest = (debt) => Math.round((debt.remaining * debt.monthlyRate) / 100);

export default function Debts() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);

  // The chosen payoff strategy. Local to this screen for now.
  const [strategy, setStrategy] = useState('snowball');

  // Totals.
  const sum = (list, fn) => list.reduce((total, d) => total + fn(d), 0);
  const totalDebt = sum(sampleDebts, (d) => d.remaining);
  const totalMin = sum(sampleDebts, (d) => d.minPayment);
  const totalInterest = sum(sampleDebts, monthlyInterest);

  // Order the debts by the chosen strategy.
  // Snowball: smallest balance first (quick wins, motivating).
  // Avalanche: highest interest rate first (cheapest overall).
  const ordered = [...sampleDebts].sort((a, b) =>
    strategy === 'snowball' ? a.remaining - b.remaining : b.monthlyRate - a.monthlyRate
  );
  const focus = ordered[0]; // the debt to attack first

  // Group for the lists below.
  const shortTerm = sampleDebts.filter((d) => termOf(d.type) === 'short');
  const longTerm = sampleDebts.filter((d) => termOf(d.type) === 'long');

  // One debt row.
  const Row = ({ debt }) => (
    <View style={styles.row}>
      <Text style={styles.rowIcon}>💳</Text>
      <View style={styles.rowMiddle}>
        <Text style={styles.rowName}>{debt.name}</Text>
        <Text style={styles.rowSub}>
          Min {formatMoney(debt.minPayment)} . {formatMoney(monthlyInterest(debt))} interest/mo
        </Text>
      </View>
      <Text style={styles.rowAmount}>{formatMoney(debt.remaining)}</Text>
    </View>
  );

  // A titled group with a subtotal.
  const Group = ({ title, list }) => {
    if (list.length === 0) return null;
    return (
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>{title}</Text>
          <Text style={styles.sectionSubtotal}>
            {formatMoney(sum(list, (d) => d.remaining))}
          </Text>
        </View>
        <View style={styles.card}>
          {list.map((d) => (
            <Row key={d.id} debt={d} />
          ))}
        </View>
      </View>
    );
  };

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.pageTitle}>Debts</Text>

        {/* Total debt summary. */}
        <View style={styles.card}>
          <Text style={styles.kicker}>TOTAL DEBT</Text>
          <Text style={styles.totalDebt}>{formatMoney(totalDebt)}</Text>
          <View style={styles.splitRow}>
            <View>
              <Text style={styles.smallLabel}>Minimum due this month</Text>
              <Text style={styles.smallValue}>{formatMoney(totalMin)}</Text>
            </View>
            <View>
              <Text style={styles.smallLabel}>Interest this month</Text>
              <Text style={[styles.smallValue, { color: colors.warning }]}>
                {formatMoney(totalInterest)}
              </Text>
            </View>
          </View>
        </View>

        {/* Strategy switch. */}
        <View style={styles.cardPad}>
          <Text style={styles.kicker}>PAYOFF STRATEGY</Text>
          <View style={styles.toggleRow}>
            {[
              { key: 'snowball', label: 'Snowball' },
              { key: 'avalanche', label: 'Avalanche' },
            ].map((opt) => {
              const on = strategy === opt.key;
              return (
                <Pressable
                  key={opt.key}
                  onPress={() => setStrategy(opt.key)}
                  style={[styles.toggle, on && styles.toggleOn]}
                >
                  <Text style={[styles.toggleText, on && styles.toggleTextOn]}>
                    {opt.label}
                  </Text>
                </Pressable>
              );
            })}
          </View>
          <Text style={styles.strategyNote}>
            {strategy === 'snowball'
              ? 'Pay the smallest balance first for quick wins.'
              : 'Pay the highest interest first to save the most money.'}
          </Text>
        </View>

        {/* Focus debt. */}
        <View style={styles.focusCard}>
          <Text style={styles.focusKicker}>FOCUS DEBT</Text>
          <Text style={styles.focusName}>{focus.name}</Text>
          <Text style={styles.focusSub}>
            {formatMoney(focus.remaining)} left . put any extra money here first.
          </Text>
        </View>

        <Group title="SHORT TERM" list={shortTerm} />
        <Group title="LONG TERM" list={longTerm} />

        <Text style={styles.footnote}>
          Sample data for now. Logging payments comes in Phase 2.
        </Text>
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
    cardPad: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.lg,
      padding: spacing.lg,
      marginBottom: spacing.lg,
    },
    kicker: {
      color: colors.softGreen,
      fontSize: fontSize.caption,
      fontWeight: fontWeight.medium,
      letterSpacing: 2,
    },
    totalDebt: {
      color: colors.warning,
      fontSize: fontSize.huge,
      fontWeight: fontWeight.bold,
      marginTop: spacing.xs,
      marginBottom: spacing.lg,
    },
    splitRow: { flexDirection: 'row', justifyContent: 'space-between' },
    smallLabel: { color: colors.muted, fontSize: fontSize.caption },
    smallValue: {
      color: colors.text,
      fontSize: fontSize.subtitle,
      fontWeight: fontWeight.bold,
      marginTop: spacing.xs,
    },

    toggleRow: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.md },
    toggle: {
      flex: 1,
      paddingVertical: spacing.sm + 2,
      borderRadius: radius.md,
      borderWidth: 1,
      borderColor: colors.border,
      alignItems: 'center',
    },
    toggleOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    toggleText: { color: colors.muted, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    toggleTextOn: { color: '#FFFFFF' },
    strategyNote: { color: colors.faint, fontSize: fontSize.small, marginTop: spacing.md },

    focusCard: {
      backgroundColor: colors.card,
      borderColor: colors.primary,
      borderWidth: 1,
      borderRadius: radius.lg,
      padding: spacing.xl,
      marginBottom: spacing.lg,
    },
    focusKicker: {
      color: colors.primary,
      fontSize: fontSize.caption,
      fontWeight: fontWeight.bold,
      letterSpacing: 2,
    },
    focusName: {
      color: colors.text,
      fontSize: fontSize.title,
      fontWeight: fontWeight.bold,
      marginTop: spacing.xs,
    },
    focusSub: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.xs },

    section: { marginBottom: spacing.lg },
    sectionHeader: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      alignItems: 'flex-end',
      marginBottom: spacing.sm,
      paddingHorizontal: spacing.xs,
    },
    sectionTitle: {
      color: colors.muted,
      fontSize: fontSize.caption,
      fontWeight: fontWeight.medium,
      letterSpacing: 1.5,
    },
    sectionSubtotal: { color: colors.warning, fontSize: fontSize.body, fontWeight: fontWeight.bold },

    row: {
      flexDirection: 'row',
      alignItems: 'center',
      paddingVertical: spacing.md,
      borderBottomColor: colors.border,
      borderBottomWidth: StyleSheet.hairlineWidth,
    },
    rowIcon: { fontSize: 22, marginRight: spacing.md },
    rowMiddle: { flex: 1 },
    rowName: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    rowSub: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },
    rowAmount: { color: colors.warning, fontSize: fontSize.body, fontWeight: fontWeight.bold },

    footnote: {
      color: colors.faint,
      fontSize: fontSize.small,
      textAlign: 'center',
      marginTop: spacing.sm,
    },
  });
}
