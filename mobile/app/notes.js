// Money notes. A simple notepad that does the math for you, like the iPhone
// Notes app. Type things like "grab to work 120 + 65" and the app quietly
// works out 185 for that line, then adds up every line into one total at the
// bottom of the editor. Notes save on the device on every keystroke.

import { useMemo, useState } from 'react';
import {
  Modal,
  Pressable,
  ScrollView,
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
import { formatMoney } from '../lib/format';
import EmptyState from '../components/EmptyState';

// ---------------------------------------------------------------------------
// The math engine. A small, safe calculator with no eval and no new Function.
// It reads a piece of text in two steps, exactly like a tiny pocket compiler:
//
//   1. tokenize() chops the text into tokens: numbers, + - * /, parentheses.
//      Numbers may contain commas (1,500.50) and may end in % (10% is 0.1).
//      Currency symbols are stripped before we get here. If the text contains
//      anything else (letters, emoji), tokenizing fails and we return null.
//   2. parseTokens() walks the tokens with a standard recursive descent
//      parser: expression is terms joined by + and -, term is factors joined
//      by * and /, factor is a number, a parenthesized expression, or a
//      leading sign. This gives * and / priority over + and - for free.
//
// Anything suspicious (divide by zero, unbalanced parens, leftover junk,
// numbers too big to trust) makes the whole line evaluate to null. A bad
// line simply shows no result. It never crashes the screen.
// ---------------------------------------------------------------------------

// Symbols we quietly remove so "₱120 + $80" still computes.
const CURRENCY_RE = /[₱$€£¥₩₹¢]/g;

// Results bigger than this are almost certainly typos, so we drop them.
const MAX_RESULT = 1e15;

// Step 1: turn text into a list of tokens, or null if the text is not math.
function tokenize(text) {
  const tokens = [];
  let i = 0;
  while (i < text.length) {
    const ch = text[i];
    if (ch === ' ' || ch === '\t') {
      i += 1;
      continue;
    }
    if ('+-*/()'.includes(ch)) {
      tokens.push({ type: ch });
      i += 1;
      continue;
    }
    if ((ch >= '0' && ch <= '9') || ch === '.') {
      // Read the whole number, commas and decimal point included.
      let raw = '';
      while (i < text.length && /[\d.,]/.test(text[i])) {
        raw += text[i];
        i += 1;
      }
      const plain = raw.replace(/,/g, '');
      // The digits must form one sane number, so "1..2" or a lone "." fail.
      if (!/^(\d+(\.\d+)?|\.\d+)$/.test(plain)) return null;
      let value = parseFloat(plain);
      // A trailing percent divides by 100, so "10%" becomes 0.1.
      let j = i;
      while (j < text.length && text[j] === ' ') j += 1;
      if (text[j] === '%') {
        value = value / 100;
        i = j + 1;
      }
      tokens.push({ type: 'num', value });
      continue;
    }
    // Any other character (a letter, for example) means this is not math.
    return null;
  }
  return tokens;
}

// Step 2: compute the tokens. Throws on any malformed input, and the caller
// catches everything, so the worst case is simply "no result for this line".
function parseTokens(tokens) {
  let pos = 0;
  const peek = () => tokens[pos];
  const next = () => tokens[pos++];

  function parseExpr() {
    let left = parseTerm();
    while (peek() && (peek().type === '+' || peek().type === '-')) {
      const op = next().type;
      const right = parseTerm();
      left = op === '+' ? left + right : left - right;
    }
    return left;
  }
  function parseTerm() {
    let left = parseFactor();
    while (peek() && (peek().type === '*' || peek().type === '/')) {
      const op = next().type;
      const right = parseFactor();
      if (op === '/') {
        if (right === 0) throw new Error('divide by zero');
        left = left / right;
      } else {
        left = left * right;
      }
    }
    return left;
  }
  function parseFactor() {
    const t = peek();
    if (!t) throw new Error('unexpected end');
    if (t.type === '+') {
      next();
      return parseFactor();
    }
    if (t.type === '-') {
      next();
      return -parseFactor();
    }
    if (t.type === 'num') {
      next();
      return t.value;
    }
    if (t.type === '(') {
      next();
      const inner = parseExpr();
      if (!peek() || peek().type !== ')') throw new Error('missing close paren');
      next();
      return inner;
    }
    throw new Error('unexpected token');
  }

  const value = parseExpr();
  // Leftover tokens mean something like "5 5" that never joined up. Reject.
  if (pos !== tokens.length) throw new Error('leftover tokens');
  return value;
}

// Evaluate one candidate string. Returns a finite number, or null.
export function evaluateMath(text) {
  const tokens = tokenize(text);
  if (!tokens || tokens.length === 0) return null;
  try {
    const value = parseTokens(tokens);
    if (!Number.isFinite(value) || Math.abs(value) > MAX_RESULT) return null;
    return value;
  } catch (e) {
    return null;
  }
}

// Pulls math out of a line that mixes words and numbers, like
// "grab to work 120 + 65". We take the longest contiguous math looking chunk.
const MATH_PIECE_RE = /[-+]?[\d,.]+(?:\s*[-+*/()]\s*[\d,.%]+)*/g;

// Look at one line of the note and decide what it is worth.
// Returns { value, bare }:
//   value is the computed number, or null when the line has no usable math.
//   bare is true when the line is just one plain number ("500"). A bare
//   number still counts toward the total, it just does not need its own row.
export function analyzeLine(rawLine) {
  const line = rawLine.replace(CURRENCY_RE, '').trim();
  // No digits at all means no math, skip early.
  if (!line || !/\d/.test(line)) return { value: null, bare: false };

  // First attempt: maybe the whole line is already a clean expression.
  const whole = evaluateMath(line);
  if (whole !== null) {
    const bare = /^[\d,.]+$/.test(line);
    return { value: whole, bare };
  }

  // Second attempt: the line mixes words and math. Grab the longest chunk
  // that looks like an expression, but only trust it if it truly computes
  // something, meaning it has an operator sitting after a digit. That is why
  // "10% of typo" shows nothing: the extracted "10" has no operator.
  const pieces = line.match(MATH_PIECE_RE) || [];
  let best = '';
  for (const p of pieces) {
    if (p.length > best.length) best = p;
  }
  if (best && /\d\s*[-+*/]/.test(best)) {
    const value = evaluateMath(best);
    if (value !== null) return { value, bare: false };
  }
  return { value: null, bare: false };
}

// Break a note into calculator rows. Each row remembers a short copy of its
// line so the CALCULATIONS panel can show where each number came from.
function computeCalc(text) {
  const lines = String(text || '').split('\n');
  const rows = [];
  let total = 0;
  let counted = 0;
  for (const raw of lines) {
    const { value, bare } = analyzeLine(raw);
    if (value === null) continue;
    total += value;
    counted += 1;
    if (!bare) {
      const trimmed = raw.trim();
      const label = trimmed.length > 26 ? trimmed.slice(0, 25) + '…' : trimmed;
      rows.push({ label, value });
    }
  }
  // Show the panel when at least one line did real math, or when two or more
  // plain numbers are worth adding up. One lonely bare number stays quiet.
  const hasMath = rows.length > 0 || counted >= 2;
  return { rows, total, hasMath };
}

export default function Notes() {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const router = useRouter();
  const { data, addItem, updateItem, removeItem } = useAppData();

  // We only keep the id of the note being edited. The text itself lives in
  // AppData, so every keystroke is already saved and nothing can be lost.
  const [editingId, setEditingId] = useState(null);
  const [confirmDel, setConfirmDel] = useState(false);

  const list = (data.notes || [])
    .slice()
    .sort((a, b) => String(b.updatedAt || '').localeCompare(String(a.updatedAt || '')));
  const editing = editingId ? list.find((n) => n.id === editingId) : null;
  const calc = useMemo(() => computeCalc(editing ? editing.text : ''), [editing]);

  function openAdd() {
    const id = addItem('notes', { text: '', updatedAt: new Date().toISOString() });
    setConfirmDel(false);
    setEditingId(id);
  }
  function openEdit(note) {
    setConfirmDel(false);
    setEditingId(note.id);
  }
  function onChangeText(t) {
    if (!editingId) return;
    updateItem('notes', editingId, { text: t, updatedAt: new Date().toISOString() });
  }
  function del() {
    if (!confirmDel) {
      setConfirmDel(true);
      return;
    }
    if (editingId) removeItem('notes', editingId);
    setEditingId(null);
  }

  // Card helpers: the first line is the title, the next non empty line is
  // the preview underneath it.
  function noteTitle(note) {
    const first = String(note.text || '').split('\n')[0].trim();
    return first || 'Untitled note';
  }
  function notePreview(note) {
    const rest = String(note.text || '').split('\n').slice(1);
    for (const line of rest) {
      if (line.trim()) return line.trim();
    }
    return '';
  }

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <View style={styles.headerBar}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
          <Ionicons name="chevron-back" size={24} color={colors.text} />
        </Pressable>
        <Text style={styles.headerTitle}>Money notes</Text>
        <Pressable onPress={openAdd} hitSlop={10}>
          <Text style={styles.add}>+ Add</Text>
        </Pressable>
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        {list.length === 0 ? (
          <EmptyState
            icon="🧮"
            title="No notes yet"
            subtitle="Tap + Add to write one. Math like 120 + 65 solves itself as you type."
          />
        ) : (
          list.map((note) => {
            const noteCalc = computeCalc(note.text);
            const preview = notePreview(note);
            return (
              <Pressable key={note.id} onPress={() => openEdit(note)} style={styles.card}>
                <View style={styles.cardMain}>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.noteTitle} numberOfLines={1}>
                      {noteTitle(note)}
                    </Text>
                    {preview ? (
                      <Text style={styles.sub} numberOfLines={1}>
                        {preview}
                      </Text>
                    ) : null}
                  </View>
                  {noteCalc.hasMath ? (
                    <Text style={styles.cardTotal}>{formatMoney(noteCalc.total)}</Text>
                  ) : null}
                </View>
              </Pressable>
            );
          })
        )}
      </ScrollView>

      <Modal
        visible={!!editing}
        transparent
        animationType="slide"
        onRequestClose={() => setEditingId(null)}
      >
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            <ScrollView keyboardShouldPersistTaps="handled">
              <Text style={styles.sheetTitle}>Note</Text>

              <TextInput
                style={styles.noteInput}
                value={editing ? editing.text : ''}
                onChangeText={onChangeText}
                placeholder={'e.g.\njeep 24 + 24\nlunch 120\ngrab home 185'}
                placeholderTextColor={colors.faint}
                multiline
                numberOfLines={10}
                textAlignVertical="top"
                autoFocus
              />

              {calc.hasMath ? (
                <View style={styles.calcPanel}>
                  <Text style={styles.calcKicker}>CALCULATIONS</Text>
                  {calc.rows.map((row, idx) => (
                    <View key={idx} style={styles.calcRow}>
                      <Text style={styles.calcLabel} numberOfLines={1}>
                        {row.label}
                      </Text>
                      <Text style={styles.calcValue}>{formatMoney(row.value)}</Text>
                    </View>
                  ))}
                  <View style={[styles.calcRow, styles.calcTotalRow]}>
                    <Text style={styles.calcTotalLabel}>Total</Text>
                    <Text style={styles.calcTotalValue}>{formatMoney(calc.total)}</Text>
                  </View>
                </View>
              ) : null}

              <View style={styles.sheetButtons}>
                <Pressable onPress={del} style={[styles.sheetBtn, styles.deleteBtn]}>
                  <Text style={styles.deleteText}>{confirmDel ? 'Tap to confirm' : 'Delete'}</Text>
                </Pressable>
                <Pressable onPress={() => setEditingId(null)} style={[styles.sheetBtn, styles.closeBtn]}>
                  <Text style={styles.closeText}>Close</Text>
                </Pressable>
              </View>
            </ScrollView>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    headerBar: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: spacing.lg, paddingTop: spacing.md, paddingBottom: spacing.sm },
    back: { marginLeft: -4 },
    headerTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    add: { color: colors.primary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },

    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginBottom: spacing.md },
    cardMain: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
    noteTitle: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    sub: { color: colors.muted, fontSize: fontSize.caption, marginTop: 2 },
    cardTotal: { color: colors.primary, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },

    overlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)', justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl, maxHeight: '90%' },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    noteInput: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body, minHeight: 220, marginTop: spacing.md, textAlignVertical: 'top' },

    calcPanel: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, padding: spacing.lg, marginTop: spacing.md },
    calcKicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 2, marginBottom: spacing.sm },
    calcRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: spacing.md, paddingVertical: spacing.xs },
    calcLabel: { color: colors.muted, fontSize: fontSize.small, flex: 1 },
    calcValue: { color: colors.textSecondary, fontSize: fontSize.small, fontWeight: fontWeight.medium },
    calcTotalRow: { borderTopWidth: 1, borderTopColor: colors.border, marginTop: spacing.sm, paddingTop: spacing.sm },
    calcTotalLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    calcTotalValue: { color: colors.primary, fontSize: fontSize.body, fontWeight: fontWeight.bold },

    sheetButtons: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: spacing.xl },
    sheetBtn: { paddingVertical: spacing.md, paddingHorizontal: spacing.lg, borderRadius: radius.md },
    deleteBtn: { backgroundColor: 'transparent' },
    deleteText: { color: colors.warning, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    closeBtn: { backgroundColor: colors.primary },
    closeText: { color: '#FFFFFF', fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
