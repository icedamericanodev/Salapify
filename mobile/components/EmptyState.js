// A friendly placeholder shown when a list has no items yet. Reused across
// screens so empty areas look intentional instead of blank.

import { useMemo } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { spacing, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';

export default function EmptyState({ icon = '✨', title, subtitle }) {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  return (
    <View style={styles.wrap}>
      <Text style={styles.icon}>{icon}</Text>
      <Text style={styles.title}>{title}</Text>
      {subtitle ? <Text style={styles.subtitle}>{subtitle}</Text> : null}
    </View>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    wrap: { alignItems: 'center', paddingVertical: spacing.xl },
    icon: { fontSize: 32, marginBottom: spacing.sm },
    title: { color: colors.textSecondary, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    subtitle: { color: colors.faint, fontSize: fontSize.small, marginTop: spacing.xs, textAlign: 'center' },
  });
}
