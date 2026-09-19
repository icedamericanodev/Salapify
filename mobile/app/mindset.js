// Money mindset screen. A daily tip, a quick impulse-spending check, and a
// list of small wins you can add to. Reached from the More tab. Tips are
// currency neutral. Wins are saved on the device.

import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';
import { lessonOfTheDay } from '../lib/lessons';

// The impulse check questions.
const QUESTIONS = [
  'Do I actually need this?',
  'Can I wait 24 hours and still want it?',
  'Does it fit my budget this month?',
];

export default function Mindset() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data, addItem, removeItem } = useAppData();

  // Today's featured lesson, a pointer into the full Learn track.
  const lesson = lessonOfTheDay(new Date());

  // Impulse check toggles.
  const [checks, setChecks] = useState([false, false, false]);
  const yesCount = checks.filter(Boolean).length;

  const [winText, setWinText] = useState('');
  function addWin() {
    const text = winText.trim();
    if (!text) return;
    addItem('wins', { text, date: new Date().toISOString().slice(0, 10) });
    setWinText('');
  }

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>Money mindset</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        {/* Today's lesson: a pointer into the Learn track. */}
        <Pressable onPress={() => router.push('/learn')} style={({ pressed }) => [styles.tipCard, pressed && styles.pressed]}>
          <Text style={styles.kicker}>TODAY'S LESSON</Text>
          <Text style={styles.tip}>{lesson.emoji}  {lesson.title}</Text>
          <Text style={styles.tipSub}>{lesson.summary}</Text>
          <Text style={styles.tipLink}>Read this and more in Money lessons ›</Text>
        </Pressable>

        {/* Impulse check. */}
        <Text style={styles.sectionTitle}>IMPULSE CHECK</Text>
        <View style={styles.card}>
          {QUESTIONS.map((q, i) => {
            const on = checks[i];
            return (
              <Pressable
                key={q}
                onPress={() => setChecks((c) => c.map((v, idx) => (idx === i ? !v : v)))}
                style={({ pressed }) => [styles.qRow, i > 0 && styles.divider, pressed && styles.pressed]}
              >
                <Ionicons
                  name={on ? 'checkbox' : 'square-outline'}
                  size={22}
                  color={on ? colors.primary : colors.muted}
                />
                <Text style={styles.qText}>{q}</Text>
              </Pressable>
            );
          })}
          <Text style={[styles.verdict, { color: yesCount === 3 ? colors.primary : colors.warning }]}>
            {yesCount === 3 ? 'Looks like a thoughtful buy. Go for it.' : 'Maybe wait a bit before buying.'}
          </Text>
        </View>

        {/* Wins. */}
        <Text style={styles.sectionTitle}>SMALL WINS</Text>
        <View style={styles.addRow}>
          <TextInput
            style={[styles.input, { flex: 1 }]}
            value={winText}
            onChangeText={setWinText}
            placeholder="e.g. Packed lunch all week"
            placeholderTextColor={colors.faint}
          />
          <Pressable onPress={addWin} style={[styles.sheetBtn, styles.saveBtn]}>
            <Text style={styles.saveText}>Add</Text>
          </Pressable>
        </View>
        <View style={styles.card}>
          {data.wins.length === 0 ? (
            <Text style={styles.empty}>No wins yet. Add a small one above.</Text>
          ) : (
            [...data.wins].reverse().map((w, i) => (
              <View key={w.id} style={[styles.winRow, i > 0 && styles.divider]}>
                <Text style={styles.winText}>🎉 {w.text}</Text>
                <Pressable onPress={() => removeItem('wins', w.id)} hitSlop={8}>
                  <Ionicons name="close" size={16} color={colors.faint} />
                </Pressable>
              </View>
            ))
          )}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: spacing.lg, paddingTop: spacing.md, paddingBottom: spacing.sm },
    back: { marginLeft: -4 },
    headerTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },

    tipCard: { backgroundColor: colors.card, borderColor: colors.primary, borderWidth: 1, borderRadius: radius.lg, padding: spacing.xl, marginBottom: spacing.lg },
    kicker: { color: colors.primary, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1.2, marginBottom: spacing.sm },
    tip: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold, lineHeight: 22 },
    tipSub: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: spacing.xs, lineHeight: 18 },
    tipLink: { color: colors.primary, fontSize: fontSize.small, fontWeight: fontWeight.medium, marginTop: spacing.sm },

    sectionTitle: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.5, marginBottom: spacing.sm, paddingHorizontal: spacing.xs },
    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, paddingHorizontal: spacing.lg, marginBottom: spacing.lg },
    pressed: { opacity: 0.6 },
    divider: { borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth },
    qRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, paddingVertical: spacing.md },
    qText: { color: colors.text, fontSize: fontSize.body, flex: 1 },
    verdict: { fontSize: fontSize.small, fontWeight: fontWeight.medium, paddingVertical: spacing.md },

    addRow: { flexDirection: 'row', gap: spacing.sm, marginBottom: spacing.md, alignItems: 'center' },
    input: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
    winRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: spacing.md },
    winText: { color: colors.text, fontSize: fontSize.body, flex: 1 },
    empty: { color: colors.faint, fontSize: fontSize.small, paddingVertical: spacing.md },

    sheetBtn: { paddingVertical: spacing.md, paddingHorizontal: spacing.lg, borderRadius: radius.md },
    saveBtn: { backgroundColor: colors.primary },
    saveText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
