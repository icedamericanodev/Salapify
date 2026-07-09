// Reports: three proper personal financial statements built from your data.
//  - Balance Sheet: Assets = Liabilities + Equity, split current vs long term.
//  - Income Statement: income earned minus expenses (with interest called out).
//  - Cash Flow: operating, investing, and financing, reconciled to the cash that
//    actually moved through your accounts this month.
// Plus the Pro debt free plan. Reached from the More tab. Read-only summaries.

import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';
import { formatMoney, monthLabel } from '../lib/format';
import { debtFreeProjection } from '../lib/analytics';
import { balanceSheet, incomeStatement, cashFlowStatement } from '../lib/statements';

const MONTHS_FULL = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const fmtMonth = (d) => `${MONTHS_FULL[d.getMonth()]} ${d.getFullYear()}`;

export default function Reports() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data } = useAppData();
  const pro = !!(data.settings && data.settings.pro);
  const hasDebts = (data.debts || []).some((d) => d && d.remaining > 0);
  // The strategies only differ when there is EXTRA money beyond minimums
  // (that is what avalanche and snowball allocate differently). With no
  // extra, showing two identical lines as a comparison would be fake, so
  // the user types their extra amount and the plan responds honestly.
  const [extraText, setExtraText] = useState('');
  const extra = Math.max(0, Number(String(extraText).replace(/[, ]/g, '')) || 0);
  const avalanche = pro && hasDebts ? debtFreeProjection(data.debts, 'avalanche', extra) : null;
  const snowball = pro && hasDebts ? debtFreeProjection(data.debts, 'snowball', extra) : null;
  const interestSaved = avalanche && snowball ? snowball.totalInterest - avalanche.totalInterest : 0;

  // All three statements come from the one shared pure module, so the numbers
  // here match Home, Insights, and the regression tests exactly.
  const bs = useMemo(() => balanceSheet(data), [data]);
  const is = useMemo(() => incomeStatement(data), [data]);
  const cf = useMemo(() => cashFlowStatement(data), [data]);

  const Line = ({ label, value, strong, color, indent }) => (
    <View style={[styles.line, indent && styles.lineIndent]}>
      <Text style={[styles.lineLabel, strong && styles.strongLabel, indent && styles.subLabel]}>{label}</Text>
      <Text style={[styles.lineValue, strong && styles.strongValue, indent && styles.subValue, color ? { color } : null]}>
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
        {/* Balance Sheet */}
        <Text style={styles.sectionTitle}>BALANCE SHEET</Text>
        <Text style={styles.sectionSub}>What you own and owe, as of today</Text>
        <View style={styles.card}>
          <Text style={styles.groupLabel}>Assets</Text>
          <Line label="Cash" value={bs.cash} indent />
          <Line label="Savings and bank" value={bs.bank} indent />
          {bs.receivables > 0 ? <Line label="Utang owed to you (tracked)" value={bs.receivables} indent /> : null}
          <Line label="Current assets" value={bs.currentAssets} />
          {bs.longTermAssets > 0 ? <Line label="Investments and things you own" value={bs.longTermAssets} indent /> : null}
          <Line label="Total assets" value={bs.totalAssets} strong color={colors.primary} />

          <View style={styles.divider} />
          <Text style={styles.groupLabel}>Liabilities</Text>
          {bs.shortDebts > 0 ? <Line label="Cards and short term debt" value={bs.shortDebts} indent /> : null}
          {bs.payables > 0 ? <Line label="Utang you owe (tracked)" value={bs.payables} indent /> : null}
          <Line label="Current liabilities" value={bs.currentLiabilities} />
          {bs.longDebts > 0 ? <Line label="Long term loans" value={bs.longDebts} indent /> : null}
          <Line label="Total liabilities" value={bs.totalLiabilities} strong color={colors.warning} />

          <View style={styles.divider} />
          <Text style={styles.groupLabel}>Equity</Text>
          <Line label="Net worth" value={bs.equity} strong color={bs.equity >= 0 ? colors.primary : colors.warning} />
          <Text style={styles.note}>
            Assets {formatMoney(bs.totalAssets)} = Liabilities {formatMoney(bs.totalLiabilities)} + Equity {formatMoney(bs.equity)}.
            {bs.balances ? ' Balanced.' : ' Check your figures.'}
          </Text>
        </View>

        {/* Income Statement */}
        <Text style={styles.sectionTitle}>INCOME STATEMENT</Text>
        <Text style={styles.sectionSub}>What you earned and spent in {monthLabel()}</Text>
        <View style={styles.card}>
          <Line label="Income earned" value={is.income} color={colors.primary} />
          <Line label="Spending" value={is.spendingExpense} indent />
          {is.interestExpense > 0 ? <Line label="Debt interest" value={is.interestExpense} indent /> : null}
          <Line label="Total expenses" value={is.expenses} color={colors.warning} />
          <View style={styles.divider} />
          <Line label="Net income" value={is.netIncome} strong color={is.netIncome >= 0 ? colors.primary : colors.warning} />
          <Text style={styles.note}>
            Money you collected on utang and loans you took are not income, and debt
            principal you paid is not spending, so this line is your true earnings, not
            cash movement. See the cash flow below for that.
          </Text>
        </View>

        {/* Cash Flow */}
        <Text style={styles.sectionTitle}>CASH FLOW</Text>
        <Text style={styles.sectionSub}>Where cash moved in {monthLabel()}</Text>
        <View style={styles.card}>
          <Text style={styles.groupLabel}>Operating (day to day)</Text>
          <Line label="Cash in" value={cf.operating.in} indent />
          <Line label="Cash out" value={cf.operating.out} indent />
          <Line label="Net operating" value={cf.operating.net} color={cf.operating.net >= 0 ? colors.primary : colors.warning} />

          <View style={styles.divider} />
          <Text style={styles.groupLabel}>Investing (things you own)</Text>
          {cf.investing.in === 0 && cf.investing.out === 0 ? (
            <Text style={[styles.subLabel, styles.emptyLine]}>No investing activity this month.</Text>
          ) : (
            <>
              <Line label="Cash in" value={cf.investing.in} indent />
              <Line label="Cash out" value={cf.investing.out} indent />
            </>
          )}
          <Line label="Net investing" value={cf.investing.net} color={cf.investing.net >= 0 ? colors.primary : colors.warning} />

          <View style={styles.divider} />
          <Text style={styles.groupLabel}>Financing (debt and utang)</Text>
          {cf.financing.in === 0 && cf.financing.out === 0 ? (
            <Text style={[styles.subLabel, styles.emptyLine]}>No borrowing, lending, or debt payments this month.</Text>
          ) : (
            <>
              <Line label="Cash in (borrowed, utang collected)" value={cf.financing.in} indent />
              <Line label="Cash out (repaid, lent out)" value={cf.financing.out} indent />
            </>
          )}
          <Line label="Net financing" value={cf.financing.net} color={cf.financing.net >= 0 ? colors.primary : colors.warning} />

          <View style={styles.divider} />
          <Line label="Net change in cash" value={cf.netChange} strong color={cf.netChange >= 0 ? colors.primary : colors.warning} />
          {!cf.reconciles ? (
            <Text style={[styles.note, { color: colors.warning }]}>
              Some cash movement could not be sorted into a section. Editing an account
              balance by hand does not show here, only logged income, spending, and
              payments do.
            </Text>
          ) : null}
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
          ) : (
            <>
              <Text style={styles.extraLabel}>Extra you can pay per month, beyond the minimums</Text>
              <TextInput
                style={styles.extraInput}
                value={extraText}
                onChangeText={setExtraText}
                placeholder="e.g. 2000"
                placeholderTextColor={colors.faint}
                keyboardType="numeric"
              />
              {avalanche === null && snowball === null ? (
                <Text style={[styles.lineLabel, { color: colors.warning }]}>
                  At the current payments{extra > 0 ? ' plus that extra' : ''}, interest grows
                  faster than you pay, so there is no freedom date yet. Type
                  {extra > 0 ? ' a bigger' : ' an'} extra amount above, even a small one aimed
                  at your highest interest debt changes this fast.
                </Text>
              ) : extra > 0 ? (
                <>
                  {avalanche ? (
                    <Line label={`Avalanche: debt free ${fmtMonth(avalanche.date)}`} value={avalanche.totalInterest} color={colors.primary} />
                  ) : null}
                  {snowball ? (
                    <Line label={`Snowball: debt free ${fmtMonth(snowball.date)}`} value={snowball.totalInterest} color={colors.warning} />
                  ) : null}
                  <Text style={styles.projNote}>
                    Amounts are total interest paid along the way.
                    {interestSaved > 0
                      ? ` With ${formatMoney(extra)} extra monthly, avalanche saves you ${formatMoney(interestSaved)} in interest versus snowball.`
                      : ` With ${formatMoney(extra)} extra monthly, both strategies cost about the same here.`}
                    {' '}These are estimates: they assume rates and minimum payments stay the
                    same, and that when one debt is finished its payment rolls into the next.
                  </Text>
                </>
              ) : (
                <>
                  {avalanche ? (
                    <Line label={`Minimums only: debt free ${fmtMonth(avalanche.date)}`} value={avalanche.totalInterest} color={colors.primary} />
                  ) : null}
                  <Text style={styles.projNote}>
                    That amount is the total interest paid along the way, keeping your total
                    monthly payment the same until every debt is gone. It is an estimate, rates
                    and minimums are assumed to stay the same. Type an extra amount above and
                    the plan shows which strategy, avalanche or snowball, saves you more.
                  </Text>
                </>
              )}
            </>
          )}
        </View>

        <Text style={styles.footnote}>
          Balance sheet is as of today. Income and cash flow cover {monthLabel()} only.
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

    sectionTitle: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.5, marginBottom: 2, marginTop: spacing.md, paddingHorizontal: spacing.xs },
    sectionSub: { color: colors.faint, fontSize: fontSize.small, marginBottom: spacing.sm, paddingHorizontal: spacing.xs },
    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.xl, marginBottom: spacing.lg },
    groupLabel: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1, marginBottom: spacing.sm },
    line: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: spacing.sm },
    lineIndent: { paddingVertical: spacing.xs },
    lineLabel: { color: colors.textSecondary, fontSize: fontSize.body },
    lineValue: { color: colors.text, fontSize: fontSize.body },
    subLabel: { color: colors.muted, fontSize: fontSize.small, paddingLeft: spacing.md },
    subValue: { color: colors.muted, fontSize: fontSize.small },
    emptyLine: { paddingVertical: spacing.xs },
    strongLabel: { color: colors.text, fontWeight: fontWeight.bold },
    strongValue: { fontWeight: fontWeight.bold, fontSize: fontSize.subtitle },
    divider: { height: StyleSheet.hairlineWidth, backgroundColor: colors.border, marginVertical: spacing.sm },
    footnote: { color: colors.faint, fontSize: fontSize.small, textAlign: 'center', marginTop: spacing.sm },
    note: { color: colors.faint, fontSize: fontSize.small, marginTop: spacing.sm, lineHeight: 18 },
    proBadge: { color: colors.celebrate, fontWeight: fontWeight.heavy },
    projNote: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.md },
    extraLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs },
    extraInput: { backgroundColor: colors.background, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.sm, color: colors.text, fontSize: fontSize.body, marginBottom: spacing.md },
  });
}
