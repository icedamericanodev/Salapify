// Learn: short money lessons, grounded in Filipino money life. Reached from
// More. Reading a lesson marks it done on the device. Education stays free,
// always. Pure content from lib/lessons.js, no network. The reading view is a
// Modal, which is fine here because it holds no text input, so no keyboard.

import { useMemo, useState } from 'react';
import { Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';
import { LESSONS, lessonOfTheDay } from '../lib/lessons';

export default function Learn() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data, updateSettings } = useAppData();

  const readIds = (data.settings && data.settings.lessonsRead) || [];
  const isRead = (id) => readIds.includes(id);
  const readCount = LESSONS.filter((l) => isRead(l.id)).length;
  const featured = lessonOfTheDay(new Date());

  const [reading, setReading] = useState(null);

  function openLesson(l) {
    setReading(l);
    if (!isRead(l.id)) {
      // Dedupe so re-reading never grows the list.
      updateSettings((s) => ({ lessonsRead: [...new Set([...((s && s.lessonsRead) || []), l.id])] }));
    }
  }

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>Money lessons</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        {/* Progress across the track. */}
        <View style={styles.progressCard}>
          <Text style={styles.kicker}>YOUR PROGRESS</Text>
          <Text style={styles.progressText}>
            {readCount} of {LESSONS.length} lessons read
          </Text>
          <View style={styles.barTrack}>
            <View style={[styles.barFill, { width: `${Math.round((readCount / LESSONS.length) * 100)}%` }]} />
          </View>
          <Text style={styles.progressSub}>Short reads, real money. All free, always.</Text>
        </View>

        {/* Lesson of the day. */}
        <Text style={styles.sectionTitle}>TODAY'S LESSON</Text>
        <Pressable onPress={() => openLesson(featured)} style={({ pressed }) => [styles.featCard, pressed && styles.pressed]}>
          <Text style={styles.featEmoji}>{featured.emoji}</Text>
          <View style={{ flex: 1 }}>
            <Text style={styles.featTitle}>{featured.title}</Text>
            <Text style={styles.featSummary}>{featured.summary}</Text>
            <Text style={styles.meta}>{featured.minutes} min read{isRead(featured.id) ? ' · read' : ''}</Text>
          </View>
        </Pressable>

        {/* The full track. */}
        <Text style={styles.sectionTitle}>ALL LESSONS</Text>
        <View style={styles.card}>
          {LESSONS.map((l, i) => (
            <Pressable
              key={l.id}
              onPress={() => openLesson(l)}
              style={({ pressed }) => [styles.row, i > 0 && styles.divider, pressed && styles.pressed]}
            >
              <Text style={styles.rowEmoji}>{l.emoji}</Text>
              <View style={{ flex: 1 }}>
                <Text style={styles.rowTitle}>{l.title}</Text>
                <Text style={styles.rowSummary} numberOfLines={1}>{l.summary}</Text>
              </View>
              {isRead(l.id) ? (
                <Ionicons name="checkmark-circle" size={20} color={colors.primary} />
              ) : (
                <Ionicons name="chevron-forward" size={18} color={colors.faint} />
              )}
            </Pressable>
          ))}
        </View>
      </ScrollView>

      {/* Reading view. */}
      <Modal visible={!!reading} transparent animationType="slide" onRequestClose={() => setReading(null)}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            <View style={styles.sheetHead}>
              <Text style={styles.sheetEmoji}>{reading ? reading.emoji : ''}</Text>
              <Pressable onPress={() => setReading(null)} hitSlop={10}>
                <Ionicons name="close" size={22} color={colors.muted} />
              </Pressable>
            </View>
            <ScrollView showsVerticalScrollIndicator={false}>
              <Text style={styles.readTitle}>{reading ? reading.title : ''}</Text>
              <Text style={styles.meta}>{reading ? `${reading.minutes} min read` : ''}</Text>
              {reading
                ? reading.body.map((p, i) => (
                    <Text key={i} style={styles.para}>{p}</Text>
                  ))
                : null}
              <Pressable onPress={() => setReading(null)} style={styles.doneBtn}>
                <Text style={styles.doneText}>Done</Text>
              </Pressable>
            </ScrollView>
          </View>
        </View>
      </Modal>
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

    progressCard: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginBottom: spacing.lg },
    kicker: { color: colors.primary, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1.2, marginBottom: spacing.sm },
    progressText: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    barTrack: { height: 8, borderRadius: 4, backgroundColor: colors.background, borderColor: colors.border, borderWidth: 1, marginTop: spacing.sm, overflow: 'hidden' },
    barFill: { height: '100%', backgroundColor: colors.primary },
    progressSub: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.sm },

    sectionTitle: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.5, marginBottom: spacing.sm, paddingHorizontal: spacing.xs },
    featCard: { flexDirection: 'row', gap: spacing.md, alignItems: 'center', backgroundColor: colors.card, borderColor: colors.primary, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginBottom: spacing.lg },
    featEmoji: { fontSize: 34 },
    featTitle: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    featSummary: { color: colors.textSecondary, fontSize: fontSize.small, marginTop: 2, lineHeight: 18 },
    meta: { color: colors.faint, fontSize: fontSize.caption, marginTop: spacing.xs },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, paddingHorizontal: spacing.lg, marginBottom: spacing.lg },
    pressed: { opacity: 0.6 },
    divider: { borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth },
    row: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, paddingVertical: spacing.md },
    rowEmoji: { fontSize: 24 },
    rowTitle: { color: colors.text, fontSize: fontSize.body },
    rowSummary: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },

    overlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl, maxHeight: '86%' },
    sheetHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: spacing.sm },
    sheetEmoji: { fontSize: 34 },
    readTitle: { color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.heavy, marginTop: spacing.xs },
    para: { color: colors.text, fontSize: fontSize.body, lineHeight: 24, marginTop: spacing.md },
    doneBtn: { backgroundColor: colors.primary, borderRadius: radius.md, paddingVertical: spacing.md, alignItems: 'center', marginTop: spacing.xl },
    doneText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
