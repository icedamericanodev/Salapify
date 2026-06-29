// A simple reusable screen for tabs we have not built yet.
// It shows a title and a short note, using our shared theme tokens.

import { StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { colors, spacing, fontSize, fontWeight } from '../theme';

export default function Placeholder({ title, note }) {
  return (
    // SafeAreaView with edges top keeps content below the phone's status bar.
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.body}>
        <Text style={styles.kicker}>SALAPIFY</Text>
        <Text style={styles.title}>{title}</Text>
        <Text style={styles.note}>{note}</Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
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
