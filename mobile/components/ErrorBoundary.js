// ErrorBoundary: catches errors thrown during RENDER (and lifecycles and
// constructors) anywhere below it, showing a calm recovery screen instead
// of a dead white screen. Honest scope note: React boundaries do NOT
// catch errors inside press handlers, async code, or timers; those paths
// must handle their own failures. It NEVER touches storage, so the data
// on disk is exactly as it was; Try again remounts the tree, which
// reloads from the saved state (the store flushes its pending save on
// unmount so nothing in the debounce window is lost). Colors are
// hardcoded forest dark on purpose: this must render even if the theme
// system itself is what crashed.

import { Component } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

export default class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }

  static getDerivedStateFromError(error) {
    return { error };
  }

  componentDidCatch(error, info) {
    // Log only. No storage writes, no network. The blob on disk is safe.
    console.warn('Salapify screen crash:', error, info && info.componentStack);
  }

  render() {
    if (!this.state.error) return this.props.children;
    return (
      <View style={styles.screen}>
        <Text style={styles.emoji}>😅</Text>
        <Text style={styles.title}>Something went wrong</Text>
        <Text style={styles.body}>
          The screen hit an error, but your money data is safe on this phone. Nothing was
          changed or deleted.
        </Text>
        <Pressable onPress={() => this.setState({ error: null })} style={styles.btn}>
          <Text style={styles.btnText}>Try again</Text>
        </Pressable>
        <Text style={styles.hint}>
          If this keeps happening, close the app fully and reopen it, then check for updates in
          More.
        </Text>
      </View>
    );
  }
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#101E15',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 32,
  },
  emoji: { fontSize: 44, marginBottom: 12 },
  title: { color: '#FBF7EF', fontSize: 22, fontWeight: '800', marginBottom: 10 },
  body: { color: '#D9D6C5', fontSize: 15, textAlign: 'center', lineHeight: 22, marginBottom: 24 },
  btn: {
    backgroundColor: '#FFA45C',
    borderRadius: 14,
    paddingVertical: 12,
    paddingHorizontal: 28,
  },
  btnText: { color: '#3A1E07', fontSize: 15, fontWeight: '700' },
  hint: { color: '#9DAF9D', fontSize: 13, textAlign: 'center', marginTop: 20, lineHeight: 19 },
});
