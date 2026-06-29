// This is the root layout. Expo Router loads it first and it wraps every
// screen. We wrap everything in two providers: ThemeProvider (light/dark
// colors) and AppDataProvider (the saved data). Then a Stack holds the tabs.

import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { AppDataProvider } from '../context/AppData';
import { ThemeProvider, useTheme } from '../context/Theme';

// Small helper so the status bar icons flip to match the theme:
// light icons on a dark background, dark icons on a light background.
function ThemedStatusBar() {
  const { isDark } = useTheme();
  return <StatusBar style={isDark ? 'light' : 'dark'} />;
}

export default function RootLayout() {
  return (
    // ThemeProvider is outermost so every screen (and the status bar) can read
    // the active colors. AppDataProvider holds the saved app data.
    <ThemeProvider>
      <AppDataProvider>
        <SafeAreaProvider>
          {/* headerShown: false hides the default top bar; screens draw their own. */}
          <Stack screenOptions={{ headerShown: false }}>
            <Stack.Screen name="(tabs)" />
          </Stack>

          <ThemedStatusBar />
        </SafeAreaProvider>
      </AppDataProvider>
    </ThemeProvider>
  );
}
