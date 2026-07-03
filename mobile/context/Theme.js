// Theme context. Holds the chosen mode (light, dark, or system) AND the
// chosen color theme (forest or mint), works out the active palette, and
// saves both choices on the phone so they stick between app launches.
// Any screen reads colors with useTheme().

import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { useColorScheme } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { palettes, DEFAULT_PALETTE } from '../theme';

// Where we save the choices on the phone.
const MODE_KEY = 'salapify_theme_mode';
const PALETTE_KEY = 'salapify_theme_palette';

const ThemeContext = createContext(null);

export function ThemeProvider({ children }) {
  // The phone's own setting (light or dark). Null until the phone reports it.
  const device = useColorScheme();

  // Our chosen mode. "system" means follow the phone. Default to system.
  const [mode, setModeState] = useState('system');
  // Our chosen color theme. Forest is the Salapify brand.
  const [palette, setPaletteState] = useState(DEFAULT_PALETTE);

  // Load the saved choices once on startup.
  useEffect(() => {
    (async () => {
      try {
        const savedMode = await AsyncStorage.getItem(MODE_KEY);
        if (savedMode === 'light' || savedMode === 'dark' || savedMode === 'system') {
          setModeState(savedMode);
        }
        const savedPalette = await AsyncStorage.getItem(PALETTE_KEY);
        if (savedPalette && palettes[savedPalette]) {
          setPaletteState(savedPalette);
        }
      } catch (e) {
        console.warn('load theme failed', e);
      }
    })();
  }, []);

  // Change the mode and remember it on the phone.
  function setMode(next) {
    setModeState(next);
    AsyncStorage.setItem(MODE_KEY, next).catch((e) => console.warn('save theme mode failed', e));
  }

  // Change the color theme and remember it on the phone.
  function setPalette(next) {
    if (!palettes[next]) return;
    setPaletteState(next);
    AsyncStorage.setItem(PALETTE_KEY, next).catch((e) => console.warn('save palette failed', e));
  }

  // Decide the active palette. If mode is system, use the phone's setting.
  // Fall back to dark when the phone has not reported yet (dark first app).
  const scheme = mode === 'system' ? device || 'dark' : mode;
  const isDark = scheme === 'dark';
  const colors = palettes[palette][isDark ? 'dark' : 'light'];

  // useMemo avoids rebuilding this object unless something actually changed.
  const value = useMemo(
    () => ({ mode, setMode, palette, setPalette, colors, isDark }),
    [mode, palette, colors, isDark]
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

// Shortcut hook: const { colors, mode, setMode, palette, setPalette, isDark } = useTheme();
export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) {
    throw new Error('useTheme must be used inside ThemeProvider');
  }
  return ctx;
}
