// WeekRecap is the share worthy card: a small brag about how many of the
// last 7 days you logged your money. It appears on the Overview when the
// week deserves it (3 or more logged days) or on Sundays as a weekly
// closing note, and one tap shares a plain text brag to any app. The
// number celebrated is awareness (days logged), never amounts, so it is
// always safe to share.

import { useEffect, useMemo, useRef } from 'react';
import { Animated, Pressable, Share, StyleSheet, Text, View } from 'react-native';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { todayISO } from '../lib/format';
import { SAMPLE_TX_IDS } from '../lib/sampleData';

export default function WeekRecap({ transactions }) {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);

  // Count how many of the last 7 days (ending today) have at least one log.
  // Demo rows do not count (a brag the user never earned is a lie), and
  // neither do transfer or debt payment records, only real logs.
  const logged = new Set(
    (transactions || [])
      .filter(
        (t) => t && !SAMPLE_TX_IDS.has(t.id) && (t.type === 'income' || t.type === 'expense')
      )
      .map((t) => t.date)
  );
  let daysLogged = 0;
  for (let i = 0; i < 7; i++) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    if (logged.has(todayISO(d))) daysLogged += 1;
  }

  const isSunday = new Date().getDay() === 0;
  const visible = daysLogged >= 3 || (isSunday && daysLogged > 0);

  // Gentle entrance: fade in and drift up.
  const anim = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    if (visible) {
      Animated.timing(anim, { toValue: 1, duration: 450, useNativeDriver: true }).start();
    }
  }, [visible]);

  if (!visible) return null;

  const line =
    daysLogged === 7
      ? 'Buong linggo mong alam ang gastos mo. Sana all. ✨'
      : `${daysLogged} days aware ng gastos mo this week. Sana all. ✨`;

  function share() {
    const message =
      daysLogged === 7
        ? 'Logged my money 7 for 7 days this week on Salapify 💚🔥 Sana all aware sa gastos.'
        : `Logged my money ${daysLogged} of the last 7 days on Salapify 💚 Sana all aware sa gastos.`;
    Share.share({ message }).catch(() => {});
  }

  return (
    <Animated.View
      style={[
        styles.card,
        {
          opacity: anim,
          transform: [{ translateY: anim.interpolate({ inputRange: [0, 1], outputRange: [12, 0] }) }],
        },
      ]}
    >
      <Text style={styles.kicker}>YOUR WEEK</Text>
      <View style={styles.heroRow}>
        <Text style={styles.hero}>{daysLogged}</Text>
        <Text style={styles.heroOf}>of 7 days logged</Text>
      </View>
      <Text style={styles.line}>{line}</Text>
      <Pressable onPress={share} style={({ pressed }) => [styles.shareBtn, pressed && styles.pressed]}>
        <Text style={styles.shareText}>Share</Text>
      </Pressable>
    </Animated.View>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    card: {
      backgroundColor: colors.positiveSurface,
      borderColor: colors.positiveBorder,
      borderWidth: 1,
      borderRadius: radius.lg,
      padding: spacing.xl,
      marginBottom: spacing.lg,
    },
    kicker: { color: colors.celebrate, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1.2 },
    heroRow: { flexDirection: 'row', alignItems: 'flex-end', gap: spacing.sm, marginTop: spacing.sm },
    hero: {
      color: colors.text,
      fontSize: fontSize.huge,
      fontWeight: fontWeight.heavy,
      fontVariant: ['tabular-nums'],
    },
    heroOf: { color: colors.textSecondary, fontSize: fontSize.body, marginBottom: 6 },
    line: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.sm },
    shareBtn: {
      alignSelf: 'flex-start',
      marginTop: spacing.md,
      minHeight: 44,
      justifyContent: 'center',
      paddingHorizontal: spacing.lg,
      borderRadius: radius.md,
      borderWidth: 1,
      borderColor: colors.primary,
    },
    pressed: { opacity: 0.6 },
    shareText: { color: colors.primary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
