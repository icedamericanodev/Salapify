// Appearance screen (reached from More > Theme and colors). It holds the two
// look settings that used to sit inline in the More tab and made it a very long
// scroll: the light/dark/system MODE, and the COLOR THEME picker. Nothing about
// how the choice is stored or applied changed, this only moves the UI here and
// lays the 8 themes out as a compact 2-column grid of tiles instead of 8 tall
// full-width rows. Reads live theme colors through useTheme(), so all 8 palettes
// and both light and dark render correctly.

import { useMemo } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight, palettes, APPEARANCE_MODES, PALETTE_OPTIONS } from '../theme';
import { useTheme } from '../context/Theme';
import SectionHeader from '../components/SectionHeader';

export default function Appearance() {
  const { colors, mode, setMode, palette, setPalette, isDark } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable
          onPress={() => router.back()}
          hitSlop={10}
          style={styles.back}
          accessibilityRole="button"
          accessibilityLabel="Go back"
        >
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle} accessibilityRole="header">Appearance</Text>
        <View style={{ width: 24 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        <SectionHeader title="MODE" />
        {/* A compact 3-up segmented control, not three tall rows. */}
        <View style={styles.segment}>
          {APPEARANCE_MODES.map((opt) => {
            const selected = mode === opt.key;
            return (
              <Pressable
                key={opt.key}
                onPress={() => setMode(opt.key)}
                style={({ pressed }) => [styles.segBtn, selected && styles.segBtnOn, pressed && styles.pressed]}
                accessibilityRole="button"
                accessibilityState={{ selected }}
                accessibilityLabel={`${opt.label} mode`}
              >
                <Text style={[styles.segText, selected && styles.segTextOn]}>{opt.label}</Text>
              </Pressable>
            );
          })}
        </View>

        <SectionHeader title="COLOR THEME" style={styles.themeHeader} />
        {/* A compact 2-column grid of tiles. Each tile shows a three dot preview
            (base, brand accent, win color) drawn from the theme's LIVE variant,
            so the preview matches what you will actually get in your current
            light or dark mode. Plus the name, its hint, and a ring/check when
            active. */}
        <View style={styles.grid}>
          {PALETTE_OPTIONS.map((opt) => {
            const selected = palette === opt.key;
            const p = palettes[opt.key];
            const pv = p && (isDark ? p.dark : p.light);
            return (
              <Pressable
                key={opt.key}
                onPress={() => setPalette(opt.key)}
                style={({ pressed }) => [styles.tile, selected && styles.tileOn, pressed && styles.pressed]}
                accessibilityRole="button"
                accessibilityState={{ selected }}
                accessibilityLabel={`${opt.label} theme. ${opt.hint}`}
              >
                <View style={styles.tileTop}>
                  {pv ? (
                    <View style={styles.swatchRow}>
                      <View style={[styles.swatchDot, { backgroundColor: pv.background, borderColor: pv.border }]} />
                      <View style={[styles.swatchDot, styles.swatchOverlap, { backgroundColor: pv.primary, borderColor: pv.background }]} />
                      <View style={[styles.swatchDot, styles.swatchOverlap, { backgroundColor: pv.celebrate, borderColor: pv.background }]} />
                    </View>
                  ) : null}
                  {selected ? <Ionicons name="checkmark-circle" size={20} color={colors.primary} /> : null}
                </View>
                <Text style={styles.tileLabel}>{opt.label}</Text>
                <Text style={styles.tileHint} numberOfLines={3}>{opt.hint}</Text>
              </Pressable>
            );
          })}
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

    // MODE segmented control.
    segment: { flexDirection: 'row', backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, padding: spacing.xxs },
    segBtn: { flex: 1, alignItems: 'center', justifyContent: 'center', minHeight: 44, borderRadius: radius.sm },
    segBtnOn: { backgroundColor: colors.primary },
    segText: { color: colors.textSecondary, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    segTextOn: { color: colors.onPrimary, fontWeight: fontWeight.bold },

    // COLOR THEME grid.
    themeHeader: { marginTop: spacing.xl },
    grid: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between' },
    tile: {
      width: '48.5%',
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.lg,
      padding: spacing.md,
      marginBottom: spacing.md,
      minHeight: 44,
    },
    tileOn: { borderColor: colors.primary, borderWidth: 2, padding: spacing.md - 1 },
    tileTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: spacing.sm },
    swatchRow: { flexDirection: 'row', alignItems: 'center' },
    swatchDot: { width: 22, height: 22, borderRadius: 11, borderWidth: 1 },
    swatchOverlap: { marginLeft: -8 },
    tileLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    tileHint: { color: colors.faint, fontSize: fontSize.small, marginTop: 2 },

    // Shared pressed feedback, matching the row convention elsewhere.
    pressed: { opacity: 0.7 },
  });
}
