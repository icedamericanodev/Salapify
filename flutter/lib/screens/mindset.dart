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
import '../money/categories.dart' show categoryTree, spentByCategory;
import '../money/currencies.dart' show baseCurrencySymbol;
import '../money/format.dart' show formatMoney;
import '../money/ledger.dart' show amountOf;
import '../theme.dart';
import '../typography.dart';
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
String _whyText(_Verdict v, List<bool?> answers, Map<String, dynamic>? impact) {
  final essential = answers[0]!;
  final waited24h = answers[2]!;
  final affordableWithoutReserved = answers[1]!;
  final overBudget = impact != null && impact['exceeds'] == true;
  switch (v) {
    case _Verdict.notInPlan:
      if (!affordableWithoutReserved) {
        return overBudget
            ? 'It would use money already reserved for bills, debt, or '
                  'goals, and ${_budgetClause(impact)}'
            : 'It would use money already reserved for bills, debt, or goals.';
      }
      // _computeVerdict only reaches notInPlan with affordableWithoutReserved
      // true when the budget check is what pushed it there.
      assert(overBudget);
      return 'The other answers fit your plan, but ${_budgetClause(impact!)}';
    case _Verdict.pause24h:
      return "It is not essential right now, and you have not wanted it for "
          "a full 24 hours yet.";
    case _Verdict.fitsPlan:
      if (essential) {
        return 'It is essential, and it will not touch money reserved for '
            'bills, debt, or goals.';
      }
      // _computeVerdict only reaches fitsPlan with essential == false when
      // waited24h == true; otherwise it would have returned pause24h.
      assert(waited24h);
      return 'It is not essential, but you have wanted it for at least 24 '
          'hours and it will not touch your reserved money.';
  }
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

  // "What are you considering?": all three are optional context for the
  // decision check, never a transaction. Nothing here is saved; it lives only
  // in this screen's state and is gone the moment the screen closes or Clear
  // check is tapped.
  final _itemName = TextEditingController();
  final _amountText = TextEditingController();
  final _amountFocus = FocusNode();
  String? _categoryId;

  // A ceiling past which a typed amount stops meaning anything for a
  // purchase estimate, the same guard afford_card.dart uses for its own
  // display math, so a pasted absurd number reads as an error instead of
  // silently producing a nonsense budget comparison.
  static const double _amountCeiling = 1e12;

  @override
  void initState() {
    super.initState();
    // The error caption only shows once the field is no longer focused.
    // parseAmount rejects a bare trailing decimal point, so validating on
    // every keystroke flashed "Enter a valid amount." the instant someone
    // typed the "." in "150." and cleared it the moment the next digit
    // landed: a flicker on completely ordinary decimal entry. Rebuilding on
    // focus change (not on every character) is what makes the error appear
    // only once the person has actually moved on.
    _amountFocus.addListener(() => setState(() {}));
  }

  void _clearCheck() {
    setState(() {
      for (var i = 0; i < _answers.length; i++) {
        _answers[i] = null;
      }
      _itemName.clear();
      _amountText.clear();
      _categoryId = null;
    });
  }

  @override
  void dispose() {
    _winText.dispose();
    _itemName.dispose();
    _amountText.dispose();
    _amountFocus.dispose();
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

  /// A validation message for the amount field, or null when it is empty
  /// (a legitimate "not answering this" state, not an error), holds a usable
  /// number, or the field is still focused (mid-type: see _amountFocus above,
  /// this is deliberately not evaluated while the person is still typing).
  String? get _amountError {
    if (_amountFocus.hasFocus) return null;
    final text = _amountText.text.trim();
    if (text.isEmpty) return null;
    final v = parseAmount(text);
    if (v == null) return 'Enter a valid amount.';
    if (v > _amountCeiling) return 'That amount is too large to check.';
    return null;
  }

  List<Map<String, dynamic>> _categories() => [
    for (final c in (widget.store.data['categories'] as List? ?? const []))
      if (c is Map) c.cast<String, dynamic>(),
  ];

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
  Map<String, dynamic>? _budgetImpact(List<Map<String, dynamic>> categories) {
    final categoryId = _categoryId;
    if (categoryId == null) return null;
    final amount = _validAmount;
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

  void _addWin() {
    final text = _winText.text.trim();
    if (text.isEmpty) return;
    // If saving is off (a prior load failed), keep the typed win in the box
    // rather than silently eating it, and never write over data we could not
    // read.
    if (!widget.store.canWrite) return;
    widget.store.addWin(text);
    _winText.clear();
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
    final text = w['text'];
    widget.store.deleteWin(id);
    // A win is user-typed content, so offer a one tap undo rather than losing
    // it silently on a stray tap.
    if (text is String && text.isNotEmpty) {
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
                if (widget.store.canWrite) widget.store.addWin(text);
              },
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = lessonFromMap(lessonOfTheDay(DateTime.now()));
    final lessonTitle = _lessonTitleOf(lesson);
    final lessonSummary = _lessonSummaryOf(lesson);
    final categories = _categories();
    final impact = _budgetImpact(categories);
    final verdict = _computeVerdict(_answers, impact);
    final answered = _answers.any((a) => a != null);
    final hasConsiderInput =
        _itemName.text.trim().isNotEmpty ||
        _amountText.text.trim().isNotEmpty ||
        _categoryId != null;
    final showClear = answered || hasConsiderInput;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Money mindset',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final wins = _wins().reversed.toList();
            return ListView(
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
                              _considerSection(categories),
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
                          child: _verdictSection(verdict, impact),
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

                // Small wins.
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
                      onPressed: _addWin,
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
  Widget _verdictSection(_Verdict? verdict, Map<String, dynamic>? impact) {
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
            _whyText(verdict, _answers, impact),
            style: AppText.small.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  // "What are you considering?": item name, estimated amount, and category,
  // all optional. Nothing here creates a transaction or touches a balance;
  // it only feeds the budget-impact comparison below and the verdict above.
  Widget _considerSection(List<Map<String, dynamic>> categories) {
    final amountError = _amountError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WHAT ARE YOU CONSIDERING?', style: Barako.cardKickerStyle),
        const SizedBox(height: 10),
        Text('Item (optional)', style: AppText.caption.tint(Barako.muted)),
        const SizedBox(height: 6),
        _itemNameField(),
        const SizedBox(height: 12),
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
    focusNode: _amountFocus,
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
  // invented fresh: one selection, tap again to clear it.
  Widget _categoryChips(List<Map<String, dynamic>> categories) {
    final rows = categoryTree(categories);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final row in rows)
          ChoiceChip(
            label: Text(_categoryLabel(row.cat)),
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

  String _categoryLabel(Map<String, dynamic> cat) {
    final icon = '${cat['icon'] ?? ''}';
    final name = '${cat['name'] ?? 'Category'}';
    return icon.isEmpty ? name : '$icon $name';
  }

  // Only rendered when _budgetImpact returned non-null: a valid amount, a
  // chosen category, and a real Pro monthly cap all lined up. Read-only,
  // exactly like AffordCard; nothing here saves or spends anything.
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

  Widget _winRow(Map<String, dynamic> w, bool divided) {
    return Container(
      decoration: divided
          ? BoxDecoration(
              border: Border(top: BorderSide(color: Barako.border, width: 0.5)),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          SalapifyGlyph('celebrate', size: 18, boxed: false),
          const SizedBox(width: 8),
          Expanded(child: Text('${w['text'] ?? ''}', style: AppText.body)),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _deleteWin(w),
            iconSize: 18,
            visualDensity: VisualDensity.standard,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            tooltip: 'Delete win',
            icon: Icon(salapifyIcon('close'), color: Barako.faint),
          ),
        ],
      ),
    );
  }
}
