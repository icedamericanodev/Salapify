// 13th month pay calculator. Shows what a rank-and-file employee should receive
// (total basic earned this year over 12), prorated for a partial year, and how
// the 90,000 tax-free ceiling applies. All math is in lib/thirteenth.js (pure
// and tested). This is an estimate, not your payslip, and the screen says so.

import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { formatMoney } from '../lib/format';
import { thirteenthMonth, THIRTEENTH_TAX_FREE_CEILING } from '../lib/thirteenth';
import { RATES_YEAR } from '../lib/phtax';

export default function ThirteenthCalculator() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();

  const [basic, setBasic] = useState('');
  const [monthsWorked, setMonthsWorked] = useState('');
  const [otherBenefits, setOtherBenefits] = useState('');

  const parse = (s) => Number(String(s).replace(/[, ]/g, '')) || 0;
  const basicNum = parse(basic);
  const monthsNum = monthsWorked === '' ? 12 : parse(monthsWorked);
  const otherNum = parse(otherBenefits);

  const r = useMemo(
    () => thirteenthMonth(basicNum, { monthsWorked: monthsNum, otherBenefits: otherNum }),
    [basicNum, monthsNum, otherNum]
  );
  const m = (n) => formatMoney(Math.round(n));

  const ready = basicNum > 0;
  const taxed = r.taxable > 0;

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>13th month pay</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={styles.intro}>
          Every rank-and-file employee who worked at least a month this year should receive 13th month pay, on or before 24 December. It is your basic salary for the year divided by 12.
        </Text>

        <Text style={styles.fieldLabel}>Monthly basic pay</Text>
        <View style={styles.inputWrap}>
          <Text style={styles.peso}>₱</Text>
          <TextInput style={styles.input} value={basic} onChangeText={setBasic} keyboardType="numeric" placeholder="e.g. 25,000" placeholderTextColor={colors.faint} autoFocus />
        </View>

        <View style={styles.twoCol}>
          <View style={styles.col}>
            <Text style={styles.fieldLabel}>Months worked this year</Text>
            <View style={styles.smallInputWrap}>
              <TextInput style={styles.smallInput} value={monthsWorked} onChangeText={setMonthsWorked} keyboardType="numeric" placeholder="12" placeholderTextColor={colors.faint} />
            </View>
          </View>
          <View style={styles.col}>
            <Text style={styles.fieldLabel}>Other bonuses this year</Text>
            <View style={styles.smallInputWrap}>
              <Text style={styles.pesoSm}>₱</Text>
              <TextInput style={styles.smallInput} value={otherBenefits} onChangeText={setOtherBenefits} keyboardType="numeric" placeholder="0" placeholderTextColor={colors.faint} />
            </View>
          </View>
        </View>
        <Text style={styles.subHint}>
          Only basic pay counts, not overtime, allowances, or holiday pay. Other bonuses matter only for the {m(THIRTEENTH_TAX_FREE_CEILING)} tax-free ceiling.
        </Text>

        {ready ? (
          <>
            <View style={styles.card}>
              <View style={styles.amtHead}>
                <Text style={styles.amtLabel}>Your 13th month pay</Text>
                {!taxed ? <Text style={styles.freeTag}>TAX FREE</Text> : null}
              </View>
              <Text style={styles.amtValue}>{m(r.amount)}</Text>
              {r.monthsWorked < 12 ? (
                <Text style={styles.amtNote}>Prorated for {r.monthsWorked} {r.monthsWorked === 1 ? 'month' : 'months'} worked this year.</Text>
              ) : null}

              {taxed ? (
                <View style={styles.breakdown}>
                  <View style={styles.row}>
                    <Text style={styles.rowLabel}>Tax free part</Text>
                    <Text style={styles.rowValue}>{m(r.taxFreePortion)}</Text>
                  </View>
                  <View style={styles.row}>
                    <Text style={styles.rowLabel}>Taxable part</Text>
                    <Text style={styles.rowValue}>{m(r.taxable)}</Text>
                  </View>
                  <View style={styles.row}>
                    <Text style={styles.rowLabel}>Estimated tax on the excess</Text>
                    <Text style={styles.rowValue}>- {m(r.taxOnExcess)}</Text>
                  </View>
                  <View style={styles.netRow}>
                    <Text style={styles.netLabel}>You take home about</Text>
                    <Text style={styles.netValue}>{m(r.net)}</Text>
                  </View>
                </View>
              ) : null}
            </View>

            <View style={styles.infoCard}>
              <Text style={styles.infoKicker}>GOOD TO KNOW</Text>
              <Text style={styles.infoLine}>
                {taxed
                  ? `The first ${m(THIRTEENTH_TAX_FREE_CEILING)} of your 13th month pay and other bonuses combined is tax free. Only the amount above that is taxed, at your income tax rate, which is why the tax here is an estimate.`
                  : `Your 13th month pay is within the ${m(THIRTEENTH_TAX_FREE_CEILING)} tax-free ceiling for 13th month pay and other bonuses combined, so no tax is taken.`}
              </Text>
              <Text style={styles.infoLine}>
                It must be paid on or before 24 December. It is separate from any 14th month or performance bonus your employer chooses to give.
              </Text>
            </View>
          </>
        ) : (
          <Text style={styles.hint}>Enter your monthly basic pay to see your 13th month pay.</Text>
        )}

        <Text style={styles.disclaimer}>
          Estimate based on {RATES_YEAR} rules (PD 851 and the {m(THIRTEENTH_TAX_FREE_CEILING)} TRAIN tax-free ceiling). It assumes a steady basic salary and counts basic pay only. Your actual 13th month can differ if your pay changed during the year or your company integrates other pay. Not a substitute for your payslip.
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
    smallInputWrap: { flexDirection: 'row', alignItems: 'center', backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md },
    pesoSm: { color: colors.muted, fontSize: fontSize.body, marginRight: spacing.xs },
    smallInput: { flex: 1, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    subHint: { color: colors.faint, fontSize: fontSize.caption, lineHeight: 16, marginTop: spacing.sm },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginTop: spacing.xl },
    amtHead: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
    amtLabel: { color: colors.muted, fontSize: fontSize.caption, letterSpacing: 0.3 },
    freeTag: { color: colors.primary, fontSize: 10, fontWeight: fontWeight.bold, letterSpacing: 1, borderColor: colors.primary, borderWidth: 1, borderRadius: radius.sm, paddingHorizontal: 6, paddingVertical: 1 },
    amtValue: { color: colors.primary, fontSize: fontSize.huge, fontWeight: fontWeight.heavy, marginTop: 2 },
    amtNote: { color: colors.faint, fontSize: fontSize.caption, marginTop: spacing.xs },

    breakdown: { borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth, marginTop: spacing.md, paddingTop: spacing.sm },
    row: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: spacing.sm },
    rowLabel: { color: colors.muted, fontSize: fontSize.small, flexShrink: 1, paddingRight: spacing.md },
    rowValue: { color: colors.textSecondary, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    netRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', borderTopColor: colors.border, borderTopWidth: 1, marginTop: spacing.sm, paddingTop: spacing.md },
    netLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    netValue: { color: colors.primary, fontSize: fontSize.subtitle, fontWeight: fontWeight.heavy },

    infoCard: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginTop: spacing.md },
    infoKicker: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1.2, marginBottom: spacing.sm },
    infoLine: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 19, marginTop: spacing.xs },

    hint: { color: colors.muted, fontSize: fontSize.body, textAlign: 'center', marginTop: spacing.xl, marginBottom: spacing.xl },
    disclaimer: { color: colors.faint, fontSize: fontSize.caption, lineHeight: 17, marginTop: spacing.xl },
  });
}
