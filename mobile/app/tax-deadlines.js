// BIR filing dates for freelancers and the self-employed: the next deadlines,
// how many days away, and what each one covers. This is state derived, it reads
// the device date every time you open it, so it never depends on a notification
// firing (many phones silently kill those). All date math is in
// lib/taxdeadlines.js (pure and tested). Awareness only, not a filing service.

import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { taxDeadlines } from '../lib/taxdeadlines';

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const fmtDate = (d) => `${MONTHS[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;

function daysLabel(n) {
  if (n <= 0) return 'Due today';
  if (n === 1) return 'Tomorrow';
  if (n <= 30) return `In ${n} days`;
  const months = Math.round(n / 30);
  return `In about ${months} ${months === 1 ? 'month' : 'months'}`;
}

export default function TaxDeadlines() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();

  const [onEight, setOnEight] = useState(false);

  // Read the device date once per render. lib/taxdeadlines is pure and takes it
  // as an argument, so the list is a plain function of today and the 8% toggle.
  const list = useMemo(() => taxDeadlines(new Date(), { onEightPercent: onEight, count: 5 }), [onEight]);
  const next = list[0];

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>BIR filing dates</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.intro}>
          If you are a freelancer, professional, or small business, you file with the BIR every quarter, not just once a year. Here are your next deadlines so nothing sneaks up on you.
        </Text>

        <Pressable style={styles.toggleRow} onPress={() => setOnEight((v) => !v)}>
          <View style={{ flex: 1 }}>
            <Text style={styles.toggleTitle}>I am on the 8% option</Text>
            <Text style={styles.toggleDesc}>The flat 8% replaces the percentage tax, so hide the 2551Q filings.</Text>
          </View>
          <View style={[styles.check, onEight && styles.checkOn]}>
            {onEight ? <Ionicons name="checkmark" size={16} color={colors.background} /> : null}
          </View>
        </Pressable>

        {next ? (
          <View style={styles.nextCard}>
            <Text style={styles.nextKicker}>NEXT DEADLINE</Text>
            <Text style={styles.nextWhen}>{daysLabel(next.daysLeft)}</Text>
            <Text style={styles.nextTitle}>{next.title} ({next.form})</Text>
            <Text style={styles.nextDate}>{fmtDate(next.date)} · {next.what}</Text>
          </View>
        ) : null}

        <Text style={styles.sectionLabel}>COMING UP</Text>
        {list.map((d, i) => (
          <View key={`${d.form}-${d.year}-${d.date.getMonth()}`} style={[styles.row, i === 0 && styles.rowFirst]}>
            <View style={styles.rowDate}>
              <Text style={styles.rowMonth}>{MONTHS[d.date.getMonth()]}</Text>
              <Text style={styles.rowDay}>{d.date.getDate()}</Text>
            </View>
            <View style={styles.rowBody}>
              <Text style={styles.rowTitle}>{d.title} <Text style={styles.rowForm}>{d.form}</Text></Text>
              <Text style={styles.rowWhat}>{d.what}</Text>
            </View>
            <Text style={styles.rowDays}>{daysLabel(d.daysLeft)}</Text>
          </View>
        ))}

        <Pressable style={styles.linkRow} onPress={() => { try { router.push('/tax-calculator'); } catch (e) {} }}>
          <Ionicons name="calculator-outline" size={18} color={colors.primary} />
          <Text style={styles.linkText}>Estimate how much to set aside in the Income tax calculator</Text>
        </Pressable>

        <View style={styles.infoCard}>
          <Text style={styles.infoKicker}>GOOD TO KNOW</Text>
          <Text style={styles.infoLine}>
            A quarter with no income still means you file, just with nothing to pay. Missing a deadline adds a surcharge and interest, so it is worth setting aside a little each month.
          </Text>
          <Text style={styles.infoLine}>
            These are the regular statutory dates. When one lands on a weekend or a holiday it moves to the next working day, so confirm with the BIR near the date.
          </Text>
        </View>

        <Text style={styles.disclaimer}>
          For awareness only, not tax advice or a filing service. Deadlines and forms follow the National Internal Revenue Code as amended by the TRAIN law and the 2024 Ease of Paying Taxes Act. Confirm with the BIR or a licensed accountant before you file.
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

    toggleRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, marginBottom: spacing.lg },
    toggleTitle: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    toggleDesc: { color: colors.muted, fontSize: fontSize.caption, lineHeight: 16, marginTop: 2 },
    check: { width: 26, height: 26, borderRadius: radius.sm, borderWidth: 1.5, borderColor: colors.border, alignItems: 'center', justifyContent: 'center' },
    checkOn: { backgroundColor: colors.primary, borderColor: colors.primary },

    nextCard: { backgroundColor: colors.card, borderColor: colors.primary, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg },
    nextKicker: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1.2 },
    nextWhen: { color: colors.primary, fontSize: fontSize.title, fontWeight: fontWeight.heavy, marginTop: 4 },
    nextTitle: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold, marginTop: spacing.xs },
    nextDate: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 18, marginTop: 2 },

    sectionLabel: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1.2, marginTop: spacing.xl, marginBottom: spacing.sm },
    row: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, padding: spacing.md, marginTop: spacing.sm },
    rowFirst: { marginTop: 0 },
    rowDate: { width: 44, alignItems: 'center' },
    rowMonth: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 0.5, textTransform: 'uppercase' },
    rowDay: { color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.heavy, lineHeight: 26 },
    rowBody: { flex: 1 },
    rowTitle: { color: colors.text, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    rowForm: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.bold },
    rowWhat: { color: colors.muted, fontSize: fontSize.caption, lineHeight: 15, marginTop: 2 },
    rowDays: { color: colors.textSecondary, fontSize: fontSize.caption, fontWeight: fontWeight.medium, flexShrink: 0 },

    linkRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginTop: spacing.lg },
    linkText: { color: colors.primary, fontSize: fontSize.small, fontWeight: fontWeight.medium, flex: 1 },

    infoCard: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginTop: spacing.lg },
    infoKicker: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1.2, marginBottom: spacing.sm },
    infoLine: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 19, marginTop: spacing.xs },

    disclaimer: { color: colors.faint, fontSize: fontSize.caption, lineHeight: 17, marginTop: spacing.xl },
  });
}
