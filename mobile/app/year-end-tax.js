// Year-end tax check for employees: am I getting a refund, or do I still owe?
// Every December an employer trues up the whole year's tax, and steady monthly
// withholding rarely matches the real annual tax once a 13th month, bonuses, a
// raise, or a mid-year start are counted. This estimates the annual tax due and
// compares it to what was already withheld. All math is in lib/phtax.js (pure
// and tested). This is an estimate, not your Form 2316, and the screen says so.

import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { formatMoney } from '../lib/format';
import { annualizeCompensation, BONUS_TAX_FREE_CEILING, RATES_YEAR } from '../lib/phtax';

export default function YearEndTax() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();

  const [basic, setBasic] = useState('');
  const [allowance, setAllowance] = useState('');
  const [monthsWorked, setMonthsWorked] = useState('');
  const [bonuses, setBonuses] = useState('');
  const [withheld, setWithheld] = useState('');

  const parse = (s) => Number(String(s).replace(/[, ]/g, '')) || 0;
  const basicNum = parse(basic);
  const allowanceNum = parse(allowance);
  const monthsNum = monthsWorked === '' ? 12 : parse(monthsWorked);
  const bonusesNum = parse(bonuses);
  const withheldNum = parse(withheld);

  const r = useMemo(
    () =>
      annualizeCompensation(basicNum, {
        taxableAllowance: allowanceNum,
        monthsWorked: monthsNum,
        bonuses: bonusesNum,
        taxWithheld: withheldNum,
      }),
    [basicNum, allowanceNum, monthsNum, bonusesNum, withheldNum]
  );
  const m = (n) => formatMoney(Math.round(n));

  const ready = basicNum > 0;
  // Round before deciding the verdict so a sub-peso gap reads as settled, not a
  // stray one peso refund or shortfall.
  const gap = Math.round(r.difference);
  const settled = gap === 0;
  const refund = gap > 0;

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>Year-end tax check</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={styles.intro}>
          At year end your employer adds up your whole year and settles the tax. If too much was taken from your payslips you get a refund, if too little you pay the small difference. See roughly which way you are heading.
        </Text>

        <Text style={styles.fieldLabel}>Monthly basic pay</Text>
        <View style={styles.inputWrap}>
          <Text style={styles.peso}>₱</Text>
          <TextInput style={styles.input} value={basic} onChangeText={setBasic} keyboardType="numeric" placeholder="e.g. 25,000" placeholderTextColor={colors.faint} autoFocus />
        </View>

        <View style={styles.twoCol}>
          <View style={styles.col}>
            <Text style={styles.fieldLabel}>Monthly taxable allowance</Text>
            <View style={styles.smallInputWrap}>
              <Text style={styles.pesoSm}>₱</Text>
              <TextInput style={styles.smallInput} value={allowance} onChangeText={setAllowance} keyboardType="numeric" placeholder="0" placeholderTextColor={colors.faint} />
            </View>
          </View>
          <View style={styles.col}>
            <Text style={styles.fieldLabel}>Months worked this year</Text>
            <View style={styles.smallInputWrap}>
              <TextInput style={styles.smallInput} value={monthsWorked} onChangeText={setMonthsWorked} keyboardType="numeric" placeholder="12" placeholderTextColor={colors.faint} />
            </View>
          </View>
        </View>

        <Text style={[styles.fieldLabel, { marginTop: spacing.lg }]}>13th month plus bonuses this year</Text>
        <View style={styles.inputWrap}>
          <Text style={styles.peso}>₱</Text>
          <TextInput style={styles.input} value={bonuses} onChangeText={setBonuses} keyboardType="numeric" placeholder="e.g. 25,000" placeholderTextColor={colors.faint} />
        </View>
        <Text style={styles.subHint}>The first {m(BONUS_TAX_FREE_CEILING)} of your 13th month and other bonuses combined is tax free. Only the excess is taxed.</Text>

        <Text style={[styles.fieldLabel, { marginTop: spacing.lg }]}>Income tax withheld so far</Text>
        <View style={styles.inputWrap}>
          <Text style={styles.peso}>₱</Text>
          <TextInput style={styles.input} value={withheld} onChangeText={setWithheld} keyboardType="numeric" placeholder="Total for the year" placeholderTextColor={colors.faint} />
        </View>
        <Text style={styles.subHint}>Add up the tax taken from each payslip this year, or read it from your latest payslip year to date. Your Form 2316 shows the final figure.</Text>

        {ready ? (
          <>
            <View style={[styles.card, refund ? styles.cardGood : settled ? styles.cardNeutral : styles.cardOwe]}>
              <Text style={styles.amtLabel}>
                {settled ? 'You are about even' : refund ? 'Estimated refund' : 'You may still owe about'}
              </Text>
              <Text style={[styles.amtValue, refund ? styles.good : settled ? styles.neutral : styles.owe]}>
                {settled ? m(0) : m(Math.abs(r.difference))}
              </Text>
              <Text style={styles.amtNote}>
                {settled
                  ? 'What was withheld matches your estimated tax for the year, so expect little or no adjustment.'
                  : refund
                    ? 'More was withheld than your estimated tax for the year, so you should get the difference back.'
                    : 'Less was withheld than your estimated tax, so a small amount may be deducted at year end.'}
              </Text>
            </View>

            <View style={styles.breakdownCard}>
              <View style={styles.row}>
                <Text style={styles.rowLabel}>Taxable income for the year</Text>
                <Text style={styles.rowValue}>{m(r.annualTaxable)}</Text>
              </View>
              {r.bonusTaxable > 0 ? (
                <View style={styles.row}>
                  <Text style={styles.rowLabel}>Includes taxable part of bonuses</Text>
                  <Text style={styles.rowSubtle}>{m(r.bonusTaxable)}</Text>
                </View>
              ) : null}
              <View style={styles.row}>
                <Text style={styles.rowLabel}>Tax due for the year</Text>
                <Text style={styles.rowValue}>{m(r.annualTaxDue)}</Text>
              </View>
              <View style={styles.row}>
                <Text style={styles.rowLabel}>Tax already withheld</Text>
                <Text style={styles.rowValue}>{m(r.taxWithheld)}</Text>
              </View>
              <View style={styles.netRow}>
                <Text style={styles.netLabel}>{refund ? 'Refund to you' : settled ? 'Difference' : 'Still to pay'}</Text>
                <Text style={[styles.netValue, refund ? styles.good : settled ? styles.neutral : styles.owe]}>
                  {settled ? m(0) : m(Math.abs(r.difference))}
                </Text>
              </View>
              <View style={styles.rateRow}>
                <Text style={styles.rateText}>Effective tax rate about {r.effectiveRate}% of what you earned this year.</Text>
              </View>
            </View>

            <View style={styles.infoCard}>
              <Text style={styles.infoKicker}>GOOD TO KNOW</Text>
              <Text style={styles.infoLine}>
                Most employees do not file this themselves. Your employer does the year-end adjustment and a refund usually shows up in your December or January pay. This just tells you what to expect.
              </Text>
              <Text style={styles.infoLine}>
                If you changed jobs this year, give your new employer your Form 2316 from the old one so they annualize correctly, otherwise you can be under-withheld.
              </Text>
            </View>
          </>
        ) : (
          <Text style={styles.hint}>Enter your monthly basic pay to see your year-end estimate.</Text>
        )}

        <Text style={styles.disclaimer}>
          Estimate based on {RATES_YEAR} BIR rules (TRAIN graduated table, the {m(BONUS_TAX_FREE_CEILING)} tax-free ceiling for 13th month and bonuses, and mandatory contributions figured on basic pay). It assumes a steady salary and that this job is your only income. Your real refund depends on your exact payslips, allowances, and any de minimis benefits. Not a substitute for your Form 2316 or an accountant.
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

    twoCol: { flexDirection: 'row', gap: spacing.md, marginTop: spacing.lg },
    col: { flex: 1 },
    smallInputWrap: { flexDirection: 'row', alignItems: 'center', backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md },
    pesoSm: { color: colors.muted, fontSize: fontSize.body, marginRight: spacing.xs },
    smallInput: { flex: 1, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },

    card: { borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginTop: spacing.xl },
    cardGood: { backgroundColor: colors.card, borderColor: colors.primary },
    cardNeutral: { backgroundColor: colors.card, borderColor: colors.border },
    cardOwe: { backgroundColor: colors.card, borderColor: colors.border },
    amtLabel: { color: colors.muted, fontSize: fontSize.caption, letterSpacing: 0.3 },
    amtValue: { fontSize: fontSize.huge, fontWeight: fontWeight.heavy, marginTop: 2 },
    amtNote: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 18, marginTop: spacing.sm },
    good: { color: colors.primary },
    neutral: { color: colors.text },
    owe: { color: colors.warning || colors.text },

    breakdownCard: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginTop: spacing.md },
    row: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: spacing.sm },
    rowLabel: { color: colors.muted, fontSize: fontSize.small, flexShrink: 1, paddingRight: spacing.md },
    rowValue: { color: colors.text, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    rowSubtle: { color: colors.textSecondary, fontSize: fontSize.small },
    netRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', borderTopColor: colors.border, borderTopWidth: 1, marginTop: spacing.sm, paddingTop: spacing.md },
    netLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    netValue: { fontSize: fontSize.subtitle, fontWeight: fontWeight.heavy },
    rateRow: { borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth, marginTop: spacing.sm, paddingTop: spacing.md },
    rateText: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 18 },

    infoCard: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginTop: spacing.md },
    infoKicker: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1.2, marginBottom: spacing.sm },
    infoLine: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 19, marginTop: spacing.xs },

    hint: { color: colors.muted, fontSize: fontSize.body, textAlign: 'center', marginTop: spacing.xl, marginBottom: spacing.xl },
    disclaimer: { color: colors.faint, fontSize: fontSize.caption, lineHeight: 17, marginTop: spacing.xl },
  });
}
