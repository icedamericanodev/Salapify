// Contribution checker. For any monthly salary it shows the SSS, PhilHealth,
// and Pag-IBIG contributions: what is deducted from your pay, what your
// employer adds, and the total credited. All math is in lib/phtax.js (pure and
// tested). This is an estimate from published rates, not your payslip.

import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { formatMoney } from '../lib/format';
import { contributionBreakdown, RATES_YEAR } from '../lib/phtax';

export default function ContributionCalculator() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();

  const [salary, setSalary] = useState('');
  const parse = (s) => Number(String(s).replace(/[, ]/g, '')) || 0;
  const salaryNum = parse(salary);
  const r = useMemo(() => contributionBreakdown(salaryNum), [salaryNum]);
  const m = (n) => formatMoney(Math.round(n));

  const ready = salaryNum > 0;

  // Round each line item to whole pesos once, then derive the totals by summing
  // those rounded values. If we rounded the engine's float totals separately,
  // the displayed You total plus Employer total could be a peso off the shown
  // grand total (PhilHealth's identical halves carry the same fraction twice).
  const rows = [
    { key: 'SSS', ee: Math.round(r.sss.employee), er: Math.round(r.sss.employer) },
    { key: 'PhilHealth', ee: Math.round(r.philhealth.employee), er: Math.round(r.philhealth.employer) },
    { key: 'Pag-IBIG', ee: Math.round(r.pagibig.employee), er: Math.round(r.pagibig.employer) },
  ];
  const eeTotal = rows.reduce((s, x) => s + x.ee, 0);
  const erTotal = rows.reduce((s, x) => s + x.er, 0);
  const grandTotal = eeTotal + erTotal;

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>Contribution checker</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={styles.intro}>
          See your monthly SSS, PhilHealth, and Pag-IBIG for any salary: what comes out of your pay, what your employer adds, and the total credited to you.
        </Text>

        <Text style={styles.fieldLabel}>Monthly salary</Text>
        <View style={styles.inputWrap}>
          <Text style={styles.peso}>₱</Text>
          <TextInput style={styles.input} value={salary} onChangeText={setSalary} keyboardType="numeric" placeholder="e.g. 25,000" placeholderTextColor={colors.faint} autoFocus />
        </View>

        {ready ? (
          <>
            <View style={styles.card}>
              <View style={styles.tblHead}>
                <Text style={[styles.thProgram]}>Program</Text>
                <Text style={styles.thAmt}>You</Text>
                <Text style={styles.thAmt}>Employer</Text>
              </View>
              {rows.map((x, i) => (
                <View key={x.key} style={[styles.tblRow, i === 0 && styles.tblRowFirst]}>
                  <Text style={styles.tdProgram}>{x.key}</Text>
                  <Text style={styles.tdAmt}>{m(x.ee)}</Text>
                  <Text style={styles.tdAmtMuted}>{m(x.er)}</Text>
                </View>
              ))}
              <View style={styles.totalRow}>
                <Text style={styles.totalLabel}>Total</Text>
                <Text style={styles.totalAmt}>{m(eeTotal)}</Text>
                <Text style={styles.totalAmtMuted}>{m(erTotal)}</Text>
              </View>
            </View>

            <View style={styles.summaryCard}>
              <View style={styles.sumRow}>
                <Text style={styles.sumLabel}>Deducted from your pay</Text>
                <Text style={styles.sumValue}>{m(eeTotal)}</Text>
              </View>
              <View style={styles.sumRow}>
                <Text style={styles.sumLabelMuted}>Your employer adds</Text>
                <Text style={styles.sumValueMuted}>{m(erTotal)}</Text>
              </View>
              <View style={[styles.sumRow, styles.sumRowTop]}>
                <Text style={styles.sumLabel}>Total credited to you</Text>
                <Text style={styles.sumValueStrong}>{m(grandTotal)}</Text>
              </View>
            </View>

            <View style={styles.infoCard}>
              <Text style={styles.infoKicker}>GOOD TO KNOW</Text>
              <Text style={styles.infoLine}>
                Your SSS is based on a Monthly Salary Credit of {m(r.msc)}, your salary rounded to the nearest 500 and kept between 5,000 and 35,000.
              </Text>
              <Text style={styles.infoLine}>
                If you are self-employed or a voluntary member, you pay both shares yourself, so budget for close to the {m(grandTotal)} total above, less the small employer-only Employees Compensation part.
              </Text>
            </View>
          </>
        ) : (
          <Text style={styles.hint}>Enter your monthly salary to see your contributions.</Text>
        )}

        <Text style={styles.disclaimer}>
          Estimate based on {RATES_YEAR} SSS, PhilHealth, and Pag-IBIG rates. SSS includes the WISP portion above a 20,000 salary credit and the employer's small Employees Compensation share. Your payslip can differ with your employer's rounding and cut-off. Not a substitute for your official records.
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

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginTop: spacing.xl },
    tblHead: { flexDirection: 'row', alignItems: 'center', paddingBottom: spacing.sm },
    thProgram: { flex: 1.4, color: colors.muted, fontSize: fontSize.caption, letterSpacing: 0.3 },
    thAmt: { flex: 1, color: colors.muted, fontSize: fontSize.caption, textAlign: 'right' },
    tblRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.sm, borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth },
    tblRowFirst: { borderTopWidth: 0 },
    tdProgram: { flex: 1.4, color: colors.text, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    tdAmt: { flex: 1, color: colors.text, fontSize: fontSize.small, fontWeight: fontWeight.bold, textAlign: 'right' },
    tdAmtMuted: { flex: 1, color: colors.muted, fontSize: fontSize.small, textAlign: 'right' },
    totalRow: { flexDirection: 'row', alignItems: 'center', borderTopColor: colors.border, borderTopWidth: 1, marginTop: spacing.xs, paddingTop: spacing.md },
    totalLabel: { flex: 1.4, color: colors.text, fontSize: fontSize.small, fontWeight: fontWeight.bold },
    totalAmt: { flex: 1, color: colors.primary, fontSize: fontSize.body, fontWeight: fontWeight.heavy, textAlign: 'right' },
    totalAmtMuted: { flex: 1, color: colors.textSecondary, fontSize: fontSize.small, fontWeight: fontWeight.bold, textAlign: 'right' },

    summaryCard: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginTop: spacing.md },
    sumRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: spacing.xs },
    sumRowTop: { borderTopColor: colors.border, borderTopWidth: 1, marginTop: spacing.xs, paddingTop: spacing.md },
    sumLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    sumLabelMuted: { color: colors.muted, fontSize: fontSize.small },
    sumValue: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    sumValueMuted: { color: colors.muted, fontSize: fontSize.small },
    sumValueStrong: { color: colors.primary, fontSize: fontSize.subtitle, fontWeight: fontWeight.heavy },

    infoCard: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginTop: spacing.md },
    infoKicker: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1.2, marginBottom: spacing.sm },
    infoLine: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 19, marginTop: spacing.xs },

    hint: { color: colors.muted, fontSize: fontSize.body, textAlign: 'center', marginTop: spacing.xl, marginBottom: spacing.xl },
    disclaimer: { color: colors.faint, fontSize: fontSize.caption, lineHeight: 17, marginTop: spacing.xl },
  });
}
