// This file defines the bottom tab bar. Each <Tabs.Screen> points to a file
// in this same folder. The "name" must match the file name (without .js).
// For example name="accounts" shows accounts.js.
//
// It also mounts the global floating add button. Logging is the heartbeat
// of the whole app, so adding an entry is one tap from every tab, not a
// walk to Budget first.

import { useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Tabs, useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../../context/Theme';
import { useAppData } from '../../context/AppData';
import LogSheet from '../../components/LogSheet';

export default function TabsLayout() {
  // Read the active colors so the tab bar recolors when the theme changes.
  const { colors } = useTheme();
  // Bottom inset so labels are not cut off by the phone's gesture bar.
  const insets = useSafeAreaInsets();
  const [logOpen, setLogOpen] = useState(false);
  const barHeight = 78 + insets.bottom;
  const { data, updateSettings, saveFailed } = useAppData();
  const router = useRouter();

  // Right after onboarding, open the add sheet once. The first session
  // should end with one real log, that is the habit's first rep. The flag
  // flips off immediately so this can never nag twice.
  const firstPrompt = !!(data.settings && data.settings.firstLogPrompt && data.settings.onboarded);
  useEffect(() => {
    if (firstPrompt) {
      updateSettings({ firstLogPrompt: false });
      setLogOpen(true);
    }
  }, [firstPrompt]);

  return (
    <View style={{ flex: 1 }}>
      {/* Shown only when saving has failed repeatedly: the one situation
          where staying quiet could cost the user their recent entries. */}
      {saveFailed ? (
        <Pressable
          onPress={() => router.push('/more')}
          style={[styles.saveBanner, { paddingTop: insets.top + 8, backgroundColor: colors.warningStrong }]}
        >
          <Text style={styles.saveBannerText}>
            Your changes are not saving to this phone. Tap here and back up to a file now.
          </Text>
        </Pressable>
      ) : null}
    <Tabs
      screenOptions={{
        headerShown: false, // each screen draws its own header
        tabBarActiveTintColor: colors.primary, // selected tab
        tabBarInactiveTintColor: colors.muted, // the others
        tabBarStyle: {
          backgroundColor: colors.card, // bar background
          borderTopColor: colors.border, // subtle top border
          height: 78 + insets.bottom, // room for icon + label + safe area
          paddingTop: 10,
          paddingBottom: insets.bottom + 18, // lifts labels off the bottom edge
        },
        tabBarLabelStyle: { fontSize: 11, fontWeight: '600', marginTop: 2 },
      }}
    >
      {/* index.js is the default screen, shown first. It is our Overview. */}
      <Tabs.Screen
        name="index"
        options={{
          title: 'Overview',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="home-outline" color={color} size={size} />
          ),
        }}
      />
      {/* Accounts moved off the bar to make room for Tools. Still reachable
          from the Home quick links and the More tab. */}
      <Tabs.Screen name="accounts" options={{ href: null }} />
      <Tabs.Screen
        name="debts"
        options={{
          title: 'Debts',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="card-outline" color={color} size={size} />
          ),
        }}
      />
      <Tabs.Screen
        name="budget"
        options={{
          title: 'Budget',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="pie-chart-outline" color={color} size={size} />
          ),
        }}
      />
      <Tabs.Screen
        name="tools"
        options={{
          title: 'Tools',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="calculator-outline" color={color} size={size} />
          ),
        }}
      />
      <Tabs.Screen
        name="insights"
        options={{
          title: 'Insights',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="bar-chart-outline" color={color} size={size} />
          ),
        }}
      />
      <Tabs.Screen
        name="more"
        options={{
          title: 'More',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="ellipsis-horizontal" color={color} size={size} />
          ),
        }}
      />
    </Tabs>

      {/* The floating add button, always one tap away above the tab bar. */}
      <Pressable
        onPress={() => setLogOpen(true)}
        style={({ pressed }) => [
          styles.fab,
          {
            bottom: barHeight + 16,
            backgroundColor: colors.primary,
            shadowColor: colors.primary,
            opacity: pressed ? 0.85 : 1,
          },
        ]}
        hitSlop={8}
        accessibilityLabel="Add entry"
      >
        <Ionicons name="add" size={30} color={colors.onPrimary} />
      </Pressable>

      <LogSheet
        visible={logOpen}
        onClose={() => setLogOpen(false)}
        toastBottom={barHeight + 84}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  saveBanner: {
    paddingHorizontal: 16,
    paddingBottom: 10,
  },
  saveBannerText: { color: '#FFFFFF', fontSize: 13, fontWeight: '600', textAlign: 'center' },
  fab: {
    position: 'absolute',
    right: 20,
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 6,
    shadowOpacity: 0.35,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 4 },
  },
});
