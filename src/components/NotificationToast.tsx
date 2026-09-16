import React from 'react';
import {
  X,
  CalendarCheck,
  CreditCard,
  Zap,
  RefreshCw,
  ChevronRight,
  Bell,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { AppNotification, ReminderType } from '../types';

interface NotificationToastProps {
  onActionClick?: (notification: AppNotification) => void;
  onOpenLogExpense?: () => void;
  onOpenBills?: () => void;
  onOpenDebts?: () => void;
  onOpenInstallments?: () => void;
  onOpenRemindersCenter?: () => void;
}

export const NotificationToast: React.FC<NotificationToastProps> = ({
  onActionClick,
  onOpenLogExpense,
  onOpenBills,
  onOpenDebts,
  onOpenInstallments,
  onOpenRemindersCenter,
}) => {
  const { activeToasts, dismissToast, markNotificationRead } = useFinancial();

  if (!activeToasts || activeToasts.length === 0) return null;

  const getIcon = (type: ReminderType) => {
    switch (type) {
      case 'daily_expense':
        return <CalendarCheck size={18} className="text-[#B03C09] dark:text-[#FF9A52]" />;
      case 'payment_due':
        return <CreditCard size={18} className="text-rose-600 dark:text-rose-400" />;
      case 'bill_due':
        return <Zap size={18} className="text-amber-600 dark:text-amber-400" />;
      case 'subscription':
        return <RefreshCw size={18} className="text-blue-600 dark:text-blue-400" />;
      default:
        return <Bell size={18} className="text-[#B03C09] dark:text-[#FF9A52]" />;
    }
  };

  const getTypeBadge = (type: ReminderType) => {
    switch (type) {
      case 'daily_expense':
        return {
          label: 'Daily Log Reminder',
          bg: 'bg-[#B03C09]/10 text-[#B03C09] dark:bg-[#FF9A52]/15 dark:text-[#FF9A52] border-[#B03C09]/20 dark:border-[#FF9A52]/30',
        };
      case 'payment_due':
        return {
          label: 'Payment Due',
          bg: 'bg-rose-500/10 text-rose-700 dark:text-rose-300 border-rose-500/20',
        };
      case 'bill_due':
        return {
          label: 'Bill Due',
          bg: 'bg-amber-500/10 text-amber-700 dark:text-amber-300 border-amber-500/20',
        };
      case 'subscription':
        return {
          label: 'Subscription Renewal',
          bg: 'bg-blue-500/10 text-blue-700 dark:text-blue-300 border-blue-500/20',
        };
    }
  };

  const handleItemClick = (notification: AppNotification) => {
    markNotificationRead(notification.id);
    dismissToast(notification.id);

    if (onActionClick) {
      onActionClick(notification);
      return;
    }

    if (notification.actionType === 'open_log_expense' && onOpenLogExpense) {
      onOpenLogExpense();
    } else if (notification.actionType === 'open_debts' && onOpenDebts) {
      onOpenDebts();
    } else if (notification.actionType === 'open_installments' && onOpenInstallments) {
      onOpenInstallments();
    } else if (notification.actionType === 'open_bills' && onOpenBills) {
      onOpenBills();
    } else if (onOpenRemindersCenter) {
      onOpenRemindersCenter();
    }
  };

  return (
    <div
      id="salapify-notification-toast-container"
      className="fixed top-3 left-1/2 -translate-x-1/2 z-50 w-[94%] max-w-md pointer-events-none flex flex-col gap-2"
    >
      {activeToasts.slice(0, 3).map((toast) => {
        const badge = getTypeBadge(toast.type);

        return (
          <div
            key={toast.id}
            id={`toast-${toast.id}`}
            className="pointer-events-auto bg-white dark:bg-[#201A15] border-2 border-[#B03C09] dark:border-[#FF9A52] rounded-2xl shadow-xl p-3.5 sm:p-4 animate-in fade-in slide-in-from-top-4 duration-300 flex flex-col gap-2"
          >
            {/* Header row */}
            <div className="flex items-start justify-between gap-2">
              <div className="flex items-center gap-2 min-w-0">
                <div className="p-1.5 rounded-xl bg-black/5 dark:bg-white/5 shrink-0">
                  {getIcon(toast.type)}
                </div>
                <div className="min-w-0">
                  <span
                    className={`inline-block px-2 py-0.5 rounded-full text-[10px] font-bold border whitespace-nowrap ${badge.bg}`}
                  >
                    {badge.label}
                  </span>
                  <h4 className="text-xs sm:text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] truncate mt-0.5">
                    {toast.title}
                  </h4>
                </div>
              </div>

              <button
                type="button"
                id={`btn-dismiss-toast-${toast.id}`}
                onClick={() => dismissToast(toast.id)}
                className="p-1 text-[#7A6E63] hover:text-[#15120F] dark:text-[#A89A8D] dark:hover:text-[#F6EFE8] rounded-lg transition-colors cursor-pointer"
                title="Dismiss"
                aria-label="Dismiss notification"
              >
                <X size={16} />
              </button>
            </div>

            {/* Body text */}
            <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
              {toast.body}
            </p>

            {/* Action Row */}
            <div className="flex items-center justify-between pt-1 border-t border-[#F3DFCD] dark:border-[#383029]">
              <span className="text-[10px] text-[#7A6E63] dark:text-[#A89A8D]">
                Salapify Local Reminder
              </span>

              <button
                type="button"
                id={`btn-toast-action-${toast.id}`}
                onClick={() => handleItemClick(toast)}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-[#B03C09] hover:bg-[#8F3006] text-white rounded-lg text-xs font-bold transition-colors cursor-pointer shadow-xs"
              >
                <span>
                  {toast.actionType === 'open_log_expense'
                    ? 'Log Expense Now'
                    : toast.actionType === 'open_debts'
                    ? 'View Debt'
                    : toast.actionType === 'open_installments'
                    ? 'View Installment'
                    : 'View Bill & Pay'}
                </span>
                <ChevronRight size={13} />
              </button>
            </div>
          </div>
        );
      })}
    </div>
  );
};
