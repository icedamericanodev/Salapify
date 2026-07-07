// Overview screen (Home). Shows the headline numbers: net worth, this month's
// cash flow (money in minus money out), and days to payday, plus quick links
// to the main sections. Cash flow only counts transactions dated this month.

import { useEffect, useMemo, useRef, useState } from 'react';
import { Animated, Modal, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import { spacing, radius, fontSize, fontWeight } from '../../theme';
import { useTheme } from '../../context/Theme';
import { useAppData } from '../../context/AppData';
import { formatMoney, daysUntilPayday, prevPayday, scheduleLabel, isThisMonth, monthLabel, todayISO } from '../../lib/format';
import { safeToSpend, upcomingCommitments } from '../../lib/analytics';
import { sweldoAllocation, planForSave } from '../../lib/allocation';
import Mascot from '../../components/Mascot';
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
  const [salaryErr, setSalaryErr] = useState('');
  const [showPeak, setShowPeak] = useState(false);
  const peakAnim = useRef(new Animated.Value(0)).current;
  // The save amount the user types into the sweldo allocation. Empty means
  // "use the suggested amount"; once they type, their number wins.
  const [saveInput, setSaveInput] = useState('');

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

  // Pan's mood on the dashboard: worried when you are over your monthly
  // budget, a happy pop the moment a new entry is logged, idle otherwise.
  const budgetLimit = data.settings.monthlyLimit || 0;
  const overBudget = budgetLimit > 0 && moneyOut > budgetLimit;
  const [panHappy, setPanHappy] = useState(false);
  const prevTxCount = useRef(null);
  useEffect(() => {
    const n = data.transactions.length;
    const prev = prevTxCount.current;
    prevTxCount.current = n;
    if (prev !== null && n > prev) {
      setPanHappy(true);
      const t = setTimeout(() => setPanHappy(false), 1100);
      return () => clearTimeout(t);
    }
    return undefined;
  }, [data.transactions.length]);
  const panState = panHappy ? 'happy' : overBudget ? 'worried' : 'idle';

  // Safe to spend until sweldo: the daily question, answered from spendable
  // balances minus the bills that land before the next payday. Only shown
  // when there is at least one spendable (non savings) account to reason
  // about. The cycle bar shows how far through this pay period we are.
  const sts = useMemo(() => safeToSpend(data), [data]);
  const hasLiquid = (data.accounts || []).some((a) =>
    ['cash', 'ewallet', 'checking'].includes(a.kind)
  );
  const cycleStart = prevPayday(new Date(), data.settings.paydaySchedule);
  const cycleLen = Math.max(
    1,
    Math.round((sts.payday - new Date(cycleStart.getFullYear(), cycleStart.getMonth(), cycleStart.getDate())) / 86400000)
  );
  const cycleFrac = Math.max(0, Math.min(1, (cycleLen - sts.daysLeft) / cycleLen));
  const stsDate = `${MONTHS_SHORT[sts.payday.getMonth()]} ${sts.payday.getDate()}`;

  // Days to the next payday on the user's own schedule, with extra energy
  // in the final stretch.
  const paySchedule = data.settings.paydaySchedule;
  const payday = daysUntilPayday(new Date(), paySchedule);
  const paydaySoon = payday <= 3;
  const paydayCopy =
    payday === 0
      ? 'Payday today. Log that income first. 💸'
      : payday === 1
      ? 'Bukas na. 🤑'
      : paydaySoon
      ? 'Malapit na. Konting tiis. 💪'
      : `Based on ${scheduleLabel(paySchedule)}. Change it in More.`;

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

  // Unpaid utang, surfaced on home so collecting is one tap away. Partial
  // payments reduce what is still owed.
  const unpaid = (data.receivables || []).filter((r) => !r.paid);
  const owedToMe = unpaid.reduce((t, r) => {
    const paidSoFar = (r.payments || []).reduce((s, p) => s + (Number(p.amount) || 0), 0);
    return t + Math.max(0, (Number(r.amount) || 0) - paidSoFar);
  }, 0);
  const owedCount = unpaid.length;

  // The bills that land before the next sweldo, with a running balance so
  // the katapusan question, "will my money survive until payday?", is
  // answered bill by bill. This is the detail behind the safe to spend
  // number above.
  const commitments = useMemo(() => upcomingCommitments(data), [data]);
  let runBal = sts.liquid;
  const billRows = commitments.bills.map((b) => {
    runBal -= b.amount;
    return { ...b, after: runBal };
  });
  const endBalance = sts.liquid - commitments.total;

  // The sweldo plan: a guided three step card that appears for 48 hours
  // after each payday on the user's own schedule. The key is the payday's
  // date, so steps are remembered per payday and the card never nags twice.
  const now = new Date();
  const lastPay = prevPayday(now, paySchedule);
  const sincePay = Math.round(
    (new Date(now.getFullYear(), now.getMonth(), now.getDate()) - lastPay) / 86400000
  );
  const paydayKey = sincePay <= 1 ? todayISO(lastPay) : '';
  const savedPlan = data.settings.paydayPlan || {};
  const planSteps = savedPlan.key === paydayKey ? savedPlan.steps || {} : {};
  const planDone = planSteps.logged && planSteps.saved && planSteps.budget;

  // Completing a step earns a light buzz and a little spring on the card,
  // the same reward language logging uses.
  const planPop = useRef(new Animated.Value(1)).current;
  function markStep(step) {
    try {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
    } catch (e) {
      // Haptics are not available on web. That is fine.
    }
    planPop.setValue(0.97);
    Animated.spring(planPop, { toValue: 1, friction: 4, useNativeDriver: true }).start();
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
    setSalaryErr('');
    setSalaryModal(true);
  }
  function saveSalary() {
    const amount = Number(String(salaryAmount).replace(/[, ]/g, ''));
    if (!Number.isFinite(amount) || amount <= 0) {
      setSalaryErr('Enter an amount greater than 0.');
      return;
    }
    const entry = { type: 'income', label: 'Salary', amount, date: todayISO() };
    addTransaction(salaryAccount ? { ...entry, accountId: salaryAccount } : entry);
    if ((data.settings.salaryAccountId || '') !== salaryAccount) {
      updateSettings({ salaryAccountId: salaryAccount });
    }
    setSalaryModal(false);
    setSalaryAmount('');
    markStep('logged');
  }

  // The sweldo allocation: split this cycle's pay into bills, a savings-first
  // slice, and what is left to live on per day. A plan, not a transfer.
  const alloc = sweldoAllocation(data, now);
  const saveAmt = saveInput === '' ? alloc.save : Number(String(saveInput).replace(/[, ]/g, '')) || 0;
  const plan = planForSave(data, now, saveAmt);
  const allocPayday = alloc.payday ? `${MONTHS_SHORT[alloc.payday.getMonth()]} ${alloc.payday.getDate()}` : '';
  // Committing the plan marks the savings step done. It moves no money. It
  // remembers a new savings rate ONLY when the user actually chose an amount
  // that still leaves something to live on, so a high-bills cycle or a
  // fat-fingered number can never silently ratchet their ongoing rate down (or
  // up to an absurd value). An untouched confirm keeps their existing rate.
  function commitPlan() {
    if (saveInput !== '' && alloc.income > 0 && plan.save > 0 && plan.leftToLive > 0) {
      const pct = Math.min(Math.max(plan.save / alloc.income, 0), 0.9);
      updateSettings({ savePct: pct });
    }
    markStep('saved');
  }

  // A new payday cycle starts fresh: clear any amount typed last cycle so it
  // never carries a stale number (or a stale rate) into the next split.
  useEffect(() => { setSaveInput(''); }, [paydayKey]);

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
          <View style={{ flex: 1 }}>
            <Text style={styles.greeting}>{greeting}</Text>
            <Text style={styles.subgreeting}>Here is your money today</Text>
          </View>
          <Pressable onPress={() => router.push('/search')} hitSlop={10} style={styles.searchBtn}>
            <Ionicons name="search" size={22} color={colors.text} />
          </Pressable>
          <Mascot size={62} state={panState} />
        </View>

        {/* Sweldo plan: appears for 48 hours after each payday. Now a real
            allocation once the sweldo is logged, not just a checklist. */}
        {paydayKey && !planDone ? (
          <Animated.View style={[styles.planCard, { transform: [{ scale: planPop }] }]}>
            <Text style={styles.planKicker}>SWELDO PLAN</Text>
            <Text style={styles.planSub}>
              Payday! Plan this cycle before the money spends itself.
            </Text>

            {/* Step 1: log the sweldo. */}
            <Pressable onPress={planSteps.logged ? undefined : openSalary} style={styles.planRow}>
              <Ionicons
                name={planSteps.logged ? 'checkmark-circle' : 'ellipse-outline'}
                size={22}
                color={planSteps.logged ? colors.primary : colors.faint}
              />
              <Text style={[styles.planLabel, planSteps.logged && styles.planLabelDone]}>Log your sweldo</Text>
            </Pressable>

            {/* The allocation, once there is a sweldo to split. */}
            {planSteps.logged && alloc.hasIncome ? (
              <View style={styles.allocBox}>
                <Text style={styles.allocLead}>
                  Your {formatMoney(alloc.income)} sweldo, for the {alloc.daysLeft} days until {allocPayday}:
                </Text>
                <View style={styles.allocRow}>
                  <Text style={styles.allocKey}>Bills before then</Text>
                  <Text style={styles.allocVal}>{formatMoney(alloc.bills)}</Text>
                </View>
                <View style={styles.allocRow}>
                  <Text style={styles.allocKey}>Set aside to save</Text>
                  <TextInput
                    style={styles.allocInput}
                    value={saveInput === '' ? String(alloc.save) : saveInput}
                    onChangeText={setSaveInput}
                    keyboardType="numeric"
                    selectTextOnFocus
                    placeholderTextColor={colors.faint}
                  />
                </View>
                <View style={[styles.allocRow, styles.allocTotalRow]}>
                  <Text style={styles.allocKeyStrong}>Left to live on</Text>
                  <Text style={styles.allocValStrong}>{formatMoney(plan.leftToLive)}</Text>
                </View>
                <Text style={styles.allocPerDay}>
                  {plan.leftToLive > 0
                    ? `about ${formatMoney(plan.perDay)} a day`
                    : alloc.bills >= alloc.income
                    ? 'Bills use it all this cycle. Go gentle.'
                    : 'Your savings slice uses it all. Lower it to leave daily money.'}
                </Text>
                {planSteps.saved ? (
                  <Text style={styles.allocSet}>Plan set. ✅</Text>
                ) : (
                  <Pressable onPress={commitPlan} style={({ pressed }) => [styles.allocBtn, pressed && { opacity: 0.85 }]}>
                    <Text style={styles.allocBtnText}>Set my plan</Text>
                  </Pressable>
                )}
                <Text style={styles.allocNote}>A plan, not a transfer. Nothing moves out of your accounts.</Text>
              </View>
            ) : !planSteps.logged ? (
              <Text style={styles.allocHint}>Log your sweldo to see your split.</Text>
            ) : null}

            {/* Step 3: check the spending budget. */}
            <Pressable
              onPress={planSteps.budget ? undefined : () => { markStep('budget'); router.push('/budget'); }}
              style={styles.planRow}
            >
              <Ionicons
                name={planSteps.budget ? 'checkmark-circle' : 'ellipse-outline'}
                size={22}
                color={planSteps.budget ? colors.primary : colors.faint}
              />
              <Text style={[styles.planLabel, planSteps.budget && styles.planLabelDone]}>Check your spending budget</Text>
            </Pressable>
          </Animated.View>
        ) : null}
        {paydayKey && planDone ? (
          <View style={styles.planCard}>
            <Text style={styles.planKicker}>SWELDO PLAN</Text>
            <Text style={styles.planSub}>All three done. This cycle is planned. Nice one. ✅</Text>
          </View>
        ) : null}

        {/* Safe to spend until sweldo: the daily-open number. */}
        {hasLiquid ? (
          <View style={[styles.card, sts.available <= 0 && styles.safeTightCard]}>
            <Text style={styles.kicker}>SAFE TO SPEND</Text>
            {sts.available > 0 ? (
              <>
                <Text style={styles.safeBig}>
                  {formatMoney(Math.floor(sts.perDay))}
                  <Text style={styles.safeUnit}> /day</Text>
                </Text>
                <Text style={styles.safeSub}>
                  for the {sts.daysLeft} {sts.daysLeft === 1 ? 'day' : 'days'} until sweldo on {stsDate}
                </Text>
              </>
            ) : (
              <>
                <Text style={[styles.safeBig, { color: colors.warning }]}>Tight until sweldo</Text>
                <Text style={styles.safeSub}>bills before payday use up your spendable cash</Text>
              </>
            )}
            <View style={styles.cycleTrack}>
              <View style={[styles.cycleFill, { width: `${Math.round(cycleFrac * 100)}%` }]} />
            </View>
            <Text style={styles.safeDetail}>
              {sts.available > 0
                ? `You have ${formatMoney(sts.available)} free to spend${
                    sts.committed > 0
                      ? `, after setting aside ${formatMoney(sts.committed)} for ${sts.billCount} ${
                          sts.billCount === 1 ? 'bill' : 'bills'
                        } due before then`
                      : ''
                  }. Spendable cash means everything except savings.`
                : `${formatMoney(sts.committed)} in bills is due before sweldo on ${stsDate}, more than your ${formatMoney(
                    sts.liquid
                  )} spendable cash. Ease off until payday, or move some from savings.`}
            </Text>
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

        {/* Bills before the next sweldo, with a running balance. */}
        {billRows.length > 0 ? (
          <>
            <Text style={styles.sectionTitle}>BILLS BEFORE SWELDO</Text>
            <View style={styles.card}>
              {billRows.map((b, i) => (
                <View key={i} style={[styles.dueRow, i > 0 && styles.dueDivider]}>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.dueName}>{b.name}</Text>
                    <Text style={styles.dueWhen}>
                      {b.kind} · {MONTHS_SHORT[b.date.getMonth()]} {b.date.getDate()}
                    </Text>
                  </View>
                  <View style={{ alignItems: 'flex-end' }}>
                    <Text style={styles.dueAmount}>- {formatMoney(b.amount)}</Text>
                    <Text style={[styles.dueWhen, { color: b.after < 0 ? colors.warning : colors.faint }]}>
                      {formatMoney(b.after)} left
                    </Text>
                  </View>
                </View>
              ))}
              <Text style={[styles.dueHint, endBalance < 0 && { color: colors.warning }]}>
                {endBalance >= 0
                  ? `After these ${billRows.length} ${billRows.length === 1 ? 'bill' : 'bills'} you will have ${formatMoney(
                      endBalance
                    )} spendable before sweldo on ${stsDate}. Card minimums shown; pay in full when you can to skip interest.`
                  : `These bills total ${formatMoney(commitments.total)}, ${formatMoney(
                      -endBalance
                    )} more than your ${formatMoney(sts.liquid)} spendable cash. Move some from savings before they hit, or pay what you can.`}
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
            {salaryErr ? <Text style={styles.err}>{salaryErr}</Text> : null}
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
    searchBtn: {
      width: 40,
      height: 40,
      borderRadius: radius.pill,
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      alignItems: 'center',
      justifyContent: 'center',
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
    safeTightCard: { borderColor: colors.warning },
    safeBig: {
      color: colors.primary,
      fontSize: fontSize.huge,
      fontWeight: fontWeight.heavy,
      fontVariant: ['tabular-nums'],
      letterSpacing: -0.5,
      marginTop: spacing.xs,
    },
    safeUnit: { color: colors.muted, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, letterSpacing: 0 },
    safeSub: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: 2 },
    cycleTrack: {
      height: 6,
      borderRadius: radius.pill,
      backgroundColor: colors.border,
      overflow: 'hidden',
      marginTop: spacing.md,
    },
    cycleFill: { height: '100%', borderRadius: radius.pill, backgroundColor: colors.primary },
    safeDetail: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.sm, lineHeight: 19 },
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
    allocBox: { marginVertical: spacing.sm, paddingVertical: spacing.md, paddingHorizontal: spacing.md, backgroundColor: colors.background, borderRadius: radius.md, borderColor: colors.border, borderWidth: 1 },
    allocLead: { color: colors.textSecondary, fontSize: fontSize.small, marginBottom: spacing.sm, lineHeight: 18 },
    allocRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: spacing.xs, gap: spacing.md },
    allocKey: { color: colors.muted, fontSize: fontSize.small },
    allocVal: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    allocInput: { minWidth: 90, textAlign: 'right', color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium, paddingVertical: 4, paddingHorizontal: spacing.sm, backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.sm },
    allocTotalRow: { borderTopColor: colors.border, borderTopWidth: 1, marginTop: spacing.xs, paddingTop: spacing.sm },
    allocKeyStrong: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    allocValStrong: { color: colors.primary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    allocPerDay: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: 2 },
    allocBtn: { marginTop: spacing.md, backgroundColor: colors.primary, borderRadius: radius.md, paddingVertical: spacing.sm + 2, alignItems: 'center' },
    allocBtnText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    allocSet: { color: colors.primary, fontSize: fontSize.small, fontWeight: fontWeight.medium, marginTop: spacing.sm },
    allocNote: { color: colors.faint, fontSize: fontSize.caption, marginTop: spacing.sm },
    allocHint: { color: colors.muted, fontSize: fontSize.small, marginVertical: spacing.sm, marginLeft: 34 },

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
    err: { color: colors.warning, fontSize: fontSize.small, marginTop: spacing.sm },
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
