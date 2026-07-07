// Income tax calculator for the self-employed, freelancers, and professionals.
// It answers the one question that actually saves them money: the flat 8% on
// gross, or the graduated table plus the 3% percentage tax? It computes both
// and points to the cheaper one. All math is in lib/phtax.js (pure and tested).
// This is an estimate from published rates, not a BIR filing, and it says so.

import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { formatMoney } from '../lib/format';
import { selfEmployedTax, VAT_THRESHOLD, RATES_YEAR } from '../lib/phtax';

export default function TaxCalculator() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();

  const [gross, setGross] = useState('');
  const [mixedIncome, setMixedIncome] = useState(false);
  const [salaryTaxable, setSalaryTaxable] = useState('');
  const [useOSD, setUseOSD] = useState(true);
  const [expenses, setExpenses] = useState('');

  const parse = (s) => Number(String(s).replace(/[, ]/g, '')) || 0;
  const grossNum = parse(gross);
  const expensesNum = parse(expenses);
  const salaryNum = parse(salaryTaxable);
  const r = useMemo(
    () => selfEmployedTax(grossNum, { mixedIncome, useOSD, expenses: expensesNum, salaryTaxable: salaryNum }),
    [grossNum, mixedIncome, useOSD, expensesNum, salaryNum]
  );
  const m = (n) => formatMoney(Math.round(n));

  const eightWins = r.recommended === 'eight';
  // Only claim one option is cheaper when the gap is a real peso or more and we
  // could actually compare both (a mixed earner needs a salary to compare).
  const meaningful = r.canCompareGraduated && r.savings >= 1;
  const chosenTotal = eightWins ? r.eightPercent.total : r.graduated.total;

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>Income tax</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={styles.intro}>
          For freelancers, professionals, and small businesses. Enter your yearly income and see whether the flat 8% or the graduated rate costs you less.
        </Text>

        <Text style={styles.fieldLabel}>Yearly gross income</Text>
        <View style={styles.inputWrap}>
          <Text style={styles.peso}>₱</Text>
          <TextInput
            style={styles.input}
            value={gross}
            onChangeText={setGross}
            keyboardType="numeric"
            placeholder="e.g. 600,000"
            placeholderTextColor={colors.faint}
            autoFocus
          />
        </View>
        {grossNum > 0 ? (
          <Text style={styles.subHint}>About {m(grossNum / 12)} a month in sales or fees.</Text>
        ) : null}

        <Pressable style={styles.toggleRow} onPress={() => setMixedIncome((v) => !v)}>
          <View style={{ flex: 1 }}>
            <Text style={styles.toggleTitle}>I also earn a salary</Text>
            <Text style={styles.toggleDesc}>Mixed income. The 250,000 tax-free part is used by your salary, so the whole business income is taxed.</Text>
          </View>
          <View style={[styles.check, mixedIncome && styles.checkOn]}>
            {mixedIncome ? <Ionicons name="checkmark" size={16} color={colors.background} /> : null}
          </View>
        </Pressable>

        {mixedIncome ? (
          <View style={{ marginTop: spacing.md }}>
            <Text style={styles.fieldLabel}>Your yearly taxable salary</Text>
            <View style={styles.inputWrap}>
              <Text style={styles.peso}>₱</Text>
              <TextInput
                style={styles.input}
                value={salaryTaxable}
                onChangeText={setSalaryTaxable}
                keyboardType="numeric"
                placeholder="e.g. 400,000"
                placeholderTextColor={colors.faint}
              />
            </View>
            <Text style={styles.subHint}>Roughly your yearly basic pay minus SSS, PhilHealth, and Pag-IBIG. The take-home pay tool shows this. Needed to compare the graduated option fairly.</Text>
          </View>
        ) : null}

        <Text style={[styles.fieldLabel, { marginTop: spacing.lg }]}>Deductions for the graduated option</Text>
        <View style={styles.segment}>
          <Pressable style={[styles.segBtn, useOSD && styles.segBtnOn]} onPress={() => setUseOSD(true)}>
            <Text style={[styles.segText, useOSD && styles.segTextOn]}>40% standard</Text>
          </Pressable>
          <Pressable style={[styles.segBtn, !useOSD && styles.segBtnOn]} onPress={() => setUseOSD(false)}>
            <Text style={[styles.segText, !useOSD && styles.segTextOn]}>My expenses</Text>
          </Pressable>
        </View>
        {!useOSD ? (
          <View style={[styles.inputWrap, { marginTop: spacing.md }]}>
            <Text style={styles.peso}>₱</Text>
            <TextInput
              style={styles.input}
              value={expenses}
              onChangeText={setExpenses}
              keyboardType="numeric"
              placeholder="Yearly expenses"
              placeholderTextColor={colors.faint}
            />
          </View>
        ) : (
          <Text style={styles.subHint}>The 40% standard deduction (OSD) needs no receipts. Pick My expenses if your real costs are higher.</Text>
        )}

        {grossNum > 0 ? (
          <>
            {!r.eligible8 ? (
              <View style={[styles.pickCard, styles.pickGrad]}>
                <Text style={styles.pickKicker}>HEADS UP</Text>
                <Text style={styles.pickTitle}>Over {m(VAT_THRESHOLD)} a year</Text>
                <Text style={styles.pickSave}>
                  The flat 8% is only for income of {m(VAT_THRESHOLD)} or less. Above it you register for VAT (12%), so this graduated figure is a rough floor, not the full picture. Talk to an accountant.
                </Text>
              </View>
            ) : !r.canCompareGraduated ? (
              <View style={[styles.pickCard, styles.pickEight]}>
                <Text style={styles.pickKicker}>OUR PICK</Text>
                <Text style={styles.pickTitle}>Take the flat 8%</Text>
                <Text style={styles.pickSave}>
                  One simple tax, no receipts. To compare the graduated route fairly we need your yearly taxable salary, so add it above if you want to check both.
                </Text>
              </View>
            ) : (
              <View style={[styles.pickCard, eightWins ? styles.pickEight : styles.pickGrad]}>
                <Text style={styles.pickKicker}>OUR PICK</Text>
                <Text style={styles.pickTitle}>
                  {!meaningful ? 'Either option works' : eightWins ? 'Take the flat 8%' : 'Use the graduated rate'}
                </Text>
                <Text style={styles.pickSave}>
                  {meaningful
                    ? `Saves you about ${m(r.savings)} a year versus the other option.`
                    : 'Both options cost about the same this year, so pick whichever is simpler for you.'}
                </Text>
              </View>
            )}

            {r.eligible8 ? (
              <View style={[styles.optCard, eightWins && meaningful && styles.optCardWin]}>
                <View style={styles.optHead}>
                  <Text style={styles.optTitle}>Flat 8% option</Text>
                  {eightWins && meaningful ? <Text style={styles.winTag}>LOWER</Text> : null}
                </View>
                <View style={styles.row}>
                  <Text style={styles.rowLabel}>{r.mixedIncome ? '8% on all business income' : '8% on income over ' + m(250000)}</Text>
                  <Text style={styles.rowValue}>{m(r.eightPercent.total)}</Text>
                </View>
                <View style={styles.totalRow}>
                  <Text style={styles.totalLabel}>Total tax</Text>
                  <Text style={styles.totalValue}>{m(r.eightPercent.total)}</Text>
                </View>
                <Text style={styles.optNote}>
                  {r.mixedIncome
                    ? 'This is the tax on your business income only. Your salary is taxed separately by your employer. One flat tax, no expense receipts.'
                    : 'One flat tax. It covers both income tax and the percentage tax, and needs no expense receipts.'}
                </Text>
              </View>
            ) : null}

            {r.canCompareGraduated ? (
              <View style={[styles.optCard, !eightWins && meaningful && styles.optCardWin]}>
                <View style={styles.optHead}>
                  <Text style={styles.optTitle}>Graduated option</Text>
                  {!eightWins && meaningful ? <Text style={styles.winTag}>LOWER</Text> : null}
                </View>
                <View style={styles.row}>
                  <Text style={styles.rowLabel}>{useOSD ? '40% standard deduction' : 'Your expenses'}</Text>
                  <Text style={styles.rowSubtle}>- {m(r.graduated.deduction)}</Text>
                </View>
                <View style={styles.row}>
                  <Text style={styles.rowLabel}>Net taxable income</Text>
                  <Text style={styles.rowSubtle}>{m(r.graduated.net)}</Text>
                </View>
                {r.mixedIncome ? (
                  <View style={styles.row}>
                    <Text style={styles.rowLabel}>Taxed on top of your salary</Text>
                    <Text style={styles.rowSubtle}>{m(salaryNum)}</Text>
                  </View>
                ) : null}
                <View style={[styles.row, styles.rowBorder]}>
                  <Text style={styles.rowLabel}>{r.mixedIncome ? 'Extra income tax (graduated)' : 'Income tax (graduated)'}</Text>
                  <Text style={styles.rowValue}>{m(r.graduated.incomeTax)}</Text>
                </View>
                {r.graduated.percentageTax > 0 ? (
                  <View style={styles.row}>
                    <Text style={styles.rowLabel}>Percentage tax (3%)</Text>
                    <Text style={styles.rowValue}>{m(r.graduated.percentageTax)}</Text>
                  </View>
                ) : null}
                <View style={styles.totalRow}>
                  <Text style={styles.totalLabel}>Total tax</Text>
                  <Text style={styles.totalValue}>{m(r.graduated.total)}</Text>
                </View>
                <Text style={styles.optNote}>
                  {r.graduated.percentageTax > 0
                    ? 'Graduated income tax on your net, plus a separate 3% tax on your whole gross.'
                    : 'Graduated income tax on your net. Above the VAT threshold the 3% tax is replaced by 12% VAT, which this tool does not compute.'}
                </Text>
              </View>
            ) : null}

            <View style={styles.setAside}>
              <Text style={styles.setAsideText}>
                On your pick, set aside about {m(chosenTotal / 12)} a month so the tax is ready when it is due.
              </Text>
            </View>
          </>
        ) : (
          <Text style={styles.hint}>Enter your yearly gross income to compare the two options.</Text>
        )}

        <Text style={styles.disclaimer}>
          Estimate based on {RATES_YEAR} BIR rates: the graduated income tax table, the 8% option, and the 3% percentage tax for non-VAT taxpayers. The 8% must be chosen with the BIR on time (at registration or the first quarter return) and it is locked in for the whole year. This is a guide, not a tax filing or professional advice.
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
    inputWrap: { flexDirection: 'row', alignItems: 'center', backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.lg },
    peso: { color: colors.muted, fontSize: fontSize.title, fontWeight: fontWeight.bold, marginRight: spacing.sm },
    input: { flex: 1, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.bold },
    subHint: { color: colors.faint, fontSize: fontSize.caption, lineHeight: 16, marginTop: spacing.sm },

    toggleRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, marginTop: spacing.lg },
    toggleTitle: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    toggleDesc: { color: colors.muted, fontSize: fontSize.caption, lineHeight: 16, marginTop: 2 },
    check: { width: 26, height: 26, borderRadius: radius.sm, borderWidth: 1.5, borderColor: colors.border, alignItems: 'center', justifyContent: 'center' },
    checkOn: { backgroundColor: colors.primary, borderColor: colors.primary },

    segment: { flexDirection: 'row', backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, padding: 3 },
    segBtn: { flex: 1, paddingVertical: spacing.sm, alignItems: 'center', borderRadius: radius.sm },
    segBtnOn: { backgroundColor: colors.primary },
    segText: { color: colors.muted, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    segTextOn: { color: colors.background, fontWeight: fontWeight.bold },

    pickCard: { borderRadius: radius.lg, padding: spacing.lg, marginTop: spacing.xl, borderWidth: 1 },
    pickEight: { backgroundColor: colors.card, borderColor: colors.primary },
    pickGrad: { backgroundColor: colors.card, borderColor: colors.border },
    pickKicker: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1.2 },
    pickTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.heavy, marginTop: 4 },
    pickSave: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 19, marginTop: spacing.sm },

    optCard: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginTop: spacing.md },
    optCardWin: { borderColor: colors.primary },
    optHead: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.sm },
    optTitle: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    winTag: { color: colors.primary, fontSize: 10, fontWeight: fontWeight.bold, letterSpacing: 1, borderColor: colors.primary, borderWidth: 1, borderRadius: radius.sm, paddingHorizontal: 6, paddingVertical: 1 },
    row: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: spacing.sm },
    rowBorder: { borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth, paddingTop: spacing.md },
    rowLabel: { color: colors.muted, fontSize: fontSize.small, flexShrink: 1, paddingRight: spacing.md },
    rowValue: { color: colors.text, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    rowSubtle: { color: colors.textSecondary, fontSize: fontSize.small },
    totalRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', borderTopColor: colors.border, borderTopWidth: 1, marginTop: spacing.sm, paddingTop: spacing.md },
    totalLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    totalValue: { color: colors.primary, fontSize: fontSize.subtitle, fontWeight: fontWeight.heavy },
    optNote: { color: colors.faint, fontSize: fontSize.caption, lineHeight: 16, marginTop: spacing.sm },

    setAside: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginTop: spacing.md },
    setAsideText: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 19 },

    hint: { color: colors.muted, fontSize: fontSize.body, textAlign: 'center', marginTop: spacing.xl, marginBottom: spacing.xl },
    disclaimer: { color: colors.faint, fontSize: fontSize.caption, lineHeight: 17, marginTop: spacing.xl },
  });
}
