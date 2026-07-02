// Local notifications: reminders that fire on the phone itself, no server
// needed. Three kinds, each with its own switch in Settings:
//  - payday: morning of the 15th and the last day of each month
//  - collect: on the due date of each unpaid receivable
//  - daily: a gentle 8pm nudge to log today's spending
// Everything is a no-op on web, where notifications are not available.

import { Platform } from 'react-native';
import * as Notifications from 'expo-notifications';

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

// Returns the last day of the month for a given date, like 31 for July.
function lastDayOfMonth(year, monthIndex) {
  return new Date(year, monthIndex + 1, 0).getDate();
}

// Wipe every scheduled reminder and set them up again from current data.
// Called whenever the toggles or the receivables list change, so the
// schedule always matches what is in the app.
export async function rescheduleAll(data) {
  if (!isNative) return;
  const notifs = (data.settings && data.settings.notifications) || {};
  const anyOn = notifs.payday || notifs.collect || notifs.daily;

  await Notifications.cancelAllScheduledNotificationsAsync();
  if (!anyOn) return;

  const perm = await Notifications.getPermissionsAsync();
  if (!perm.granted) return;

  const channel = Platform.OS === 'android' ? { channelId: 'reminders' } : {};

  if (notifs.daily) {
    await Notifications.scheduleNotificationAsync({
      content: {
        title: 'Quick money check',
        body: 'Take 30 seconds to log what you spent today.',
      },
      trigger: { type: Notifications.SchedulableTriggerInputTypes.DAILY, hour: 20, minute: 0, ...channel },
    });
  }

  if (notifs.payday) {
    // The 15th repeats monthly. The last day of the month is a different
    // date every month, so we schedule the next three month ends one by one.
    await Notifications.scheduleNotificationAsync({
      content: {
        title: 'Payday!',
        body: 'Log your income and pay yourself first.',
      },
      trigger: { type: Notifications.SchedulableTriggerInputTypes.MONTHLY, day: 15, hour: 9, minute: 0, ...channel },
    });
    const now = new Date();
    for (let i = 0; i < 3; i++) {
      const y = now.getFullYear();
      const m = now.getMonth() + i;
      const end = new Date(y, m, lastDayOfMonth(y, m), 9, 0, 0);
      if (end > now) {
        await Notifications.scheduleNotificationAsync({
          content: {
            title: 'Payday!',
            body: 'End of the month. Log your income and pay yourself first.',
          },
          trigger: { type: Notifications.SchedulableTriggerInputTypes.DATE, date: end, ...channel },
        });
      }
    }
  }

  if (notifs.collect) {
    const now = new Date();
    for (const r of data.receivables || []) {
      if (r.paid || !r.dueDate) continue;
      // Due dates are stored as text like 2026-07-15.
      const parts = String(r.dueDate).split('-').map(Number);
      if (parts.length !== 3 || parts.some(isNaN)) continue;
      const when = new Date(parts[0], parts[1] - 1, parts[2], 9, 0, 0);
      if (when <= now) continue;
      await Notifications.scheduleNotificationAsync({
        content: {
          title: 'Time to collect',
          body: `${r.person} owes you money and it is due today. Send them a reminder from the app.`,
        },
        trigger: { type: Notifications.SchedulableTriggerInputTypes.DATE, date: when, ...channel },
      });
    }
  }
}
