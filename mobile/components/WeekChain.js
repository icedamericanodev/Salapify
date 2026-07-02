// WeekChain shows the last 7 days as dots: filled when you logged at least
// one transaction that day. It is a chain, not a streak: missing a day dims
// one dot but nothing ever resets to zero, so coming back always feels
// worth it. Used on Overview and Budget.

import { useMemo } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { todayISO } from '../lib/format';

const DAY_LETTERS = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

export default function WeekChain({ transactions }) {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);

  // Build the last 7 days, oldest first, ending today.
  const logged = new Set((transactions || []).map((t) => t.date));
  const days = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    days.push({
      iso: todayISO(d),
      letter: DAY_LETTERS[d.getDay()],
      done: logged.has(todayISO(d)),
      isToday: i === 0,
    });
  }
  const count = days.filter((d) => d.done).length;

  const message =
    count === 0
      ? 'Log anything today to start your chain.'
      : count === 7
      ? 'A full week of knowing where your money goes.'
      : `Logged ${count} of the last 7 days. Keep the chain going.`;

  return (
    <View style={styles.card}>
      <Text style={styles.kicker}>LOGGING CHAIN</Text>
      <View style={styles.row}>
        {days.map((d) => (
          <View key={d.iso} style={styles.col}>
            <View
              style={[
                styles.dot,
                d.done && styles.dotOn,
                d.isToday && !d.done && styles.dotToday,
              ]}
            >
              {d.done ? <Text style={styles.check}>✓</Text> : null}
            </View>
            <Text style={[styles.letter, d.isToday && styles.letterToday]}>{d.letter}</Text>
          </View>
        ))}
      </View>
      <Text style={styles.message}>{message}</Text>
    </View>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    card: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.lg,
      padding: spacing.xl,
      marginBottom: spacing.lg,
    },
    kicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 2 },
    row: { flexDirection: 'row', justifyContent: 'space-between', marginTop: spacing.md },
    col: { alignItems: 'center', gap: spacing.xs },
    dot: {
      width: 30,
      height: 30,
      borderRadius: radius.pill,
      borderWidth: 1.5,
      borderColor: colors.border,
      alignItems: 'center',
      justifyContent: 'center',
    },
    dotOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    dotToday: { borderColor: colors.primary, borderStyle: 'dashed' },
    check: { color: '#FFFFFF', fontSize: fontSize.small, fontWeight: fontWeight.bold },
    letter: { color: colors.muted, fontSize: fontSize.caption },
    letterToday: { color: colors.primary, fontWeight: fontWeight.bold },
    message: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.md },
  });
}
