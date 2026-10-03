// PeriodSelector: a small, reusable control that lets a screen show its money by
// Month, Year, or a Custom date range (and optionally All time). It holds no
// state of its own. The parent keeps a `period` object (see lib/format.js) and
// receives a new one through onChange, so History, Insights, and any future
// screen share the exact same period logic and look.
//
// Custom dates are typed as YYYY-MM-DD, the same way the log sheet already takes
// "another day", so there is no new date picker library to add.

import { View, Text, Pressable, TextInput, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import {
  periodLabel,
  shiftPeriod,
  periodIsFuture,
  currentMonthPeriod,
  todayISO,
} from '../lib/format';

export default function PeriodSelector({ period, onChange, colors, allowAll = false }) {
  const styles = makeStyles(colors);
  const mode = period && period.mode ? period.mode : 'month';

  // The mode chips. "All" is opt-in because some screens (like a monthly budget)
  // never want it.
  const modes = [
    ...(allowAll ? [{ key: 'all', label: 'All' }] : []),
    { key: 'month', label: 'Month' },
    { key: 'year', label: 'Year' },
    { key: 'custom', label: 'Custom' },
  ];

  // Switching mode starts each one at a sensible default so the view is never
  // blank: month and year start at today, custom starts empty (all dates).
  function setMode(next) {
    if (next === mode) return;
    if (next === 'all') onChange({ mode: 'all' });
    else if (next === 'month') onChange(currentMonthPeriod());
    else if (next === 'year') onChange({ mode: 'year', y: todayISO().slice(0, 4) });
    else onChange({ mode: 'custom', from: '', to: '' });
  }

  // Do not let the user step past this month or year: it would only ever be an
  // empty future period.
  const stepping = mode === 'month' || mode === 'year';
  const canForward = stepping && !periodIsFuture(shiftPeriod(period, 1));

  return (
    <View style={styles.wrap}>
      <View style={styles.modeRow}>
        {modes.map((m) => {
          const on = m.key === mode;
          return (
            <Pressable
              key={m.key}
              onPress={() => setMode(m.key)}
              style={[styles.modeChip, on && styles.modeChipOn]}
              accessibilityRole="button"
              accessibilityState={{ selected: on }}
            >
              <Text style={[styles.modeText, on && styles.modeTextOn]}>{m.label}</Text>
            </Pressable>
          );
        })}
      </View>

      {stepping ? (
        <View style={styles.stepRow}>
          <Pressable onPress={() => onChange(shiftPeriod(period, -1))} hitSlop={10} style={styles.stepBtn} accessibilityLabel="Previous period">
            <Ionicons name="chevron-back" size={18} color={colors.text} />
          </Pressable>
          <Text style={styles.stepLabel}>{periodLabel(period)}</Text>
          <Pressable
            onPress={() => (canForward ? onChange(shiftPeriod(period, 1)) : null)}
            hitSlop={10}
            style={styles.stepBtn}
            accessibilityLabel="Next period"
            accessibilityState={{ disabled: !canForward }}
          >
            <Ionicons name="chevron-forward" size={18} color={canForward ? colors.text : colors.faint} />
          </Pressable>
        </View>
      ) : null}

      {mode === 'custom' ? (
        <View style={styles.customRow}>
          <View style={styles.customField}>
            <Text style={styles.customLabel}>From</Text>
            <TextInput
              style={styles.customInput}
              value={period.from || ''}
              onChangeText={(t) => onChange({ mode: 'custom', from: t.trim(), to: period.to || '' })}
              placeholder="YYYY-MM-DD"
              placeholderTextColor={colors.faint}
              keyboardType="numbers-and-punctuation"
              autoCapitalize="none"
            />
          </View>
          <View style={styles.customField}>
            <Text style={styles.customLabel}>To</Text>
            <TextInput
              style={styles.customInput}
              value={period.to || ''}
              onChangeText={(t) => onChange({ mode: 'custom', from: period.from || '', to: t.trim() })}
              placeholder="YYYY-MM-DD"
              placeholderTextColor={colors.faint}
              keyboardType="numbers-and-punctuation"
              autoCapitalize="none"
            />
          </View>
        </View>
      ) : null}
    </View>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    wrap: { marginBottom: spacing.md },
    modeRow: { flexDirection: 'row', gap: spacing.xs },
    modeChip: {
      paddingVertical: spacing.xs,
      paddingHorizontal: spacing.md,
      borderRadius: radius.pill || radius.lg,
      backgroundColor: colors.card,
      borderWidth: 1,
      borderColor: colors.border,
    },
    modeChipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    modeText: { color: colors.textSecondary, fontSize: fontSize.caption, fontWeight: fontWeight.medium },
    modeTextOn: { color: colors.onPrimary, fontWeight: fontWeight.bold },
    stepRow: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'space-between',
      marginTop: spacing.sm,
      backgroundColor: colors.card,
      borderWidth: 1,
      borderColor: colors.border,
      borderRadius: radius.md,
      paddingHorizontal: spacing.sm,
      paddingVertical: spacing.xs,
    },
    stepBtn: { padding: spacing.xs },
    stepLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    customRow: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.sm },
    customField: { flex: 1 },
    customLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs },
    customInput: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.md,
      paddingHorizontal: spacing.md,
      paddingVertical: spacing.sm,
      color: colors.text,
      fontSize: fontSize.body,
    },
  });
}
