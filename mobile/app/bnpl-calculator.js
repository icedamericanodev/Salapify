// Installment true cost calculator. Answers the one question that matters
// before an installment or "0% interest" plan (GGives, BillEase, Home Credit,
// Shopee/Lazada, card installment): is it really free, and if not, what does it
// really cost versus paying cash. The math is in lib/bnpl.js (pure and tested),
// which reuses the loan engine to back out the real effective rate. An estimate
// from the numbers you enter, not a loan offer. No dashes.

import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { formatMoney } from '../lib/format';
import { bnplCost } from '../lib/bnpl';

export default function BnplCalculator() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();

  const [price, setPrice] = useState('');
  const [months, setMonths] = useState('');
  const [monthly, setMonthly] = useState('');
  const [down, setDown] = useState('');
  const [fee, setFee] = useState('');

  const parse = (s) => Number(String(s).replace(/[, ]/g, '')) || 0;
  const priceNum = parse(price);
  const monthsNum = Math.round(parse(months));
  const monthlyNum = parse(monthly);
  const downNum = parse(down);
  const feeNum = parse(fee);

  const r = useMemo(
    () => bnplCost({ cashPrice: priceNum, downpayment: downNum, months: monthsNum, monthlyPayment: monthlyNum, upfrontFee: feeNum }),
    [priceNum, downNum, monthsNum, monthlyNum, feeNum]
  );
  const m = (n) => formatMoney(Math.round(n));
  const pct = (x) => (x * 100).toFixed(1) + '%';
  // A real rate above 1,000% a year is arithmetically true on a punishing fee
  // but reads as broken, so cap the display and let the peso extra cost carry it.
  const rateDisplay = r.annualRate > 10 ? 'over 1,000%' : pct(r.annualRate);

  const badInput = priceNum < 0 || monthlyNum < 0 || downNum < 0 || feeNum < 0 || monthsNum < 0;
  const ready = priceNum > 0 && monthsNum >= 1 && monthlyNum > 0;
  const monthsCapped = monthsNum > 60; // the engine estimates up to 60 months

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back} accessibilityRole="button" accessibilityLabel="Go back">
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>Installment true cost</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={styles.intro}>
          Is that "0% interest" really 0%? Enter the plan and see the real cost versus paying cash, and the true rate a monthly quote can hide.
        </Text>

        <Text style={styles.fieldLabel}>Cash price (if you paid in full today)</Text>
        <View style={styles.inputWrap}>
          <Text style={styles.peso}>₱</Text>
          <TextInput style={styles.input} value={price} onChangeText={setPrice} keyboardType="numeric" placeholder="e.g. 12,000" placeholderTextColor={colors.faint} autoFocus />
        </View>

        <View style={styles.twoCol}>
          <View style={styles.col}>
            <Text style={styles.fieldLabel}>Months to pay</Text>
            <View style={styles.smallInputWrap}>
              <TextInput style={styles.smallInput} value={months} onChangeText={setMonths} keyboardType="numeric" placeholder="e.g. 6" placeholderTextColor={colors.faint} />
            </View>
          </View>
          <View style={styles.col}>
            <Text style={styles.fieldLabel}>Monthly payment</Text>
            <View style={styles.smallInputWrap}>
              <Text style={styles.pesoSmall}>₱</Text>
              <TextInput style={styles.smallInput} value={monthly} onChangeText={setMonthly} keyboardType="numeric" placeholder="e.g. 2,100" placeholderTextColor={colors.faint} />
            </View>
          </View>
        </View>

        <View style={[styles.twoCol, { marginTop: spacing.lg }]}>
          <View style={styles.col}>
            <Text style={styles.fieldLabel}>Downpayment (optional)</Text>
            <View style={styles.smallInputWrap}>
              <Text style={styles.pesoSmall}>₱</Text>
              <TextInput style={styles.smallInput} value={down} onChangeText={setDown} keyboardType="numeric" placeholder="0" placeholderTextColor={colors.faint} />
            </View>
          </View>
          <View style={styles.col}>
            <Text style={styles.fieldLabel}>Upfront fee (optional)</Text>
            <View style={styles.smallInputWrap}>
              <Text style={styles.pesoSmall}>₱</Text>
              <TextInput style={styles.smallInput} value={fee} onChangeText={setFee} keyboardType="numeric" placeholder="0" placeholderTextColor={colors.faint} />
            </View>
          </View>
        </View>
        <Text style={styles.methodHint}>
          Some "0%" plans still charge a processing or convenience fee. Put it in the upfront fee box and it shows up in the real cost.
        </Text>

        {badInput ? (
          <Text style={styles.hint}>Check your numbers. None of the amounts can be negative.</Text>
        ) : !ready ? (
          <Text style={styles.hint}>Enter the cash price, the months to pay, and the monthly payment to see the real cost.</Text>
        ) : r.underpays ? (
          <View style={styles.rateCard}>
            <Text style={styles.rateKicker}>CHECK YOUR NUMBERS</Text>
            <Text style={styles.rateNote}>
              Your payments come to {m(r.totalPaid)}, which is less than the {m(r.cash)} cash price. Double check the monthly amount, the months, and the downpayment.
            </Text>
          </View>
        ) : (
          <>
            {monthsCapped ? (
              <Text style={styles.methodHint}>Using 60 months, the longest this tool estimates.</Text>
            ) : null}
            <View style={styles.card}>
              <Text style={styles.payLabel}>Total you will pay</Text>
              <Text style={styles.payValue} accessibilityLabel={`${m(r.totalPaid)} total`}>{m(r.totalPaid)}</Text>
              <View style={styles.splitRow}>
                <View style={styles.splitCol}>
                  <Text style={styles.splitLabel}>Cash price</Text>
                  <Text style={styles.splitValue}>{m(r.cash)}</Text>
                </View>
                <View style={styles.splitCol}>
                  <Text style={styles.splitLabel}>Extra over cash</Text>
                  <Text style={[styles.splitValue, r.extraCost > 0 && styles.splitValueWarn]}>{m(r.extraCost)}</Text>
                </View>
              </View>
            </View>

            <View style={[styles.rateCard, !r.trulyFree && styles.rateCardWarn]}>
              <Text style={styles.rateKicker}>TRUE COST</Text>
              {r.trulyFree ? (
                <Text style={styles.verdictGood}>
                  Based on your numbers, this costs the same as paying cash today. Just make sure you can keep up with the {m(r.monthly)} a month for {r.months} months.
                </Text>
              ) : r.rateReliable ? (
                <>
                  <View style={styles.rateRow}>
                    <Text style={styles.rateLabel}>Real interest per year</Text>
                    <Text style={styles.rateValueWarn}>{rateDisplay}</Text>
                  </View>
                  <Text style={styles.rateNote}>
                    This plan costs you {m(r.extraCost)} more than paying cash, about {rateDisplay} a year on the {m(r.netCredit)} of credit you receive. Saving up for {r.months} months and paying cash would cost nothing.
                  </Text>
                </>
              ) : (
                <Text style={styles.rateNote}>
                  This plan costs you {m(r.extraCost)} more than paying cash. Paying cash would cost nothing.
                </Text>
              )}
            </View>
          </>
        )}

        <Text style={styles.disclaimer}>
          An estimate from the numbers you enter, not a loan offer. Real plans can add late fees and penalties. If a plan will not show you the total you will pay or a clear rate, that is a warning sign.
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
    pesoSmall: { color: colors.muted, fontSize: fontSize.body, fontWeight: fontWeight.bold, marginRight: spacing.xs },
    smallInput: { flex: 1, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    methodHint: { color: colors.faint, fontSize: fontSize.caption, lineHeight: 16, marginTop: spacing.sm },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginTop: spacing.xl },
    payLabel: { color: colors.muted, fontSize: fontSize.caption, letterSpacing: 0.3 },
    payValue: { color: colors.primary, fontSize: fontSize.huge, fontWeight: fontWeight.heavy, marginTop: 2 },
    splitRow: { flexDirection: 'row', borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth, marginTop: spacing.md, paddingTop: spacing.md },
    splitCol: { flex: 1 },
    splitLabel: { color: colors.muted, fontSize: fontSize.caption },
    splitValue: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginTop: 2 },
    splitValueWarn: { color: colors.warning },

    rateCard: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginTop: spacing.md },
    rateCardWarn: { borderColor: colors.warning },
    rateKicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.2, marginBottom: spacing.sm },
    rateRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: spacing.sm },
    rateLabel: { color: colors.text, fontSize: fontSize.small },
    rateValueWarn: { color: colors.warning, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    rateNote: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 19 },
    verdictGood: { color: colors.primary, fontSize: fontSize.small, lineHeight: 19, fontWeight: fontWeight.medium },

    hint: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.xl, textAlign: 'center' },
    disclaimer: { color: colors.faint, fontSize: fontSize.caption, lineHeight: 16, marginTop: spacing.xl },
  });
}
