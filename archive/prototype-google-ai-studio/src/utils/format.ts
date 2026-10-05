export function formatPeso(amount: number, showDecimals: boolean = true): string {
  const parts = Math.abs(amount).toLocaleString('en-PH', {
    minimumFractionDigits: showDecimals ? 2 : 0,
    maximumFractionDigits: showDecimals ? 2 : 0,
  });
  return `₱${parts}`;
}

export function formatSignedPeso(amount: number, type?: 'income' | 'expense'): string {
  const formatted = formatPeso(Math.abs(amount));
  if (type === 'income' || amount > 0) {
    return `+${formatted}`;
  }
  return formatted;
}

export function formatDateLabel(isoDate: string): string {
  const date = new Date(isoDate);
  if (isNaN(date.getTime())) return isoDate;
  
  const today = new Date();
  const yesterday = new Date();
  yesterday.setDate(today.getDate() - 1);

  if (date.toDateString() === today.toDateString()) {
    return 'Today';
  }
  if (date.toDateString() === yesterday.toDateString()) {
    return 'Yesterday';
  }

  return date.toLocaleDateString('en-PH', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  });
}
