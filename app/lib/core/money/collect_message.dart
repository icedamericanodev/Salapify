/// Help with the hardest part of money owed TO you: asking for it (D31).
///
/// People do not avoid collecting because they forget. They avoid it because
/// asking feels awkward, and between friends and family that awkwardness is
/// real. So Salapify writes the words, and the person sends them through
/// whichever chat app they use, after editing them if they like. Nothing is
/// sent by Salapify itself: the share sheet hands the text over and the
/// person chooses where it goes.
library;

import '../../models/models.dart';
import 'format.dart';
import 'reminders.dart';

/// Whole days a debt is past its due date, or null when it is not overdue:
/// settled, archived, no due date, a due date nobody could read, or a date
/// still ahead. A bare day of the month ("15th") never reads as overdue,
/// because it means the NEXT such day.
int? overdueDays(Debt debt, DateTime now) {
  if (debt.isSettled || debt.isArchived) return null;
  final int? days = daysUntil(debt.dueDate, now);
  if (days == null || days >= 0) return null;
  return -days;
}

/// A short, polite message asking for money owed to the person.
///
/// Warm and neutral on purpose: it names the amount, never the debt's
/// history or how late it is, because a message that sounds like a demand
/// is the one that does not get sent. The first word of the name only, as a
/// person would write to someone they know.
String collectionMessage(Debt debt, {required DateTime now}) {
  final String name = debt.person.trim().split(RegExp(r'\s+')).first;
  final String amount = formatPeso(debt.remaining.pesos);
  final String due = debt.dueDate == null || debt.dueDate!.trim().isEmpty
      ? ''
      : ' (due ${debt.dueDate!.trim()})';
  final String greeting = name.isEmpty ? 'Hi' : 'Hi $name';
  return '$greeting, just a friendly reminder about the $amount$due. '
      'Whenever you can, thank you!';
}
