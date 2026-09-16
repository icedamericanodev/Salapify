import {
  ReminderSettings,
  AppNotification,
  ReminderType,
  Transaction,
  Debt,
  BillItem,
  InstallmentPlan,
  Account,
  UpcomingItem,
} from '../types';

export const DEFAULT_REMINDER_SETTINGS: ReminderSettings = {
  dailyExpenseReminderEnabled: true,
  dailyExpenseReminderTime: '20:00', // 8:00 PM local time default
  paymentDueReminderEnabled: true,
  paymentDueDaysBefore: 2, // 2 days before payment deadline
  billReminderEnabled: true,
  billDaysBefore: 2, // 2 days before bill due date
  subscriptionReminderEnabled: true,
  subscriptionDaysBefore: 1, // 1 day before auto-renewal
  webNotificationsEnabled: true,
  inAppToastsEnabled: true,
  soundEnabled: true,
};

/**
 * Synthesizes a clean, pleasant two-tone chime via Web Audio API without external audio files.
 */
export function playNotificationChime() {
  try {
    const AudioContextClass =
      window.AudioContext ||
      (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    if (!AudioContextClass) return;

    const ctx = new AudioContextClass();
    const now = ctx.currentTime;

    // Tone 1: C5 (523.25 Hz)
    const osc1 = ctx.createOscillator();
    const gain1 = ctx.createGain();
    osc1.type = 'sine';
    osc1.frequency.setValueAtTime(523.25, now);
    gain1.gain.setValueAtTime(0.09, now);
    gain1.gain.exponentialRampToValueAtTime(0.001, now + 0.28);
    osc1.connect(gain1);
    gain1.connect(ctx.destination);
    osc1.start(now);
    osc1.stop(now + 0.28);

    // Tone 2: E5 (659.25 Hz)
    const osc2 = ctx.createOscillator();
    const gain2 = ctx.createGain();
    osc2.type = 'sine';
    osc2.frequency.setValueAtTime(659.25, now + 0.1);
    gain2.gain.setValueAtTime(0.09, now + 0.1);
    gain2.gain.exponentialRampToValueAtTime(0.001, now + 0.42);
    osc2.connect(gain2);
    gain2.connect(ctx.destination);
    osc2.start(now + 0.1);
    osc2.stop(now + 0.42);
  } catch {
    // Silently ignore if audio context is blocked by browser autoplay policy
  }
}

/**
 * Format 24-hour time "HH:MM" into human-readable 12-hour format "8:00 PM"
 */
export function formatTimeDisplay(timeStr: string): string {
  if (!timeStr || !timeStr.includes(':')) return '8:00 PM';
  const parts = timeStr.split(':');
  const h = parseInt(parts[0], 10);
  const m = parseInt(parts[1], 10);
  if (isNaN(h) || isNaN(m)) return '8:00 PM';

  const period = h >= 12 ? 'PM' : 'AM';
  const displayHours = h % 12 === 0 ? 12 : h % 12;
  const displayMinutes = m < 10 ? `0${m}` : `${m}`;
  return `${displayHours}:${displayMinutes} ${period}`;
}

/**
 * Sends a native browser notification if granted and supported.
 */
export function sendNativeWebNotification(notification: AppNotification) {
  if (typeof window === 'undefined' || !('Notification' in window)) return;
  if (Notification.permission !== 'granted') return;

  try {
    const nativeNotice = new Notification(notification.title, {
      body: notification.body,
      tag: `salapify-${notification.id}`,
      silent: false,
    });

    nativeNotice.onclick = () => {
      window.focus();
      nativeNotice.close();
    };
  } catch {
    // In iframe or sandboxed context Notification constructor might be disallowed
  }
}

export interface ReminderAuditContext {
  settings: ReminderSettings;
  transactions: Transaction[];
  debts: Debt[];
  bills: BillItem[];
  installments: InstallmentPlan[];
  accounts: Account[];
  upcoming: UpcomingItem[];
  lastCheckedDate?: string;
  sentNotificationTags: string[]; // List of IDs/tags already fired
}

/**
 * Parse various date formats ("2026-09-18", "15th", "Sep 18", "Today", "Tomorrow") to a Date or difference in days.
 */
function getDaysUntilDate(dueDateStr?: string): number | null {
  if (!dueDateStr) return null;

  const lower = dueDateStr.toLowerCase().trim();
  if (lower === 'today') return 0;
  if (lower === 'tomorrow') return 1;

  const now = new Date();
  const currentYear = now.getFullYear();
  const currentMonth = now.getMonth();
  const currentDay = now.getDate();

  // If format is day number like "15th" or "30"
  const dayMatch = dueDateStr.match(/^(\d{1,2})(?:st|nd|rd|th)?$/i);
  if (dayMatch) {
    const targetDay = parseInt(dayMatch[1], 10);
    let targetDate = new Date(currentYear, currentMonth, targetDay);
    if (targetDate < new Date(currentYear, currentMonth, currentDay)) {
      // If already passed this month, consider next month
      targetDate = new Date(currentYear, currentMonth + 1, targetDay);
    }
    const diffMs = targetDate.getTime() - new Date(currentYear, currentMonth, currentDay).getTime();
    return Math.round(diffMs / (1000 * 60 * 60 * 24));
  }

  // If format is standard YYYY-MM-DD
  const isoMatch = dueDateStr.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (isoMatch) {
    const targetDate = new Date(dueDateStr);
    const todayZero = new Date(currentYear, currentMonth, currentDay);
    const targetZero = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate());
    const diffMs = targetZero.getTime() - todayZero.getTime();
    return Math.round(diffMs / (1000 * 60 * 60 * 24));
  }

  // If format is like "Sep 18"
  try {
    const parsed = new Date(`${dueDateStr} ${currentYear}`);
    if (!isNaN(parsed.getTime())) {
      const todayZero = new Date(currentYear, currentMonth, currentDay);
      const targetZero = new Date(parsed.getFullYear(), parsed.getMonth(), parsed.getDate());
      const diffMs = targetZero.getTime() - todayZero.getTime();
      return Math.round(diffMs / (1000 * 60 * 60 * 24));
    }
  } catch {
    // Ignore unparseable
  }

  return null;
}

/**
 * Runs the evaluation engine to see what new notifications need to be triggered.
 */
export function evaluateReminders(context: ReminderAuditContext): {
  newNotifications: AppNotification[];
  updatedSentTags: string[];
} {
  const {
    settings,
    transactions,
    debts,
    bills,
    installments,
    accounts,
    upcoming,
    sentNotificationTags,
  } = context;

  const newNotifications: AppNotification[] = [];
  const updatedSentTags = [...sentNotificationTags];

  const now = new Date();
  const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
  const currentHours = now.getHours();
  const currentMinutes = now.getMinutes();
  const currentTimeMinutes = currentHours * 60 + currentMinutes;

  // Parse configured reminder time
  const [remH, remM] = (settings.dailyExpenseReminderTime || '20:00').split(':').map((v) => parseInt(v, 10));
  const configuredReminderMinutes = (isNaN(remH) ? 20 : remH) * 60 + (isNaN(remM) ? 0 : remM);

  // ----------------------------------------------------------------
  // 1. RECURRING DAILY EXPENSE REMINDER
  // Fires if user has not made any expense entries by the specific time of day.
  // ----------------------------------------------------------------
  const dailyTag = `daily-expense-${todayStr}`;
  if (
    settings.dailyExpenseReminderEnabled &&
    currentTimeMinutes >= configuredReminderMinutes &&
    !updatedSentTags.includes(dailyTag)
  ) {
    // Check if user has logged any expense transactions today
    const hasExpenseToday = transactions.some((t) => {
      if (t.type !== 'expense') return false;
      const txDateStr = t.date.split('T')[0];
      return txDateStr === todayStr;
    });

    if (!hasExpenseToday) {
      const timeDisplay = formatTimeDisplay(settings.dailyExpenseReminderTime);
      newNotifications.push({
        id: `daily-${Date.now()}`,
        type: 'daily_expense',
        title: "Daily Expense Reminder",
        body: `It is past ${timeDisplay} and you have not logged any expenses for today yet. Keep your sweldo records up to date!`,
        timestamp: Date.now(),
        isRead: false,
        actionType: 'open_log_expense',
      });
      updatedSentTags.push(dailyTag);
    }
  }

  // ----------------------------------------------------------------
  // 2. PAYMENT DUE REMINDER
  // Debts owed, credit cards due dates, installment payments
  // ----------------------------------------------------------------
  if (settings.paymentDueReminderEnabled) {
    // A. Debts owed (I owe someone or an institution)
    const activeDebtsIOwe = debts.filter((d) => d.direction === 'i_owe' && !d.isSettled);
    activeDebtsIOwe.forEach((debt) => {
      if (!debt.dueDate) return;
      const days = getDaysUntilDate(debt.dueDate);
      if (days !== null && days >= 0 && days <= settings.paymentDueDaysBefore) {
        const debtTag = `debt-due-${debt.id}-${debt.dueDate}-${todayStr}`;
        if (!updatedSentTags.includes(debtTag)) {
          const duePhrase = days === 0 ? 'today' : days === 1 ? 'tomorrow' : `in ${days} days (${debt.dueDate})`;
          const remaining = debt.totalAmount - debt.paidAmount;
          newNotifications.push({
            id: `debt-${debt.id}-${Date.now()}`,
            type: 'payment_due',
            title: `Payment Due: ${debt.person}`,
            body: `You have an outstanding payment of ₱${remaining.toLocaleString()} due ${duePhrase}. Avoid late fees and protect your relationships.`,
            timestamp: Date.now(),
            isRead: false,
            actionType: 'open_debts',
            referenceId: debt.id,
            metadata: {
              amount: remaining,
              dueDate: debt.dueDate,
              name: debt.person,
            },
          });
          updatedSentTags.push(debtTag);
        }
      }
    });

    // B. Credit cards with payment due dates
    const creditCards = accounts.filter((a) => a.kind === 'credit' && a.dueDate && a.balance < 0);
    creditCards.forEach((card) => {
      const days = getDaysUntilDate(card.dueDate);
      if (days !== null && days >= 0 && days <= settings.paymentDueDaysBefore) {
        const cardTag = `card-due-${card.id}-${card.dueDate}-${todayStr}`;
        if (!updatedSentTags.includes(cardTag)) {
          const duePhrase = days === 0 ? 'today' : days === 1 ? 'tomorrow' : `in ${days} days (${card.dueDate})`;
          const amountDue = Math.abs(card.balance);
          newNotifications.push({
            id: `card-${card.id}-${Date.now()}`,
            type: 'payment_due',
            title: `Credit Card Due: ${card.name}`,
            body: `Outstanding balance of ₱${amountDue.toLocaleString()} is due ${duePhrase}. Pay before cutoff to avoid finance charges.`,
            timestamp: Date.now(),
            isRead: false,
            actionType: 'open_bills',
            referenceId: card.id,
            metadata: {
              amount: amountDue,
              dueDate: card.dueDate,
              name: card.name,
            },
          });
          updatedSentTags.push(cardTag);
        }
      }
    });

    // C. Installment plans
    const activeInstallments = installments.filter((i) => !i.isSettled);
    activeInstallments.forEach((plan) => {
      const days = getDaysUntilDate(plan.startDate); // Use current cycle calculation
      if (days !== null && days >= 0 && days <= settings.paymentDueDaysBefore) {
        const instTag = `installment-due-${plan.id}-${todayStr}`;
        if (!updatedSentTags.includes(instTag)) {
          newNotifications.push({
            id: `inst-${plan.id}-${Date.now()}`,
            type: 'payment_due',
            title: `Installment Due: ${plan.name}`,
            body: `Scheduled payment of ₱${Math.round(plan.installmentAmount).toLocaleString()} with ${plan.provider} is due soon.`,
            timestamp: Date.now(),
            isRead: false,
            actionType: 'open_installments',
            referenceId: plan.id,
            metadata: {
              amount: plan.installmentAmount,
              name: plan.name,
            },
          });
          updatedSentTags.push(instTag);
        }
      }
    });
  }

  // ----------------------------------------------------------------
  // 3. BILL REMINDER
  // Electricity, Water, Internet, Rent, Condo Dues, Government
  // ----------------------------------------------------------------
  if (settings.billReminderEnabled) {
    // Check upcoming items that are bills
    const upcomingBills = upcoming.filter((u) => u.type === 'bill' && !u.isPaid);
    upcomingBills.forEach((bill) => {
      const days = getDaysUntilDate(bill.dueDate);
      if (days !== null && days >= 0 && days <= settings.billDaysBefore) {
        const billTag = `bill-due-${bill.id}-${bill.dueDate}-${todayStr}`;
        if (!updatedSentTags.includes(billTag)) {
          const duePhrase = days === 0 ? 'today' : days === 1 ? 'tomorrow' : `in ${days} days (${bill.dueDate})`;
          newNotifications.push({
            id: `bill-${bill.id}-${Date.now()}`,
            type: 'bill_due',
            title: `Bill Due: ${bill.name}`,
            body: `₱${bill.amount.toLocaleString()} is due ${duePhrase}. Pay ahead to avoid disconnection or late surcharges.`,
            timestamp: Date.now(),
            isRead: false,
            actionType: 'open_bills',
            referenceId: bill.id,
            metadata: {
              amount: bill.amount,
              dueDate: bill.dueDate,
              name: bill.name,
            },
          });
          updatedSentTags.push(billTag);
        }
      }
    });

    // Also check Phase 4 structured bills collection (non-subscriptions)
    const structuredBills = bills.filter((b) => b.category !== 'subscription' && !b.isPaid);
    structuredBills.forEach((b) => {
      const days = getDaysUntilDate(b.dueDate);
      if (days !== null && days >= 0 && days <= settings.billDaysBefore) {
        const bTag = `struct-bill-${b.id}-${b.dueDate}-${todayStr}`;
        if (!updatedSentTags.includes(bTag)) {
          const duePhrase = days === 0 ? 'today' : days === 1 ? 'tomorrow' : `in ${days} days (${b.dueDate})`;
          newNotifications.push({
            id: `bill-${b.id}-${Date.now()}`,
            type: 'bill_due',
            title: `Bill Due: ${b.name}`,
            body: `₱${b.amount.toLocaleString()} is due ${duePhrase}. Keep your utilities active and on schedule.`,
            timestamp: Date.now(),
            isRead: false,
            actionType: 'open_bills',
            referenceId: b.id,
            metadata: {
              amount: b.amount,
              dueDate: b.dueDate,
              name: b.name,
            },
          });
          updatedSentTags.push(bTag);
        }
      }
    });
  }

  // ----------------------------------------------------------------
  // 4. SUBSCRIPTION REMINDER
  // Netflix, Spotify, YouTube Premium, Apple One, Gym, etc.
  // ----------------------------------------------------------------
  if (settings.subscriptionReminderEnabled) {
    // Check upcoming items that are subscriptions
    const upcomingSubs = upcoming.filter((u) => u.type === 'subscription' && !u.isPaid);
    upcomingSubs.forEach((sub) => {
      const days = getDaysUntilDate(sub.dueDate);
      if (days !== null && days >= 0 && days <= settings.subscriptionDaysBefore) {
        const subTag = `sub-renew-${sub.id}-${sub.dueDate}-${todayStr}`;
        if (!updatedSentTags.includes(subTag)) {
          const duePhrase = days === 0 ? 'today' : days === 1 ? 'tomorrow' : `in ${days} days (${sub.dueDate})`;
          newNotifications.push({
            id: `sub-${sub.id}-${Date.now()}`,
            type: 'subscription',
            title: `Subscription Renewal: ${sub.name}`,
            body: `₱${sub.amount.toLocaleString()} will auto-renew ${duePhrase}. Ensure your payment card is funded or cancel if not using.`,
            timestamp: Date.now(),
            isRead: false,
            actionType: 'open_bills',
            referenceId: sub.id,
            metadata: {
              amount: sub.amount,
              dueDate: sub.dueDate,
              name: sub.name,
            },
          });
          updatedSentTags.push(subTag);
        }
      }
    });

    // Also check Phase 4 structured bills marked as subscriptions
    const structuredSubs = bills.filter((b) => b.category === 'subscription' && !b.isPaid);
    structuredSubs.forEach((sub) => {
      const targetDateStr = sub.renewalDate || sub.dueDate;
      const days = getDaysUntilDate(targetDateStr);
      if (days !== null && days >= 0 && days <= settings.subscriptionDaysBefore) {
        const subTag = `struct-sub-${sub.id}-${targetDateStr}-${todayStr}`;
        if (!updatedSentTags.includes(subTag)) {
          const duePhrase = days === 0 ? 'today' : days === 1 ? 'tomorrow' : `in ${days} days (${targetDateStr})`;
          newNotifications.push({
            id: `sub-${sub.id}-${Date.now()}`,
            type: 'subscription',
            title: `Subscription Renewal: ${sub.name}`,
            body: `₱${sub.amount.toLocaleString()} is scheduled to renew ${duePhrase}. Review your active digital subscriptions.`,
            timestamp: Date.now(),
            isRead: false,
            actionType: 'open_bills',
            referenceId: sub.id,
            metadata: {
              amount: sub.amount,
              dueDate: targetDateStr,
              name: sub.name,
            },
          });
          updatedSentTags.push(subTag);
        }
      }
    });
  }

  return {
    newNotifications,
    updatedSentTags,
  };
}
