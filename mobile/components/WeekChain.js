// WeekChain shows the last 7 days as dots: filled when you logged at least
// one transaction that day. It is a chain, not a streak: missing a day dims
// one dot but nothing ever resets to zero, so coming back always feels
// worth it. Today's dot springs when it fills, and a full 7 for 7 week
// earns a gold border and a staggered pop across all seven dots.
// Used on Overview and Budget.

import { useEffect, useMemo, useRef } from 'react';
import { Animated, StyleSheet, Text, View } from 'react-native';
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
  const todayDone = days[6].done;
  const fullWeek = count === 7;

  // One animated scale per dot. Springing past 1 gives the playful pop.
  const scales = useRef(days.map(() => new Animated.Value(1))).current;
  const prevToday = useRef(todayDone);
  const prevCount = useRef(count);
  useEffect(() => {
    if (todayDone && !prevToday.current) {
      scales[6].setValue(0.4);
      Animated.spring(scales[6], { toValue: 1, friction: 3, useNativeDriver: true }).start();
    }
    if (fullWeek && prevCount.current < 7) {
      Animated.stagger(
        45,
        scales.map((v) => {
          v.setValue(0.6);
          return Animated.spring(v, { toValue: 1, friction: 4, useNativeDriver: true });
        })
      ).start();
    }
    prevToday.current = todayDone;
    prevCount.current = count;
  }, [todayDone, fullWeek, count]);

  const message =
    count === 0
      ? 'Log anything today to start your chain.'
      : fullWeek
      ? '7 for 7. Ikaw na. 🔥'
      : `Logged ${count} of the last 7 days. Keep the chain going.`;

  return (
    <View style={[styles.card, fullWeek && styles.cardFull]}>
      <Text style={styles.kicker}>LOGGING CHAIN</Text>
      <View style={styles.row}>
        {days.map((d, i) => (
          <View key={d.iso} style={styles.col}>
            <Animated.View
              style={[
                styles.dot,
                d.done && styles.dotOn,
                d.isToday && !d.done && styles.dotToday,
                { transform: [{ scale: scales[i] }] },
              ]}
            >
              {d.done ? <Text style={styles.check}>✓</Text> : null}
            </Animated.View>
            <Text style={[styles.letter, d.isToday && styles.letterToday]}>{d.letter}</Text>
          </View>
        ))}
      </View>
      <Text style={[styles.message, fullWeek && styles.messageFull]}>{message}</Text>
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
    cardFull: { borderColor: colors.celebrate },
    kicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.2 },
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
    check: { color: colors.onPrimary, fontSize: fontSize.small, fontWeight: fontWeight.bold },
    letter: { color: colors.muted, fontSize: fontSize.caption },
    letterToday: { color: colors.primary, fontWeight: fontWeight.bold },
    message: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.md },
    messageFull: { color: colors.celebrate, fontWeight: fontWeight.medium },
  });
}
