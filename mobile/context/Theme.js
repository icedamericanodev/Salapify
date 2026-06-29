// Theme context. Holds the chosen mode (light, dark, or system), works out
// which color palette is active, and saves the choice on the phone so it
// sticks between app launches. Any screen reads colors with useTheme().

import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { useColorScheme } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { darkColors, lightColors } from '../theme';

// Where we save the chosen mode on the phone.
const MODE_KEY = 'salapify_theme_mode';

const ThemeContext = createContext(null);

export function ThemeProvider({ children }) {
  // The phone's own setting (light or dark). Null until the phone reports it.
  const device = useColorScheme();

  // Our chosen mode. "system" means follow the phone. Default to system.
  const [mode, setModeState] = useState('system');

  // Load the saved choice once on startup.
  useEffect(() => {
    (async () => {
      try {
        const saved = await AsyncStorage.getItem(MODE_KEY);
        if (saved === 'light' || saved === 'dark' || saved === 'system') {
          setModeState(saved);
        }
      } catch (e) {
        console.warn('load theme mode failed', e);
      }
    })();
  }, []);

  // Change the mode and remember it on the phone.
  function setMode(next) {
    setModeState(next);
    AsyncStorage.setItem(MODE_KEY, next).catch((e) =>
      console.warn('save theme mode failed', e)
    );
  }

  // Decide the active palette. If mode is system, use the phone's setting.
  // Fall back to dark when the phone has not reported yet (dark first app).
  const scheme = mode === 'system' ? device || 'dark' : mode;
  const isDark = scheme === 'dark';
  const colors = isDark ? darkColors : lightColors;

  // useMemo avoids rebuilding this object unless something actually changed.
  const value = useMemo(
    () => ({ mode, setMode, colors, isDark }),
    [mode, colors, isDark]
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

// Shortcut hook: const { colors, mode, setMode, isDark } = useTheme();
export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) {
    throw new Error('useTheme must be used inside ThemeProvider');
  }
  return ctx;
}
