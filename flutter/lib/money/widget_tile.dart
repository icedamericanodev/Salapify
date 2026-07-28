// Every string the home screen tile shows, decided in one pure function.
//
// This is round one of the widget: NO native code exists yet, and none is
// needed to test any of this. That split is the whole design. Kotlin will read
// these strings and put them in four TextViews; it will do no money math, no
// date math, and make no decisions. So the entire decision surface is here,
// where `flutter test` can drive all eight states.
//
// It computes no new money math either. It composes cycleStatus, which
// composes the golden locked safeToSpend and paydayProjection, and formats the
// result. A widget that re-implemented "safe to spend" would be a second,
// unverified copy of the most important number in the app.
//
// EVERY VALUE IS A STRING, including the ones that look like numbers. The
// bridge stores each Dart type in a different slot, so a key that changes type
// between two builds makes the native side throw and the tile goes blank on a
// phone nobody can debug. One type, forever, removes that failure.

import 'cycle.dart' show cycleStatus;
import 'debtmath.dart' show formatMoneyText;

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// An ISO date as a short human day, "Jul 27".
///
/// A private copy of prettyDay, which lives in screens/overview.dart and
/// therefore imports Flutter. This file must not, so it can stay plain Dart.
/// widget_tile_test.dart asserts the two agree across a set of dates including
/// junk, which costs five lines and stops a third month name list drifting.
String _prettyDay(String iso) {
  final p = iso.split('-');
  if (p.length < 3) return iso;
  final y = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2].length > 2 ? p[2].substring(0, 2) : p[2]);
  if (y == null || m == null || d == null || m < 1 || m > 12) return iso;
  return '${_months[m - 1]} $d';
}

/// "Jul 27, 7:04 PM", baked at write time.
///
/// The date is ALWAYS present, never conditional on whether it is today, and
/// that is the one honesty mechanism in the whole widget. A tile written last
/// night would otherwise still read "as of 7:04 PM" this morning and look
/// current. With the day in it, a stale tile visibly names an old day, and the
/// native side needs no clock at all.
String _stampedAt(DateTime ref) {
  final h24 = ref.hour;
  final h = h24 % 12 == 0 ? 12 : h24 % 12;
  final m = ref.minute.toString().padLeft(2, '0');
  final ampm = h24 < 12 ? 'AM' : 'PM';
  return 'as of ${_months[ref.month - 1]} ${ref.day}, $h:$m $ampm';
}

/// The headline text size, because a RemoteViews TextView cannot autosize and
/// the peso figure is variable width: "₱1,234,567" is ten characters where
/// "₱1,000" is six.
String _headlineSp(String headline) {
  if (headline.length <= 8) return '32';
  if (headline.length <= 11) return '24';
  return '20';
}

/// The six content strings plus the build stamp.
///
/// [appLock] and [hideAmounts] are passed IN rather than read from settings
/// here, so a test can drive all eight states without assembling settings
/// maps, and so this function stays honestly pure. The caller reads the two
/// keys.
///
/// [stamp] is never rendered. It is written so that if a tile ever looks
/// wrong, the stored file names the build that wrote it.
///
/// Junk never throws: anything unreadable resolves to a silent state, the same
/// posture cycleStatus itself takes.
Map<String, String> widgetTileStrings(
  dynamic data,
  DateTime ref, {
  required bool canWrite,
  required bool appLock,
  required bool hideAmounts,
  required String stamp,
}) {
  Map<String, String> tile({
    required String headline,
    required String sub,
    required String bar,
    required bool barLogs,
    bool asOf = false,
  }) => {
    'yn_headline': headline,
    'yn_headline_sp': _headlineSp(headline),
    'yn_sub': sub,
    'yn_asof': asOf ? _stampedAt(ref) : '',
    'yn_bar': bar,
    // '1' opens the log sheet, '0' just opens the app. Never a dead tap.
    'yn_bar_tap': barLogs ? '1' : '0',
    'yn_stamp': stamp,
  };

  // 1. A failed read comes FIRST. The store holds its empty default after one,
  // so computing a peso figure from it would print a specific, credible,
  // wrong number, which is the worst failure this app has. The bar must also
  // not offer a write that would throw.
  if (!canWrite) {
    return tile(
      headline: 'Open Salapify',
      sub: 'Saving is off until your stored data can be read. Tap to fix it.',
      bar: 'Open Salapify',
      barLogs: false,
    );
  }

  // 2. App lock exists so somebody holding the phone cannot see the money, and
  // the home screen is visible BEFORE any unlock. A tile showing the number
  // would defeat it completely. Logging still works: the app opens, the lock
  // gate draws over it, and the sheet waits behind the fingerprint.
  if (appLock) {
    return tile(
      headline: 'Salapify',
      sub: 'App lock is on, so amounts stay hidden here.',
      bar: 'Log an expense',
      barLogs: true,
    );
  }

  final c = cycleStatus(data, ref);

  // 3. Numbers that cannot be read say so rather than being folded to zero.
  if (c.reason == 'nonfinite') {
    return tile(
      headline: 'Open Salapify',
      sub: 'Some of your saved numbers could not be read. Tap to check.',
      bar: 'Open Salapify',
      barLogs: false,
    );
  }

  // 4. Nothing logged and no accounts. There is no number that can go stale,
  // so no "as of" line either.
  if (c.reason == 'fresh') {
    return tile(
      headline: 'Start here',
      sub: 'Add your cash and log one expense. Your daily number appears here.',
      bar: 'Log an expense',
      barLogs: true,
    );
  }

  final payday = c.payday.isEmpty ? '' : _prettyDay(c.payday);

  // 5. Accounts exist but none of it is spendable cash.
  if (c.reason == 'quiet') {
    return tile(
      headline: 'No cash yet',
      sub: 'Update your cash and e-wallet balances to see your daily number.',
      bar: 'Log an expense',
      barLogs: true,
      asOf: true,
    );
  }

  // 6. There IS cash and the bills eat all of it. Deliberately names no peso
  // figure: Home already shows this state with its own numbers and its own
  // rounding, and a second, differently rounded number for the same fact is
  // the "two versions of one number" bug this codebase already fixed once.
  if (c.reason == 'committed') {
    return tile(
      headline: 'Bills first',
      sub: payday.isEmpty
          ? 'Everything you have is spoken for. Open Salapify for what to do.'
          : 'Everything you have is spoken for before $payday. Open Salapify '
                'for what to do.',
      bar: 'Log an expense',
      barLogs: true,
      asOf: true,
    );
  }

  final days = c.daysLeft;
  final dayWord = days == 1 ? 'day' : 'days';

  // 7. Hiding amounts must not leave a blank card. Days to payday is the other
  // half of the same question and is not a peso figure.
  if (hideAmounts) {
    return tile(
      headline: '$days $dayWord',
      sub: payday.isEmpty
          ? 'until your next payday. Amounts are hidden on this widget.'
          : 'to your $payday payday. Amounts are hidden on this widget.',
      bar: 'Log an expense',
      barLogs: true,
      asOf: true,
    );
  }

  // 8. The real thing.
  //
  // comeback, onTrack and easeOff are all available on CycleStatus and Home
  // uses them. This tile deliberately does not. Two rows hold two lines of
  // prose, the pace sentence alone is about ninety characters, and the
  // comeback greeting needs the warmth of the surrounding card to read as kind
  // rather than odd on a launcher. One wording means it can never drift into a
  // second variant of what Home says. Do not "improve" this by adding them.
  return tile(
    headline: formatMoneyText(c.perDay),
    sub: payday.isEmpty
        ? 'a day until your next payday, $days $dayWord away.'
        : 'a day until your $payday payday, $days $dayWord away.',
    bar: 'Log an expense',
    barLogs: true,
    asOf: true,
  );
}
