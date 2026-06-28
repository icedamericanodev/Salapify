// Overview screen (the Home tab). For now it shows the brand card.
// In a later step we will replace this with the real net worth and
// cash flow summary, ported from v1.

import { StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

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
  screen: { flex: 1, backgroundColor: '#0E1512' },
  body: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 },
  card: {
    width: '100%',
    maxWidth: 360,
    backgroundColor: '#16211C',
    borderColor: '#244034',
    borderWidth: 1,
    borderRadius: 18,
    padding: 28,
    alignItems: 'center',
  },
  kicker: {
    color: '#7FB89E',
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 2,
    marginBottom: 10,
  },
  title: { color: '#1D9E75', fontSize: 34, fontWeight: '800' },
  version: { color: '#8A9690', fontSize: 13, marginTop: 4 },
  tagline: { color: '#D7E0DB', fontSize: 15, marginTop: 16, textAlign: 'center' },
  hint: { color: '#5A6B63', fontSize: 13, marginTop: 20, textAlign: 'center' },
});
