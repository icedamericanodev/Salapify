// Local notifications: reminders that fire on the phone itself, no server
// needed. Three kinds, each with its own switch in Settings:
//  - payday: morning of the 15th and the last day of each month
//  - collect: day before, day of, and after the due date of unpaid utang
//  - daily: an evening nudge to log spending, skipped if you already logged
// Everything is a no-op on web, where notifications are not available.

import { Platform } from 'react-native';
import * as Notifications from 'expo-notifications';
import { formatMoney, todayISO, upcomingPaydays } from './format';
import { bankDueDate } from './soa';

const isNative = Platform.OS !== 'web';

// How notifications behave if one fires while the app is open on screen.
if (isNative) {
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowBanner: true,
      shouldShowList: true,
      shouldPlaySound: false,
      shouldSetBadge: false,
    }),
  });
}

// Ask the phone for permission to show notifications. Returns true if allowed.
export async function ensureNotifPermission() {
  if (!isNative) return false;
  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync('reminders', {
      name: 'Reminders',
      importance: Notifications.AndroidImportance.DEFAULT,
    });
  }
  const current = await Notifications.getPermissionsAsync();
  if (current.granted) return true;
  const asked = await Notifications.requestPermissionsAsync();
  return asked.granted;
}

// Turns "2026-07-15" into a Date at the given hour, or null if unreadable.
function atHour(dateStr, hour) {
  const parts = String(dateStr).split('-').map(Number);
  if (parts.length !== 3 || parts.some(isNaN)) return null;
  const d = new Date(parts[0], parts[1] - 1, parts[2], hour, 0, 0);
  // A made up date like 2026-02-31 quietly rolls over to March 3, which
  // would fire a reminder on a day the user never picked. Reject it.
  if (d.getFullYear() !== parts[0] || d.getMonth() !== parts[1] - 1 || d.getDate() !== parts[2]) {
    return null;
  }
  return d;
}

// The daily nudge rotates through a small pool so it never goes stale.
// Same idea every night, different words. The habit is logging, not
// being perfect, so none of these judge.
const DAILY_LINES = [
  'Take 30 seconds to log what you spent today.',
  'Quick check in. What did money do today?',
  'Log today before you forget. Future you says thanks.',
  'Even a zero spend day counts. Log it and keep the chain.',
  'One tap per expense. That is the whole habit.',
];

// Wipe every scheduled reminder and set them up again from current data.
// Called whenever the toggles, transactions, or receivables change, so the
// schedule always matches what is in the app. Rapid data changes can start
// overlapping runs; the token below makes every run but the newest give up,
// so reminders can never be scheduled twice.
let runToken = 0;
export async function rescheduleAll(data) {
  if (!isNative) return;
  const myRun = ++runToken;
  const stale = () => myRun !== runToken;
  const notifs = (data.settings && data.settings.notifications) || {};
  const anyOn = notifs.payday || notifs.collect || notifs.daily || notifs.bills;

  await Notifications.cancelAllScheduledNotificationsAsync();
  if (stale() || !anyOn) return;

  const perm = await Notifications.getPermissionsAsync();
  if (stale() || !perm.granted) return;

  const channel = Platform.OS === 'android' ? { channelId: 'reminders' } : {};
  const now = new Date();

  const schedule = (title, body, when) => {
    if (stale()) return Promise.resolve();
    return Notifications.scheduleNotificationAsync({
      content: { title, body },
      trigger: { type: Notifications.SchedulableTriggerInputTypes.DATE, date: when, ...channel },
    });
  };

  if (notifs.daily) {
    // One-shot nudges for the next 14 evenings instead of a blind repeat,
    // so tonight's nudge is skipped when you already logged today. The
    // window refills every time the app opens or data changes.
    const loggedToday = (data.transactions || []).some((t) => t.date === todayISO());
    for (let i = 0; i < 14; i++) {
      const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + i, 20, 0, 0);
      if (d <= now) continue;
      if (i === 0 && loggedToday) continue;
      await schedule('Quick money check', DAILY_LINES[d.getDate() % DAILY_LINES.length], d);
    }
  }

  if (notifs.payday) {
    // The next several paydays on the user's own schedule, scheduled one
    // by one at 9am. One-shots instead of repeats because semimonthly and
    // end of month paydays land on a different date every month; the list
    // refills every time the app opens or data changes.
    if (stale()) return;
    const paydays = upcomingPaydays(now, data.settings && data.settings.paydaySchedule, 6);
    for (const p of paydays) {
      const at = new Date(p.getFullYear(), p.getMonth(), p.getDate(), 9, 0, 0);
      if (at > now) {
        await schedule(
          'Sweldo day!',
          'Log your income and move your savings before you spend anything.',
          at
        );
      }
    }
  }

  if (notifs.bills) {
    // Credit cards and loans with a due schedule: a heads up 3 evenings
    // before, and a reminder the morning it is due. The due date is the
    // bank adjusted one, weekends and holidays push it forward. Paying at
    // least the minimum on time is the single cheapest habit in finance.
    for (const d of data.debts || []) {
      if (!d || !(d.remaining > 0)) continue;
      const bankDue = bankDueDate(d, now);
      if (!bankDue) continue;
      const due = bankDue.date;
      // No minimum saved means we do NOT know it. Claiming the full balance
      // is "the minimum to avoid late fees" would overstate what is owed on
      // a lock screen, so the copy points at the SOA instead.
      const hasMin = (Number(d.minPayment) || 0) > 0;
      const minAmt = Math.min(Number(d.minPayment) || 0, Number(d.remaining) || 0);
      const minTxt = formatMoney(minAmt);
      const before = new Date(due.getFullYear(), due.getMonth(), due.getDate() - 3, 18, 0, 0);
      const morning = new Date(due.getFullYear(), due.getMonth(), due.getDate(), 9, 0, 0);
      if (before > now) {
        await schedule(
          `${d.name} is due in 3 days`,
          `${hasMin
            ? `Pay in full to avoid interest, or at least ${minTxt} to avoid late fees.`
            : 'Pay in full to avoid interest, or at least the minimum on your SOA to avoid late fees.'
          } GCash and over the counter payments can take 1 to 3 days to post, so pay early.`,
          before
        );
      }
      if (morning > now) {
        await schedule(
          `${d.name} is due today`,
          hasMin
            ? `Pay at least ${minTxt} today to avoid penalties.`
            : 'Pay at least the minimum on your SOA today to avoid penalties.',
          morning
        );
      }
    }
  }

  if (notifs.collect) {
    for (const r of data.receivables || []) {
      if (r.paid || !r.dueDate) continue;
      // Remind for what is STILL owed. After partial payments the original
      // amount would be a false claim pushed to a lock screen.
      const paidSoFar = (r.payments || []).reduce((s, p) => s + (Number(p.amount) || 0), 0);
      const remaining = Math.max(0, (Number(r.amount) || 0) - paidSoFar);
      if (remaining <= 0) continue;
      const due = atHour(r.dueDate, 9);
      if (!due) continue;
      const amount = formatMoney(remaining);

      const dayBefore = new Date(due.getFullYear(), due.getMonth(), due.getDate() - 1, 9, 0, 0);
      if (dayBefore > now) {
        await schedule('Utang due tomorrow', `${r.person}'s ${amount} is due tomorrow.`, dayBefore);
      }
      if (due > now) {
        await schedule(
          'Time to collect',
          `${r.person} owes you ${amount} and it is due today. Send a reminder from the app.`,
          due
        );
      } else {
        // Already overdue: one follow up tomorrow morning. It renews each
        // time the app opens, and stops the moment you mark it paid.
        const followUp = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 9, 0, 0);
        await schedule(
          'Still waiting',
          `${r.person}'s ${amount} was due ${r.dueDate}. A friendly follow up usually works.`,
          followUp
        );
      }
    }
  }
}
