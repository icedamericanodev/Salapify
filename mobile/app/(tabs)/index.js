// Overview screen (Home). Shows the headline numbers: net worth, this month's
// cash flow (money in minus money out), and days to payday, plus quick links
// to the main sections. Uses sample data for now; real data arrives in Phase 2.

import { useMemo } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../../theme';
import { useTheme } from '../../context/Theme';
import { useAppData } from '../../context/AppData';
import { formatMoney, daysUntilPayday } from '../../lib/format';

export default function Overview() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter(); // lets the quick links open other tabs
  const { data } = useAppData(); // live data from the store

  // Helper to add up a number field across a list.
  const sum = (list, key) => list.reduce((total, item) => total + item[key], 0);

  // Net worth: everything you own minus everything you owe.
  const totalAssets = sum(data.accounts, 'balance') + sum(data.assets, 'value');
  const totalDebt = sum(data.debts, 'remaining');
  const netWorth = totalAssets - totalDebt;

  // This month's cash flow.
  const income = data.transactions.filter((t) => t.type === 'income');
  const expense = data.transactions.filter((t) => t.type === 'expense');
  const moneyIn = sum(income, 'amount');
  const moneyOut = sum(expense, 'amount');
  const cashFlow = moneyIn - moneyOut;

  // Days to the next payday.
  const payday = daysUntilPayday();

  // The quick links shown at the bottom. Each opens a tab when tapped.
  const links = [
    { label: 'Accounts', icon: 'wallet-outline', href: '/accounts' },
    { label: 'Debts', icon: 'card-outline', href: '/debts' },
    { label: 'Budget', icon: 'pie-chart-outline', href: '/budget' },
    { label: 'Insights', icon: 'bar-chart-outline', href: '/insights' },
  ];

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.pageTitle}>Overview</Text>

        {/* Net worth headline. */}
        <View style={styles.card}>
          <Text style={styles.kicker}>NET WORTH</Text>
          <Text style={styles.netWorth}>{formatMoney(netWorth)}</Text>
          <View style={styles.splitRow}>
            <View>
              <Text style={styles.smallLabel}>Total assets</Text>
              <Text style={[styles.smallValue, { color: colors.primary }]}>
                {formatMoney(totalAssets)}
              </Text>
            </View>
            <View>
              <Text style={styles.smallLabel}>Total debt</Text>
              <Text style={[styles.smallValue, { color: colors.warning }]}>
                {formatMoney(totalDebt)}
              </Text>
            </View>
          </View>
        </View>

        {/* This month's cash flow. */}
        <View style={styles.card}>
          <Text style={styles.kicker}>THIS MONTH</Text>
          <Text
            style={[
              styles.cashFlow,
              { color: cashFlow >= 0 ? colors.primary : colors.warning },
            ]}
          >
            {cashFlow >= 0 ? '+' : ''}
            {formatMoney(cashFlow)}
          </Text>
          <View style={styles.splitRow}>
            <View>
              <Text style={styles.smallLabel}>Money in</Text>
              <Text style={[styles.smallValue, { color: colors.primary }]}>
                {formatMoney(moneyIn)}
              </Text>
            </View>
            <View>
              <Text style={styles.smallLabel}>Money out</Text>
              <Text style={[styles.smallValue, { color: colors.warning }]}>
                {formatMoney(moneyOut)}
              </Text>
            </View>
          </View>
        </View>

        {/* Days to payday. */}
        <View style={styles.card}>
          <Text style={styles.kicker}>DAYS TO PAYDAY</Text>
          <Text style={styles.payday}>
            {payday} {payday === 1 ? 'day' : 'days'}
          </Text>
          <Text style={styles.smallLabel}>Based on the 15th and end of month.</Text>
        </View>

        {/* Quick links to the other tabs. */}
        <Text style={styles.sectionTitle}>QUICK LINKS</Text>
        <View style={styles.linksRow}>
          {links.map((link) => (
            <Pressable
              key={link.href}
              onPress={() => router.push(link.href)}
              style={({ pressed }) => [styles.linkCard, pressed && styles.pressed]}
            >
              <Ionicons name={link.icon} size={22} color={colors.primary} />
              <Text style={styles.linkLabel}>{link.label}</Text>
            </Pressable>
          ))}
        </View>

        <Text style={styles.footnote}>Sample data for now. Real data comes in Phase 2.</Text>
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
    netWorth: {
      color: colors.text,
      fontSize: fontSize.huge,
      fontWeight: fontWeight.bold,
      marginTop: spacing.xs,
      marginBottom: spacing.lg,
    },
    cashFlow: {
      fontSize: fontSize.huge,
      fontWeight: fontWeight.bold,
      marginTop: spacing.xs,
      marginBottom: spacing.lg,
    },
    payday: {
      color: colors.text,
      fontSize: fontSize.big,
      fontWeight: fontWeight.bold,
      marginTop: spacing.xs,
      marginBottom: spacing.xs,
    },

    splitRow: { flexDirection: 'row', justifyContent: 'space-between' },
    smallLabel: { color: colors.muted, fontSize: fontSize.caption },
    smallValue: { fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginTop: spacing.xs },

    sectionTitle: {
      color: colors.muted,
      fontSize: fontSize.caption,
      fontWeight: fontWeight.medium,
      letterSpacing: 1.5,
      marginBottom: spacing.sm,
      paddingHorizontal: spacing.xs,
    },
    linksRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.md },
    linkCard: {
      flexGrow: 1,
      flexBasis: '47%', // two per row
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.md,
      paddingVertical: spacing.lg,
      alignItems: 'center',
      gap: spacing.xs,
    },
    pressed: { opacity: 0.6 },
    linkLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },

    footnote: {
      color: colors.faint,
      fontSize: fontSize.small,
      textAlign: 'center',
      marginTop: spacing.lg,
    },
  });
}
