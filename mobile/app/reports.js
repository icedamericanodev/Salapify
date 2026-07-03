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
import { formatMoney, isThisMonth, monthLabel } from '../lib/format';
import { debtFreeProjection } from '../lib/analytics';

const MONTHS_FULL = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const fmtMonth = (d) => `${MONTHS_FULL[d.getMonth()]} ${d.getFullYear()}`;

export default function Reports() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data } = useAppData();
  const pro = !!(data.settings && data.settings.pro);
  const hasDebts = (data.debts || []).some((d) => d && d.remaining > 0);
  const avalanche = pro && hasDebts ? debtFreeProjection(data.debts, 'avalanche') : null;
  const snowball = pro && hasDebts ? debtFreeProjection(data.debts, 'snowball') : null;
  const interestSaved = avalanche && snowball ? snowball.totalInterest - avalanche.totalInterest : 0;

  const sum = (list, fn) => (list || []).reduce((t, x) => t + fn(x), 0);

  // ---- Financial Position ----
  const cash = sum(data.accounts.filter((a) => a.kind === 'cash'), (a) => a.balance);
  const bank = sum(data.accounts.filter((a) => ['savings', 'checking', 'ewallet'].includes(a.kind)), (a) => a.balance);
  const investments = sum(data.assets, (a) => a.value);
  // Only what is STILL owed counts: a partial payment already became cash
  // in an account, counting the full amount here would double count it.
  const receivables = sum((data.receivables || []).filter((r) => !r.paid), (r) => {
    const paidSoFar = (r.payments || []).reduce((s, p) => s + (Number(p.amount) || 0), 0);
    return Math.max(0, (Number(r.amount) || 0) - paidSoFar);
  });
  const totalAssets = cash + bank + investments + receivables;
  const liabilities = sum(data.debts, (d) => d.remaining);
  const netWorth = totalAssets - liabilities;

  // ---- Income Statement (this month only) ----
  const thisMonth = data.transactions.filter((t) => isThisMonth(t.date));
  const income = sum(thisMonth.filter((t) => t.type === 'income'), (t) => t.amount);
  const expenses = sum(thisMonth.filter((t) => t.type === 'expense'), (t) => t.amount);
  const netIncome = income - expenses;

  // ---- Cash Flow (this month only) ----
  const debtPaid = sum((data.payments || []).filter((p) => isThisMonth(p.date)), (p) => p.amount);
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
        <Text style={styles.sectionTitle}>INCOME STATEMENT ({monthLabel().toUpperCase()})</Text>
        <View style={styles.card}>
          <Line label="Income" value={income} color={colors.primary} />
          <Line label="Expenses" value={expenses} color={colors.warning} />
          <View style={styles.divider} />
          <Line label="Net income" value={netIncome} strong color={netIncome >= 0 ? colors.primary : colors.warning} />
        </View>

        {/* Cash Flow */}
        <Text style={styles.sectionTitle}>CASH FLOW ({monthLabel().toUpperCase()})</Text>
        <View style={styles.card}>
          <Line label="Cash in (income)" value={cashIn} color={colors.primary} />
          <Line label="Cash out (spending)" value={expenses} color={colors.warning} />
          <Line label="Cash out (debt payments)" value={debtPaid} color={colors.warning} />
          <View style={styles.divider} />
          <Line label="Net cash flow" value={netCash} strong color={netCash >= 0 ? colors.primary : colors.warning} />
        </View>

        {/* Debt free plan: the Pro projection. */}
        <Text style={styles.sectionTitle}>DEBT FREE PLAN <Text style={styles.proBadge}>PRO</Text></Text>
        <View style={styles.card}>
          {!pro ? (
            <Text style={styles.lineLabel}>
              Unlock Pro on the Insights tab to see your debt free date and how much
              interest the right strategy saves you.
            </Text>
          ) : !hasDebts ? (
            <Text style={styles.lineLabel}>No debts to project. You are already free. 🎉</Text>
          ) : avalanche === null && snowball === null ? (
            <Text style={[styles.lineLabel, { color: colors.warning }]}>
              At the current minimum payments, interest grows faster than you pay.
              Raise the payments on your highest interest debt, even a little, and
              this projection will find your freedom date.
            </Text>
          ) : (
            <>
              {avalanche ? (
                <Line label={`Avalanche: debt free ${fmtMonth(avalanche.date)}`} value={avalanche.totalInterest} color={colors.primary} />
              ) : null}
              {snowball ? (
                <Line label={`Snowball: debt free ${fmtMonth(snowball.date)}`} value={snowball.totalInterest} color={colors.warning} />
              ) : null}
              <Text style={styles.projNote}>
                Amounts are total interest paid along the way, assuming your minimum
                payments continue.{interestSaved > 0 ? ` Avalanche saves you ${formatMoney(interestSaved)} in interest.` : ''} Every
                extra peso toward the focus debt moves the date closer.
              </Text>
            </>
          )}
        </View>

        <Text style={styles.footnote}>
          Financial position is as of today. Income and cash flow cover {monthLabel()} only.
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
    proBadge: { color: colors.celebrate, fontWeight: fontWeight.heavy },
    projNote: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.md },
  });
}
