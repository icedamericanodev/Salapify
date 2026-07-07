// Loan and amortization calculator. Shows the real monthly payment, the total
// interest, and, most importantly, the TRUE effective rate, so a low "add-on"
// quote cannot hide how much a loan really costs. All math is in lib/loan.js
// (pure and tested). This is an estimate from the numbers you enter, not a loan
// offer, and the screen says so.

import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { formatMoney } from '../lib/format';
import { loanSummary } from '../lib/loan';

export default function LoanCalculator() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();

  const [amount, setAmount] = useState('');
  const [term, setTerm] = useState('');
  const [termUnit, setTermUnit] = useState('months'); // 'months' | 'years'
  const [rate, setRate] = useState('');
  const [rateBasis, setRateBasis] = useState('monthly'); // 'monthly' | 'annual'
  const [method, setMethod] = useState('diminishing'); // 'diminishing' | 'addon'
  const [showSchedule, setShowSchedule] = useState(false);

  const parse = (s) => Number(String(s).replace(/[, ]/g, '')) || 0;
  const amountNum = parse(amount);
  const termNum = parse(term);
  const rateNum = parse(rate);
  const months = termUnit === 'years' ? Math.round(termNum * 12) : Math.round(termNum);

  const r = useMemo(
    () => loanSummary(amountNum, rateNum, months, { method, rateBasis }),
    [amountNum, rateNum, months, method, rateBasis]
  );
  const m = (n) => formatMoney(Math.round(n));
  const pct = (x) => (x * 100).toFixed(2) + '%';

  const ready = amountNum > 0 && months >= 1 && rateNum >= 0;
  const addon = method === 'addon';

  const Seg = ({ options, value, onChange }) => (
    <View style={styles.segment}>
      {options.map((o) => (
        <Pressable key={o.id} style={[styles.segBtn, value === o.id && styles.segBtnOn]} onPress={() => onChange(o.id)}>
          <Text style={[styles.segText, value === o.id && styles.segTextOn]}>{o.label}</Text>
        </Pressable>
      ))}
    </View>
  );

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>Loan calculator</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={styles.intro}>
          See the real monthly payment and the true cost of a loan. If your lender quoted an add-on rate, this shows what it really works out to.
        </Text>

        <Text style={styles.fieldLabel}>Loan amount</Text>
        <View style={styles.inputWrap}>
          <Text style={styles.peso}>₱</Text>
          <TextInput style={styles.input} value={amount} onChangeText={setAmount} keyboardType="numeric" placeholder="e.g. 100,000" placeholderTextColor={colors.faint} autoFocus />
        </View>

        <View style={styles.twoCol}>
          <View style={styles.col}>
            <Text style={styles.fieldLabel}>Term</Text>
            <View style={styles.smallInputWrap}>
              <TextInput style={styles.smallInput} value={term} onChangeText={setTerm} keyboardType="numeric" placeholder="12" placeholderTextColor={colors.faint} />
            </View>
            <Seg options={[{ id: 'months', label: 'Months' }, { id: 'years', label: 'Years' }]} value={termUnit} onChange={setTermUnit} />
          </View>
          <View style={styles.col}>
            <Text style={styles.fieldLabel}>Interest rate</Text>
            <View style={styles.smallInputWrap}>
              <TextInput style={styles.smallInput} value={rate} onChangeText={setRate} keyboardType="numeric" placeholder="1.5" placeholderTextColor={colors.faint} />
              <Text style={styles.pctSign}>%</Text>
            </View>
            <Seg options={[{ id: 'monthly', label: 'Per month' }, { id: 'annual', label: 'Per year' }]} value={rateBasis} onChange={setRateBasis} />
          </View>
        </View>

        <Text style={[styles.fieldLabel, { marginTop: spacing.lg }]}>How the interest is charged</Text>
        <Seg options={[{ id: 'diminishing', label: 'Diminishing' }, { id: 'addon', label: 'Add-on' }]} value={method} onChange={setMethod} />
        <Text style={styles.methodHint}>
          {addon
            ? 'Add-on charges interest on the full amount for the whole term, even the part you have already paid back. Common in in-house and informal financing, and much costlier than it looks.'
            : 'Diminishing balance charges interest only on what you still owe. This is how banks and most formal lenders compute a loan.'}
        </Text>

        {ready ? (
          <>
            <View style={styles.card}>
              <Text style={styles.payLabel}>Monthly payment</Text>
              <Text style={styles.payValue}>{m(r.payment)}</Text>
              <View style={styles.splitRow}>
                <View style={styles.splitCol}>
                  <Text style={styles.splitLabel}>Total interest</Text>
                  <Text style={styles.splitValue}>{m(r.totalInterest)}</Text>
                </View>
                <View style={styles.splitCol}>
                  <Text style={styles.splitLabel}>Total to pay</Text>
                  <Text style={styles.splitValue}>{m(r.totalPaid)}</Text>
                </View>
              </View>
            </View>

            <View style={[styles.rateCard, addon && styles.rateCardWarn]}>
              <Text style={styles.rateKicker}>TRUE COST</Text>
              <View style={styles.rateRow}>
                <Text style={styles.rateLabel}>Effective interest per year</Text>
                <Text style={[styles.rateValue, addon && styles.rateValueWarn]}>{pct(r.effectiveAnnualRate)}</Text>
              </View>
              <Text style={styles.rateNote}>
                {addon
                  ? `Your ${pct(r.quotedMonthlyRate)} a month add-on really costs about ${pct(r.effectiveMonthlyRate)} a month, or ${pct(r.effectiveAnnualRate)} a year, once you account for paying interest on money you have already returned.`
                  : `This is the yearly rate with monthly compounding. On a diminishing balance the effective rate is close to the quoted rate.`}
              </Text>
            </View>

            <Pressable style={styles.scheduleToggle} onPress={() => setShowSchedule((v) => !v)}>
              <Text style={styles.scheduleToggleText}>{showSchedule ? 'Hide payment schedule' : 'Show payment schedule'}</Text>
              <Ionicons name={showSchedule ? 'chevron-up' : 'chevron-down'} size={16} color={colors.primary} />
            </Pressable>

            {showSchedule ? (
              <View style={styles.scheduleCard}>
                <View style={styles.schHead}>
                  <Text style={[styles.schCol, styles.schNum]}>#</Text>
                  <Text style={[styles.schCol, styles.schAmt]}>Interest</Text>
                  <Text style={[styles.schCol, styles.schAmt]}>Principal</Text>
                  <Text style={[styles.schCol, styles.schAmt]}>Balance</Text>
                </View>
                {r.schedule.map((row) => (
                  <View key={row.period} style={styles.schRow}>
                    <Text style={[styles.schCol, styles.schNum, styles.schMuted]}>{row.period}</Text>
                    <Text style={[styles.schCol, styles.schAmt, styles.schMuted]}>{m(row.interest)}</Text>
                    <Text style={[styles.schCol, styles.schAmt]}>{m(row.principal)}</Text>
                    <Text style={[styles.schCol, styles.schAmt, styles.schMuted]}>{m(row.balance)}</Text>
                  </View>
                ))}
              </View>
            ) : null}
          </>
        ) : (
          <Text style={styles.hint}>Enter the loan amount, term, and interest rate to see the payment and the true cost.</Text>
        )}

        <Text style={styles.disclaimer}>
          An estimate from the numbers you enter. Real loans add fees, insurance, and penalties, and a pre-termination charge can reduce the saving from paying early. This is a guide, not a loan offer. If a lender will not tell you the effective interest rate, that is a warning sign.
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
    intro: { color: colors.muted, fontSize: fontSize.small, lineHeight: 19, marginBottom: spacing.lg },

    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.sm, letterSpacing: 0.3 },
    inputWrap: { flexDirection: 'row', alignItems: 'center', backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.lg, marginBottom: spacing.lg },
    peso: { color: colors.muted, fontSize: fontSize.title, fontWeight: fontWeight.bold, marginRight: spacing.sm },
    input: { flex: 1, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.bold },

    twoCol: { flexDirection: 'row', gap: spacing.md },
    col: { flex: 1 },
    smallInputWrap: { flexDirection: 'row', alignItems: 'center', backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, marginBottom: spacing.sm },
    smallInput: { flex: 1, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    pctSign: { color: colors.muted, fontSize: fontSize.body, fontWeight: fontWeight.bold, marginLeft: spacing.xs },

    segment: { flexDirection: 'row', backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, padding: 3 },
    segBtn: { flex: 1, paddingVertical: spacing.sm, alignItems: 'center', borderRadius: radius.sm },
    segBtnOn: { backgroundColor: colors.primary },
    segText: { color: colors.muted, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    segTextOn: { color: colors.background, fontWeight: fontWeight.bold },
    methodHint: { color: colors.faint, fontSize: fontSize.caption, lineHeight: 16, marginTop: spacing.sm },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginTop: spacing.xl },
    payLabel: { color: colors.muted, fontSize: fontSize.caption, letterSpacing: 0.3 },
    payValue: { color: colors.primary, fontSize: fontSize.huge, fontWeight: fontWeight.heavy, marginTop: 2 },
    splitRow: { flexDirection: 'row', borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth, marginTop: spacing.md, paddingTop: spacing.md },
    splitCol: { flex: 1 },
    splitLabel: { color: colors.muted, fontSize: fontSize.caption },
    splitValue: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold, marginTop: 2 },

    rateCard: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginTop: spacing.md },
    rateCardWarn: { borderColor: colors.warning || colors.primary },
    rateKicker: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1.2 },
    rateRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: spacing.sm },
    rateLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium, flexShrink: 1, paddingRight: spacing.md },
    rateValue: { color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.heavy },
    rateValueWarn: { color: colors.warning || colors.primary },
    rateNote: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 19, marginTop: spacing.sm },

    scheduleToggle: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: spacing.xs, paddingVertical: spacing.md, marginTop: spacing.md },
    scheduleToggleText: { color: colors.primary, fontSize: fontSize.small, fontWeight: fontWeight.bold },
    scheduleCard: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.md },
    schHead: { flexDirection: 'row', borderBottomColor: colors.border, borderBottomWidth: StyleSheet.hairlineWidth, paddingBottom: spacing.sm, marginBottom: spacing.xs },
    schRow: { flexDirection: 'row', paddingVertical: spacing.xs },
    schCol: { fontSize: fontSize.caption },
    schNum: { width: 28, color: colors.text },
    schAmt: { flex: 1, textAlign: 'right', color: colors.text, fontWeight: fontWeight.medium },
    schMuted: { color: colors.muted, fontWeight: fontWeight.regular },

    hint: { color: colors.muted, fontSize: fontSize.body, textAlign: 'center', marginTop: spacing.xl, marginBottom: spacing.xl },
    disclaimer: { color: colors.faint, fontSize: fontSize.caption, lineHeight: 17, marginTop: spacing.xl },
  });
}
