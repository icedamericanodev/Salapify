// Overview screen (the Home tab). For now it shows the brand card.
// In a later step we will replace this with the real net worth and
// cash flow summary, ported from v1. It now uses our theme tokens.

import { StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { colors, spacing, radius, fontSize, fontWeight } from '../../theme';

export default function Overview() {
  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.body}>
        <View style={styles.card}>
          <Text style={styles.kicker}>PERSONAL FINANCE</Text>
          <Text style={styles.title}>Salapify</Text>
          <Text style={styles.version}>v2 . React Native</Text>
          <Text style={styles.tagline}>Your money, calm and clear.</Text>
        </View>

        <Text style={styles.hint}>
          Tap the tabs below to move between sections.
        </Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.background },
  body: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.xl },
  card: {
    width: '100%',
    maxWidth: 360,
    backgroundColor: colors.card,
    borderColor: colors.border,
    borderWidth: 1,
    borderRadius: radius.lg,
    padding: spacing.xl + spacing.xs, // a touch more breathing room
    alignItems: 'center',
  },
  kicker: {
    color: colors.softGreen,
    fontSize: fontSize.caption,
    fontWeight: fontWeight.medium,
    letterSpacing: 2,
    marginBottom: spacing.sm,
  },
  title: { color: colors.primary, fontSize: fontSize.huge, fontWeight: fontWeight.bold },
  version: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.xs },
  tagline: {
    color: colors.textSecondary,
    fontSize: fontSize.body,
    marginTop: spacing.lg,
    textAlign: 'center',
  },
  hint: {
    color: colors.faint,
    fontSize: fontSize.small,
    marginTop: spacing.xl,
    textAlign: 'center',
  },
});
