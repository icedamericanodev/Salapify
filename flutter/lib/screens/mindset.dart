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
import '../money/categories.dart'
    show CategoryRow, categoryTree, spentByCategory;
import '../money/currencies.dart' show baseCurrencySymbol;
import '../money/format.dart' show formatMoney;
import '../money/ledger.dart' show amountOf;
import '../money/mindset_waiting.dart' show isDue, revisitLabel, waitingItems;
import '../money/mindset_wins.dart'
    show MindsetSnapshot, mindsetInsight, mindsetSnapshot;
import '../services/notifications.dart' show Reminders;
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
      // true when the budget check is what pushed it there, so impact is
      // never null here in practice. assert() is stripped in release builds
      // though, so this stays a null check with a safe fallback sentence
      // rather than an operator that would crash in production if that
      // invariant were ever broken by a future edit to _computeVerdict.
      if (impact == null) return 'This does not fit your plan right now.';
      return 'The other answers fit your plan, but ${_budgetClause(impact)}';
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
      _checkLogged = false;
    });
    // Same reasoning as _reviewAgain's own scroll-to-top: Clear check sits
    // near the bottom of the Impulse check card, so whatever scrolled it
    // into view (ensureVisible, or a long card above a taller screen) can
    // leave the just-reset neutral state sitting above the fold with
    // nothing on screen to show anything changed.
    if (_listController.hasClients) {
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
        amount: _validAmount,
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
      for (var i = 0; i < _answers.length; i++) {
        _answers[i] = null;
      }
      // Without this, re-answering all three questions in this new
      // considering session would never log a fresh completed check:
      // _checkLogged would still be true from whatever check this screen
      // last completed, so the postFrameCallback's guard would silently
      // skip it.
      _checkLogged = false;
    });
    // Back to the top: the WAITING card the person just tapped from is below
    // the fold, and it is about to lose this row entirely (status is no
    // longer 'waiting'), so without this the refilled considering section
    // sits off screen with nothing but a snackbar to say anything happened.
    if (_listController.hasClients) {
      _listController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SafeArea(
          top: false,
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
    );
  }

  @override
  Widget build(BuildContext context) {
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
            final lesson = lessonFromMap(lessonOfTheDay(DateTime.now()));
            final lessonTitle = _lessonTitleOf(lesson);
            final lessonSummary = _lessonSummaryOf(lesson);
            final categories = _categories();
            final impact = _budgetImpact(categories);
            final verdict = _computeVerdict(_answers, impact);
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
                _categoryId != null;
            final showClear = answered || hasConsiderInput;
            final wins = _wins().reversed.toList();
            final now = DateTime.now();
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
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
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
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
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

  InputDecoration _fieldDecoration({required String hint, String? prefix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Barako.faint),
        prefixText: prefix,
        prefixStyle: AppText.body.tint(Barako.textSecondary),
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
      );

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
                decoration: _fieldDecoration(hint: 'e.g. New shoes'),
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
                decoration: _fieldDecoration(
                  hint: 'e.g. 150',
                  prefix: '$baseCurrencySymbol ',
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
                decoration: _fieldDecoration(hint: 'A short reflection'),
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
