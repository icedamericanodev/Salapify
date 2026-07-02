// Reports: three simple financial statements built from your data.
//  - Financial Position (assets, liabilities, net worth) like a balance sheet
//  - Income Statement (income, expenses, net)
//  - Cash Flow (money in, money out incl. debt payments, net change)
// Reached from the More tab. Read-only summaries.

import { useMemo } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';
import { formatMoney } from '../lib/format';

export default function Reports() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data } = useAppData();

  const sum = (list, fn) => (list || []).reduce((t, x) => t + fn(x), 0);

  // ---- Financial Position ----
  const cash = sum(data.accounts.filter((a) => a.kind === 'cash'), (a) => a.balance);
  const bank = sum(data.accounts.filter((a) => ['savings', 'checking', 'ewallet'].includes(a.kind)), (a) => a.balance);
  const investments = sum(data.assets, (a) => a.value);
  const receivables = sum((data.receivables || []).filter((r) => !r.paid), (r) => r.amount);
  const totalAssets = cash + bank + investments + receivables;
  const liabilities = sum(data.debts, (d) => d.remaining);
  const netWorth = totalAssets - liabilities;

  // ---- Income Statement ----
  const income = sum(data.transactions.filter((t) => t.type === 'income'), (t) => t.amount);
  const expenses = sum(data.transactions.filter((t) => t.type === 'expense'), (t) => t.amount);
  const netIncome = income - expenses;

  // ---- Cash Flow ----
  const debtPaid = sum(data.payments, (p) => p.amount);
  const cashIn = income;
  const cashOut = expenses + debtPaid;
  const netCash = cashIn - cashOut;

  const Line = ({ label, value, strong, color }) => (
    <View style={styles.line}>
      <Text style={[styles.lineLabel, strong && styles.strongLabel]}>{label}</Text>
      <Text style={[styles.lineValue, strong && styles.strongValue, color ? { color } : null]}>
        {formatMoney(value)}
      </Text>
    </View>
  );

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>Reports</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        {/* Financial Position */}
        <Text style={styles.sectionTitle}>FINANCIAL POSITION</Text>
        <View style={styles.card}>
          <Text style={styles.groupLabel}>Assets</Text>
          <Line label="Cash" value={cash} />
          <Line label="Savings and bank" value={bank} />
          <Line label="Investments" value={investments} />
          <Line label="Receivables" value={receivables} />
          <Line label="Total assets" value={totalAssets} strong color={colors.primary} />
          <View style={styles.divider} />
          <Text style={styles.groupLabel}>Liabilities</Text>
          <Line label="Debts" value={liabilities} />
          <Line label="Total liabilities" value={liabilities} strong color={colors.warning} />
          <View style={styles.divider} />
          <Line label="Net worth" value={netWorth} strong color={netWorth >= 0 ? colors.primary : colors.warning} />
        </View>

        {/* Income Statement */}
        <Text style={styles.sectionTitle}>INCOME STATEMENT</Text>
        <View style={styles.card}>
          <Line label="Income" value={income} color={colors.primary} />
          <Line label="Expenses" value={expenses} color={colors.warning} />
          <View style={styles.divider} />
          <Line label="Net income" value={netIncome} strong color={netIncome >= 0 ? colors.primary : colors.warning} />
        </View>

        {/* Cash Flow */}
        <Text style={styles.sectionTitle}>CASH FLOW</Text>
        <View style={styles.card}>
          <Line label="Cash in (income)" value={cashIn} color={colors.primary} />
          <Line label="Cash out (spending)" value={expenses} color={colors.warning} />
          <Line label="Cash out (debt payments)" value={debtPaid} color={colors.warning} />
          <View style={styles.divider} />
          <Line label="Net cash flow" value={netCash} strong color={netCash >= 0 ? colors.primary : colors.warning} />
        </View>

        <Text style={styles.footnote}>
          Figures are based on everything you have recorded so far.
        </Text>
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

    sectionTitle: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.5, marginBottom: spacing.sm, marginTop: spacing.md, paddingHorizontal: spacing.xs },
    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.xl, marginBottom: spacing.lg },
    groupLabel: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1, marginBottom: spacing.sm },
    line: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: spacing.sm },
    lineLabel: { color: colors.textSecondary, fontSize: fontSize.body },
    lineValue: { color: colors.text, fontSize: fontSize.body },
    strongLabel: { color: colors.text, fontWeight: fontWeight.bold },
    strongValue: { fontWeight: fontWeight.bold, fontSize: fontSize.subtitle },
    divider: { height: StyleSheet.hairlineWidth, backgroundColor: colors.border, marginVertical: spacing.sm },
    footnote: { color: colors.faint, fontSize: fontSize.small, textAlign: 'center', marginTop: spacing.sm },
  });
}
