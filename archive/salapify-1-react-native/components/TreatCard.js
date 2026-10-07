// TreatCard is the Overview face of the earn-your-treats habit. It shows one
// active treat, its progress dots, and a one-tap check-in, so the habit lives
// where the user already looks every day. Tapping the body opens the full
// manage screen. When no treat is set it becomes a slim invite instead. It
// reuses the WeekChain look, and turns celebrate colored when a treat is
// earned. When payday is near it nudges to earn the treat before the money
// lands. No dashes, no health data, never blocks a purchase.

import { useMemo } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';
import { treatStatus, toggleCheckIn } from '../lib/treats';
import { daysUntilPayday } from '../lib/format';

export default function TreatCard() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data, updateSettings } = useAppData();

  const treats = Array.isArray(data.settings && data.settings.treats) ? data.settings.treats : [];

  // Show the treat that most needs attention: the first one not yet earned,
  // else the first earned one so the win still shows.
  const statuses = treats.map((t) => treatStatus(t));
  const pick = statuses.find((s) => !s.earned) || statuses[0] || null;

  const onToggle = (id) => {
    updateSettings((s) => ({
      treats: (Array.isArray(s.treats) ? s.treats : []).map((t) => (t.id === id ? toggleCheckIn(t) : t)),
    }));
  };

  // Slim invite when no treat exists yet, so the feature is discoverable
  // without crowding Overview.
  if (!pick) {
    return (
      <Pressable
        onPress={() => router.push('/treats')}
        style={({ pressed }) => [styles.invite, pressed && styles.pressed]}
      >
        <Text style={styles.inviteEmoji}>☕</Text>
        <View style={{ flex: 1 }}>
          <Text style={styles.inviteTitle}>Earn your treats</Text>
          <Text style={styles.inviteSub}>Pair a small reward with a healthy habit. Guilt free.</Text>
        </View>
        <Ionicons name="chevron-forward" size={16} color={colors.faint} />
      </Pressable>
    );
  }

  // Only nudge on payday when the user actually set a schedule. Without one
  // the default would fire the nudge on random days and read as noise.
  const schedule = data.settings && data.settings.paydaySchedule;
  const paydaySoon = !!schedule && daysUntilPayday(new Date(), schedule) <= 1;

  const subtitle = pick.earned
    ? `Earned. Enjoy your ${String(pick.treat || 'treat').toLowerCase()}, you paid for it in ${String(pick.action || 'effort').toLowerCase()}.`
    : paydaySoon
    ? `Sweldo malapit na. Lock in your ${String(pick.action || 'habit').toLowerCase()} habit first, ${pick.remaining} to go.`
    : pick.recent === 0
    ? `Do your ${String(pick.action || 'habit').toLowerCase()}, then check in. ${pick.target} earns it.`
    : `${pick.recent} of ${pick.target} check ins. ${pick.remaining} more and it is yours.`;

  return (
    <View style={[styles.card, pick.earned && styles.cardEarned]}>
      <Pressable onPress={() => router.push('/treats')} style={styles.head} hitSlop={4}>
        <Text style={styles.kicker}>EARN YOUR TREAT</Text>
        <Ionicons name="chevron-forward" size={16} color={colors.faint} />
      </Pressable>

      <Pressable onPress={() => router.push('/treats')} style={styles.body}>
        <Text style={styles.emoji} importantForAccessibility="no">{pick.emoji}</Text>
        <View style={{ flex: 1 }}>
          <Text style={styles.treat}>{pick.treat}</Text>
          <View style={styles.dotsRow}>
            {Array.from({ length: pick.target }).map((_, i) => (
              <View
                key={i}
                style={[
                  styles.dot,
                  i < pick.recent && styles.dotOn,
                  pick.earned && i < pick.recent && styles.dotEarned,
                ]}
              />
            ))}
          </View>
        </View>
        {pick.earned ? <Text style={styles.earnedTag}>EARNED</Text> : null}
      </Pressable>

      <Text style={[styles.sub, pick.earned && styles.subEarned]}>{subtitle}</Text>

      <Pressable
        onPress={() => onToggle(pick.id)}
        style={({ pressed }) => [styles.checkBtn, pick.doneToday && styles.checkBtnDone, pressed && styles.pressed]}
      >
        <Ionicons
          name={pick.doneToday ? 'checkmark-circle' : 'ellipse-outline'}
          size={18}
          color={pick.doneToday ? colors.background : colors.primary}
        />
        <Text style={[styles.checkBtnText, pick.doneToday && styles.checkBtnTextDone]}>
          {pick.doneToday ? 'Done for today, tap to undo' : 'I did it today'}
        </Text>
      </Pressable>
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
    cardEarned: { borderColor: colors.celebrate || colors.primary },
    head: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
    kicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.2 },

    body: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, marginTop: spacing.md },
    emoji: { fontSize: 26 },
    treat: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    dotsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginTop: spacing.sm },
    dot: { width: 14, height: 14, borderRadius: 7, borderWidth: 1.5, borderColor: colors.border },
    dotOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    dotEarned: { backgroundColor: colors.celebrate || colors.primary, borderColor: colors.celebrate || colors.primary },
    earnedTag: {
      color: colors.celebrate || colors.primary,
      fontSize: 10,
      fontWeight: fontWeight.bold,
      letterSpacing: 1,
      borderColor: colors.celebrate || colors.primary,
      borderWidth: 1,
      borderRadius: radius.sm,
      paddingHorizontal: 6,
      paddingVertical: 1,
    },

    sub: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 19, marginTop: spacing.md },
    subEarned: { color: colors.celebrate || colors.primary, fontWeight: fontWeight.medium },

    checkBtn: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'center',
      gap: spacing.sm,
      borderColor: colors.primary,
      borderWidth: 1,
      borderRadius: radius.pill,
      paddingVertical: spacing.md,
      marginTop: spacing.md,
    },
    checkBtnDone: { backgroundColor: colors.primary },
    checkBtnText: { color: colors.primary, fontSize: fontSize.small, fontWeight: fontWeight.bold },
    checkBtnTextDone: { color: colors.background },

    invite: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: spacing.md,
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.lg,
      padding: spacing.lg,
      marginBottom: spacing.lg,
    },
    inviteEmoji: { fontSize: 24 },
    inviteTitle: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    inviteSub: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },

    pressed: { opacity: 0.7 },
  });
}
