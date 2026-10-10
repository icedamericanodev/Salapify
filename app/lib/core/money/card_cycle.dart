import '../../models/models.dart';
import 'reminders.dart' show daysUntil;

/// Where a credit card sits in its billing cycle.
///
/// A credit card runs on TWO dates and most people only ever hear about one
/// of them. The statement date, or cutoff, is when the bank closes the month
/// and works out what you owe. The due date is when that amount has to be
/// paid. Everything that makes a card cheap or expensive lives in the gap
/// between those two dates, and the app has been storing both since the first
/// build while showing neither as anything more than the text somebody typed.
///
/// ## The field nobody could fill
///
/// `Account.statementDate` round trips through the model, the codec and the
/// backup file, and there was no input for it anywhere in the app. The sample
/// card has one because the seed sets it directly. A person could not. So
/// this module arrives with an editor beside it, or it would compute a figure
/// out of a field that is always null.
///
/// ## What is NOT ported
///
/// The prototype's card advisory prints "3% finance charge" and "Up to 50
/// days interest-free". Neither number comes from the person's own card, and
/// both vary by bank and by card. A made up rate shown next to a real balance
/// reads as this card's rate, and somebody plans around it. The same
/// reasoning already kept the prototype's invented 40,000 credit limit out of
/// `creditUtilization`.
///
/// It also does its date arithmetic on 30 day months, three separate times,
/// with `if (days < 0) days += 30`. February is 28 days and seven months are
/// 31, so "due in 3 days" can really be due tomorrow. Everything here counts
/// real calendar days through [daysUntil], which is the same parser the
/// reminder tray already uses, so a date that raises a reminder and a date
/// that draws this strip can never disagree about what day it is.

/// How many days until the statement closes and until the payment falls due.
///
/// Either may be null, and null means UNREADABLE rather than zero. The two
/// date fields are free text on purpose, because a card that bills on the
/// last working day of the month has no clean day number to store, so a
/// person can always type something no parser can settle. Saying nothing is
/// the right answer there; a guess would be drawn on screen next to a real
/// balance and read as fact.
class CardCycle {
  const CardCycle({this.daysToCutoff, this.daysToDue});

  /// Days until the statement closes. NEGATIVE IS POSSIBLE, which the first
  /// version of this comment denied.
  ///
  /// A cutoff written as a repeating day ("the 10th") does roll forward to
  /// the next one and so is never negative. But the field is free text, so
  /// somebody can write a one-off date instead, and "Sep 18" read on the
  /// 20th is two days ago. The render of three sample cards is what showed
  /// it: one of them had exactly that, and the rule below read it wrongly.
  final int? daysToCutoff;

  /// Days until the payment falls due. Negative means it is already late.
  final int? daysToDue;

  bool get knowsCutoff => daysToCutoff != null;
  bool get knowsDue => daysToDue != null;

  /// True when there is anything at all to draw.
  bool get isKnown => knowsCutoff || knowsDue;

  /// True when the payment being counted is for a statement that has ALREADY
  /// closed, so the amount is fixed and only the paying is left.
  ///
  /// Two ways that happens, and the first one was missed until three sample
  /// cards were rendered and looked at.
  ///
  /// 1. THE CUTOFF ITSELF HAS PASSED. The bill closed, so the payment coming
  ///    up is for it by definition. Only a one-off date can do this, because
  ///    a repeating day rolls forward, which is exactly why it was easy to
  ///    miss: every test written from a day number said the cutoff was in
  ///    the future.
  /// 2. The cutoff is still ahead but the due date arrives FIRST. A bill
  ///    cannot fall due before the month it bills for has been closed, so a
  ///    due date on the near side of the cutoff must belong to the month
  ///    before it.
  ///
  /// Equality is deliberately NOT counted. A card whose cutoff and due date
  /// land on the same day is genuinely ambiguous from two dates alone, and
  /// the screen resolves an ambiguity by saying less.
  bool get paymentOutstanding =>
      knowsCutoff &&
      knowsDue &&
      (daysToCutoff! < 0 || daysToDue! < daysToCutoff!);

  /// True when the payment date has passed.
  bool get isLate => knowsDue && daysToDue! < 0;
}

/// Read a card's two stored dates against a given day.
///
/// Returns an empty cycle for anything that is not a credit card. A savings
/// account has no statement, and a loan's due date is a fixed instalment
/// rather than a cycle, so neither gets a strip that implies one.
CardCycle cardCycleFor(Account account, DateTime now) {
  if (account.kind != AccountKind.credit) return const CardCycle();
  return CardCycle(
    daysToCutoff: daysUntil(account.statementDate, now),
    daysToDue: daysUntil(account.dueDate, now),
  );
}

/// "today", "tomorrow", "in 4 days", "3 days ago".
///
/// Plain English and no jargon, because the founder is the first reader of
/// every line in this app and "T-4" is not a sentence.
String inDaysPhrase(int days) {
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days == -1) return 'yesterday';
  if (days < 0) return '${-days} days ago';
  return 'in $days days';
}
