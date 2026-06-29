// Budget and logging screen. Shows the monthly spending limit with a progress
// bar, quick add buttons for fast expense logging, and recent transactions.
// The quick add buttons add to a temporary list so you can feel the logging
// flow; real saving arrives in Phase 2.

import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { spacing, radius, fontSize, fontWeight } from '../../theme';
import { useTheme } from '../../context/Theme';
import { formatMoney } from '../../lib/format';
import { sampleBudget, sampleTransactions } from '../../lib/sampleData';

export default function Budget() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);

  // The sample expenses already on file (money out).
  const baseExpenses = sampleTransactions
    .filter((t) => t.type === 'expense')
    .map((t) => ({ id: t.id, label: t.label, amount: t.amount }));

  // Expenses you add by tapping a quick add button. Temporary, resets on reload.
  const [logged, setLogged] = useState([]);

  function quickAdd(item) {
    setLogged((prev) => [{ id: `${item.label}-${prev.length}-${Date.now()}`, ...item }, ...prev]);
  }

  // Newest first: your tapped ones, then the sample ones.
  const recent = [...logged, ...baseExpenses];
  const spent = recent.reduce((total, e) => total + e.amount, 0);
  const limit = sampleBudget.monthlyLimit;
  const remaining = limit - spent;
  const pct = Math.min(Math.round((spent / limit) * 100), 100);
  const over = spent > limit;

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.pageTitle}>Budget</Text>

        {/* Monthly limit with a progress bar. */}
        <View style={styles.card}>
          <Text style={styles.kicker}>THIS MONTH</Text>
          <Text style={styles.spent}>
            {formatMoney(spent)} <Text style={styles.ofLimit}>of {formatMoney(limit)}</Text>
          </Text>
          <View style={styles.track}>
            <View
              style={[
                styles.fill,
                { width: `${pct}%`, backgroundColor: over ? colors.warning : colors.primary },
              ]}
            />
          </View>
          <Text style={[styles.remaining, { color: over ? colors.warning : colors.muted }]}>
            {over
              ? `${formatMoney(-remaining)} over your limit`
              : `${formatMoney(remaining)} left to spend`}
          </Text>
        </View>

        {/* Quick add buttons for fast logging. */}
        <Text style={styles.sectionTitle}>QUICK ADD</Text>
        <View style={styles.quickRow}>
          {sampleBudget.quickAdds.map((item) => (
            <Pressable
              key={item.label}
              onPress={() => quickAdd(item)}
              style={({ pressed }) => [styles.quick, pressed && styles.pressed]}
            >
              <Text style={styles.quickLabel}>{item.label}</Text>
              <Text style={styles.quickAmount}>{formatMoney(item.amount)}</Text>
            </Pressable>
          ))}
        </View>

        {/* Recent transactions. */}
        <Text style={styles.sectionTitle}>RECENT</Text>
        <View style={styles.card}>
          {recent.slice(0, 8).map((e) => (
            <View key={e.id} style={styles.row}>
              <Text style={styles.rowName}>{e.label}</Text>
              <Text style={styles.rowAmount}>- {formatMoney(e.amount)}</Text>
            </View>
          ))}
        </View>

        <Text style={styles.footnote}>
          Tap a quick add to log an expense. Saving for real comes in Phase 2.
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
    kicker: {
      color: colors.softGreen,
      fontSize: fontSize.caption,
      fontWeight: fontWeight.medium,
      letterSpacing: 2,
    },
    spent: {
      color: colors.text,
      fontSize: fontSize.big,
      fontWeight: fontWeight.bold,
      marginTop: spacing.xs,
      marginBottom: spacing.md,
    },
    ofLimit: { color: colors.muted, fontSize: fontSize.body, fontWeight: fontWeight.regular },
    track: {
      height: 10,
      borderRadius: radius.pill,
      backgroundColor: colors.border,
      overflow: 'hidden',
    },
    fill: { height: '100%', borderRadius: radius.pill },
    remaining: { fontSize: fontSize.small, marginTop: spacing.sm },

    sectionTitle: {
      color: colors.muted,
      fontSize: fontSize.caption,
      fontWeight: fontWeight.medium,
      letterSpacing: 1.5,
      marginBottom: spacing.sm,
      paddingHorizontal: spacing.xs,
    },
    quickRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.md, marginBottom: spacing.lg },
    quick: {
      flexGrow: 1,
      flexBasis: '47%',
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.md,
      paddingVertical: spacing.md,
      paddingHorizontal: spacing.lg,
      flexDirection: 'row',
      justifyContent: 'space-between',
      alignItems: 'center',
    },
    pressed: { opacity: 0.6 },
    quickLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    quickAmount: { color: colors.softGreen, fontSize: fontSize.body, fontWeight: fontWeight.bold },

    row: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      alignItems: 'center',
      paddingVertical: spacing.md,
      borderBottomColor: colors.border,
      borderBottomWidth: StyleSheet.hairlineWidth,
    },
    rowName: { color: colors.text, fontSize: fontSize.body },
    rowAmount: { color: colors.warning, fontSize: fontSize.body, fontWeight: fontWeight.bold },

    footnote: {
      color: colors.faint,
      fontSize: fontSize.small,
      textAlign: 'center',
      marginTop: spacing.sm,
    },
  });
}
