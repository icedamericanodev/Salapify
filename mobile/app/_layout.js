// This is the root layout. Expo Router loads it first and it wraps every
// screen. We wrap everything in two providers: ThemeProvider (light/dark
// colors) and AppDataProvider (the saved data). Then a Stack holds the tabs.

import { Platform, View, useWindowDimensions } from 'react-native';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { AppDataProvider } from '../context/AppData';
import { ThemeProvider, useTheme } from '../context/Theme';

// On a phone, this just shows the app full screen. In a web browser, it draws
// the app inside a centered phone-shaped frame so the preview looks like a
// phone. It changes nothing on the real device.
function PhoneFrame({ children }) {
  const { height } = useWindowDimensions();

  if (Platform.OS !== 'web') {
    return children;
  }

  const frameHeight = Math.min(height - 32, 880); // leave a little margin
  return (
    <View style={webStyles.backdrop}>
      <View style={[webStyles.phone, { height: frameHeight }]}>{children}</View>
    </View>
  );
}

// Small helper so the status bar icons flip to match the theme.
function ThemedStatusBar() {
  const { isDark } = useTheme();
  return <StatusBar style={isDark ? 'light' : 'dark'} />;
}

export default function RootLayout() {
  return (
    <ThemeProvider>
      <AppDataProvider>
        <SafeAreaProvider>
          <PhoneFrame>
            {/* headerShown: false hides the default top bar; screens draw their own. */}
            <Stack screenOptions={{ headerShown: false }}>
              <Stack.Screen name="(tabs)" />
            </Stack>
          </PhoneFrame>

          <ThemedStatusBar />
        </SafeAreaProvider>
      </AppDataProvider>
    </ThemeProvider>
  );
}

// These styles only apply on web (PhoneFrame returns early on a real phone).
const webStyles = {
  backdrop: {
    flex: 1,
    minHeight: '100vh', // fill the browser window
    backgroundColor: '#0A0A0A', // dark page behind the phone
    alignItems: 'center',
    justifyContent: 'center',
  },
  phone: {
    width: 390, // typical phone width
    maxWidth: '100%',
    overflow: 'hidden',
    borderRadius: 28,
    borderWidth: 1,
    borderColor: '#2A2A2A',
  },
};
