// Overview screen (Home). Shows the headline numbers: net worth, this month's
// cash flow (money in minus money out), and days to payday, plus quick links
// to the main sections. Cash flow only counts transactions dated this month.

import { useEffect, useMemo, useRef, useState } from 'react';
import { Animated, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../../theme';
import { useTheme } from '../../context/Theme';
import { useAppData } from '../../context/AppData';
import { formatMoney, daysUntilPayday, isThisMonth, monthLabel, todayISO } from '../../lib/format';
import { upcomingDues } from '../../lib/soa';
import WeekChain from '../../components/WeekChain';
import WeekRecap from '../../components/WeekRecap';

const MONTHS_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export default function Overview() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter(); // lets the quick links open other tabs
  const { data, addTransaction, updateSettings, loaded } = useAppData(); // live data from the store

  const [salaryModal, setSalaryModal] = useState(false);
  const [salaryAmount, setSalaryAmount] = useState('');
  const [salaryAccount, setSalaryAccount] = useState('');
  const [showPeak, setShowPeak] = useState(false);
  const peakAnim = useRef(new Animated.Value(0)).current;

  // Helper to add up a number field across a list.
  const sum = (list, key) => list.reduce((total, item) => total + item[key], 0);

  // Net worth: everything you own minus everything you owe.
  const totalAssets = sum(data.accounts, 'balance') + sum(data.assets, 'value');
  const totalDebt = sum(data.debts, 'remaining');
  const netWorth = totalAssets - totalDebt;

  // This month's cash flow. Only transactions dated in the current month
  // count, so every new month starts fresh.
  const thisMonth = data.transactions.filter((t) => isThisMonth(t.date));
  const income = thisMonth.filter((t) => t.type === 'income');
  const expense = thisMonth.filter((t) => t.type === 'expense');
  const moneyIn = sum(income, 'amount');
  const moneyOut = sum(expense, 'amount');
  const cashFlow = moneyIn - moneyOut;

  // Days to the next payday, with extra energy in the final stretch.
  const payday = daysUntilPayday();
  const paydaySoon = payday <= 3;
  const paydayCopy =
    payday === 0
      ? 'Payday today. Log that income first. 💸'
      : payday === 1
      ? 'Bukas na. 🤑'
      : paydaySoon
      ? 'Malapit na. Konting tiis. 💪'
      : 'Based on the 15th and end of month.';

  // Net worth peak: gold appears only when earned. The stored peak only
  // ever climbs, and the pill fires when net worth crosses into a new
  // 10,000 step above it.
  useEffect(() => {
    if (!loaded) return;
    (async () => {
      try {
        const raw = await AsyncStorage.getItem('salapify_peak_networth');
        const prevPeak = raw ? Number(raw) : 0;
        if (netWorth > prevPeak) {
          await AsyncStorage.setItem('salapify_peak_networth', String(netWorth));
          if (prevPeak > 0 && Math.floor(netWorth / 10000) > Math.floor(prevPeak / 10000)) {
            setShowPeak(true);
            Animated.timing(peakAnim, { toValue: 1, duration: 400, useNativeDriver: true }).start();
          }
        }
      } catch (e) {
        // Peak tracking is a nice-to-have; never let it break the screen.
      }
    })();
  }, [loaded, netWorth]);

  // Unpaid utang, surfaced on home so collecting is one tap away.
  const unpaid = (data.receivables || []).filter((r) => !r.paid);
  const owedToMe = sum(unpaid, 'amount');
  const owedCount = unpaid.length;

  // Payments coming due in the next 30 days (cards and loans with a due
  // day set), so future cash flow is visible before it hits.
  const dues = upcomingDues(data.debts, 30);

  // The sweldo plan: a guided three step card that appears for 48 hours
  // after each payday (the 15th and the last day of the month). The steps
  // done are remembered per payday, so the card never nags twice.
  const now = new Date();
  const dayNum = now.getDate();
  const lastDayNum = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  let paydayKey = '';
  if (dayNum === 15 || dayNum === 16) {
    paydayKey = `${now.getFullYear()}-${now.getMonth()}-15`;
  } else if (dayNum === 1) {
    const p = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    paydayKey = `${p.getFullYear()}-${p.getMonth()}-end`;
  } else if (dayNum === lastDayNum) {
    paydayKey = `${now.getFullYear()}-${now.getMonth()}-end`;
  }
  const savedPlan = data.settings.paydayPlan || {};
  const planSteps = savedPlan.key === paydayKey ? savedPlan.steps || {} : {};
  const planDone = planSteps.logged && planSteps.saved && planSteps.budget;

  function markStep(step) {
    updateSettings((s) => {
      const cur = s.paydayPlan && s.paydayPlan.key === paydayKey ? s.paydayPlan.steps || {} : {};
      return { paydayPlan: { key: paydayKey, steps: { ...cur, [step]: true } } };
    });
  }
  // Open the sweldo sheet with the account chip preset to the last one a
  // salary landed in, so payday logging stays two taps.
  function openSalary() {
    const def = data.settings.salaryAccountId;
    setSalaryAccount(def && data.accounts.some((a) => a.id === def) ? def : '');
    setSalaryModal(true);
  }
  function saveSalary() {
    const amount = Number(String(salaryAmount).replace(/[, ]/g, ''));
    if (!Number.isFinite(amount) || amount <= 0) return;
    const entry = { type: 'income', label: 'Salary', amount, date: todayISO() };
    addTransaction(salaryAccount ? { ...entry, accountId: salaryAccount } : entry);
    if ((data.settings.salaryAccountId || '') !== salaryAccount) {
      updateSettings({ salaryAccountId: salaryAccount });
    }
    setSalaryModal(false);
    setSalaryAmount('');
    markStep('logged');
  }

  // Time-based greeting for the header.
  const hour = new Date().getHours();
  const greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';

  // The quick links shown at the bottom. Each opens a tab when tapped.
  const links = [
    { label: 'Accounts', icon: 'wallet-outline', href: '/accounts' },
    { label: 'Debts', icon: 'card-outline', href: '/debts' },
    { label: 'Budget', icon: 'pie-chart-outline', href: '/budget' },
    { label: 'Insights', icon: 'bar-chart-outline', href: '/insights' },
  ];

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.header}>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>🪙</Text>
          </View>
          <View>
            <Text style={styles.greeting}>{greeting}</Text>
            <Text style={styles.subgreeting}>Here is your money today</Text>
          </View>
        </View>

        {/* Sweldo plan: appears for 48 hours after each payday. */}
        {paydayKey && !planDone ? (
          <View style={styles.planCard}>
            <Text style={styles.planKicker}>SWELDO PLAN</Text>
            <Text style={styles.planSub}>
              Payday! Three taps and this cycle is planned before the money moves.
            </Text>
            {[
              { k: 'logged', label: 'Log your sweldo', action: openSalary },
              { k: 'saved', label: 'Move savings first', action: () => { markStep('saved'); router.push('/goals'); } },
              { k: 'budget', label: 'Check your spending budget', action: () => { markStep('budget'); router.push('/budget'); } },
            ].map((s) => (
              <Pressable
                key={s.k}
                onPress={planSteps[s.k] ? undefined : s.action}
                style={styles.planRow}
              >
                <Ionicons
                  name={planSteps[s.k] ? 'checkmark-circle' : 'ellipse-outline'}
                  size={22}
                  color={planSteps[s.k] ? colors.primary : colors.faint}
                />
                <Text style={[styles.planLabel, planSteps[s.k] && styles.planLabelDone]}>{s.label}</Text>
              </Pressable>
            ))}
          </View>
        ) : null}
        {paydayKey && planDone ? (
          <View style={styles.planCard}>
            <Text style={styles.planKicker}>SWELDO PLAN</Text>
            <Text style={styles.planSub}>All three done. This cycle is planned. Nice one. ✅</Text>
          </View>
        ) : null}

        {/* Net worth headline. Tap to open Accounts. */}
        <Pressable
          onPress={() => router.push('/accounts')}
          style={({ pressed }) => [styles.card, pressed && styles.cardPressed]}
        >
          <View style={styles.cardHead}>
            <Text style={styles.kicker}>NET WORTH</Text>
            <Ionicons name="chevron-forward" size={16} color={colors.faint} />
          </View>
          <Text style={styles.netWorth} numberOfLines={1} adjustsFontSizeToFit>
            {formatMoney(netWorth)}
          </Text>
          {showPeak ? (
            <Animated.View
              style={[
                styles.peakPill,
                {
                  opacity: peakAnim,
                  transform: [
                    { scale: peakAnim.interpolate({ inputRange: [0, 0.5, 1], outputRange: [1, 1.06, 1] }) },
                  ],
                },
              ]}
            >
              <Text style={styles.peakText}>New peak 📈 Angat ka ngayon.</Text>
            </Animated.View>
          ) : null}
          <View style={styles.splitRow}>
            <View>
              <Text style={styles.smallLabel}>Total assets</Text>
              <Text style={[styles.smallValue, { color: colors.primary }]}>
                {formatMoney(totalAssets)}
              </Text>
            </View>
            <View>
              <Text style={styles.smallLabel}>Total debt</Text>
              <Text style={[styles.smallValue, { color: colors.warning }]}>
                {formatMoney(totalDebt)}
              </Text>
            </View>
          </View>
        </Pressable>

        {/* This month's cash flow. Tap to open Budget. */}
        <Pressable
          onPress={() => router.push('/budget')}
          style={({ pressed }) => [styles.card, pressed && styles.cardPressed]}
        >
          <View style={styles.cardHead}>
            <Text style={styles.kicker}>{monthLabel().toUpperCase()}</Text>
            <Ionicons name="chevron-forward" size={16} color={colors.faint} />
          </View>
          <Text
            style={[
              styles.cashFlow,
              { color: cashFlow >= 0 ? colors.primary : colors.warning },
            ]}
          >
            {cashFlow >= 0 ? '+' : ''}
            {formatMoney(cashFlow)}
          </Text>
          <View style={styles.splitRow}>
            <View>
              <Text style={styles.smallLabel}>Money in</Text>
              <Text style={[styles.smallValue, { color: colors.primary }]}>
                {formatMoney(moneyIn)}
              </Text>
            </View>
            <View>
              <Text style={styles.smallLabel}>Money out</Text>
              <Text style={[styles.smallValue, { color: colors.textSecondary }]}>
                {formatMoney(moneyOut)}
              </Text>
            </View>
          </View>
        </Pressable>

        {/* Logging chain: filled dots for days you logged in the last week. */}
        <WeekChain transactions={data.transactions} />

        {/* The share worthy week recap, when the week deserves it. */}
        <WeekRecap transactions={data.transactions} />

        {/* People who owe me, one tap from home. */}
        <Pressable
          onPress={() => router.push('/receivables')}
          style={({ pressed }) => [styles.card, pressed && styles.cardPressed]}
        >
          <View style={styles.cardHead}>
            <Text style={styles.kicker}>PEOPLE WHO OWE ME</Text>
            <Ionicons name="chevron-forward" size={16} color={colors.faint} />
          </View>
          <Text style={styles.payday}>{formatMoney(owedToMe)}</Text>
          <Text style={styles.smallLabel}>
            {owedCount === 0
              ? 'No one owes you right now.'
              : `${owedCount} ${owedCount === 1 ? 'person' : 'people'}. Tap to view or send a reminder.`}
          </Text>
        </Pressable>

        {/* Payments coming due soon: cards and loans with a due day set. */}
        {dues.length > 0 ? (
          <>
            <Text style={styles.sectionTitle}>UPCOMING PAYMENTS</Text>
            <View style={styles.card}>
              {dues.map((u, i) => (
                <View key={u.debt.id} style={[styles.dueRow, i > 0 && styles.dueDivider]}>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.dueName}>{u.debt.name}</Text>
                    <Text style={styles.dueWhen}>
                      {u.inDays === 0 ? 'Due today' : u.inDays === 1 ? 'Due tomorrow' : `In ${u.inDays} days`}
                      {' '}({MONTHS_SHORT[u.due.getMonth()]} {u.due.getDate()})
                    </Text>
                  </View>
                  <Text style={styles.dueAmount}>{formatMoney(u.amount)}</Text>
                </View>
              ))}
              <Text style={styles.dueHint}>
                Minimum amounts shown. Pay cards in full when you can to avoid interest.
              </Text>
            </View>
          </>
        ) : null}

        {/* Days to payday, glowing when it is close. */}
        <View style={[styles.card, paydaySoon && styles.paydaySoonCard]}>
          <Text style={styles.kicker}>DAYS TO PAYDAY</Text>
          <Text style={[styles.payday, paydaySoon && styles.paydaySoonNumber]}>
            {payday === 0 ? 'Today' : `${payday} ${payday === 1 ? 'day' : 'days'}`}
          </Text>
          <Text style={styles.smallLabel}>{paydayCopy}</Text>
        </View>

        {/* Quick links to the other tabs. */}
        <Text style={styles.sectionTitle}>QUICK LINKS</Text>
        <View style={styles.linksRow}>
          {links.map((link) => (
            <Pressable
              key={link.href}
              onPress={() => router.push(link.href)}
              style={({ pressed }) => [styles.linkCard, pressed && styles.pressed]}
            >
              <Ionicons name={link.icon} size={22} color={colors.primary} />
              <Text style={styles.linkLabel}>{link.label}</Text>
            </Pressable>
          ))}
        </View>

        <Text style={styles.footnote}>Showing {monthLabel()}. Every new month starts fresh.</Text>
      </ScrollView>

      {/* Quick salary entry for the sweldo plan. */}
      <Modal visible={salaryModal} transparent animationType="slide" onRequestClose={() => setSalaryModal(false)}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            <Text style={styles.sheetTitle}>Log your sweldo</Text>
            <Text style={styles.fieldLabel}>Amount</Text>
            <TextInput
              style={styles.input}
              value={salaryAmount}
              onChangeText={setSalaryAmount}
              placeholder="0"
              placeholderTextColor={colors.faint}
              keyboardType="numeric"
              autoFocus
            />
            {data.accounts.length > 0 ? (
              <>
                <Text style={styles.fieldLabel}>Into which account?</Text>
                <View style={styles.chips}>
                  <Pressable onPress={() => setSalaryAccount('')} style={[styles.chip, salaryAccount === '' && styles.chipOn]}>
                    <Text style={[styles.chipText, salaryAccount === '' && styles.chipTextOn]}>Not linked</Text>
                  </Pressable>
                  {data.accounts.map((a) => {
                    const on = salaryAccount === a.id;
                    return (
                      <Pressable key={a.id} onPress={() => setSalaryAccount(a.id)} style={[styles.chip, on && styles.chipOn]}>
                        <Text style={[styles.chipText, on && styles.chipTextOn]}>
                          {a.icon ? `${a.icon} ` : ''}{a.name}
                        </Text>
                      </Pressable>
                    );
                  })}
                </View>
              </>
            ) : null}
            <View style={styles.sheetButtons}>
              <Pressable onPress={() => setSalaryModal(false)} style={[styles.sheetBtn, styles.cancelBtn]}>
                <Text style={styles.cancelText}>Cancel</Text>
              </Pressable>
              <Pressable onPress={saveSalary} style={[styles.sheetBtn, styles.saveBtn]}>
                <Text style={styles.saveText}>Log it</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },
    header: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: spacing.md,
      marginBottom: spacing.lg,
    },
    avatar: {
      width: 44,
      height: 44,
      borderRadius: radius.pill,
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      alignItems: 'center',
      justifyContent: 'center',
    },
    avatarText: { fontSize: 22 },
    greeting: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    subgreeting: { color: colors.muted, fontSize: fontSize.small, marginTop: 2 },

    card: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.lg,
      padding: spacing.xl,
      marginBottom: spacing.lg,
    },
    cardPressed: { opacity: 0.7 },
    cardHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
    kicker: {
      color: colors.softGreen,
      fontSize: fontSize.caption,
      fontWeight: fontWeight.medium,
      letterSpacing: 1.2,
    },
    netWorth: {
      color: colors.text,
      fontSize: fontSize.display,
      fontWeight: fontWeight.heavy,
      fontVariant: ['tabular-nums'],
      letterSpacing: -0.5,
      marginTop: spacing.xs,
      marginBottom: spacing.lg,
    },
    cashFlow: {
      fontSize: fontSize.huge,
      fontWeight: fontWeight.heavy,
      fontVariant: ['tabular-nums'],
      letterSpacing: -0.5,
      marginTop: spacing.xs,
      marginBottom: spacing.lg,
    },
    payday: {
      color: colors.text,
      fontSize: fontSize.big,
      fontWeight: fontWeight.bold,
      marginTop: spacing.xs,
      marginBottom: spacing.xs,
    },
    paydaySoonCard: { backgroundColor: colors.positiveSurface, borderColor: colors.positiveBorder },
    paydaySoonNumber: { color: colors.primary, fontSize: fontSize.huge, fontWeight: fontWeight.heavy },
    peakPill: {
      alignSelf: 'flex-start',
      backgroundColor: colors.positiveSurface,
      borderColor: colors.positiveBorder,
      borderWidth: 1,
      borderRadius: radius.pill,
      paddingHorizontal: spacing.md,
      paddingVertical: spacing.xs,
      marginTop: -spacing.sm,
      marginBottom: spacing.md,
    },
    peakText: { color: colors.celebrate, fontSize: fontSize.small, fontWeight: fontWeight.medium },

    splitRow: { flexDirection: 'row', justifyContent: 'space-between' },
    smallLabel: { color: colors.muted, fontSize: fontSize.caption },
    smallValue: { fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginTop: spacing.xs },

    sectionTitle: {
      color: colors.muted,
      fontSize: fontSize.caption,
      fontWeight: fontWeight.medium,
      letterSpacing: 1.5,
      marginBottom: spacing.sm,
      paddingHorizontal: spacing.xs,
    },
    linksRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.md },
    linkCard: {
      flexGrow: 1,
      flexBasis: '47%', // two per row
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.md,
      paddingVertical: spacing.lg,
      alignItems: 'center',
      gap: spacing.xs,
    },
    pressed: { opacity: 0.6 },
    linkLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },

    footnote: {
      color: colors.faint,
      fontSize: fontSize.small,
      textAlign: 'center',
      marginTop: spacing.lg,
    },

    planCard: {
      backgroundColor: colors.card,
      borderColor: colors.primary,
      borderWidth: 1,
      borderRadius: radius.lg,
      padding: spacing.xl,
      marginBottom: spacing.lg,
    },
    planKicker: { color: colors.primary, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1.2 },
    planSub: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.xs, marginBottom: spacing.sm },
    planRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, minHeight: 44 },
    planLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    planLabelDone: { color: colors.muted, textDecorationLine: 'line-through' },

    dueRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.sm },
    dueDivider: { borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth },
    dueName: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    dueWhen: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },
    dueAmount: { color: colors.warning, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    dueHint: { color: colors.faint, fontSize: fontSize.small, marginTop: spacing.sm },

    overlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginBottom: spacing.sm },
    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs, marginTop: spacing.md },
    input: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
    chips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
    chip: { borderWidth: 1, borderColor: colors.border, borderRadius: radius.pill, paddingHorizontal: spacing.md, paddingVertical: spacing.sm, backgroundColor: colors.card },
    chipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    chipText: { color: colors.text, fontSize: fontSize.small },
    chipTextOn: { color: colors.onPrimary, fontWeight: fontWeight.medium },
    sheetButtons: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.sm, marginTop: spacing.xl },
    sheetBtn: { paddingVertical: spacing.md, paddingHorizontal: spacing.lg, borderRadius: radius.md },
    cancelBtn: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1 },
    cancelText: { color: colors.text, fontSize: fontSize.body },
    saveBtn: { backgroundColor: colors.primary },
    saveText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
