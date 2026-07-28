// The 7-day logging chain, ported from the RN WeekChain (mobile/components/
// WeekChain.js). Derived per call from the transactions list, nothing stored:
// the chain cannot desync from the ledger because it IS the ledger, read
// sideways.
//
// Deliberately a chain, not a streak: nothing resets. Missing a day leaves a
// gap in the dots and a gentle line about filling it, never a zeroed counter.
// That behavioral design came from the RN app and it is the whole point.
//
// Copy differences from RN, on purpose: the RN lines carried emoji and
// Tagalog sentence fragments. UI copy is English first (founder decision,
// 2026-07-23) and emoji in Salapify-authored content draws as an OS sticker
// the palette cannot reach, so the lines here say the same things in plain
// English with no emoji.

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// One dot of the chain.
class ChainDay {
  final String iso;
  final String letter;
  final bool done;
  final bool isToday;
  const ChainDay({
    required this.iso,
    required this.letter,
    required this.done,
    required this.isToday,
  });
}

/// The whole chain state for a reference day.
class ChainState {
  final List<ChainDay> days;
  final int count;
  final bool todayDone;
  final bool fullWeek;
  final bool missedYesterday;
  final String message;
  const ChainState({
    required this.days,
    required this.count,
    required this.todayDone,
    required this.fullWeek,
    required this.missedYesterday,
    required this.message,
  });
}

const _dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

/// Build the chain for the 7 days ending on [ref]'s date, oldest first.
///
/// A day counts as logged when any income or expense carries its date.
/// Transfers, debt payments and adjustments do not count, the RN rule: the
/// chain rewards the logging habit, and records are written by machinery.
ChainState chainState(dynamic transactions, DateTime ref) {
  final logged = <String>{};
  if (transactions is List) {
    for (final t in transactions) {
      if (t is! Map) continue;
      final type = t['type'];
      if (type != 'income' && type != 'expense') continue;
      final date = t['date'];
      if (date is String && date.isNotEmpty) logged.add(date);
    }
  }
  final days = <ChainDay>[];
  for (var i = 6; i >= 0; i--) {
    final d = DateTime(ref.year, ref.month, ref.day - i);
    final iso = _iso(d);
    days.add(
      ChainDay(
        iso: iso,
        letter: _dayLetters[d.weekday % 7],
        done: logged.contains(iso),
        isToday: i == 0,
      ),
    );
  }
  final count = days.where((d) => d.done).length;
  final todayDone = days[6].done;
  final fullWeek = count == 7;
  // Yesterday empty AND something logged in the five days before it: a chain
  // exists to come back to. Only spoken while today is also still unlogged,
  // because once today is logged the comeback already happened.
  final missedYesterday =
      !days[5].done && days.sublist(0, 5).any((d) => d.done);

  final String message;
  if (count == 0) {
    message = 'Log anything today to start your chain.';
  } else if (fullWeek) {
    message = '7 for 7. The whole week, logged.';
  } else if (missedYesterday && !todayDone) {
    message =
        'Missed yesterday? Nothing resets here. Log today, or pick '
        'Yesterday on the log sheet to fill the gap.';
  } else if (count == 1) {
    message = 'Day one logged. Every chain starts with one dot.';
  } else if (count == 2) {
    message = 'Two days in. One more and this becomes a real habit.';
  } else if (count == 3) {
    message = 'Three days logged. This is a real chain now.';
  } else {
    message = 'Logged $count of the last 7 days. Keep the chain going.';
  }

  return ChainState(
    days: days,
    count: count,
    todayDone: todayDone,
    fullWeek: fullWeek,
    missedYesterday: missedYesterday,
    message: message,
  );
}
