// Accounts: see, add, edit, and delete your accounts and assets, change a
// balance, and move money between two accounts. Reached from the Overview,
// ported from mobile/app/accounts.js. A balance change to an existing account
// posts a recorded adjustment through the golden-verified ledger (reversible,
// shows in History) rather than silently overwriting the number, and the
// transfer sheet at the bottom of this file spends every peso decision
// through money/transfers.dart, which is locked to the RN engine by goldens.

import 'dart:async' show Timer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../money/accounts_calc.dart';
import '../money/debtmath.dart' show formatMoneyText;
import '../money/ledger.dart' show amountOf;
import '../money/base_currency_scope.dart'
    show baseCurrencyOf, excludedNotice, manualRatesOf;
import '../money/fx_totals.dart' show FxOutcome, conversionNotice, resolveRate;
import '../money/currencies.dart'
    show baseCurrencySymbol, currencies, currencySymbol, formatConverted;
import '../money/transfers.dart'
    show TransferOutcome, TransferRefusal, balanceLabel;
import '../money/statements.dart' show netWorthParts;
import '../data/store.dart';
import '../data/qr_vault.dart';
import '../money/account_taxonomy.dart';
import '../money/card_products.dart' show cardNetworkWordmark;
import 'account_detail.dart' show AccountDetailScreen;
import '../money/institutions.dart'
    show institutionBrandColor, institutionById, institutionLabel;
import '../theme.dart';
import '../typography.dart';
import 'add_account_flow.dart'
    show InstitutionAvatar, showAddAccountSheet, showInstitutionPicker;
import 'debts.dart' show showDebtFormSheet;
import '../widgets/bank_card.dart';
import '../widgets/flip_bank_card.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/salapify_icon.dart';

const _accountKinds = [
  ('cash', 'Cash'),
  ('savings', 'Savings'),
  ('checking', 'Checking'),
  ('ewallet', 'E-wallet'),
];
const _assetKinds = [
  ('crypto', 'Crypto'),
  ('stocks', 'Stocks'),
  ('mp2', 'MP2'),
  ('real estate', 'Real estate'),
  ('vehicle', 'Vehicle'),
  ('other', 'Other'),
];
String _todayISO() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

class AccountsScreen extends StatefulWidget {
  final SalapifyStore store;

  /// Routes the "manage debts" note to the canonical "I owe" segment of the
  /// Utang tab. Null when this screen is pushed by a host with no tab switcher
  /// (a deep push), in which case the note is plain words pointing the same way
  /// rather than a live link.
  final VoidCallback? onOpenPayables;

  /// An account id to reveal on open: the list scrolls to it and it flashes
  /// once. Set when Search opens this screen on a specific account match. If
  /// the id no longer exists (the account was deleted between the search result
  /// rendering and this tap), the screen opens normally and says so, rather
  /// than crashing on a stale id.
  final String? focusAccountId;

  const AccountsScreen({
    super.key,
    required this.store,
    this.onOpenPayables,
    this.focusAccountId,
  });

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  // The rest of this class was written against a bare `store` field. This
  // getter keeps every one of those references compiling after the split to a
  // StatefulWidget, so the focus/highlight state could be added without a
  // rename sweep across two hundred lines.
  SalapifyStore get store => widget.store;

  /// The row to reveal, and its transient highlight. The key stays put so the
  /// scroll can find the row; the id clears after the flash so the tint fades.
  final GlobalKey _focusKey = GlobalKey();
  String? _highlightId;
  Timer? _fade;

  /// Loaded once and passed down to the flipped card's QR shortcut, so the
  /// carousel does not re-read the documents directory per card. Best effort:
  /// off a device (web, tests) this stays null and the QR button simply does
  /// not appear, exactly as the detail screen behaves.
  QrVault? _vault;

  @override
  void initState() {
    super.initState();
    QrVault.inAppDocuments()
        .then((v) {
          if (mounted) setState(() => _vault = v);
        })
        .catchError((_) {});
    final id = widget.focusAccountId;
    if (id != null) {
      _highlightId = id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealFocus(id));
    }
  }

  /// Open the edit sheet for a card, the same one "View full details" reaches a
  /// tap deeper. Accounts and debts have different editors, so the card's own
  /// collection decides which one opens.
  void _editCard(BuildContext context, _CardItem it) {
    if (it.store == AccountStore.debts) {
      showDebtFormSheet(context, store, debt: it.row);
    } else {
      _openForm(context, isAccount: true, item: it.row);
    }
  }

  @override
  void dispose() {
    // A cancelable Timer, not Future.delayed: a pending timer at teardown
    // fails the widget suite with "A Timer is still pending", and a real user
    // can leave this screen before the flash fades.
    _fade?.cancel();
    super.dispose();
  }

  /// Scroll the focused account into view and let its flash fade. If it was
  /// deleted between the search result and this tap, there is nothing to
  /// reveal: clear the highlight and say so plainly, so a stale id is a calm
  /// sentence rather than a crash or a silent no-op.
  void _revealFocus(String id) {
    if (!mounted) return;
    final present = _rows('accounts').any((a) => '${a['id']}' == id);
    if (!present) {
      setState(() => _highlightId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That account was just removed, so there is nothing to open here.',
          ),
        ),
      );
      return;
    }
    // This reaches a match far down a long list, and the comment that used to
    // sit here saying it did NOT was wrong. It claimed the lazy ListView leaves
    // a far-down row unbuilt, so currentContext is null and the scroll no-ops.
    // But every account renders inside ONE eager Column (the "Cash and
    // e-wallets" section, anchored at the top of the list), and a Column builds
    // all its children, so the row's element exists even when painted well below
    // the fold. ensureVisible finds it and scrolls it in. The old note was a
    // code-reading guess about a lazy per-row list that this tree is not.
    // accounts_focus_scroll_test.dart proves the 40th of 40 accounts is scrolled
    // onto the screen; if the rows are ever moved to a lazy per-row builder that
    // guard reddens, and only then would a scroll loop be needed.
    final ctx = _focusKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.3,
        duration: const Duration(milliseconds: 300),
      );
    }
    _fade = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _highlightId = null);
    });
  }

  List<Map<String, dynamic>> _rows(String key) {
    final raw = store.data[key];
    return [
      for (final a in (raw is List ? raw : const []))
        if (a is Map) a.cast<String, dynamic>(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Accounts',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            // Grouped by the TAXONOMY category, not by the four legacy kinds.
            //
            // Everything a person owns or owes now sits under the same heading
            // the Add flow offered them, so what they chose and what they see
            // afterwards use the same words. A row with no classification is
            // derived from its legacy fields, so an account created before any
            // of this still lands in the right place with nothing written to
            // it (money/account_taxonomy.dart).
            //
            // The amount key differs per collection, which is why the group
            // carries it rather than the caller guessing.
            final groups = <String, List<(Map<String, dynamic>, AccountStore)>>{
              for (final c in accountCategories) c.id: [],
            };
            for (final (rows, which) in [
              (_rows('accounts'), AccountStore.accounts),
              (_rows('assets'), AccountStore.assets),
              (_rows('debts'), AccountStore.debts),
            ]) {
              for (final r in rows) {
                groups[resolveKind(r, which).category.id]!.add((r, which));
              }
            }
            final parts = netWorthParts(store.data, fx: store.fxTable);

            double amountOfRow((Map<String, dynamic>, AccountStore) e) =>
                switch (e.$2) {
                  AccountStore.accounts => amountOf(e.$1['balance']),
                  AccountStore.assets => amountOf(e.$1['value']),
                  AccountStore.debts => amountOf(e.$1['remaining']),
                };

            final anyRows = groups.values.any((g) => g.isNotEmpty);
            // The cards shown in the swipeable carousel: every cash or wallet
            // account, then any credit card. The grouped list below still shows
            // and edits all of them, so this is a hero on top, not a
            // replacement, and the net worth subtotals it owns are untouched.
            //
            // Shown only with TWO or more cards. A carousel is a "swipe between
            // several" affordance, so a lone card with one page dot and nothing
            // to peek at is not one; a single account keeps the familiar row and
            // gains the card the moment a second account joins it.
            // Cash is money you hold, not an account at an institution, so it is
            // NOT a card: it gets its own compact "Cash on hand" section (a
            // CashBalanceTile per cash account) above the card carousel, which is
            // bank and credit only. The hero zone appears at two or more accounts
            // TOTAL, the same threshold as before, so a single account keeps just
            // its list row and no one loses a card when cash moves out of the
            // deck (the carousel itself handles a lone bank card, dots suppressed).
            final all = _cardItems(groups);
            final cashItems = all.where((it) => it.isCash).toList();
            final cardItems = all.where((it) => !it.isCash).toList();
            final showHero = all.length > 1;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _summary(parts),
                // What the total was converted with, or what it left out,
                // directly UNDER the number it explains. It sat at the bottom
                // of the list first, a full scroll from the figure somebody
                // was reading.
                //
                // There is no state in which a converted number is shown
                // without this line. That is the design document's rule and
                // the whole reason conversion was gated separately from the
                // rest of the feature.
                if (_fxNotice(store, parts) case final notice?)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(notice, style: AppText.caption),
                  ),
                if (_missingRateCodes(parts).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final code in _missingRateCodes(parts))
                          TextButton(
                            onPressed: () =>
                                _askManualRate(context, store, code),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text('Set a $code rate'),
                          ),
                      ],
                    ),
                  ),
                if (showHero && cashItems.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text('CASH ON HAND', style: Barako.kickerStyle),
                  ),
                  for (var i = 0; i < cashItems.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    PressableScale(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _openCard(context, cashItems[i]),
                        child: CashBalanceTile(
                          name: cashItems[i].name,
                          balance: cashItems[i].amount,
                          amountText: cashItems[i].amountText,
                        ),
                      ),
                    ),
                  ],
                ],
                if (showHero && cardItems.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text('YOUR CARDS', style: Barako.kickerStyle),
                  ),
                  _AccountsCarousel(
                    items: cardItems,
                    store: store,
                    vault: _vault,
                    onOpen: (it) => _openCard(context, it),
                    onEdit: (it) => _editCard(context, it),
                    // The first-time nudge, shown until the founder flips any
                    // card once. Persisted so it never returns on the next open.
                    showHint:
                        (store.data['settings'] as Map?)?['flipHintSeen'] !=
                        true,
                    onFirstFlip: () => store.setSetting('flipHintSeen', true),
                  ),
                ],
                const SizedBox(height: 16),
                // ONE button. It used to be two, "+ Account" and "+ Asset",
                // which asked people to know Salapify's internal split before
                // they could record anything, and offered nothing at all for a
                // car loan, which lives on a different tab.
                _addButton(context, '+ Add an account', () => _add(context)),
                // Only with somewhere to move money from AND to. One account
                // cannot transfer to itself, so offering the button then
                // would be offering a dead end.
                if (store.canWrite &&
                    groups['cash_equivalents']!.length > 1) ...[
                  const SizedBox(height: 10),
                  _addButton(
                    context,
                    'Move money between accounts',
                    () => _openTransfer(context),
                  ),
                ],
                const SizedBox(height: 20),
                // An EMPTY section is not shown. Six headings over six "nothing
                // here yet" lines is a screen that looks like a chore list, and
                // the old two-section version already had two of them. One
                // honest empty state instead, below.
                for (final c in accountCategories)
                  if (groups[c.id]!.isNotEmpty)
                    _section(
                      c.label.toUpperCase(),
                      // Counts exactly what the total above counts: base
                      // currency rows, plus any foreign row the app can price.
                      // A subtotal that used a different rule from the total
                      // is the "two versions of one number" bug, and it is
                      // easy to write by accident because each rule looks
                      // right on its own.
                      groups[c.id]!.fold(
                        0.0,
                        (t, e) => t + _countedAmount(e, amountOfRow(e)),
                      ),
                      [
                        for (final e in groups[c.id]!) _taxonomyRow(context, e),
                        // Once, under the last debt section, not under each.
                        if (c.store == AccountStore.debts &&
                            c.id == _lastDebtCategoryWithRows(groups))
                          _manageDebtsNote(),
                      ],
                      subtotalColor: c.cls == AccountClass.liability
                          ? Barako.warningStrong
                          : null,
                    ),
                if (!anyRows)
                  _empty(
                    'Nothing recorded yet. Tap Add an account above and '
                    'Salapify will ask what it is.',
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The one sentence under the total.
  ///
  /// With a rate table it names what was converted and with what; without one
  /// it names what was left out. Both come from the same place, so a person
  /// never sees a total whose provenance is unexplained.
  String? _fxNotice(SalapifyStore store, Map<String, dynamic> parts) {
    final t = store.fxTable;
    if (t == null) return excludedNotice(store.data);
    final a = parts['fxAssets'] as FxOutcome?;
    final d = parts['fxDebts'] as FxOutcome?;
    if (a == null || d == null) return excludedNotice(store.data);
    // Assets and debts are converted separately so a foreign debt lands on
    // the right side, but the SENTENCE is about the total, so the two are
    // merged for the reader.
    final merged = FxOutcome(
      0,
      {...a.excluded, ...d.excluded},
      {...a.used, ...d.used},
    );
    return conversionNotice(t, merged);
  }

  /// The currencies with no rate at all, which are the only ones worth
  /// offering to price by hand.
  List<String> _missingRateCodes(Map<String, dynamic> parts) {
    final a = parts['fxAssets'] as FxOutcome?;
    final d = parts['fxDebts'] as FxOutcome?;
    return {...?a?.excluded.keys, ...?d?.excluded.keys}.toList()..sort();
  }

  Future<void> _askManualRate(
    BuildContext context,
    SalapifyStore store,
    String code,
  ) async {
    final base = baseCurrencyOf(store.data);
    final entered = await showDialog<double?>(
      context: context,
      builder: (ctx) => _ManualRateDialog(
        code: code,
        base: base,
        existing: manualRatesOf(store.data)[code],
      ),
    );
    if (entered == null) return;
    // 0 is the Remove button, and a junk parse also lands here; both clear the
    // rate rather than storing something the totals would then trust.
    await store.setManualRate(code, entered > 0 ? entered : null);
  }

  Widget _summary(Map<String, dynamic> parts) => Card(
    color: Barako.surfaceRaised,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NET WORTH', style: Barako.kickerStyle),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoneyText(parts['netWorth'] as double),
              maxLines: 1,
              style: AppText.amountLg.w7,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Flexible(
                child: _miniStat(
                  'Total assets',
                  parts['assets'] as double,
                  Barako.primaryText,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: _miniStat(
                  'Total owed',
                  parts['liabilities'] as double,
                  Barako.warningStrong,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _miniStat(String label, double value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppText.caption),
      const SizedBox(height: 2),
      Text(
        formatMoneyText(value),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.amountRow.tint(color).copyWith(fontSize: 16),
      ),
    ],
  );

  Widget _addButton(BuildContext context, String label, VoidCallback onTap) =>
      PressableScale(
        child: Material(
          color: Barako.card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Barako.border),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: Barako.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _section(
    String title,
    double subtotal,
    List<Widget> children, {
    Color? subtotalColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Barako.kickerStyle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatMoneyText(subtotal),
                  style: AppText.amountRow
                      .tint(subtotalColor ?? Barako.textSecondary)
                      .copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(text, style: AppText.small.tint(Barako.faint)),
  );

  /// Which debt category renders the "manage debts elsewhere" note.
  ///
  /// The LAST one with rows, so the note appears exactly once and always at
  /// the bottom of the debts, whichever categories happen to be present.
  String _lastDebtCategoryWithRows(
    Map<String, List<(Map<String, dynamic>, AccountStore)>> groups,
  ) {
    var last = '';
    for (final c in accountCategories) {
      if (c.store == AccountStore.debts && groups[c.id]!.isNotEmpty) {
        last = c.id;
      }
    }
    return last;
  }

  /// Where debts are actually managed now: the "I owe" segment of the Utang
  /// tab. This line used to read "Manage debts on the Debts screen", which
  /// named a screen that is only a fallback and pointed away from the tab that
  /// is the real home. When the host wired the jump it is a live link there;
  /// otherwise it is plain words pointing the same way, never at a "Debts
  /// screen".
  Widget _manageDebtsNote() {
    final open = widget.onOpenPayables;
    const label = 'Manage debts under the "I owe" tab.';
    if (open == null) {
      // Left-aligned, the same as the linked variant below, so the note does
      // not jump from centered to left depending on whether the host wired the
      // jump. The section Card's Column centers its children by default, which
      // is why this needs saying out loud.
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(label, style: AppText.caption.tint(Barako.faint)),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        // popUntil, not pop: Search can push this two deep, so popping to the
        // root is what lands the tab switch cleanly from any depth.
        onPressed: () {
          Navigator.of(context).popUntil((r) => r.isFirst);
          open();
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          foregroundColor: Barako.primaryText,
          minimumSize: const Size(0, 44),
        ),
        child: const Text(label),
      ),
    );
  }

  /// One row, whichever collection it came from.
  ///
  /// The sub line names the SUBTYPE and the institution, which is the pair
  /// that answers "which of my three BPI things is this". It replaces the old
  /// free text brand, which only accounts had and which nothing validated.
  Widget _taxonomyRow(
    BuildContext context,
    (Map<String, dynamic>, AccountStore) entry,
  ) {
    final (row, which) = entry;
    final kind = resolveKind(row, which);
    final bank = institutionLabel(row);
    final parts = <String>[kind.subtype.label, ?bank];

    switch (which) {
      case AccountStore.accounts:
        final id = '${row['id']}';
        return _accountRow(
          context,
          row,
          sub: parts.join(' · '),
          // The key rides on the row Search asked to reveal, so the scroll can
          // find it; the flash follows the transient highlight id.
          rowKey: id == widget.focusAccountId ? _focusKey : null,
          highlight: id == _highlightId,
        );
      case AccountStore.assets:
        return _row(
          // Salapify-authored rows carry system glyphs; only USER-picked
          // icons stay emoji, and an asset row's marker was never theirs.
          icon: '',
          leading: SalapifyGlyph('growth', size: 20, boxed: false),
          name: row['name']?.toString() ?? 'Asset',
          sub: parts.join(' · '),
          amount: amountOf(row['value']),
          onTap: () => _openForm(context, isAccount: false, item: row),
        );
      case AccountStore.debts:
        // Not tappable. Editing a debt belongs to the Utang tab's "I owe"
        // segment, which owns interest, due dates and payment history; opening
        // the account form on one would offer fields that do not apply and drop
        // the ones that do.
        return _row(
          icon: '',
          leading: SalapifyGlyph('card', size: 20, boxed: false),
          name: row['name']?.toString() ?? 'Debt',
          sub: parts.join(' · '),
          amount: amountOf(row['remaining']),
          amountColor: Barako.warningStrong,
        );
    }
  }

  Widget _accountRow(
    BuildContext context,
    Map<String, dynamic> a, {
    String? sub,
    Key? rowKey,
    bool highlight = false,
  }) {
    final target = amountOf(a['target']);
    final balance = amountOf(a['balance']);
    final brand = (a['brand'] ?? '').toString();
    // The caller's line (subtype and institution) is the default. A savings
    // TARGET replaces it, because progress toward a goal is the more useful
    // fact and a third clause would not fit on one line at any font size.
    //
    // That sentence was written first and the code underneath it then APPENDED
    // rather than replaced, so a savings account with a goal rendered
    // "Savings account · BPI · 49% of ₱1..." and the target, the one number
    // the line exists to show, was the part cut off. The author knew a third
    // clause would not fit and wrote a third clause. It survived because no
    // fixture had ever given an account a target: the render that would have
    // shown it seeded its own store, and that store had no goals in it.
    //
    // Nothing is lost by replacing. The subtype is a category the row already
    // sits under, and the institution is drawn as its own avatar two
    // centimetres to the left.
    double? progress;
    if (target > 0) {
      final pct = ((balance / target) * 100).clamp(0, 999).round();
      sub = '$pct% of ${formatMoneyText(target)}';
      progress = (balance / target).clamp(0.0, 1.0);
    } else if (sub == null && brand.isNotEmpty) {
      sub = brand;
    }
    // The bank's initials, but ONLY when there is no emoji to respect.
    //
    // CLAUDE.md's icon rule is that Salapify styles the icons IT authors and
    // never touches the ones a person picked: an account icon is user data,
    // it lives in the backup file, and replacing it would overwrite a choice
    // that was never ours. So an account with any stored icon keeps it, and
    // the avatar appears only where the field is genuinely empty, which is
    // what the Add flow now leaves when a bank was chosen instead.
    final storedIcon = (a['icon'] ?? '').toString();
    final bankId = (a['institutionId'] ?? '').toString();
    return _row(
      foreignCode: _foreignCodeOf(a),
      icon: storedIcon,
      // Empty icon field: the bank's avatar when one was chosen, else the
      // system's cash glyph. The DISPLAY fallback is Salapify's to style;
      // only a stored emoji is the user's.
      leading: storedIcon.isEmpty
          ? (bankId.isNotEmpty
                ? InstitutionAvatar(id: bankId, size: 30)
                : SalapifyGlyph('cash', size: 22, boxed: false))
          : null,
      name: a['name']?.toString() ?? 'Account',
      sub: sub,
      amount: balance,
      progress: progress,
      onTap: () => _openForm(context, isAccount: true, item: a),
      rowKey: rowKey,
      highlight: highlight,
    );
  }

  /// A row's contribution to a base-currency subtotal.
  ///
  /// Base currency rows count as themselves; foreign rows count as their
  /// converted value, or as nothing when there is no rate. The same three
  /// cases netWorthParts uses, so the subtotal and the total can never
  /// disagree about a row.
  double _countedAmount((Map<String, dynamic>, AccountStore) e, double amount) {
    final code = _foreignCodeOf(e.$1);
    if (code == null) return amount;
    final t = store.fxTable;
    if (t == null) return 0;
    final r = resolveRate(t, code);
    return r.basePerUnit == null ? 0 : amount * r.basePerUnit!;
  }

  /// The row's own currency, when it differs from the app's. Null otherwise,
  /// which is every row that has ever existed.
  String? _foreignCodeOf(Map<String, dynamic> r) {
    final base = baseCurrencyOf(store.data);
    final c = r['currencyCode'];
    if (c is! String || c.isEmpty) return null;
    return c.toUpperCase() == base ? null : c.toUpperCase();
  }

  /// What the second line under a foreign amount should say.
  ///
  /// This exists because the first version said "not counted" on every foreign
  /// row, unconditionally. Once conversion shipped that became a LIE on any row
  /// the app could price: net worth included the converted dollars, and the row
  /// underneath insisted they were left out. Two versions of one number, which
  /// is a bug this project has fixed before.
  ///
  /// So the line follows the same resolution the total used. Converted, it
  /// shows the base-currency equivalent, marked with a tilde because it is an
  /// equivalent and not a balance. Unpriceable, it says so.
  String _foreignSubLabel(String code, double amount) {
    final t = store.fxTable;
    if (t == null) return 'not counted';
    final r = resolveRate(t, code);
    if (r.basePerUnit == null) return 'not counted';
    return '~ ${formatMoneyText(amount * r.basePerUnit!)}';
  }

  Widget _row({
    /// When set, the amount is drawn in THIS currency and marked as not
    /// counted. The mark is not decoration: the figure beside it is real money
    /// that the totals above deliberately leave out, and a row that showed the
    /// amount without saying so would make the totals look wrong instead of
    /// incomplete.
    String? foreignCode,
    required String icon,

    /// Drawn instead of [icon] when given. Only ever the institution avatar,
    /// and only where there is no emoji to respect.
    Widget? leading,
    required String name,
    double? amount,
    String? sub,
    double? progress,
    Color? amountColor,
    VoidCallback? onTap,

    /// Rides on the row Search asked to reveal, so Scrollable.ensureVisible can
    /// find its element. Null on every other row.
    Key? rowKey,

    /// Draws a brief accent tint and border, the flash that says "this is the
    /// one you searched for". Fades on its own after a couple of seconds.
    bool highlight = false,
  }) {
    final body = Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          leading ?? Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.w6,
                ),
                if (sub != null && sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ],
                if (progress != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Barako.border,
                      color: Barako.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (amount != null) ...[
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  foreignCode == null
                      ? formatMoneyText(amount)
                      : formatConverted(amount, foreignCode),
                  style: AppText.amountRow.tint(amountColor ?? Barako.text),
                ),
                if (foreignCode != null)
                  Text(
                    _foreignSubLabel(foreignCode, amount),
                    style: AppText.micro.w4,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
    Widget result = onTap == null
        ? body
        : PressableScale(
            child: InkWell(onTap: onTap, child: body),
          );
    if (highlight) {
      result = DecoratedBox(
        decoration: BoxDecoration(
          color: Barako.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Barako.primary),
        ),
        child: result,
      );
    }
    return rowKey == null ? result : KeyedSubtree(key: rowKey, child: result);
  }

  /// The cards for the carousel: cash and wallet accounts as savings cards,
  /// then credit cards as credit cards. Order matches the sections below.
  List<_CardItem> _cardItems(
    Map<String, List<(Map<String, dynamic>, AccountStore)>> groups,
  ) {
    final out = <_CardItem>[];
    for (final (row, which) in groups['cash_equivalents']!) {
      final kind = resolveKind(row, which);
      final inst = institutionLabel(row);
      // A foreign account is shown in its OWN currency on the card, the same
      // way the row does, so the card never prints a peso symbol on dollars.
      // Net worth already leaves an unpriced currency out and the row says so;
      // the card just has to be honest about the symbol.
      final code = _foreignCodeOf(row);
      final bal = amountOf(row['balance']);
      out.add(
        _CardItem(
          row: row,
          store: which,
          name: row['name']?.toString() ?? 'Account',
          typeLabel: _shortType(row['kind']?.toString()),
          subtitle: [kind.subtype.label, ?inst].join(' · '),
          // A cash or unlisted account has no brand color, so the card falls
          // back to the neutral gradient rather than looking broken.
          brandColor: institutionBrandColor(row['institutionId']?.toString()),
          last4: _last4Of(row),
          amount: bal,
          amountText: code == null ? null : formatConverted(bal, code),
          monogram: institutionById(row['institutionId']?.toString())?.initials,
          variant: BankCardVariant.savings,
          isCash: row['kind']?.toString() == 'cash',
        ),
      );
    }
    for (final (row, which) in groups['credit']!) {
      final inst = institutionLabel(row);
      out.add(
        _CardItem(
          row: row,
          store: which,
          name: row['name']?.toString() ?? 'Credit card',
          typeLabel: 'Credit',
          subtitle: ['Credit card', ?inst].join(' · '),
          brandColor: institutionBrandColor(row['institutionId']?.toString()),
          last4: _last4Of(row),
          amount: amountOf(row['remaining']),
          limit: amountOf(row['creditLimit']),
          monogram: institutionById(row['institutionId']?.toString())?.initials,
          networkMark: cardNetworkWordmark(row['cardNetwork']?.toString()),
          variant: BankCardVariant.credit,
        ),
      );
    }
    return out;
  }

  /// The short top-right label on a card, from the legacy kind.
  String _shortType(String? kind) => switch (kind) {
    'savings' => 'Savings',
    'checking' => 'Checking',
    'ewallet' => 'E-wallet',
    'cash' => 'Cash',
    _ => 'Account',
  };

  /// The last four digits, only when a stored value is exactly four digits.
  /// Anything else (absent, or a longer string a backup should never carry)
  /// shows as masked dots with no digits.
  String? _last4Of(Map<String, dynamic> row) {
    final v = row['last4'];
    return (v is String && RegExp(r'^\d{4}$').hasMatch(v)) ? v : null;
  }

  /// Tapping a card opens its full detail screen, the wallet page for that one
  /// account: the card, its numbers, the secure information, a saved receiving
  /// QR, and recent activity, with Edit, Archive and Delete inside. This
  /// replaces the old shortcut that jumped straight to the edit sheet; editing
  /// still lives one tap deeper, and a credit card's CARD reaches the right
  /// screen even though the debt LIST ROW below stays non-tappable.
  void _openCard(BuildContext context, _CardItem it) {
    final id = it.row['id'];
    if (id is! String || id.isEmpty) {
      // A hand-edited backup row with no id cannot be addressed by the detail
      // screen, so fall back to the old editor rather than opening a blank page.
      if (it.store == AccountStore.debts) {
        showDebtFormSheet(context, store, debt: it.row);
      } else {
        _openForm(context, isAccount: true, item: it.row);
      }
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AccountDetailScreen(store: store, id: id, accountStore: it.store),
      ),
    );
  }

  void _openTransfer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransferSheet(store: store),
    );
  }

  /// Ask what it is, then open the form that can actually record it.
  ///
  /// The routing is the whole feature. An answer maps to one of the three
  /// collections, and each collection has a form that already works: accounts
  /// and assets share this file's sheet, and a liability goes to the debts
  /// form, which owns interest, due dates and payment history. Nothing is
  /// rewritten and nothing moves between collections.
  Future<void> _add(BuildContext context) async {
    final choice = await showAddAccountSheet(context);
    if (choice == null || !context.mounted) return;
    if (choice.store == AccountStore.debts) {
      // Seeded, not pre-created. The debt form decides add against edit by
      // whether it was handed a row with an id, so a seed carrying only a type
      // and a subtype stays an ADD.
      await showDebtFormSheet(context, store, seed: choice.subtype);
      return;
    }
    if (!context.mounted) return;
    _openForm(
      context,
      isAccount: choice.store == AccountStore.accounts,
      seed: choice.subtype,
    );
  }

  void _openForm(
    BuildContext context, {
    required bool isAccount,
    Map<String, dynamic>? item,
    AccountSubtype? seed,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountForm(
        store: store,
        isAccount: isAccount,
        item: item,
        seed: seed,
      ),
    );
  }
}

/// The add/edit sheet for an account or an asset.
class _AccountForm extends StatefulWidget {
  final SalapifyStore store;
  final bool isAccount;
  final Map<String, dynamic>? item;

  /// What the person said they were adding. Null when editing an existing row
  /// or when this sheet is reached by a path that never asked.
  final AccountSubtype? seed;
  const _AccountForm({
    required this.store,
    required this.isAccount,
    this.item,
    this.seed,
  });

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _target;
  late final TextEditingController _brand;
  late final TextEditingController _icon;
  late String _kind;
  late String _institutionId;

  /// Empty means "the app's currency", which is what every account has always
  /// been. A code is only stored when it DIFFERS from the base, so no row ever
  /// gains a key that just restates the setting.
  late String _currencyCode;
  bool _confirmDel = false;
  bool _saving = false;
  String? _err;

  bool get _isEdit => widget.item != null;

  String _numStr(dynamic v) {
    final n = amountOf(v);
    return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
  }

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _name = TextEditingController(text: it?['name']?.toString() ?? '');
    _amount = TextEditingController(
      text: it == null
          ? ''
          : _numStr(widget.isAccount ? it['balance'] : it['value']),
    );
    _target = TextEditingController(
      text: (it != null && amountOf(it['target']) > 0)
          ? _numStr(it['target'])
          : '',
    );
    _brand = TextEditingController(text: it?['brand']?.toString() ?? '');
    _icon = TextEditingController(text: it?['icon']?.toString() ?? '');
    // Order matters: an existing row's own kind always wins, then the seed's
    // legacy mapping, then the default. Letting the seed win over a stored
    // kind would silently re-type an account somebody is only editing.
    _kind =
        (it?['kind'] ??
                (widget.isAccount
                    ? (widget.seed?.legacyKind ?? 'cash')
                    : (_assetKindFor(widget.seed) ?? 'crypto')))
            .toString();
    _institutionId = it?['institutionId']?.toString() ?? '';
    _currencyCode = it?['currencyCode']?.toString() ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _target.dispose();
    _brand.dispose();
    _icon.dispose();
    super.dispose();
  }

  /// The reverse of the taxonomy's asset mapping: a chosen subtype back to the
  /// free-string `kind` the Accounts picker has always written, so an asset
  /// created through the new flow is indistinguishable from one created the
  /// old way and every existing screen keeps grouping it correctly.
  ///
  /// Returns null for a subtype with no legacy equivalent, and the caller
  /// falls back rather than inventing one.
  static String? _assetKindFor(AccountSubtype? s) => switch (s?.id) {
    'crypto' => 'crypto',
    'stocks' => 'stocks',
    'retirement' => 'mp2',
    'real_estate' => 'real estate',
    'vehicle' => 'vehicle',
    _ => s == null ? null : 'other',
  };

  /// The classification to store alongside the row.
  ///
  /// Only ever added on CREATE. An edit leaves whatever classification the row
  /// already has, because this sheet does not ask the question and writing a
  /// seed here would let opening and saving an untouched row silently
  /// reclassify it. sanitizeData validates every key on the way to disk, so a
  /// value that does not belong to this collection is dropped rather than
  /// stored.
  Map<String, dynamic> _meta() {
    final s = widget.seed;
    if (s == null) return const {};
    return {
      'subtype': s.id,
      if (_institutionId.isNotEmpty) 'institutionId': _institutionId,
      if (_currencyCode.isNotEmpty) 'currencyCode': _currencyCode,
    };
  }

  /// The currency, as ONE row rather than a wall of chips.
  ///
  /// It was eight chips first. That is two wrapped rows for a question whose
  /// answer is the base currency almost every time, and it pushed the Save
  /// button off the bottom of the sheet, which is the same defect this feature
  /// already fixed once by removing the Kind chips. A row that states the
  /// current answer and opens a list is smaller, matches the bank field right
  /// under it, and makes the ordinary answer the cheapest one.
  ///
  /// The warning below it is the point of the whole control. Somebody who
  /// records a dollar account and is not told it sits outside their peso
  /// totals will read a net worth that silently omits it, and a missing
  /// feature is visible where a wrong total is not. So the consequence is
  /// stated at the moment of choosing.
  Widget _currencyRow() {
    final base = baseCurrencyOf(widget.store.data);
    final shown = _currencyCode.isEmpty ? base : _currencyCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Barako.card,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await _pickCurrency(base, shown);
              if (picked == null || !mounted) return;
              setState(() => _currencyCode = picked == base ? '' : picked);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$shown  ${currencySymbol(shown)}',
                      style: TextStyle(
                        color: Barako.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(salapifyIcon('forward'), color: Barako.faint, size: 20),
                ],
              ),
            ),
          ),
        ),
        if (shown != base) ...[
          const SizedBox(height: 6),
          Text(
            'Salapify cannot convert $shown to $base yet, so this will NOT be '
            'counted in your net worth or your daily number. It stays on this '
            'screen with its own amount.',
            style: AppText.caption.tint(Barako.warningStrong),
          ),
        ],
      ],
    );
  }

  Future<String?> _pickCurrency(String base, String current) {
    // The base currency pinned first, then the ones people here actually hold,
    // then everything else. Not alphabetical: the answer somebody wants is
    // almost always in the first two rows, and an alphabetical list buries it.
    const common = ['USD', 'EUR', 'GBP', 'JPY', 'SGD', 'AUD', 'CAD', 'HKD'];
    final order = <String>{
      base,
      ...common,
      for (final c in currencies) c['code']!,
    };
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Barako.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            children: [
              Text(
                'Which currency?',
                style: AppText.title.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 8),
              for (final code in order)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '$code  ${currencySymbol(code)}',
                    style: TextStyle(color: Barako.text),
                  ),
                  subtitle: code == base
                      ? Text(
                          'Your app currency. Counted in every total.',
                          style: AppText.caption,
                        )
                      : null,
                  trailing: current == code
                      ? Icon(salapifyIcon('check'), color: Barako.primary)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(code),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _institutionRow() {
    final label = _institutionId.isEmpty
        ? 'Choose'
        : (institutionById(_institutionId)?.displayName ?? 'Choose');
    return Material(
      color: Barako.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picked = await showInstitutionPicker(
            context,
            current: _institutionId,
          );
          // Null means dismissed, which is NOT the same as choosing none. A
          // back swipe must not silently clear an answer already given.
          if (picked == null || !mounted) return;
          setState(() => _institutionId = picked);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              InstitutionAvatar(id: _institutionId, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: _institutionId.isEmpty ? Barako.muted : Barako.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(salapifyIcon('forward'), color: Barako.faint, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  double? _parseAmount(String t) {
    if (t.trim().isEmpty) return null;
    final n = double.tryParse(t.trim());
    if (n == null || !n.isFinite || n < 0) return null;
    return n;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!widget.store.canWrite) {
      _offBanner();
      return;
    }
    if (_name.text.trim().isEmpty) {
      setState(() => _err = 'Please enter a name.');
      return;
    }
    final amount = _parseAmount(_amount.text);
    if (amount == null) {
      setState(() => _err = 'Enter a valid amount (0 or more).');
      return;
    }

    if (!widget.isAccount) {
      final name = _name.text.trim();
      final aid = widget.item?['id'];
      setState(() => _saving = true);
      // Only update a real, id-carrying asset; otherwise add a fresh one, so a
      // hand-edited backup asset without a string id never crashes on the cast.
      if (aid is String) {
        await widget.store.updateAsset(
          aid,
          name: name,
          kind: _kind,
          value: amount,
        );
      } else {
        await widget.store.addAsset(
          name: name,
          kind: _kind,
          value: amount,
          meta: _meta(),
        );
      }
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // Account.
    double? target = 0;
    if (_target.text.trim().isNotEmpty) {
      target = _parseAmount(_target.text);
      if (target == null) {
        setState(() => _err = 'Enter a valid target, or leave it empty.');
        return;
      }
    }
    final name = _name.text.trim();
    final brand = _brand.text.trim();
    // The default emoji is NOT written when a bank was chosen and no icon was
    // typed, so the row can show that bank's initials. Writing 💵 anyway would
    // make "the person left it blank" and "the person picked the money emoji"
    // the same stored value, and the row would then have to guess which, which
    // is exactly the guess the icon rule forbids.
    final typedIcon = _icon.text.trim();
    final icon = typedIcon.isNotEmpty
        ? typedIcon
        : (_institutionId.isNotEmpty ? '' : '💵');

    setState(() => _saving = true);
    final id = widget.item?['id'];
    if (id is String) {
      final oldBal = amountOf(widget.item!['balance']);
      await widget.store.updateAccountDetails(
        id,
        name: name,
        kind: _kind,
        brand: brand,
        icon: icon,
        target: target,
      );
      final delta = balanceAdjustDelta(amount, oldBal);
      if (delta > 0) {
        await _post(id, 'adjustment', 'in', delta, 'Balance adjustment');
      } else if (delta < 0) {
        await _handleDecrease(id, -delta);
      }
    } else {
      await widget.store.addAccount(
        name: name,
        kind: _kind,
        brand: brand,
        icon: icon,
        target: target,
        balance: amount,
        meta: _meta(),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// A balance drop is often an unlogged expense. Offer to record it as one
  /// (which counts in spending) or as a plain correction; either lands the
  /// balance on the typed total. Not cancelable, so the change is never lost.
  Future<void> _handleDecrease(String id, double amt) async {
    if (!mounted) return;
    final asExpense = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text(
          'Was this money spent?',
          style: TextStyle(color: Barako.text),
        ),
        content: Text(
          'Your balance is ${formatMoneyText(amt)} lower. Logging it as an expense keeps your spending reports right. If it is just a correction, we record a balance adjustment instead.',
          style: TextStyle(color: Barako.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Just a correction',
              style: TextStyle(color: Barako.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Log as expense',
              style: TextStyle(
                color: Barako.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (asExpense == true) {
      await _post(id, 'expense', null, amt, 'Unlogged expense');
    } else {
      await _post(id, 'adjustment', 'out', amt, 'Balance adjustment');
    }
  }

  Future<void> _post(
    String id,
    String type,
    String? flow,
    double amount,
    String label,
  ) async {
    final tx = <String, dynamic>{
      'type': type,
      'accountId': id,
      'amount': amount,
      'label': label,
      'date': _todayISO(),
      'flow': ?flow,
    };
    try {
      await widget.store.addEntry(tx);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record the balance change. $e')),
        );
      }
    }
  }

  void _delete() {
    if (!_confirmDel) {
      setState(() => _confirmDel = true);
      return;
    }
    if (!widget.store.canWrite) {
      _offBanner();
      return;
    }
    final id = widget.item?['id'];
    if (id is String) {
      if (widget.isAccount) {
        widget.store.deleteAccount(id);
      } else {
        widget.store.deleteAsset(id);
      }
    }
    Navigator.of(context).pop();
  }

  void _offBanner() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Saving is off because your data could not be read. Import a backup to recover first.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final kinds = widget.isAccount ? _accountKinds : _assetKinds;
    final noun = widget.isAccount ? 'account' : 'asset';
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Barako.background,
          border: Border.all(color: Barako.border),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight:
              (MediaQuery.of(context).size.height -
                  MediaQuery.of(context).viewInsets.bottom) *
              0.9,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // The seed's own words, so the sheet confirms what was just
                // chosen instead of falling back to "Add account" and leaving
                // the person wondering whether the tap registered.
                _isEdit
                    ? 'Edit $noun'
                    : 'Add ${widget.seed?.label.toLowerCase() ?? noun}',
                style: TextStyle(
                  color: Barako.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (!_isEdit && widget.seed != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.seed!.hint,
                  style: AppText.small.tint(Barako.muted),
                ),
              ],
              _label('Name'),
              _input(_name, hint: 'e.g. GCash', action: TextInputAction.next),
              // The Kind chips are HIDDEN once the sheet was reached through
              // the Add flow, because the question was already asked and
              // answered one screen ago. Leaving them was worse than
              // redundant: picking "Payroll account" and then flipping the
              // chip to Cash stored kind:'cash' with subtype:'payroll_account',
              // an account that disagrees with its own classification and no
              // screen would ever explain. The render is what showed this;
              // reading the code, the two rows are two hundred lines apart.
              if (_isEdit || widget.seed == null) ...[
                _label('Kind'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (key, lbl) in kinds)
                      ChoiceChip(
                        label: Text(lbl),
                        selected: _kind == key,
                        onSelected: (_) => setState(() => _kind = key),
                        selectedColor: Barako.primary,
                        backgroundColor: Barako.card,
                        labelStyle: TextStyle(
                          color: _kind == key
                              ? Barako.onPrimary
                              : Barako.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(color: Barako.border),
                      ),
                  ],
                ),
              ],
              _label(widget.isAccount ? 'Balance' : 'Value'),
              _input(
                _amount,
                hint: '0',
                number: true,
                action: widget.isAccount
                    ? TextInputAction.next
                    : TextInputAction.done,
              ),
              if (_isEdit && widget.isAccount) ...[
                const SizedBox(height: 6),
                Text(
                  'Set this to the real total in your account. We log the difference so your reports and History stay right.',
                  style: AppText.caption.tint(Barako.faint),
                ),
              ],
              if (!_isEdit && widget.seed != null) ...[
                _label('Currency'),
                _currencyRow(),
              ],
              // Only when the subtype actually has an institution. A cash
              // on hand row has no bank, and asking anyway is the tap tax the
              // design document warns about.
              if (!_isEdit && (widget.seed?.hasInstitution ?? false)) ...[
                _label('Bank or wallet (optional)'),
                _institutionRow(),
              ],
              if (widget.isAccount) ...[
                // The free text brand field is hidden when the institution
                // PICKER is showing, because the two asked the same question
                // one above the other, in different words, with different
                // answers. The render made that obvious in a second and the
                // code never would have.
                if (!(!_isEdit && (widget.seed?.hasInstitution ?? false))) ...[
                  _label('Bank or brand (optional)'),
                  _input(
                    _brand,
                    hint: 'e.g. BPI',
                    action: TextInputAction.next,
                  ),
                ],
                _label('Icon emoji (optional)'),
                _input(_icon, hint: '💵', action: TextInputAction.next),
                _label('Savings target (optional)'),
                _input(
                  _target,
                  hint: '0',
                  number: true,
                  action: TextInputAction.done,
                ),
              ],
              if (_err != null) ...[
                const SizedBox(height: 10),
                Text(_err!, style: AppText.small.tint(Barako.warningStrong)),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_isEdit)
                    TextButton(
                      onPressed: _delete,
                      style: _confirmDel
                          ? TextButton.styleFrom(
                              backgroundColor: Barako.warningStrong.withValues(
                                alpha: 0.12,
                              ),
                            )
                          : null,
                      child: Text(
                        _confirmDel ? 'Tap again to delete' : 'Delete',
                        style: TextStyle(
                          color: Barako.warningStrong,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Barako.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: Barako.primary,
                          foregroundColor: Barako.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(t, style: AppText.caption),
  );

  Widget _input(
    TextEditingController c, {
    String? hint,
    bool number = false,
    TextInputAction? action,
  }) {
    return TextField(
      controller: c,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textInputAction: action,
      inputFormatters: number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      style: AppText.body,
      decoration: InputDecoration(
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
    );
  }
}

/// Move money between two accounts.
///
/// Every peso decision here belongs to money/transfers.dart, which is locked
/// to the RN engine by golden vectors. This sheet collects three fields and
/// shows whatever the engine says: it does no arithmetic of its own, on
/// purpose, because a screen that computes a peso is how two versions of one
/// number start to disagree.
class _TransferSheet extends StatefulWidget {
  final SalapifyStore store;
  const _TransferSheet({required this.store});

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final _amount = TextEditingController();
  late String _fromId;
  late String _toId;
  bool _saving = false;
  String? _err;

  List<Map<String, dynamic>> get _accounts {
    final raw = widget.store.data['accounts'];
    return [
      for (final a in (raw is List ? raw : const []))
        if (a is Map) a.cast<String, dynamic>(),
    ];
  }

  @override
  void initState() {
    super.initState();
    // The RN defaults: the first two accounts, so the common case is one tap
    // and an amount.
    final list = _accounts;
    _fromId = list.isNotEmpty ? '${list[0]['id']}' : '';
    _toId = list.length > 1 ? '${list[1]['id']}' : '';
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _err = null;
    });
    TransferOutcome? refusal;
    try {
      refusal = await widget.store.transferBetweenAccounts(
        fromId: _fromId,
        toId: _toId,
        amountText: _amount.text,
      );
    } catch (e) {
      // A failed save, or writing shut after an unreadable load. Without this
      // the button stayed disabled forever with nothing on screen, leaving
      // the person unable to tell whether their money moved. Every other
      // write on this screen already catches.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _err = 'Could not move it, nothing was changed. $e';
      });
      return;
    }
    if (!mounted) return;
    if (refusal != null) {
      setState(() {
        _saving = false;
        _err = _honest(refusal!);
      });
      return;
    }
    Navigator.of(context).pop();
  }

  /// The refusal as a sentence that cannot contradict itself.
  ///
  /// The engine's own overdraft message rounds the balance, because it is
  /// locked to the RN wording, so an account holding 3,200.995 reports "only
  /// has 3,201" and then refuses a transfer of 3,201: same figure, opposite
  /// answers. The engine keeps its string so the two apps stay comparable,
  /// and the screen says the truthful thing using the same truncated label
  /// the picker chips show, so the sentence and the chips always agree.
  String _honest(TransferOutcome r) => switch (r.refusal) {
    TransferRefusal.overdraft =>
      '${_nameOf(_fromId)} only has ${balanceLabel(r.available ?? 0)}.',
    _ => r.error ?? 'Could not move it.',
  };

  String _nameOf(String id) {
    for (final a in _accounts) {
      if ('${a['id']}' == id) return '${a['name'] ?? 'That account'}';
    }
    return 'That account';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) => _sheet(context),
  );

  Widget _sheet(BuildContext context) {
    final list = _accounts;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Barako.background,
          border: Border.all(color: Barako.border),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight:
              (MediaQuery.of(context).size.height -
                  MediaQuery.of(context).viewInsets.bottom) *
              0.9,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        // The fields SCROLL and the actions are PINNED below them. The old
        // layout put the whole sheet, buttons included, in one scroll view, so
        // on a short phone with the keyboard up, large text, or long account
        // names the pickers could push "Move it" off the bottom and there was
        // no signal it was down there. Flexible gives the scroll area the space
        // left after the pinned footer, so the primary action is always visible
        // within the maxHeight box and above the keyboard inset.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Move money',
                      style: AppText.title.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This is not income and not spending, so it never touches '
                      'your budget. It just moves the balances.',
                      style: AppText.small.copyWith(height: 1.4),
                    ),
                    _label('From'),
                    _picker(list, _fromId, (v) => setState(() => _fromId = v)),
                    _label('To'),
                    _picker(list, _toId, (v) => setState(() => _toId = v)),
                    _label('Amount'),
                    TextField(
                      controller: _amount,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: AppText.heading.copyWith(fontSize: 20),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: Barako.faint),
                        prefixText: '$baseCurrencySymbol ',
                        prefixStyle: AppText.bodyLg
                            .tint(Barako.muted)
                            .copyWith(fontSize: 20),
                        filled: true,
                        fillColor: Barako.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Radii.md),
                          borderSide: BorderSide(color: Barako.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Radii.md),
                          borderSide: BorderSide(color: Barako.border),
                        ),
                      ),
                      onSubmitted: (_) => _save(),
                    ),
                  ],
                ),
              ),
            ),
            // Pinned footer: the refusal line and the actions, always on screen.
            if (_err != null) ...[
              const SizedBox(height: 10),
              // liveRegion, so a screen reader announces the refusal. Without it
              // a blind user taps "Move it", hears nothing, and has no signal
              // that the money did not move.
              Semantics(
                liveRegion: true,
                child: Text(
                  _err!,
                  // Capped: this line is pinned OUTSIDE the scroll area, and the
                  // catch branch can interpolate a raw exception, so on a very
                  // short height a long message could otherwise overflow the
                  // sheet. Four lines is plenty for the refusal sentences.
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small.tint(Barako.warningStrong),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Wrap, not Row: at a large text scale on a narrow phone "Cancel"
            // and "Move it" side by side overflow the width, and a Row would
            // paint the barber-pole overflow stripe. Wrap drops "Move it" to a
            // second right-aligned line instead, so both stay reachable.
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Barako.textSecondary),
                  ),
                ),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: Barako.primary,
                    foregroundColor: Barako.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                  child: const Text(
                    'Move it',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(t, style: AppText.caption),
  );

  /// The account chips, each showing what it holds, because "can I move 5,000
  /// out of GCash" is answered by seeing the balance, not by being told no
  /// after typing.
  Widget _picker(
    List<Map<String, dynamic>> list,
    String selected,
    void Function(String) onPick,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final a in list)
        ChoiceChip(
          label: Text(
            '${a['name'] ?? 'Account'}  ${balanceLabel(amountOf(a['balance']))}',
          ),
          selected: selected == '${a['id']}',
          onSelected: (_) => onPick('${a['id']}'),
          selectedColor: Barako.primary,
          backgroundColor: Barako.card,
          labelStyle: TextStyle(
            color: selected == '${a['id']}'
                ? Barako.onPrimary
                : Barako.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: Barako.border),
        ),
    ],
  );
}

/// The rate dialog, as a widget rather than a local in an async function.
///
/// It was a local first, and that was a CRASH, not a style problem. The
/// controller was disposed the moment showDialog returned, while the dialog
/// was still animating out and its TextField was still reading it, so tapping
/// "Use this rate" threw "A TextEditingController was used after being
/// disposed" and took the frame down. A widget test found it; nothing in the
/// code reads as wrong.
class _ManualRateDialog extends StatefulWidget {
  final String code;
  final String base;
  final double? existing;
  const _ManualRateDialog({
    required this.code,
    required this.base,
    this.existing,
  });

  @override
  State<_ManualRateDialog> createState() => _ManualRateDialogState();
}

class _ManualRateDialogState extends State<_ManualRateDialog> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _ctl = TextEditingController(
      text: e == null
          ? ''
          : (e == e.roundToDouble() ? e.toInt().toString() : e.toString()),
    );
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Barako.surfaceRaised,
      title: Text(
        '${widget.code} to ${widget.base}',
        style: TextStyle(color: Barako.text),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // The direction is stated in words, because a rate typed upside
            // down is a total wrong by a factor of thousands and looks
            // perfectly reasonable on the way in.
            'How many ${widget.base} is ONE ${widget.code} worth?',
            style: AppText.small.tint(Barako.muted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ctl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: Barako.text),
            decoration: const InputDecoration(hintText: 'e.g. 56.50'),
          ),
        ],
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(0.0),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(double.tryParse(_ctl.text.trim().replaceAll(',', ''))),
          child: const Text('Use this rate'),
        ),
      ],
    );
  }
}

/// One card's worth of data for the carousel, resolved from a stored row so the
/// PageView and the detail panel never re-read the raw map.
class _CardItem {
  final Map<String, dynamic> row;
  final AccountStore store;
  final String name;
  final String typeLabel;
  final String subtitle;
  final Color? brandColor;
  final String? last4;
  final double amount;

  /// The preformatted amount for a foreign-currency account (its own symbol).
  /// Null for a base-currency account, where the card formats [amount] as pesos.
  final String? amountText;

  /// The bank's initials for the card's corner watermark, or null to let the
  /// card derive them from the name.
  final String? monogram;
  final double? limit;

  /// The card network's wordmark ("VISA"), or null. Credit cards only.
  final String? networkMark;
  final BankCardVariant variant;

  /// Physical cash: rendered as a wallet, not a bank card, and it does not flip
  /// (there is no number, chip, network or QR to turn over to). A tap opens the
  /// account instead.
  final bool isCash;
  const _CardItem({
    required this.row,
    required this.store,
    required this.name,
    required this.typeLabel,
    required this.subtitle,
    required this.brandColor,
    required this.last4,
    required this.amount,
    required this.variant,
    this.amountText,
    this.monogram,
    this.limit,
    this.networkMark,
    this.isCash = false,
  });
}

/// A horizontal, peeking carousel of bank cards.
///
/// viewportFraction 0.88 leaves the next card peeking from the right, so it
/// reads as swipeable at a glance. A light selection tick fires when the page
/// settles on a new card, and the card in focus drives the detail panel below.
class _AccountsCarousel extends StatefulWidget {
  final List<_CardItem> items;
  final SalapifyStore store;
  final QrVault? vault;

  /// Open the full wallet page for a card (its back's "View full details").
  final void Function(_CardItem) onOpen;

  /// Open the edit sheet for a card (its back's edit action).
  final void Function(_CardItem) onEdit;

  /// Show the one-time "Tap to view details" nudge on the focused front.
  final bool showHint;

  /// The founder flipped a card for the first time; persist that the nudge is
  /// no longer needed.
  final VoidCallback onFirstFlip;

  const _AccountsCarousel({
    required this.items,
    required this.store,
    required this.vault,
    required this.onOpen,
    required this.onEdit,
    required this.showHint,
    required this.onFirstFlip,
  });

  @override
  State<_AccountsCarousel> createState() => _AccountsCarouselState();
}

class _AccountsCarouselState extends State<_AccountsCarousel>
    with WidgetsBindingObserver {
  final _controller = PageController(viewportFraction: 0.88);
  int _index = 0;

  /// Which card is currently flipped to its back, or null for all-front. A
  /// single int is what enforces "only one card flipped at a time" for free.
  int? _flipped;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding returns every card to its front. The FlipBankCard re-masks
    // any revealed digits itself; this is the other half, the cards' faces.
    if (state != AppLifecycleState.resumed && _flipped != null) {
      setState(() => _flipped = null);
    }
  }

  @override
  void didUpdateWidget(_AccountsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A card was deleted while this was open and the focus now points past the
    // last page. Clamp it and jump the controller after the frame, so the
    // viewport does not sit on a blank page the swipe never corrected.
    final last = widget.items.length - 1;
    if (_index > last && last >= 0) {
      _index = last;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(last);
      });
    }
    // A flipped card that no longer exists (deleted, filtered) returns to none.
    if (_flipped != null && _flipped! > last) _flipped = null;
  }

  void _onPageChanged(int i) {
    if (i == _index) return;
    // Swiping to another card returns the one we left to its front, so a list
    // never scrolls with a card sitting open behind the one in focus.
    setState(() {
      _index = i;
      _flipped = null;
    });
    // The page settled on a new card: a light tick, the same feel as a native
    // wallet flicking between cards.
    HapticFeedback.selectionClick();
  }

  void _flip(int i, bool want) {
    if (want && widget.showHint) widget.onFirstFlip();
    setState(() => _flipped = want ? i : null);
  }

  void _open(_CardItem it) {
    // Leaving for the full page returns the card to its front, so it is not
    // sitting flipped when the founder swipes back.
    setState(() => _flipped = null);
    widget.onOpen(it);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    // Defensive: the parent only builds this with two or more cards, but a
    // clamp on an empty list throws, so never assume it.
    if (items.isEmpty) return const SizedBox.shrink();
    final focus = _index.clamp(0, items.length - 1);
    // A card is never wider than a phone-sized card, even on a tablet or a wide
    // window: past this it becomes a giant rectangle, and it also pushed the
    // account list far enough down that a lazy sliver stopped building it.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth * 0.88 - 12;
            // The card's own aspect ratio, plus a little room for its tinted
            // shadow so the shadow is not clipped by the PageView's bounds.
            final height = cardWidth / 1.586 + 22;
            // A lone card is not a "swipe between several": show it centred with
            // no page dots, rather than a one-page PageView that peeks at empty
            // space. It still flips and reveals through the same state. This is
            // the case that keeps a user with one bank card and cash from losing
            // their card when cash moved out of the deck.
            final single = items.length == 1;
            return Column(
              children: [
                SizedBox(
                  height: height,
                  child: single
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: _card(items[0], 0, focus),
                        )
                      : PageView.builder(
                          controller: _controller,
                          onPageChanged: _onPageChanged,
                          itemCount: items.length,
                          itemBuilder: (context, i) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: _card(items[i], i, focus),
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                if (!single) _pageIndicator(items.length, focus),
                if (!single) const SizedBox(height: 12),
                _CardDetail(item: items[focus]),
              ],
            );
          },
        ),
      ),
    );
  }

  /// One flip card in the deck. Extracted so the single-card layout and the
  /// PageView share exactly one construction (same key discipline, same flip
  /// wiring), and the itemBuilder stays a one-liner.
  Widget _card(_CardItem it, int i, int focus) => PressableScale(
    child: FlipBankCard(
      // Key by the stored id so deleting a card disposes the RIGHT card
      // (releasing its secure latch), but fall back to the index for a malformed
      // row whose id is missing or an empty string, so two such rows cannot
      // collapse to the same key and trip Flutter's duplicate-key assertion.
      key: ValueKey(
        (it.row['id'] is String && (it.row['id'] as String).isNotEmpty)
            ? it.row['id']
            : i,
      ),
      row: it.row,
      vault: widget.vault,
      bankName: it.name,
      accountType: it.typeLabel,
      brandColor: it.brandColor,
      last4: it.last4,
      balance: it.amount,
      amountText: it.amountText,
      monogram: it.monogram,
      creditLimit: it.limit,
      networkMark: it.networkMark,
      variant: it.variant,
      flipped: _flipped == i,
      // The nudge sits only on the focused, front-facing card, never on the
      // peeking neighbour.
      showHint: widget.showHint && i == focus && _flipped == null,
      onFlip: (want) => _flip(i, want),
      onViewFullDetails: () => _open(it),
      onEdit: () => widget.onEdit(it),
    ),
  );

  /// Dots for a handful of cards, a compact "n of m" once there are enough that
  /// a row of dots would overflow a narrow phone.
  Widget _pageIndicator(int count, int focus) {
    if (count > 8) {
      return Text('${focus + 1} of $count', style: AppText.caption);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: i == focus ? 18 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: i == focus ? Barako.primary : Barako.border,
            ),
          ),
      ],
    );
  }
}

/// The panel under the carousel, driven by the focused card.
///
/// It deliberately does NOT repeat the card's name or its big balance, which
/// the card already shows two centimetres above. It adds what the card cannot:
/// what the account IS (subtype and institution), and, for a credit card, how
/// much room is left. Keeping the name off this panel is also what stops it
/// colliding with the card in a "find this account once" test: the card is the
/// one on-screen copy of the name, and tapping it opens the editor.
class _CardDetail extends StatelessWidget {
  final _CardItem item;
  const _CardDetail({required this.item});

  @override
  Widget build(BuildContext context) {
    final isCredit = item.variant == BankCardVariant.credit;
    final limit = item.limit ?? 0;
    final available = (limit - item.amount)
        .clamp(0, double.infinity)
        .toDouble();
    return Card(
      color: Barako.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.w6,
            ),
            if (isCredit && limit > 0) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Available credit', style: AppText.caption),
                  Text(
                    formatMoneyText(available),
                    style: AppText.amountRow.tint(Barako.primaryText),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text('Tap the card to flip it over.', style: AppText.caption),
            ],
          ],
        ),
      ),
    );
  }
}
