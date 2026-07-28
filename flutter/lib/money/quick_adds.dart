// The quick add button list: the presets on Budget that turn a repeat expense
// into one tap. Ported 1:1 from the addQuickAdd and removeQuickAdd functions
// inside mobile/app/preferences.js, and golden locked against output generated
// by executing those exact characters.
//
// One deliberate difference, and it is the whole reason this file exists
// rather than the logic sitting in a screen. RN's addQuickAdd returns silently
// on every invalid input: a typo in the amount, a duplicate label, an empty
// name, all produce nothing at all. The person taps Add and the row does not
// appear, with no explanation anywhere. Here the same rules produce the same
// list AND a sentence saying which rule was hit, the shape saveCategory
// already uses.
//
// The ACCEPTANCE rules are locked to RN exactly, because a preset that exists
// in one app and not the other is a button the person taps out of habit.

import 'transfers.dart' show jsNumber;

/// One preset: a name and the amount it logs.
class QuickAdd {
  final String label;
  final double amount;
  const QuickAdd(this.label, this.amount);

  Map<String, dynamic> toJson() => {'label': label, 'amount': amount};

  @override
  bool operator ==(Object other) =>
      other is QuickAdd && other.label == label && other.amount == amount;

  @override
  int get hashCode => Object.hash(label, amount);
}

/// The four the app ships with. Same list and same order as RN's
/// DEFAULT_QUICK_ADDS in mobile/lib/backup.js, so a person who used the old
/// app finds the same buttons in the same places.
const List<QuickAdd> defaultQuickAdds = [
  QuickAdd('Food', 150),
  QuickAdd('Transport', 50),
  QuickAdd('Coffee', 120),
  QuickAdd('Load', 100),
];

/// Read a stored quick add list, dropping anything unusable.
///
/// A negative or non finite amount is dropped rather than kept, because a
/// quick add whose amount is negative would log money BACK into the budget on
/// every tap, and nothing on the chip would say so.
List<QuickAdd> readQuickAdds(dynamic raw) {
  if (raw is! List) return const [];
  final out = <QuickAdd>[];
  for (final q in raw) {
    if (q is! Map) continue;
    final label = q['label'];
    final amount = q['amount'];
    if (label is! String || label.trim().isEmpty) continue;
    if (amount is! num || !amount.isFinite || amount <= 0) continue;
    out.add(QuickAdd(label, amount.toDouble()));
  }
  return out;
}

/// What an attempted add produced: either a new list, or the reason it was
/// refused. Exactly one of the two is set.
class QuickAddResult {
  final List<QuickAdd>? list;
  final String? error;
  const QuickAddResult.ok(this.list) : error = null;
  const QuickAddResult.refused(this.error) : list = null;
}

/// Append a preset, refusing the same inputs RN refuses.
///
/// The rules, all three of them RN's: the label must be something once
/// trimmed, the amount must be a finite number above zero, and the label must
/// not already be taken, compared case insensitively because the Budget screen
/// keys its chips by label.
QuickAddResult addQuickAdd(
  List<QuickAdd> current,
  String labelInput,
  String amountInput,
) {
  final label = labelInput.trim();
  // jsNumber, not double.tryParse: RN coerces with Number(), which accepts a
  // leading plus and 0x literals and rejects comma grouping. The goldens found
  // all four, and a preset that exists in one app and not the other is a
  // button someone taps out of habit and nothing happens.
  final amount = jsNumber(amountInput);

  if (label.isEmpty) return const QuickAddResult.refused('Give it a name.');
  // A cap, because this is now a first class place to TYPE a label rather
  // than something only a hand edited backup could carry. A long one clipped
  // the amount off the Budget chip entirely, so the button logged a figure
  // that was never on screen.
  if (label.length > 24) {
    return const QuickAddResult.refused(
      'Keep the name short, 24 letters or less, so the amount still fits.',
    );
  }
  // Commas get their own sentence. The app prints ₱1,500 on every screen, so
  // typing it back is the obvious thing to do, and "enter an amount above
  // zero" is a confusing answer to a number that plainly is above zero. The
  // log sheet already had this exact message; it was simply not reused.
  if (amountInput.contains(',')) {
    return const QuickAddResult.refused(
      'Use a period for centavos, like 2.50. Commas only group thousands.',
    );
  }
  // Below a centavo is not an amount, it is a typo. RN accepts it and then
  // draws the chip as "Kape ₱0" while every tap files a real 0.004 expense,
  // which is the silent-junk class this project keeps meeting. Recorded as a
  // deliberate divergence in the goldens rather than left to be discovered.
  if (!amount.isFinite || amount < 0.01) {
    return const QuickAddResult.refused(
      'Enter an amount of at least 0.01, like 150 or 13.50.',
    );
  }
  final taken = current.any(
    (q) => q.label.toLowerCase() == label.toLowerCase(),
  );
  if (taken) {
    return QuickAddResult.refused('You already have a button called $label.');
  }
  return QuickAddResult.ok([...current, QuickAdd(label, amount)]);
}

/// Drop the preset at [index]. An index that is not there leaves the list
/// alone, which is RN's behaviour and the safe one: a stale tap from a list
/// that just changed underneath must never remove the wrong button.
List<QuickAdd> removeQuickAdd(List<QuickAdd> current, int index) {
  if (index < 0 || index >= current.length) return List.of(current);
  return [
    for (var i = 0; i < current.length; i++)
      if (i != index) current[i],
  ];
}
