// Insights screen. Simple, readable charts built from plain views (no chart
// library yet, so nothing extra to install): income vs spending, spending by
// category, net worth by category, and a net worth trend built from real
// monthly snapshots taken whenever this screen is opened.

import { useEffect, useMemo } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { spacing, radius, fontSize, fontWeight } from '../../theme';
import { useTheme } from '../../context/Theme';
import { useAppData } from '../../context/AppData';
import { formatMoney, isThisMonth, monthLabel, todayISO } from '../../lib/format';
import {
  monthlySeries,
  categoryMovers,
  categoryVsAverage,
  weekdayPattern,
  savingsRate,
  forecastMonthEnd,
  healthScore,
  safeToSpend,
  utangAging,
  goalPace,
} from '../../lib/analytics';

const WEEKDAY_LETTERS = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

export default function Insights() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const { data, updateSettings } = useAppData(); // live data from the store
  const pro = !!(data.settings && data.settings.pro);

  const sum = (list, fn) => list.reduce((t, x) => t + fn(x), 0);

  // Income vs spending, this month only.
  const thisMonth = data.transactions.filter((t) => isThisMonth(t.date));
  const moneyIn = sum(thisMonth.filter((t) => t.type === 'income'), (t) => t.amount);
  const moneyOut = sum(thisMonth.filter((t) => t.type === 'expense'), (t) => t.amount);

  // Spending by category, this month only. Entries tagged with a category
  // group under its name; untagged ones fall back to their label so nothing
  // disappears. Keys fold case so "food" and "Food" make one bar.
  // Object.create(null): a plain {} would let labels like __proto__ or
  // constructor collide with built in properties and vanish from the chart.
  const catNames = new Map((data.categories || []).map((c) => [c.id, c.name]));
  const catTotals = Object.create(null);
  for (const t of thisMonth) {
    if (t.type !== 'expense') continue;
    const name =
      (t.categoryId && catNames.get(t.categoryId)) || (t.label || 'Other').trim() || 'Other';
    const key = name.toLowerCase();
    if (!catTotals[key]) catTotals[key] = { label: name, amount: 0 };
    catTotals[key].amount += t.amount;
  }
  const byCategory = Object.values(catTotals).sort((a, b) => b.amount - a.amount);

  // Where your money went, as one 100 percent proportion bar (the pie, done
  // with plain views so it ships now; a true donut arrives with the chart
  // rebuild). Top six categories get their own segment shaded from the brand
  // color, so the bar always matches whatever theme is chosen; the rest fold
  // into one muted "more" segment. Legend carries the labels and amounts.
  const totalSpent = byCategory.reduce((t, c) => t + c.amount, 0);
  const TOP_N = 6;
  const topCats = byCategory.slice(0, TOP_N);
  const restCats = byCategory.slice(TOP_N);
  const restSum = restCats.reduce((t, c) => t + c.amount, 0);
  const SEG_ALPHA = ['FF', 'D9', 'B8', '99', '7A', '5E'];
  const segments = topCats.map((c, i) => ({
    label: c.label,
    amount: c.amount,
    pct: totalSpent > 0 ? c.amount / totalSpent : 0,
    color: `${colors.primary}${SEG_ALPHA[i] || '5E'}`,
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
      `${top.label} is ${topPct}% of the ${formatMoney(totalSpent)} you spent this month` +
      (beatsNextTwo ? `, more than ${byCategory[1].label} and ${byCategory[2].label} combined.` : '.') +
      (topPct >= 40 ? ' If you want to trim, that is the lever.' : '');
  }

  // Net worth by category.
  const cash = sum(data.accounts.filter((a) => a.kind === 'cash'), (a) => a.balance);
  const bank = sum(
    data.accounts.filter((a) => ['savings', 'checking', 'ewallet'].includes(a.kind)),
    (a) => a.balance
  );
  const investments = sum(data.assets, (a) => a.value);
  const debt = sum(data.debts, (d) => d.remaining);
  const worthRows = [
    { label: 'Cash', amount: cash, color: colors.primary },
    { label: 'Bank', amount: bank, color: colors.primary },
    { label: 'Investments', amount: investments, color: colors.primary },
    { label: 'Debt', amount: debt, color: colors.warning },
  ];

  // A horizontal bar: label, a filled track sized by share of max, and amount.
  const HBar = ({ label, amount, max, color }) => (
    <View style={styles.hbarRow}>
      <Text style={styles.hbarLabel}>{label}</Text>
      <View style={styles.hbarTrack}>
        <View
          style={[
            styles.hbarFill,
            { width: `${max ? Math.max((amount / max) * 100, 2) : 0}%`, backgroundColor: color },
          ]}
        />
      </View>
      <Text style={styles.hbarValue}>{formatMoney(amount)}</Text>
    </View>
  );

  const worthMax = Math.max(...worthRows.map((w) => w.amount), 1);
  const inOutMax = Math.max(moneyIn, moneyOut, 1);

  // Real net worth history: same formula as the Overview headline
  // (accounts plus assets minus debts). Opening this screen stamps this
  // month's snapshot, so the trend grows one honest bar per month. Until
  // there are two real months, the card stays hidden, no made up bars.
  const netWorthNow = Math.round(cash + bank + investments - debt);
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
  const trendMax = Math.max(...trendPoints.map((p) => p.value), 1);

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

        <View style={styles.card}>
          <Text style={styles.kicker}>INCOME VS SPENDING ({monthLabel().toUpperCase()})</Text>
          <View style={styles.cardBody}>
            <HBar label="In" amount={moneyIn} max={inOutMax} color={colors.primary} />
            <HBar label="Out" amount={moneyOut} max={inOutMax} color={colors.warning} />
          </View>
        </View>

        <View style={styles.card}>
          <Text style={styles.kicker}>WHERE YOUR MONEY WENT ({monthLabel().toUpperCase()})</Text>
          {byCategory.length > 0 && totalSpent > 0 ? (
            <>
              <View style={styles.propBar}>
                {segments.map((s, i) => (
                  <View
                    key={s.label + i}
                    style={{ width: `${Math.max(s.pct * 100, 1)}%`, backgroundColor: s.color }}
                  />
                ))}
              </View>
              <View style={styles.legend}>
                {segments.map((s, i) => (
                  <View key={s.label + i} style={styles.legendRow}>
                    <View style={styles.legendLeft}>
                      <View style={[styles.legendDot, { backgroundColor: s.color }]} />
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
            <Text style={styles.proNote}>Nothing spent this month yet. Log an expense and the breakdown appears.</Text>
          )}
        </View>

        <View style={styles.card}>
          <Text style={styles.kicker}>NET WORTH BY CATEGORY</Text>
          <View style={styles.cardBody}>
            {worthRows.map((w) => (
              <HBar key={w.label} label={w.label} amount={w.amount} max={worthMax} color={w.color} />
            ))}
          </View>
        </View>

        {trendPoints.length >= 2 ? (
          <View style={styles.card}>
            <Text style={styles.kicker}>NET WORTH TREND</Text>
            <View style={styles.trend}>
              {trendPoints.map((p) => (
                <View key={p.month} style={styles.trendCol}>
                  <View
                    style={[
                      styles.trendBar,
                      { height: Math.max((p.value / trendMax) * 120, 4) },
                    ]}
                  />
                  <Text style={styles.trendLabel}>{p.label}</Text>
                </View>
              ))}
            </View>
            <Text style={styles.trendNow}>Now: {formatMoney(netWorthNow)}</Text>
          </View>
        ) : null}

        {showCommitted ? (
          <View style={styles.card}>
            <Text style={styles.kicker}>WHAT IS ALREADY SPOKEN FOR</Text>
            <View style={styles.propBar}>
              <View style={{ width: `${Math.max(committedShare * 100, 1)}%`, backgroundColor: colors.warning }} />
              {sts.available > 0 ? (
                <View style={{ width: `${Math.max((1 - committedShare) * 100, 1)}%`, backgroundColor: colors.primary }} />
              ) : null}
            </View>
            <View style={styles.legend}>
              <View style={styles.legendRow}>
                <View style={styles.legendLeft}>
                  <View style={[styles.legendDot, { backgroundColor: colors.warning }]} />
                  <Text style={styles.legendLabel}>Committed</Text>
                </View>
                <Text style={styles.legendVal}>{formatMoney(sts.committed)}</Text>
              </View>
              <View style={styles.legendRow}>
                <View style={styles.legendLeft}>
                  <View style={[styles.legendDot, { backgroundColor: colors.primary }]} />
                  <Text style={styles.legendLabel}>{sts.available > 0 ? 'Free to spend' : 'Short'}</Text>
                </View>
                <Text style={styles.legendVal}>{formatMoney(Math.abs(sts.available))}</Text>
              </View>
            </View>
            {committedLine ? <Text style={styles.insightLine}>{committedLine}</Text> : null}
          </View>
        ) : null}

        {utang.people.length > 0 ? (
          <View style={styles.card}>
            <Text style={styles.kicker}>UTANG: WHO OWES YOU</Text>
            <View style={styles.cardBody}>
              {utangTop.map((p) => (
                <View key={p.personId || p.name} style={styles.utangRow}>
                  <View style={styles.utangHead}>
                    <Text style={styles.moverLabel} numberOfLines={1}>{p.name}</Text>
                    <Text style={styles.utangAmt}>{formatMoney(p.outstanding)}</Text>
                  </View>
                  <View style={styles.hbarTrack}>
                    <View
                      style={[
                        styles.hbarFill,
                        {
                          width: `${Math.max((p.outstanding / utangMax) * 100, 2)}%`,
                          backgroundColor: p.daysOverdue > 0 ? colors.warning : colors.primary,
                        },
                      ]}
                    />
                  </View>
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
          </View>
        ) : null}

        {goalRows.length > 0 ? (
          <View style={styles.card}>
            <Text style={styles.kicker}>GOAL PACE</Text>
            <View style={styles.cardBody}>
              {goalRows.map(({ goal, pace }) => (
                <View key={goal.id} style={styles.utangRow}>
                  <View style={styles.utangHead}>
                    <Text style={styles.moverLabel} numberOfLines={1}>{goal.name}</Text>
                    <Text style={styles.goalPct}>{Math.round(pace.pct * 100)}%</Text>
                  </View>
                  <View style={styles.hbarTrack}>
                    <View
                      style={[
                        styles.hbarFill,
                        {
                          width: `${Math.max(pace.pct * 100, 2)}%`,
                          backgroundColor: pace.status === 'behind' ? colors.warning : colors.primary,
                        },
                      ]}
                    />
                  </View>
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
          </View>
        ) : null}

        {/* ---- Pro analytics: the deep analysis tier ---- */}
        <Text style={styles.sectionTitleRow}>
          PRO ANALYTICS <Text style={styles.proBadge}>PRO</Text>
        </Text>
        {!pro ? (
          <View style={styles.card}>
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
          </View>
        ) : (
          <>
            <ProInsights data={data} styles={styles} colors={colors} />
          </>
        )}

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
function ProInsights({ data, styles, colors }) {
  const score = healthScore(data);
  const series = monthlySeries(data.transactions, 6);
  const seriesMax = Math.max(...series.map((m) => Math.max(m.income, m.expenses)), 1);
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
      <View style={styles.card}>
        <Text style={styles.kicker}>FINANCIAL HEALTH SCORE</Text>
        <View style={styles.scoreRow}>
          <Text style={styles.scoreBig}>{score.total}</Text>
          <Text style={styles.scoreOf}>/ 100</Text>
        </View>
        <View style={styles.partRow}><Text style={styles.partLabel}>Savings rate</Text><Text style={styles.partVal}>{score.parts.savings}/35</Text></View>
        <View style={styles.partRow}><Text style={styles.partLabel}>Budget discipline</Text><Text style={styles.partVal}>{score.parts.budget}/25</Text></View>
        <View style={styles.partRow}><Text style={styles.partLabel}>Debt load</Text><Text style={styles.partVal}>{score.parts.debt}/25</Text></View>
        <View style={styles.partRow}><Text style={styles.partLabel}>Logging habit</Text><Text style={styles.partVal}>{score.parts.logging}/15</Text></View>
      </View>

      <View style={styles.card}>
        <Text style={styles.kicker}>SIX MONTH TREND</Text>
        <View style={styles.trend}>
          {series.map((m) => (
            <View key={m.key} style={styles.trendCol}>
              <View style={styles.duoBars}>
                <View style={[styles.duoBar, { height: Math.max((m.income / seriesMax) * 100, 2), backgroundColor: colors.primary }]} />
                <View style={[styles.duoBar, { height: Math.max((m.expenses / seriesMax) * 100, 2), backgroundColor: colors.border }]} />
              </View>
              <Text style={styles.trendLabel}>{m.label}</Text>
            </View>
          ))}
        </View>
        <Text style={styles.proNote}>Bright bars are income, dim bars are spending. Net this month: {formatMoney(series[series.length - 1].net)}.</Text>
      </View>

      <View style={styles.card}>
        <Text style={styles.kicker}>THIS MONTH, AT THIS PACE</Text>
        <Text style={styles.forecastBig}>{formatMoney(fc.projected)}</Text>
        <Text style={styles.proNote}>
          Projected month end spending{limit > 0 ? ` against your ${formatMoney(limit)} budget` : ''}.
          {limit > 0 && fc.projected > limit ? ' Ease off a little.' : ''}
          {rate !== null ? ` Savings rate so far: ${Math.round(rate * 100)}% of income kept.` : ''}
        </Text>
      </View>

      {vsAvg.length > 0 ? (
        <View style={styles.card}>
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
                  <View style={styles.vsTrack}>
                    <View style={[styles.vsBarNow, { width: `${Math.max((v.now / vsAvgMax) * 100, 1)}%`, backgroundColor: over ? colors.warning : colors.primary }]} />
                  </View>
                  <View style={styles.vsTrack}>
                    <View style={[styles.vsBarAvg, { width: `${Math.max((v.avg / vsAvgMax) * 100, 1)}%` }]} />
                  </View>
                  <Text style={styles.vsNums}>
                    {formatMoney(v.now)} now, usually {formatMoney(Math.round(v.avg))}
                  </Text>
                </View>
              );
            })}
          </View>
        </View>
      ) : null}

      {movers.length > 0 ? (
        <View style={styles.card}>
          <Text style={styles.kicker}>MOVERS VS LAST MONTH</Text>
          <View style={styles.cardBody}>
            {movers.map((mv) => (
              <View key={mv.label} style={styles.moverRow}>
                <Text style={styles.moverLabel}>{mv.label}</Text>
                <Text style={[styles.moverVal, { color: mv.change > 0 ? colors.warning : colors.primary }]}>
                  {mv.change > 0 ? '+' : '-'}{formatMoney(Math.abs(mv.change))}
                </Text>
              </View>
            ))}
          </View>
        </View>
      ) : null}

      <View style={styles.card}>
        <Text style={styles.kicker}>YOUR WEEK IN SPENDING</Text>
        <View style={styles.trend}>
          {wk.map((w, i) => (
            <View key={i} style={styles.trendCol}>
              <View style={[styles.wkBar, { height: Math.max((w.avg / wkMax) * 90, 3), backgroundColor: w.day === topDay.day && w.avg > 0 ? colors.primary : colors.border }]} />
              <Text style={styles.trendLabel}>{WEEKDAY_LETTERS[i]}</Text>
            </View>
          ))}
        </View>
        {topDay.avg > 0 ? (
          <Text style={styles.proNote}>You spend the most on {DAY_NAMES[topDay.day]} ({formatMoney(Math.round(topDay.avg))} on average).</Text>
        ) : (
          <Text style={styles.proNote}>Log a few weeks of spending and your pattern appears here.</Text>
        )}
      </View>
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

    card: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.lg,
      padding: spacing.xl,
      marginBottom: spacing.lg,
    },
    kicker: {
      color: colors.softGreen,
      fontSize: fontSize.caption,
      fontWeight: fontWeight.medium,
      letterSpacing: 1.2,
    },
    cardBody: { marginTop: spacing.md, gap: spacing.md },

    propBar: {
      flexDirection: 'row',
      height: 16,
      borderRadius: radius.pill,
      overflow: 'hidden',
      marginTop: spacing.md,
      backgroundColor: colors.border,
    },
    legend: { marginTop: spacing.md, gap: spacing.sm },
    legendRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: spacing.sm },
    legendLeft: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, flex: 1, minWidth: 0 },
    legendDot: { width: 11, height: 11, borderRadius: 3, flex: 0 },
    legendLabel: { color: colors.textSecondary, fontSize: fontSize.small, flexShrink: 1 },
    legendVal: { color: colors.text, fontSize: fontSize.small, fontWeight: fontWeight.bold, fontVariant: ['tabular-nums'] },
    insightLine: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 20, marginTop: spacing.lg },

    hbarRow: { flexDirection: 'row', alignItems: 'center' },
    hbarLabel: { color: colors.textSecondary, fontSize: fontSize.small, width: 92 },
    hbarTrack: {
      flex: 1,
      height: 12,
      borderRadius: radius.pill,
      backgroundColor: colors.border,
      overflow: 'hidden',
      marginHorizontal: spacing.sm,
    },
    hbarFill: { height: '100%', borderRadius: radius.pill },
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
    trendBar: {
      width: 22,
      borderRadius: radius.sm,
      backgroundColor: colors.primary,
    },
    trendLabel: { color: colors.muted, fontSize: fontSize.caption, marginTop: spacing.xs },
    trendNow: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.md },

    sectionTitleRow: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.2, marginBottom: spacing.sm, marginTop: spacing.md, paddingHorizontal: spacing.xs },
    proBadge: { color: colors.celebrate, fontWeight: fontWeight.heavy },
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
    duoBars: { flexDirection: 'row', alignItems: 'flex-end', gap: 3, height: 100 },
    duoBar: { width: 10, borderRadius: 3 },
    proNote: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.md },
    forecastBig: { color: colors.text, fontSize: fontSize.big, fontWeight: fontWeight.heavy, fontVariant: ['tabular-nums'], marginTop: spacing.xs },
    moverRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: spacing.xs },
    moverLabel: { color: colors.text, fontSize: fontSize.body },
    vsHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: spacing.xs },
    vsVerdict: { fontSize: fontSize.caption, fontWeight: fontWeight.medium },
    vsTrack: { height: 8, borderRadius: radius.pill, backgroundColor: 'transparent', marginBottom: 3 },
    vsBarNow: { height: 8, borderRadius: radius.pill },
    vsBarAvg: { height: 8, borderRadius: radius.pill, backgroundColor: colors.border },
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
