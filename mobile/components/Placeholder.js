// A simple reusable screen for tabs we have not built yet.
// It now reads colors from the Theme context, so it follows light or dark.

import { useMemo } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { spacing, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';

export default function Placeholder({ title, note }) {
  const { colors } = useTheme();
  // Build the styles from the active colors. useMemo rebuilds them only when
  // the colors change (that is, when you switch theme).
  const styles = useMemo(() => makeStyles(colors), [colors]);

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.body}>
        <Text style={styles.kicker}>SALAPIFY</Text>
        <Text style={styles.title}>{title}</Text>
        <Text style={styles.note}>{note}</Text>
      </View>
    </SafeAreaView>
  );
}

// makeStyles takes the active colors and returns the styles. We pass colors in
// rather than importing a fixed set, so the screen can change theme.
function makeStyles(colors) {
  return StyleSheet.create({
    screen: {
      flex: 1,
      backgroundColor: colors.background,
    },
    body: {
      flex: 1,
      alignItems: 'center',
      justifyContent: 'center',
      padding: spacing.xl,
    },
    kicker: {
      color: colors.softGreen,
      fontSize: fontSize.caption,
      fontWeight: fontWeight.medium,
      letterSpacing: 2,
      marginBottom: spacing.sm,
    },
    title: {
      color: colors.text,
      fontSize: fontSize.big,
      fontWeight: fontWeight.bold,
    },
    note: {
      color: colors.muted,
      fontSize: fontSize.body,
      marginTop: spacing.sm,
      textAlign: 'center',
    },
  });
}
