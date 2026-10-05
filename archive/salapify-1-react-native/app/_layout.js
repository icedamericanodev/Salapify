// This is the root layout. Expo Router loads it first and it wraps every
// screen. We wrap everything in two providers: ThemeProvider (light/dark
// colors) and AppDataProvider (the saved data). Then a Stack holds the tabs.

import { Platform, Text, View, useWindowDimensions } from 'react-native';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { AppDataProvider, useAppData } from '../context/AppData';
import { ThemeProvider, useTheme } from '../context/Theme';
import { MotionProvider } from '../context/Motion';
import LockGate from '../components/LockGate';
import Onboarding from '../components/Onboarding';
import ErrorBoundary from '../components/ErrorBoundary';

// Shows the one time welcome flow until it has been completed, then the
// real app. While the saved data loads it shows a plain background, so
// neither sample data nor the welcome ever flashes at the wrong moment.
// If saved data exists but cannot be read, it says so instead of leaving
// a silent blank screen; nothing is deleted and saving stays off.
function OnboardingGate({ children }) {
  const { data, loaded, loadFailed } = useAppData();
  const { colors } = useTheme();
  if (loadFailed) {
    return (
      <View style={{ flex: 1, backgroundColor: colors.background, alignItems: 'center', justifyContent: 'center', padding: 32 }}>
        <Text style={{ color: colors.text, fontSize: 20, fontWeight: '700', textAlign: 'center' }}>
          Could not read your saved data
        </Text>
        <Text style={{ color: colors.textSecondary, fontSize: 15, textAlign: 'center', marginTop: 12, lineHeight: 22 }}>
          Nothing was deleted. Close the app fully and open it again. If this
          keeps happening, restore from your latest backup file.
        </Text>
      </View>
    );
  }
  if (!loaded) {
    return <View style={{ flex: 1, backgroundColor: colors.background }} />;
  }
  if (!(data.settings && data.settings.onboarded)) {
    return <Onboarding />;
  }
  return children;
}

// On a phone, this just shows the app full screen. In a web browser, it draws
// the app inside a centered phone-shaped frame so the preview looks like a
// phone. It changes nothing on the real device.
function PhoneFrame({ children }) {
  const { width, height } = useWindowDimensions();
  const { colors } = useTheme();

  if (Platform.OS !== 'web') {
    return children;
  }

  // Build a tall, modern phone shape that scales with the browser window.
  // Modern phones (including the S23 Ultra) are about 0.47 wide as they are
  // tall, so we size the height to the window, then derive the width from it.
  // The app inside lays out flexibly, so it fits any size, like a real phone.
  const frameHeight = Math.min(height - 24, 920);
  const frameWidth = Math.min(frameHeight * 0.47, width - 16);
  return (
    <View style={webStyles.backdrop}>
      {/* paddingBottom reserves a small strip (bar color) so the tab labels
          never reach the rounded bottom edge and get clipped, in the browser. */}
      <View
        style={[
          webStyles.phone,
          { width: frameWidth, height: frameHeight, backgroundColor: colors.card, paddingBottom: 18 },
        ]}
      >
        {children}
      </View>
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
    <ErrorBoundary>
    <ThemeProvider>
      <AppDataProvider>
        <MotionProvider>
        <SafeAreaProvider>
          <PhoneFrame>
            {/* LockGate shows the fingerprint screen first when App lock is on. */}
            <LockGate>
              <OnboardingGate>
                {/* headerShown: false hides the default top bar; screens draw their own. */}
                <Stack screenOptions={{ headerShown: false }}>
                  <Stack.Screen name="(tabs)" />
                </Stack>
              </OnboardingGate>
            </LockGate>
          </PhoneFrame>

          <ThemedStatusBar />
        </SafeAreaProvider>
        </MotionProvider>
      </AppDataProvider>
    </ThemeProvider>
    </ErrorBoundary>
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
    // width and height are set at runtime so the frame scales with the window
    maxWidth: '100%',
    overflow: 'hidden',
    borderRadius: 28,
    borderWidth: 1,
    borderColor: '#2A2A2A',
  },
};
