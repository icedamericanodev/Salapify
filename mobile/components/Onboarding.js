// Onboarding: the first run welcome. Three quick steps: what Salapify is,
// set your currency and monthly budget, then choose how to start. Shows
// only until settings.onboarded is true, so everyone sees it exactly once.
// The Start empty choice deletes data, so it always confirms first.

import { useMemo, useState } from 'react';
import { Alert, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';

const CURRENCY_CHIPS = [
  { code: 'PHP', symbol: '₱' },
  { code: 'USD', symbol: '$' },
  { code: 'EUR', symbol: '€' },
  { code: 'SGD', symbol: 'S$' },
];

export default function Onboarding() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const { data, updateSettings, replaceAll } = useAppData();

  const [step, setStep] = useState(0);
  // Start from whatever is already saved, so a restored USD user who taps
  // through never gets silently reset to pesos.
  const [currency, setCurrency] = useState({
    code: data.settings.currencyCode || 'PHP',
    symbol: data.settings.currency || '₱',
  });
  const [limit, setLimit] = useState(String(data.settings.monthlyLimit || 20000));

  // After Erase everything the app is already empty, so the sample data
  // pitch on step 2 would be a lie. This flips step 2 to one honest button.
  const hasAnything = ['accounts', 'transactions', 'debts', 'receivables'].some(
    (k) => (data[k] || []).length > 0
  );

  function finish(startEmpty) {
    // Accept human typing: commas and spaces stripped, capped at 100 million.
    // A typed 0 is a real answer (no budget yet, set one later in Budget),
    // so it stays 0 instead of silently becoming the 20,000 default. Only a
    // cleared field or non numeric typing falls back to the default.
    const raw = String(limit).replace(/[,\s]/g, '');
    const n = Number(raw);
    const monthlyLimit = raw !== '' && Number.isFinite(n) && n >= 0 ? Math.min(n, 100000000) : 20000;
    const patch = {
      currency: currency.symbol,
      currencyCode: currency.code,
      monthlyLimit,
      onboarded: true,
    };
    if (startEmpty) {
      const wipe = () => replaceAll({ settings: { ...data.settings, ...patch } });
      const message =
        'This clears everything currently in the app, including any sample data. This cannot be undone.';
      if (Platform.OS === 'web') {
        // Alert with buttons is a no-op in browsers, so confirm the web way.
        if (typeof window !== 'undefined' && window.confirm(message)) wipe();
        return;
      }
      Alert.alert('Start with an empty app?', message, [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Start empty', style: 'destructive', onPress: wipe },
      ]);
      return;
    }
    updateSettings(patch);
  }

  return (
    <SafeAreaView style={styles.screen} edges={['top', 'bottom']}>
      <ScrollView contentContainerStyle={styles.content}>
        {step === 0 ? (
          <View style={styles.center}>
            <View style={styles.logoBadge}>
              <Text style={styles.logoEmoji}>📈</Text>
            </View>
            <Text style={styles.title}>Salapify</Text>
            <Text style={styles.tagline}>On your money's side.</Text>
            <View style={styles.pillRow}>
              <Text style={styles.pill}>Free</Text>
              <Text style={styles.pill}>Offline</Text>
              <Text style={styles.pill}>No ads</Text>
            </View>
            <Text style={styles.body}>
              Budget, debts, savings, utang, and bills. Everything stays on your
              phone. No account needed, ever.
            </Text>
            <Pressable onPress={() => setStep(1)} style={({ pressed }) => [styles.primaryBtn, pressed && styles.pressed]}>
              <Text style={styles.primaryText}>Get started</Text>
            </Pressable>
          </View>
        ) : null}

        {step === 1 ? (
          <View>
            <Text style={styles.stepKicker}>STEP 1 OF 2</Text>
            <Text style={styles.heading}>The basics</Text>

            <Text style={styles.fieldLabel}>Your currency</Text>
            <View style={styles.chips}>
              {CURRENCY_CHIPS.map((c) => {
                const on = currency.code === c.code;
                return (
                  <Pressable key={c.code} onPress={() => setCurrency(c)} style={[styles.chip, on && styles.chipOn]}>
                    <Text style={[styles.chipText, on && styles.chipTextOn]}>
                      {c.symbol} {c.code}
                    </Text>
                  </Pressable>
                );
              })}
            </View>
            <Text style={styles.hint}>More currencies live in Settings.</Text>

            <Text style={styles.fieldLabel}>Monthly spending budget</Text>
            <TextInput
              style={styles.input}
              value={limit}
              onChangeText={setLimit}
              keyboardType="numeric"
              placeholder="20000"
              placeholderTextColor={colors.faint}
            />
            <Text style={styles.hint}>
              A starting line, not a cage. Change it anytime in Settings.
            </Text>

            <Pressable onPress={() => setStep(2)} style={({ pressed }) => [styles.primaryBtn, pressed && styles.pressed]}>
              <Text style={styles.primaryText}>Next</Text>
            </Pressable>
          </View>
        ) : null}

        {step === 2 ? (
          <View>
            <Text style={styles.stepKicker}>STEP 2 OF 2</Text>
            {hasAnything ? (
              <>
                <Text style={styles.heading}>How do you want to start?</Text>
                <Text style={styles.body}>
                  The app comes with a little sample data so you can poke around
                  and see how everything works. Or begin with a clean slate.
                </Text>

                <Pressable onPress={() => finish(false)} style={({ pressed }) => [styles.primaryBtn, pressed && styles.pressed]}>
                  <Text style={styles.primaryText}>Explore with what is in the app</Text>
                </Pressable>
                <Pressable onPress={() => finish(true)} style={({ pressed }) => [styles.secondaryBtn, pressed && styles.pressed]}>
                  <Text style={styles.secondaryText}>Start empty</Text>
                </Pressable>
              </>
            ) : (
              <>
                <Text style={styles.heading}>You are all set.</Text>
                <Text style={styles.body}>
                  The app is empty and ready. Add your accounts, log your first
                  entry, and your streak starts today.
                </Text>

                <Pressable onPress={() => finish(false)} style={({ pressed }) => [styles.primaryBtn, pressed && styles.pressed]}>
                  <Text style={styles.primaryText}>Start tracking</Text>
                </Pressable>
              </>
            )}

            <Text style={styles.hint}>
              Tip: after this, the Budget tab is where daily life happens. Log
              anything today and your chain starts.
            </Text>
          </View>
        ) : null}
      </ScrollView>
    </SafeAreaView>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    content: { flexGrow: 1, justifyContent: 'center', padding: spacing.xl },
    center: { alignItems: 'center' },

    logoBadge: {
      width: 110,
      height: 110,
      borderRadius: radius.xl,
      backgroundColor: colors.primary,
      alignItems: 'center',
      justifyContent: 'center',
      marginBottom: spacing.lg,
    },
    logoEmoji: { fontSize: 52 },
    title: { color: colors.text, fontSize: fontSize.display, fontWeight: fontWeight.heavy },
    tagline: { color: colors.textSecondary, fontSize: fontSize.subtitle, marginTop: spacing.xs },
    pillRow: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.lg },
    pill: {
      color: colors.primary,
      borderColor: colors.primary,
      borderWidth: 1,
      borderRadius: radius.pill,
      paddingHorizontal: spacing.md,
      paddingVertical: spacing.xs,
      fontSize: fontSize.small,
      fontWeight: fontWeight.bold,
      overflow: 'hidden',
    },
    body: {
      color: colors.textSecondary,
      fontSize: fontSize.body,
      lineHeight: 22,
      textAlign: 'center',
      marginTop: spacing.xl,
    },

    stepKicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.bold, letterSpacing: 1.2 },
    heading: { color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.heavy, marginTop: spacing.sm, marginBottom: spacing.md },
    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginTop: spacing.lg, marginBottom: spacing.sm },
    chips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
    chip: { borderWidth: 1, borderColor: colors.border, borderRadius: radius.pill, paddingHorizontal: spacing.lg, paddingVertical: spacing.md },
    chipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    chipText: { color: colors.muted, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    chipTextOn: { color: colors.onPrimary },
    input: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.md,
      paddingHorizontal: spacing.md,
      paddingVertical: spacing.md,
      color: colors.text,
      fontSize: fontSize.subtitle,
    },
    hint: { color: colors.faint, fontSize: fontSize.small, marginTop: spacing.sm },

    primaryBtn: {
      backgroundColor: colors.primary,
      borderRadius: radius.md,
      minHeight: 52,
      alignItems: 'center',
      justifyContent: 'center',
      marginTop: spacing.xl,
      paddingHorizontal: spacing.xl,
    },
    primaryText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    secondaryBtn: {
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.md,
      minHeight: 52,
      alignItems: 'center',
      justifyContent: 'center',
      marginTop: spacing.md,
    },
    secondaryText: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    pressed: { opacity: 0.7 },
  });
}
