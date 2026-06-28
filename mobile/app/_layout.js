// This is the root layout. Expo Router loads it first and it wraps every
// screen in the app. We keep it minimal: a SafeAreaProvider (so screens can
// avoid notches and the status bar) and a Stack that holds our tab group.

import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';

export default function RootLayout() {
  return (
    <SafeAreaProvider>
      {/* headerShown: false hides the default top bar; our screens draw their own. */}
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="(tabs)" />
      </Stack>

      {/* Light status bar icons so they are visible on our dark background. */}
      <StatusBar style="light" />
    </SafeAreaProvider>
  );
}
