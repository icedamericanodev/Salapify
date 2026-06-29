// Accounts screen. Shows your net worth and your money grouped into sections:
// Cash, Savings and bank, Investments and other assets, and Debts.
// For now it uses sample data. In Phase 2 we will load real data from the
// on-device database. Adding and editing accounts comes in a later step.

import { ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { colors, spacing, radius, fontSize, fontWeight } from '../../theme';
import { formatMoney } from '../../lib/format';
import { sampleAccounts, sampleAssets, sampleDebts } from '../../lib/sampleData';

// One line in a list: an icon, a name, an optional small note, and an amount.
function Row({ icon, name, sub, amount, amountColor }) {
  return (
    <View style={styles.row}>
      <Text style={styles.rowIcon}>{icon}</Text>
      <View style={styles.rowMiddle}>
        <Text style={styles.rowName}>{name}</Text>
        {sub ? <Text style={styles.rowSub}>{sub}</Text> : null}
      </View>
      <Text style={[styles.rowAmount, amountColor ? { color: amountColor } : null]}>
        {amount}
      </Text>
    </View>
  );
}

// A titled group of rows with a subtotal on the right of the title.
function Section({ title, subtotal, subtotalColor, children }) {
  return (
    <View style={styles.section}>
      <View style={styles.sectionHeader}>
        <Text style={styles.sectionTitle}>{title}</Text>
        <Text style={[styles.sectionSubtotal, subtotalColor ? { color: subtotalColor } : null]}>
          {subtotal}
        </Text>
      </View>
      <View style={styles.card}>{children}</View>
    </View>
  );
}

export default function Accounts() {
  // Split the accounts into their groups using the "kind" field.
  const cash = sampleAccounts.filter((a) => a.kind === 'cash');
  const bank = sampleAccounts.filter((a) =>
    ['savings', 'checking', 'ewallet'].includes(a.kind)
  );

  // Add up the numbers we need.
  const sum = (list, key) => list.reduce((total, item) => total + item[key], 0);
  const cashTotal = sum(cash, 'balance');
  const bankTotal = sum(bank, 'balance');
  const assetsValue = sum(sampleAssets, 'value');
  const debtTotal = sum(sampleDebts, 'remaining');

  // Total assets is all account balances plus all asset values.
  const totalAssets = cashTotal + bankTotal + assetsValue;
  // Net worth is what you own minus what you owe.
  const netWorth = totalAssets - debtTotal;

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.pageTitle}>Accounts</Text>

        {/* Top summary card: the headline numbers. */}
        <View style={styles.summaryCard}>
          <Text style={styles.kicker}>NET WORTH</Text>
          <Text style={styles.netWorth}>{formatMoney(netWorth)}</Text>
          <View style={styles.summaryRow}>
            <View>
              <Text style={styles.summaryLabel}>Total assets</Text>
              <Text style={[styles.summaryValue, { color: colors.primary }]}>
                {formatMoney(totalAssets)}
              </Text>
            </View>
            <View>
              <Text style={styles.summaryLabel}>Total debt</Text>
              <Text style={[styles.summaryValue, { color: colors.warning }]}>
                {formatMoney(debtTotal)}
              </Text>
            </View>
          </View>
        </View>

        <Section title="CASH" subtotal={formatMoney(cashTotal)}>
          {cash.map((a) => (
            <Row key={a.id} icon={a.icon} name={a.name} amount={formatMoney(a.balance)} />
          ))}
        </Section>

        <Section title="SAVINGS AND BANK" subtotal={formatMoney(bankTotal)}>
          {bank.map((a) => (
            <Row
              key={a.id}
              icon={a.icon}
              name={a.name}
              sub={a.brand}
              amount={formatMoney(a.balance)}
            />
          ))}
        </Section>

        <Section title="INVESTMENTS AND OTHER ASSETS" subtotal={formatMoney(assetsValue)}>
          {sampleAssets.map((a) => (
            <Row key={a.id} icon="📈" name={a.name} sub={a.kind} amount={formatMoney(a.value)} />
          ))}
        </Section>

        <Section
          title="DEBTS"
          subtotal={formatMoney(debtTotal)}
          subtotalColor={colors.warning}
        >
          {sampleDebts.map((d) => (
            <Row
              key={d.id}
              icon="💳"
              name={d.name}
              sub={`Min ${formatMoney(d.minPayment)} . ${d.monthlyRate}% per month`}
              amount={formatMoney(d.remaining)}
              amountColor={colors.warning}
            />
          ))}
        </Section>

        <Text style={styles.footnote}>
          Sample data for now. Adding and editing accounts comes next.
        </Text>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.lg, paddingBottom: spacing.xxl },
  pageTitle: {
    color: colors.text,
    fontSize: fontSize.title,
    fontWeight: fontWeight.bold,
    marginBottom: spacing.md,
  },

  summaryCard: {
    backgroundColor: colors.card,
    borderColor: colors.border,
    borderWidth: 1,
    borderRadius: radius.lg,
    padding: spacing.xl,
    marginBottom: spacing.xl,
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
  summaryRow: { flexDirection: 'row', justifyContent: 'space-between' },
  summaryLabel: { color: colors.muted, fontSize: fontSize.caption },
  summaryValue: { fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginTop: spacing.xs },

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
  sectionSubtotal: { color: colors.textSecondary, fontSize: fontSize.body, fontWeight: fontWeight.bold },

  card: {
    backgroundColor: colors.card,
    borderColor: colors.border,
    borderWidth: 1,
    borderRadius: radius.lg,
    paddingHorizontal: spacing.lg,
  },
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
  rowAmount: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },

  footnote: {
    color: colors.faint,
    fontSize: fontSize.small,
    textAlign: 'center',
    marginTop: spacing.sm,
  },
});
