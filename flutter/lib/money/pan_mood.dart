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
