// Settings screen (reached from the More tab). Working now: Appearance,
// the Data tools (backup/restore/CSV/v1 import), and Preferences (currency,
// monthly budget, and quick add buttons). Categories and Logging are still
// marked "Soon". Everything is web-preview compatible (no native libraries).

import { useMemo, useState } from 'react';
import {
  Alert,
  Linking,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  Share,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { spacing, radius, fontSize, fontWeight, palettes } from '../../theme';
import { useTheme } from '../../context/Theme';
import { useAppData } from '../../context/AppData';
import { formatMoney, normalizeSchedule, scheduleLabel } from '../../lib/format';
import { buildBackup, parseBackup, toCSV, parseV1 } from '../../lib/backup';
import { SIZE_NUDGE, SIZE_WARN } from '../../lib/storage';
import Mascot from '../../components/Mascot';
import { ensureNotifPermission } from '../../lib/notifications';
import * as LocalAuthentication from 'expo-local-authentication';
import { saveTextFile, saveToDevice, pickTextFile } from '../../lib/files';
import * as Updates from 'expo-updates';
import { todayISO } from '../../lib/format';

const NOTIF_OPTIONS = [
  { key: 'payday', label: 'Payday reminders', hint: 'Follows your payday schedule in Preferences' },
  { key: 'bills', label: 'Bill due reminders', hint: 'Cards and loans, 3 days before and on the day' },
  { key: 'collect', label: 'Collect money reminders', hint: 'When someone owes you and it is due' },
  { key: 'daily', label: 'Daily log reminder', hint: 'A quick 8pm nudge' },
];

const APPEARANCE = [
  { key: 'light', label: 'Light' },
  { key: 'dark', label: 'Dark' },
  { key: 'system', label: 'System' },
];

// The color themes. Barako is the Salapify brand; Forest and Mint are
// alternates kept for anyone who prefers green.
const PALETTE_OPTIONS = [
  { key: 'barako', label: 'Barako', hint: 'Roasted orange on dark-roast coffee. The Salapify look.' },
  { key: 'ultraviolet', label: 'Ultraviolet', hint: 'Midnight violet with an electric-lime glow.' },
  { key: 'tidal', label: 'Tidal', hint: 'Deep navy with a vivid aqua pop.' },
  { key: 'voltage', label: 'Voltage', hint: 'Ink black with an electric-blue current.' },
  { key: 'ember', label: 'Ember', hint: 'Warm charcoal with a sunrise coral.' },
  { key: 'orchidgold', label: 'Orchid Gold', hint: 'Berry plum with gold trophies.' },
  { key: 'forest', label: 'Forest', hint: 'Warm orange on deep green.' },
  { key: 'mint', label: 'Mint', hint: 'A glowing green.' },
];

const DATA_ACTIONS = [
  { mode: 'backup', label: 'Back up to a file' },
  { mode: 'restore', label: 'Restore from a file' },
  { mode: 'csv', label: 'Export to CSV' },
  { mode: 'importv1', label: 'Import v1 backup' },
];

// A short list of common currencies. "relabel" only changes the symbol shown.
const CURRENCIES = [
  { code: 'PHP', symbol: '₱' },
  { code: 'USD', symbol: '$' },
  { code: 'EUR', symbol: '€' },
  { code: 'GBP', symbol: '£' },
  { code: 'JPY', symbol: '¥' },
  { code: 'CNY', symbol: '¥' },
  { code: 'KRW', symbol: '₩' },
  { code: 'INR', symbol: '₹' },
  { code: 'IDR', symbol: 'Rp' },
  { code: 'MYR', symbol: 'RM' },
  { code: 'SGD', symbol: 'S$' },
  { code: 'THB', symbol: '฿' },
  { code: 'VND', symbol: '₫' },
  { code: 'HKD', symbol: 'HK$' },
  { code: 'AUD', symbol: 'A$' },
  { code: 'CAD', symbol: 'C$' },
  { code: 'AED', symbol: 'AED' },
  { code: 'SAR', symbol: 'SAR' },
  { code: 'CHF', symbol: 'CHF' },
  { code: 'NZD', symbol: 'NZ$' },
];

function downloadFile(filename, text) {
  if (Platform.OS !== 'web') return;
  const blob = new Blob([text], { type: 'text/plain' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export default function More() {
  const { colors, mode, setMode, palette, setPalette } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);
  const { data, replaceAll, updateSettings, storageSize } = useAppData();
  const router = useRouter();

  const [tool, setTool] = useState(null); // data tools modal
  const [msg, setMsg] = useState('');
  const [pref, setPref] = useState(null); // preferences modal: {mode, text}
  const [qaLabel, setQaLabel] = useState('');
  const [qaAmount, setQaAmount] = useState('');

  const settings = data.settings;

  // ---- Data tools ----
  // On the phone these are real files: backup and CSV ask whether to save
  // into a folder on the device (like Downloads) or open the share sheet,
  // restore and import open the file picker. The web preview keeps the
  // older text box flow.
  function offerSave(filename, text, mime, note, onDone) {
    Alert.alert('Where should it go?', note ? `${filename}\n\n${note}` : filename, [
      {
        text: 'Save to my device',
        onPress: async () => {
          try {
            const ok = await saveToDevice(filename, text, mime);
            if (ok) {
              Alert.alert('Saved', `${filename} is in the folder you picked.`);
              if (onDone) onDone();
            }
          } catch (e) {
            Alert.alert('Could not save there', e.message || 'Try Share or send instead.');
          }
        },
      },
      {
        text: 'Share or send',
        onPress: async () => {
          const ok = await saveTextFile(filename, text, mime).catch(() => false);
          if (!ok) Alert.alert('Sharing is not available', 'Try Save to my device instead.');
          else if (onDone) onDone();
        },
      },
      { text: 'Cancel', style: 'cancel' },
    ]);
  }
  async function openTool(m) {
    setMsg('');
    if (Platform.OS !== 'web') {
      try {
        if (m === 'backup') {
          offerSave(
            `salapify-backup-${todayISO()}.json`,
            buildBackup(data),
            'application/json',
            'Receipt photos stay on this phone. The backup covers your money data, not the photos.',
            // Remember when the last backup happened, so the reminder in
            // the DATA section can tell the truth.
            () => updateSettings({ lastBackupAt: todayISO() })
          );
          return;
        }
        if (m === 'csv') {
          offerSave(`salapify-${todayISO()}.csv`, toCSV(data), 'text/csv');
          return;
        }
        const text = await pickTextFile();
        if (text == null) return;
        const parsed = m === 'importv1' ? parseV1(text) : parseBackup(text);
        Alert.alert(
          'Replace your data?',
          'Everything currently in the app will be replaced by this file.',
          [
            { text: 'Cancel', style: 'cancel' },
            { text: 'Replace', style: 'destructive', onPress: () => replaceAll(parsed) },
          ]
        );
      } catch (e) {
        Alert.alert('Could not read that file', e.message || 'Pick a Salapify backup file and try again.');
      }
      return;
    }
    if (m === 'backup') setTool({ mode: m, text: buildBackup(data) });
    else if (m === 'csv') setTool({ mode: m, text: toCSV(data) });
    else setTool({ mode: m, text: '' });
  }
  // Erase everything and start over, with two explicit confirmations. The
  // wipe keeps the app usable (default quick adds, fresh welcome flow) and
  // clears the remembered net worth peak so no ghost of the old data stays.
  function resetAll() {
    const wipe = () => {
      // snapshot: false, so the erase clears the hidden safety copy too.
      // Cannot be undone must be literally true.
      replaceAll(
        {
          settings: {
            quickAdds: [
              { label: 'Food', amount: 150 },
              { label: 'Transport', amount: 50 },
              { label: 'Coffee', amount: 120 },
              { label: 'Load', amount: 100 },
            ],
          },
        },
        { snapshot: false }
      );
      AsyncStorage.removeItem('salapify_peak_networth').catch(() => {});
    };
    const first = 'This erases every account, debt, transaction, goal, utang, note, and recurring item on this phone. A backup file is the only way back.';
    const second = 'Last check. This cannot be undone.';
    if (Platform.OS === 'web') {
      if (window.confirm(`Start fresh? ${first}`) && window.confirm(second)) wipe();
      return;
    }
    Alert.alert('Start fresh?', first, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Continue',
        style: 'destructive',
        onPress: () =>
          Alert.alert('Really erase everything?', second, [
            { text: 'Cancel', style: 'cancel' },
            { text: 'Erase everything', style: 'destructive', onPress: wipe },
          ]),
      },
    ]);
  }

  function runImport() {
    try {
      const parsed = tool.mode === 'importv1' ? parseV1(tool.text) : parseBackup(tool.text);
      // The native path confirms via Alert; the web path must too, one
      // stray tap should never replace everything without asking.
      if (Platform.OS === 'web' && !window.confirm('Replace everything currently in the app with this file? This cannot be undone.')) {
        return;
      }
      replaceAll(parsed);
      setMsg('Imported. Your data has been replaced.');
    } catch (e) {
      setMsg(e.message || 'Could not read that text.');
    }
  }
  const isReadOnly = tool && (tool.mode === 'backup' || tool.mode === 'csv');
  const titleByMode = { backup: 'Back up', restore: 'Restore from a file', csv: 'Export to CSV', importv1: 'Import v1 backup' };

  // ---- Preferences ----
  function openPref(m) {
    if (m === 'limit') setPref({ mode: m, text: String(settings.monthlyLimit || 0) });
    else if (m === 'payday') {
      const sch = normalizeSchedule(settings.paydaySchedule);
      setPref({
        mode: m,
        payMode: sch.mode,
        d1: String(sch.mode === 'semimonthly' ? sch.days[0] : 15),
        d2: String(sch.mode === 'semimonthly' ? sch.days[1] : 31),
        day: String(sch.mode === 'monthly' ? sch.day : 30),
        weekday: sch.mode === 'weekly' ? sch.weekday : 5,
        err: '',
      });
    }
    else setPref({ mode: m });
    setQaLabel('');
    setQaAmount('');
  }
  function pickCurrency(c) {
    updateSettings({ currency: c.symbol, currencyCode: c.code });
    setPref(null);
  }
  function saveLimit() {
    const n = Number(pref.text);
    if (!Number.isFinite(n) || n < 0) return;
    updateSettings({ monthlyLimit: n });
    setPref(null);
  }
  function savePayday() {
    const dayOk = (t) => {
      const n = Math.trunc(Number(String(t).trim()));
      return Number.isFinite(n) && n >= 1 && n <= 31 ? n : null;
    };
    let schedule;
    if (pref.payMode === 'monthly') {
      const d = dayOk(pref.day);
      if (d === null) {
        setPref((p) => ({ ...p, err: 'Pick a day from 1 to 31. 31 means the last day of the month.' }));
        return;
      }
      schedule = { mode: 'monthly', day: d };
    } else if (pref.payMode === 'weekly') {
      schedule = { mode: 'weekly', weekday: pref.weekday };
    } else {
      const a = dayOk(pref.d1);
      const b = dayOk(pref.d2);
      if (a === null || b === null) {
        setPref((p) => ({ ...p, err: 'Both days should be from 1 to 31. 31 means the last day of the month.' }));
        return;
      }
      schedule = { mode: 'semimonthly', days: [a, b] };
    }
    updateSettings({ paydaySchedule: normalizeSchedule(schedule) });
    setPref(null);
  }
  function addQuickAdd() {
    const amount = Number(qaAmount);
    const label = qaLabel.trim();
    if (!label || !Number.isFinite(amount) || amount <= 0) return;
    // No duplicate labels: the Budget screen uses the label as its key.
    const exists = (settings.quickAdds || []).some(
      (q) => q.label.toLowerCase() === label.toLowerCase()
    );
    if (exists) return;
    updateSettings({ quickAdds: [...(settings.quickAdds || []), { label, amount }] });
    setQaLabel('');
    setQaAmount('');
  }
  function removeQuickAdd(i) {
    updateSettings({ quickAdds: (settings.quickAdds || []).filter((_, idx) => idx !== i) });
  }

  // ---- Notifications ----
  const notifs = settings.notifications || {};
  async function toggleNotif(key, on) {
    if (on) {
      const ok = await ensureNotifPermission();
      if (!ok) {
        Alert.alert(
          'Notifications are off',
          'Salapify is not allowed to send notifications. Allow it in your phone settings, then try again.'
        );
        return;
      }
    }
    // Functional update: two switches flipped while a permission dialog is
    // open must not overwrite each other with stale values.
    updateSettings((s) => ({ notifications: { ...(s.notifications || {}), [key]: on } }));
  }

  // ---- Over the air updates ----
  const [updMsg, setUpdMsg] = useState('');
  async function checkUpdates() {
    if (Platform.OS === 'web') return;
    setUpdMsg('Checking...');
    try {
      const res = await Updates.checkForUpdateAsync();
      if (res.isAvailable) {
        setUpdMsg('Downloading...');
        await Updates.fetchUpdateAsync();
        Alert.alert('Update ready', 'Restart the app now to apply it?', [
          {
            text: 'Later',
            style: 'cancel',
            onPress: () => setUpdMsg('Ready. Applies on next open.'),
          },
          { text: 'Restart now', onPress: () => Updates.reloadAsync() },
        ]);
      } else {
        setUpdMsg('Up to date.');
      }
    } catch (e) {
      setUpdMsg(`Failed: ${e.message || 'unknown error'}`);
    }
  }

  // ---- App lock (biometrics) ----
  async function toggleLock(on) {
    if (on) {
      const hasHardware = await LocalAuthentication.hasHardwareAsync();
      const enrolled = hasHardware && (await LocalAuthentication.isEnrolledAsync());
      if (!enrolled) {
        Alert.alert(
          'No fingerprint or face found',
          'Set up fingerprint or face unlock in your phone settings first, then try again.'
        );
        return;
      }
      // Confirm it works right now, so nobody locks themselves out.
      const res = await LocalAuthentication.authenticateAsync({
        promptMessage: 'Confirm to turn on App lock',
      });
      if (!res.success) return;
    }
    updateSettings({ appLock: on });
  }

  return (
    <SafeAreaView style={styles.screen} edges={['top']}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.pageTitle}>Settings</Text>

        <Pressable onPress={() => router.push('/pan')} style={({ pressed }) => [styles.panRow, pressed && styles.pressed]}>
          <Mascot size={40} />
          <View style={{ flex: 1 }}>
            <Text style={styles.panRowTitle}>Ask Pan</Text>
            <Text style={styles.panRowSub}>Your money buddy. Ask about spending, utang, goals, and bills.</Text>
          </View>
          <Ionicons name="chevron-forward" size={18} color={colors.onPrimary} />
        </Pressable>

        <Text style={styles.sectionTitle}>MY MONEY</Text>
        <View style={styles.card}>
          <Pressable onPress={() => router.push('/goals')} style={({ pressed }) => [styles.row, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Goals</Text>
            <Ionicons name="chevron-forward" size={18} color={colors.faint} />
          </Pressable>
          <Pressable onPress={() => router.push('/mindset')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Money mindset</Text>
            <Ionicons name="chevron-forward" size={18} color={colors.faint} />
          </Pressable>
          <Pressable onPress={() => router.push('/receivables')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>People who owe me</Text>
            <Ionicons name="chevron-forward" size={18} color={colors.faint} />
          </Pressable>
          <Pressable onPress={() => router.push('/reports')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Reports</Text>
            <Ionicons name="chevron-forward" size={18} color={colors.faint} />
          </Pressable>
          <Pressable onPress={() => router.push('/notes')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Notes with calculator</Text>
            <Ionicons name="chevron-forward" size={18} color={colors.faint} />
          </Pressable>
          <Pressable onPress={() => router.push('/recurring')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Recurring bills and income</Text>
            <Ionicons name="chevron-forward" size={18} color={colors.faint} />
          </Pressable>
          <Pressable onPress={() => router.push('/history')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>All transactions</Text>
            <Ionicons name="chevron-forward" size={18} color={colors.faint} />
          </Pressable>
        </View>

        <Text style={styles.sectionTitle}>APPEARANCE</Text>
        <View style={styles.card}>
          {APPEARANCE.map((opt, i) => {
            const selected = mode === opt.key;
            return (
              <Pressable key={opt.key} onPress={() => setMode(opt.key)} style={({ pressed }) => [styles.row, i > 0 && styles.rowDivider, pressed && styles.pressed]}>
                <Text style={styles.rowLabel}>{opt.label}</Text>
                {selected ? <Ionicons name="checkmark" size={20} color={colors.primary} /> : null}
              </Pressable>
            );
          })}
        </View>

        <Text style={styles.sectionTitle}>COLOR THEME</Text>
        <View style={styles.card}>
          {PALETTE_OPTIONS.map((opt, i) => {
            const selected = palette === opt.key;
            // A little three dot preview from the theme's dark variant, so
            // you can browse by look: base, brand accent, and win color.
            const pv = palettes[opt.key] && palettes[opt.key].dark;
            return (
              <Pressable key={opt.key} onPress={() => setPalette(opt.key)} style={({ pressed }) => [styles.row, i > 0 && styles.rowDivider, pressed && styles.pressed]}>
                {pv ? (
                  <View style={styles.swatchRow}>
                    <View style={[styles.swatchDot, { backgroundColor: pv.background, borderColor: pv.border }]} />
                    <View style={[styles.swatchDot, styles.swatchOverlap, { backgroundColor: pv.primary, borderColor: pv.background }]} />
                    <View style={[styles.swatchDot, styles.swatchOverlap, { backgroundColor: pv.celebrate, borderColor: pv.background }]} />
                  </View>
                ) : null}
                <View style={{ flex: 1, paddingRight: spacing.md }}>
                  <Text style={styles.rowLabel}>{opt.label}</Text>
                  <Text style={styles.rowHint}>{opt.hint}</Text>
                </View>
                {selected ? <Ionicons name="checkmark" size={20} color={colors.primary} /> : null}
              </Pressable>
            );
          })}
        </View>

        <Text style={styles.sectionTitle}>NOTIFICATIONS</Text>
        <View style={styles.card}>
          {Platform.OS === 'web' ? (
            <View style={styles.row}>
              <Text style={styles.rowLabel}>Reminders work on the phone app</Text>
            </View>
          ) : (
            NOTIF_OPTIONS.map((opt, i) => (
              <View key={opt.key} style={[styles.row, i > 0 && styles.rowDivider]}>
                <View style={{ flex: 1, paddingRight: spacing.md }}>
                  <Text style={styles.rowLabel}>{opt.label}</Text>
                  <Text style={styles.rowHint}>{opt.hint}</Text>
                </View>
                <Switch
                  value={!!notifs[opt.key]}
                  onValueChange={(on) => toggleNotif(opt.key, on)}
                  trackColor={{ false: colors.border, true: colors.primary }}
                  thumbColor={colors.onPrimary}
                />
              </View>
            ))
          )}
          {Platform.OS === 'android' ? (
            <Pressable
              onPress={() => Linking.openURL('https://dontkillmyapp.com').catch(() => {})}
              style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}
            >
              <View style={{ flex: 1, paddingRight: spacing.md }}>
                <Text style={styles.rowLabel}>Reminders not arriving?</Text>
                <Text style={styles.rowHint}>
                  Some phones (Xiaomi, OPPO, vivo, realme) kill reminders to save battery. Tap for
                  the fix for your phone brand.
                </Text>
              </View>
              <Ionicons name="open-outline" size={18} color={colors.faint} />
            </Pressable>
          ) : null}
        </View>

        <Text style={styles.sectionTitle}>SECURITY</Text>
        <View style={styles.card}>
          {Platform.OS === 'web' ? (
            <View style={styles.row}>
              <Text style={styles.rowLabel}>App lock works on the phone app</Text>
            </View>
          ) : (
            <View style={styles.row}>
              <View style={{ flex: 1, paddingRight: spacing.md }}>
                <Text style={styles.rowLabel}>App lock</Text>
                <Text style={styles.rowHint}>Fingerprint or face unlock every time the app opens. Home screen widgets still show your totals, remove them if that matters to you</Text>
              </View>
              <Switch
                value={!!settings.appLock}
                onValueChange={toggleLock}
                trackColor={{ false: colors.border, true: colors.primary }}
                thumbColor={colors.onPrimary}
              />
            </View>
          )}
        </View>

        <Text style={styles.sectionTitle}>PREFERENCES</Text>
        <View style={styles.card}>
          <Pressable onPress={() => openPref('currency')} style={({ pressed }) => [styles.row, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Currency</Text>
            <Text style={styles.rowValue}>{(settings.currencyCode || '') + ' ' + settings.currency}</Text>
          </Pressable>
          <Pressable onPress={() => openPref('limit')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Monthly budget</Text>
            <Text style={styles.rowValue}>{formatMoney(settings.monthlyLimit)}</Text>
          </Pressable>
          <Pressable onPress={() => openPref('payday')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Payday schedule</Text>
            <Text style={styles.rowValue}>{scheduleLabel(settings.paydaySchedule)}</Text>
          </Pressable>
          <Pressable onPress={() => openPref('quickadds')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Quick add buttons</Text>
            <Text style={styles.rowValue}>{(settings.quickAdds || []).length}</Text>
          </Pressable>
          <Pressable onPress={() => router.push('/categories')} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={styles.rowLabel}>Categories and caps</Text>
            <Ionicons name="chevron-forward" size={18} color={colors.faint} />
          </Pressable>
        </View>

        <Text style={styles.sectionTitle}>DATA</Text>
        <View style={styles.card}>
          {DATA_ACTIONS.map((a, i) => (
            <Pressable key={a.mode} onPress={() => openTool(a.mode)} style={({ pressed }) => [styles.row, i > 0 && styles.rowDivider, pressed && styles.pressed]}>
              <Text style={styles.rowLabel}>{a.label}</Text>
              <Ionicons name="chevron-forward" size={18} color={colors.faint} />
            </Pressable>
          ))}
          <Pressable onPress={resetAll} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
            <Text style={[styles.rowLabel, { color: colors.warning }]}>Start fresh (erase everything)</Text>
            <Ionicons name="trash-outline" size={18} color={colors.warning} />
          </Pressable>
          {(() => {
            // An offline first finance app has exactly one disaster plan:
            // the backup file. Say when the last one happened, plainly.
            const last = settings.lastBackupAt;
            const days = last
              ? Math.max(0, Math.floor((new Date() - new Date(`${last}T00:00:00`)) / 86400000))
              : null;
            const stale = days === null || days > 30;
            return (
              <Text style={[styles.sizeNote, stale && { color: colors.warning }]}>
                {days === null
                  ? 'No backup file yet. Right now this phone holds the only copy of your data.'
                  : `Last backup: ${days === 0 ? 'today' : `${days} day${days === 1 ? '' : 's'} ago`}.${days > 30 ? ' Time for a fresh one.' : ''}`}
              </Text>
            );
          })()}
          {storageSize > SIZE_WARN ? (
            <Text style={[styles.sizeNote, { color: colors.warning }]}>
              Your data is {Math.round(storageSize / 1024)} KB, close to the phone storage limit.
              Back up to a file now.
            </Text>
          ) : storageSize > SIZE_NUDGE ? (
            <Text style={styles.sizeNote}>
              Your history is growing ({Math.round(storageSize / 1024)} KB). Back up to a file
              regularly.
            </Text>
          ) : null}
        </View>

        <Text style={styles.sectionTitle}>FEEDBACK</Text>
        <View style={styles.card}>
          <Pressable
            onPress={() =>
              Linking.openURL(
                'mailto:dimaguila.carlam@gmail.com?subject=Salapify%20feedback'
              ).catch(() => {})
            }
            style={({ pressed }) => [styles.row, pressed && styles.pressed]}
          >
            <View style={{ flex: 1, paddingRight: spacing.md }}>
              <Text style={styles.rowLabel}>Send feedback</Text>
              <Text style={styles.rowHint}>Found a bug or want a feature? Email goes straight to the maker</Text>
            </View>
            <Ionicons name="mail-outline" size={18} color={colors.faint} />
          </Pressable>
          <Pressable
            onPress={() =>
              Share.share({
                message:
                  'I track my budget, utang, and bills with Salapify. Offline, no ads, core features free. https://icedamericanodev.github.io/Salapify/',
              }).catch(() => {})
            }
            style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}
          >
            <View style={{ flex: 1, paddingRight: spacing.md }}>
              <Text style={styles.rowLabel}>Share Salapify</Text>
              <Text style={styles.rowHint}>Send it to a friend who keeps asking where the sweldo went</Text>
            </View>
            <Ionicons name="share-social-outline" size={18} color={colors.faint} />
          </Pressable>
        </View>

        <View style={styles.mascotWrap}>
          <Mascot size={104} />
          <Text style={styles.mascotName}>Pan, your kape powered money buddy. ☕</Text>
        </View>

        <Text style={styles.sectionTitle}>ABOUT</Text>
        <View style={styles.card}>
          <View style={styles.row}>
            <Text style={styles.rowLabel}>Version</Text>
            <Text style={styles.rowValue}>1.3.1</Text>
          </View>
          {/* This stamp changes with every over the air update, so you can
              always tell at a glance whether the latest code has arrived. */}
          <View style={[styles.row, styles.rowDivider]}>
            <Text style={styles.rowLabel}>Update stamp</Text>
            <Text style={styles.rowValue}>v3.17: Pan QA sweep, layout and honesty fixes</Text>
          </View>
          {Platform.OS !== 'web' ? (
            <>
              <Pressable onPress={checkUpdates} style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}>
                <Text style={styles.rowLabel}>Check for updates</Text>
                <Text style={styles.rowValue}>{updMsg || 'Tap to check'}</Text>
              </Pressable>
              <View style={[styles.row, styles.rowDivider]}>
                <Text style={styles.rowLabel}>Update channel</Text>
                <Text style={styles.rowValue}>{Updates.channel || 'none'}</Text>
              </View>
              <View style={[styles.row, styles.rowDivider]}>
                <Text style={styles.rowLabel}>Runtime</Text>
                <Text style={styles.rowValue}>{String(Updates.runtimeVersion || 'none')}</Text>
              </View>
            </>
          ) : null}
          <Pressable
            onPress={() => Linking.openURL('https://icedamericanodev.github.io/Salapify/privacy.html').catch(() => {})}
            style={({ pressed }) => [styles.row, styles.rowDivider, pressed && styles.pressed]}
          >
            <Text style={styles.rowLabel}>Privacy policy</Text>
            <Ionicons name="open-outline" size={18} color={colors.faint} />
          </Pressable>
          <View style={[styles.row, styles.rowDivider]}>
            <Text style={styles.rowLabel}>Salapify</Text>
            <Text style={styles.rowValue}>v2</Text>
          </View>
        </View>
      </ScrollView>

      {/* Data tool modal. */}
      <Modal visible={!!tool} transparent animationType="slide" onRequestClose={() => setTool(null)}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            <Text style={styles.sheetTitle}>{tool ? titleByMode[tool.mode] : ''}</Text>
            <Text style={styles.sheetHint}>
              {isReadOnly
                ? Platform.OS === 'web'
                  ? 'Copy this text, or use Download to save a file.'
                  : 'Copy this text and keep it safe. That is your backup.'
                : tool?.mode === 'importv1'
                ? 'Paste your Peso Smart (v1) backup here, then Import. This replaces current data.'
                : 'Paste a Salapify backup here, then Restore. This replaces current data.'}
            </Text>
            <TextInput
              style={styles.textArea}
              value={tool?.text}
              editable={!isReadOnly}
              onChangeText={(t) => setTool((s) => ({ ...s, text: t }))}
              multiline
              placeholder={isReadOnly ? '' : 'Paste here'}
              placeholderTextColor={colors.faint}
            />
            {msg ? <Text style={styles.msg}>{msg}</Text> : null}
            <View style={styles.sheetButtons}>
              <Pressable onPress={() => setTool(null)} style={[styles.sheetBtn, styles.cancelBtn]}>
                <Text style={styles.cancelText}>Close</Text>
              </Pressable>
              {isReadOnly && Platform.OS === 'web' ? (
                <Pressable onPress={() => downloadFile(tool.mode === 'csv' ? 'salapify.csv' : 'salapify-backup.json', tool.text)} style={[styles.sheetBtn, styles.saveBtn]}>
                  <Text style={styles.saveText}>Download</Text>
                </Pressable>
              ) : null}
              {!isReadOnly ? (
                <Pressable onPress={runImport} style={[styles.sheetBtn, styles.saveBtn]}>
                  <Text style={styles.saveText}>{tool?.mode === 'importv1' ? 'Import' : 'Restore'}</Text>
                </Pressable>
              ) : null}
            </View>
          </View>
        </View>
      </Modal>

      {/* Preferences modal. */}
      <Modal visible={!!pref} transparent animationType="slide" onRequestClose={() => setPref(null)}>
        <View style={styles.overlay}>
          <View style={styles.sheet}>
            {pref?.mode === 'currency' ? (
              <>
                <Text style={styles.sheetTitle}>Currency</Text>
                <ScrollView style={{ maxHeight: 360 }}>
                  {CURRENCIES.map((c, i) => {
                    const on = settings.currency === c.symbol && settings.currencyCode === c.code;
                    return (
                      <Pressable key={c.code} onPress={() => pickCurrency(c)} style={({ pressed }) => [styles.row, i > 0 && styles.rowDivider, pressed && styles.pressed]}>
                        <Text style={styles.rowLabel}>{c.code} {c.symbol}</Text>
                        {on ? <Ionicons name="checkmark" size={20} color={colors.primary} /> : null}
                      </Pressable>
                    );
                  })}
                </ScrollView>
                <View style={styles.sheetButtons}>
                  <Pressable onPress={() => setPref(null)} style={[styles.sheetBtn, styles.cancelBtn]}>
                    <Text style={styles.cancelText}>Close</Text>
                  </Pressable>
                </View>
              </>
            ) : null}

            {pref?.mode === 'limit' ? (
              <>
                <Text style={styles.sheetTitle}>Monthly budget</Text>
                <Text style={styles.fieldLabel}>Spending limit per month</Text>
                <TextInput
                  style={styles.input}
                  value={pref.text}
                  onChangeText={(t) => setPref((p) => ({ ...p, text: t }))}
                  placeholder="0"
                  placeholderTextColor={colors.faint}
                  keyboardType="numeric"
                />
                <View style={styles.sheetButtons}>
                  <Pressable onPress={() => setPref(null)} style={[styles.sheetBtn, styles.cancelBtn]}>
                    <Text style={styles.cancelText}>Cancel</Text>
                  </Pressable>
                  <Pressable onPress={saveLimit} style={[styles.sheetBtn, styles.saveBtn]}>
                    <Text style={styles.saveText}>Save</Text>
                  </Pressable>
                </View>
              </>
            ) : null}

            {pref?.mode === 'payday' ? (
              <>
                <Text style={styles.sheetTitle}>Payday schedule</Text>
                <Text style={styles.fieldLabel}>How often does your sweldo arrive?</Text>
                <View style={styles.chips}>
                  {[
                    { k: 'semimonthly', label: 'Twice a month' },
                    { k: 'monthly', label: 'Once a month' },
                    { k: 'weekly', label: 'Weekly' },
                  ].map((opt) => {
                    const on = pref.payMode === opt.k;
                    return (
                      <Pressable key={opt.k} onPress={() => setPref((p) => ({ ...p, payMode: opt.k, err: '' }))} style={[styles.chip, on && styles.chipOn]}>
                        <Text style={[styles.chipText, on && styles.chipTextOn]}>{opt.label}</Text>
                      </Pressable>
                    );
                  })}
                </View>
                {pref.payMode === 'semimonthly' ? (
                  <>
                    <Text style={styles.fieldLabel}>First payday (day of the month)</Text>
                    <TextInput
                      style={styles.input}
                      value={pref.d1}
                      onChangeText={(t) => setPref((p) => ({ ...p, d1: t, err: '' }))}
                      placeholder="15"
                      placeholderTextColor={colors.faint}
                      keyboardType="numeric"
                    />
                    <Text style={styles.fieldLabel}>Second payday</Text>
                    <TextInput
                      style={styles.input}
                      value={pref.d2}
                      onChangeText={(t) => setPref((p) => ({ ...p, d2: t, err: '' }))}
                      placeholder="31"
                      placeholderTextColor={colors.faint}
                      keyboardType="numeric"
                    />
                    <Text style={styles.sizeNote}>Type 31 for the last day of the month, it adjusts to short months by itself.</Text>
                  </>
                ) : null}
                {pref.payMode === 'monthly' ? (
                  <>
                    <Text style={styles.fieldLabel}>Payday (day of the month)</Text>
                    <TextInput
                      style={styles.input}
                      value={pref.day}
                      onChangeText={(t) => setPref((p) => ({ ...p, day: t, err: '' }))}
                      placeholder="30"
                      placeholderTextColor={colors.faint}
                      keyboardType="numeric"
                    />
                    <Text style={styles.sizeNote}>Type 31 for the last day of the month, it adjusts to short months by itself.</Text>
                  </>
                ) : null}
                {pref.payMode === 'weekly' ? (
                  <>
                    <Text style={styles.fieldLabel}>Which day?</Text>
                    <View style={styles.chips}>
                      {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((name, i) => {
                        const on = pref.weekday === i;
                        return (
                          <Pressable key={name} onPress={() => setPref((p) => ({ ...p, weekday: i, err: '' }))} style={[styles.chip, on && styles.chipOn]}>
                            <Text style={[styles.chipText, on && styles.chipTextOn]}>{name}</Text>
                          </Pressable>
                        );
                      })}
                    </View>
                  </>
                ) : null}
                {pref.err ? <Text style={styles.prefErr}>{pref.err}</Text> : null}
                <View style={styles.sheetButtons}>
                  <Pressable onPress={() => setPref(null)} style={[styles.sheetBtn, styles.cancelBtn]}>
                    <Text style={styles.cancelText}>Cancel</Text>
                  </Pressable>
                  <Pressable onPress={savePayday} style={[styles.sheetBtn, styles.saveBtn]}>
                    <Text style={styles.saveText}>Save</Text>
                  </Pressable>
                </View>
              </>
            ) : null}

            {pref?.mode === 'quickadds' ? (
              <>
                <Text style={styles.sheetTitle}>Quick add buttons</Text>
                <ScrollView style={{ maxHeight: 240 }}>
                  {(settings.quickAdds || []).map((q, i) => (
                    <View key={i} style={[styles.row, i > 0 && styles.rowDivider]}>
                      <Text style={styles.rowLabel}>{q.label}</Text>
                      <View style={styles.qaRight}>
                        <Text style={styles.rowValue}>{formatMoney(q.amount)}</Text>
                        <Pressable onPress={() => removeQuickAdd(i)} hitSlop={8}>
                          <Ionicons name="close" size={16} color={colors.faint} />
                        </Pressable>
                      </View>
                    </View>
                  ))}
                </ScrollView>
                <Text style={styles.fieldLabel}>Add a button</Text>
                <View style={styles.qaAddRow}>
                  <TextInput style={[styles.input, { flex: 1 }]} value={qaLabel} onChangeText={setQaLabel} placeholder="Label" placeholderTextColor={colors.faint} />
                  <TextInput style={[styles.input, { width: 90 }]} value={qaAmount} onChangeText={setQaAmount} placeholder="0" placeholderTextColor={colors.faint} keyboardType="numeric" />
                  <Pressable onPress={addQuickAdd} style={[styles.sheetBtn, styles.saveBtn]}>
                    <Text style={styles.saveText}>Add</Text>
                  </Pressable>
                </View>
                <View style={styles.sheetButtons}>
                  <Pressable onPress={() => setPref(null)} style={[styles.sheetBtn, styles.cancelBtn]}>
                    <Text style={styles.cancelText}>Done</Text>
                  </Pressable>
                </View>
              </>
            ) : null}
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    screen: { flex: 1, backgroundColor: colors.background },
    content: { padding: spacing.lg, paddingBottom: spacing.xxl },
    pageTitle: { color: colors.text, fontSize: fontSize.title, fontWeight: fontWeight.heavy, marginBottom: spacing.lg },
    panRow: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: spacing.md,
      backgroundColor: colors.primary,
      borderRadius: radius.lg,
      padding: spacing.lg,
      marginBottom: spacing.lg,
    },
    panRowTitle: { color: colors.onPrimary, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    panRowSub: { color: colors.onPrimary, fontSize: fontSize.small, opacity: 0.85, marginTop: 2 },
    sectionTitle: { color: colors.muted, fontSize: fontSize.caption, fontWeight: fontWeight.medium, letterSpacing: 1.5, marginBottom: spacing.sm, marginTop: spacing.md, paddingHorizontal: spacing.xs },
    mascotWrap: { alignItems: 'center', marginTop: spacing.xl, marginBottom: spacing.sm },
    mascotName: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.sm, textAlign: 'center' },
    card: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.lg, paddingHorizontal: spacing.lg },
    row: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: spacing.md + 2 },
    rowDivider: { borderTopColor: colors.border, borderTopWidth: StyleSheet.hairlineWidth },
    pressed: { opacity: 0.6 },
    rowLabel: { color: colors.text, fontSize: fontSize.body, fontWeight: fontWeight.medium },
    rowValue: { color: colors.muted, fontSize: fontSize.body },
    rowHint: { color: colors.faint, fontSize: fontSize.small, marginTop: 2 },
    swatchRow: { flexDirection: 'row', alignItems: 'center', marginRight: spacing.md },
    swatchDot: { width: 22, height: 22, borderRadius: 11, borderWidth: 1 },
    swatchOverlap: { marginLeft: -8 },
    sizeNote: { color: colors.muted, fontSize: fontSize.small, paddingVertical: spacing.md },
    soon: { color: colors.softGreen, fontSize: fontSize.caption, fontWeight: fontWeight.medium, borderColor: colors.border, borderWidth: 1, borderRadius: radius.pill, paddingHorizontal: spacing.sm, paddingVertical: 2, overflow: 'hidden' },
    qaRight: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
    qaAddRow: { flexDirection: 'row', gap: spacing.sm, alignItems: 'center', marginBottom: spacing.md },

    overlay: { flex: 1, backgroundColor: colors.overlay, justifyContent: 'flex-end' },
    sheet: { backgroundColor: colors.background, borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, borderColor: colors.border, borderWidth: 1, padding: spacing.xl, maxHeight: '90%' },
    sheetTitle: { color: colors.text, fontSize: fontSize.subtitle, fontWeight: fontWeight.bold },
    sheetHint: { color: colors.muted, fontSize: fontSize.small, marginTop: spacing.xs, marginBottom: spacing.md },
    fieldLabel: { color: colors.muted, fontSize: fontSize.caption, marginBottom: spacing.xs, marginTop: spacing.md },
    input: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, paddingVertical: spacing.md, color: colors.text, fontSize: fontSize.body },
    textArea: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1, borderRadius: radius.md, padding: spacing.md, color: colors.text, fontSize: fontSize.small, minHeight: 140, maxHeight: 280, textAlignVertical: 'top' },
    msg: { color: colors.primary, fontSize: fontSize.small, marginTop: spacing.md },
    sheetButtons: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.sm, marginTop: spacing.lg },
    chips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginTop: spacing.xs },
    chip: { paddingVertical: spacing.sm, paddingHorizontal: spacing.md, borderRadius: radius.pill, borderWidth: 1, borderColor: colors.border, backgroundColor: colors.card },
    chipOn: { backgroundColor: colors.primary, borderColor: colors.primary },
    chipText: { color: colors.textSecondary, fontSize: fontSize.small },
    chipTextOn: { color: colors.onPrimary, fontWeight: fontWeight.bold },
    prefErr: { color: colors.warning, fontSize: fontSize.small, marginTop: spacing.sm },
    sheetBtn: { paddingVertical: spacing.md, paddingHorizontal: spacing.lg, borderRadius: radius.md },
    cancelBtn: { backgroundColor: colors.card, borderColor: colors.border, borderWidth: 1 },
    cancelText: { color: colors.text, fontSize: fontSize.body },
    saveBtn: { backgroundColor: colors.primary },
    saveText: { color: colors.onPrimary, fontSize: fontSize.body, fontWeight: fontWeight.bold },
  });
}
