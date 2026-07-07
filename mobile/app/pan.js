// Pan chat. A conversation screen reached from More. You type or tap a
// suggested question, Pan answers from your own on-device data with real
// numbers and one coaching line. No account, no network, nothing leaves the
// phone: every reply comes from lib/pan/ask, which only ever restates numbers
// the money engine computed. Conversation is in memory only, so nothing is
// stored and there is no schema change.

import { useMemo, useRef, useState, useCallback } from 'react';
import {
  FlatList,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  Share,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { useAppData } from '../context/AppData';
import Mascot from '../components/Mascot';
import { ask, helpReply, suggestions } from '../lib/pan/ask';

let seq = 0;
const nextId = () => `m${seq++}`;

export default function Pan() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data } = useAppData();

  // Newest first, so the inverted list renders naturally.
  const [messages, setMessages] = useState([]);
  const [draft, setDraft] = useState('');
  const [mood, setMood] = useState('idle');
  const chips = useMemo(() => suggestions(6), []);
  const greeting = useMemo(() => helpReply(), []);
  const listRef = useRef(null);

  const send = useCallback(
    (raw) => {
      const text = String(raw || '').trim();
      if (!text) return;
      const userMsg = { id: nextId(), role: 'user', text };
      let reply;
      try {
        reply = ask(data, text, { now: new Date() });
      } catch (e) {
        // Pan must never crash the screen; fall back to the help reply.
        reply = { ...helpReply(), text: 'Something went sideways on that one. Try one of these.' };
      }
      const panMsg = { id: nextId(), role: 'pan', ...reply };
      setMood(reply.mood || 'idle');
      setMessages((prev) => [panMsg, userMsg, ...prev]);
      setDraft('');
    },
    [data]
  );

  const openRoute = (route) => {
    try {
      router.push(route);
    } catch (e) {
      // A bad route must never crash the chat.
    }
  };

  const renderItem = ({ item }) => {
    if (item.role === 'user') {
      return (
        <View style={[styles.row, styles.rowRight]}>
          <View style={[styles.bubble, styles.userBubble]}>
            <Text style={styles.userText}>{item.text}</Text>
          </View>
        </View>
      );
    }
    return (
      <View style={[styles.row, styles.rowLeft]}>
        <View style={[styles.bubble, styles.panBubble]}>
          <Text style={styles.panText}>{item.text}</Text>
          {item.reminder ? (
            <Pressable
              onPress={() => Share.share({ message: item.reminder }).catch(() => {})}
              style={({ pressed }) => [styles.inlineBtn, pressed && styles.pressed]}
            >
              <Ionicons name="paper-plane-outline" size={14} color={colors.primary} />
              <Text style={styles.inlineBtnText}>Send this reminder</Text>
            </Pressable>
          ) : null}
          {item.cta ? (
            <Pressable
              onPress={() => openRoute(item.cta.route)}
              style={({ pressed }) => [styles.inlineBtn, pressed && styles.pressed]}
            >
              <Text style={styles.inlineBtnText}>{item.cta.label}</Text>
              <Ionicons name="chevron-forward" size={14} color={colors.primary} />
            </Pressable>
          ) : null}
          {/* When Pan is not sure, offer the suggested questions inline. */}
          {item.suggestions && item.suggestions.length ? (
            <View style={styles.inlineChips}>
              {item.suggestions.map((s) => (
                <Pressable key={s} onPress={() => send(s)} style={({ pressed }) => [styles.chip, pressed && styles.pressed]}>
                  <Text style={styles.chipText}>{s}</Text>
                </Pressable>
              ))}
            </View>
          ) : null}
        </View>
      </View>
    );
  };

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <View style={styles.headerCenter}>
          <Mascot size={40} state={mood} />
          <View>
            <Text style={styles.headerTitle}>Pan</Text>
            <Text style={styles.headerSub}>Reads only what is on your phone</Text>
          </View>
        </View>
        <View style={{ width: 24 }} />
      </View>

      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={Platform.OS === 'ios' ? 8 : 0}
      >
        {messages.length === 0 ? (
          <ScrollView contentContainerStyle={styles.empty}>
            <Mascot size={120} state="idle" />
            <Text style={styles.emptyTitle}>Hi, I am Pan.</Text>
            <Text style={styles.emptyText}>{greeting.text}</Text>
            <View style={styles.emptyChips}>
              {chips.map((c) => (
                <Pressable key={c.id} onPress={() => send(c.example)} style={({ pressed }) => [styles.chip, pressed && styles.pressed]}>
                  <Text style={styles.chipText}>{c.example}</Text>
                </Pressable>
              ))}
            </View>
          </ScrollView>
        ) : (
          <FlatList
            ref={listRef}
            data={messages}
            keyExtractor={(m) => m.id}
            renderItem={renderItem}
            inverted
            contentContainerStyle={styles.list}
            keyboardShouldPersistTaps="handled"
          />
        )}

        {/* Quick chips above the input once a chat has started. */}
        {messages.length > 0 ? (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipBar} keyboardShouldPersistTaps="handled">
            {chips.map((c) => (
              <Pressable key={c.id} onPress={() => send(c.example)} style={({ pressed }) => [styles.chip, pressed && styles.pressed]}>
                <Text style={styles.chipText}>{c.label}</Text>
              </Pressable>
            ))}
          </ScrollView>
        ) : null}

        <View style={styles.inputBar}>
          <TextInput
            style={styles.input}
            value={draft}
            onChangeText={setDraft}
            placeholder="Ask Pan about your money..."
            placeholderTextColor={colors.faint}
            onSubmitEditing={() => send(draft)}
            returnKeyType="send"
          />
          <Pressable onPress={() => send(draft)} style={({ pressed }) => [styles.sendBtn, pressed && styles.pressed]}>
            <Ionicons name="arrow-up" size={20} color={colors.onPrimary} />
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    headerBar: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'space-between',
      paddingHorizontal: spacing.lg,
      paddingTop: spacing.md,
      paddingBottom: spacing.sm,
      borderBottomColor: colors.border,
      borderBottomWidth: StyleSheet.hairlineWidth,
    },
    back: { marginLeft: -4 },
    headerCenter: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
    headerTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    headerSub: { color: colors.faint, fontSize: fontSize.caption },

    list: { padding: spacing.lg, paddingBottom: spacing.md },
    row: { flexDirection: 'row', marginBottom: spacing.md },
    rowLeft: { justifyContent: 'flex-start' },
    rowRight: { justifyContent: 'flex-end' },
    bubble: { maxWidth: '86%', borderRadius: radius.lg, paddingHorizontal: spacing.lg, paddingVertical: spacing.md },
    userBubble: { backgroundColor: colors.primary, borderBottomRightRadius: radius.sm },
    userText: { color: colors.onPrimary, fontSize: fontSize.body, lineHeight: 22 },
    panBubble: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderBottomLeftRadius: radius.sm },
    panText: { color: colors.text, fontSize: fontSize.body, lineHeight: 22 },

    inlineBtn: { flexDirection: 'row', alignItems: 'center', gap: 6, alignSelf: 'flex-start', marginTop: spacing.md, borderWidth: 1, borderColor: colors.primary, borderRadius: radius.pill, paddingVertical: spacing.sm, paddingHorizontal: spacing.md },
    inlineBtnText: { color: colors.primary, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    inlineChips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginTop: spacing.md },

    empty: { flexGrow: 1, alignItems: 'center', justifyContent: 'center', padding: spacing.xl },
    emptyTitle: { color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.heavy, marginTop: spacing.md },
    emptyText: { color: colors.textSecondary, fontSize: fontSize.body, textAlign: 'center', marginTop: spacing.sm, lineHeight: 22 },
    emptyChips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, justifyContent: 'center', marginTop: spacing.xl },

    chipBar: { paddingHorizontal: spacing.lg, paddingVertical: spacing.sm, gap: spacing.sm },
    chip: { borderWidth: 1, borderColor: colors.border, borderRadius: radius.pill, paddingHorizontal: spacing.md, paddingVertical: spacing.sm, backgroundColor: colors.card },
    chipText: { color: colors.textSecondary, fontSize: fontSize.small, fontWeight: fontWeight.medium },

    inputBar: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, padding: spacing.lg, borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth },
    input: { flex: 1, backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.pill, paddingHorizontal: spacing.lg, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
    sendBtn: { width: 44, height: 44, borderRadius: 22, backgroundColor: colors.primary, alignItems: 'center', justifyContent: 'center' },
    pressed: { opacity: 0.7 },
  });
}
