// App.js is the single screen the app shows right now.
// In later steps we will replace this with real navigation and screens.
// For now it just proves the app runs on your phone and shows our brand colors.

import { StatusBar } from 'expo-status-bar';
import { StyleSheet, Text, View } from 'react-native';

export default function App() {
  return (
    // The outer View fills the whole screen with the dark app background.
    <View style={styles.screen}>
      {/* A rounded "card" in the middle, like the cards we will use everywhere. */}
      <View style={styles.card}>
        {/* Small uppercase label, our design style for section headers. */}
        <Text style={styles.kicker}>PERSONAL FINANCE</Text>

        {/* The big brand title in primary green. */}
        <Text style={styles.title}>Salapify</Text>

        {/* A version tag so we know this is the new app. */}
        <Text style={styles.version}>v2 . React Native</Text>

        {/* A calm one liner. */}
        <Text style={styles.tagline}>Your money, calm and clear.</Text>
      </View>

      {/* Makes the phone's top status bar icons light, so they show on dark. */}
      <StatusBar style="light" />
    </View>
  );
}

// All the colors and sizes here will move into a shared theme.js file soon,
// so every screen reuses the same values. For now they live here to keep
// this first step simple.
const styles = StyleSheet.create({
  screen: {
    flex: 1, // fill the entire screen
    backgroundColor: '#0E1512', // app background (dark)
    alignItems: 'center', // center the card left to right
    justifyContent: 'center', // center the card top to bottom
    padding: 24,
  },
  card: {
    width: '100%',
    maxWidth: 360,
    backgroundColor: '#16211C', // card surface
    borderColor: '#244034', // card border
    borderWidth: 1,
    borderRadius: 18, // rounded corners
    padding: 28,
    alignItems: 'center',
  },
  kicker: {
    color: '#7FB89E', // soft green text
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 2, // spaced out uppercase look
    marginBottom: 10,
  },
  title: {
    color: '#1D9E75', // primary green
    fontSize: 34,
    fontWeight: '800',
  },
  version: {
    color: '#8A9690', // muted text
    fontSize: 13,
    marginTop: 4,
  },
  tagline: {
    color: '#D7E0DB', // secondary text
    fontSize: 15,
    marginTop: 16,
    textAlign: 'center',
  },
});
