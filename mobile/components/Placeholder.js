// A simple reusable screen for tabs we have not built yet.
// It shows a title and a short note, using our dark theme colors.
// Reusing this keeps each tab file tiny until we build the real screen.

import { StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

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
    backgroundColor: '#0E1512', // app background
  },
  body: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  kicker: {
    color: '#7FB89E',
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 2,
    marginBottom: 8,
  },
  title: {
    color: '#FFFFFF',
    fontSize: 28,
    fontWeight: '800',
  },
  note: {
    color: '#8A9690',
    fontSize: 14,
    marginTop: 10,
    textAlign: 'center',
  },
});
