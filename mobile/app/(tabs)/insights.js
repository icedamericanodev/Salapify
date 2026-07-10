// Insights screen. Simple, readable charts built from plain views (no chart
// library yet, so nothing extra to install): income vs spending, spending by
// category, net worth by category, and a net worth trend built from real
// monthly snapshots taken whenever this screen is opened.

import { useEffect, useMemo, useState } from 'react';
import { Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../../theme';
import { useTheme } from '../../context/Theme';
import { useAppData } from '../../context/AppData';
import { formatMoney, monthLabel, todayISO, inPeriod, periodLabel, currentMonthPeriod } from '../../lib/format';
import { decisionCandidates, pickWin } from '../../lib/coach';
import PeriodSelector from '../../components/PeriodSelector';
import RecapShare from '../../components/RecapShare';
import Card from '../../components/Card';
import AnimatedNumber from '../../components/motion/AnimatedNumber';
import SectionHeader from '../../components/SectionHeader';
import Bar from '../../components/Bar';
import TrendChart from '../../components/TrendChart';
import {
  monthlySeries,
  categoryMovers,
  categoryVsAverage,
  weekdayPattern,
  savingsRate,
  forecastMonthEnd,
  healthScore,
  safeToSpend,
  emergencyRunway,
  utangAging,
  goalPace,
  netWorthParts,
} from '../../lib/analytics';

const WEEKDAY_LETTERS = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

export default function Insights() {
  const { colors, chartColors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter(); // lets a DO NEXT row open the right screen
  const { data, updateSettings } = useAppData(); // live data from the store
  const pro = !!(data.settings && data.settings.pro);

  // DO NEXT: the ranked "what to do right now". Same engine Home reads, so the
  // two never contradict. Free tier shows the top 3 with an always-present win.
  const actions = useMemo(() => decisionCandidates(data).slice(0, 3), [data]);
  const win = useMemo(() => pickWin(data), [data]);
  const openAction = (route) => {
    try { router.push(route); } catch (e) { /* a bad route must never crash Insights */ }
  };

  const sum = (list, fn) => list.reduce((t, x) => t + fn(x), 0);

  // The time slice the two spending cards below show: Month (default), Year, or a
  // Custom range. The net worth trend and forecasts lower down stay monthly by
  // nature, so only these cards read `period`.
  const [period, setPeriod] = useState(currentMonthPeriod());

  // Income vs spending for the chosen period. Utang collected (source
  // 'receivable') is not income, so it is excluded to match the income statement
  // and savings rate; otherwise the income bar would overstate money in.
  const inView = data.transactions.filter((t) => inPeriod(t.date, period));
  const moneyIn = sum(inView.filter((t) => t.type === 'income' && t.source !== 'receivable'), (t) => t.amount);
  const moneyOut = sum(inView.filter((t) => t.type === 'expense'), (t) => t.amount);

  // Spending by category, this month only. Entries tagged with a category
  // group under its name; untagged ones fall back to their label so nothing
  // disappears. Keys fold case so "food" and "Food" make one bar.
  // Object.create(null): a plain {} would let labels like __proto__ or
  // constructor collide with built in properties and vanish from the chart.
  const catNames = new Map((data.categories || []).map((c) => [c.id, c.name]));
  const catTotals = Object.create(null);
  for (const t of inView) {
    if (t.type !== 'expense') continue;
    const name =
      (t.categoryId && catNames.get(t.categoryId)) || (t.label || 'Other').trim() || 'Other';
    const key = name.toLowerCase();
    if (!catTotals[key]) catTotals[key] = { label: name, amount: 0 };
    catTotals[key].amount += t.amount;
  }
  const byCategory = Object.values(catTotals).sort((a, b) => b.amount - a.amount);

  // Where your money went, as one 100 percent proportion bar. A stacked bar is
  // the correct part-to-whole form here (deliberately not a pie or donut), done
  // with plain views so it stays web-safe. Distinct categories must read as
  // distinct hues, never shades of one color, so the top categories take the
  // validated categorical palette in FIXED slot order (chartColors[0], [1]...).
  // Everything past the top 7 folds into one neutral "more" segment in a gray
  // tone (colors.faint), which must never impersonate a real category hue.
  // Legend carries the labels, amounts, and percents.
  const totalSpent = byCategory.reduce((t, c) => t + c.amount, 0);
  const TOP_N = 7;
  const topCats = byCategory.slice(0, TOP_N);
  const restCats = byCategory.slice(TOP_N);
  const restSum = restCats.reduce((t, c) => t + c.amount, 0);
  const segments = topCats.map((c, i) => ({
    label: c.label,
    amount: c.amount,
    pct: totalSpent > 0 ? c.amount / totalSpent : 0,
    color: chartColors[i],
  }));
  if (restSum > 0) {
    segments.push({
      label: `${restCats.length} more`,
      amount: restSum,
      pct: restSum / totalSpent,
      color: colors.faint,
    });
  }
  // The one honest sentence that turns the chart into a decision.
  let catInsight = '';
  if (byCategory.length > 0 && totalSpent > 0) {
    const top = byCategory[0];
    const topPct = Math.round((top.amount / totalSpent) * 100);
    const nextTwo = byCategory.slice(1, 3).reduce((t, c) => t + c.amount, 0);
    const beatsNextTwo = byCategory.length >= 3 && top.amount > nextTwo;
    catInsight =
      `${top.label} is ${topPct}% of the ${formatMoney(totalSpent)} you spent in ${periodLabel(period)}` +
      (beatsNextTwo ? `, more than ${byCategory[1].label} and ${byCategory[2].label} combined.` : '.') +
      (topPct >= 40 ? ' If you want to trim, that is the lever.' : '');
  }

  // Net worth by category. The account side sums EVERY account, exactly like
  // the Overview headline, so the two screens can never disagree. Cash is the
  // cash-kind accounts; Bank is everything else in accounts (savings, checking,
  // e-wallet). sanitizeData coerces any unknown kind to cash on load, so in
  // practice nothing falls between the two buckets, but even if it did the Bank
  // = total minus cash formula keeps the breakdown summing to the headline, so
  // no account is ever silently dropped from net worth.
  const accountsTotal = sum(data.accounts, (a) => a.balance);
  const cash = sum(data.accounts.filter((a) => a.kind === 'cash'), (a) => a.balance);
  const bank = accountsTotal - cash;
  const investments = sum(data.assets, (a) => a.value);
  const debt = sum(data.debts, (d) => d.remaining);
  // Tracked (cash leg) utang belongs in net worth. Shown as its own rows only
  // when there is any, so the breakdown adds up to the headline either way.
  const nwParts = netWorthParts(data);
  const worthRows = [
    { label: 'Cash', amount: cash, color: colors.primary },
    { label: 'Bank', amount: bank, color: colors.primary },
    { label: 'Investments', amount: investments, color: colors.primary },
    ...(nwParts.receivables > 0 ? [{ label: 'Owed to you', amount: nwParts.receivables, color: colors.primary }] : []),
    { label: 'Debt', amount: debt, color: colors.warning },
    ...(nwParts.payables > 0 ? [{ label: 'You owe', amount: nwParts.payables, color: colors.warning }] : []),
  ];

  // A horizontal bar: label, a filled track sized by share of max, and amount.
  const HBar = ({ label, amount, max, color }) => (
    <View style={styles.hbarRow}>
      <Text style={styles.hbarLabel}>{label}</Text>
      <Bar
        fraction={max ? Math.max(amount / max, 0.02) : 0}
        color={color}
        height="md"
        style={styles.hbarBar}
      />
      <Text style={styles.hbarValue} numberOfLines={1} adjustsFontSizeToFit>{formatMoney(amount)}</Text>
    </View>
  );

  const worthMax = Math.max(...worthRows.map((w) => w.amount), 1);
  const inOutMax = Math.max(moneyIn, moneyOut, 1);

  // Real net worth history: the one shared formula (accounts plus assets, plus
  // tracked utang owed to you, minus debts and tracked utang you owe). Opening
  // this screen stamps this month's snapshot, so the trend grows one honest bar
  // per month. Until there are two real months, the card stays hidden.
  const netWorthNow = Math.round(nwParts.netWorth);
  // Array.isArray, not ||: a corrupt backup can carry nwHistory as a string
  // or object, and .filter on that would crash this screen on every mount.
  const nwHistory = (Array.isArray(data.settings.nwHistory) ? data.settings.nwHistory : []).filter(
    (h) => h && typeof h.month === 'string' && Number.isFinite(Number(h.value))
  );
  useEffect(() => {
    const key = todayISO().slice(0, 7);
    const cur = nwHistory.find((h) => h.month === key);
    if (!cur || Math.round(Number(cur.value)) !== netWorthNow) {
      const next = [
        ...nwHistory.filter((h) => h.month !== key),
        { month: key, value: netWorthNow },
      ]
        .sort((a, b) => a.month.localeCompare(b.month))
        .slice(-12);
      updateSettings({ nwHistory: next });
    }
  }, [netWorthNow]);
  const trendPoints = nwHistory.slice(-6).map((h) => ({
    month: h.month,
    value: Math.max(0, Number(h.value)),
    label: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][
      Math.max(0, Math.min(11, Number(h.month.slice(5, 7)) - 1))
    ],
  }));

  // What is already spoken for: the bills and minimums that land before the
  // next sweldo, against the money you can actually spend right now. Turns
  // the abstract balance into "this much is free to live on". Same engine as
  // the Overview Safe to spend card, shown here as the split.
  const sts = safeToSpend(data);
  const committedShare = sts.liquid > 0 ? Math.min(sts.committed / sts.liquid, 1) : sts.committed > 0 ? 1 : 0;
  const showCommitted = sts.liquid > 0 || sts.committed > 0;
  const paydayLabel = sts.payday
    ? sts.payday.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
    : '';
  let committedLine = '';
  if (showCommitted) {
    if (sts.available > 0) {
      committedLine =
        `${formatMoney(sts.committed)} of your ${formatMoney(sts.liquid)} is already committed to bills and minimums before ${paydayLabel}. ` +
        `That leaves ${formatMoney(sts.available)} to live on, about ${formatMoney(Math.round(sts.perDay))} a day for ${sts.daysLeft} days.`;
    } else {
      committedLine =
        `Bills and minimums due before ${paydayLabel} come to ${formatMoney(sts.committed)}, more than the ${formatMoney(sts.liquid)} you can spend right now. ` +
        `Nothing is free until sweldo, so hold off on anything you can.`;
    }
  }

  // Emergency fund runway: how long your accessible money would last. Free and
  // near the top, because a buffer is the CFP foundation everything else rests
  // on. The line meets the user where they are: no history, building the first
  // month, or already cushioned.
  const runway = emergencyRunway(data);
  const showRunway = runway.buffer > 0 || runway.monthsCovered != null;
  // Gate each rung on the real months-covered relationship, not the raw 10,000
  // floor, so a low spender with several months covered is never told to start
  // over, and a high spender with under a month is never called well covered.
  const moWord = runway.monthsCovered === 1 ? 'month' : 'months';
  // When capped, the real figure is above the cap, so read it as "12+ months"
  // rather than a precise number we do not actually trust from thin logging.
  const monthsLabel = runway.capped ? `${runway.monthsCovered}+` : `${runway.monthsCovered}`;
  let runwayLine = '';
  if (runway.monthsCovered == null) {
    runwayLine = runway.buffer > 0
      ? `You have ${formatMoney(runway.buffer)} set aside. Log two months of spending and I will show how long it would last.`
      : 'An emergency fund keeps a surprise from becoming utang. Even your first 10,000 helps.';
  } else if (runway.monthsCovered >= 3) {
    runwayLine = `About ${monthsLabel} months covered. That is a strong cushion, well done.`;
  } else if (runway.monthsCovered >= 1) {
    runwayLine = `About ${runway.monthsCovered} ${moWord} covered. Building toward 3 to 6 months is real peace of mind.`;
  } else if (runway.buffer < runway.firstTarget && runway.oneMonthTarget > runway.firstTarget) {
    runwayLine = `Your ${formatMoney(runway.buffer)} covers under a month. Aim for your first ${formatMoney(runway.firstTarget)}, then one full month, about ${formatMoney(runway.oneMonthTarget)}.`;
  } else {
    runwayLine = `Your ${formatMoney(runway.buffer)} covers under a month. Aim for one full month, about ${formatMoney(runway.oneMonthTarget)}, to stop most surprises from becoming debt.`;
  }

  // Utang, aged: who owes you, oldest debt first. The brand wedge, so it is
  // free, not Pro. Bars scale to the biggest single balance.
  const utang = utangAging(data);
  const utangTop = utang.people.slice(0, 5);
  const utangMax = Math.max(...utangTop.map((p) => p.outstanding), 1);
  let utangLine = '';
  if (utang.people.length > 0) {
    const w = utang.worst;
    if (w && w.daysOverdue > 0) {
      utangLine =
        `${w.name} has owed you ${formatMoney(w.outstanding)} for ${w.daysOverdue} ${w.daysOverdue === 1 ? 'day' : 'days'}. ` +
        `Follow up there first.`;
    } else {
      utangLine =
        `${formatMoney(utang.totalOutstanding)} is still out with ${utang.people.length} ${utang.people.length === 1 ? 'person' : 'people'}. ` +
        `Nothing is overdue yet, so a gentle reminder is enough.`;
    }
  }

  // Goal pace: every goal with the honest amount per month to finish on time.
  // Guard against a malformed backup carrying a null or id-less goal, which
  // would otherwise crash the whole screen on the goal.id key below.
  const goalRows = (data.goals || [])
    .filter((g) => g && typeof g === 'object' && g.id)
    .map((g) => ({ goal: g, pace: goalPace(g) }));

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.pageTitle}>Insights</Text>

        {/* DO NEXT: the hero decision card. Top few ranked money moves, with an
            always-present honest win at the bottom. Calm, not loud: a raised
            surface, a tone accent stripe, no shouting colors. Rows whose action
            already points at this screen (route '/insights': the supporting
            chart is below) render as plain stated decisions, not dead taps. */}
        <Card variant="raised" padding="xl" style={styles.cardGap}>
          <Text style={styles.kicker}>DO NEXT</Text>
          {actions.length > 0 ? (
            <View style={styles.doNextList}>
              {actions.map((a, i) => {
                // Tone accent only: warning for urgent, primary for watch/nudge.
                // Never a categorical chart hue; status colors stay reserved.
                const accent = a.tone === 'urgent' ? colors.warning : colors.primary;
                const route = a.action && a.action.route;
                // A row that would navigate to Insights (this very screen) is not
                // tappable: no onPress, no chevron, no button role, so it never
                // reads as a dead tap. It stays a fully accessible stated decision.
                const tappable = route && route !== '/insights';
                const inner = (
                  <>
                    <View style={[styles.doNextAccent, { backgroundColor: accent }]} importantForAccessibility="no" />
                    <View style={styles.doNextText}>
                      <Text style={styles.doNextTitle}>{a.title}</Text>
                      <Text style={styles.doNextMsg} numberOfLines={4}>{a.message}</Text>
                    </View>
                    {tappable ? (
                      <Ionicons name="chevron-forward" size={18} color={colors.faint} importantForAccessibility="no" />
                    ) : null}
                  </>
                );
                return tappable ? (
                  <Pressable
                    key={a.kind + i}
                    onPress={() => openAction(route)}
                    accessibilityRole="button"
                    accessibilityLabel={`${a.title}. ${a.message}`}
                    style={({ pressed }) => [styles.doNextRow, pressed && styles.doNextPressed]}
                  >
                    {inner}
                  </Pressable>
                ) : (
                  <View
                    key={a.kind + i}
                    accessible
                    accessibilityLabel={`${a.title}. ${a.message}`}
                    style={styles.doNextRow}
                  >
                    {inner}
                  </View>
                );
              })}
            </View>
          ) : (
            <View style={styles.doNextClear}>
              <Ionicons name="sparkles-outline" size={16} color={colors.celebrate} importantForAccessibility="no" />
              <View style={{ flex: 1 }}>
                <Text style={styles.doNextClearTitle}>You are on track</Text>
                <Text style={styles.doNextMsg}>Nothing needs a decision right now. Keep logging and enjoy the calm.</Text>
              </View>
            </View>
          )}
          {win ? (
            <View style={styles.winRow}>
              <Ionicons name="sparkles-outline" size={15} color={colors.celebrate} importantForAccessibility="no" />
              <Text style={styles.winText}>{win.text}</Text>
            </View>
          ) : null}
        </Card>

        {/* PeriodSelector carries its own bottom margin, so the wrapper only
            adds the top gap from the card above (no double spacing). */}
        <View style={{ marginTop: spacing.md }}>
          <PeriodSelector period={period} onChange={setPeriod} colors={colors} />
        </View>

        <Card variant="flat" padding="xl" style={styles.cardGap}>
          <Text style={styles.kicker}>INCOME VS SPENDING ({periodLabel(period).toUpperCase()})</Text>
          <View style={styles.cardBody}>
            <HBar label="In" amount={moneyIn} max={inOutMax} color={colors.primary} />
            <HBar label="Out" amount={moneyOut} max={inOutMax} color={colors.textSecondary} />
          </View>
        </Card>

        <Card variant="flat" padding="xl" style={styles.cardGap}>
          <Text style={styles.kicker}>WHERE YOUR MONEY WENT ({periodLabel(period).toUpperCase()})</Text>
          {byCategory.length > 0 && totalSpent > 0 ? (
            <>
              <View
                style={styles.propBar}
                accessibilityElementsHidden
                importantForAccessibility="no-hide-descendants"
              >
                {segments.map((s, i) => (
                  <View
                    key={s.label + i}
                    style={{
                      width: `${Math.max(s.pct * 100, 1)}%`,
                      backgroundColor: s.color,
                      // A 2px card-colored gap separates adjacent segments so
                      // touching categories never blur together (the required
                      // secondary encoding alongside the legend). Not on the
                      // last segment, so the bar ends flush.
                      borderRightWidth: i < segments.length - 1 ? 2 : 0,
                      borderRightColor: colors.card,
                    }}
                  />
                ))}
              </View>
              <View style={styles.legend}>
                {segments.map((s, i) => (
                  <View
                    key={s.label + i}
                    style={styles.legendRow}
                    accessible
                    accessibilityLabel={`${s.label}, ${formatMoney(s.amount)}, ${Math.round(s.pct * 100)} percent`}
                  >
                    <View style={styles.legendLeft}>
                      <View style={[styles.legendDot, { backgroundColor: s.color }]} importantForAccessibility="no" />
                      <Text style={styles.legendLabel} numberOfLines={1}>{s.label}</Text>
                    </View>
                    <Text style={styles.legendVal}>
                      {formatMoney(s.amount)} · {Math.round(s.pct * 100)}%
                    </Text>
                  </View>
                ))}
              </View>
              {catInsight ? <Text style={styles.insightLine}>{catInsight}</Text> : null}
            </>
          ) : (
            <Text style={styles.proNote}>Nothing spent in {periodLabel(period)} yet. Log an expense and the breakdown appears.</Text>
          )}
        </Card>

        <Card variant="flat" padding="xl" style={styles.cardGap}>
          <Text style={styles.kicker}>NET WORTH BY CATEGORY</Text>
          <View style={styles.cardBody}>
            {worthRows.map((w) => (
              <HBar key={w.label} label={w.label} amount={w.amount} max={worthMax} color={w.color} />
            ))}
          </View>
        </Card>

        {trendPoints.length >= 2 ? (
          <Card variant="flat" padding="xl" style={styles.cardGap}>
            <Text style={styles.kicker}>NET WORTH TREND</Text>
            <TrendChart
              series={[{ color: colors.primary, values: trendPoints.map((p) => p.value) }]}
              labels={trendPoints.map((p) => p.label)}
              height={140}
              accessibilityLabel={`Net worth trend: ${trendPoints
                .map((p) => `${p.label} ${formatMoney(p.value)}`)
                .join(', ')}`}
            />
            <Text style={styles.trendNow}>Now: {formatMoney(netWorthNow)}</Text>
          </Card>
        ) : null}

        {showCommitted ? (
          <Card variant="flat" padding="xl" style={styles.cardGap}>
            <Text style={styles.kicker}>WHAT IS ALREADY SPOKEN FOR</Text>
            <View
              style={styles.propBar}
              accessibilityElementsHidden
              importantForAccessibility="no-hide-descendants"
            >
              <View
                style={{
                  width: `${Math.max(committedShare * 100, 1)}%`,
                  backgroundColor: colors.warning,
                  // A 2px card-colored gap so Committed and Free never touch
                  // flush, matching the "where your money went" bar. Only when
                  // the Free slice actually renders.
                  borderRightWidth: sts.available > 0 ? 2 : 0,
                  borderRightColor: colors.card,
                }}
              />
              {sts.available > 0 ? (
                <View style={{ width: `${Math.max((1 - committedShare) * 100, 1)}%`, backgroundColor: colors.primary }} />
              ) : null}
            </View>
            <View style={styles.legend}>
              <View
                style={styles.legendRow}
                accessible
                accessibilityLabel={`Committed, ${formatMoney(sts.committed)}`}
              >
                <View style={styles.legendLeft}>
                  <View style={[styles.legendDot, { backgroundColor: colors.warning }]} importantForAccessibility="no" />
                  <Text style={styles.legendLabel}>Committed</Text>
                </View>
                <Text style={styles.legendVal}>{formatMoney(sts.committed)}</Text>
              </View>
              <View
                style={styles.legendRow}
                accessible
                accessibilityLabel={`${sts.available > 0 ? 'Free to spend' : 'Short'}, ${formatMoney(Math.abs(sts.available))}`}
              >
                <View style={styles.legendLeft}>
                  <View style={[styles.legendDot, { backgroundColor: colors.primary }]} importantForAccessibility="no" />
                  <Text style={styles.legendLabel}>{sts.available > 0 ? 'Free to spend' : 'Short'}</Text>
                </View>
                <Text style={styles.legendVal}>{formatMoney(Math.abs(sts.available))}</Text>
              </View>
            </View>
            {committedLine ? <Text style={styles.insightLine}>{committedLine}</Text> : null}
          </Card>
        ) : null}

        {showRunway ? (
          <Card variant="flat" padding="xl" style={styles.cardGap}>
            <Text style={styles.kicker}>EMERGENCY FUND RUNWAY</Text>
            {runway.monthsCovered != null ? (
              <>
                <Text style={styles.runwayValue}>
                  {monthsLabel} {runway.monthsCovered === 1 ? 'month' : 'months'} covered
                </Text>
                <Bar
                  fraction={Math.max(Math.min(runway.monthsCovered / 3, 1), 0.01)}
                  color={colors.primary}
                  height="lg"
                  style={styles.barSpaced}
                />
                <Text style={styles.runwaySub}>Goal: 3 to 6 months of expenses</Text>
              </>
            ) : (
              <Text style={styles.runwayValue}>{formatMoney(runway.buffer)} set aside</Text>
            )}
            {runwayLine ? <Text style={styles.insightLine}>{runwayLine}</Text> : null}
          </Card>
        ) : null}

        {utang.people.length > 0 ? (
          <Card variant="flat" padding="xl" style={styles.cardGap}>
            <Text style={styles.kicker}>UTANG: WHO OWES YOU</Text>
            <View style={styles.cardBody}>
              {utangTop.map((p) => (
                <View key={p.personId || p.name} style={styles.utangRow}>
                  <View style={styles.utangHead}>
                    <Text style={styles.moverLabel} numberOfLines={1}>{p.name}</Text>
                    <Text style={styles.utangAmt}>{formatMoney(p.outstanding)}</Text>
                  </View>
                  <Bar
                    fraction={Math.max(p.outstanding / utangMax, 0.02)}
                    color={p.daysOverdue > 0 ? colors.warning : colors.primary}
                    height="md"
                  />
                  <Text style={styles.utangSub}>
                    {p.daysOverdue > 0
                      ? `${p.daysOverdue} ${p.daysOverdue === 1 ? 'day' : 'days'} overdue`
                      : p.oldestDue
                      ? `due ${p.oldestDue}`
                      : 'no due date set'}
                    {p.count > 1 ? ` . ${p.count} utang` : ''}
                  </Text>
                </View>
              ))}
            </View>
            {utangLine ? <Text style={styles.insightLine}>{utangLine}</Text> : null}
          </Card>
        ) : null}

        {goalRows.length > 0 ? (
          <Card variant="flat" padding="xl" style={styles.cardGap}>
            <Text style={styles.kicker}>GOAL PACE</Text>
            <View style={styles.cardBody}>
              {goalRows.map(({ goal, pace }) => (
                <View key={goal.id} style={styles.utangRow}>
                  <View style={styles.utangHead}>
                    <Text style={styles.moverLabel} numberOfLines={1}>{goal.name}</Text>
                    <Text style={styles.goalPct}>{Math.round(pace.pct * 100)}%</Text>
                  </View>
                  <Bar
                    fraction={Math.max(pace.pct, 0.02)}
                    color={pace.status === 'behind' ? colors.warning : colors.primary}
                    height="md"
                  />
                  <Text style={[styles.utangSub, pace.status === 'behind' && { color: colors.warning }]}>
                    {pace.status === 'done'
                      ? 'Funded. 🎉'
                      : pace.status === 'behind'
                      ? `Behind: ${formatMoney(pace.remaining)} still to go, the target date has passed.`
                      : pace.status === 'due-soon'
                      ? `Due this month: ${formatMoney(pace.remaining)} still to go.`
                      : pace.status === 'active'
                      ? `Save ${formatMoney(pace.perMonth)} a month (${formatMoney(pace.perWeek)} a week) to hit it by ${pace.targetDate}.`
                      : pace.status === 'no-target'
                      ? 'Set a target amount to track this goal.'
                      : `${formatMoney(pace.remaining)} to go. Add a target date to get a monthly pace.`}
                  </Text>
                </View>
              ))}
            </View>
          </Card>
        ) : null}

        {/* ---- Pro analytics: the deep analysis tier ---- */}
        <SectionHeader title="PRO ANALYTICS" trailing={<Text style={styles.proBadge}>PRO</Text>} />
        {!pro ? (
          <Card variant="flat" padding="xl" style={styles.cardGap}>
            <Text style={styles.lockTitle}>See the patterns behind your money</Text>
            <Text style={styles.lockLine}>Financial health score out of 100</Text>
            <Text style={styles.lockLine}>Six month income and spending trend</Text>
            <Text style={styles.lockLine}>Month end forecast and savings rate</Text>
            <Text style={styles.lockLine}>Category movers vs last month</Text>
            <Text style={styles.lockLine}>Your weekday spending pattern</Text>
            <Text style={styles.lockLine}>Debt free date with interest saved (in Reports)</Text>
            <Pressable
              onPress={() => updateSettings({ pro: true })}
              style={({ pressed }) => [styles.unlockBtn, pressed && { opacity: 0.7 }]}
            >
              <Text style={styles.unlockText}>Unlock free during early access</Text>
            </Pressable>
            <Text style={styles.lockHint}>Pro will be a one time purchase at launch. Early users keep it free.</Text>
          </Card>
        ) : (
          <>
            <ProInsights data={data} styles={styles} colors={colors} chartColors={chartColors} />
          </>
        )}

        {Platform.OS !== 'web' ? <RecapShare data={data} /> : null}

        <Text style={styles.footnote}>
          Charts show {monthLabel()}.
          {trendPoints.length >= 2
            ? ' The net worth trend snapshots each month you open Insights.'
            : ' Come back next month and your real net worth trend starts here.'}
        </Text>
      </ScrollView>
    </SafeAreaView>
  );
}

// The Pro cards: computed fresh from the store on every render.
function ProInsights({ data, styles, colors, chartColors }) {
  // Two distinct, calm categorical hues for the income vs spending series.
  // Income is the green slot (reads as money-in); spending is the violet
  // slot. Neither is red or orange: warning hues are reserved for debt and
  // over-limit, so expense must never wear one.
  const incomeColor = chartColors[1]; // green
  const expenseColor = chartColors[4]; // violet
  const score = healthScore(data);
  const series = monthlySeries(data.transactions, 6);
  const movers = categoryMovers(data.transactions);
  const vsAvg = categoryVsAverage(data.transactions);
  const vsAvgMax = Math.max(...vsAvg.map((v) => Math.max(v.now, v.avg)), 1);
  const rate = savingsRate(data.transactions, data.payments);
  const fc = forecastMonthEnd(data.transactions);
  const limit = (data.settings && data.settings.monthlyLimit) || 0;
  const wk = weekdayPattern(data.transactions);
  const wkMax = Math.max(...wk.map((w) => w.avg), 1);
  const topDay = wk.reduce((best, w) => (w.avg > best.avg ? w : best), wk[0]);
  const DAY_NAMES = ['Sundays', 'Mondays', 'Tuesdays', 'Wednesdays', 'Thursdays', 'Fridays', 'Saturdays'];

  return (
    <>
      <Card variant="raised" padding="xl" style={styles.cardGap}>
        <Text style={styles.kicker}>FINANCIAL HEALTH SCORE</Text>
        {/* Group the number and the "/ 100" into one spoken unit with a real
            label, and hide the descendants, so a screen reader reads one clean
            fact instead of an "edit box" then a floating "/ 100". */}
        <View
          style={styles.scoreRow}
          accessible={true}
          accessibilityLabel={`Financial health score ${score.total} out of 100`}
          importantForAccessibility="no-hide-descendants"
        >
          <AnimatedNumber
            value={score.total}
            money={false}
            style={styles.scoreBig}
            accessible={false}
            importantForAccessibility="no-hide-descendants"
          />
          <Text style={styles.scoreOf}>/ 100</Text>
        </View>
        <View style={styles.partRow}><Text style={styles.partLabel}>Savings rate</Text><Text style={styles.partVal}>{score.parts.savings}/35</Text></View>
        <View style={styles.partRow}><Text style={styles.partLabel}>Budget discipline</Text><Text style={styles.partVal}>{score.parts.budget}/25</Text></View>
        <View style={styles.partRow}><Text style={styles.partLabel}>Debt load</Text><Text style={styles.partVal}>{score.parts.debt}/25</Text></View>
        <View style={styles.partRow}><Text style={styles.partLabel}>Logging habit</Text><Text style={styles.partVal}>{score.parts.logging}/15</Text></View>
      </Card>

      <Card variant="flat" padding="xl" style={styles.cardGap}>
        <Text style={styles.kicker}>SIX MONTH TREND</Text>
        <View style={styles.chartLegend}>
          <View style={styles.chartLegendItem}>
            <View style={[styles.chartLegendSwatch, { backgroundColor: incomeColor }]} />
            <Text style={styles.chartLegendText}>Income</Text>
          </View>
          <View style={styles.chartLegendItem}>
            <View style={[styles.chartLegendSwatch, { backgroundColor: expenseColor }]} />
            <Text style={styles.chartLegendText}>Spending</Text>
          </View>
        </View>
        <TrendChart
          series={[
            { color: incomeColor, values: series.map((m) => m.income) },
            { color: expenseColor, values: series.map((m) => m.expenses) },
          ]}
          labels={series.map((m) => m.label)}
          height={140}
          accessibilityLabel={`Six month trend: ${series
            .map((m) => `${m.label} income ${formatMoney(m.income)}, spending ${formatMoney(m.expenses)}`)
            .join('. ')}`}
        />
        <Text style={styles.proNote}>Net this month: {formatMoney(series[series.length - 1].net)}.</Text>
      </Card>

      <Card variant="flat" padding="xl" style={styles.cardGap}>
        <Text style={styles.kicker}>THIS MONTH, AT THIS PACE</Text>
        <Text style={styles.forecastBig}>{formatMoney(fc.projected)}</Text>
        <Text style={styles.proNote}>
          Projected month end spending{limit > 0 ? ` against your ${formatMoney(limit)} budget` : ''}.
          {limit > 0 && fc.projected > limit ? ' Ease off a little.' : ''}
          {rate !== null ? ` Savings rate so far: ${Math.round(rate * 100)}% of income kept.` : ''}
        </Text>
      </Card>

      {vsAvg.length > 0 ? (
        <Card variant="flat" padding="xl" style={styles.cardGap}>
          <Text style={styles.kicker}>THIS MONTH VS YOUR 6 MONTH NORMAL</Text>
          <View style={styles.cardBody}>
            {vsAvg.map((v) => {
              // Verdicts compare against the pace adjusted expectation, so
              // early in the month nothing gets a free "below normal".
              const over = v.expected > 0 && v.now > v.expected * 1.2;
              const under = v.expected > 0 && v.now < v.expected * 0.8;
              return (
                <View key={v.label}>
                  <View style={styles.vsHead}>
                    <Text style={styles.moverLabel}>{v.label}</Text>
                    <Text style={[styles.vsVerdict, { color: over ? colors.warning : under ? colors.primary : colors.muted }]}>
                      {v.avg === 0 ? 'new' : over ? 'above normal' : under ? 'below normal' : 'on track'}
                    </Text>
                  </View>
                  <Bar
                    fraction={Math.max(v.now / vsAvgMax, 0.01)}
                    color={over ? colors.warning : colors.primary}
                    height="sm"
                    style={styles.vsBarGap}
                  />
                  <Bar
                    fraction={Math.max(v.avg / vsAvgMax, 0.01)}
                    color={colors.muted}
                    height="sm"
                    style={styles.vsBarGap}
                  />
                  <Text style={styles.vsNums}>
                    {formatMoney(v.now)} now, usually {formatMoney(Math.round(v.avg))}
                  </Text>
                </View>
              );
            })}
          </View>
        </Card>
      ) : null}

      {movers.length > 0 ? (
        <Card variant="flat" padding="xl" style={styles.cardGap}>
          <Text style={styles.kicker}>MOVERS VS LAST MONTH</Text>
          <View style={styles.cardBody}>
            {movers.map((mv) => (
              <View key={mv.label} style={styles.moverRow}>
                <Text style={styles.moverLabel}>{mv.label}</Text>
                <Text style={[styles.moverVal, { color: mv.change > 0 ? colors.textSecondary : colors.primary }]}>
                  {mv.change > 0 ? '+' : '-'}{formatMoney(Math.abs(mv.change))}
                </Text>
              </View>
            ))}
          </View>
        </Card>
      ) : null}

      <Card variant="flat" padding="xl" style={styles.cardGap}>
        <Text style={styles.kicker}>YOUR WEEK IN SPENDING</Text>
        <View style={styles.trend}>
          {wk.map((w, i) => (
            <View key={i} style={styles.trendCol}>
              <View style={[styles.wkBar, { height: Math.max((w.avg / wkMax) * 90, 3), backgroundColor: w.day === topDay.day && w.avg > 0 ? colors.primary : colors.muted }]} />
              <Text style={styles.trendLabel}>{WEEKDAY_LETTERS[i]}</Text>
            </View>
          ))}
        </View>
        {topDay.avg > 0 ? (
          <Text style={styles.proNote}>You spend the most on {DAY_NAMES[topDay.day]} ({formatMoney(Math.round(topDay.avg))} on average).</Text>
        ) : (
          <Text style={styles.proNote}>Log a few weeks of spending and your pattern appears here.</Text>
        )}
      </Card>
    </>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },
    pageTitle: {
      color: colors.text,
      fontSize: fontSize.title,
      fontWeight: fontWeight.heavy,
      marginBottom: spacing.md,
    },

    // Every card on this screen is now the shared <Card> component, which owns its
    // own surface, radius, padding, and depth. The parent only supplies the gap
    // below each one, so the vertical rhythm stays even.
    cardGap: { marginBottom: spacing.lg },
    kicker: {
      color: colors.softGreen,
      fontSize: fontSize.caption,
      fontWeight: fontWeight.medium,
      letterSpacing: 1.2,
    },
    cardBody: { marginTop: spacing.md, gap: spacing.md },

    // DO NEXT card. Each row is a tappable decision: a tone accent stripe, the
    // title and one-line message, and a chevron. Calm surface, honest 44pt tap
    // target, subtle pressed dip.
    doNextList: { marginTop: spacing.md, gap: spacing.sm },
    doNextRow: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: spacing.md,
      minHeight: 44,
      paddingVertical: spacing.sm,
    },
    doNextPressed: { opacity: 0.7 },
    doNextAccent: { width: 4, alignSelf: 'stretch', borderRadius: radius.pill },
    doNextText: { flex: 1, minWidth: 0 },
    doNextTitle: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    doNextMsg: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 19, marginTop: 2 },
    doNextClear: { flexDirection: 'row', alignItems: 'flex-start', gap: spacing.sm, marginTop: spacing.md },
    doNextClearTitle: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold, marginBottom: 2 },
    winRow: {
      flexDirection: 'row',
      alignItems: 'flex-start',
      gap: spacing.sm,
      marginTop: spacing.lg,
      paddingTop: spacing.md,
      borderTopColor: colors.border,
      borderTopWidth: StyleSheet.hairlineWidth,
    },
    winText: { color: colors.textSecondary, fontSize: fontSize.small, flex: 1, lineHeight: 19 },

    // propBar stays for the two genuinely multi-segment bars (where your money
    // went, and what is already spoken for): several colored slices side by side.
    // The single-fraction <Bar> is not built for that, so those remain here.
    propBar: {
      flexDirection: 'row',
      height: 16,
      borderRadius: radius.pill,
      overflow: 'hidden',
      marginTop: spacing.md,
      backgroundColor: colors.border,
    },
    // Spacing for a standalone <Bar> that sits under a headline value.
    barSpaced: { marginTop: spacing.md },
    legend: { marginTop: spacing.md, gap: spacing.sm },
    legendRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: spacing.sm },
    legendLeft: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, flex: 1, minWidth: 0 },
    legendDot: { width: 11, height: 11, borderRadius: 3, flex: 0 },
    legendLabel: { color: colors.textSecondary, fontSize: fontSize.small, flexShrink: 1 },
    legendVal: { color: colors.text, fontSize: fontSize.small, fontWeight: fontWeight.bold, fontVariant: ['tabular-nums'] },
    insightLine: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 20, marginTop: spacing.lg },
    runwayValue: { color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.heavy, marginBottom: spacing.md },
    runwaySub: { color: colors.muted, fontSize: fontSize.caption, marginTop: spacing.sm },

    hbarRow: { flexDirection: 'row', alignItems: 'center' },
    hbarLabel: { color: colors.textSecondary, fontSize: fontSize.small, width: 92 },
    // The shared <Bar> grows to fill the row between the label and the value.
    hbarBar: { flex: 1, marginHorizontal: spacing.sm },
    hbarValue: {
      color: colors.text,
      fontSize: fontSize.small,
      fontWeight: fontWeight.bold,
      width: 72,
      textAlign: 'right',
    },

    trend: {
      flexDirection: 'row',
      alignItems: 'flex-end',
      justifyContent: 'space-between',
      height: 140,
      marginTop: spacing.md,
    },
    trendCol: { alignItems: 'center', flex: 1 },
    trendLabel: { color: colors.muted, fontSize: fontSize.caption, marginTop: spacing.xs },
    trendNow: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.md },

    proBadge: { color: colors.celebrate, fontSize: fontSize.caption, fontWeight: fontWeight.heavy, letterSpacing: 1.2 },
    lockTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginBottom: spacing.md },
    lockLine: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.xs },
    unlockBtn: { backgroundColor: colors.primary, borderRadius: radius.md, minHeight: 48, alignItems: 'center', justifyContent: 'center', marginTop: spacing.lg },
    unlockText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    lockHint: { color: colors.faint, fontSize: fontSize.small, marginTop: spacing.sm },
    scoreRow: { flexDirection: 'row', alignItems: 'flex-end', gap: spacing.sm, marginTop: spacing.xs, marginBottom: spacing.sm },
    scoreBig: { color: colors.primary, fontSize: fontSize.display, fontWeight: fontWeight.heavy, fontVariant: ['tabular-nums'] },
    scoreOf: { color: colors.muted, fontSize: fontSize.subtitle, marginBottom: 8 },
    partRow: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: spacing.xs },
    partLabel: { color: colors.textSecondary, fontSize: fontSize.small },
    partVal: { color: colors.text, fontSize: fontSize.small, fontWeight: fontWeight.bold, fontVariant: ['tabular-nums'] },
    // A small swatch + label legend, the honest key for a multi-series chart.
    chartLegend: { flexDirection: 'row', gap: spacing.lg, marginTop: spacing.md },
    chartLegendItem: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
    chartLegendSwatch: { width: 11, height: 11, borderRadius: 3 },
    chartLegendText: { color: colors.textSecondary, fontSize: fontSize.small },
    proNote: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.md },
    forecastBig: { color: colors.text, fontSize: fontSize.big, fontWeight: fontWeight.heavy, fontVariant: ['tabular-nums'], marginTop: spacing.xs },
    moverRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: spacing.xs },
    moverLabel: { color: colors.text, fontSize: fontSize.body },
    vsHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: spacing.xs },
    vsVerdict: { fontSize: fontSize.caption, fontWeight: fontWeight.medium },
    // The now/normal pair of <Bar>s each carry this small gap under them.
    vsBarGap: { marginBottom: 3 },
    vsNums: { color: colors.muted, fontSize: fontSize.caption },
    moverVal: { fontSize: fontSize.body, fontWeight: fontWeight.bold, fontVariant: ['tabular-nums'] },
    wkBar: { width: 16, borderRadius: 4 },

    utangRow: { gap: spacing.xs },
    utangHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: spacing.sm },
    utangAmt: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold, fontVariant: ['tabular-nums'] },
    utangSub: { color: colors.muted, fontSize: fontSize.caption },
    goalPct: { color: colors.softGreen, fontSize: fontSize.body, fontWeight: fontWeight.bold, fontVariant: ['tabular-nums'] },

    footnote: {
      color: colors.faint,
      fontSize: fontSize.small,
      textAlign: 'center',
      marginTop: spacing.sm,
    },
  });
}
