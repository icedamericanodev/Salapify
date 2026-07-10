// Tools: a hub for Filipino money calculators and utilities. Each tool is its
// own screen; this lists them. Built one at a time, so the ones still coming
// are shown greyed with a Soon tag to set expectations honestly.

import { useMemo } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../../theme';
import { useTheme } from '../../context/Theme';

const TOOLS = [
  { id: 'salary', emoji: '🧾', title: 'Take-home pay', desc: 'Gross to net, with SSS, PhilHealth, Pag-IBIG, and tax.', route: '/salary-calculator', ready: true },
  { id: 'tax', emoji: '🧮', title: 'Income tax calculator', desc: 'Flat 8% or graduated? For freelancers and the self-employed.', route: '/tax-calculator', ready: true },
  { id: 'thirteenth', emoji: '🎁', title: '13th month pay', desc: 'What you should receive, prorated, and the tax-free part.', route: '/thirteenth-calculator', ready: true },
  { id: 'loan', emoji: '📆', title: 'Loan and amortization', desc: 'Real monthly payment, total interest, and the true rate.', route: '/loan-calculator', ready: true },
  { id: 'bnpl', emoji: '🛒', title: 'Installment true cost', desc: 'Is that 0% installment really 0%? See the real cost.', route: '/bnpl-calculator', ready: true },
  { id: 'contrib', emoji: '🏦', title: 'Contribution checker', desc: 'SSS, PhilHealth, and Pag-IBIG for any salary.', route: '/contribution-calculator', ready: true },
  { id: 'fx', emoji: '💱', title: 'Currency converter', desc: 'What is your money worth abroad? Live rates when online, saved for offline.', route: '/currency-converter', ready: true },
];

export default function Tools() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();

  const open = (t) => {
    if (!t.ready || !t.route) return;
    try { router.push(t.route); } catch (e) { /* a bad route must never crash the hub */ }
  };

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Text style={styles.headerTitle}>Tools</Text>
      </View>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.intro}>Quick money calculators, built for the Philippines. More on the way.</Text>
        {TOOLS.map((t) => (
          <Pressable
            key={t.id}
            onPress={() => open(t)}
            disabled={!t.ready}
            style={({ pressed }) => [styles.card, !t.ready && styles.cardSoon, pressed && t.ready && styles.pressed]}
          >
            <Text style={styles.emoji}>{t.emoji}</Text>
            <View style={{ flex: 1 }}>
              <View style={styles.titleRow}>
                <Text style={[styles.title, !t.ready && styles.titleSoon]}>{t.title}</Text>
                {!t.ready ? <Text style={styles.soonTag}>SOON</Text> : null}
              </View>
              <Text style={styles.desc}>{t.desc}</Text>
            </View>
            {t.ready ? <Ionicons name="chevron-forward" size={18} color={colors.faint} /> : null}
          </Pressable>
        ))}
      </ScrollView>
    </SafeAreaView>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    headerBar: { paddingHorizontal: spacing.lg, paddingTop: spacing.md, paddingBottom: spacing.sm },
    headerTitle: { color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.heavy },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },
    intro: { color: colors.muted, fontSize: fontSize.small, marginBottom: spacing.lg, lineHeight: 19 },

    card: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginBottom: spacing.md },
    cardSoon: { opacity: 0.55 },
    pressed: { opacity: 0.7 },
    emoji: { fontSize: 26 },
    titleRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
    title: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    titleSoon: { color: colors.textSecondary },
    soonTag: { color: colors.muted, fontSize: 10, fontWeight: fontWeight.bold, letterSpacing: 1, borderColor: colors.border, borderWidth: 1, borderRadius: radius.sm, paddingHorizontal: 5, paddingVertical: 1 },
    desc: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2, lineHeight: 16 },
  });
}
