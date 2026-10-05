import React, { useState } from 'react';
import {
  X,
  Bell,
  CalendarCheck,
  CreditCard,
  Zap,
  RefreshCw,
  Clock,
  CheckCheck,
  Trash2,
  Volume2,
  VolumeX,
  Globe,
  Sliders,
  Play,
  Check,
  AlertCircle,
  ShieldCheck,
  Sparkles,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { ReminderType, AppNotification } from '../types';
import { formatTimeDisplay } from '../utils/notificationEngine';

interface RemindersModalProps {
  isOpen: boolean;
  onClose: () => void;
  onOpenLogExpense?: () => void;
  onOpenBills?: () => void;
  onOpenDebts?: () => void;
  onOpenInstallments?: () => void;
}

export const RemindersModal: React.FC<RemindersModalProps> = ({
  isOpen,
  onClose,
  onOpenLogExpense,
  onOpenBills,
  onOpenDebts,
  onOpenInstallments,
}) => {
  const {
    reminderSettings,
    updateReminderSettings,
    notifications,
    unreadNotificationsCount,
    markNotificationRead,
    markAllNotificationsRead,
    clearNotification,
    clearAllNotifications,
    triggerSimulatedReminder,
    requestWebNotificationPermission,
    webNotificationPermission,
    transactions,
  } = useFinancial();

  const [activeTab, setActiveTab] = useState<'tray' | 'rules' | 'test'>('tray');
  const [filterType, setFilterType] = useState<string>('all');
  const [permissionFeedback, setPermissionFeedback] = useState<string | null>(null);

  if (!isOpen) return null;

  // Check today's expense count for the live status in rules
  const now = new Date();
  const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
  const todayExpensesCount = transactions.filter((t) => {
    return t.type === 'expense' && t.date.split('T')[0] === todayStr;
  }).length;

  const filteredNotifications = notifications.filter((n) => {
    if (filterType === 'all') return true;
    return n.type === filterType;
  });

  const handleRequestPermission = async () => {
    const perm = await requestWebNotificationPermission();
    if (perm === 'granted') {
      setPermissionFeedback('Browser notifications enabled successfully!');
    } else if (perm === 'denied') {
      setPermissionFeedback('Permission denied in browser settings.');
    } else {
      setPermissionFeedback('Permission dismissed.');
    }
    setTimeout(() => setPermissionFeedback(null), 3500);
  };

  const handleActionClick = (notification: AppNotification) => {
    markNotificationRead(notification.id);
    onClose();

    if (notification.actionType === 'open_log_expense' && onOpenLogExpense) {
      onOpenLogExpense();
    } else if (notification.actionType === 'open_debts' && onOpenDebts) {
      onOpenDebts();
    } else if (notification.actionType === 'open_installments' && onOpenInstallments) {
      onOpenInstallments();
    } else if (notification.actionType === 'open_bills' && onOpenBills) {
      onOpenBills();
    }
  };

  const formatTimestamp = (ts: number) => {
    const diffMin = Math.round((Date.now() - ts) / (1000 * 60));
    if (diffMin < 1) return 'Just now';
    if (diffMin < 60) return `${diffMin}m ago`;
    const diffHours = Math.round(diffMin / 60);
    if (diffHours < 24) return `${diffHours}h ago`;
    return new Date(ts).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' });
  };

  const getTypeMeta = (type: ReminderType) => {
    switch (type) {
      case 'daily_expense':
        return {
          icon: <CalendarCheck size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />,
          label: 'Daily Log',
          color: 'bg-[#B03C09]/10 text-[#B03C09] dark:bg-[#FF9A52]/15 dark:text-[#FF9A52] border-[#B03C09]/20 dark:border-[#FF9A52]/30',
        };
      case 'payment_due':
        return {
          icon: <CreditCard size={16} className="text-rose-600 dark:text-rose-400" />,
          label: 'Payment Due',
          color: 'bg-rose-500/10 text-rose-700 dark:text-rose-300 border-rose-500/20',
        };
      case 'bill_due':
        return {
          icon: <Zap size={16} className="text-amber-600 dark:text-amber-400" />,
          label: 'Bill Due',
          color: 'bg-amber-500/10 text-amber-700 dark:text-amber-300 border-amber-500/20',
        };
      case 'subscription':
        return {
          icon: <RefreshCw size={16} className="text-blue-600 dark:text-blue-400" />,
          label: 'Subscription',
          color: 'bg-blue-500/10 text-blue-700 dark:text-blue-300 border-blue-500/20',
        };
    }
  };

  return (
    <div
      id="reminders-modal-overlay"
      className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-black/60 backdrop-blur-xs animate-in fade-in duration-200"
    >
      <div
        id="reminders-modal-container"
        className="bg-[#FFEEDF] dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] w-full max-w-lg rounded-3xl shadow-2xl flex flex-col max-h-[90vh] overflow-hidden text-[#15120F] dark:text-[#F6EFE8]"
      >
        {/* Header */}
        <div className="p-4 sm:p-5 border-b border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between gap-3 bg-white/50 dark:bg-[#201A15]/50">
          <div className="flex items-center gap-2.5">
            <div className="p-2 rounded-xl bg-[#B03C09]/10 dark:bg-[#FF9A52]/15 text-[#B03C09] dark:text-[#FF9A52]">
              <Bell size={20} />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-base sm:text-lg font-black text-[#15120F] dark:text-[#F6EFE8]">
                  Reminders & Notifications
                </h2>
                {unreadNotificationsCount > 0 && (
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-[#B03C09] text-white">
                    {unreadNotificationsCount} unread
                  </span>
                )}
              </div>
              <p className="text-xs text-[#7A6E63] dark:text-[#A89A8D]">
                Offline-first recurring daily, bill, and payment alerts
              </p>
            </div>
          </div>

          <button
            type="button"
            id="btn-close-reminders-modal"
            onClick={onClose}
            className="p-2 rounded-full hover:bg-black/5 dark:hover:bg-white/5 text-[#7A6E63] hover:text-[#15120F] dark:text-[#A89A8D] dark:hover:text-[#F6EFE8] transition-colors cursor-pointer"
            aria-label="Close modal"
          >
            <X size={20} />
          </button>
        </div>

        {/* Navigation Tabs */}
        <div className="flex border-b border-[#F3DFCD] dark:border-[#383029] bg-white/30 dark:bg-[#201A15]/30 p-1.5 gap-1">
          <button
            type="button"
            id="tab-reminders-tray"
            onClick={() => setActiveTab('tray')}
            className={`flex-1 py-2 px-3 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-1.5 cursor-pointer ${
              activeTab === 'tray'
                ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                : 'text-[#7A6E63] dark:text-[#A89A8D] hover:bg-black/5 dark:hover:bg-white/5'
            }`}
          >
            <Bell size={14} />
            <span>Alerts Tray</span>
            {unreadNotificationsCount > 0 && (
              <span className="w-2 h-2 rounded-full bg-[#B03C09] dark:bg-[#FF9A52]"></span>
            )}
          </button>

          <button
            type="button"
            id="tab-reminders-rules"
            onClick={() => setActiveTab('rules')}
            className={`flex-1 py-2 px-3 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-1.5 cursor-pointer ${
              activeTab === 'rules'
                ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                : 'text-[#7A6E63] dark:text-[#A89A8D] hover:bg-black/5 dark:hover:bg-white/5'
            }`}
          >
            <Sliders size={14} />
            <span>Schedules & Rules</span>
          </button>

          <button
            type="button"
            id="tab-reminders-test"
            onClick={() => setActiveTab('test')}
            className={`flex-1 py-2 px-3 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-1.5 cursor-pointer ${
              activeTab === 'test'
                ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                : 'text-[#7A6E63] dark:text-[#A89A8D] hover:bg-black/5 dark:hover:bg-white/5'
            }`}
          >
            <Play size={14} />
            <span>Test Simulator</span>
          </button>
        </div>

        {/* Tab Content */}
        <div className="flex-1 overflow-y-auto p-4 sm:p-5 space-y-4">
          {/* TAB 1: ALERTS TRAY */}
          {activeTab === 'tray' && (
            <div className="space-y-4">
              {/* Controls and Filters */}
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="flex flex-wrap items-center gap-1.5">
                  {(['all', 'daily_expense', 'payment_due', 'bill_due', 'subscription'] as const).map(
                    (typeKey) => {
                      const count =
                        typeKey === 'all'
                          ? notifications.length
                          : notifications.filter((n) => n.type === typeKey).length;
                      const label =
                        typeKey === 'all'
                          ? 'All'
                          : typeKey === 'daily_expense'
                          ? 'Daily Log'
                          : typeKey === 'payment_due'
                          ? 'Payment Due'
                          : typeKey === 'bill_due'
                          ? 'Bills'
                          : 'Subscriptions';

                      return (
                        <button
                          key={typeKey}
                          type="button"
                          id={`filter-pill-${typeKey}`}
                          onClick={() => setFilterType(typeKey)}
                          className={`px-2.5 py-1 rounded-full text-xs font-semibold whitespace-nowrap cursor-pointer transition-colors ${
                            filterType === typeKey
                              ? 'bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D]'
                              : 'bg-black/5 dark:bg-white/5 text-[#7A6E63] dark:text-[#A89A8D]'
                          }`}
                        >
                          {label} ({count})
                        </button>
                      );
                    }
                  )}
                </div>

                <div className="flex items-center gap-2 shrink-0">
                  {unreadNotificationsCount > 0 && (
                    <button
                      type="button"
                      id="btn-mark-all-read"
                      onClick={markAllNotificationsRead}
                      className="text-xs font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline flex items-center gap-1 cursor-pointer"
                    >
                      <CheckCheck size={14} />
                      <span>Mark all read</span>
                    </button>
                  )}
                  {notifications.length > 0 && (
                    <button
                      type="button"
                      id="btn-clear-all-notifs"
                      onClick={clearAllNotifications}
                      className="text-xs font-bold text-[#7A6E63] hover:text-rose-600 dark:text-[#A89A8D] dark:hover:text-rose-400 flex items-center gap-1 cursor-pointer"
                    >
                      <Trash2 size={13} />
                      <span>Clear all</span>
                    </button>
                  )}
                </div>
              </div>

              {/* Notification List */}
              {filteredNotifications.length === 0 ? (
                <div className="p-8 text-center bg-white/40 dark:bg-[#201A15]/40 rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-2">
                  <div className="w-12 h-12 rounded-full bg-black/5 dark:bg-white/5 flex items-center justify-center mx-auto text-[#7A6E63] dark:text-[#A89A8D]">
                    <Bell size={24} />
                  </div>
                  <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    No Notifications Found
                  </h3>
                  <p className="text-xs text-[#7A6E63] dark:text-[#A89A8D] max-w-xs mx-auto">
                    You are all caught up! You can trigger a test reminder from the Test Simulator
                    tab to verify your alerts anytime.
                  </p>
                </div>
              ) : (
                <div className="space-y-2.5">
                  {filteredNotifications.map((notif) => {
                    const meta = getTypeMeta(notif.type);

                    return (
                      <div
                        key={notif.id}
                        id={`notif-item-${notif.id}`}
                        className={`p-3.5 sm:p-4 rounded-2xl border transition-all ${
                          notif.isRead
                            ? 'bg-white/60 dark:bg-[#201A15]/60 border-[#F3DFCD] dark:border-[#383029]'
                            : 'bg-white dark:bg-[#27201A] border-[#B03C09]/40 dark:border-[#FF9A52]/40 shadow-xs'
                        }`}
                      >
                        <div className="flex items-start justify-between gap-2.5">
                          <div className="flex items-start gap-2.5 min-w-0 flex-1">
                            <div className="mt-0.5 p-1.5 rounded-lg bg-black/5 dark:bg-white/5 shrink-0">
                              {meta.icon}
                            </div>
                            <div className="min-w-0 flex-1">
                              <div className="flex flex-wrap items-center gap-1.5 mb-1">
                                <span
                                  className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${meta.color}`}
                                >
                                  {meta.label}
                                </span>
                                <span className="text-[10px] font-medium text-[#7A6E63] dark:text-[#A89A8D]">
                                  {formatTimestamp(notif.timestamp)}
                                </span>
                                {!notif.isRead && (
                                  <span className="w-1.5 h-1.5 rounded-full bg-[#B03C09] dark:bg-[#FF9A52]"></span>
                                )}
                              </div>

                              <h4 className="text-xs sm:text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                                {notif.title}
                              </h4>
                              <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] mt-0.5 leading-relaxed">
                                {notif.body}
                              </p>

                              {/* Quick Action Button */}
                              <div className="flex items-center gap-2 mt-2.5">
                                <button
                                  type="button"
                                  id={`btn-action-item-${notif.id}`}
                                  onClick={() => handleActionClick(notif)}
                                  className="px-3 py-1 bg-[#B03C09] hover:bg-[#8F3006] text-white rounded-lg text-xs font-bold transition-colors cursor-pointer"
                                >
                                  {notif.actionType === 'open_log_expense'
                                    ? 'Log Expense Now'
                                    : notif.actionType === 'open_debts'
                                    ? 'View Debt'
                                    : notif.actionType === 'open_installments'
                                    ? 'View Installment'
                                    : 'View Bill & Pay'}
                                </button>

                                {!notif.isRead && (
                                  <button
                                    type="button"
                                    id={`btn-mark-item-read-${notif.id}`}
                                    onClick={() => markNotificationRead(notif.id)}
                                    className="px-2.5 py-1 text-xs font-bold text-[#7A6E63] hover:text-[#15120F] dark:text-[#A89A8D] dark:hover:text-[#F6EFE8] cursor-pointer"
                                  >
                                    Mark as read
                                  </button>
                                )}
                              </div>
                            </div>
                          </div>

                          <button
                            type="button"
                            id={`btn-delete-item-${notif.id}`}
                            onClick={() => clearNotification(notif.id)}
                            className="p-1 text-[#7A6E63] hover:text-rose-600 dark:text-[#A89A8D] dark:hover:text-rose-400 transition-colors cursor-pointer"
                            title="Remove notification"
                            aria-label="Remove notification"
                          >
                            <Trash2 size={15} />
                          </button>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {/* TAB 2: SCHEDULES & RULES */}
          {activeTab === 'rules' && (
            <div className="space-y-4">
              {/* Rule 1: Daily Expense Logging Reminder */}
              <div className="p-4 bg-white dark:bg-[#201A15] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-3">
                <div className="flex items-start justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <div className="p-2 rounded-xl bg-[#B03C09]/10 dark:bg-[#FF9A52]/15 text-[#B03C09] dark:text-[#FF9A52]">
                      <CalendarCheck size={18} />
                    </div>
                    <div>
                      <h3 className="text-xs sm:text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                        Daily Expense Logging Reminder
                      </h3>
                      <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
                        Reminds you if no entries are made by a set time each day
                      </p>
                    </div>
                  </div>

                  <label className="relative inline-flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      id="toggle-daily-reminder"
                      checked={reminderSettings.dailyExpenseReminderEnabled}
                      onChange={(e) =>
                        updateReminderSettings({ dailyExpenseReminderEnabled: e.target.checked })
                      }
                      className="sr-only peer"
                    />
                    <div className="w-9 h-5 bg-gray-300 peer-focus:outline-hidden rounded-full peer dark:bg-[#383029] peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-[#B03C09]"></div>
                  </label>
                </div>

                {reminderSettings.dailyExpenseReminderEnabled && (
                  <div className="pt-2 border-t border-[#F3DFCD] dark:border-[#383029] space-y-2">
                    <div className="flex items-center justify-between gap-2">
                      <span className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC] flex items-center gap-1.5">
                        <Clock size={14} className="text-[#B03C09] dark:text-[#FF9A52]" />
                        Daily Cutoff Time:
                      </span>

                      <div className="flex items-center gap-2">
                        <input
                          type="time"
                          id="input-daily-reminder-time"
                          value={reminderSettings.dailyExpenseReminderTime}
                          onChange={(e) =>
                            updateReminderSettings({ dailyExpenseReminderTime: e.target.value })
                          }
                          className="px-2.5 py-1 text-xs font-bold rounded-lg border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-[#15120F] dark:text-[#F6EFE8] cursor-pointer"
                        />
                        <span className="text-xs font-bold text-[#B03C09] dark:text-[#FF9A52]">
                          ({formatTimeDisplay(reminderSettings.dailyExpenseReminderTime)})
                        </span>
                      </div>
                    </div>

                    <div className="p-2.5 bg-black/3 dark:bg-white/3 rounded-xl flex items-center justify-between text-[11px]">
                      <span className="text-[#7A6E63] dark:text-[#A89A8D]">Today status:</span>
                      <span
                        className={`font-bold ${
                          todayExpensesCount > 0
                            ? 'text-emerald-600 dark:text-emerald-400'
                            : 'text-amber-600 dark:text-amber-400'
                        }`}
                      >
                        {todayExpensesCount > 0
                          ? `Logged ${todayExpensesCount} expense${todayExpensesCount > 1 ? 's' : ''} today`
                          : 'No expenses logged yet today'}
                      </span>
                    </div>
                  </div>
                )}
              </div>

              {/* Rule 2: Payment Due Reminder */}
              <div className="p-4 bg-white dark:bg-[#201A15] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-3">
                <div className="flex items-start justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <div className="p-2 rounded-xl bg-rose-500/10 text-rose-600 dark:text-rose-400">
                      <CreditCard size={18} />
                    </div>
                    <div>
                      <h3 className="text-xs sm:text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                        Payment Due Reminder
                      </h3>
                      <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
                        Debt installments, credit card statements, and loans
                      </p>
                    </div>
                  </div>

                  <label className="relative inline-flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      id="toggle-payment-reminder"
                      checked={reminderSettings.paymentDueReminderEnabled}
                      onChange={(e) =>
                        updateReminderSettings({ paymentDueReminderEnabled: e.target.checked })
                      }
                      className="sr-only peer"
                    />
                    <div className="w-9 h-5 bg-gray-300 peer-focus:outline-hidden rounded-full peer dark:bg-[#383029] peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-[#B03C09]"></div>
                  </label>
                </div>

                {reminderSettings.paymentDueReminderEnabled && (
                  <div className="pt-2 border-t border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between gap-2">
                    <span className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC]">
                      Advance Notice Window:
                    </span>
                    <select
                      id="select-payment-due-days"
                      value={reminderSettings.paymentDueDaysBefore}
                      onChange={(e) =>
                        updateReminderSettings({
                          paymentDueDaysBefore: parseInt(e.target.value, 10),
                        })
                      }
                      className="px-2.5 py-1 text-xs font-bold rounded-lg border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-[#15120F] dark:text-[#F6EFE8] cursor-pointer"
                    >
                      <option value="0">Due Today Only</option>
                      <option value="1">1 Day in Advance</option>
                      <option value="2">2 Days in Advance</option>
                      <option value="3">3 Days in Advance</option>
                      <option value="5">5 Days in Advance</option>
                    </select>
                  </div>
                )}
              </div>

              {/* Rule 3: Bill Reminder */}
              <div className="p-4 bg-white dark:bg-[#201A15] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-3">
                <div className="flex items-start justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <div className="p-2 rounded-xl bg-amber-500/10 text-amber-600 dark:text-amber-400">
                      <Zap size={18} />
                    </div>
                    <div>
                      <h3 className="text-xs sm:text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                        Bill Due Reminder
                      </h3>
                      <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
                        Meralco, Manila Water, Wi-Fi, Condo Dues, and Rent
                      </p>
                    </div>
                  </div>

                  <label className="relative inline-flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      id="toggle-bill-reminder"
                      checked={reminderSettings.billReminderEnabled}
                      onChange={(e) =>
                        updateReminderSettings({ billReminderEnabled: e.target.checked })
                      }
                      className="sr-only peer"
                    />
                    <div className="w-9 h-5 bg-gray-300 peer-focus:outline-hidden rounded-full peer dark:bg-[#383029] peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-[#B03C09]"></div>
                  </label>
                </div>

                {reminderSettings.billReminderEnabled && (
                  <div className="pt-2 border-t border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between gap-2">
                    <span className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC]">
                      Advance Notice Window:
                    </span>
                    <select
                      id="select-bill-days"
                      value={reminderSettings.billDaysBefore}
                      onChange={(e) =>
                        updateReminderSettings({
                          billDaysBefore: parseInt(e.target.value, 10),
                        })
                      }
                      className="px-2.5 py-1 text-xs font-bold rounded-lg border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-[#15120F] dark:text-[#F6EFE8] cursor-pointer"
                    >
                      <option value="0">Due Today Only</option>
                      <option value="1">1 Day in Advance</option>
                      <option value="2">2 Days in Advance</option>
                      <option value="3">3 Days in Advance</option>
                      <option value="5">5 Days in Advance</option>
                    </select>
                  </div>
                )}
              </div>

              {/* Rule 4: Subscription Reminder */}
              <div className="p-4 bg-white dark:bg-[#201A15] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-3">
                <div className="flex items-start justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <div className="p-2 rounded-xl bg-blue-500/10 text-blue-600 dark:text-blue-400">
                      <RefreshCw size={18} />
                    </div>
                    <div>
                      <h3 className="text-xs sm:text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                        Subscription Renewal Reminder
                      </h3>
                      <p className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
                        Spotify, Netflix, Apple One, and recurring subscriptions
                      </p>
                    </div>
                  </div>

                  <label className="relative inline-flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      id="toggle-subscription-reminder"
                      checked={reminderSettings.subscriptionReminderEnabled}
                      onChange={(e) =>
                        updateReminderSettings({ subscriptionReminderEnabled: e.target.checked })
                      }
                      className="sr-only peer"
                    />
                    <div className="w-9 h-5 bg-gray-300 peer-focus:outline-hidden rounded-full peer dark:bg-[#383029] peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-[#B03C09]"></div>
                  </label>
                </div>

                {reminderSettings.subscriptionReminderEnabled && (
                  <div className="pt-2 border-t border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between gap-2">
                    <span className="text-xs font-semibold text-[#5A5148] dark:text-[#C6B8AC]">
                      Advance Notice Window:
                    </span>
                    <select
                      id="select-subscription-days"
                      value={reminderSettings.subscriptionDaysBefore}
                      onChange={(e) =>
                        updateReminderSettings({
                          subscriptionDaysBefore: parseInt(e.target.value, 10),
                        })
                      }
                      className="px-2.5 py-1 text-xs font-bold rounded-lg border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-[#15120F] dark:text-[#F6EFE8] cursor-pointer"
                    >
                      <option value="0">Renewal Day Only</option>
                      <option value="1">1 Day in Advance</option>
                      <option value="2">2 Days in Advance</option>
                      <option value="3">3 Days in Advance</option>
                    </select>
                  </div>
                )}
              </div>

              {/* Delivery Channels */}
              <div className="p-4 bg-white dark:bg-[#201A15] rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-3">
                <h3 className="text-xs font-bold uppercase tracking-wider text-[#7A6E63] dark:text-[#A89A8D]">
                  Alert Delivery Channels
                </h3>

                {/* Web Native Notifications */}
                <div className="flex items-center justify-between gap-2 py-1">
                  <div className="flex items-center gap-2">
                    <Globe size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />
                    <div>
                      <div className="flex items-center gap-1.5">
                        <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                          Browser Web Notifications
                        </span>
                        <span
                          className={`px-1.5 py-0.2 rounded-full text-[9px] font-bold ${
                            webNotificationPermission === 'granted'
                              ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300'
                              : webNotificationPermission === 'denied'
                              ? 'bg-rose-100 text-rose-800 dark:bg-rose-950 dark:text-rose-300'
                              : 'bg-black/5 dark:bg-white/5 text-[#7A6E63]'
                          }`}
                        >
                          {webNotificationPermission.toUpperCase()}
                        </span>
                      </div>
                      <span className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D]">
                        Show system banners even when app is tabbed out
                      </span>
                    </div>
                  </div>

                  {webNotificationPermission !== 'granted' ? (
                    <button
                      type="button"
                      id="btn-request-web-permission"
                      onClick={handleRequestPermission}
                      className="px-2.5 py-1 text-xs font-bold bg-[#B03C09] text-white rounded-lg cursor-pointer"
                    >
                      Enable
                    </button>
                  ) : (
                    <label className="relative inline-flex items-center cursor-pointer">
                      <input
                        type="checkbox"
                        id="toggle-web-notifications"
                        checked={reminderSettings.webNotificationsEnabled}
                        onChange={(e) =>
                          updateReminderSettings({ webNotificationsEnabled: e.target.checked })
                        }
                        className="sr-only peer"
                      />
                      <div className="w-9 h-5 bg-gray-300 peer-focus:outline-hidden rounded-full peer dark:bg-[#383029] peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-[#B03C09]"></div>
                    </label>
                  )}
                </div>

                {permissionFeedback && (
                  <p className="text-[11px] font-semibold text-[#B03C09] dark:text-[#FF9A52]">
                    {permissionFeedback}
                  </p>
                )}

                {/* In-App Toast Banners */}
                <div className="flex items-center justify-between gap-2 py-1 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60">
                  <div className="flex items-center gap-2">
                    <Bell size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />
                    <div>
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                        In-App Toast Banners
                      </span>
                      <p className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D]">
                        Floating interactive toast at top of screen
                      </p>
                    </div>
                  </div>

                  <label className="relative inline-flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      id="toggle-inapp-toasts"
                      checked={reminderSettings.inAppToastsEnabled}
                      onChange={(e) =>
                        updateReminderSettings({ inAppToastsEnabled: e.target.checked })
                      }
                      className="sr-only peer"
                    />
                    <div className="w-9 h-5 bg-gray-300 peer-focus:outline-hidden rounded-full peer dark:bg-[#383029] peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-[#B03C09]"></div>
                  </label>
                </div>

                {/* Subtle Audio Chime */}
                <div className="flex items-center justify-between gap-2 py-1 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60">
                  <div className="flex items-center gap-2">
                    {reminderSettings.soundEnabled ? (
                      <Volume2 size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />
                    ) : (
                      <VolumeX size={16} className="text-[#7A6E63]" />
                    )}
                    <div>
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                        Audio Chime (Web Audio Synthesizer)
                      </span>
                      <p className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D]">
                        Pleasant 2-tone melodic chime without external audio files
                      </p>
                    </div>
                  </div>

                  <label className="relative inline-flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      id="toggle-audio-chime"
                      checked={reminderSettings.soundEnabled}
                      onChange={(e) => updateReminderSettings({ soundEnabled: e.target.checked })}
                      className="sr-only peer"
                    />
                    <div className="w-9 h-5 bg-gray-300 peer-focus:outline-hidden rounded-full peer dark:bg-[#383029] peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-[#B03C09]"></div>
                  </label>
                </div>
              </div>
            </div>
          )}

          {/* TAB 3: TEST SIMULATOR */}
          {activeTab === 'test' && (
            <div className="space-y-4">
              <div className="p-4 bg-[#B03C09]/10 dark:bg-[#FF9A52]/10 rounded-2xl border border-[#B03C09]/20 dark:border-[#FF9A52]/20 flex items-start gap-3">
                <Sparkles size={20} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0 mt-0.5" />
                <div className="text-xs">
                  <span className="font-bold block text-[#15120F] dark:text-[#F6EFE8] mb-0.5">
                    Instant Notification Verification
                  </span>
                  <p className="text-[#5A5148] dark:text-[#C6B8AC]">
                    Click any test button below to immediately fire a notification. This tests the
                    in-app floating toast banner, Web Audio chime, and native browser notification
                    simultaneously.
                  </p>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {/* Test 1: Daily Expense */}
                <button
                  type="button"
                  id="btn-test-daily-expense"
                  onClick={() => triggerSimulatedReminder('daily_expense')}
                  className="p-3.5 bg-white dark:bg-[#201A15] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl text-left hover:border-[#B03C09] dark:hover:border-[#FF9A52] transition-all cursor-pointer flex flex-col justify-between gap-3 shadow-xs group"
                >
                  <div className="flex items-center gap-2">
                    <div className="p-2 rounded-xl bg-[#B03C09]/10 dark:bg-[#FF9A52]/15 text-[#B03C09] dark:text-[#FF9A52] group-hover:scale-105 transition-transform">
                      <CalendarCheck size={18} />
                    </div>
                    <div>
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block">
                        Daily Expense Alert
                      </span>
                      <span className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D]">
                        No entries by {formatTimeDisplay(reminderSettings.dailyExpenseReminderTime)}
                      </span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between text-xs font-bold text-[#B03C09] dark:text-[#FF9A52] pt-2 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60">
                    <span>Fire Daily Test</span>
                    <Play size={12} />
                  </div>
                </button>

                {/* Test 2: Payment Due */}
                <button
                  type="button"
                  id="btn-test-payment-due"
                  onClick={() => triggerSimulatedReminder('payment_due')}
                  className="p-3.5 bg-white dark:bg-[#201A15] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl text-left hover:border-rose-500 transition-all cursor-pointer flex flex-col justify-between gap-3 shadow-xs group"
                >
                  <div className="flex items-center gap-2">
                    <div className="p-2 rounded-xl bg-rose-500/10 text-rose-600 dark:text-rose-400 group-hover:scale-105 transition-transform">
                      <CreditCard size={18} />
                    </div>
                    <div>
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block">
                        Payment Due Alert
                      </span>
                      <span className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D]">
                        Credit card or debt cutoff
                      </span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between text-xs font-bold text-rose-600 dark:text-rose-400 pt-2 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60">
                    <span>Fire Payment Test</span>
                    <Play size={12} />
                  </div>
                </button>

                {/* Test 3: Bill Due */}
                <button
                  type="button"
                  id="btn-test-bill-due"
                  onClick={() => triggerSimulatedReminder('bill_due')}
                  className="p-3.5 bg-white dark:bg-[#201A15] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl text-left hover:border-amber-500 transition-all cursor-pointer flex flex-col justify-between gap-3 shadow-xs group"
                >
                  <div className="flex items-center gap-2">
                    <div className="p-2 rounded-xl bg-amber-500/10 text-amber-600 dark:text-amber-400 group-hover:scale-105 transition-transform">
                      <Zap size={18} />
                    </div>
                    <div>
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block">
                        Bill Due Alert
                      </span>
                      <span className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D]">
                        Meralco electricity bill
                      </span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between text-xs font-bold text-amber-600 dark:text-amber-400 pt-2 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60">
                    <span>Fire Bill Test</span>
                    <Play size={12} />
                  </div>
                </button>

                {/* Test 4: Subscription */}
                <button
                  type="button"
                  id="btn-test-subscription"
                  onClick={() => triggerSimulatedReminder('subscription')}
                  className="p-3.5 bg-white dark:bg-[#201A15] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl text-left hover:border-blue-500 transition-all cursor-pointer flex flex-col justify-between gap-3 shadow-xs group"
                >
                  <div className="flex items-center gap-2">
                    <div className="p-2 rounded-xl bg-blue-500/10 text-blue-600 dark:text-blue-400 group-hover:scale-105 transition-transform">
                      <RefreshCw size={18} />
                    </div>
                    <div>
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] block">
                        Subscription Alert
                      </span>
                      <span className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D]">
                        Spotify renewal notice
                      </span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between text-xs font-bold text-blue-600 dark:text-blue-400 pt-2 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60">
                    <span>Fire Subscription Test</span>
                    <Play size={12} />
                  </div>
                </button>
              </div>

              {/* Privacy & Engine Assurance Card */}
              <div className="p-4 bg-white/40 dark:bg-[#201A15]/40 rounded-2xl border border-[#F3DFCD] dark:border-[#383029] space-y-1.5 text-xs">
                <div className="flex items-center gap-1.5 font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  <ShieldCheck size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />
                  <span>100% Offline Recurring Engine</span>
                </div>
                <p className="text-[#7A6E63] dark:text-[#A89A8D] leading-relaxed">
                  All reminder checks run completely locally inside your browser container. No
                  financial balances, merchant names, or spending habits are ever transmitted to any
                  cloud server.
                </p>
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-[#F3DFCD] dark:border-[#383029] bg-white/50 dark:bg-[#201A15]/50 flex items-center justify-between">
          <div className="text-[11px] text-[#7A6E63] dark:text-[#A89A8D]">
            Cadence: Checks active every 30s locally
          </div>
          <button
            type="button"
            id="btn-done-reminders"
            onClick={onClose}
            className="px-4 py-2 bg-[#B03C09] hover:bg-[#8F3006] text-white rounded-xl text-xs font-bold transition-colors cursor-pointer"
          >
            Done
          </button>
        </div>
      </div>
    </div>
  );
};
