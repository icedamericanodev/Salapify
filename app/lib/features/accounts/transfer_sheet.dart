// Move money between two of your own accounts.
//
// A PORT, not a rewrite. The shipped app's transfer sheet (flutter/lib/screens/
// accounts.dart, _TransferSheet) has had a year of edge cases found in it, and
// every one of them is kept here: the two-account minimum, the first-two
// default so the common case is one tap and an amount, the refusal that names
// the TRUNCATED balance rather than the engine's rounded one, the catch around
// a failed write so the button never stays dead, and a receipt after the move
// because there is no undo. What changed is the skin: Salapify 3's kit and
// theme, so this looks like the rest of the app a stranger meets in onboarding.
//
// EVERY PESO DECISION BELONGS TO core/money/transfers.dart, which is byte
// identical to the shipped app's and golden locked to the RN engine. This sheet
// collects three fields and shows whatever the engine says. It does no
// arithmetic of its own, on purpose, because a screen that computes a peso is
// how two versions of one number start to disagree.
//
// WHY MOVE WAS MISSING. The Log sheet used to offer Transfer and it destroyed
// money: one account picker, no destination, the money left and nothing
// received it, and sanitizeData then stripped the accountId so it could not
// even be given back (test/features/transfer_loss_test.dart holds that line).
// A transfer needs a FROM and a TO, and this is the sheet that has both.
import 'package:flutter/material.dart';

import '../../app/clock.dart';
import '../../app/ledger_scope.dart';
import '../../core/money/currencies.dart' show baseCurrencySymbol;
import '../../core/money/format.dart' show formatMoney;
import '../../core/money/ledger.dart' show amountOf;
import '../../core/money/transfers.dart'
    show TransferOutcome, TransferRefusal, applyTransfer, balanceLabel;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// Open the sheet, or say calmly why it cannot open yet.
///
/// Moving money needs two accounts to move between. With one, or none, this
/// points the way forward instead of opening a sheet with nothing to pick.
Future<void> showTransferSheet(BuildContext context) async {
  final store = context.ledger;
  final accounts = _accountsOf(store.data);
  if (accounts.length < 2) {
    final skin = context.skin;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: skin.card,
        title: Text(
          'Nowhere to move it yet',
          style: TypeScale.sheetTitle(skin.text),
        ),
        content: Text(
          accounts.isEmpty
              ? 'Add two accounts, then you can move money between them.'
              : 'Add a second account, then you can move money between them.',
          style: TypeScale.caption(skin.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Got it', style: TypeScale.action(skin.accent)),
          ),
        ],
      ),
    );
    return;
  }

  final now = context.now;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    // Or it lands under the nav bar. And every context INSIDE the builder is
    // the sheet's own: popping the caller's from in here took the whole screen
    // down once and gave the founder a black screen.
    useRootNavigator: true,
    builder: (sheetContext) => LedgerScope(
      store: store,
      child: _TransferSheet(
        now: now,
        // The shipped app's defaults: the first two accounts, so the common
        // case is one tap and an amount. Chosen HERE, not in the sheet's
        // initState, because initState may not read an inherited widget and
        // `context.ledger` is one. Settings shipped exactly that mistake and
        // drew nothing at all; its header still records the founder finding it.
        fromId: '${accounts[0]['id']}',
        toId: '${accounts[1]['id']}',
      ),
    ),
  );
}

List<Map<String, dynamic>> _accountsOf(Map<String, dynamic> data) => [
  for (final a
      in (data['accounts'] is List ? data['accounts'] as List : const []))
    if (a is Map) a.cast<String, dynamic>(),
];

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class _TransferSheet extends StatefulWidget {
  const _TransferSheet({
    required this.now,
    required this.fromId,
    required this.toId,
  });
  final DateTime now;
  final String fromId;
  final String toId;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final _amount = TextEditingController();
  late String _fromId = widget.fromId;
  late String _toId = widget.toId;
  bool _saving = false;
  String? _err;

  List<Map<String, dynamic>> get _accounts => _accountsOf(context.ledger.data);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Map<String, dynamic> _rowOf(String id) {
    for (final a in _accounts) {
      if ('${a['id']}' == id) return a;
    }
    return const {};
  }

  String _nameOf(String id) =>
      (_rowOf(id)['name'] ?? 'That account').toString();

  /// The refusal as a sentence that cannot contradict itself.
  ///
  /// The engine's own overdraft message rounds the balance, because it is
  /// locked to the RN wording, so an account holding 3,200.995 reports "only
  /// has 3,201" and then refuses a transfer of 3,201: same figure, opposite
  /// answers. The engine keeps its string so the two apps stay comparable, and
  /// the screen says the truthful thing with the same TRUNCATED label the
  /// picker shows, so the sentence and the chips always agree.
  String _honest(TransferOutcome r) => switch (r.refusal) {
    // Says what to DO, not only what is true. A fact with no instruction at
    // the moment somebody just tapped a disabled-feeling button reads as a
    // dead end rather than a next step.
    TransferRefusal.overdraft =>
      '${_nameOf(_fromId)} only has ${balanceLabel(r.available ?? 0)}. You '
          'can move up to that.',
    _ => r.error ?? 'Could not move it.',
  };

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _err = null;
    });

    final store = context.ledger;
    final today = _isoDay(widget.now);
    String genId() => 'tx_${DateTime.now().microsecondsSinceEpoch}';

    // Ask the engine FIRST, on the live ledger, so a refusal never becomes a
    // write. Then apply the same pure function inside the store's queue, where
    // it runs against a deep copy and lands only after sanitizeData accepts it.
    final probe = applyTransfer(
      store.data,
      fromId: _fromId,
      toId: _toId,
      amountText: _amount.text,
      today: today,
      genId: genId,
    );
    if (!probe.ok) {
      setState(() {
        _saving = false;
        _err = _honest(probe);
      });
      return;
    }

    // Captured BEFORE the write, because the receipt shows where the money
    // went and the sheet's own state is gone the moment it closes.
    final moved = amountOf(probe.data!['transactions'].last['amount']);
    final fromName = _nameOf(_fromId);
    final toName = _nameOf(_toId);

    try {
      await store.apply((s) {
        final out = applyTransfer(
          s,
          fromId: _fromId,
          toId: _toId,
          amountText: _amount.text,
          today: today,
          genId: genId,
        );
        // The probe above said yes on the same ledger a moment ago. If the
        // answer changed in between, refuse the write rather than guess.
        if (!out.ok) throw StateError(out.error ?? 'Could not move it.');
        return out.data!;
      });
    } catch (e) {
      // A failed save, or writing shut after an unreadable load. Without this
      // the button stayed disabled forever with nothing on screen, leaving the
      // person unable to tell whether their money moved.
      if (!mounted) return;
      // NEVER a raw exception in front of a person. `$e` here once printed
      // "Bad state: ..." on screen, which answers nothing and reads as the
      // app breaking rather than as English.
      setState(() {
        _saving = false;
        _err = 'Could not move it, nothing was changed.';
      });
      return;
    }
    if (!mounted) return;

    // Read back AFTER the write, so the receipt shows what is actually stored
    // rather than what this sheet expected to store.
    final after = _accountsOf(store.data);
    double balanceOf(String id) {
      for (final a in after) {
        if ('${a['id']}' == id) return amountOf(a['balance']);
      }
      return 0;
    }

    final fromBalance = balanceOf(_fromId);
    final toBalance = balanceOf(_toId);
    final nav = Navigator.of(context);
    final skin = context.skin;
    nav.pop();

    // A RECEIPT, because there is no undo. Deleting a transfer row does not
    // reverse the balances (see transfers.dart), so the honest thing is to
    // confirm exactly what moved and where both accounts stand now.
    await showDialog<void>(
      context: nav.context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: skin.card,
        // THE FIGURE IS THE TITLE, and the sentence it used to sit in is
        // gone: "from A to B" is already answered by the two lines below,
        // which is where the amount actually lands as a decision (do these
        // two new balances look right). And the closing line said "not
        // income, not spending" a second time in the same dialog, after the
        // sheet's own subtitle said it once already. One promise, once.
        title: Text(
          'Moved ${formatMoney(moved)}',
          style: TypeScale.sheetTitle(skin.text),
        ),
        content: Text(
          '$fromName now has ${formatMoney(fromBalance)}.\n'
          '$toName now has ${formatMoney(toBalance)}.',
          style: TypeScale.rowTitle(skin.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Done', style: TypeScale.action(skin.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final list = _accounts;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        28 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: skin.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      // The fields SCROLL and the actions are PINNED below them, the shipped
      // app's layout. One scroll view for everything let the pickers push the
      // primary action off the bottom on a short phone with the keyboard up,
      // with no signal it was down there.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Move money', style: TypeScale.sheetTitle(skin.text)),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Text('Cancel', style: TypeScale.action(skin.text2)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'This is not income and not spending, so it never touches your '
            'budget. It just moves the balances.',
            style: TypeScale.caption(skin.text3),
          ),
          const SizedBox(height: 16),

          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('From', style: TypeScale.fieldLabel(skin.text2)),
                  const SizedBox(height: 8),
                  _picker(list, _fromId, (v) {
                    setState(() {
                      _fromId = v;
                      // If the newly picked From is the current To, swap
                      // the collision away instead of leaving it for the
                      // engine to refuse. The person moved the pair, not a
                      // mistake they made.
                      if (_toId == v) {
                        final other = list.firstWhere(
                          (a) => '${a['id']}' != v,
                          orElse: () => const {},
                        );
                        _toId = '${other['id'] ?? ''}';
                      }
                      _err = null;
                    });
                  }, balances: true),
                  const SizedBox(height: 16),
                  Text('To', style: TypeScale.fieldLabel(skin.text2)),
                  const SizedBox(height: 8),
                  _picker(
                    // The chip you are moving FROM is not an option here,
                    // which makes "Pick two different accounts" unreachable
                    // rather than merely worded well. The engine still
                    // refuses it, as a floor rather than the only guard.
                    [
                      for (final a in list)
                        if ('${a['id']}' != _fromId) a,
                    ],
                    _toId,
                    (v) => setState(() {
                      _toId = v;
                      _err = null;
                    }),
                    balances: false,
                  ),
                  const SizedBox(height: 16),
                  Text('Amount', style: TypeScale.fieldLabel(skin.text2)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amount,
                    // NOT autofocus. The sheet is capped at 85 percent of the
                    // screen height, and the keyboard is subtracted from that.
                    // On a small phone the chips the sheet had just CHOSEN for
                    // the person scroll off the top the instant the sheet
                    // opens, so the first thing they see is a number pad with
                    // no visible From or To. That is exactly how a transfer
                    // goes to the wrong account.
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TypeScale.rowTitle(skin.text),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TypeScale.rowTitle(skin.text3),
                      prefixText: '$baseCurrencySymbol ',
                      prefixStyle: TypeScale.rowTitle(skin.text2),
                      filled: true,
                      fillColor: skin.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() => _err = null),
                    onSubmitted: (_) => _save(),
                  ),
                ],
              ),
            ),
          ),

          // Pinned: the refusal and the action, always on screen.
          if (_err != null) ...[
            const SizedBox(height: 12),
            // liveRegion, so a screen reader announces the refusal. Without it
            // a blind user taps Move it, hears nothing, and has no signal that
            // the money did not move.
            Semantics(
              liveRegion: true,
              child: Text(
                _err!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TypeScale.caption(skin.bad),
              ),
            ),
          ],
          const SizedBox(height: 18),
          PillButton(
            label: _saving ? 'Moving' : 'Move it',
            icon: Icons.swap_horiz_rounded,
            onTap: _saving || _amount.text.trim().isEmpty ? null : _save,
          ),
        ],
      ),
    );
  }

  /// The account chips. Dumb on purpose: it draws and it calls [onPick], and
  /// every caller owns its own state change, because the two callers change
  /// DIFFERENT things (From can also move To out of a collision) and a picker
  /// that tried to know that for both would be guessing at the caller's job.
  ///
  /// [balances], TRUNCATED and never rounded, through the engine's own
  /// `balanceLabel`. Shown on From, where "can I move this much out of here"
  /// is the real question; left off To, where the same figure answered
  /// nothing and made the two rows of chips pixel identical under two
  /// different labels, which is the visual condition somebody picks the wrong
  /// row in. An account holding 48,500.55 that read "48,501" would refuse a
  /// transfer of 48,501, and a chip printing a number the next tap
  /// contradicts is worse than no number.
  Widget _picker(
    List<Map<String, dynamic>> list,
    String picked,
    void Function(String) onPick, {
    required bool balances,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final a in list)
        PickChip(
          label: balances
              ? '${a['name'] ?? ''}  ${balanceLabel(amountOf(a['balance']))}'
              : (a['name'] ?? '').toString(),
          on: '${a['id']}' == picked,
          onTap: _saving ? null : () => onPick('${a['id']}'),
        ),
    ],
  );
}
