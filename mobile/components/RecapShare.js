// RecapShare: the monthly recap share card. An Insights card with one button
// that opens a modal: a Skia drawn preview of the recap (dark Barako card
// with Pan on it), a privacy toggle that hides peso amounts, and share
// buttons. The image path uses only what the binary already has (Skia to
// draw and snapshot, expo-file-system and expo-sharing to hand the PNG to
// the share sheet), so this whole feature ships over the air.
//
// Defensive by design: the Skia preview lives behind an error boundary, and
// if drawing or snapshotting ever fails the user still has Share as text,
// which cannot fail. The cached PNG is deleted after the share sheet closes,
// the same hygiene as backups.

import React, { useMemo, useRef, useState } from 'react';
import { Alert, Modal, Platform, Pressable, Share, StyleSheet, Switch, Text, View } from 'react-native';
import {
  Canvas,
  RoundedRect,
  Line,
  Text as SkText,
  useCanvasRef,
  useImage,
  Image as SkImage,
  matchFont,
} from '@shopify/react-native-skia';
import * as FileSystem from 'expo-file-system/legacy';
import * as Sharing from 'expo-sharing';
import { spacing, radius, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';
import { formatMoney } from '../lib/format';
import { monthRecap, recapText } from '../lib/recap';

// Card canvas in logical units; the snapshot comes out at device pixels.
const CW = 330;
const CH = 430;

// Barako, baked into the shared image on purpose: the card is brand
// marketing wherever it lands, whatever theme the sender uses in the app.
const BG = '#1A130E';
const BORDER = '#3A2A20';
const ORANGE = '#FF8A3D';
const CREAM = '#FBF3E9';
const MUTED = '#A99182';

const FAMILY = Platform.select({ android: 'sans-serif', ios: 'Helvetica', default: 'sans-serif' });

// Wrap a sentence into at most `max` lines of roughly `width` characters,
// because plain Skia text does not wrap on its own.
function wrapLines(text, width = 40, max = 2) {
  const words = String(text).split(' ');
  const lines = [''];
  for (const w of words) {
    const cur = lines[lines.length - 1];
    if ((cur + ' ' + w).trim().length <= width) lines[lines.length - 1] = (cur + ' ' + w).trim();
    else if (lines.length < max) lines.push(w);
    else return lines;
  }
  return lines;
}

// The Skia drawn card. Isolated so the error boundary around it can catch a
// Skia problem and leave the rest of the modal working.
function RecapCanvas({ canvasRef, recap, hideAmounts }) {
  const pan = useImage(require('../assets/pan-clay.png'));
  const fonts = useMemo(
    () => ({
      kicker: matchFont({ fontFamily: FAMILY, fontSize: 12, fontWeight: 'bold' }),
      big: matchFont({ fontFamily: FAMILY, fontSize: 30, fontWeight: 'bold' }),
      sub: matchFont({ fontFamily: FAMILY, fontSize: 12 }),
      row: matchFont({ fontFamily: FAMILY, fontSize: 13 }),
      rowBold: matchFont({ fontFamily: FAMILY, fontSize: 13, fontWeight: 'bold' }),
      foot: matchFont({ fontFamily: FAMILY, fontSize: 11, fontWeight: 'bold' }),
    }),
    []
  );

  const money = (n) => (hideAmounts ? '***' : formatMoney(n));
  const pct = recap.keptRate !== null ? Math.round(recap.keptRate * 100) : null;
  const big =
    pct === null
      ? `${recap.daysLogged} ${recap.daysLogged === 1 ? 'day' : 'days'} logged`
      : recap.kept >= 0
      ? hideAmounts
        ? `Kept ${Math.max(0, pct)}%`
        : `${formatMoney(recap.kept)} kept`
      : hideAmounts
      ? 'Over this month'
      : `${formatMoney(-recap.kept)} over`;
  const sub =
    pct === null
      ? 'Every logged day builds the habit.'
      : recap.kept >= 0
      ? hideAmounts
        ? 'of my income this month'
        : `${Math.max(0, pct)}% of income kept`
      : 'spending passed income';

  const rows = [];
  if (pct !== null) {
    rows.push(['Money in', money(recap.moneyIn)]);
    rows.push(['Money out', money(recap.moneyOut)]);
  }
  if (recap.topCats[0]) rows.push(['Top spending', `${recap.topCats[0].label} ${recap.topCats[0].pct}%`]);
  if (recap.utangCollected > 0) rows.push(['Utang collected', money(recap.utangCollected)]);
  if (recap.debtPaid > 0) rows.push(['Debt paid down', money(recap.debtPaid)]);
  rows.push(['Days logged', String(recap.daysLogged)]);

  const verdictLines = wrapLines(recap.verdict, 44, 2);
  const rowsTop = 176;
  const rowH = 25;

  return (
    <Canvas ref={canvasRef} style={{ width: CW, height: CH }}>
      <RoundedRect x={0} y={0} width={CW} height={CH} r={20} color={BG} />
      <RoundedRect x={0.5} y={0.5} width={CW - 1} height={CH - 1} r={20} color={BORDER} style="stroke" strokeWidth={1} />

      {pan ? <SkImage image={pan} x={CW - 96} y={16} width={80} height={80} fit="contain" /> : null}

      <SkText x={22} y={40} text={`MY ${recap.label.toUpperCase()}`} font={fonts.kicker} color={ORANGE} />
      <SkText x={22} y={104} text={big} font={fonts.big} color={CREAM} />
      <SkText x={22} y={128} text={sub} font={fonts.sub} color={MUTED} />

      <Line p1={{ x: 22, y: 150 }} p2={{ x: CW - 22, y: 150 }} color={BORDER} strokeWidth={1} />

      {rows.map(([label, value], i) => (
        <React.Fragment key={label}>
          <SkText x={22} y={rowsTop + i * rowH} text={label} font={fonts.row} color={MUTED} />
          <SkText x={168} y={rowsTop + i * rowH} text={value} font={fonts.rowBold} color={CREAM} />
        </React.Fragment>
      ))}

      {verdictLines.map((l, i) => (
        <SkText key={i} x={22} y={CH - 74 + i * 18} text={l} font={fonts.sub} color={CREAM} />
      ))}

      <SkText x={22} y={CH - 24} text="Salapify, on your money's side" font={fonts.foot} color={ORANGE} />
    </Canvas>
  );
}

class CanvasBoundary extends React.Component {
  state = { failed: false };
  static getDerivedStateFromError() {
    return { failed: true };
  }
  componentDidCatch() {}
  render() {
    if (this.state.failed) return this.props.fallback;
    return this.props.children;
  }
}

export default function RecapShare({ data }) {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const [open, setOpen] = useState(false);
  const [hideAmounts, setHideAmounts] = useState(false);
  const [busy, setBusy] = useState(false);
  const canvasRef = useCanvasRef();
  const canvasOk = useRef(true);

  const recap = useMemo(() => monthRecap(data), [data, open]);

  async function shareText() {
    try {
      await Share.share({ message: recapText(recap, formatMoney, hideAmounts) });
    } catch (e) {
      // The user closing the sheet is not an error worth surfacing.
    }
  }

  async function shareImage() {
    if (busy) return;
    setBusy(true);
    const uri = FileSystem.cacheDirectory + `salapify-recap-${recap.monthKey}.png`;
    try {
      const snapshot = canvasRef.current && canvasRef.current.makeImageSnapshot();
      if (!snapshot) throw new Error('no snapshot');
      const b64 = snapshot.encodeToBase64();
      await FileSystem.writeAsStringAsync(uri, b64, { encoding: FileSystem.EncodingType.Base64 });
      if (await Sharing.isAvailableAsync()) {
        await Sharing.shareAsync(uri, { mimeType: 'image/png', dialogTitle: 'Share your month' });
      } else {
        await shareText();
      }
    } catch (e) {
      Alert.alert('Could not build the image', 'Sharing it as text instead.', [
        { text: 'OK', onPress: shareText },
      ]);
    } finally {
      FileSystem.deleteAsync(uri, { idempotent: true }).catch(() => {});
      setBusy(false);
    }
  }

  return (
    <>
      <View style={styles.card}>
        <Text style={styles.kicker}>SHARE YOUR MONTH</Text>
        <Text style={styles.line}>
          Turn {recap.label} into a card you can post or send. You choose if peso amounts show.
        </Text>
        <Pressable onPress={() => setOpen(true)} style={({ pressed }) => [styles.btn, pressed && styles.pressed]}>
          <Text style={styles.btnText}>Make my recap card</Text>
        </Pressable>
      </View>

      <Modal visible={open} transparent animationType="slide" onRequestClose={() => setOpen(false)}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            <Text style={styles.sheetTitle}>Your {recap.label} recap</Text>

            <View style={styles.preview}>
              <CanvasBoundary
                fallback={
                  <View style={styles.previewFail}>
                    <Text style={styles.line}>
                      The image preview is not available on this device. Share as text below still works.
                    </Text>
                  </View>
                }
              >
                {open ? (
                  <RecapCanvas canvasRef={canvasRef} recap={recap} hideAmounts={hideAmounts} />
                ) : null}
              </CanvasBoundary>
            </View>

            <View style={styles.toggleRow}>
              <View style={{ flex: 1 }}>
                <Text style={styles.toggleLabel}>Hide peso amounts</Text>
                <Text style={styles.toggleHint}>Show percentages only, keep numbers private.</Text>
              </View>
              <Switch
                value={hideAmounts}
                onValueChange={setHideAmounts}
                trackColor={{ false: colors.border, true: colors.primary }}
                thumbColor={colors.onPrimary}
              />
            </View>

            <Pressable onPress={shareImage} disabled={busy} style={({ pressed }) => [styles.btn, (pressed || busy) && styles.pressed]}>
              <Text style={styles.btnText}>{busy ? 'Preparing...' : 'Share the card'}</Text>
            </Pressable>
            <View style={styles.rowBtns}>
              <Pressable onPress={shareText} style={({ pressed }) => [styles.ghostBtn, pressed && styles.pressed]}>
                <Text style={styles.ghostText}>Share as text</Text>
              </Pressable>
              <Pressable onPress={() => setOpen(false)} style={({ pressed }) => [styles.ghostBtn, pressed && styles.pressed]}>
                <Text style={styles.ghostText}>Close</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>
    </>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    card: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.lg,
      padding: spacing.xl,
      marginBottom: spacing.lg,
    },
    kicker: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.2 },
    line: { color: colors.textSecondary, fontSize: fontSize.small, lineHeight: 20, marginTop: spacing.md },
    btn: {
      backgroundColor: colors.primary,
      borderRadius: radius.md,
      minHeight: 48,
      alignItems: 'center',
      justifyContent: 'center',
      marginTop: spacing.lg,
    },
    btnText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
    pressed: { opacity: 0.7 },

    overlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' },
    sheet: {
      backgroundColor: colors.background,
      borderTopLeftRadius: radius.lg,
      borderTopRightRadius: radius.lg,
      borderColor: colors.border,
      borderWidth: 1,
      padding: spacing.xl,
    },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold, marginBottom: spacing.md },
    preview: { alignItems: 'center' },
    previewFail: {
      width: CW,
      height: 120,
      borderRadius: radius.md,
      borderColor: colors.border,
      borderWidth: 1,
      padding: spacing.lg,
      justifyContent: 'center',
    },
    toggleRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, marginTop: spacing.lg },
    toggleLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    toggleHint: { color: colors.faint, fontSize: fontSize.small, marginTop: 2 },
    rowBtns: { flexDirection: 'row', justifyContent: 'space-between', marginTop: spacing.md },
    ghostBtn: { paddingVertical: spacing.md, paddingHorizontal: spacing.lg },
    ghostText: { color: colors.textSecondary, fontSize: fontSize.body, fontWeight: fontWeight.medium },
  });
}
