// Settings screen (reached from the More tab). The Appearance switch (Light,
// Dark, System) works now and is saved on the phone. The other rows lay out
// the full settings structure and are marked "Soon" until we wire them up in
// later phases (currency, categories, quick add, logging, and the data tools).

import { useMemo } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../../theme';
import { useTheme } from '../../context/Theme';

const APPEARANCE = [
  { key: 'light', label: 'Light' },
  { key: 'dark', label: 'Dark' },
  { key: 'system', label: 'System' },
];

// The other settings, grouped. "value" shows on the right; "soon" marks rows
// not built yet.
const SECTIONS = [
  {
    title: 'PREFERENCES',
    rows: [
      { label: 'Currency', value: 'PHP ₱', soon: true },
      { label: 'Categories and income', soon: true },
      { label: 'Quick add buttons', soon: true },
      { label: 'Logging preference', soon: true },
    ],
  },
  {
    title: 'DATA',
    rows: [
      { label: 'Back up to a file', soon: true },
      { label: 'Restore from a file', soon: true },
      { label: 'Export to CSV', soon: true },
      { label: 'Import v1 backup', soon: true },
    ],
  },
  {
    title: 'ABOUT',
    rows: [
      { label: 'Version', value: '0.1.0' },
      { label: 'Salapify', value: 'v2' },
    ],
  },
];

export default function More() {
  const { colors, mode, setMode } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);

  // One settings row: label on the left, a value or a "Soon" chip on the right.
  const Row = ({ row, last }) => (
    <View style={[styles.row, !last && styles.rowDivider]}>
      <Text style={styles.rowLabel}>{row.label}</Text>
      {row.soon ? (
        <Text style={styles.soon}>Soon</Text>
      ) : row.value ? (
        <Text style={styles.rowValue}>{row.value}</Text>
      ) : (
        <Ionicons name="chevron-forward" size={18} color={colors.faint} />
      )}
    </View>
  );

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.pageTitle}>Settings</Text>

        {/* Appearance: the one that works today. */}
        <Text style={styles.sectionTitle}>APPEARANCE</Text>
        <View style={styles.card}>
          {APPEARANCE.map((opt, i) => {
            const selected = mode === opt.key;
            return (
              <Pressable
                key={opt.key}
                onPress={() => setMode(opt.key)}
                style={({ pressed }) => [
                  styles.row,
                  i > 0 && styles.rowDivider,
                  pressed && styles.pressed,
                ]}
              >
                <Text style={styles.rowLabel}>{opt.label}</Text>
                {selected ? (
                  <Ionicons name="checkmark" size={20} color={colors.primary} />
                ) : null}
              </Pressable>
            );
          })}
        </View>
        <Text style={styles.hint}>System follows your phone's light or dark setting.</Text>

        {/* The rest of the settings structure. */}
        {SECTIONS.map((section) => (
          <View key={section.title}>
            <Text style={styles.sectionTitle}>{section.title}</Text>
            <View style={styles.card}>
              {section.rows.map((row, i) => (
                <Row key={row.label} row={row} last={i === section.rows.length - 1} />
              ))}
            </View>
          </View>
        ))}

        <Text style={styles.footnote}>
          Rows marked Soon get wired up in the next phases.
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
      marginTop: spacing.md,
      paddingHorizontal: spacing.xs,
    },
    card: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.lg,
      paddingHorizontal: spacing.lg,
    },
    row: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'space-between',
      paddingVertical: spacing.md + 2,
    },
    rowDivider: {
      borderTopColor: colors.border,
      borderTopWidth: StyleSheet.hairlineWidth,
    },
    pressed: { opacity: 0.6 },
    rowLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    rowValue: { color: colors.muted, fontSize: fontSize.body },
    soon: {
      color: colors.softGreen,
      fontSize: fontSize.caption,
      fontWeight: fontWeight.medium,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.pill,
      paddingHorizontal: spacing.sm,
      paddingVertical: 2,
      overflow: 'hidden',
    },
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
      marginTop: spacing.lg,
    },
  });
}
