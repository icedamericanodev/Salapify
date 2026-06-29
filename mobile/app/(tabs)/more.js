// More tab. Will hold Goals, Money mindset, full Settings, and Backup later.
// For now it has the Appearance switcher so you can choose Light, Dark, or
// System. The choice is saved on the phone and applies across the whole app.

import { useMemo } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../../theme';
import { useTheme } from '../../context/Theme';

// The three appearance choices.
const OPTIONS = [
  { key: 'light', label: 'Light' },
  { key: 'dark', label: 'Dark' },
  { key: 'system', label: 'System' },
];

export default function More() {
  const { colors, mode, setMode } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.pageTitle}>More</Text>

        <Text style={styles.sectionTitle}>APPEARANCE</Text>
        <View style={styles.card}>
          {OPTIONS.map((opt, i) => {
            const selected = mode === opt.key;
            return (
              <Pressable
                key={opt.key}
                onPress={() => setMode(opt.key)}
                style={({ pressed }) => [
                  styles.option,
                  i > 0 && styles.optionDivider, // divider between rows
                  pressed && styles.optionPressed,
                ]}
              >
                <Text style={styles.optionLabel}>{opt.label}</Text>
                {/* A green check marks the current choice. */}
                {selected ? (
                  <Ionicons name="checkmark" size={20} color={colors.primary} />
                ) : null}
              </Pressable>
            );
          })}
        </View>
        <Text style={styles.hint}>
          System follows your phone's own light or dark setting.
        </Text>

        <Text style={styles.footnote}>
          Goals, money mindset, full settings, and backup will live here.
        </Text>
      </ScrollView>
    </SafeAreaView>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },
    pageTitle: {
      color: colors.text,
      fontSize: fontSize.title,
      fontWeight: fontWeight.bold,
      marginBottom: spacing.lg,
    },
    sectionTitle: {
      color: colors.muted,
      fontSize: fontSize.caption,
      fontWeight: fontWeight.medium,
      letterSpacing: 1.5,
      marginBottom: spacing.sm,
      paddingHorizontal: spacing.xs,
    },
    card: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.lg,
      paddingHorizontal: spacing.lg,
    },
    option: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'space-between',
      paddingVertical: spacing.md + 2,
    },
    optionDivider: {
      borderTopColor: colors.border,
      borderTopWidth: StyleSheet.hairlineWidth,
    },
    optionPressed: { opacity: 0.6 },
    optionLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    hint: {
      color: colors.faint,
      fontSize: fontSize.small,
      marginTop: spacing.sm,
      paddingHorizontal: spacing.xs,
    },
    footnote: {
      color: colors.faint,
      fontSize: fontSize.small,
      textAlign: 'center',
      marginTop: spacing.xxl,
    },
  });
}
