// Set the monthly limit, and a cap per category.
//
// The founder hit this wall directly: a screen called Budget, showing four rows
// that all said "No limit set", with nothing anywhere in the app that could set
// one. Worse than the empty state, because empty at least explains itself.
//
// Both fields already exist in the stored schema and have for twelve versions:
// `settings.monthlyLimit` is what the golden locked `budgetSummary` reads, and
// `monthlyCap` on a category is what the per category rows read. So this writes
// fields the engine already understands and adds no new stored shape.
//
// FREE, not Pro. Decision D19: the shipped app reads monthlyCap only when
// settings.pro is set, that rule is untouched in the engine, and this screen
// does not consult it. A budget app whose budgets sit behind a wall fails the
// core features free forever promise at the first screen a stranger opens.
//
// NOTHING HERE REFUSES A PLAN, and that is a decision rather than an oversight.
// The two refusals in _read are the app reporting its own inability ("that
// amount cannot be read"), which is honest. Refusing a plan is the app saying
// it knows the user's money better than they do, and it traps somebody who is
// mid edit behind an order of entry rule they cannot see: raise a cap first and
// the limit second and a blocking editor stops you between the two. Do not turn
// either note below into a block, an "are you sure" or a one tap "raise your
// limit to match". That last one looks like the friendliest option and is the
// worst, because its effect is to delete the only whole month control in the
// app, and a new user will tap whatever makes the orange text go away.
//
// A CAP IS A CEILING ON ONE CATEGORY, NOT A SHARE OF THE MONTH. That sentence
// is the whole reason the caps are allowed to add up to more than the limit,
// and the earlier version of this file gave the wrong reason: it said people
// deliberately leave headroom on categories they will not all max out. That is
// a behavioural excuse, and if caps really were slices of one pot it would be a
// defect rather than a feature. The real reason is structural and it is in the
// engine: budgetSummary counts EVERY peso, including spending with no category
// at all, which no cap can ever cover. So the caps were never a partition of
// the limit and the two figures were never meant to reconcile.
//
// One cap ALONE being larger than the whole month is a different fact, and it
// is not headroom, it is arithmetic that cannot happen. needsALook in
// budget_rows.dart fires at remaining <= cap * 0.25, so a 50,000 cap inside a
// 20,000 month first warns at 37,500 of spending: 17,500 past the point the
// entire month is gone. The control cannot fire inside the range it monitors,
// which makes it a disabled control that looks armed, strictly worse than the
// honest "No limit set". It also contradicts the screen above it: at 19,000
// spent the hero says 1,000 left of 20,000 while the row says 31,000 left of
// 50,000 in calm grey with a green bar. Two numbers, one ledger, one moment,
// that can never agree. plan_screen.dart already carries a long note about
// exactly that defect class, from the pacing bug that had to be fixed once
// before. So the row says so, in words, as you type.
import 'package:flutter/material.dart';

import '../../app/ledger_scope.dart';
import '../categories/category_rows.dart' show pickableCategories;
import '../../core/money/format.dart';
import '../../core/money/ledger.dart' show amountOf;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../shared/editor_safety.dart';

/// Open the editor. Returns true when something was saved.
///
/// `useRootNavigator`, for the reason spelled out in account_editor.dart: a
/// sheet opened from a tab lands in that tab's Navigator, which the shell
/// draws UNDERNEATH the nav bar, so the save button ends up behind the tabs.
Future<bool> showBudgetEditor(BuildContext context) async {
  final store = context.ledger;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LedgerScope(store: store, child: const _BudgetSheet()),
  );
  return saved ?? false;
}

/// Everything the form used to say out loud, said once, on request.
///
/// Four entries and not one more. A help sheet that grows every time somebody
/// has a thought becomes the wall of text it was built to replace, just one tap
/// further away.
const _help = <(String, String)>[
  (
    'The monthly amount',
    'Everything you spend counts against it, whether or not it has a category.',
  ),
  (
    'A blank cap means no limit',
    'That category is still tracked, it is just never flagged. Zero is not the '
        'same thing: zero means you meant to spend nothing on it.',
  ),
  (
    'Caps can add up to more than the limit',
    'A cap is a ceiling on one category, not a share of the month. Spending '
        'with no category at all still counts against the monthly amount, so '
        'the two figures were never meant to match.',
  ),
  (
    'Unassigned money still counts',
    'Whatever is not inside a category is still spendable and still comes off '
        'your monthly limit. It is usually the best place to find a savings '
        'cap or a debt payment.',
  ),
];

/// The quiet "i". A 36 square target, because an icon drawn at 17 points is
/// not a 17 point button.
class _InfoDot extends StatelessWidget {
  const _InfoDot({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Semantics(
      button: true,
      label: 'How this budget works',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.info_outline_rounded, size: 19, color: skin.text3),
        ),
      ),
    );
  }
}

class _BudgetSheet extends StatefulWidget {
  const _BudgetSheet();

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  final _monthly = TextEditingController();

  /// Focus on the MONTHLY field, watched so the row notes can be silenced
  /// while it is being typed into. Typing "20000" passes through 2, 20, 200
  /// and 2000, and at those moments nearly every cap is above the limit. With
  /// no suppression the sheet lights up with warnings on every row while
  /// somebody enters their headline number, which is an alarm that cries wolf
  /// and then gets ignored during the real fire. Cap fields need no equivalent,
  /// because typing a number upward only passes through smaller prefixes.
  final _monthlyFocus = FocusNode();
  final _caps = <String, TextEditingController>{};
  String? _error;
  var _loaded = false;

  /// One save at a time. The button has no disabled look and the write is a
  /// platform channel round trip taking a tenth of a second or so, which is
  /// long enough for a second tap. Two saves meant two pops, and the second
  /// pop does not close a sheet: see [_closeAfterSaving].
  var _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;

    final data = context.ledger.data;
    final settings = data['settings'] is Map
        ? data['settings'] as Map
        : const {};
    final limit = amountOf(settings['monthlyLimit']);
    if (limit > 0) _monthly.text = moneyField(limit);

    // Every field rebuilds the sheet as it changes, which is what makes the
    // running total and the row notes LIVE. Without these the controllers
    // change text and nothing redraws, so the only place left to say anything
    // is on save, and on save is too late: the sheet closes in the same frame.
    _monthly.addListener(_redraw);
    _monthlyFocus.addListener(_redraw);

    for (final c in _categories) {
      final cap = amountOf(c['monthlyCap']);
      _caps[c['id'] as String] = TextEditingController(
        text: cap > 0 ? moneyField(cap) : '',
      )..addListener(_redraw);
    }
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  /// The categories this form can set a cap on: the ones you can still pick.
  ///
  /// A retired category is kept out because setting a limit on something you
  /// can no longer log against is a control with nothing behind it. Archiving
  /// clears the cap in the same write for the matching reason: a capped row
  /// this form cannot list is a number nobody can ever change again.
  List<Map<String, dynamic>> get _categories => [
    for (final c in pickableCategories(context.ledger.data))
      if (c['id'] is String) c,
  ];

  /// What the monthly field currently says, or null when it cannot be read.
  ///
  /// Zero means "no monthly limit", which is a real state and not an error:
  /// somebody can set per category caps without ever setting a whole month
  /// figure, and the footer says so rather than comparing against nothing.
  double? get _typedMonthly => _read(_monthly.text);

  /// The caps that can be read, summed.
  ///
  /// An unreadable one counts as nothing, which would make the footer quietly
  /// UNDERSTATE the total, so [_unreadableCaps] says how many were skipped and
  /// the footer names them. An earlier version of this claimed in a comment
  /// that it skipped them "so the total is never lower than the truth", which
  /// was the opposite of what the code did.
  double get _typedCapTotal {
    var total = 0.0;
    for (final c in _caps.values) {
      total += readMoney(c.text).value ?? 0;
    }
    return total;
  }

  int get _unreadableCaps =>
      _caps.values.where((c) => readMoney(c.text).value == null).length;

  @override
  void dispose() {
    _monthly.removeListener(_redraw);
    _monthly.dispose();
    _monthlyFocus.dispose();
    for (final c in _caps.values) {
      c
        ..removeListener(_redraw)
        ..dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: skin.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      // The title and the save button are OUTSIDE the scroll view, and only
      // the fields scroll between them. With everything in one scroll view the
      // render showed a sliver of orange at the bottom edge and nothing else:
      // eight categories pushed "Save budget" off the sheet, so the one
      // control the screen exists for was reachable only by scrolling past
      // every field. A form's primary action does not hide behind its own
      // contents.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Set your budget', style: TypeScale.sheetTitle(skin.text)),
              const SizedBox(width: 8),
              // The teaching copy lives behind this, not on the form.
              //
              // The founder looked at the built sheet and said it plainly:
              // "it is too wordy, we can give the user the option to view
              // this". Three explanatory paragraphs were stacked between the
              // fields, and a person who already knows what a budget is has to
              // read past all of them every time they change one number. Help
              // that is always on stops being help and becomes noise.
              //
              // What did NOT move: the running total. That is live data, not
              // teaching, and D21 exists because the thing this sheet had to
              // say was hidden where nobody could see it. Hiding it again
              // behind an icon would undo that fix. Its explanatory half moved
              // in here; its figures stayed on the form.
              _InfoDot(onTap: () => _showHelp(context)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: TypeScale.action(skin.text2)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'For the whole month',
                    style: TypeScale.fieldLabel(skin.text3),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _monthly,
                    focusNode: _monthlyFocus,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TypeScale.input(skin.text),
                    decoration: _box(skin, '20000'),
                  ),

                  const SizedBox(height: 20),
                  Text('Per category', style: TypeScale.fieldLabel(skin.text3)),
                  const SizedBox(height: 12),

                  for (final c in _categories) ...[
                    Row(
                      key: ValueKey('cap-row-${c['id']}'),
                      children: [
                        if ((c['icon'] ?? '').toString().isNotEmpty) ...[
                          Text(
                            (c['icon'] ?? '').toString(),
                            style: TypeScale.rowTitle(skin.text),
                          ),
                          const SizedBox(width: 9),
                        ],
                        Expanded(
                          child: Text(
                            (c['name'] ?? '').toString(),
                            style: TypeScale.rowTitle(skin.text),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _caps[c['id']],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.right,
                            style: TypeScale.input(skin.text),
                            decoration: _box(skin, 'none'),
                          ),
                        ),
                      ],
                    ),
                    // Accent, not `bad`. Red means you did something wrong,
                    // and setting a big cap is not wrong, it is just a cap
                    // that cannot do its job. The note says what will happen
                    // and names the two ways out, then stops.
                    if (_capOverstepsMonth(c['id'] as String)) ...[
                      const SizedBox(height: 6),
                      Text(
                        'More than your ${formatMoney(_typedMonthly ?? 0)} '
                        'monthly limit, so this cap can never warn you. Leave '
                        'it blank for the same result, or raise the monthly '
                        'limit.',
                        style: TypeScale.caption(skin.accent),
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TypeScale.caption(skin.bad)),
          ],

          const SizedBox(height: 12),
          // The running total, always on, never an error. It replaced a
          // save-time warning that no human could ever see: the old code set
          // the message and then saved and closed the sheet in the same frame,
          // so the control existed in the source and nowhere else.
          Text(_runningTotal(), style: TypeScale.caption(skin.text3)),

          const SizedBox(height: 12),
          PillButton(label: 'Save budget', onTap: _save),
        ],
      ),
    );
  }

  /// Whether ONE category's cap is bigger than the whole month.
  ///
  /// Silent while the monthly field is being typed into, and silent when
  /// either number cannot be read yet: a note that appears halfway through a
  /// keystroke is noise, and noise is what gets alarms switched off.
  bool _capOverstepsMonth(String id) {
    if (_monthlyFocus.hasFocus) return false;
    final monthly = _typedMonthly;
    if (monthly == null || monthly <= 0) return false;
    final cap = _read(_caps[id]?.text ?? '');
    if (cap == null || cap <= 0) return false;
    return cap > monthly;
  }

  /// The line under the fields. Figures only, never a lecture.
  ///
  /// It used to run to three sentences, two of which explained what a cap IS.
  /// The founder read the built sheet and said it was too wordy, and they were
  /// right: this sits under every field and is read on every visit, so the
  /// teaching half belongs in [_showHelp], where somebody can ask for it once.
  ///
  /// Every FIGURE stays, and that part is not negotiable. D21 exists because
  /// the thing this sheet needed to say was set with setState and thrown away
  /// in the same frame, so nobody ever saw it. Moving the numbers behind an
  /// icon would be the same defect wearing a nicer hat.
  String _runningTotal() {
    final total = _typedCapTotal;
    final monthly = _typedMonthly;
    final skipped = _unreadableCaps;
    final caveat = skipped == 0
        ? ''
        : skipped == 1
        ? ', 1 unreadable'
        : ', $skipped unreadable';

    if (monthly == null || monthly <= 0) {
      return '${formatMoney(total)} in categories. No monthly limit$caveat';
    }
    if (total > monthly) {
      return '${formatMoney(total)} in categories, '
          '${formatMoney(total - monthly)} over the monthly limit$caveat';
    }
    // The UNASSIGNED figure is the one that changes behaviour rather than just
    // reporting. A semimonthly earner builds the monthly limit out of two
    // sweldos, and the remainder nothing is assigned to is exactly where a
    // savings cap or a debt payment belongs. So the number stays on the form
    // and only the paragraph explaining it moved into the help.
    return '${formatMoney(total)} of ${formatMoney(monthly)} in categories, '
        '${formatMoney(monthly - total)} unassigned$caveat';
  }

  /// What a budget actually is, on request rather than on every visit.
  void _showHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      // SCROLL CONTROLLED, AND THE CONTENT SCROLLS. Without both, this sheet
      // clipped the very words it exists to show: the default cap is nine
      // sixteenths of the screen and a bare Column cannot scroll, so at 320dp
      // the fourth entry was gone entirely and at 1.5x text on a normal phone
      // the last two were. A help sheet that hides its own help is worse than
      // the paragraphs it replaced, because at least those were visible.
      //
      // The render harness could not catch it: it pins 412 by 915 at 1.0x,
      // which is the one size where this happened to fit.
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // The skin is read INSIDE the builder, not captured from the caller, so
      // flipping the system theme with the sheet open repaints it.
      builder: (sheetContext) {
        final skin = sheetContext.skin;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          decoration: BoxDecoration(
            color: skin.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'How this budget works',
                      style: TypeScale.sheetTitle(skin.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.of(sheetContext).pop(),
                    child: Text('Done', style: TypeScale.action(skin.text2)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (title, body) in _help) ...[
                        Text(title, style: TypeScale.fieldLabel(skin.text2)),
                        const SizedBox(height: 5),
                        Text(body, style: TypeScale.caption(skin.text3)),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _box(Skin skin, String hint) => InputDecoration(
    filled: true,
    fillColor: skin.card,
    hintText: hint,
    hintStyle: TypeScale.input(skin.text3),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  /// Blank means "no limit" and returns zero. Unreadable returns null, which is
  /// a refusal rather than a value: silently taking "2o,000" as zero would wipe
  /// a limit somebody had set. See [readMoney] for why plain `double.tryParse`
  /// is not enough, and what "Infinity" used to do to a saved limit.
  double? _read(String raw) => readMoney(raw).value;

  /// The name to put in an error message, without throwing if the category has
  /// gone. A bare `firstWhere` here would replace the message with a StateError
  /// inside a tap handler, which turns a small problem into a crash.
  String _nameOf(String id) {
    for (final c in _categories) {
      if (c['id'] == id) return (c['name'] ?? '').toString();
    }
    return 'that category';
  }

  Future<void> _save() async {
    if (_saving) return;

    final monthly = readMoney(_monthly.text);
    if (monthly.value == null) {
      setState(
        () => _error = monthly.negative
            ? 'The monthly amount cannot be negative.'
            : 'The monthly amount cannot be read.',
      );
      return;
    }

    final caps = <String, double>{};
    for (final entry in _caps.entries) {
      final v = readMoney(entry.value.text);
      if (v.value == null) {
        final name = _nameOf(entry.key);
        setState(
          () => _error = v.negative
              // Says what is actually wrong. Folding "negative" into "cannot
              // be read" tells somebody their perfectly legible -500 is
              // gibberish, which reads as a broken app rather than a rule.
              ? 'The amount for $name cannot be negative.'
              : 'The amount for $name cannot be read.',
        );
        return;
      }
      caps[entry.key] = v.value!;
    }

    // Nothing is compared here on purpose. Everything the user needs to know
    // about how the caps sit against the month has already been on screen,
    // live, while they typed. A save-time verdict on top of that would be a
    // scold, and the last one was worse than useless: it set a message and
    // then closed the sheet in the same frame, so it warned nobody.

    setState(() => _saving = true);
    final store = context.ledger;
    try {
      await store.mutate((draft) {
        final settings = draft['settings'] is Map
            ? Map<String, dynamic>.from(draft['settings'] as Map)
            : <String, dynamic>{};
        settings['monthlyLimit'] = monthly.value;
        draft['settings'] = settings;

        draft['categories'] = [
          for (final c
              in (draft['categories'] is List
                  ? draft['categories'] as List
                  : const []))
            if (c is Map)
              {
                ...c.cast<String, dynamic>(),
                // Falls back to the category's OWN stored cap, not to zero. A
                // category that appeared after this sheet opened has no
                // controller, and defaulting it to zero would wipe a cap the
                // user never saw and never touched.
                'monthlyCap': caps[c['id']] ?? amountOf(c['monthlyCap']),
              },
        ];
      });
    } catch (e) {
      // A failed write used to be indistinguishable from a dead button: the
      // exception became an unhandled async error, no message appeared, and
      // the sheet stayed open. The user then taps again, which is how the
      // double-save above gets triggered in the first place.
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Your budget is unchanged.';
        });
      }
      return;
    }

    if (mounted) closeAfterSaving(context, true);
  }
}
