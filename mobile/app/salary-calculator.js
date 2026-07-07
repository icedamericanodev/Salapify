// Take-home pay calculator. Type your monthly gross and see the SSS,
// PhilHealth, Pag-IBIG, and income tax taken out, and what lands in your
// pocket. All math is in lib/phtax.js (pure and tested). This is an estimate
// from published rates, not your official payslip, and the screen says so.

import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { formatMoney } from '../lib/format';
import { takeHomePay, RATES_YEAR } from '../lib/phtax';

export default function SalaryCalculator() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();

  const [basic, setBasic] = useState('');
  const [taxAllow, setTaxAllow] = useState('');
  const [nonTaxAllow, setNonTaxAllow] = useState('');
  const parse = (s) => Number(String(s).replace(/[, ]/g, '')) || 0;
  const basicNum = parse(basic);
  const taxAllowNum = parse(taxAllow);
  const nonTaxAllowNum = parse(nonTaxAllow);
  const r = useMemo(
    () => takeHomePay(basicNum, { taxableAllowance: taxAllowNum, nonTaxableAllowance: nonTaxAllowNum }),
    [basicNum, taxAllowNum, nonTaxAllowNum]
  );
  const m = (n) => formatMoney(Math.round(n));

  const rows = [
    { label: 'SSS', value: r.sss },
    { label: 'PhilHealth', value: r.philhealth },
    { label: 'Pag-IBIG', value: r.pagibig },
    { label: 'Income tax', value: r.monthlyTax },
  ];

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>Take-home pay</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={styles.fieldLabel}>Monthly basic pay</Text>
        <View style={styles.inputWrap}>
          <Text style={styles.peso}>₱</Text>
          <TextInput
            style={styles.input}
            value={basic}
            onChangeText={setBasic}
            keyboardType="numeric"
            placeholder="e.g. 25,000"
            placeholderTextColor={colors.faint}
            autoFocus
          />
        </View>

        <View style={styles.allowRow}>
          <View style={styles.allowCol}>
            <Text style={styles.fieldLabel}>Taxable allowance</Text>
            <View style={styles.smallInputWrap}>
              <Text style={styles.pesoSm}>₱</Text>
              <TextInput style={styles.smallInput} value={taxAllow} onChangeText={setTaxAllow} keyboardType="numeric" placeholder="0" placeholderTextColor={colors.faint} />
            </View>
          </View>
          <View style={styles.allowCol}>
            <Text style={styles.fieldLabel}>Non-taxable allowance</Text>
            <View style={styles.smallInputWrap}>
              <Text style={styles.pesoSm}>₱</Text>
              <TextInput style={styles.smallInput} value={nonTaxAllow} onChangeText={setNonTaxAllow} keyboardType="numeric" placeholder="0" placeholderTextColor={colors.faint} />
            </View>
          </View>
        </View>
        <Text style={styles.allowHint}>
          Non-taxable covers de minimis benefits and allowances within BIR limits. They are added to your pay but not taxed. Contributions are figured on your basic pay.
        </Text>

        {basicNum > 0 ? (
          <>
            <View style={styles.card}>
              <View style={styles.grossRow}>
                <Text style={styles.grossLabel}>Basic pay</Text>
                <Text style={styles.grossValue}>{m(r.basic)}</Text>
              </View>
              {r.taxableAllowance > 0 ? (
                <View style={styles.row}>
                  <Text style={styles.rowLabel}>Taxable allowance</Text>
                  <Text style={styles.addValue}>+ {m(r.taxableAllowance)}</Text>
                </View>
              ) : null}
              {r.nonTaxableAllowance > 0 ? (
                <View style={styles.row}>
                  <Text style={styles.rowLabel}>Non-taxable allowance</Text>
                  <Text style={styles.addValue}>+ {m(r.nonTaxableAllowance)}</Text>
                </View>
              ) : null}
              {r.taxableAllowance > 0 || r.nonTaxableAllowance > 0 ? (
                <View style={[styles.row, styles.rowTopBorder]}>
                  <Text style={styles.grossLabel}>Gross pay</Text>
                  <Text style={styles.grossValue}>{m(r.gross)}</Text>
                </View>
              ) : null}
              {rows.map((row, i) => (
                <View key={row.label} style={[styles.row, i === 0 && styles.rowTopBorder]}>
                  <Text style={styles.rowLabel}>{row.label}</Text>
                  <Text style={styles.rowValue}>- {m(row.value)}</Text>
                </View>
              ))}
              <View style={styles.netRow}>
                <Text style={styles.netLabel}>Take-home pay</Text>
                <Text style={styles.netValue}>{m(r.net)}</Text>
              </View>
              <Text style={styles.perYear}>About {m(r.net * 12)} a year, before any 13th month.</Text>
            </View>

            <View style={styles.deductCard}>
              <Text style={styles.deductKicker}>WHAT COMES OUT, AND WHY</Text>
              <Text style={styles.deductLine}>
                Contributions total {m(r.contributions)}. They come out before tax, so your taxable pay is {m(r.monthlyTaxable)}.
              </Text>
              <Text style={styles.deductLine}>
                Income tax uses the graduated BIR table on your yearly taxable pay, spread across 12 months.
              </Text>
            </View>
          </>
        ) : (
          <Text style={styles.hint}>Enter your monthly basic pay to see the breakdown.</Text>
        )}

        <Text style={styles.disclaimer}>
          Estimate based on {RATES_YEAR} SSS, PhilHealth, Pag-IBIG, and BIR rates. Contributions are figured on your basic pay, non-taxable allowances are not taxed, and low salaries still pay the minimum contributions. Your real payslip can differ with de minimis limits and your employer's rounding. Not a substitute for your official payslip or a BIR filing.
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

    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.sm, letterSpacing: 0.3 },
    inputWrap: { flexDirection: 'row', alignItems: 'center', backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.lg, marginBottom: spacing.lg },
    peso: { color: colors.muted, fontSize: fontSize.title, fontWeight: fontWeight.bold, marginRight: spacing.sm },
    input: { flex: 1, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.bold },

    allowRow: { flexDirection: 'row', gap: spacing.md, marginBottom: spacing.sm },
    allowCol: { flex: 1 },
    smallInputWrap: { flexDirection: 'row', alignItems: 'center', backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md },
    pesoSm: { color: colors.muted, fontSize: fontSize.body, marginRight: spacing.xs },
    smallInput: { flex: 1, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    allowHint: { color: colors.faint, fontSize: fontSize.caption, lineHeight: 16, marginBottom: spacing.lg },
    addValue: { color: colors.textSecondary, fontSize: fontSize.small, fontWeight: fontWeight.medium },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginBottom: spacing.lg },
    grossRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingBottom: spacing.md },
    grossLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    grossValue: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    row: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: spacing.sm },
    rowTopBorder: { borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth, paddingTop: spacing.md },
    rowLabel: { color: colors.muted, fontSize: fontSize.small },
    rowValue: { color: colors.textSecondary, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    netRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', borderTopColor: colors.border, borderTopWidth: 1, marginTop: spacing.md, paddingTop: spacing.md },
    netLabel: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    netValue: { color: colors.primary, fontSize: fontSize.subtitle, fontWeight: fontWeight.heavy },
    perYear: { color: colors.faint, fontSize: fontSize.caption, marginTop: spacing.sm },

    deductCard: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginBottom: spacing.lg },
    deductKicker: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1.2, marginBottom: spacing.sm },
    deductLine: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 19, marginTop: spacing.xs },

    hint: { color: colors.muted, fontSize: fontSize.body, textAlign: 'center', marginTop: spacing.xl, marginBottom: spacing.xl },
    disclaimer: { color: colors.faint, fontSize: fontSize.caption, lineHeight: 17, marginTop: spacing.sm },
  });
}
