// Money mindset: a decision check for an impulse buy (the primary section),
// today's lesson below it (a doorway into the Learn track), and a running
// list of small wins. Wins are saved on the device in data.wins, which the
// backup already carries.
//
// The lesson card reads through content/lesson_model.dart's lessonFromMap,
// the same typed boundary learn.dart uses, instead of indexing the raw
// authoring map directly. The raw lessons never carried an 'emoji' field
// (they carry 'icon', a semantic name resolved by widgets/salapify_icon.dart)
// so reading lesson['emoji'] here printed the literal word "null" in front of
// every lesson title. Going through the typed lesson and its icon widget
// makes that class of bug impossible: a missing field falls back to '' (or
// the resolver's neutral marker for an unknown icon name), never to Dart's
// null string.

import 'package:flutter/material.dart';

import '../content/lesson_model.dart';
import '../content/lessons.dart';
import '../data/store.dart';
import '../money/bnpl.dart' show bnplCost;
import '../money/categories.dart'
    show CategoryRow, categoryTree, spentByCategory;
import '../money/commitmentload.dart' show commitmentLoad;
import '../money/currencies.dart' show baseCurrencySymbol;
import '../money/format.dart' show formatMoney;
import '../money/ledger.dart' show amountOf;
import '../money/mindset_decision.dart'
    show MindsetMode, mindsetBandLabel, mindsetComfortRange, mindsetDecision;
import '../money/mindset_purchase.dart'
    show goalTradeoff, subscriptionEquivalents;
import '../money/mindset_waiting.dart' show isDue, revisitLabel, waitingItems;
import '../money/mindset_wins.dart'
    show MindsetSnapshot, mindsetInsight, mindsetSnapshot;
import '../services/notifications.dart' show Reminders;
import '../theme.dart';
import '../typography.dart';
import '../widgets/mindset_spectrum_bar.dart';
import '../widgets/salapify_icon.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/segmented.dart';
import 'log_sheet.dart' show parseAmount;
import 'learn.dart';
import 'shell.dart';

// The decision-check questions, in the order the verdict logic below reads
// them.
const _questions = [
  'Is this essential right now?',
  'Can I afford it without using money reserved for bills, debt, or goals?',
  'Have I wanted it for at least 24 hours?',
];

/// The three deterministic outcomes of the decision check.
enum _Verdict { fitsPlan, pause24h, notInPlan }

/// Null until every question has an answer, so the screen shows a neutral
/// state rather than a verdict computed from partial information.
///
/// [impact] is only non-null when a valid amount, a selected category, and a
/// reliable monthly cap all line up (see _MindsetScreenState._budgetImpact).
/// When it shows the purchase would exceed that category's budget, it
/// overrides whatever the three questions would otherwise land on: reliable
/// numbers outrank a self-report, the same way an unaffordable answer
/// already does below.
_Verdict? _computeVerdict(List<bool?> answers, Map<String, dynamic>? impact) {
  if (answers.any((a) => a == null)) return null;
  final essential = answers[0]!;
  final affordableWithoutReserved = answers[1]!;
  final waited24h = answers[2]!;
  // Touching money reserved for bills, debt, or goals rules it out on its
  // own, essential or not: the plan already promised that money elsewhere.
  if (!affordableWithoutReserved) return _Verdict.notInPlan;
  if (impact != null && impact['exceeds'] == true) return _Verdict.notInPlan;
  if (!essential && !waited24h) return _Verdict.pause24h;
  return _Verdict.fitsPlan;
}

/// A number-typed string for a controller: a whole number prints without a
/// trailing ".0", a fractional one keeps its decimals. Used both to prefill
/// Small Wins from a waiting item's amount and to seed the edit sheet's own
/// amount field.
String _amountControllerText(num amount) => amount == amount.roundToDouble()
    ? amount.toInt().toString()
    : amount.toString();

/// The stable string a completed check's verdict is logged under
/// (settings.mindsetChecks, see the store), matching the 'result' string
/// addMindsetWaitingItem already writes for its own pause24h saves.
String _verdictKey(_Verdict v) => switch (v) {
  _Verdict.fitsPlan => 'fitsPlan',
  _Verdict.pause24h => 'pause24h',
  _Verdict.notInPlan => 'notInPlan',
};

/// The verdict word, its color, and a non-chromatic severity icon. Mirrors
/// the shape of AffordCard's _verdictHead in afford_card.dart.
(String, Color, IconData) _verdictHead(_Verdict v) => switch (v) {
  _Verdict.fitsPlan => ('Fits your plan', Barako.primary, salapifyIcon('done')),
  _Verdict.pause24h => (
    'Pause for 24 hours',
    Barako.warning,
    salapifyIcon('paused'),
  ),
  _Verdict.notInPlan => (
    'Not in the plan right now',
    Barako.warningStrong,
    salapifyIcon('blocked'),
  ),
};

/// A one-sentence reason, built from the actual answers rather than a fixed
/// string per verdict, so it stays honest about which answer decided it.
/// [impact] folds the budget numbers into the sentence whenever they are the
/// reason (or part of it) behind a notInPlan verdict, per the founder's
/// result-integration rule: the budget impact belongs in this text, not just
/// in the card above it.
///
/// [subscriptionInfo], [creditInfo], [commitmentInfo], and [goalInfo] add
/// zero or more trailing sentences describing the purchase-type and
/// goal-tradeoff context (Money Mindset Phase 5). They never change which
/// verdict was reached, only what the sentence explains about it: per the
/// founder's rule, selecting Credit or BNPL must never automatically turn a
/// result negative on its own.
String _whyText(
  _Verdict v,
  List<bool?> answers,
  Map<String, dynamic>? impact, {
  required String purchaseType,
  Map<String, dynamic>? subscriptionInfo,
  Map<String, dynamic>? creditInfo,
  Map<String, dynamic>? commitmentInfo,
  Map<String, dynamic>? goalInfo,
}) {
  final essential = answers[0]!;
  final waited24h = answers[2]!;
  final affordableWithoutReserved = answers[1]!;
  final overBudget = impact != null && impact['exceeds'] == true;
  final String base;
  switch (v) {
    case _Verdict.notInPlan:
      if (!affordableWithoutReserved) {
        base = overBudget
            ? 'It would use money already reserved for bills, debt, or '
                  'goals, and ${_budgetClause(impact)}'
            : 'It would use money already reserved for bills, debt, or goals.';
      } else if (impact == null) {
        // _computeVerdict only reaches notInPlan with
        // affordableWithoutReserved true when the budget check is what
        // pushed it there, so impact is never null here in practice.
        // assert() is stripped in release builds though, so this stays a
        // null check with a safe fallback sentence rather than an operator
        // that would crash in production if that invariant were ever broken
        // by a future edit to _computeVerdict.
        base = 'This does not fit your plan right now.';
      } else {
        base = 'The other answers fit your plan, but ${_budgetClause(impact)}';
      }
    case _Verdict.pause24h:
      base =
          "It is not essential right now, and you have not wanted it for "
          "a full 24 hours yet.";
    case _Verdict.fitsPlan:
      if (essential) {
        base =
            'It is essential, and it will not touch money reserved for '
            'bills, debt, or goals.';
      } else {
        // _computeVerdict only reaches fitsPlan with essential == false when
        // waited24h == true; otherwise it would have returned pause24h.
        assert(waited24h);
        base =
            'It is not essential, but you have wanted it for at least 24 '
            'hours and it will not touch your reserved money.';
      }
  }
  final extras = _purchaseContextSentences(
    purchaseType: purchaseType,
    subscriptionInfo: subscriptionInfo,
    creditInfo: creditInfo,
    commitmentInfo: commitmentInfo,
    goalInfo: goalInfo,
  );
  return extras.isEmpty ? base : '$base ${extras.join(' ')}';
}

/// The subscription, credit, and goal-tradeoff sentences _whyText appends,
/// split out so it stays readable. Each sentence only appears when its own
/// data is actually reliable (a parsed subscription amount, a complete
/// credit plan, existing debt minimums, or a goal comparison), the same
/// "explainable or absent" rule goal_plan.dart's own suggestions follow.
List<String> _purchaseContextSentences({
  required String purchaseType,
  Map<String, dynamic>? subscriptionInfo,
  Map<String, dynamic>? creditInfo,
  Map<String, dynamic>? commitmentInfo,
  Map<String, dynamic>? goalInfo,
}) {
  final extras = <String>[];
  if (purchaseType == 'subscription' && subscriptionInfo != null) {
    extras.add(
      'This subscription runs about '
      '${formatMoney(subscriptionInfo['monthly'] as double)} a month, '
      '${formatMoney(subscriptionInfo['annual'] as double)} a year.',
    );
  }
  if (purchaseType == 'credit' && creditInfo != null) {
    final cash = creditInfo['cash'] as double;
    final totalPaid = creditInfo['totalPaid'] as double;
    final extraCost = creditInfo['extraCost'] as double;
    extras.add(
      creditInfo['trulyFree'] == true
          ? 'Paying this way costs nothing extra: ${formatMoney(totalPaid)} '
                'total, the same as the ${formatMoney(cash)} cash price.'
          : 'Paying this way costs ${formatMoney(extraCost)} more than the '
                '${formatMoney(cash)} cash price, ${formatMoney(totalPaid)} '
                'in total.',
    );
    if (commitmentInfo != null &&
        commitmentInfo['applicable'] == true &&
        (commitmentInfo['minimumsCount'] as int) > 0) {
      extras.add(
        'You already commit about '
        '${formatMoney(commitmentInfo['minimumsTotal'] as double)} a month '
        'to other debt minimums.',
      );
    }
  }
  if (goalInfo != null) {
    final pct = goalInfo['percentOfRemaining'] as double;
    final name = goalInfo['goalName'] as String;
    final sentence = StringBuffer(
      pct >= 100
          ? 'This is more than what is left on "$name".'
          : 'This is about ${pct.round()}% of what is left on "$name".',
    );
    final delay = goalInfo['delay'] as Map<String, dynamic>?;
    if (delay != null) {
      final periods = delay['periods'] as int;
      sentence.write(
        ' At your current pace, it could push that goal about $periods '
        '${_periodWord(delay['frequency'] as String, periods)} later.',
      );
    }
    extras.add(sentence.toString());
  }
  return extras;
}

/// "week"/"weeks" or "month"/"month" for a goal delay estimate's frequency
/// and count.
String _periodWord(String frequency, int count) {
  final unit = frequency == 'weekly' ? 'week' : 'month';
  return count == 1 ? unit : '${unit}s';
}

/// The lower-case clause describing exactly how far over the category's cap
/// this purchase would push it. Only ever called with an [impact] whose
/// 'exceeds' is true.
String _budgetClause(Map<String, dynamic> impact) {
  final categoryName = impact['categoryName'] as String;
  final over = (impact['remainingAfter'] as double).abs();
  final cap = impact['cap'] as double;
  return 'it would take the $categoryName budget ${formatMoney(over)} over '
      'its ${formatMoney(cap)} monthly cap.';
}

/// Never blank, never the literal word "null": a missing lesson field falls
/// back to this instead.
String _safe(String value, String fallback) =>
    value.trim().isEmpty ? fallback : value;

const _lessonTitleFallback = "Today's lesson";
const _lessonSummaryFallback = 'Check back soon for a new tip.';

String _lessonTitleOf(MoneyLesson lesson) =>
    _safe(lesson.title, _lessonTitleFallback);
String _lessonSummaryOf(MoneyLesson lesson) =>
    _safe(lesson.summary, _lessonSummaryFallback);

/// The exact title and summary the lesson card renders for a raw authoring
/// map, fallbacks included: build() below calls the same two functions
/// above, just already holding the converted MoneyLesson. Exposed only so a
/// lesson with a missing title or summary can be proven safe directly,
/// without waiting for the day-of-year rotation in lessonOfTheDay to land on
/// a broken real entry (today's real content never is one; this is what
/// stops a future one from reprinting the "null" bug this screen shipped
/// with).
@visibleForTesting
String mindsetLessonTitle(Map<String, dynamic> rawLesson) =>
    _lessonTitleOf(lessonFromMap(rawLesson));

@visibleForTesting
String mindsetLessonSummary(Map<String, dynamic> rawLesson) =>
    _lessonSummaryOf(lessonFromMap(rawLesson));

/// Whether a raw lesson map should carry the "For freelancers" label on this
/// screen's Today's lesson card. A missing or non-bool 'forFreelancers' key
/// safely reads as false (lessonFromMap's own === true check), the same
/// "never guess, default to the safe reading" contract every other optional
/// field on this screen follows.
@visibleForTesting
bool mindsetLessonForFreelancers(Map<String, dynamic> rawLesson) =>
    lessonFromMap(rawLesson).forFreelancers;

class MindsetScreen extends StatefulWidget {
  /// Threaded through to Money courses so lesson actions that jump to a
  /// bottom tab keep working when courses are opened from here.
  final void Function(Destination)? onSwitchTab;
  final SalapifyStore store;
  const MindsetScreen({super.key, required this.store, this.onSwitchTab});

  @override
  State<MindsetScreen> createState() => _MindsetScreenState();
}

class _MindsetScreenState extends State<MindsetScreen> {
  final List<bool?> _answers = List<bool?>.filled(_questions.length, null);
  final _winText = TextEditingController();
  final _winAmountText = TextEditingController();
  final _winNoteText = TextEditingController();
  // Collapsed by default so the plain text-and-Add flow (manual entry) reads
  // exactly as it always has; a person who wants to record an amount or a
  // reflection opts into the extra fields instead of always seeing them.
  bool _winDetailsExpanded = false;
  // Guards Add the same way _savingToWaiting guards Revisit in 24 hours: the
  // button stays disabled until the write settles, so a fast double tap
  // cannot fire addWin twice before the first call's write has landed (the
  // store's own duplicate guard is the real backstop; this just avoids
  // queuing a second write that the store would then have to catch).
  bool _addingWin = false;
  // True once THIS considering session has already logged a completed
  // decision check, so flipping an answer back and forth after all three are
  // answered logs the check once, not once per flip. Reset by _clearCheck
  // and by _reviewAgain, the two places the three answers go blank again.
  bool _checkLogged = false;
  // "Review again" (from the Waiting section, which sits below the fold)
  // refills the considering fields, but a person who scrolled down to open
  // the prompt would otherwise see no visible change: the viewport stays
  // wherever it was, on the now-empty Waiting card, with only a snackbar to
  // notice. Scrolled back to the top so the refilled section is on screen.
  final _listController = ScrollController();

  // "What are you considering?": all three are optional context for the
  // decision check, never a transaction. Nothing here is saved; it lives only
  // in this screen's state and is gone the moment the screen closes or Clear
  // check is tapped.
  final _itemName = TextEditingController();
  final _amountText = TextEditingController();
  String? _categoryId;

  // Money Mindset Phase 5: which shape of purchase the fields below collect.
  // 'oneTime' is the original Phase 2 flow above, untouched by default.
  // Switching types never clears what was typed in another type's fields;
  // only the active type's fields feed the verdict and the cards below.
  String _purchaseType = 'oneTime';

  // The what-if slider's explored amount, and the entered amount it was based
  // on. When the entered amount changes, the explored value falls back to it
  // (checked in build, never a setState there). Only the one-time flow shows it.
  double? _whatIf;
  double? _whatIfBase;
  // The comfort spectrum (band ceilings), memoised by a store-money signature so
  // dragging the slider never re-runs the binary search over the ledger.
  Map<String, double>? _spectrum;
  String? _spectrumKey;
  double? _spectrumSearchMax;

  // Subscription fields: a recurring amount and how often it bills.
  final _subAmountText = TextEditingController();
  String _subFrequency = 'monthly';

  // Credit or BNPL fields, mirroring bnplCost's own inputs (bnpl.dart) so the
  // true-cost engine already used elsewhere in the app (afford_card.dart)
  // powers this card too, rather than a second copy of that math.
  final _creditCashText = TextEditingController();
  final _creditDownText = TextEditingController();
  final _creditInstallmentText = TextEditingController();
  final _creditInstallmentsCountText = TextEditingController();
  final _creditFeesText = TextEditingController();

  // Goal trade-off: which existing goal, if any, to compare this purchase
  // against. Read-only, like everything else on this screen: nothing here
  // ever writes to goals.dart's own saved/target fields.
  String? _goalId;

  // A ceiling past which a typed amount stops meaning anything for a
  // purchase estimate, the same guard afford_card.dart uses for its own
  // display math, so a pasted absurd number reads as an error instead of
  // silently producing a nonsense budget comparison.
  static const double _amountCeiling = 1e12;

  void _clearCheck() {
    setState(() {
      for (var i = 0; i < _answers.length; i++) {
        _answers[i] = null;
      }
      _itemName.clear();
      _amountText.clear();
      _categoryId = null;
      _purchaseType = 'oneTime';
      _subAmountText.clear();
      _subFrequency = 'monthly';
      _creditCashText.clear();
      _creditDownText.clear();
      _creditInstallmentText.clear();
      _creditInstallmentsCountText.clear();
      _creditFeesText.clear();
      _goalId = null;
      _checkLogged = false;
      _whatIf = null;
      _whatIfBase = null;
    });
    // Same reasoning as _reviewAgain's own scroll-to-top: Clear check sits
    // near the bottom of the Impulse check card, so whatever scrolled it
    // into view (ensureVisible, or a long card above a taller screen) can
    // leave the just-reset neutral state sitting above the fold with
    // nothing on screen to show anything changed.
    _scrollToTop();
  }

  /// Jumps the list back to the top, honoring reduce-motion the same way
  /// Segmented and PressableScale do: the setting means no animation, not a
  /// shorter one. Shared by _clearCheck and _reviewAgain, the two places that
  /// need the person to actually see the section they just refilled.
  void _scrollToTop() {
    if (!_listController.hasClients) return;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _listController.jumpTo(0);
    } else {
      _listController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _winText.dispose();
    _winAmountText.dispose();
    _winNoteText.dispose();
    _itemName.dispose();
    _amountText.dispose();
    _subAmountText.dispose();
    _creditCashText.dispose();
    _creditDownText.dispose();
    _creditInstallmentText.dispose();
    _creditInstallmentsCountText.dispose();
    _creditFeesText.dispose();
    _listController.dispose();
    super.dispose();
  }

  /// The typed amount, or null when the field is blank, negative, zero,
  /// unparsable, or past the ceiling above. parseAmount (log_sheet.dart)
  /// already rejects blank, negative, zero, and non-numeric text; the
  /// ceiling check here is the only thing it does not cover.
  double? get _validAmount {
    final v = parseAmount(_amountText.text);
    if (v == null || v > _amountCeiling) return null;
    return v;
  }

  // A bare trailing decimal point ("150.") is still on the way to a valid
  // number, not yet invalid. A first version of this getter flagged it the
  // instant "." was typed and cleared the instant the next digit landed, a
  // flicker on completely ordinary decimal entry. A second version tried to
  // fix that by gating the whole getter on the field's FocusNode instead,
  // which broke worse: nothing on this screen ever explicitly unfocuses the
  // amount field when a category chip or a Yes/No answer is tapped, so the
  // error could stay invisible forever even on a genuinely invalid amount,
  // and the flutter_test focus-settling timing around that made the whole
  // suite flaky (green or red on the identical commit). This version fixes
  // only the actual complaint, the trailing-dot case, and stays a pure
  // function of the typed text: no focus, no timing, nothing to flake.
  static final _midDecimalEntry = RegExp(r'^\d+\.$');

  /// A validation message for the amount field, or null when it is empty (a
  /// legitimate "not answering this" state, not an error), still mid-way
  /// through typing a decimal, or holds a usable number.
  String? get _amountError {
    final text = _amountText.text.trim();
    if (text.isEmpty || _midDecimalEntry.hasMatch(text)) return null;
    final v = parseAmount(text);
    if (v == null) return 'Enter a valid amount.';
    if (v > _amountCeiling) return 'That amount is too large to check.';
    return null;
  }

  /// The same "empty is fine, junk is not, absurd is not" contract as
  /// [_validAmount], reused for every subscription and credit field below
  /// instead of five near-identical copies. Empty and blank are both valid
  /// "not answering this yet" states here, same as [_amountError]'s own
  /// empty case.
  double? _numericFieldValue(String text) {
    final v = parseAmount(text);
    if (v == null || v > _amountCeiling) return null;
    return v;
  }

  String? _numericFieldError(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _midDecimalEntry.hasMatch(trimmed)) return null;
    final v = parseAmount(trimmed);
    if (v == null) return 'Enter a valid amount.';
    if (v > _amountCeiling) return 'That amount is too large to check.';
    return null;
  }

  /// The recurring amount and frequency turned into a monthly and annual
  /// size, or null until a usable amount is typed. Purely a display and
  /// budget-impact input; never saved anywhere.
  Map<String, double>? get _subscriptionSummary {
    final amount = _numericFieldValue(_subAmountText.text);
    if (amount == null || amount <= 0) return null;
    return subscriptionEquivalents(amount, _subFrequency);
  }

  /// The full BNPL/credit read, or null until cash price, installment
  /// amount, and number of installments are all present and valid: the same
  /// "every input needed for a trustworthy comparison" gate _budgetImpact
  /// already applies to the one-time budget check. Down payment and fees
  /// default to zero (both are genuinely optional, per the founder's spec),
  /// covering the zero-interest and no-fee cases without a separate branch.
  Map<String, dynamic>? get _creditSummary {
    final cash = _numericFieldValue(_creditCashText.text);
    final installment = _numericFieldValue(_creditInstallmentText.text);
    final installments = _numericFieldValue(_creditInstallmentsCountText.text);
    if (cash == null ||
        cash <= 0 ||
        installment == null ||
        installment <= 0 ||
        installments == null ||
        installments <= 0) {
      return null;
    }
    final down = _numericFieldValue(_creditDownText.text) ?? 0;
    final fees = _numericFieldValue(_creditFeesText.text) ?? 0;
    return bnplCost({
      'cashPrice': cash,
      'downpayment': down,
      'months': installments,
      'monthlyPayment': installment,
      'upfrontFee': fees,
    });
  }

  /// The amount this purchase would put at risk right now, by purchase
  /// type: the typed one-time amount, a subscription's monthly bite, or a
  /// BNPL plan's own installment (never its total repayment, so the
  /// affordability self-report stays about the recurring commitment, the
  /// same "never focus only on the small installment amount" rule the
  /// screen's copy also follows for the totals shown separately).
  double? get _effectiveAmount => switch (_purchaseType) {
    'subscription' => _subscriptionSummary?['monthly'],
    'credit' => _creditSummary?['monthly'] as double?,
    _ => _validAmount,
  };

  /// The amount to weigh against a chosen savings goal: a one-time price,
  /// what a subscription would cost across a year (the goal comparison is a
  /// lump-sum question, unlike the monthly budget check above), or a BNPL
  /// plan's real total repayment, never just its installment, so the goal
  /// trade-off never understates what the plan actually costs.
  double? get _goalTradeoffAmount => switch (_purchaseType) {
    'subscription' => _subscriptionSummary?['annual'],
    'credit' => _creditSummary?['totalPaid'] as double?,
    _ => _validAmount,
  };

  List<Map<String, dynamic>> _categories() => [
    for (final c in (widget.store.data['categories'] as List? ?? const []))
      if (c is Map) c.cast<String, dynamic>(),
  ];

  List<Map<String, dynamic>> _goals() => [
    for (final g in (widget.store.data['goals'] as List? ?? const []))
      if (g is Map) g.cast<String, dynamic>(),
  ];

  Map<String, dynamic>? _selectedGoal(List<Map<String, dynamic>> goals) {
    final id = _goalId;
    if (id == null) return null;
    for (final g in goals) {
      if ('${g['id']}' == id) return g;
    }
    return null;
  }

  /// Only non-null when every input needed for a trustworthy comparison is
  /// actually present: a usable amount, a category the user picked, Pro
  /// (monthly caps are a Pro-only field, see categories.dart), that category
  /// still existing, and a cap it actually set. Any missing piece means no
  /// claim is made about affordability, per the founder's rule: never guess.
  ///
  /// This deliberately does NOT reach into account balances or payday
  /// history (afford.dart's territory) even though it would be easy to bolt
  /// on here; a balance is not disposable money and mixing the two engines
  /// would misrepresent both.
  ///
  /// Credit or BNPL purchases skip this entirely: Phase 5 shows their own
  /// total-repayment and existing-commitments cards instead, and comparing a
  /// single installment against a monthly category cap the same way a
  /// one-time purchase or a subscription's monthly bite does would read as
  /// a claim this screen never actually checked (a BNPL plan's real cost is
  /// the total repayment, not the installment alone).
  Map<String, dynamic>? _budgetImpact(List<Map<String, dynamic>> categories) {
    if (_purchaseType == 'credit') return null;
    final categoryId = _categoryId;
    if (categoryId == null) return null;
    final amount = _effectiveAmount;
    if (amount == null) return null;
    final pro = (widget.store.data['settings'] as Map?)?['pro'] == true;
    if (!pro) return null;
    Map<String, dynamic>? cat;
    for (final c in categories) {
      if ('${c['id']}' == categoryId) {
        cat = c;
        break;
      }
    }
    if (cat == null) return null;
    final cap = amountOf(cat['monthlyCap']);
    if (cap <= 0) return null;
    final spent =
        spentByCategory(
          widget.store.data['transactions'],
          categories,
          DateTime.now(),
        )[categoryId] ??
        0.0;
    final remainingBefore = cap - spent;
    final remainingAfter = remainingBefore - amount;
    return {
      'categoryName': '${cat['name'] ?? 'Category'}',
      'cap': cap,
      'spent': spent,
      'amount': amount,
      'remainingBefore': remainingBefore,
      'remainingAfter': remainingAfter,
      'exceeds': remainingAfter < 0,
    };
  }

  /// A typed amount that does not parse blocks the whole submission rather
  /// than being silently dropped, the same "do not guess" rule the
  /// considering amount field follows; a blank amount field is simply
  /// optional, not an error.
  String? get _winAmountError {
    final text = _winAmountText.text.trim();
    if (text.isEmpty) return null;
    return parseAmount(text) == null ? 'Enter a valid amount.' : null;
  }

  Future<void> _addWin() async {
    if (_addingWin) return;
    final text = _winText.text.trim();
    if (text.isEmpty) return;
    // If saving is off (a prior load failed), keep the typed win in the box
    // rather than silently eating it, and never write over data we could not
    // read.
    if (!widget.store.canWrite) return;
    final amountText = _winAmountText.text.trim();
    double? amount;
    if (amountText.isNotEmpty) {
      amount = parseAmount(amountText);
      if (amount == null) return; // _winAmountError already flags this
    }
    final note = _winNoteText.text.trim();
    setState(() => _addingWin = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.store.addWin(
        text,
        amount: amount,
        note: note.isEmpty ? null : note,
      );
    } catch (e) {
      if (mounted) setState(() => _addingWin = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save that, nothing changed. $e')),
      );
      return;
    }
    if (!mounted) return;
    _winText.clear();
    _winAmountText.clear();
    _winNoteText.clear();
    setState(() {
      _addingWin = false;
      _winDetailsExpanded = false;
    });
    FocusScope.of(context).unfocus();
  }

  List<Map<String, dynamic>> _wins() {
    final raw = widget.store.data['wins'];
    return [
      for (final w in (raw is List ? raw : const []))
        if (w is Map) w.cast<String, dynamic>(),
    ];
  }

  void _deleteWin(Map<String, dynamic> w) {
    // A win imported from a hand-edited backup can lack a string id (sanitize
    // keeps wins verbatim), so read it defensively: the delete no-ops instead
    // of crashing, matching the RN screen.
    final id = w['id'];
    if (id is! String || !widget.store.canWrite) return;
    widget.store.deleteWin(id);
    // A win is user-recorded content, so offer a one tap undo rather than
    // losing it silently on a stray tap. Restored verbatim (id, date, amount,
    // note included) through restoreWinRow rather than re-added through
    // addWin, which would mint a fresh id and drop the amount and note.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Win removed'),
          duration: const Duration(seconds: 5),
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (widget.store.canWrite) widget.store.restoreWinRow(w);
            },
          ),
        ),
      );
  }

  /// "Delete" inside the edit sheet: a deliberate, out-of-context destructive
  /// action (unlike the row's own quick delete-with-undo icon, which is
  /// already a single unambiguous tap), so it gets a real confirm dialog,
  /// the same pattern notes.dart's editor uses for "Delete this note?".
  Future<void> _confirmDeleteWin(String id, Map<String, dynamic> win) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text('Delete this win?', style: TextStyle(color: Barako.text)),
        content: Text(
          'This removes it from your Small Wins list.',
          style: TextStyle(color: Barako.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: Barako.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: Barako.warningStrong),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !widget.store.canWrite) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.store.deleteWin(id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete, nothing was changed. $e')),
      );
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Win removed'),
          duration: const Duration(seconds: 5),
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (widget.store.canWrite) widget.store.restoreWinRow(win);
            },
          ),
        ),
      );
  }

  /// Edit an existing win's text, amount, and note in a bottom sheet, the
  /// same interaction pattern _openRevisitPrompt already uses on this
  /// screen. A win with no id (a hand-edited backup, sanitize keeps wins
  /// verbatim) cannot be targeted, so this no-ops rather than throwing,
  /// matching _deleteWin's own guard. The sheet's own fields are owned by
  /// _EditWinSheet (a real State with a real dispose()), not created loose in
  /// this closure: three TextEditingControllers created here and handed to a
  /// stateless builder would never be disposed once the sheet closes, the
  /// same leak every other form sheet in this app (DebtFormSheet and
  /// siblings) avoids by being its own StatefulWidget.
  void _openEditWinSheet(Map<String, dynamic> w) {
    final id = w['id'];
    if (id is! String || !widget.store.canWrite) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EditWinSheet(
        win: w,
        onSave: (text, amount, note) async {
          try {
            await widget.store.editWin(
              id,
              text: text,
              amount: amount,
              note: note,
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not save that, nothing changed. $e'),
              ),
            );
          }
        },
        onDelete: () => _confirmDeleteWin(id, w),
      ),
    );
  }

  // Never blank in a Waiting row, a notification body, or a restored check:
  // the item name is optional to type, so this is what stands in for it.
  static const _untitledWaitingItem = "Something you're considering";

  String _waitingDisplayName(Map<String, dynamic> item) {
    final name = item['itemName'];
    return (name is String && name.trim().isNotEmpty)
        ? name.trim()
        : _untitledWaitingItem;
  }

  // Reschedule is guarded and swallows its own failures (see
  // services/notifications.dart), so every waiting-list write follows it with
  // a best-effort call rather than waiting for the next app resume to notice
  // an item that changed or disappeared.
  // Guards _saveToWaiting the same way every other save action in this app
  // guards itself (payday.dart, recurring.dart, paluwagan.dart, treats.dart):
  // the button stays enabled until this flips true, so a fast double tap
  // fired _saveToWaiting twice on identical answers and produced two waiting
  // items with two independently scheduled reminders.
  bool _savingToWaiting = false;

  Future<void> _saveToWaiting() async {
    if (!widget.store.canWrite || _savingToWaiting) return;
    if (_answers.any((a) => a == null)) return; // pause24h implies all answered
    setState(() => _savingToWaiting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.store.addMindsetWaitingItem(
        itemName: _itemName.text.trim().isEmpty
            ? _untitledWaitingItem
            : _itemName.text.trim(),
        // The effective amount for whichever purchase type is active, so a
        // subscription or BNPL item revisited from Waiting still recalls the
        // figure its own decision check actually weighed.
        amount: _effectiveAmount,
        categoryId: _categoryId,
        essential: _answers[0]!,
        affordableWithoutReserved: _answers[1]!,
        waited24h: _answers[2]!,
        result: 'pause24h',
      );
    } catch (e) {
      if (mounted) setState(() => _savingToWaiting = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save that, nothing changed. $e')),
      );
      return;
    }
    await Reminders.reschedule(widget.store.data, DateTime.now());
    if (!mounted) return;
    setState(() => _savingToWaiting = false);
    _clearCheck();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          "Saved to Waiting. We'll check back with you in 24 hours.",
        ),
      ),
    );
  }

  // Awaits the patch before rescheduling, unlike an earlier version of this
  // function: _mutate queues writes on _writes.then(...), and .then() always
  // defers to a microtask even on an already-completed Future, so calling
  // Reminders.reschedule on the very next line (no await in between) read
  // widget.store.data from BEFORE the status flip landed. The reschedule
  // wipes and rebuilds the whole notification schedule from whatever data it
  // is handed, so Cancel silently failed to cancel the item's own reminder;
  // it kept firing until the next unrelated reschedule happened to run.
  Future<void> _cancelWaitingItem(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id is! String || !widget.store.canWrite) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.store.patchMindsetWaitingItem(id, {'status': 'dismissed'});
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save that, nothing changed. $e')),
      );
      return;
    }
    await Reminders.reschedule(widget.store.data, DateTime.now());
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Removed from Waiting'),
          duration: const Duration(seconds: 5),
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              if (!widget.store.canWrite) return;
              try {
                await widget.store.patchMindsetWaitingItem(id, {
                  'status': 'waiting',
                });
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Could not undo, nothing was restored. $e'),
                  ),
                );
                return;
              }
              await Reminders.reschedule(widget.store.data, DateTime.now());
            },
          ),
        ),
      );
  }

  // A confirm step for the one real way this screen can lose typed-but-not-
  // saved work: a DIFFERENT waiting item comes due while the person still
  // has their own in-progress considering fields or win text sitting
  // unsaved, and reviewing or skipping that item would silently overwrite
  // it. Nothing persisted is ever at risk (the store never held that text),
  // but a silent overwrite of what somebody just typed is still a real loss.
  Future<bool> _confirmOverwrite(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text(
          'Replace what you have?',
          style: TextStyle(color: Barako.text),
        ),
        content: Text(message, style: TextStyle(color: Barako.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: Barako.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Replace',
              style: TextStyle(color: Barako.warningStrong),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // "Review again": restores the item into the decision tool. Only the
  // considering fields come back; the three answers are cleared so the
  // person actually re-answers rather than inheriting a stale "have I
  // wanted it 24 hours" from before the 24 hours were even up.
  Future<void> _reviewAgain(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id is! String || !widget.store.canWrite) return;
    final hasUnsavedConsidering =
        _itemName.text.trim().isNotEmpty ||
        _amountText.text.trim().isNotEmpty ||
        _categoryId != null ||
        _purchaseType != 'oneTime' ||
        _subAmountText.text.trim().isNotEmpty ||
        _creditCashText.text.trim().isNotEmpty ||
        _creditDownText.text.trim().isNotEmpty ||
        _creditInstallmentText.text.trim().isNotEmpty ||
        _creditInstallmentsCountText.text.trim().isNotEmpty ||
        _creditFeesText.text.trim().isNotEmpty ||
        _goalId != null ||
        _answers.any((a) => a != null);
    if (hasUnsavedConsidering &&
        !await _confirmOverwrite(
          "This replaces what you're currently checking above with this "
          "waiting item. Nothing you already typed there is saved.",
        )) {
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.store.patchMindsetWaitingItem(id, {'status': 'reviewed'});
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save that, nothing changed. $e')),
      );
      return;
    }
    await Reminders.reschedule(widget.store.data, DateTime.now());
    if (!mounted) return;
    final name = item['itemName'];
    final amount = item['amount'];
    final categoryId = item['categoryId'];
    setState(() {
      _itemName.text = (name is String && name.trim().isNotEmpty) ? name : '';
      _amountText.text = amount is num
          ? (amount == amount.roundToDouble()
                ? amount.toInt().toString()
                : amount.toString())
          : '';
      _categoryId = categoryId is String && categoryId.isNotEmpty
          ? categoryId
          : null;
      // A waiting item only ever remembers a one-time-shaped amount and
      // category (addMindsetWaitingItem's own fields), so a review always
      // comes back into the one-time flow; whatever a subscription or
      // credit section held is cleared with it, the same clean-slate
      // contract Clear check gives those fields.
      _purchaseType = 'oneTime';
      _subAmountText.clear();
      _subFrequency = 'monthly';
      _creditCashText.clear();
      _creditDownText.clear();
      _creditInstallmentText.clear();
      _creditInstallmentsCountText.clear();
      _creditFeesText.clear();
      _goalId = null;
      for (var i = 0; i < _answers.length; i++) {
        _answers[i] = null;
      }
      // Without this, re-answering all three questions in this new
      // considering session would never log a fresh completed check:
      // _checkLogged would still be true from whatever check this screen
      // last completed, so the postFrameCallback's guard would silently
      // skip it.
      _checkLogged = false;
      _whatIf = null;
      _whatIfBase = null;
    });
    // Back to the top: the WAITING card the person just tapped from is below
    // the fold, and it is about to lose this row entirely (status is no
    // longer 'waiting'), so without this the refilled considering section
    // sits off screen with nothing but a snackbar to say anything happened.
    _scrollToTop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Brought back. Answer the three questions again.'),
      ),
    );
  }

  // "Skip it": can prefill Small Wins, deliberately never auto-saves it. The
  // person still taps Add themselves, the same as typing a win by hand.
  Future<void> _skipItem(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id is! String || !widget.store.canWrite) return;
    if (_winText.text.trim().isNotEmpty &&
        !await _confirmOverwrite(
          'This replaces the win you were typing below.',
        )) {
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.store.patchMindsetWaitingItem(id, {'status': 'skipped'});
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save that, nothing changed. $e')),
      );
      return;
    }
    await Reminders.reschedule(widget.store.data, DateTime.now());
    if (!mounted) return;
    setState(() {
      _winText.text = 'Skipped ${_waitingDisplayName(item)}';
      _prefillWinAmount(item);
    });
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Skipped. Log it as a win below if you would like.'),
      ),
    );
  }

  /// Fills the optional amount field (and opens the details panel to show
  /// it) from a waiting item's own estimated amount, when it had one.
  /// Called with setState already in progress by the caller.
  void _prefillWinAmount(Map<String, dynamic> item) {
    final amount = item['amount'];
    if (amount is num) {
      _winAmountText.text = _amountControllerText(amount);
      _winDetailsExpanded = true;
    }
  }

  Future<void> _waitAnotherDay(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id is! String || !widget.store.canWrite) return;
    final messenger = ScaffoldMessenger.of(context);
    final next = DateTime.now().add(const Duration(hours: 24));
    try {
      await widget.store.patchMindsetWaitingItem(id, {
        'revisitAt': next.toIso8601String(),
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save that, nothing changed. $e')),
      );
      return;
    }
    await Reminders.reschedule(widget.store.data, DateTime.now());
    messenger.showSnackBar(
      const SnackBar(content: Text("We'll check back again in 24 hours.")),
    );
  }

  // "Do you still want this?" with three choices, never a fourth silent one:
  // reviewing, skipping, and extending are the only ways this item's status
  // changes, and each is a single deliberate tap.
  void _openRevisitPrompt(Map<String, dynamic> item) {
    final name = _waitingDisplayName(item);
    final amount = item['amount'];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: Barako.background,
          border: Border.all(color: Barako.border),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        // A long typed item name (itemName has no length cap) plus a large
        // system text scale overflows a plain Column here with no way to
        // reach the buttons below the fold: SingleChildScrollView, the same
        // fix _EditWinSheet already applies below, so the sheet scrolls
        // instead of clipping.
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          24 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Do you still want this?',
                  style: AppText.title.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 6),
                Text(name, style: AppText.bodyLg.w7),
                if (amount is num) ...[
                  const SizedBox(height: 2),
                  Text(formatMoney(amount), style: AppText.body),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _reviewAgain(item);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Barako.primary,
                      foregroundColor: Barako.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Yes, review again'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _skipItem(item);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Barako.textSecondary,
                      side: BorderSide(color: Barako.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('No, skip it'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _waitAnotherDay(item);
                    },
                    child: Text(
                      'Not sure, wait another 24 hours',
                      style: TextStyle(color: Barako.muted),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Money mindset')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            // Every read of store.data lives INSIDE this builder, not in the
            // outer build() above: something outside this screen's own
            // setState calls (main.dart posts due recurring transactions on
            // every app-foreground resume, for one) can call
            // store.notifyListeners() at any time, and only this inner
            // builder re-runs when that happens. Computing categories,
            // impact, or verdict up in build() would close over a stale
            // snapshot that this ListenableBuilder can never refresh, the
            // same trap categories.dart's own comment already warns about
            // for spentByCategory.
            final now = DateTime.now();
            final lesson = lessonFromMap(lessonOfTheDay(now));
            final lessonTitle = _lessonTitleOf(lesson);
            final lessonSummary = _lessonSummaryOf(lesson);
            final categories = _categories();
            final impact = _budgetImpact(categories);
            final verdict = _computeVerdict(_answers, impact);
            // Money Mindset Phase 5's purchase-type context, computed once
            // here (not inside the widgets that render them) so the verdict
            // card's "Why this result" and the considering section's own
            // cards always agree, the same single-source rule impact above
            // already follows for the budget check.
            final subscriptionSummary = _purchaseType == 'subscription'
                ? _subscriptionSummary
                : null;
            final creditSummary = _purchaseType == 'credit'
                ? _creditSummary
                : null;
            final commitLoad = _purchaseType == 'credit'
                ? commitmentLoad(widget.store.data, now)
                : null;
            final goals = _goals();
            final selectedGoal = _selectedGoal(goals);
            final goalInfo = goalTradeoff(
              goal: selectedGoal,
              purchaseAmount: _goalTradeoffAmount,
              now: now,
            );
            // The objective Decision Score for the current entry, shown as its
            // own card between the inputs and the questions. Null until a
            // usable amount is typed, so the card appears only once it has
            // something honest to say.
            final decision = _decisionResult(now, selectedGoal);
            // The one-time comfort spectrum for the what-if slider, memoised so
            // dragging never re-runs the search. Shown only for a one-time buy
            // with NO linked goal: the score is monotonic in the amount for the
            // buffer, income and reserved axes, but the goal axis is NOT (a near
            // funded deadline goal makes it jump as the amount crosses a period
            // boundary), which would break the binary search and let the zoned
            // bar disagree with the real score. So the spectrum is gated to the
            // provably monotone case; a subscription or credit "ceiling" is a
            // monthly figure that reads differently and is also deferred. Making
            // the goal axis monotone is a money-methodology change flagged to the
            // founder, not done here.
            final enteredOneTime = _validAmount ?? 0;
            final spectrum =
                (_purchaseType == 'oneTime' &&
                    decision != null &&
                    enteredOneTime > 0 &&
                    selectedGoal == null)
                ? _spectrumFor(now, decision, enteredOneTime)
                : null;
            // One log row per completed check, the moment all three answers
            // first line up. Scheduled for after this frame rather than
            // called straight from build(): logMindsetCheck writes through
            // the store and calls notifyListeners, and doing that WHILE this
            // very ListenableBuilder is still building is exactly the kind
            // of build-time side effect Flutter (rightly) does not allow.
            if (verdict != null && !_checkLogged && widget.store.canWrite) {
              _checkLogged = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.store.logMindsetCheck(verdict: _verdictKey(verdict));
              });
            }
            final answered = _answers.any((a) => a != null);
            final hasConsiderInput =
                _itemName.text.trim().isNotEmpty ||
                _amountText.text.trim().isNotEmpty ||
                _categoryId != null ||
                _purchaseType != 'oneTime' ||
                _subAmountText.text.trim().isNotEmpty ||
                _creditCashText.text.trim().isNotEmpty ||
                _creditDownText.text.trim().isNotEmpty ||
                _creditInstallmentText.text.trim().isNotEmpty ||
                _creditInstallmentsCountText.text.trim().isNotEmpty ||
                _creditFeesText.text.trim().isNotEmpty ||
                _goalId != null;
            final showClear = answered || hasConsiderInput;
            final wins = _wins().reversed.toList();
            final waiting = waitingItems(
              widget.store.data['settings'] is Map
                  ? (widget.store.data['settings'] as Map)['mindsetWaiting']
                  : null,
            );
            final snapshot = mindsetSnapshot(
              wins: widget.store.data['wins'],
              mindsetChecks: widget.store.mindsetChecks,
              mindsetWaiting: widget.store.mindsetWaiting,
              now: now,
            );
            final categoryNameById = {
              for (final c in categories) '${c['id']}': '${c['name'] ?? ''}',
            };
            final insight = mindsetInsight(
              mindsetWaiting: widget.store.mindsetWaiting,
              now: now,
              categoryName: (id) => categoryNameById[id],
            );
            return ListView(
              controller: _listController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // The decision check: the primary reason someone opens this
                // screen, so it leads.
                Text('IMPULSE CHECK', style: Barako.kickerStyle),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 14),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            // A distinct panel, not just a hairline: the
                            // "considering" step and the yes/no questions read
                            // as one long form without something more than a
                            // 0.5dp border marking them as two separate steps.
                            color: Barako.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Barako.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _considerSection(
                                categories,
                                goals,
                                commitLoad,
                                goalInfo,
                              ),
                              if (decision != null) ...[
                                const SizedBox(height: 14),
                                _decisionSection(
                                  decision,
                                  _purchaseType,
                                  spectrum: spectrum,
                                  entered: enteredOneTime,
                                ),
                              ],
                              if (impact != null) ...[
                                const SizedBox(height: 14),
                                _budgetImpactSection(impact),
                              ],
                            ],
                          ),
                        ),
                        for (var i = 0; i < _questions.length; i++)
                          _questionRow(i),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: _verdictSection(
                            verdict,
                            impact,
                            purchaseType: _purchaseType,
                            subscriptionInfo: subscriptionSummary,
                            creditInfo: creditSummary,
                            commitmentInfo: commitLoad,
                            goalInfo: goalInfo,
                          ),
                        ),
                        if (showClear)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _clearCheck,
                                child: Text(
                                  'Clear check',
                                  style: TextStyle(color: Barako.muted),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Waiting: every paused purchase still counting down to its
                // Do you still want this? check-in. Hidden entirely when
                // empty, the same as SMALL WINS is not, because an empty
                // Waiting list is the common case and a permanent "nothing
                // waiting" line would just be more of the screen to skip.
                if (waiting.isNotEmpty) ...[
                  Text('WAITING', style: Barako.kickerStyle),
                  const SizedBox(height: 8),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          for (var i = 0; i < waiting.length; i++)
                            _waitingRow(waiting[i], i > 0, now),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 30-day snapshot: local, on-device counts only, built from
                // this screen's own records (mindsetChecks, mindsetWaiting,
                // wins). Always shown, even at zero, so the numbers read as
                // a running tally rather than something that only appears
                // once it has good news.
                _snapshotSection(snapshot, insight),

                // Today's lesson: a doorway into the Learn track.
                PressableScale(
                  child: Card(
                    color: Barako.surfaceRaised,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Barako.primary),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LearnScreen(
                            store: widget.store,
                            onSwitchTab: widget.onSwitchTab,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "TODAY'S LESSON",
                              style: Barako.kickerStyle.copyWith(
                                color: Barako.primaryText,
                              ),
                            ),
                            if (lesson.forFreelancers) ...[
                              const SizedBox(height: 4),
                              // A text label, not a color swatch: this lesson
                              // is wrong advice for a salaried reader (it
                              // covers setting aside your OWN tax or
                              // restarting your OWN SSS/PhilHealth/Pag-IBIG),
                              // so it says who it is for instead of quietly
                              // reading as advice for everyone. Never derived
                              // from a guess at who the reader is; Salapify
                              // has no employment-status field to guess from.
                              Text(
                                'For freelancers',
                                style: AppText.caption.w6.tint(
                                  Barako.textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SalapifyGlyph(
                                  lesson.icon,
                                  size: 22,
                                  boxed: false,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    lessonTitle,
                                    style: AppText.bodyLg.w7.copyWith(
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lessonSummary,
                              style: AppText.small.copyWith(height: 1.4),
                            ),
                            const SizedBox(height: 8),
                            // The go-deeper affordance is a real glyph now,
                            // not a '›' typeset into the sentence.
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Read this and more in Money courses',
                                    style: AppText.small.w6.tint(
                                      Barako.primaryText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  salapifyIcon('forward'),
                                  size: 16,
                                  color: Barako.primaryText,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Small wins: what you decided not to buy. The plain
                // text-and-Add row is manual entry exactly as it always was;
                // the optional amount and reflection are a step you opt into
                // below it, never a requirement to log a win at all.
                Text('SMALL WINS', style: Barako.kickerStyle),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('mindsetWinText'),
                        controller: _winText,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addWin(),
                        style: AppText.body,
                        decoration: InputDecoration(
                          hintText: 'e.g. Packed lunch all week',
                          hintStyle: TextStyle(color: Barako.faint),
                          filled: true,
                          fillColor: Barako.card,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Barako.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Barako.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Barako.primary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _addingWin ? null : _addWin,
                      style: FilledButton.styleFrom(
                        backgroundColor: Barako.primary,
                        foregroundColor: Barako.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      child: const Text(
                        'Add',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_winDetailsExpanded) ...[
                  _winAmountField(),
                  if (_winAmountError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _winAmountError!,
                      style: AppText.caption.tint(Barako.warningStrong),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _winNoteField(),
                ] else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _winDetailsExpanded = true),
                      child: Text(
                        '+ Add spending avoided or a reflection',
                        style: AppText.small.w6.tint(Barako.primaryText),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: wins.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No wins yet. Add a small one above.',
                              style: AppText.small.tint(Barako.faint),
                            ),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < wins.length; i++)
                                _winRow(wins[i], i > 0),
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _questionRow(int i) {
    final question = _questions[i];
    return Container(
      decoration: i > 0
          ? BoxDecoration(
              border: Border(top: BorderSide(color: Barako.border, width: 0.5)),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: AppText.body),
          const SizedBox(height: 10),
          Segmented<bool?>(
            // Explicit semanticLabel per option: without it a screen reader
            // landing on the control directly (not swiping in from the
            // question text above it) hears only "Yes, button", with no
            // question context.
            options: [
              SegmentOption(
                value: true,
                label: 'Yes',
                semanticLabel: 'Yes, $question',
              ),
              SegmentOption(
                value: false,
                label: 'No',
                semanticLabel: 'No, $question',
              ),
            ],
            current: _answers[i],
            onPick: (v) => setState(() => _answers[i] = v),
          ),
        ],
      ),
    );
  }

  // Neutral until every question has an answer (verdict is null), then the
  // verdict word, why it landed there, and updates live as an answer changes
  // because it is derived straight from _answers on every build. [impact]
  // flows into _whyText so the budget numbers can show up in the reason.
  Widget _verdictSection(
    _Verdict? verdict,
    Map<String, dynamic>? impact, {
    required String purchaseType,
    Map<String, dynamic>? subscriptionInfo,
    Map<String, dynamic>? creditInfo,
    Map<String, dynamic>? commitmentInfo,
    Map<String, dynamic>? goalInfo,
  }) {
    if (verdict == null) {
      return Row(
        children: [
          Icon(salapifyIcon('help'), color: Barako.muted, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Answer all three questions to see where this fits.',
              style: AppText.small.tint(Barako.muted),
            ),
          ),
        ],
      );
    }
    final (word, color, icon) = _verdictHead(verdict);
    return Semantics(
      liveRegion: true,
      // Without this, the live region has no boundary of its own: its flag
      // and text merge upward into whatever plain-text SemanticsNode sits
      // above it in the same Card (the WHAT ARE YOU CONSIDERING? kicker and
      // all three questions), so a screen reader replays the ENTIRE form
      // from the top every time an answer changes the verdict. container:
      // true gives this block its own node, so only the verdict, its
      // reason, and the Revisit button announce.
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(word, style: AppText.small.w6.tint(color))),
            ],
          ),
          const SizedBox(height: 8),
          Text('Why this result', style: AppText.small.w6),
          const SizedBox(height: 2),
          Text(
            _whyText(
              verdict,
              _answers,
              impact,
              purchaseType: purchaseType,
              subscriptionInfo: subscriptionInfo,
              creditInfo: creditInfo,
              commitmentInfo: commitmentInfo,
              goalInfo: goalInfo,
            ),
            style: AppText.small.copyWith(height: 1.4),
          ),
          if (verdict == _Verdict.pause24h) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (widget.store.canWrite && !_savingToWaiting)
                    ? _saveToWaiting
                    : null,
                icon: Icon(salapifyIcon('waiting'), size: 18),
                label: const Text('Revisit in 24 hours'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Barako.primaryText,
                  side: BorderSide(color: Barako.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // "What are you considering?": item name, estimated amount, and category,
  // all optional. Nothing here creates a transaction or touches a balance;
  // it only feeds the budget-impact comparison below and the verdict above.
  Widget _considerSection(
    List<Map<String, dynamic>> categories,
    List<Map<String, dynamic>> goals,
    Map<String, dynamic>? commitLoad,
    Map<String, dynamic>? goalInfo,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WHAT ARE YOU CONSIDERING?', style: Barako.cardKickerStyle),
        const SizedBox(height: 10),
        _purchaseTypeSelector(),
        const SizedBox(height: 12),
        Text('Item (optional)', style: AppText.caption.tint(Barako.muted)),
        const SizedBox(height: 6),
        _itemNameField(),
        const SizedBox(height: 12),
        switch (_purchaseType) {
          'subscription' => _subscriptionFields(categories),
          'credit' => _creditFields(commitLoad),
          _ => _oneTimeFields(categories),
        },
        if (goals.isNotEmpty) ...[
          const SizedBox(height: 14),
          _goalTradeoffSection(goals, goalInfo),
        ],
      ],
    );
  }

  // Money Mindset Phase 5's purchase-type picker: which shape the fields
  // below collect. One-time is first and is what a blank check still opens
  // to, so nothing about Phase 2's original flow changes for someone who
  // never touches this control.
  Widget _purchaseTypeSelector() => Segmented<String>(
    options: const [
      SegmentOption(value: 'oneTime', label: 'One-time purchase'),
      SegmentOption(value: 'subscription', label: 'Subscription'),
      SegmentOption(value: 'credit', label: 'Credit or BNPL'),
    ],
    current: _purchaseType,
    onPick: (v) => setState(() => _purchaseType = v),
  );

  // Phase 2's original considering fields, unchanged: an estimated amount
  // and an optional category, feeding the budget-impact card above.
  Widget _oneTimeFields(List<Map<String, dynamic>> categories) {
    final amountError = _amountError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estimated amount (optional)',
          style: AppText.caption.tint(Barako.muted),
        ),
        const SizedBox(height: 6),
        _amountField(),
        if (amountError != null) ...[
          const SizedBox(height: 4),
          Text(amountError, style: AppText.caption.tint(Barako.warningStrong)),
        ],
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Category (optional)',
            style: AppText.caption.tint(Barako.muted),
          ),
          const SizedBox(height: 6),
          _categoryChips(categories),
        ],
      ],
    );
  }

  // A recurring amount, how often it bills, the monthly and annual size
  // that comes out of, and the same optional category the one-time flow
  // offers (so a subscription's monthly bite can still show against a
  // category's cap through the shared budget-impact card above).
  Widget _subscriptionFields(List<Map<String, dynamic>> categories) {
    final amountError = _numericFieldError(_subAmountText.text);
    final summary = _subscriptionSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recurring amount', style: AppText.caption.tint(Barako.muted)),
        const SizedBox(height: 6),
        _subAmountField(),
        if (amountError != null) ...[
          const SizedBox(height: 4),
          Text(amountError, style: AppText.caption.tint(Barako.warningStrong)),
        ],
        const SizedBox(height: 12),
        Text('Frequency', style: AppText.caption.tint(Barako.muted)),
        const SizedBox(height: 6),
        _subFrequencySelector(),
        if (summary != null) ...[
          const SizedBox(height: 12),
          _summaryCard([
            _impactRow('Monthly equivalent', formatMoney(summary['monthly']!)),
            _impactRow('Annual equivalent', formatMoney(summary['annual']!)),
          ]),
        ],
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Category (optional)',
            style: AppText.caption.tint(Barako.muted),
          ),
          const SizedBox(height: 6),
          _categoryChips(categories),
        ],
      ],
    );
  }

  Widget _subAmountField() => TextField(
    key: const Key('mindsetSubAmount'),
    controller: _subAmountText,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() {}),
    style: AppText.body,
    decoration: InputDecoration(
      prefixText: '$baseCurrencySymbol ',
      prefixStyle: AppText.body.tint(Barako.textSecondary),
      hintText: 'e.g. 149',
      hintStyle: TextStyle(color: Barako.faint),
      filled: true,
      fillColor: Barako.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Barako.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Barako.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Barako.primary),
      ),
    ),
  );

  // Four options, not Segmented's two or three: "Monthly" and "Quarterly"
  // do not fit a quarter-width column as one unbroken word, so Segmented's
  // own line-fit check (which only asks whether a label fits in two lines,
  // not whether a wrap lands somewhere readable) let it hyphen-less
  // mid-word wrap into "Mont/hly" and "Quart/erly", caught by actually
  // looking at the render. ChoiceChips in a Wrap sidestep it entirely: each
  // chip is a whole word that only ever wraps as a whole chip to a new
  // line, the same pattern goal_create.dart's own frequency picker already
  // uses.
  Widget _subFrequencySelector() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final f in const [
        ('weekly', 'Weekly'),
        ('monthly', 'Monthly'),
        ('quarterly', 'Quarterly'),
        ('annual', 'Annual'),
      ])
        ChoiceChip(
          label: Text(f.$2),
          selected: _subFrequency == f.$1,
          onSelected: (_) => setState(() => _subFrequency = f.$1),
          selectedColor: Barako.primary,
          backgroundColor: Barako.background,
          labelStyle: TextStyle(
            color: _subFrequency == f.$1
                ? Barako.onPrimary
                : Barako.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: Barako.border),
        ),
    ],
  );

  // Cash price, an optional down payment, the installment amount, how many
  // installments, and any known fee, mirroring bnplCost's own fields
  // (bnpl.dart) exactly so that engine's true-cost math, not a second copy
  // of it, produces everything shown here. No category: Phase 5's spec
  // does not ask for a BNPL budget-impact card, only its own totals and
  // existing debt commitments.
  Widget _creditFields(Map<String, dynamic>? commitLoad) {
    final summary = _creditSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labeledNumberField(
          label: 'Cash price',
          fieldKey: const Key('mindsetCreditCash'),
          controller: _creditCashText,
          hint: 'e.g. 15000',
          prefix: baseCurrencySymbol,
        ),
        const SizedBox(height: 12),
        _labeledNumberField(
          label: 'Down payment (optional)',
          fieldKey: const Key('mindsetCreditDown'),
          controller: _creditDownText,
          hint: 'e.g. 3000',
          prefix: baseCurrencySymbol,
        ),
        const SizedBox(height: 12),
        _labeledNumberField(
          label: 'Installment amount',
          fieldKey: const Key('mindsetCreditInstallment'),
          controller: _creditInstallmentText,
          hint: 'e.g. 1500',
          prefix: baseCurrencySymbol,
        ),
        const SizedBox(height: 12),
        _labeledNumberField(
          label: 'Number of installments',
          fieldKey: const Key('mindsetCreditInstallmentsCount'),
          controller: _creditInstallmentsCountText,
          hint: 'e.g. 12',
          decimal: false,
        ),
        const SizedBox(height: 12),
        _labeledNumberField(
          label: 'Known fees (optional)',
          fieldKey: const Key('mindsetCreditFees'),
          controller: _creditFeesText,
          hint: 'e.g. 0',
          prefix: baseCurrencySymbol,
        ),
        if (summary != null) ...[
          const SizedBox(height: 14),
          _creditSummaryCard(summary, commitLoad),
        ],
      ],
    );
  }

  Widget _labeledNumberField({
    required String label,
    required Key fieldKey,
    required TextEditingController controller,
    required String hint,
    String? prefix,
    // Number of installments is a whole-number count; a "." key that can
    // only ever produce an invalid value for that one field is worth
    // hiding, even though _numericFieldError still accepts a typed decimal
    // the same forgiving way every other field here does.
    bool decimal = true,
  }) {
    final error = _numericFieldError(controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption.tint(Barako.muted)),
        const SizedBox(height: 6),
        TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          onChanged: (_) => setState(() {}),
          style: AppText.body,
          decoration: InputDecoration(
            prefixText: prefix == null ? null : '$prefix ',
            prefixStyle: AppText.body.tint(Barako.textSecondary),
            hintText: hint,
            hintStyle: TextStyle(color: Barako.faint),
            filled: true,
            fillColor: Barako.card,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Barako.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Barako.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Barako.primary),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error, style: AppText.caption.tint(Barako.warningStrong)),
        ],
      ],
    );
  }

  // A plain bordered panel of rows, the same shape _budgetImpactSection
  // already uses for its own card, reused here for the subscription and
  // credit summaries instead of a third near-identical container.
  Widget _summaryCard(List<Widget> rows) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Barako.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Barako.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
  );

  Widget _creditSummaryCard(
    Map<String, dynamic> summary,
    Map<String, dynamic>? commitLoad,
  ) {
    final totalPaid = summary['totalPaid'] as double;
    final extraCost = summary['extraCost'] as double;
    final cash = summary['cash'] as double;
    final monthly = summary['monthly'] as double;
    final underpays = summary['underpays'] as bool;
    final hasCommitments =
        commitLoad != null &&
        commitLoad['applicable'] == true &&
        (commitLoad['minimumsCount'] as int) > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Barako.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: underpays ? Barako.warningStrong : Barako.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOTAL COST', style: Barako.cardKickerStyle),
          const SizedBox(height: 8),
          // Short labels on purpose: _impactRow splits its row 50/50 between
          // label and value, and this card's own padding leaves each side
          // under 150dp on a 390dp-wide phone. "Difference from cash price"
          // and "Your other debt minimums (monthly)" both hard-wrapped
          // mid-word into unreadable ellipsized fragments in the actual
          // render, caught by looking at the screenshot rather than by any
          // text-matching widget test, since Text.data still holds the full
          // string regardless of whether it visually truncates.
          _impactRow('Total repayment', formatMoney(totalPaid)),
          _impactRow('Extra cost', formatMoney(extraCost), warn: extraCost > 0),
          _impactRow('Monthly payment', formatMoney(monthly)),
          if (hasCommitments) ...[
            const SizedBox(height: 4),
            _impactRow(
              'Debt minimums',
              formatMoney(commitLoad['minimumsTotal'] as double),
            ),
          ],
          if (underpays) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  salapifyIcon('warning'),
                  color: Barako.warningStrong,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'These numbers do not add up: the payments do not cover '
                    'the ${formatMoney(cash)} cash price.',
                    style: AppText.small
                        .tint(Barako.warningStrong)
                        .copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Money Mindset Phase 5's goal trade-off: an optional, read-only compare
  // against one existing goal. Selecting a chip never writes to
  // goals.dart's own data; it only feeds goalTradeoff (mindset_purchase.dart)
  // for the card below.
  Widget _goalTradeoffSection(
    List<Map<String, dynamic>> goals,
    Map<String, dynamic>? goalInfo,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('COMPARE TO A GOAL (OPTIONAL)', style: Barako.cardKickerStyle),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in goals)
              ChoiceChip(
                label: Text('${g['name'] ?? 'Goal'}'),
                selected: _goalId == '${g['id']}',
                onSelected: (_) => setState(() {
                  final id = '${g['id']}';
                  _goalId = _goalId == id ? null : id;
                }),
                selectedColor: Barako.primary,
                backgroundColor: Barako.background,
                labelStyle: TextStyle(
                  color: _goalId == '${g['id']}'
                      ? Barako.onPrimary
                      : Barako.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(color: Barako.border),
              ),
          ],
        ),
        if (goalInfo != null) ...[
          const SizedBox(height: 12),
          _goalTradeoffCard(goalInfo),
        ],
      ],
    );
  }

  Widget _goalTradeoffCard(Map<String, dynamic> info) {
    final remaining = info['remaining'] as double;
    final amount = info['purchaseAmount'] as double;
    final pct = info['percentOfRemaining'] as double;
    final name = info['goalName'] as String;
    final delay = info['delay'] as Map<String, dynamic>?;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Barako.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Barako.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: AppText.small.w7,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 8),
          // Short labels, same reason as _creditSummaryCard just above:
          // "Remaining goal amount" and "Percent of what is left" both
          // hard-wrapped mid-word in the actual render at this card's
          // narrow width, caught by looking at the screenshot.
          _impactRow('Purchase amount', formatMoney(amount)),
          _impactRow('Goal remaining', formatMoney(remaining)),
          _impactRow('Percent left', '${pct.round()}%', emphasize: true),
          if (delay != null) ...[
            const SizedBox(height: 8),
            Text(
              'At your current pace, this could push that goal about '
              '${delay['periods']} '
              '${_periodWord(delay['frequency'] as String, delay['periods'] as int)} '
              'later.',
              style: AppText.small.tint(Barako.muted).copyWith(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemNameField() => TextField(
    key: const Key('mindsetItemName'),
    controller: _itemName,
    textInputAction: TextInputAction.next,
    onChanged: (_) => setState(() {}),
    style: AppText.body,
    decoration: InputDecoration(
      hintText: 'e.g. New shoes',
      hintStyle: TextStyle(color: Barako.faint),
      filled: true,
      fillColor: Barako.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Barako.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Barako.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Barako.primary),
      ),
    ),
  );

  Widget _amountField() => TextField(
    key: const Key('mindsetAmount'),
    controller: _amountText,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() {}),
    style: AppText.body,
    decoration: InputDecoration(
      prefixText: '$baseCurrencySymbol ',
      prefixStyle: AppText.body.tint(Barako.textSecondary),
      hintText: 'e.g. 1500',
      hintStyle: TextStyle(color: Barako.faint),
      filled: true,
      fillColor: Barako.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Barako.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Barako.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Barako.primary),
      ),
    ),
  );

  // The same categoryTree-plus-ChoiceChip pattern categories.dart and its own
  // delete sheet already use to list categories, reused here rather than
  // invented fresh: one selection, tap again to clear it. categories.dart's
  // own list conveys parent/child by indenting a vertical column, which does
  // not translate to a Wrap: a child chip can land on a different row than
  // its parent, so a left-padded chip here would just look misaligned rather
  // than nested. The parent's name goes into the child's own label instead.
  Widget _categoryChips(List<Map<String, dynamic>> categories) {
    final rows = categoryTree(categories);
    final byId = {for (final c in categories) '${c['id']}': c};
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final row in rows)
          ChoiceChip(
            label: Text(_categoryChipLabel(row, byId)),
            selected: _categoryId == '${row.cat['id']}',
            onSelected: (_) => setState(() {
              final id = '${row.cat['id']}';
              _categoryId = _categoryId == id ? null : id;
            }),
            selectedColor: Barako.primary,
            backgroundColor: Barako.background,
            labelStyle: TextStyle(
              color: _categoryId == '${row.cat['id']}'
                  ? Barako.onPrimary
                  : Barako.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(color: Barako.border),
          ),
      ],
    );
  }

  String _categoryChipLabel(
    CategoryRow row,
    Map<String, Map<String, dynamic>> byId,
  ) {
    final label = _categoryLabel(row.cat);
    if (row.depth != 1) return label;
    final parent = byId['${row.cat['parentId'] ?? ''}'];
    final parentName = parent == null ? null : '${parent['name'] ?? ''}';
    return (parentName == null || parentName.isEmpty)
        ? label
        : '$parentName · $label';
  }

  String _categoryLabel(Map<String, dynamic> cat) {
    final icon = '${cat['icon'] ?? ''}';
    final name = '${cat['name'] ?? 'Category'}';
    return icon.isEmpty ? name : '$icon $name';
  }

  // Only rendered when _budgetImpact returned non-null: a valid amount, a
  // chosen category, and a real Pro monthly cap all lined up. Read-only,
  // exactly like AffordCard; nothing here saves or spends anything.
  MindsetMode get _mindsetMode => switch (_purchaseType) {
    'subscription' => MindsetMode.subscription,
    'credit' => MindsetMode.credit,
    _ => MindsetMode.oneTime,
  };

  /// The objective Decision Score for whatever is currently typed, or null
  /// when there is not yet a usable amount to judge. Read-only: it composes
  /// the same golden-locked engines Home and the Afford card already show, so
  /// this card can never disagree with them. A one-time buy weighs its whole
  /// price against the cushion; a subscription or a credit plan weighs its
  /// monthly bite, matching [_effectiveAmount]'s own per-type rule.
  Map<String, dynamic>? _decisionResult(
    DateTime now,
    Map<String, dynamic>? selectedGoal,
  ) {
    final mode = _mindsetMode;
    final double? cashNow;
    final double monthlyLoad;
    if (mode == MindsetMode.oneTime) {
      cashNow = _validAmount;
      monthlyLoad = 0;
    } else {
      cashNow = _effectiveAmount;
      monthlyLoad = _effectiveAmount ?? 0;
    }
    if (cashNow == null || !(cashNow > 0)) return null;
    var markup = 0.0;
    if (mode == MindsetMode.credit) {
      final extra = amountOf(_creditSummary?['extraCost']);
      final cash = _numericFieldValue(_creditCashText.text) ?? 0;
      if (cash > 0 && extra > 0) markup = extra / cash;
    }
    return mindsetDecision(
      widget.store.data,
      now,
      mode: mode,
      cashNow: cashNow,
      monthlyLoad: monthlyLoad,
      creditMarkup: markup,
      goal: selectedGoal,
      goalAmount: _goalTradeoffAmount,
    );
  }

  /// Round up to a tidy number for the slider's top end, so the axis reads in
  /// round pesos rather than an arbitrary 1.4x figure.
  static double _niceCeil(double x) {
    if (x <= 0) return 1000;
    final step = x < 5000
        ? 500.0
        : x < 20000
        ? 1000.0
        : x < 100000
        ? 5000.0
        : 10000.0;
    return (x / step).ceil() * step;
  }

  /// The comfort spectrum (band ceilings) for the current one-time entry,
  /// memoised by the store's money state so dragging the slider reuses it
  /// instead of re-running the binary search over the ledger. The ceilings
  /// depend on the money on hand and the linked goal, not on the entered amount,
  /// so the cache stays valid as the typed amount changes. Assigning the cache
  /// fields here is not setState, so it never triggers a rebuild.
  Map<String, double>? _spectrumFor(
    DateTime now,
    Map<String, dynamic> decision,
    double entered,
  ) {
    final buffer = amountOf(decision['bufferAfter']) + entered;
    final available = amountOf(decision['availableAfter']) + entered;
    // daysLeft is in the key because the sweldo-relief boundary (3 days) can
    // move the reserved axis with no change to buffer or available, which would
    // otherwise leave a stale ceiling cached across a day boundary.
    final daysLeft = decision['daysLeft'];
    final key =
        '${buffer.round()}_${available.round()}_'
        '${daysLeft}_${decision['incomeKnown']}';
    if (key != _spectrumKey) {
      final searchMax = [
        buffer * 2,
        entered * 5,
        300000.0,
      ].reduce((a, b) => a > b ? a : b);
      // No goal here (the caller gates the spectrum to the no-goal case), so the
      // score is monotone and the binary search is exact.
      _spectrum = mindsetComfortRange(
        widget.store.data,
        now,
        goal: null,
        maxAmount: searchMax,
      );
      _spectrumKey = key;
      _spectrumSearchMax = searchMax;
    }
    return _spectrum;
  }

  static Color _scoreColor(double score) {
    if (score.isNaN) return Barako.muted;
    if (score >= 70) return Barako.primary;
    if (score >= 45) return Barako.warning;
    return Barako.warningStrong;
  }

  /// The headline colour reads the BAND, not the raw score, so it can never
  /// disagree with the band word beside it if the cutoffs are ever retuned in
  /// the engine (one source of truth for the headline).
  static Color _bandColor(int band) => switch (band) {
    1 => Barako.primary,
    2 => Barako.warning,
    _ => Barako.warningStrong,
  };

  /// A plain valence word for an axis score, so the dot colour is never the only
  /// signal: a colour-blind user and a screen reader both get the severity.
  static String _axisValence(double score) {
    if (score.isNaN) return 'not enough history to judge';
    if (score >= 70) return 'looks fine';
    if (score >= 45) return 'worth watching';
    return 'a concern';
  }

  /// The singular or plural period word for a goal-delay estimate, so
  /// "1 month later" and "5 months later" both read right.
  static String _goalPeriodWord(int n, String frequency) {
    final base = switch (frequency) {
      'weekly' => 'week',
      'quarterly' => 'quarter',
      'annual' => 'year',
      _ => 'month',
    };
    return n == 1 ? base : '${base}s';
  }

  /// One axis of the Decision Score: a colour dot keyed to how that axis
  /// scored, the plain-English factor name, and the honest figure behind it.
  /// The label ellipsizes and the value scales down, so neither overflows a
  /// 320dp phone at large text, the same guard [_impactRow] keeps.
  Widget _axisRow(String label, String value, Color dot, String valence) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      // One merged node per row so a screen reader reads "Cushion after, 1.5
      // months left, worth watching" instead of a bare fact with the severity
      // hidden in a colour it cannot see.
      child: Semantics(
        container: true,
        excludeSemantics: true,
        label: '$label: $value, $valence',
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: AppText.small.tint(Barako.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  maxLines: 1,
                  style: AppText.small.w6.tint(dot),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The Money Mindset Decision Score card: the objective read on what a
  /// purchase does to the money, shown the moment a usable amount is typed and
  /// before the three reflection questions. It never gives an order (founder
  /// rule): impact words, not "buy" or "skip", and the user still decides.
  Widget _decisionSection(
    Map<String, dynamic> decision,
    String purchaseType, {
    Map<String, double>? spectrum,
    double entered = 0,
  }) {
    final score = decision['financialScore'] as int;
    final band = decision['band'] as int;
    final bandLabel = decision['bandLabel'] as String;
    final c = _bandColor(band);
    final runwayAfter = decision['runwayAfter'] as double?;
    final incomeShare = decision['incomeShare'] as double?;
    final dips = decision['dipsReserved'] as bool;
    final shortfall = amountOf(decision['reservedShortfall']);
    final tradeoff = decision['goalTradeoff'] as Map<String, dynamic>?;
    final axes = (decision['axes'] as List).cast<Map<String, dynamic>>();
    double axisScore(String name) {
      final a = axes.firstWhere(
        (e) => e['name'] == name,
        orElse: () => const {'score': double.nan},
      );
      return (a['score'] as num).toDouble();
    }

    // Cushion after the buy. With enough expense history this is a count of
    // months; without it (a thin, early-user ledger) there is no honest month
    // figure, so it shows the actual pesos left in the accounts instead of a
    // fabricated month count or a vague word.
    final bufferAfter = amountOf(decision['bufferAfter']);
    final String cushionText;
    if (runwayAfter == null) {
      cushionText = bufferAfter > 0
          ? '${formatMoney(bufferAfter)} left'
          : 'Empties it';
    } else if (runwayAfter <= 0) {
      cushionText = 'Empties it';
    } else if (runwayAfter < 0.05) {
      // Positive but rounds to 0.0: say so honestly rather than print the same
      // "0.0" a reader takes for empty (which the branch above already owns).
      cushionText = 'Under 0.1 months left';
    } else {
      cushionText = '${runwayAfter.toStringAsFixed(1)} months left';
    }
    // Share of income.
    final String incomeText;
    if (incomeShare == null) {
      incomeText = 'Income unknown';
    } else if (purchaseType == 'oneTime') {
      incomeText = '${(incomeShare * 100).round()}% of a month';
    } else {
      incomeText = '${(incomeShare * 100).round()}% of income committed';
    }
    // Goal trade-off (only when a goal is linked and there is a real delay
    // or a real share to show).
    String? goalLabel;
    String? goalText;
    if (tradeoff != null) {
      goalLabel = tradeoff['goalName'] as String? ?? 'Goal';
      final delay = tradeoff['delay'];
      if (delay is Map) {
        final p = (delay['periods'] as num).toInt();
        final f = delay['frequency'] as String? ?? 'monthly';
        goalText = '$p ${_goalPeriodWord(p, f)} later';
      } else {
        final pct = amountOf(tradeoff['percentOfRemaining']).round();
        goalText = "$pct% of what's left";
      }
    }

    // Per-axis dot colour and valence. The reserved dot is floored at the
    // warning colour whenever the buy dips into reserved money, so the sweldo
    // relief in the engine (which can lift the axis score into the green band)
    // can never paint a green dot beside the words "Dips PHP X".
    final bufferScore = axisScore('buffer');
    final incomeScoreV = axisScore('income');
    final reservedScore = axisScore('reserved');
    final goalScore = axisScore('goal');
    var reservedDot = _scoreColor(reservedScore);
    if (dips && reservedDot == Barako.primary) reservedDot = Barako.warning;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // A raised card surface, not the page background: the band label, score
        // and axis values are drawn in the accent, warning and warningStrong
        // tints, and the mid warning fails AA on background in two light themes
        // (voltage, tidal) while it passes comfortably on card. Sitting on card
        // inside the darker considering panel also reads as a raised inset.
        color: Barako.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MONEY IMPACT', style: Barako.cardKickerStyle),
          const SizedBox(height: 6),
          Semantics(
            container: true,
            excludeSemantics: true,
            label: 'Money impact score $score out of 100, $bandLabel',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    bandLabel,
                    style: AppText.subtitle.w7.tint(c),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text('$score', style: AppText.title.w8.tabular.tint(c)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(' /100', style: AppText.small.tint(Barako.muted)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How this purchase sits against your money right now. You decide.',
            style: AppText.small
                .tint(Barako.textSecondary)
                .copyWith(height: 1.4),
          ),
          const SizedBox(height: 10),
          _axisRow(
            'Cushion after',
            cushionText,
            _scoreColor(bufferScore),
            _axisValence(bufferScore),
          ),
          _axisRow(
            'Share of income',
            incomeText,
            _scoreColor(incomeScoreV),
            incomeShare == null
                ? 'income history unknown'
                : _axisValence(incomeScoreV),
          ),
          _axisRow(
            'Bills & debt money',
            dips ? 'Dips ${formatMoney(shortfall)}' : 'No dip',
            reservedDot,
            dips ? 'dips into money reserved for bills and debt' : 'no dip',
          ),
          if (goalLabel != null && goalText != null)
            _axisRow(
              goalLabel,
              goalText,
              _scoreColor(goalScore),
              _axisValence(goalScore),
            ),
          if (spectrum != null && entered > 0) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: Barako.border),
            const SizedBox(height: 10),
            ..._whatIfSpectrum(spectrum, entered),
          ],
        ],
      ),
    );
  }

  /// The what-if spending spectrum: a plain-English comfortable ceiling, a
  /// zoned draggable bar, and a live readout. Only shown for a one-time buy.
  List<Widget> _whatIfSpectrum(Map<String, double> spectrum, double entered) {
    final comfortCeiling = spectrum['comfortCeiling'] ?? 0;
    final cautionCeiling = spectrum['cautionCeiling'] ?? 0;
    final maxSlider = _niceCeil(
      [
        entered * 1.4,
        cautionCeiling * 1.25,
        comfortCeiling * 1.5,
        1000.0,
      ].reduce((a, b) => a > b ? a : b),
    );
    // The explored value falls back to the entered amount whenever the entered
    // amount has changed since the last drag (never a setState in build).
    final synced = _whatIfBase == entered;
    final sliderValue = ((synced ? (_whatIf ?? entered) : entered)).clamp(
      0.0,
      maxSlider,
    );
    final band = MindsetSpectrumBar.bandForAmount(
      sliderValue,
      comfortCeiling,
      cautionCeiling,
    );
    final bandColor = _bandColor(band);

    // Floor the ceiling to a tidy ₱50 for the sentence (the bar keeps the exact
    // value): a ceiling reads as a round guideline, and rounding DOWN keeps it
    // honest (never promises more headroom than there is).
    final displayCeiling = (comfortCeiling / 50).floorToDouble() * 50;
    // When the search never left the comfortable band inside its own bound, the
    // ceiling equals that bound and is not a real boundary: say "well past"
    // rather than print the search bound as if it were a precise limit.
    final searchMax = _spectrumSearchMax ?? double.infinity;
    final saturated = comfortCeiling >= searchMax * 0.999;
    final String line;
    if (saturated) {
      line = 'Comfortable well past anything you would buy right now.';
    } else if (displayCeiling > 0) {
      line =
          'Up to ${formatMoney(displayCeiling)} still fits comfortably '
          'right now.';
    } else {
      line = 'Right now, even a small buy is worth a pause.';
    }

    // Spoken value for a screen reader: the amount and the band it lands in.
    String readout(double v) {
      final b = MindsetSpectrumBar.bandForAmount(
        v,
        comfortCeiling,
        cautionCeiling,
      );
      return '${formatMoney(v.roundToDouble())}, ${mindsetBandLabel(b)}';
    }

    final step = MindsetSpectrumBar.stepFor(maxSlider);

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(salapifyIcon('insights'), size: 16, color: Barako.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              line,
              style: AppText.small
                  .tint(Barako.textSecondary)
                  .copyWith(height: 1.35),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      MindsetSpectrumBar(
        value: sliderValue,
        maxAmount: maxSlider,
        comfortCeiling: comfortCeiling,
        cautionCeiling: cautionCeiling,
        semanticLabel: 'What if amount',
        semanticValue: readout(sliderValue),
        semanticIncreasedValue: readout(
          (sliderValue + step).clamp(0.0, maxSlider),
        ),
        semanticDecreasedValue: readout(
          (sliderValue - step).clamp(0.0, maxSlider),
        ),
        onChanged: (v) => setState(() {
          _whatIf = v;
          _whatIfBase = entered;
        }),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: Text(
              'Drag to explore',
              style: AppText.small.tint(Barako.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${formatMoney(sliderValue.roundToDouble())} · '
                '${mindsetBandLabel(band)}',
                maxLines: 1,
                style: AppText.small.w6.tint(bandColor),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _budgetImpactSection(Map<String, dynamic> impact) {
    final categoryName = impact['categoryName'] as String;
    final remainingBefore = impact['remainingBefore'] as double;
    final amount = impact['amount'] as double;
    final remainingAfter = impact['remainingAfter'] as double;
    final cap = impact['cap'] as double;
    final exceeds = impact['exceeds'] as bool;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Barako.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: exceeds ? Barako.warningStrong : Barako.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BUDGET IMPACT', style: Barako.cardKickerStyle),
          const SizedBox(height: 2),
          // The category name off the all-caps kicker line: a real name like
          // "Food & Dining" dropping to mixed case mid kicker read like a
          // typo, not a label.
          Text(
            categoryName,
            style: AppText.small.w7,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 8),
          _impactRow('Category budget remaining', formatMoney(remainingBefore)),
          _impactRow('Purchase amount', formatMoney(amount)),
          const SizedBox(height: 4),
          _impactRow(
            'Expected amount remaining',
            formatMoney(remainingAfter),
            emphasize: true,
            warn: exceeds,
          ),
          if (exceeds) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  salapifyIcon('warning'),
                  color: Barako.warningStrong,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'This would take the $categoryName budget '
                    '${formatMoney(remainingAfter.abs())} over its '
                    '${formatMoney(cap)} monthly cap.',
                    style: AppText.small
                        .tint(Barako.warningStrong)
                        .copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _impactRow(
    String label,
    String value, {
    bool emphasize = false,
    bool warn = false,
  }) {
    // The amount field allows anything up to _amountCeiling (a trillion), so
    // the value here can run to fifteen-plus characters. Neither side is a
    // bare Text: the label ellipsizes and the value scales down rather than
    // overflowing a 320dp phone, the way budget.dart's own limit card guards
    // its big figure.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.small.tint(Barako.muted),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                style: (emphasize ? AppText.small.w7 : AppText.small.w6).tabular
                    .tint(warn ? Barako.warningStrong : Barako.text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _winAmountField() => TextField(
    key: const Key('mindsetWinAmount'),
    controller: _winAmountText,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() {}),
    style: AppText.body,
    decoration: InputDecoration(
      labelText: 'Spending avoided (optional)',
      labelStyle: TextStyle(color: Barako.muted),
      prefixText: '$baseCurrencySymbol ',
      prefixStyle: AppText.body.tint(Barako.textSecondary),
      hintText: 'e.g. 150',
      hintStyle: TextStyle(color: Barako.faint),
      filled: true,
      fillColor: Barako.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Barako.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Barako.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Barako.primary),
      ),
    ),
  );

  Widget _winNoteField() => TextField(
    key: const Key('mindsetWinNote'),
    controller: _winNoteText,
    maxLines: 2,
    style: AppText.body,
    decoration: InputDecoration(
      labelText: 'Reflection (optional)',
      labelStyle: TextStyle(color: Barako.muted),
      hintText: 'e.g. I already have enough of these',
      hintStyle: TextStyle(color: Barako.faint),
      filled: true,
      fillColor: Barako.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Barako.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Barako.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Barako.primary),
      ),
    ),
  );

  /// One line per win: what was decided not to buy, plus the amount and
  /// reflection when they were recorded. Tapping the row opens the edit
  /// sheet; the trailing icon stays a quick delete-with-undo, unchanged from
  /// before Phase 4. A legacy win with no id (a hand-edited backup) simply
  /// cannot be tapped into an edit sheet, matching _deleteWin's own guard.
  Widget _winRow(Map<String, dynamic> w, bool divided) {
    final amount = w['amount'];
    final note = w['note'];
    return Container(
      decoration: divided
          ? BoxDecoration(
              border: Border(top: BorderSide(color: Barako.border, width: 0.5)),
            )
          : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openEditWinSheet(w),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SalapifyGlyph('celebrate', size: 18, boxed: false),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${w['text'] ?? ''}', style: AppText.body),
                      if (amount is num) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Spending avoided: ${formatMoney(amount)}',
                          style: AppText.small.tint(Barako.muted).tabular,
                        ),
                      ],
                      if (note is String && note.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          note.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.small.tint(Barako.faint),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _deleteWin(w),
                  iconSize: 18,
                  visualDensity: VisualDensity.standard,
                  // 48, not 44: segmented.dart's own comment states the rule
                  // for this app explicitly ("Android wants 48"); these two
                  // destructive-ish row actions (delete a win, cancel a
                  // waiting item) should not be an unforced exception to it.
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  tooltip: 'Delete win',
                  icon: Icon(salapifyIcon('close'), color: Barako.faint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The 30-day snapshot card: four local, on-device counts plus the
  /// spending-avoided disclaimer, and the single rule-based insight when
  /// there is enough data for one. Nothing here is a transaction; the
  /// spending-avoided figure is never framed as money added anywhere.
  Widget _snapshotSection(MindsetSnapshot snap, String? insight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('30-DAY SNAPSHOT', style: Barako.kickerStyle),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _snapStat(
                        'Decision checks',
                        '${snap.decisionChecksCompleted}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _snapStat(
                        'Purchases paused',
                        '${snap.purchasesPaused}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _snapStat(
                        'Purchases skipped',
                        '${snap.purchasesSkipped}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _snapStat(
                        'Spending avoided',
                        formatMoney(snap.confirmedSpendingAvoided),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  snap.spendingAvoidedRecordCount > 0
                      ? 'From ${snap.spendingAvoidedRecordCount} small '
                            '${snap.spendingAvoidedRecordCount == 1 ? 'win' : 'wins'} '
                            'with an amount. This does not add to your account '
                            'balance, it reflects what you chose not to spend.'
                      : 'Add an amount to a small win to start tracking '
                            'spending avoided. It never adds to your account '
                            'balance.',
                  style: AppText.caption
                      .tint(Barako.muted)
                      .copyWith(height: 1.4),
                ),
                if (insight != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Barako.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Barako.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              salapifyIcon('insights'),
                              size: 18,
                              color: Barako.primaryText,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                insight,
                                style: AppText.small.w6.copyWith(height: 1.4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'From your own recorded decisions, not an '
                          'analysis of your spending.',
                          style: AppText.caption.tint(Barako.faint),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _snapStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption.tint(Barako.muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.bodyLg.w7.tabular,
        ),
      ],
    );
  }

  // Tappable only once due: before then there is nothing to decide yet, and
  // a tap that silently did nothing would read as broken rather than early.
  Widget _waitingRow(Map<String, dynamic> item, bool divided, DateTime now) {
    final due = isDue(item, now);
    final name = _waitingDisplayName(item);
    final amount = item['amount'];
    return Container(
      decoration: divided
          ? BoxDecoration(
              border: Border(top: BorderSide(color: Barako.border, width: 0.5)),
            )
          : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: due ? () => _openRevisitPrompt(item) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                // Dimmed as a whole, not just tinted: a colour-only signal
                // (icon and label tint alone) reads too close between muted
                // and faint in the light palette, so a not-due row also
                // loses opacity, a structural cue that survives at a glance.
                Opacity(
                  opacity: due ? 1 : 0.6,
                  child: Icon(
                    salapifyIcon('waiting'),
                    size: 18,
                    color: due ? Barako.primaryText : Barako.faint,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Opacity(
                    opacity: due ? 1 : 0.6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body,
                        ),
                        if (amount is num) ...[
                          const SizedBox(height: 2),
                          Text(
                            formatMoney(amount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.small.tint(Barako.muted).tabular,
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          revisitLabel(item, now),
                          style: AppText.small.w6.tint(
                            due ? Barako.primaryText : Barako.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _cancelWaitingItem(item),
                  iconSize: 18,
                  visualDensity: VisualDensity.standard,
                  // 48, not 44: segmented.dart's own comment states the rule
                  // for this app explicitly ("Android wants 48"); these two
                  // destructive-ish row actions (delete a win, cancel a
                  // waiting item) should not be an unforced exception to it.
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  tooltip: 'Cancel',
                  icon: Icon(salapifyIcon('close'), color: Barako.faint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bottom sheet _openEditWinSheet opens: what was decided not to buy,
/// its optional amount and reflection, Save, and Delete. A real StatefulWidget
/// (not a plain builder closure) so its three TextEditingControllers get a
/// real dispose(), the same discipline every other form sheet in this app
/// (DebtFormSheet in debts.dart and its siblings) already follows.
class _EditWinSheet extends StatefulWidget {
  final Map<String, dynamic> win;

  /// Called once Save passes validation, with the trimmed text and the
  /// parsed, already-validated amount and note (note null when blank). The
  /// sheet is already popped by the time this runs.
  final Future<void> Function(String text, double? amount, String? note) onSave;

  /// Called after the sheet is popped by its own Delete button; the caller
  /// owns the confirm dialog and the actual delete.
  final VoidCallback onDelete;

  const _EditWinSheet({
    required this.win,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EditWinSheet> createState() => _EditWinSheetState();
}

class _EditWinSheetState extends State<_EditWinSheet> {
  late final TextEditingController _textCtl;
  late final TextEditingController _amountCtl;
  late final TextEditingController _noteCtl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _textCtl = TextEditingController(text: '${widget.win['text'] ?? ''}');
    final amountValue = widget.win['amount'];
    _amountCtl = TextEditingController(
      text: amountValue is num ? _amountControllerText(amountValue) : '',
    );
    _noteCtl = TextEditingController(text: '${widget.win['note'] ?? ''}');
  }

  @override
  void dispose() {
    _textCtl.dispose();
    _amountCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _textCtl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Say what you decided not to buy.');
      return;
    }
    final amountText = _amountCtl.text.trim();
    double? amount;
    if (amountText.isNotEmpty) {
      amount = parseAmount(amountText);
      if (amount == null) {
        setState(() => _error = 'Enter a valid amount.');
        return;
      }
    }
    final note = _noteCtl.text.trim();
    Navigator.of(context).pop();
    await widget.onSave(text, amount, note.isEmpty ? null : note);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Barako.background,
        border: Border.all(color: Barako.border),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit win', style: AppText.title.copyWith(fontSize: 20)),
              const SizedBox(height: 16),
              Text(
                'What did you decide not to buy?',
                style: AppText.caption.tint(Barako.muted),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('mindsetEditWinText'),
                controller: _textCtl,
                style: AppText.body,
                decoration: const InputDecoration(hintText: 'e.g. New shoes'),
              ),
              const SizedBox(height: 12),
              Text(
                'Spending avoided (optional)',
                style: AppText.caption.tint(Barako.muted),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('mindsetEditWinAmount'),
                controller: _amountCtl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: AppText.body,
                decoration: InputDecoration(
                  hintText: 'e.g. 150',
                  prefixText: '$baseCurrencySymbol ',
                  prefixStyle: AppText.body.tint(Barako.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Reflection (optional)',
                style: AppText.caption.tint(Barako.muted),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const Key('mindsetEditWinNote'),
                controller: _noteCtl,
                maxLines: 2,
                style: AppText.body,
                decoration: const InputDecoration(
                  hintText: 'A short reflection',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: AppText.caption.tint(Barako.warningStrong),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: Barako.primary,
                    foregroundColor: Barako.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save changes'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onDelete();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Barako.warningStrong,
                    side: BorderSide(color: Barako.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Delete win'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
