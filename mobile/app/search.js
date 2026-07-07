// Search: one box that finds anything on the device, grouped by kind.
// Entries, utang, debts, goals, notes, and accounts. The matching lives in
// lib/search.js (pure and tested); this screen only renders results and
// routes a tap to the screen that owns the item. Nothing leaves the phone.
//
// Typing stays smooth on large data because the query drives a deferred
// value: the input updates instantly while the (heavier) result list catches
// up a beat behind, instead of blocking every keystroke.

import { useDeferredValue, useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';
import { formatMoney } from '../lib/format';
import { search } from '../lib/search';
import EmptyState from '../components/EmptyState';

const GROUP_ICON = {
  transactions: 'receipt-outline',
  utang: 'people-outline',
  debts: 'card-outline',
  goals: 'flag-outline',
  notes: 'document-text-outline',
  accounts: 'wallet-outline',
};

export default function Search() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data } = useAppData();

  const [query, setQuery] = useState('');
  const deferred = useDeferredValue(query);
  const result = useMemo(() => search(data, deferred), [data, deferred]);

  const openGroup = (route) => {
    try {
      // Entries land on History pre-filtered to the same words.
      if (route === '/history') router.push({ pathname: '/history', params: { q: query.trim() } });
      else router.push(route);
    } catch (e) {
      // A bad route must never crash search.
    }
  };

  const amountColor = (sign) => (sign === '+' ? colors.primary : sign === '-' ? colors.text : colors.muted);

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable
          onPress={() => (router.canGoBack && router.canGoBack() ? router.back() : router.replace('/(tabs)'))}
          hitSlop={10}
          style={styles.back}
        >
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>Search</Text>
        <View style={{ width: 24 }} />
      </View>

      <View style={styles.searchWrap}>
        <Ionicons name="search" size={18} color={colors.faint} />
        <TextInput
          style={styles.searchInput}
          value={query}
          onChangeText={setQuery}
          placeholder="Search anything, like jollibee, Ana, or 1500"
          placeholderTextColor={colors.faint}
          autoCapitalize="none"
          autoFocus
          returnKeyType="search"
        />
        {query ? (
          <Pressable onPress={() => setQuery('')} hitSlop={8}>
            <Ionicons name="close-circle" size={18} color={colors.faint} />
          </Pressable>
        ) : null}
      </View>

      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled" keyboardDismissMode="on-drag">
        {result.empty ? (
          <View style={styles.hint}>
            <Text style={styles.hintTitle}>Find anything, fast</Text>
            <Text style={styles.hintText}>
              Search across your entries, utang, debts, goals, notes, and accounts. Try a name, a place, a category, or an amount.
            </Text>
          </View>
        ) : result.total === 0 ? (
          <EmptyState icon="🔍" title="No matches" subtitle={`Nothing found for "${result.query}". Try fewer or different words.`} />
        ) : (
          result.groups.map((g) => (
            <View key={g.kind} style={styles.group}>
              <View style={styles.groupHead}>
                <Ionicons name={GROUP_ICON[g.kind] || 'search'} size={15} color={colors.muted} />
                <Text style={styles.groupTitle}>{g.title}</Text>
                <Text style={styles.groupCount}>{g.count}</Text>
              </View>
              {g.items.map((it) => (
                <Pressable key={it.id} onPress={() => openGroup(g.route)} style={({ pressed }) => [styles.row, pressed && styles.pressed]}>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.rowTitle} numberOfLines={1}>{it.title}</Text>
                    {it.subtitle ? <Text style={styles.rowSub} numberOfLines={1}>{it.subtitle}</Text> : null}
                  </View>
                  {it.amount != null ? (
                    <Text style={[styles.rowAmount, { color: amountColor(it.sign) }]}>
                      {it.sign ? `${it.sign} ` : ''}{formatMoney(it.amount)}
                    </Text>
                  ) : null}
                </Pressable>
              ))}
              {g.more > 0 ? (
                <Pressable onPress={() => openGroup(g.route)} style={styles.moreRow}>
                  <Text style={styles.moreText}>{g.more} more in {g.title}</Text>
                  <Ionicons name="chevron-forward" size={14} color={colors.primary} />
                </Pressable>
              ) : null}
            </View>
          ))
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: spacing.lg, paddingTop: spacing.md, paddingBottom: spacing.sm },
    back: { marginLeft: -4 },
    headerTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },

    searchWrap: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: spacing.sm,
      marginHorizontal: spacing.lg,
      marginBottom: spacing.sm,
      paddingHorizontal: spacing.md,
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.md,
    },
    searchInput: { flex: 1, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },

    content: { padding: spacing.lg, paddingBottom: spacing.xxl },

    hint: { paddingTop: spacing.xxl, alignItems: 'center', paddingHorizontal: spacing.lg },
    hintTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginBottom: spacing.sm },
    hintText: { color: colors.textSecondary, fontSize: fontSize.body, textAlign: 'center', lineHeight: 22 },

    group: { marginBottom: spacing.xl },
    groupHead: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginBottom: spacing.sm },
    groupTitle: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.bold, textTransform: 'uppercase', letterSpacing: 0.5, flex: 1 },
    groupCount: { color: colors.faint, fontSize: fontSize.caption },

    row: { flexDirection: 'row', alignItems: 'center', paddingVertical: spacing.md, borderBottomColor: colors.border, borderBottomWidth: StyleSheet.hairlineWidth, gap: spacing.sm },
    rowTitle: { color: colors.text, fontSize: fontSize.body },
    rowSub: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },
    rowAmount: { fontSize: fontSize.body, fontWeight: fontWeight.bold },

    moreRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 4, paddingVertical: spacing.md },
    moreText: { color: colors.primary, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    pressed: { opacity: 0.6 },
  });
}
