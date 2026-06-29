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
  const { width, height } = useWindowDimensions();

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
      <View style={[webStyles.phone, { width: frameWidth, height: frameHeight }]}>
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
    // width and height are set at runtime so the frame scales with the window
    maxWidth: '100%',
    overflow: 'hidden',
    borderRadius: 28,
    borderWidth: 1,
    borderColor: '#2A2A2A',
  },
};
