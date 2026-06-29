// This file defines the bottom tab bar. Each <Tabs.Screen> points to a file
// in this same folder. The "name" must match the file name (without .js).
// For example name="accounts" shows accounts.js.

import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../../context/Theme';

export default function TabsLayout() {
  // Read the active colors so the tab bar recolors when the theme changes.
  const { colors } = useTheme();
  // Bottom inset so labels are not cut off by the phone's gesture bar.
  const insets = useSafeAreaInsets();

  return (
    <Tabs
      screenOptions={{
        headerShown: false, // each screen draws its own header
        tabBarActiveTintColor: colors.primary, // selected tab
        tabBarInactiveTintColor: colors.muted, // the others
        tabBarStyle: {
          backgroundColor: colors.card, // bar background
          borderTopColor: colors.border, // subtle top border
          height: 62 + insets.bottom, // room for icon + label + safe area
          paddingTop: 8,
          paddingBottom: insets.bottom + 10,
        },
        tabBarLabelStyle: { fontSize: 11, fontWeight: '600' },
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
      <Tabs.Screen
        name="accounts"
        options={{
          title: 'Accounts',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="wallet-outline" color={color} size={size} />
          ),
        }}
      />
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
  );
}
