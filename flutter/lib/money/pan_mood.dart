// Pan's moods, in ONE place. Pan the cup and Pan the assistant are the same
// character, so the cup must show the same mood whether it came from the coach's
// ambient "DO NEXT" item on Home or from an Ask Pan chat reply. This maps both
// mood sources onto a single small set, so the two can never disagree.
//
// Pan invents no financial logic: it only reflects moods the app already
// produced (coach.dart kinds, respond.dart reply moods). This file is pure and
// has no Flutter or Rive dependency, so it is unit-testable and the mapping is
// locked by pan_mood_test.dart.

/// The cup's four moods, lowest to highest arousal. `input` is the number the
/// future Rive state machine will read (a single `mood` number input), kept
/// here so the mapping and the animation never drift apart.
enum PanMood {
  calm(0),
  nudge(1),
  worried(2),
  happy(3);

  const PanMood(this.input);
  final int input;
}

/// A coach "DO NEXT" kind (coach.dart) to a cup mood. This drives Pan's ambient
/// mood on Home, taken from the top check-in item.
///
/// worried  <- crunch, debtdue, overspend, payday, forecast (money at risk)
/// nudge    <- utang, hot, logtoday, buffer, goal, lesson    (a gentle to-do)
/// happy    <- good                                          (the all-clear)
/// calm     <- anything else / no pressing item              (resting default)
PanMood panMoodForCoachKind(String? kind) {
  switch (kind) {
    case 'crunch':
    case 'debtdue':
    case 'overspend':
    case 'payday':
    case 'forecast':
      return PanMood.worried;
    case 'utang':
    case 'hot':
    case 'logtoday':
    case 'buffer':
    case 'goal':
    case 'lesson':
      return PanMood.nudge;
    case 'good':
      return PanMood.happy;
    default:
      return PanMood.calm;
  }
}

/// An Ask Pan reply mood (respond.dart returns exactly 'worried' | 'happy' |
/// 'idle') to a cup mood. This drives Pan's live reaction in the chat. The chat
/// vocabulary has no separate "nudge", so its neutral 'idle' rests as calm and
/// its concern 'worried' matches the coach's worried, keeping the cup consistent
/// across both sources.
PanMood panMoodForReplyMood(String? mood) {
  switch (mood) {
    case 'worried':
      return PanMood.worried;
    case 'happy':
      return PanMood.happy;
    case 'idle':
    default:
      return PanMood.calm;
  }
}

/// How long Pan stays reacting to something the user just DID, before falling
/// back to the ambient mood the coach computes.
///
/// Short on purpose. A reaction that outstays the action stops being a
/// reaction and becomes a lie: Pan grinning about a log from ten minutes ago
/// while the coach is trying to say a bill is due reads as a bug, not warmth.
const Duration panReactionWindow = Duration(seconds: 6);

/// Pan's reaction to something the user just did, or null when there is
/// nothing recent enough to react to.
///
/// This exists because Pan reacted only to the ambient state: he mirrored the
/// coach's top item and was otherwise indifferent to the person using the app.
/// Logging an expense, the single most common thing anyone does here, changed
/// his face not at all. Reaction to ACTION is what makes a character feel
/// present; idle animation does not.
///
/// Pure and clock-injected so it is testable and cannot drift from the
/// ambient mapping above.
PanMood? panMoodForRecentAction(
  String? kind,
  DateTime? at,
  DateTime now,
) {
  if (kind == null || at == null) return null;
  final elapsed = now.difference(at);
  // A negative elapsed means the stamp is in the future, which happens when a
  // phone's clock jumps back. Treat it as stale rather than pinning Pan in a
  // reaction forever.
  if (elapsed.isNegative || elapsed > panReactionWindow) return null;
  switch (kind) {
    // The things worth a genuine smile: money kept, or a promise cleared.
    case 'goal':
    case 'debtpaid':
    case 'utangpaid':
      return PanMood.happy;
    // Logging is the habit the whole app rests on, so it is acknowledged
    // warmly every single time, never graded. Pan does not judge the amount.
    case 'log':
      return PanMood.happy;
    default:
      return null;
  }
}
