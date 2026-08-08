// The utang ledger: who owes you, aged, and now actionable. Per-person
// groups come from the golden-verified utangAging engine; tapping a person
// opens the action hub the UX critique asked for (log a payment, mark paid,
// undo a fat-fingered payment) built on the golden-verified receivables
// engine. Warning color stays reserved for genuinely overdue money, amounts
// use tabular figures, and every money action confirms or can be reversed,
// never both silent and permanent.

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/store.dart';
import '../money/receivables.dart' as engine;
import '../money/statement.dart';
import '../money/splits.dart' as splits;
import '../money/utang.dart';
import '../theme.dart';
import '../typography.dart';
import '../money/milestones.dart' show milestoneFor;
import '../widgets/celebration.dart';
import 'milestone_share.dart' show showMilestoneCelebration;
import '../widgets/empty_state.dart';
import '../widgets/screen_header.dart';
import '../widgets/salapify_icon.dart';
import 'log_sheet.dart' show parseAmount;
import 'overview.dart' show formatMoney, prettyDay;
import '../money/ledger.dart' as ledger;
import '../widgets/section.dart' show Kicker;
import '../widgets/entry_form.dart' show AmountField;
import '../widgets/choice_chip.dart';
import '../money/currencies.dart' show baseCurrencySymbol;

/// The open receivables behind one aging row. utangAging folds rows by the
/// lowercased resolved name (personId row and legacy name row together), so
/// the action hub must gather by the same rule or a person's older utang
/// would silently miss from their own sheet.
bool _belongsTo(
  Map<String, dynamic> data,
  Map<String, dynamic> r,
  String key,
  String personId,
) {
  // The person's OWN id wins, exactly as the RN person screen does. Matching
  // on name alone merged two different people who happen to share one, and
  // this sheet now builds a document that gets sent to one of them: QA
  // reproduced Ana being handed a statement billing her for ₱7,000 of another
  // Ana's debt. A name is not an identity.
  final rowId = r['personId'];
  if (personId.isNotEmpty) {
    if (rowId is String && rowId.isNotEmpty) return rowId == personId;
    // Utang logged before person records existed carry no id at all. RN drops
    // those when opening by id; keeping them is the one deliberate difference,
    // because dropping them UNDERSTATES a real debt in a real document, and
    // an unlinked row cannot belong to anybody else.
    return engine.nameOf(data, r).trim().toLowerCase() == key;
  }
  return engine.nameOf(data, r).trim().toLowerCase() == key;
}

List<Map<String, dynamic>> openUtangFor(
  Map<String, dynamic> data,
  String name, {
  String personId = '',
}) {
  final key = name.trim().toLowerCase();
  final out = <Map<String, dynamic>>[];
  for (final r
      in (data['receivables'] as List? ?? []).cast<Map<String, dynamic>>()) {
    if (r['paid'] == true) continue;
    if (engine.remainingOf(r) <= 0) continue;
    if (_belongsTo(data, r, key, personId)) out.add(r);
  }
  return out;
}

/// A date for a list that spans years. prettyDay gives "Jul 10", which is
/// right on Home where everything is recent and wrong here: a payment history
/// exists to be read in order, and 2025-07-10 and 2026-07-10 rendered
/// identically in a column whose whole point is chronology. The year appears
/// only when it is not this one, so the common case stays short.
String _dayMaybeYear(String iso) {
  final short = prettyDay(iso);
  if (short == iso || iso.length < 4) return short;
  final year = iso.substring(0, 4);
  return year == '${DateTime.now().year}' ? short : '$short, $year';
}

/// EVERY utang for one person, settled ones included, oldest row order kept.
///
/// The action hub used to gather only what was still open, which was right for
/// the buttons and wrong for everything else: a statement built from open rows
/// alone silently drops the utang they already paid, so it can neither prove
/// they paid nor add up to the total ever lent. The same rule folds personId
/// rows and legacy name rows together, so a person's whole history arrives.
List<Map<String, dynamic>> allUtangFor(
  Map<String, dynamic> data,
  String name, {
  String personId = '',
}) {
  final key = name.trim().toLowerCase();
  final out = <Map<String, dynamic>>[];
  for (final r
      in (data['receivables'] as List? ?? []).cast<Map<String, dynamic>>()) {
    if (_belongsTo(data, r, key, personId)) out.add(r);
  }
  return out;
}

/// The stored person record behind a name, when there is one. Legacy utang
/// carry only a name string, so this is allowed to come back null and every
/// caller falls back to the resolved display name.
Map<String, dynamic>? personRecordFor(
  Map<String, dynamic> data,
  String name, {
  String personId = '',
}) {
  final people = (data['people'] as List? ?? []).cast<Map<String, dynamic>>();
  // By id first. Falling straight to the name returned whichever same-named
  // person happened to be stored first, so the statement could carry one
  // person's saved phone and note while listing another person's utang.
  if (personId.isNotEmpty) {
    for (final p in people) {
      if (p['id'] == personId) return p;
    }
  }
  final key = name.trim().toLowerCase();
  for (final p in people) {
    final n = p['name'];
    if (n is String && n.trim().toLowerCase() == key) return p;
  }
  return null;
}

/// The tab shape as it existed before the merge: header plus body. Kept as a
/// widget because tests and the shell's transition period mount it directly;
/// the Money tab mounts [UtangBody] under its own shared header instead.
class UtangScreen extends StatelessWidget {
  final SalapifyStore store;
  final VoidCallback? onMenu;
  const UtangScreen({super.key, required this.store, this.onMenu});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: UtangBody(
        store: store,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        header: ScreenHeader(
          'Utang',
          subtitle: 'Money owed to you, oldest first',
          onMenu: onMenu,
          trailing: store.canWrite ? newUtangButton(context, store) : null,
        ),
      ),
    );
  }
}

/// The filled create action, shared by the standalone header and the Money
/// tab's "Owed to me" segment so the two cannot drift.
Widget newUtangButton(BuildContext context, SalapifyStore store) =>
    FilledButton.icon(
      onPressed: () => showAddUtangSheet(context, store),
      icon: Icon(salapifyIcon('add'), size: 18),
      label: const Text('New'),
      style: FilledButton.styleFrom(
        backgroundColor: Barako.primary,
        foregroundColor: Barako.onPrimary,
        // Filled, and at the 48 floor. A create action demoted from a FAB
        // must not also become a small grey word.
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
      ),
    );

/// Who owes you, as a plain scrolling body with no header of its own.
class UtangBody extends StatelessWidget {
  final SalapifyStore store;
  final ScrollController? controller;
  final EdgeInsets padding;

  /// Rendered as the first child when present, so it scrolls with the list.
  final Widget? header;
  const UtangBody({
    super.key,
    required this.store,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 96),
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    final aging = utangAging(store.data, DateTime.now());
    final people = (aging['people'] as List).cast<Map<String, dynamic>>();
    final total = aging['totalOutstanding'] as double;
    final overdueTotal = aging['overdueTotal'] as double;
    final overdueCount = aging['overdueCount'] as int;

    return ListView(
      controller: controller,
      padding: padding,
      children: [
        ?header,
        if (people.isEmpty)
          EmptyState(
            icon: 'handshake',
            showPan: true,
            title: 'Nobody owes you right now',
            // Names the button by its label and its place. The button moved
            // from a FAB in the corner to the top of the screen, and an
            // empty state that still said "tap New utang" would be sending a
            // first-time user to look for something that is not there.
            body:
                'When someone borrows, tap New at the top to log it, so it '
                'never gets awkward later. Salapify keeps the running '
                'total and the date, so you never have to be the one '
                'who remembers.',
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "Out" was lending-desk shorthand only its author
                  // understood; the segment is "Owed to me", so the kicker
                  // extends it instead of riddling it.
                  Text('STILL UNPAID', style: Barako.cardKickerStyle),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatMoney(total),
                      maxLines: 1,
                      style: AppText.amountLg.w7.tint(Barako.primary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    overdueCount > 0
                        ? '${formatMoney(overdueTotal)} of it is overdue with $overdueCount ${overdueCount == 1 ? 'person' : 'people'}. Follow up gently, oldest first.'
                        : 'Nothing is overdue yet, so a gentle reminder is enough.',
                    style: AppText.small.copyWith(
                      color: overdueCount > 0 ? Barako.warning : Barako.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _splitsSection(),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < people.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: Barako.border),
                    _PersonRow(
                      person: people[i],
                      onTap: () => showPersonSheet(
                        context,
                        store,
                        people[i]['name'] as String,
                        personId: (people[i]['personId'] as String?) ?? '',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _splitsSection() {
    // The per-activity fold lives in the tested splits engine, not here, so the
    // totals are covered by a vector. This is a pure display lens; each share
    // still appears in the golden-locked per-person aging below.
    final groups = splits.activitySummaries(store.data['receivables']);
    if (groups.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text('SPLITS', style: Barako.cardKickerStyle),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < groups.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: Barako.border),
                  _activityRow(groups[i]),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _activityRow(Map<String, dynamic> g) {
    final label = g['label'] as String;
    final stillOut = g['stillOut'] as double;
    final count = g['people'] as int;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(salapifyIcon('split'), size: 18, color: Barako.primaryText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.w7,
                ),
                const SizedBox(height: 2),
                Text(
                  '$count ${count == 1 ? 'person owes you' : 'people owe you'}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${formatMoney(stillOut)} out',
            style: AppText.amountRow
                .copyWith(fontSize: 14)
                .w8
                .tint(Barako.primaryText),
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final Map<String, dynamic> person;
  final VoidCallback onTap;
  const _PersonRow({required this.person, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final days = person['daysOverdue'] as int;
    final count = person['count'] as int;
    final overdue = days > 0;
    final sub = overdue
        ? 'Overdue $days ${days == 1 ? 'day' : 'days'}'
        : (person['oldestDue'] as String).isNotEmpty
        // _dayMaybeYear, not the raw stored value. This printed
        // "Due 2026-08-15" on the Owed to me list for its whole life: the same
        // machine-date-in-a-sentence defect f2.84 fixed on Insights, on a
        // screen about asking a friend for money, where reading like a
        // spreadsheet is the last thing wanted.
        //
        // The guard written for that fix did not catch this one. It matched
        // four hardcoded key names and this key is called oldestDue, so a test
        // that reads as "no raw dates in copy" actually meant "not those four
        // spellings". The helper it needs was already in this file, ten lines
        // up, with a comment explaining why a utang list in particular needs
        // the year.
        ? 'Due ${_dayMaybeYear(person['oldestDue'] as String)}'
        : 'No due date';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person['name'] as String, style: AppText.bodyLg.w6),
                  const SizedBox(height: 2),
                  Text(
                    '$sub · $count ${count == 1 ? 'entry' : 'entries'}',
                    style: AppText.caption.tint(
                      overdue ? Barako.warning : Barako.muted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatMoney(person['outstanding'] as double),
              style: AppText.amountRow
                  .copyWith(fontSize: 16)
                  .tint(overdue ? Barako.warning : Barako.textSecondary),
            ),
            const SizedBox(width: 6),
            Icon(salapifyIcon('forward'), color: Barako.faint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Person action hub: every open utang for one person, with log payment,
// mark paid, and remove payment. Rebuilt live from the store so a logged
// payment updates the sheet in place.
// ---------------------------------------------------------------------------

/// How a built statement or reminder leaves the app. Injectable so a test can
/// assert the EXACT text that would reach someone's chat app: a test that only
/// proves a Share button exists proves nothing about the document it sends,
/// and the document is the whole feature.
typedef ShareText = Future<void> Function(String text);

/// Hands the text to the OS. Throws when there is genuinely nowhere to send
/// it, which the caller turns into a message.
///
/// It used to swallow every exception with a comment about the user closing
/// the sheet. Dismissal IS harmless, but it is not the only thing that lands
/// here: with no share target installed, or on the web preview where
/// navigator.share does not exist, the person picked a language and then
/// absolutely nothing happened, with no explanation. Dismissal returns
/// normally from share_plus; a real failure throws, so the two can be told
/// apart rather than both being ignored.
Future<void> _shareViaOs(String text) => Share.share(text);

Future<void> showPersonSheet(
  BuildContext context,
  SalapifyStore store,
  String name, {
  String personId = '',
  ShareText? share,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Barako.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: PersonSheet(
        store: store,
        name: name,
        personId: personId,
        share: share,
      ),
    ),
  );
}

class PersonSheet extends StatefulWidget {
  final SalapifyStore store;
  final String name;

  /// The stored person's id when the utang are linked to one. Empty for
  /// legacy name-only utang, which is why it cannot simply be required.
  final String personId;
  final ShareText? share;
  const PersonSheet({
    super.key,
    required this.store,
    required this.name,
    this.personId = '',
    this.share,
  });

  @override
  State<PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends State<PersonSheet> {
  final payController = TextEditingController();
  String? payingFor; // receivable id the payment field is open for
  String? error;
  bool busy = false;

  @override
  void dispose() {
    payController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (mounted) setState(() => busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Nothing was changed. $e';
        });
      }
    }
  }

  Future<void> _logPayment(Map<String, dynamic> r) async {
    final amount = parseAmount(payController.text);
    if (amount == null) {
      setState(
        () => error = 'Enter a plain amount above zero, like 250 or 99.50.',
      );
      return;
    }
    final text = payController.text;
    // Whether this payment settles the utang, decided BEFORE the write from
    // the same numbers the engine will use, so the celebration can never
    // fire on a still-open balance.
    final settles = amount >= engine.remainingOf(r);
    await _run(() async {
      await widget.store.collectUtangPayment((r['id'] ?? '').toString(), text);
      // The sheet may have been dismissed while the save was in flight; the
      // payment is already persisted, so only touch the controller if the
      // widget is still alive.
      if (mounted) {
        payController.clear();
        payingFor = null;
        if (settles) {
          _celebrateUtang(r);
        }
      }
    });
  }

  // Confetti, then the branded card to share. milestoneFor returns null for a
  // shape the engine does not count as a settled utang, in which case the
  // moment still earns the plain confetti.
  void _celebrateUtang(Map<String, dynamic> r) {
    final win = milestoneFor(widget.store.data, (r['id'] ?? '').toString());
    if (win != null) {
      showMilestoneCelebration(context, win);
    } else {
      showCelebration(context, '${widget.name} paid you back in full.');
    }
  }

  Future<void> _markPaid(Map<String, dynamic> r) async {
    final remaining = engine.remainingOf(r);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text('Mark as paid?', style: TextStyle(color: Barako.text)),
        content: Text(
          'Log ${formatMoney(remaining)} from ${widget.name} as received and mark it settled?',
          style: TextStyle(color: Barako.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: Barako.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Mark paid', style: TextStyle(color: Barako.primary)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // Only a real balance reaching zero celebrates; closing an already
    // settled row is bookkeeping, the RN guard.
    await _run(() => widget.store.markUtangPaid((r['id'] ?? '').toString()));
    if (mounted && remaining > 0) {
      _celebrateUtang(r);
    }
  }

  Future<void> _removePayment(
    Map<String, dynamic> r,
    Map<String, dynamic> p,
  ) async {
    final linked = p['txnId'] is String && (p['txnId'] as String).isNotEmpty;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text('Remove payment?', style: TextStyle(color: Barako.text)),
        content: Text(
          linked
              ? 'Remove this ${formatMoney((p['amount'] as num).toDouble())} payment? Its money entry will be reversed too.'
              : 'Remove this ${formatMoney((p['amount'] as num).toDouble())} payment? It was logged before payment tracking, so no money entry is linked to reverse.',
          style: TextStyle(color: Barako.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: Barako.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Remove', style: TextStyle(color: Barako.warning)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => widget.store.removeUtangPayment(
        (r['id'] ?? '').toString(),
        (p['id'] ?? '').toString(),
      ),
    );
  }

  /// Ask which language the message should be written in, then hand the built
  /// text to the OS. The picker itself is English, like the rest of the app;
  /// the choice is about a message the user SENDS to someone else, in whatever
  /// language the two of them actually talk in.
  Future<void> _shareWithLanguage(
    String title,
    String Function(StatementLang) build,
  ) async {
    final lang = await showDialog<StatementLang>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text(title, style: TextStyle(color: Barako.text)),
        content: Text(
          'Which language should the message be in?',
          style: TextStyle(color: Barako.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel', style: TextStyle(color: Barako.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(StatementLang.tl),
            child: Text('Tagalog', style: TextStyle(color: Barako.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(StatementLang.en),
            child: Text('English', style: TextStyle(color: Barako.primary)),
          ),
        ],
      ),
    );
    if (lang == null) return;
    // The dialog was itself an await, so the sheet may already be gone by
    // now. Checked before context is touched, then the messenger is captured
    // so the catch below never reaches across the share await.
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await (widget.share ?? _shareViaOs)(build(lang));
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Could not open the share sheet. Nothing was sent.'),
        ),
      );
    }
  }

  Future<void> _shareStatement(List<Map<String, dynamic>> all) {
    final person =
        personRecordFor(
          widget.store.data,
          widget.name,
          personId: widget.personId,
        ) ??
        {'name': widget.name};
    return _shareWithLanguage(
      'Share statement',
      (lang) =>
          // formatMoney, not the RN whole peso formatter: the sheet above
          // this button shows centavos, and a statement that rounds them away
          // prints two ₱100.50 utang as ₱101 and ₱101 over a total of ₱201.
          buildPersonStatement(
            person,
            all,
            lang: lang,
            asOf: DateTime.now(),
            money: formatMoney,
          ),
    );
  }

  Future<void> _remind(double owed) {
    final person =
        personRecordFor(
          widget.store.data,
          widget.name,
          personId: widget.personId,
        ) ??
        {'name': widget.name};
    return _shareWithLanguage(
      'Send a reminder',
      (lang) =>
          buildPersonReminder(person, owed, lang: lang, money: formatMoney),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final items = openUtangFor(
          widget.store.data,
          widget.name,
          personId: widget.personId,
        );
        final all = allUtangFor(
          widget.store.data,
          widget.name,
          personId: widget.personId,
        );
        final settled = all.where((r) => !items.contains(r)).toList();
        final history = engine.personPaymentHistory(all);
        final total = items.fold(0.0, (t, r) => t + engine.remainingOf(r));
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Barako.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(widget.name, style: AppText.title),
                Text(
                  items.isEmpty
                      ? 'All settled. Thank you, ${widget.name}!'
                      : '${formatMoney(total)} still out',
                  style: AppText.small.tint(
                    items.isEmpty ? Barako.primaryText : Barako.muted,
                  ),
                ),
                const SizedBox(height: 12),
                if (all.isNotEmpty) _actionRow(all, total),
                for (final r in items) _utangCard(r),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: AppText.small.tint(Barako.warning)),
                ],
                if (settled.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Kicker('SETTLED'),
                  const SizedBox(height: 8),
                  for (final r in settled) _settledRow(r),
                ],
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Kicker('PAYMENT HISTORY'),
                  const SizedBox(height: 8),
                  for (final p in history) _paymentRow(p, all),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Remind, and the statement. Remind only appears while something is
  /// actually owed: a reminder about nothing is just an accusation.
  Widget _actionRow(List<Map<String, dynamic>> all, double owed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (owed > 0) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Barako.primary),
                foregroundColor: Barako.primary,
                minimumSize: const Size(0, 44),
              ),
              onPressed: busy ? null : () => _remind(owed),
              icon: Icon(salapifyIcon('send'), size: 16),
              label: const Text('Remind'),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Barako.primary,
                foregroundColor: Barako.onPrimary,
                minimumSize: const Size(0, 44),
              ),
              onPressed: busy ? null : () => _shareStatement(all),
              icon: Icon(salapifyIcon('document'), size: 16),
              label: const Text('Share statement'),
            ),
          ),
        ],
      ),
    );
  }

  /// A settled utang, shown but not actionable. It is here so the person's
  /// history is complete and the statement's total lent can be checked against
  /// what is on screen, not so anything can be done to it.
  Widget _settledRow(Map<String, dynamic> r) {
    // The utang itself, always. The first version printed remainingOf when it
    // was positive and the raw num otherwise, and QA found both halves wrong:
    // a stored amount of "2400" (a string, from a restored backup) is not a
    // num, so the row read "₱0 paid" beside a statement saying ₱2,400; and a
    // ₱2,000 utang marked paid with a ₱750 logged payment read "₱1,250 paid",
    // which is what was LEFT, labelled as what was paid. amountOf coerces the
    // same way every other money read in the app does.
    final amount = ledger.amountOf(r['amount']);
    final note = (r['note'] ?? '').toString();
    return Semantics(
      label: '${note.isEmpty ? 'Utang' : note}, ${formatMoney(amount)}, paid',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(salapifyIcon('done'), color: Barako.muted, size: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                note.isEmpty ? 'Utang' : note,
                style: AppText.small,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${formatMoney(amount)} paid',
              style: AppText.small.tint(Barako.muted).tabular,
            ),
          ],
        ),
      ),
    );
  }

  /// One payment, with the running total received as of that payment. Reading
  /// down the list the running figure counts DOWN, because the newest payment
  /// is the one they have paid the most by.
  Widget _paymentRow(engine.PaymentRow p, List<Map<String, dynamic>> all) {
    final when = p.date.isEmpty ? '' : '${_dayMaybeYear(p.date)} · ';
    // The stored maps behind this row, so the remove action reverses exactly
    // the payment shown. rid picks the utang first, which is what makes this
    // safe: a restored backup can give two payments on two DIFFERENT utang
    // the same payment id, and matching on the id alone would remove whichever
    // came first.
    final source = _sourceOf(p, all);
    return Semantics(
      label:
          '${formatMoney(p.amount)} received'
          '${p.date.isEmpty ? '' : ' on ${_dayMaybeYear(p.date)}'} for ${p.from}. '
          '${formatMoney(p.running)} paid back in total by then.',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: formatMoney(p.amount),
                      style: TextStyle(
                        color: Barako.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: '  $when${p.from}',
                      style: TextStyle(color: Barako.muted, fontSize: 12),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${formatMoney(p.running)} paid by then',
              style: AppText.caption.tint(Barako.faint),
            ),
            if (source != null)
              InkWell(
                onTap: busy ? null : () => _removePayment(source.$1, source.$2),
                customBorder: const CircleBorder(),
                // A real 44dp tap target around a deliberately small icon.
                child: Semantics(
                  button: true,
                  label: 'Remove this payment',
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      salapifyIcon('close'),
                      color: Barako.faint,
                      size: 14,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }

  /// The receivable and payment maps a history row came from, or null when
  /// neither can be found (a store that changed under a stale row).
  (Map<String, dynamic>, Map<String, dynamic>)? _sourceOf(
    engine.PaymentRow p,
    List<Map<String, dynamic>> all,
  ) {
    for (final r in all) {
      if ('${r['id'] ?? ''}' != p.rid) continue;
      for (final pay in (r['payments'] as List? ?? []).whereType<Map>()) {
        if ('${pay['id'] ?? ''}' == p.id) {
          return (r, pay.cast<String, dynamic>());
        }
      }
    }
    return null;
  }

  Widget _utangCard(Map<String, dynamic> r) {
    final remaining = engine.remainingOf(r);
    final amount = (r['amount'] is num) ? (r['amount'] as num).toDouble() : 0.0;
    final paidPart = engine.paidSumOf(r);
    final due = (r['dueDate'] ?? '').toString();
    final note = (r['note'] ?? '').toString();
    final rId = (r['id'] ?? '').toString();
    final open = payingFor == rId;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    paidPart > 0
                        ? '${formatMoney(remaining)} left of ${formatMoney(amount)}'
                        : formatMoney(remaining),
                    style: AppText.amountRow.copyWith(fontSize: 17),
                  ),
                ),
                Text(
                  due.isNotEmpty ? 'due ${_dayMaybeYear(due)}' : 'no due date',
                  style: AppText.caption,
                ),
              ],
            ),
            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(note, style: AppText.caption.tint(Barako.faint)),
              ),
            // The payments used to be listed HERE as well as under PAYMENT
            // HISTORY, so every payment appeared twice on one sheet, once
            // removable and once not, and a person with 200 payments rendered
            // 400 rows. One list now, the chronological one, which is also the
            // only one that can carry a running total or show a payment
            // against an utang that has since been settled. The remove action
            // moved there with it.
            const SizedBox(height: 10),
            if (open) ...[
              TextField(
                controller: payController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: AppText.heading,
                // The theme decoration carries the fill and borders now; only
                // the hint and the currency prefix are this field's own. The
                // hint stays label sized because it is a sentence, not a
                // figure, and would shout at heading size.
                decoration: InputDecoration(
                  hintText: 'How much came back?',
                  hintStyle: AppText.label.w4.tint(Barako.faint),
                  prefixText: '$baseCurrencySymbol ',
                  prefixStyle: AppText.heading.tint(Barako.muted),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Barako.primary,
                        foregroundColor: Barako.onPrimary,
                      ),
                      onPressed: busy ? null : () => _logPayment(r),
                      child: Text(
                        busy ? 'Saving...' : 'Save payment',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            payingFor = null;
                            payController.clear();
                          }),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Barako.muted),
                    ),
                  ),
                ],
              ),
            ] else
              Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Barako.border),
                      foregroundColor: Barako.text,
                    ),
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            payingFor = rId;
                            payController.clear();
                            error = null;
                          }),
                    child: const Text('Log payment'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Barako.border),
                      foregroundColor: Barako.primary,
                    ),
                    onPressed: busy ? null : () => _markPaid(r),
                    child: const Text('Mark paid'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// New utang sheet: person (with chips for existing people), amount, optional
// due date, optional source account for the lending cash leg.
// ---------------------------------------------------------------------------

Future<void> showAddUtangSheet(BuildContext context, SalapifyStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Barako.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: AddUtangSheet(store: store),
    ),
  );
}

class AddUtangSheet extends StatefulWidget {
  final SalapifyStore store;
  const AddUtangSheet({super.key, required this.store});

  @override
  State<AddUtangSheet> createState() => _AddUtangSheetState();
}

class _AddUtangSheetState extends State<AddUtangSheet> {
  final personController = TextEditingController();
  final amountController = TextEditingController();
  final dueController = TextEditingController();
  final noteController = TextEditingController();
  String fromAccount = '';
  String? error;
  bool saving = false;

  @override
  void dispose() {
    personController.dispose();
    amountController.dispose();
    dueController.dispose();
    noteController.dispose();
    super.dispose();
  }

  String _plusDays(int days) {
    final d = DateTime.now().add(Duration(days: days));
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (saving) return;
    // The same strict parse as every other money field: a bare comma decimal
    // like 2,50 is rejected with guidance, never silently read as 250 (which
    // would move 250 real pesos out of the source account).
    final amount = parseAmount(amountController.text);
    if (amount == null) {
      setState(
        () => error = amountController.text.contains(',')
            ? 'Use a period for centavos, like 2.50. Commas only group thousands.'
            : 'Enter a plain amount above zero, like 250 or 99.50.',
      );
      return;
    }
    setState(() {
      error = null;
      saving = true;
    });
    try {
      await widget.store.addUtang(
        person: personController.text,
        amountText: amount.toString(),
        dueDate: dueController.text,
        note: noteController.text,
        fromAccount: fromAccount,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e is ArgumentError
              ? e.message.toString()
              : 'Could not save, so nothing was changed. $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = (widget.store.data['people'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where((p) => p['name'] is String && (p['name'] as String).isNotEmpty)
        .toList();
    final accounts = (widget.store.data['accounts'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where((a) => a['id'] is String && (a['id'] as String).isNotEmpty)
        .toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Barako.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'NEW UTANG',
              style: AppText.heading.w8.copyWith(letterSpacing: 2),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: personController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: AppText.bodyLg,
              decoration: const InputDecoration(
                hintText: 'Who borrowed? e.g. Juan',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (people.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in people)
                    ActionChip(
                      label: Text(p['name'] as String),
                      backgroundColor: Barako.card,
                      labelStyle: TextStyle(
                        color: Barako.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(color: Barako.border),
                      onPressed: () => setState(
                        () => personController.text = p['name'] as String,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            AmountField(controller: amountController),
            const SizedBox(height: 10),
            // Read only, tap to pick. This used to ask a phone keyboard for
            // hand-typed ISO 8601, on a field that later drives overdue
            // math; any typo was silent until "why is this not overdue".
            // The picker writes the same YYYY-MM-DD string the store
            // expects, so a stored date can no longer be malformed.
            TextField(
              controller: dueController,
              readOnly: true,
              style: AppText.bodyLg,
              decoration: InputDecoration(
                hintText: 'Due date (optional), tap to pick',
                suffixIcon: dueController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear due date',
                        icon: Icon(
                          salapifyIcon('close'),
                          size: 18,
                          color: Barako.muted,
                        ),
                        onPressed: () => setState(() => dueController.clear()),
                      ),
              ),
              onTap: () async {
                final now = DateTime.now();
                final current = DateTime.tryParse(dueController.text);
                final picked = await showDatePicker(
                  context: context,
                  initialDate: current ?? now.add(const Duration(days: 7)),
                  firstDate: now.subtract(const Duration(days: 1)),
                  lastDate: DateTime(now.year + 5),
                );
                if (picked != null) {
                  setState(
                    () => dueController.text = picked
                        .toIso8601String()
                        .substring(0, 10),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (label, days) in [
                  ('In 1 week', 7),
                  ('In 2 weeks', 14),
                  ('In 30 days', 30),
                ])
                  ActionChip(
                    label: Text(label),
                    backgroundColor: Barako.card,
                    labelStyle: TextStyle(
                      color: Barako.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: Barako.border),
                    onPressed: () =>
                        setState(() => dueController.text = _plusDays(days)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              style: AppText.bodyLg,
              decoration: const InputDecoration(
                hintText: 'Note, like "sa jeep" (optional)',
              ),
            ),
            if (accounts.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'WHERE DID THE MONEY LEAVE FROM?',
                style: Barako.cardKickerStyle,
              ),
              const SizedBox(height: 4),
              Text(
                'Pick an account and the lent amount moves out of it now, '
                'then comes back when they pay. Skip it to just track what is owed.',
                style: AppText.caption.tint(Barako.faint),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _accountChip('Just track it', ''),
                  for (final a in accounts)
                    _accountChip(
                      a['name']?.toString() ?? 'Account',
                      a['id'] as String,
                    ),
                ],
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: AppText.small.tint(Barako.warning)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Barako.primary,
                  foregroundColor: Barako.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: saving ? null : _save,
                child: Text(
                  saving ? 'Saving...' : 'Save',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountChip(String label, String id) {
    return SalapifyChoiceChip(
      label: label,
      selected: fromAccount == id,
      onSelected: (_) => setState(() => fromAccount = id),
    );
  }
}
