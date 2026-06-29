// Overview screen (the Home tab). For now it shows the brand card plus a
// small test button that proves data saving works. The tapped count is stored
// on the phone, so it stays the same even after you fully close the app.
// In a later step this screen becomes the real net worth and cash flow summary.

import { Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { colors, spacing, radius, fontSize, fontWeight } from '../../theme';
import { useAppData } from '../../context/AppData';

export default function Overview() {
  // Read the shared data and the function that updates it.
  const { data, setData } = useAppData();

  // Add one to the saved counter. Using a function form is the safe way to
  // update based on the previous value.
  function tap() {
    setData((prev) => ({ ...prev, testCounter: prev.testCounter + 1 }));
  }

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.body}>
        <View style={styles.card}>
          <Text style={styles.kicker}>PERSONAL FINANCE</Text>
          <Text style={styles.title}>Salapify</Text>
          <Text style={styles.version}>v2 . React Native</Text>
          <Text style={styles.tagline}>Your money, calm and clear.</Text>
        </View>

        {/* Test of on-device saving. Tap, then fully close and reopen the app. */}
        <View style={styles.card}>
          <Text style={styles.kicker}>SAVE TEST</Text>
          <Text style={styles.counter}>{data.testCounter}</Text>
          <Pressable
            onPress={tap}
            // style can be a function to react to being pressed.
            style={({ pressed }) => [styles.button, pressed && styles.buttonPressed]}
          >
            <Text style={styles.buttonText}>Tap to save</Text>
          </Pressable>
          <Text style={styles.hint}>
            Tap a few times, fully close the app, reopen it. The number stays.
          </Text>
        </View>
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
    padding: spacing.xl,
    alignItems: 'center',
    marginBottom: spacing.lg,
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
  counter: {
    color: colors.text,
    fontSize: fontSize.huge,
    fontWeight: fontWeight.bold,
    marginBottom: spacing.md,
  },
  button: {
    backgroundColor: colors.primary,
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.xl,
    borderRadius: radius.md,
  },
  buttonPressed: { opacity: 0.7 }, // slight dim while pressed
  buttonText: { color: '#FFFFFF', fontSize: fontSize.body, fontWeight: fontWeight.medium },
  hint: {
    color: colors.faint,
    fontSize: fontSize.small,
    marginTop: spacing.md,
    textAlign: 'center',
  },
});
