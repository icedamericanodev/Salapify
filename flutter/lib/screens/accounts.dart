// Accounts: see, add, edit, and delete your accounts and assets, change a
// balance, and move money between two accounts. Reached from the Overview,
// ported from mobile/app/accounts.js. A balance change to an existing account
// posts a recorded adjustment through the golden-verified ledger (reversible,
// shows in History) rather than silently overwriting the number, and the
// transfer sheet at the bottom of this file spends every peso decision
// through money/transfers.dart, which is locked to the RN engine by goldens.

import 'dart:async' show Timer;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';

import '../money/accounts_calc.dart';
import '../money/debtmath.dart' show formatMoneyText;
import '../money/format.dart' show formatMoney;
import '../money/greeting.dart' show greetingFor;
import '../money/net_worth_history.dart'
    show netWorthHistoryOf, netWorthMonthKey, netWorthTrend, netWorthWindow;
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
import '../money/account_taxonomy.dart';
import '../money/commitments.dart'
    show bankDueDate, daysUntil, daysUntilWords, shortDueDate;
import '../money/card_products.dart' show cardNetworkWordmark;
import '../data/export_files.dart' show shareAccountStatementPdf;
import '../data/qr_vault.dart' show QrVault;
import '../services/card_skins.dart' show CardSkinStore;
import 'account_detail.dart' show AccountDetailScreen, showAccountQrSheet;
import 'assets_liabilities.dart' show AssetsLiabilitiesScreen, AssetsView;
import 'history.dart' show HistoryScreen;
import 'log_sheet.dart' show showLogSheet;
import 'net_worth_trend.dart' show NetWorthTrendScreen;
import '../widgets/account_action_sheet.dart' show showAccountActionSheet;
import '../widgets/card_skin_studio.dart' show showCardSkinStudio;
import '../widgets/floating_pan_card.dart' show FloatingPanCard;
import '../widgets/pan_mascot.dart' show PanMascot, PanEmotion;
import '../money/institutions.dart'
    show
        institutionBrandColor,
        institutionById,
        institutionLabel,
        institutionLogoAsset;
import '../theme.dart';
import '../typography.dart';
import 'add_account_flow.dart'
    show InstitutionAvatar, showAddAccountSheet, showInstitutionPicker;
import 'debts.dart' show showDebtFormSheet;
import '../widgets/bank_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/net_worth_sparkline.dart' show NetWorthSparkline;
import '../widgets/pressable_scale.dart';
import '../widgets/progress_bar.dart';
import '../widgets/salapify_icon.dart';
import '../widgets/screen_header.dart' show MenuAction;

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

  /// Opens the Menu. Set only when Accounts is the resident bottom-bar tab (the
  /// shell hands it down): a bar tab has no back button, so this is its one way
  /// into the sixteen Menu destinations, the same door the other tabs carry.
  /// Null on a deep push, where the AppBar's own back button is the way out and
  /// a Menu action would be redundant.
  final VoidCallback? onMenu;

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
    this.onMenu,
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

  /// Which category groups are EXPANDED in the Accounts Overview accordion, by
  /// their stable group id (cash_bank / ewallets / investments / property /
  /// credit / loans). In memory only, so a fresh open starts from the calm
  /// collapsed overview; the choice is transient the same way the old per-group
  /// collapse was. Seeded in initState so the screen never opens all-collapsed
  /// (the first non-empty group opens) and a searched account's group is open.
  final Set<String> _expanded = {};

  /// Whether the collapsed-state seed has run. The seed needs the built groups,
  /// which only exist inside build, so it runs once on the first build rather
  /// than in initState where the store rows are not yet grouped.
  bool _seededExpansion = false;

  /// The active class filter for the overview: 'all', 'assets', 'liabilities',
  /// or 'hidden'. 'hidden' surfaces accounts the person archived or excluded
  /// from net worth, which are otherwise left out of the counted groups. In
  /// memory only, resets to 'all' on a fresh open.
  String _filter = 'all';

  /// How many trailing months the hero sparkline plots, or null for the whole
  /// recorded history. The period selector sets it; the chart never invents a
  /// point, so a short history simply draws fewer. In memory only.
  int? _sparkMonths;

  @override
  void initState() {
    super.initState();
    final id = widget.focusAccountId;
    if (id != null) {
      _highlightId = id;
      // A deep-linked account only builds inside its OWN group, and only when
      // that group is EXPANDED (a collapsed group does not render its rows), so
      // open the account's group up front or the reveal scroll finds no
      // element. Search targets accounts, which live in Cash & Bank or
      // E-Wallets. Marking it seeded stops the first-non-empty seed from also
      // opening a second group and pushing the focused row further down.
      _expanded.add(_groupIdForAccount(id));
      _seededExpansion = true;
      // A hidden (archived or excluded) account is filtered out of the default
      // "all" view, so its row would never render and the reveal would land on
      // nothing. Open the Hidden filter for it, so the focused row is actually
      // built in the group above and the scroll and flash have something to
      // reach.
      for (final r in _rows('accounts')) {
        if ('${r['id']}' == id && !countsInNetWorth(r)) {
          _filter = 'hidden';
          break;
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealFocus(id));
    }
  }

  /// The overview group a stored account id belongs to, for the search reveal.
  /// Accounts are the only focus targets, so the answer is E-Wallets for an
  /// e-wallet subtype and Cash & Bank for everything else in the accounts
  /// store.
  String _groupIdForAccount(String id) {
    for (final r in _rows('accounts')) {
      if ('${r['id']}' == id) {
        return resolveKind(r, AccountStore.accounts).subtype.id == 'ewallet'
            ? 'ewallets'
            : 'cash_bank';
      }
    }
    return 'cash_bank';
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
    // This reaches a match far down a long list. It works because the selected
    // tab's rows render inside ONE eager Column (a Card's child), so the
    // searched row's element exists even when painted well below the fold, and
    // because initState already selected the account's own tab (Bank or
    // E-Wallets) before this post-frame callback runs, so the target row is in
    // the built tab. The caveat a future change must respect, or this scroll
    // dies SILENTLY (no snackbar, the account was confirmed present above): a
    // row in an UNSELECTED tab is not built. If a reveal ever has to reach a
    // row in another tab, select that tab before calling ensureVisible.
    // accounts_focus_scroll_test.dart proves the 40th of 40 accounts is scrolled
    // onto the screen.
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

  /// Whether balances are masked on this screen. A privacy toggle the eye in the
  /// hero flips, persisted in settings (the same free settings map the widget's
  /// hide-amount preference uses), so a shoulder-surfer glance never reveals a
  /// figure and the choice survives a reopen. Read live from the store, not held
  /// in local state, so the toggle and every masked figure can never disagree.
  bool get _hideBalances =>
      (store.data['settings'] as Map?)?['accountsHideBalances'] == true;

  void _toggleHideBalances() {
    Haptics.select();
    store.setSetting('accountsHideBalances', !_hideBalances);
  }

  /// A money figure for display, masked to dots when the privacy toggle is on.
  /// Every peso figure on the screen routes through this so one flag hides them
  /// all at once, and nothing that is hidden can leak through a stray call site.
  /// The real formatting stays formatMoneyText, so an unmasked figure is byte
  /// for byte what it was before this toggle existed.
  String _money(double v) => _hideBalances ? '₱ ••••' : formatMoneyText(v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        // Title plus the time-of-day greeting, the mockup's header. The greeting
        // moved here out of the hero card so the hero can lead with the number,
        // the way the mockup opens. greetingFor reads the clock and the stored
        // display name; both change rarely, so computing it in build is fine.
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Accounts'),
            Text(
              greetingFor(DateTime.now(), name: store.displayName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.tint(Barako.textSecondary),
            ),
          ],
        ),
        // Pan greets from the header, the way the mockup opens the screen, and
        // the Menu action follows when this is the resident bar tab. A bar tab
        // has no back button, so without the Menu action Accounts would be the
        // one primary screen with no one-tap way into the Menu; on a deep push
        // onMenu is null and the AppBar's own back arrow is the way out. Pan is
        // decoration, kept out of semantics.
        actions: [
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(right: Gap.xs),
              child: PanMascot.emotion(emotion: PanEmotion.content, size: 40),
            ),
          ),
          if (widget.onMenu != null) ...[
            MenuAction(onTap: widget.onMenu!),
            const SizedBox(width: Gap.sm),
          ],
        ],
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
            // The same golden-locked month move the hero reads, computed once
            // here so Pan's insight card and the hero can never disagree about
            // "this month". Null until there is a prior month to compare.
            final insightTrend = netWorthTrend(
              netWorthHistoryOf(store.data),
              netWorthMonthKey(DateTime.now()),
              parts['netWorth'] as double,
            );

            double amountOfRow((Map<String, dynamic>, AccountStore) e) =>
                switch (e.$2) {
                  AccountStore.accounts => amountOf(e.$1['balance']),
                  AccountStore.assets => amountOf(e.$1['value']),
                  AccountStore.debts => amountOf(e.$1['remaining']),
                };

            final anyRows = groups.values.any((g) => g.isNotEmpty);

            // "Money you can reach now": the sum of genuinely LIQUID asset
            // accounts, the mockup's Available card. The definition is the
            // financial-coach ruling, chosen so the one honest sentence under
            // the figure stays true: cash, e-wallets, digital banks, and the
            // deposit accounts (savings, checking, payroll), and NOTHING else.
            // Time deposits are locked, so "use or transfer today" would be a
            // lie about them; investments, property and credit are not money you
            // can spend right now. Rows the app cannot price (a foreign balance
            // with no rate) count as zero, exactly as they do in net worth, and
            // an archived or excluded row is left out via countsInNetWorth. The
            // amount is the SAME _countedAmount the subtotals use (base as-is,
            // foreign converted, unpriceable zero), summed at its real signed
            // value so a negative account is not hidden. No new arithmetic: this
            // folds the same per-row counting the rest of the screen already
            // trusts, so it can never disagree with the totals.
            const liquidSubtypes = {
              'cash_on_hand',
              'savings_account',
              'checking_account',
              'payroll_account',
              'digital_bank',
              'ewallet',
            };
            final liquidRows = groups['cash_equivalents']!
                .where(
                  (e) =>
                      liquidSubtypes.contains(
                        resolveKind(e.$1, e.$2).subtype.id,
                      ) &&
                      countsInNetWorth(e.$1),
                )
                .toList();
            final liquidTotal = liquidRows.fold(
              0.0,
              (t, e) => t + _countedAmount(e, amountOfRow(e)),
            );
            final liquidCount = liquidRows.length;
            // A tilde marks the figure as approximate when a foreign row was
            // converted into it, the same honesty the total above carries.
            final liquidApprox = liquidRows.any(
              (e) => _foreignCodeOf(e.$1) != null,
            );

            // Seed the accordion's open state once, on the first build that has
            // real groups: open the first non-empty COUNTED group so the screen
            // never lands all-collapsed with the person's money one tap away,
            // yet still reads as the calm overview the mockup opens on. A search
            // deep-link already seeded its own group in initState and set the
            // flag, so this never fights it.
            if (!_seededExpansion) {
              for (final g in _overviewGroups(groups, 'all')) {
                if (g.rows.isNotEmpty) {
                  _expanded.add(g.id);
                  // Only consume the seed once a group actually opened, so a
                  // fresh install (no groups yet) still auto-opens the first
                  // group the moment the person adds their first account,
                  // rather than burning the seed on the empty first build.
                  _seededExpansion = true;
                  break;
                }
              }
            }

            return ListView(
              // Extra bottom room so the last account or the manage-debts note is
              // never trapped under the shell's floating "Log" button, which
              // floats over this list at the bottom right. 96 clears the extended
              // FAB and its margin; normal scrolling reveals everything above it.
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              // When a search deep-link focuses an account, the reveal scrolls
              // to its row with Scrollable.ensureVisible, which needs the row's
              // group already BUILT: the group is a direct child of this lazy
              // ListView, so a group sitting below the default 250px cache
              // extent never builds and _focusKey.currentContext is null,
              // making the scroll die silently (see _revealFocus). The taller
              // hero pushed that boundary far enough to expose it. A generous
              // cache extent WHILE focusing builds every group so the reveal
              // always lands; normal browsing keeps the default lazy behaviour
              // and its cost. Guarded by accounts_focus_scroll_test.dart.
              scrollCacheExtent: widget.focusAccountId != null
                  ? ScrollCacheExtent.pixels(5000)
                  : null,
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
                // The compact command row: the four things a person opens this
                // screen to do, one tap from the number they just read. Shown
                // only once there is anything on the book; a fresh install
                // meets the empty state below, which carries its own Add
                // button, so an all-disabled action row never appears.
                if (anyRows) ...[
                  const SizedBox(height: Gap.lg),
                  _quickActions(
                    context,
                    canTransfer: groups['cash_equivalents']!.length > 1,
                  ),
                ],
                // "Money you can reach now", the mockup's Available card. It
                // replaces the old per-cash-account tiles with one honest
                // summary of everything liquid; the individual cash accounts
                // still live in the account list below, where they can be
                // opened and edited. Shown whenever there is at least one liquid
                // account.
                if (liquidCount > 0) ...[
                  const SizedBox(height: 20),
                  _availableCard(liquidTotal, liquidCount, liquidApprox),
                ],
                // Accounts Overview: the mockup's expandable category groups.
                // Each category collapses to a one-line header (icon, name,
                // count, class-coloured total, a chevron) and expands to its
                // accounts, with credit cards drawn as real cards. A class
                // filter row above it narrows to assets, liabilities, or the
                // accounts hidden from net worth. This replaces the old one-tab
                // chip filter; every peso still folds the SAME _countedAmount
                // the hero totals use, so a group total can never diverge.
                if (anyRows) ...[
                  const SizedBox(height: 24),
                  _overviewSection(context, groups, amountOfRow),
                ],
                // Pan's read on the month, the mockup's Pan AI card. It reuses
                // the golden-locked trend the hero shows, so the two can never
                // disagree, and opens the full trend on tap. Shown only when
                // there is a prior month to compare against.
                if (insightTrend != null) ...[
                  const SizedBox(height: 24),
                  _panInsight(insightTrend, _largestLiability(groups)),
                ],
                if (!anyRows)
                  // The shared empty-state shape. It carries the Add button
                  // itself now, because the quick-actions row is hidden until
                  // there is something on the book, so this is the only way
                  // forward on a fresh install.
                  EmptyState(
                    icon: 'wallet',
                    title: 'Nothing recorded yet',
                    body:
                        'Add the places where you keep your money and Salapify '
                        'will ask what each one is.',
                    actionLabel: 'Add an account',
                    onAction: () => _add(context),
                  ),
                if (anyRows) ...[
                  const SizedBox(height: 18),
                  _nonAffiliationNote(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// The trademark non-affiliation line the logo work requires: a bank's mark
  /// is shown only to identify the user's OWN account, never to imply a tie to
  /// the bank. Quiet, plain English, under the list once there is at least one
  /// account that could carry a logo.
  Widget _nonAffiliationNote() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
    child: Text(
      'Bank and e-wallet logos are shown only to help you identify your own '
      'accounts. Salapify is not affiliated with, endorsed by, or connected to '
      'any bank or e-wallet.',
      style: AppText.caption,
    ),
  );

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

  Widget _summary(Map<String, dynamic> parts) {
    final netWorth = parts['netWorth'] as double;
    final assets = parts['assets'] as double;
    final liabilities = parts['liabilities'] as double;
    // The ratio splits owned against owed. Only POSITIVE money counts as owned
    // or owed: an overdrawn account can drive the assets total negative, and
    // counting that as "owned" would announce a positive owned share over
    // money the reader does not have. A negative assets book reads 0% owned,
    // which is the honest answer.
    final ownedValue = assets > 0 ? assets : 0.0;
    final owedValue = liabilities > 0 ? liabilities : 0.0;
    final gross = ownedValue + owedValue;
    // Ownership share, rounded. Null when there is nothing on the book yet, so
    // the bar is hidden rather than dividing by zero on a fresh install. A side
    // that holds real money never rounds away to 0%: that would let the bar
    // deny a peso figure shown in the mini-stats right above it.
    int? ownedPct;
    if (gross > 0) {
      var p = (ownedValue / gross * 100).round();
      if (ownedValue > 0 && p == 0) p = 1;
      if (owedValue > 0 && p == 100) p = 99;
      ownedPct = p;
    }
    // The month move, from the SAME golden-locked trend the Overview hero
    // shows, so the two screens can never disagree about "this month". Null
    // until there is a prior month to compare against, and the line is simply
    // omitted then rather than faking a zero.
    final now = DateTime.now();
    final monthKey = netWorthMonthKey(now);
    final history = netWorthHistoryOf(store.data);
    final trend = netWorthTrend(history, monthKey, netWorth);
    // The sparkline plots the recorded snapshots plus today's live figure, cut
    // to the selected window. Fewer than two points draws nothing (the widget
    // and this guard agree), so the chart and its selector only appear once a
    // trend exists to show. Values, not the raw doubles, so the window applies.
    final sparkPoints = netWorthWindow(
      history,
      monthKey,
      netWorth,
      months: _sparkMonths,
    );
    final sparkValues = [for (final p in sparkPoints) p.value];
    final hasSpark = sparkValues.length >= 2;

    // The one raised hero, warmed by Barako.heroWash (the tokenized coffee
    // glow). The mockup's dashboard card: the NET WORTH kicker with a
    // hide-balances eye and a period selector on top, the figure and its
    // percentage move, the trend sparkline, then the assets-and-liabilities
    // split, the owned/owe bar, and one "View financial position" button.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.hero),
        border: Border.all(color: Barako.border),
        gradient: Barako.heroWash,
      ),
      padding: Insets.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kicker row: NET WORTH and the eye on the left, the period selector
          // on the right, the way the mockup lays out the card's top line.
          Row(
            children: [
              Text('NET WORTH', style: Barako.kickerStyle),
              const SizedBox(width: Gap.xs),
              _eyeToggle(),
              const Spacer(),
              if (hasSpark) _periodSelector(),
            ],
          ),
          const SizedBox(height: Gap.xs),
          // The figure and its delta open the full trend screen, one tap from
          // the number. A named button so a screen reader gets a destination,
          // not a stream of fragments, and it says "hidden" when masked.
          Semantics(
            button: true,
            label: _hideBalances
                ? 'Net worth hidden. Opens the trend over time.'
                : 'Net worth ${formatMoneyText(netWorth)}. Opens the trend over time.',
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Haptics.select();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NetWorthTrendScreen(store: store),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _money(netWorth),
                        maxLines: 1,
                        style: AppText.amountLg.w8,
                      ),
                    ),
                    if (trend != null) ...[
                      const SizedBox(height: Gap.sm),
                      _monthTrendLine(trend),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // The trend sparkline, the rising line the mockup draws under the
          // figure. Decorative shape only (no axis, no labels), so it is kept
          // out of semantics and stays even when balances are masked: it shows
          // the shape of the move, never a peso figure.
          if (hasSpark) ...[
            const SizedBox(height: Gap.md),
            ExcludeSemantics(
              child: NetWorthSparkline(values: sparkValues, height: 56),
            ),
          ],
          const SizedBox(height: Gap.lg),
          // Assets and liabilities, stacked full width. The old design put them
          // side by side, which truncated "TOTAL LIABILITIES" on a narrow
          // phone; stacked, each reads at full width and the figure right-aligns
          // with tabular digits so the two line up. Each taps into its own
          // breakdown. Assets keep the brand accent, liabilities the warning
          // red (the palette_contrast_test-guarded lighter red), and a status
          // dot carries the meaning alongside the colour, never colour alone.
          Container(height: 1, color: Barako.border),
          const SizedBox(height: Gap.lg),
          _heroLine(
            'Assets',
            assets,
            Barako.primaryText,
            Barako.primary,
            () => _openBreakdown(context, AssetsView.own),
          ),
          const SizedBox(height: Gap.md),
          _heroLine(
            'Liabilities',
            liabilities,
            Barako.warning,
            Barako.warning,
            () => _openBreakdown(context, AssetsView.owe),
          ),
          if (ownedPct != null) ...[
            const SizedBox(height: Gap.lg),
            _ownershipBar(ownedPct),
          ],
          const SizedBox(height: Gap.lg),
          _positionButton(),
        ],
      ),
    );
  }

  /// The hide-balances eye in the hero kicker. Flipping it masks every peso
  /// figure on the screen at once and persists the choice, so a shoulder glance
  /// never reads a balance. An icon control, so it carries its own spoken label.
  Widget _eyeToggle() {
    final hidden = _hideBalances;
    return Semantics(
      button: true,
      label: hidden ? 'Show balances' : 'Hide balances',
      child: ExcludeSemantics(
        child: InkResponse(
          radius: 22,
          onTap: _toggleHideBalances,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              salapifyIcon(hidden ? 'hide' : 'reveal'),
              size: IconSizes.inline,
              color: Barako.muted,
            ),
          ),
        ),
      ),
    );
  }

  /// The sparkline's period selector, the mockup's "This Month" control turned
  /// into an honest chart-range picker: it changes how many trailing months the
  /// trend line plots, nothing more. Labelled by the current window, never a
  /// period the numbers below it do not actually cover.
  Widget _periodSelector() {
    const options = <(int?, String, String)>[
      (6, '6M', 'Last 6 months'),
      (12, '1Y', 'Last 12 months'),
      (null, 'All', 'All time'),
    ];
    final current = options.firstWhere(
      (o) => o.$1 == _sparkMonths,
      orElse: () => options.last,
    );
    return Semantics(
      button: true,
      label: 'Trend range, ${current.$3}. Opens a range picker.',
      child: ExcludeSemantics(
        child: PopupMenuButton<int?>(
          initialValue: _sparkMonths,
          tooltip: 'Trend range',
          onSelected: (v) => setState(() => _sparkMonths = v),
          itemBuilder: (_) => [
            for (final (months, _, long) in options)
              PopupMenuItem<int?>(value: months, child: Text(long)),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Barako.card,
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(color: Barako.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(current.$2, style: AppText.small.w6.tint(Barako.text)),
                const SizedBox(width: 2),
                Icon(
                  salapifyIcon('expand'),
                  size: IconSizes.dense,
                  color: Barako.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One stacked hero line: a status dot, a plain-words label on the left, and
  /// the peso figure in its meaning colour with a chevron on the right. Full
  /// width, so the label never truncates the way the old side-by-side halves did,
  /// and the figure right-aligns with tabular digits so own and owe line up. The
  /// dot carries the meaning alongside the colour, never colour alone.
  Widget _heroLine(
    String label,
    double value,
    Color valueColor,
    Color dotColor,
    VoidCallback onTap,
  ) {
    return Semantics(
      button: true,
      label: _hideBalances
          ? '$label hidden. Opens the breakdown.'
          : '$label ${formatMoneyText(value)}. Opens the breakdown.',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Haptics.select();
            onTap();
          },
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Gap.sm),
              // The label ("Assets" / "Liabilities") gets an equal Flexible
              // share with the figure. In the shipped Jakarta font it fits at
              // full size (so it never truncates, which is what the readability
              // sweep checks), and it ellipsizes only as a last resort at a very
              // large system font rather than overflowing the row.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.w6.tint(Barako.text),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    _money(value),
                    maxLines: 1,
                    style: AppText.amountRow.w8.tint(valueColor),
                  ),
                ),
              ),
              const SizedBox(width: Gap.xs),
              Icon(
                salapifyIcon('forward'),
                size: IconSizes.dense,
                color: Barako.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The mockup's "View financial position" button: one full-width tap into the
  /// assets-and-liabilities breakdown, the net-worth view. Reuses _openBreakdown
  /// so it lands on the same screen the totals do, just without preselecting a
  /// side.
  Widget _positionButton() {
    return Semantics(
      button: true,
      label: 'View financial position. Opens assets and liabilities.',
      child: ExcludeSemantics(
        child: Material(
          color: Barako.surfaceRaised,
          borderRadius: BorderRadius.circular(Radii.control),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.control),
            onTap: () {
              Haptics.select();
              _openBreakdown(context, AssetsView.netWorth);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg,
                vertical: Gap.md,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.control),
                border: Border.all(color: Barako.border),
              ),
              child: Row(
                children: [
                  Icon(
                    salapifyIcon('chart'),
                    size: IconSizes.inline,
                    color: Barako.primaryText,
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      'View financial position',
                      style: AppText.body.w7,
                    ),
                  ),
                  Icon(
                    salapifyIcon('forward'),
                    size: IconSizes.inline,
                    color: Barako.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The net worth move this month, the mockup's green delta under the figure.
  ///
  /// Reads the SAME netWorthTrend the Overview hero reads and matches its
  /// icon-and-colour convention (up in the brand accent, down in muted ink, a
  /// flat month in words), so a person who sees both heroes never finds them
  /// disagreeing. The wording is "this month" per the mockup; Overview says
  /// "from last month"; both describe the one move since last month's snapshot.
  Widget _monthTrendLine(Map<String, dynamic> trend) {
    final delta = trend['delta'] as double;
    final pct = trend['pct'] as double?;
    final flat = delta.abs() < 0.005;
    final up = delta > 0;
    final color = up ? Barako.primary : Barako.muted;
    final iconName = flat ? 'forward' : (up ? 'growth' : 'decline');
    final pctText = pct == null ? '' : ' (${pct.abs().toStringAsFixed(1)}%)';
    // Masked, the line drops the peso amount and shows the percentage only, so
    // the delta never leaks the absolute figure the eye is hiding. With no
    // meaningful percentage it falls back to the direction alone.
    final String label;
    if (flat) {
      label = 'No change this month';
    } else if (_hideBalances) {
      label = pct == null
          ? '${up ? 'Up' : 'Down'} this month'
          : '${up ? 'Up' : 'Down'} ${pct.abs().toStringAsFixed(1)}% this month';
    } else {
      label =
          '${up ? 'Up' : 'Down'} ${formatMoney(delta.abs())}$pctText this month';
    }
    return Row(
      children: [
        Icon(salapifyIcon(iconName), size: IconSizes.dense, color: color),
        const SizedBox(width: Gap.xs),
        Flexible(
          child: Text(
            label,
            style: AppText.small.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              height: 1.3,
              // Tabular figures so "PHP7,545 (3.4%)" holds its column when the
              // month's numbers change, the same rule as every peso figure.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  /// The owned-versus-owed split of the whole position, as one glanceable bar.
  ///
  /// Two segments in the same two colours the mini-stats already use (assets in
  /// the brand accent, owed in the warning ink), so the bar and the figures
  /// above it read as one thought. The percentages are spelled out in words
  /// beside the bar, so the meaning never rides on colour alone: a colourblind
  /// reader gets "68% owned" and "32% owed", not just two shapes.
  Widget _ownershipBar(int ownedPct) {
    final owedPct = 100 - ownedPct;
    final segments = <Widget>[
      if (ownedPct > 0)
        Expanded(
          flex: ownedPct,
          child: ColoredBox(color: Barako.primary),
        ),
      if (ownedPct > 0 && owedPct > 0) const SizedBox(width: 3),
      if (owedPct > 0)
        Expanded(
          flex: owedPct,
          child: ColoredBox(color: Barako.warning),
        ),
    ];
    return Semantics(
      label: '$ownedPct percent assets, $owedPct percent liabilities.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: SizedBox(
                height: 10,
                // stretch: a childless ColoredBox has no intrinsic height, so
                // without this the segments collapse to a zero-height (and so
                // invisible) bar. Caught by looking at the render, not a test.
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: segments,
                ),
              ),
            ),
            const SizedBox(height: Gap.sm),
            // One caption in words, the meaning never on colour alone: assets in
            // the brand accent, liabilities in the warning ink, joined by a
            // middot. Scale down rather than overflow at a large system font; the
            // peso figures above stay full size, this is the reinforcing read.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Text(
                    '$ownedPct% assets',
                    style: AppText.caption.tint(Barako.primaryText).w6,
                  ),
                  Text('  ·  ', style: AppText.caption.tint(Barako.muted).w6),
                  Text(
                    '$owedPct% liabilities',
                    style: AppText.caption.tint(Barako.warning).w6,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBreakdown(BuildContext context, AssetsView view) {
    Haptics.select();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssetsLiabilitiesScreen(store: store, initial: view),
      ),
    );
  }

  /// The single biggest balance the person still owes, as (name, amount), or
  /// null when they owe nothing. Read from the same debt rows the screen already
  /// groups: any row that lives in the debts store with a positive remaining
  /// balance qualifies, so it covers credit cards, loans and installments
  /// without depending on a category key. Presentation only, never written.
  (String, double)? _largestLiability(
    Map<String, List<(Map<String, dynamic>, AccountStore)>> groups,
  ) {
    (String, double)? best;
    for (final entries in groups.values) {
      for (final (row, which) in entries) {
        if (which != AccountStore.debts) continue;
        final amt = amountOf(row['remaining']);
        if (amt <= 0) continue;
        if (best == null || amt > best.$2) {
          // Guard empty and whitespace names, not just null, so a malformed or
          // imported backup row can never make Pan say "clear is , PHP12,500".
          // This matches the ?? 'Debt' / ?? 'Account' fallbacks the list rows use.
          final rawName = row['name']?.toString().trim() ?? '';
          best = (rawName.isEmpty ? 'a balance' : rawName, amt);
        }
      }
    }
    return best;
  }

  /// Pan's read on the month: a data-driven line, not one fixed sentence, so the
  /// mascot does a job instead of decorating. It is built from the SAME
  /// golden-locked trend the hero shows (never a second opinion) plus, on a flat
  /// month, the single biggest balance left to clear, named from the same
  /// liabilities the screen already lists. Pan is kind: a rise is celebrated, a
  /// dip is stated plainly and pointed at the detail, never scolded; a steady
  /// month turns into a concrete, gentle nudge. All read-only.
  Widget _panInsight(
    Map<String, dynamic> trend,
    (String, double)? largestOwed,
  ) {
    final delta = trend['delta'] as double;
    final flat = delta.abs() < 0.005;
    final up = delta > 0;
    // Masked, Pan keeps the sentiment but drops the peso figures, so the eye
    // that hides every other number on the screen hides these too (the card,
    // and the screen-reader label built from the same line).
    final hide = _hideBalances;
    final amount = formatMoney(delta.abs());
    final String line;
    if (up) {
      line = hide
          ? 'Great month. Your net worth grew this month.'
          : 'Great month. Your net worth grew by $amount.';
    } else if (!flat) {
      line = hide
          ? 'Your net worth dipped this month. Tap to see where.'
          : 'Your net worth dipped by $amount this month. Tap to see where.';
    } else if (largestOwed != null) {
      line = hide
          ? 'Steady month. Your biggest balance to clear is ${largestOwed.$1}.'
          : 'Steady month. Your biggest balance to clear is ${largestOwed.$1}, '
                '${formatMoney(largestOwed.$2)}.';
    } else {
      line = 'Your net worth held steady this month. Steady is progress too.';
    }
    return Semantics(
      button: true,
      label: 'Pan insight. $line Opens the trend over time.',
      child: ExcludeSemantics(
        child: Material(
          color: Barako.card,
          borderRadius: BorderRadius.circular(Radii.hero),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.hero),
            onTap: () {
              Haptics.select();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NetWorthTrendScreen(store: store),
                ),
              );
            },
            child: Container(
              padding: Insets.hero,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.hero),
                border: Border.all(color: Barako.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("PAN'S INSIGHT", style: Barako.kickerStyle),
                        const SizedBox(height: Gap.sm),
                        Text(
                          line,
                          style: AppText.body.w6.copyWith(height: 1.4),
                        ),
                        const SizedBox(height: Gap.sm),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'See more insights',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.small.w7.tint(
                                  Barako.primaryText,
                                ),
                              ),
                            ),
                            const SizedBox(width: Gap.xs),
                            Icon(
                              salapifyIcon('forward'),
                              size: IconSizes.dense,
                              color: Barako.primaryText,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  ExcludeSemantics(
                    child: PanMascot.emotion(
                      emotion: up || flat
                          ? PanEmotion.content
                          : PanEmotion.worried,
                      size: 56,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "Money you can reach now", the mockup's Available card. One honest summary
  /// of everything liquid. The title is deliberately NOT "available to spend":
  /// per the financial-coach ruling that overpromises, since an emergency fund
  /// in a savings account is reachable but not free to spend. The sentence under
  /// it names exactly what is left out so the number cannot mislead, and puts
  /// bills and savings first without a nag or a warning colour.
  Widget _availableCard(double total, int count, bool approx) {
    final amountText = _hideBalances
        ? _money(total)
        : '${approx ? '~' : ''}${formatMoneyText(total)}';
    final accountsWord = count == 1 ? 'account' : 'accounts';
    return Semantics(
      label:
          'Money you can reach now, ${_hideBalances ? 'hidden' : amountText} across $count liquid $accountsWord. '
          'Everyday money you can use or transfer today. It leaves out time '
          'deposits, investments, and credit. Cover your bills and savings first.',
      child: ExcludeSemantics(
        child: Container(
          padding: Insets.hero,
          decoration: BoxDecoration(
            color: Barako.card,
            borderRadius: BorderRadius.circular(Radii.hero),
            border: Border.all(color: Barako.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MONEY YOU CAN REACH NOW',
                          style: Barako.kickerStyle,
                        ),
                        const SizedBox(height: Gap.xs),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            amountText,
                            maxLines: 1,
                            style: AppText.amountLg.w8.tint(Barako.primaryText),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Across $count liquid $accountsWord',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  // The wallet mark where the mockup drew a wallet-and-bills
                  // illustration. A photo would need a new bundled asset and an
                  // APK; the brand glyph on a tinted disc is the OTA-safe mark.
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Barako.primary.withValues(alpha: BarakoAlpha.tint),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      salapifyIcon('wallet'),
                      size: IconSizes.inline,
                      color: Barako.primaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              Text(
                'Everyday money you can use or transfer today. It leaves out '
                'time deposits, investments, and credit. Cover your bills and '
                'savings first.',
                style: AppText.caption.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The overview's category groups, in the mockup's order, already filtered by
  /// the active class filter. The single cash_equivalents category is split at
  /// the SUBTYPE level (e-wallets out of the rest) and installments fold into
  /// Loans, so a person sees the five familiar buckets the mockup draws rather
  /// than the six raw taxonomy ids. Every row still resolves through the same
  /// taxonomy, so nothing is reclassified; this only regroups for display.
  ///
  /// [filter] decides which rows and which groups survive:
  ///  - 'hidden' keeps only the rows left OUT of net worth (archived or
  ///    excluded), across every class, so a hidden account always has a home.
  ///  - 'all' / 'assets' / 'liabilities' keep only the COUNTED rows, then drop
  ///    the groups whose class does not match ('all' keeps both classes).
  /// A group with no surviving rows is dropped, so an empty category never
  /// draws a header the person cannot open onto anything.
  List<_GroupSpec> _overviewGroups(
    Map<String, List<(Map<String, dynamic>, AccountStore)>> groups,
    String filter,
  ) {
    bool wallet((Map<String, dynamic>, AccountStore) e) =>
        resolveKind(e.$1, e.$2).subtype.id == 'ewallet';
    // The row test for the current filter: hidden shows only the uncounted
    // rows; every other filter shows only the counted ones.
    bool keep((Map<String, dynamic>, AccountStore) e) =>
        filter == 'hidden' ? !countsInNetWorth(e.$1) : countsInNetWorth(e.$1);

    List<(Map<String, dynamic>, AccountStore)> pick(
      Iterable<(Map<String, dynamic>, AccountStore)> src,
    ) => [
      for (final e in src)
        if (keep(e)) e,
    ];

    final cash = groups['cash_equivalents']!;
    final bank = pick(cash.where((e) => !wallet(e)));
    final wallets = pick(cash.where(wallet));
    final investments = pick(groups['investments']!);
    final property = pick(groups['property']!);
    final credit = pick(groups['credit']!);
    final loans = pick([...groups['loans']!, ...groups['installments']!]);

    final specs = <_GroupSpec>[
      _GroupSpec(
        'cash_bank',
        'Cash & Bank',
        'bank',
        AccountClass.asset,
        bank,
        'Add account in Cash & Bank',
      ),
      _GroupSpec(
        'ewallets',
        'E-Wallets',
        'wallet',
        AccountClass.asset,
        wallets,
        'Add account in E-Wallets',
      ),
      _GroupSpec(
        'investments',
        'Investments',
        'growth',
        AccountClass.asset,
        investments,
        'Add investment account',
      ),
      _GroupSpec(
        'property',
        'Property',
        'house',
        AccountClass.asset,
        property,
        'Add property',
      ),
      _GroupSpec(
        'credit',
        'Credit Cards',
        'card',
        AccountClass.liability,
        credit,
        'Add credit card',
      ),
      _GroupSpec(
        'loans',
        'Loans',
        'document',
        AccountClass.liability,
        loans,
        'Add loan account',
      ),
    ];

    return [
      for (final s in specs)
        if (s.rows.isNotEmpty &&
            (filter == 'all' ||
                filter == 'hidden' ||
                (filter == 'assets' && s.cls == AccountClass.asset) ||
                (filter == 'liabilities' && s.cls == AccountClass.liability)))
          s,
    ];
  }

  /// The Accounts Overview: a class-filter row, then the expandable category
  /// groups. It replaces the old one-tab chip filter with independent
  /// accordions the mockup draws, and gives the class filters (All, Assets,
  /// Liabilities, Hidden) their own axis above the grouping. Every peso still
  /// folds the SAME _countedAmount the hero uses, so a group total can never
  /// disagree with the totals.
  Widget _overviewSection(
    BuildContext context,
    Map<String, List<(Map<String, dynamic>, AccountStore)>> groups,
    double Function((Map<String, dynamic>, AccountStore)) amountOfRow,
  ) {
    final visible = _overviewGroups(groups, _filter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _classFilterRow(groups),
        const SizedBox(height: Gap.lg),
        Text('ACCOUNTS OVERVIEW', style: Barako.kickerStyle),
        const SizedBox(height: Gap.xs),
        Text(
          _filter == 'hidden'
              ? 'Accounts you hid from net worth'
              : 'Tap a category to open its accounts',
          style: AppText.caption,
        ),
        const SizedBox(height: Gap.md),
        if (visible.isEmpty)
          _emptyFilter(hasHidden: _overviewGroups(groups, 'hidden').isNotEmpty)
        else
          for (final spec in visible) ...[
            _categoryGroup(context, spec, amountOfRow),
            const SizedBox(height: Gap.md),
          ],
      ],
    );
  }

  /// The class filter chips (All, Assets, Liabilities, Hidden), each with the
  /// count of accounts it holds. All / Assets / Liabilities count only the rows
  /// that COUNT in net worth (so All == Assets + Liabilities); Hidden counts the
  /// rows left out of net worth. Selecting one re-filters the accordion below.
  Widget _classFilterRow(
    Map<String, List<(Map<String, dynamic>, AccountStore)>> groups,
  ) {
    int rowsIn(String filter, {AccountClass? cls}) {
      var n = 0;
      for (final spec in _overviewGroups(groups, filter)) {
        if (cls == null || spec.cls == cls) n += spec.rows.length;
      }
      return n;
    }

    final allN = rowsIn('all');
    final assetN = rowsIn('all', cls: AccountClass.asset);
    final liabN = rowsIn('all', cls: AccountClass.liability);
    final hiddenN = rowsIn('hidden');

    final chips = <(String, String, int)>[
      ('all', 'All', allN),
      ('assets', 'Assets', assetN),
      ('liabilities', 'Liabilities', liabN),
      // Hidden only appears once there is something hidden, so the common case
      // is the three the person needs, not a chip that always reads zero.
      if (hiddenN > 0) ('hidden', 'Hidden', hiddenN),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (key, label, count) in chips) ...[
            _CategoryChip(
              // Keyed so a test can target the filter chip unambiguously: its
              // label ("Assets" / "Liabilities") also appears in the hero above.
              key: ValueKey('accounts-filter-$key'),
              label: label,
              count: count,
              selected: _filter == key,
              onTap: () {
                Haptics.select();
                setState(() => _filter = key);
              },
            ),
            const SizedBox(width: Gap.sm),
          ],
        ],
      ),
    );
  }

  /// One expandable category group: a tappable header (icon disc, name, account
  /// count, class-coloured total, a chevron that rotates on open) and, when
  /// expanded, the accounts inside with a per-category Add button. Credit cards
  /// render as real cards; every other account is a compact row. The header
  /// total folds the SAME _countedAmount the hero uses.
  Widget _categoryGroup(
    BuildContext context,
    _GroupSpec spec,
    double Function((Map<String, dynamic>, AccountStore)) amountOfRow,
  ) {
    final open = _expanded.contains(spec.id);
    final owed = spec.cls == AccountClass.liability;
    final total = spec.rows.fold(
      0.0,
      (t, e) => t + _countedAmount(e, amountOfRow(e)),
    );
    final totalColor = owed ? Barako.warning : Barako.text;
    final discColor = owed ? Barako.warning : Barako.primary;
    final count = spec.rows.length;
    final countWord = count == 1 ? 'account' : 'accounts';
    final totalText = (owed && !_hideBalances && total.abs() >= 0.005)
        ? '-${_money(total)}'
        : _money(total);

    final header = Semantics(
      button: true,
      expanded: open,
      label:
          '${spec.label}, $count $countWord, ${owed ? 'owed ' : ''}$totalText',
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: () {
            Haptics.select();
            setState(() {
              if (open) {
                _expanded.remove(spec.id);
              } else {
                _expanded.add(spec.id);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: discColor.withValues(alpha: BarakoAlpha.tint),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    salapifyIcon(spec.glyph),
                    size: IconSizes.inline,
                    color: discColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.w7,
                      ),
                      const SizedBox(height: 2),
                      Text('$count $countWord', style: AppText.caption),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      totalText,
                      maxLines: 1,
                      style: AppText.amountRow.w7.tint(totalColor),
                    ),
                  ),
                ),
                const SizedBox(width: Gap.xs),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    salapifyIcon('expand'),
                    size: IconSizes.inline,
                    color: Barako.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // The expanded body: the accounts, a per-category Add button, and (for the
    // liability groups) the one manage-debts note. Cross-faded so the collapse
    // is a smooth height-and-opacity move, not a jump; the collapsed side is an
    // empty full-width box so the card keeps its width.
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 1, color: Barako.border),
        for (final e in spec.rows)
          if (spec.id == 'credit' && !_hideBalances)
            _creditCardTile(context, e.$1)
          else
            _taxonomyRow(context, e),
        if (owed) ...[const Divider(height: 1), _manageDebtsNote()],
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          child: _addInGroupButton(spec.addLabel),
        ),
      ],
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          // AnimatedSize animates the height as the body appears or leaves; the
          // collapsed side is an empty full-width box, so a collapsed group does
          // NOT build its rows (they are off the tree, out of finders, and cheap
          // to skip), while an expanded group builds them eagerly so a search
          // reveal can scroll to a row inside it.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? body
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  /// A credit card row drawn as a real card: the mockup's richer treatment for
  /// the one account the data can truthfully call a card (a debt whose type is a
  /// credit card, carrying a limit and a network). Tapping opens its full
  /// detail. Only reached in the non-masked view; the masked view falls back to
  /// a compact row so no owed figure or limit leaks.
  Widget _creditCardTile(BuildContext context, Map<String, dynamic> row) {
    final name = row['name']?.toString() ?? 'Credit card';
    final instId = row['institutionId']?.toString();
    final due = _dueMeta(row);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
      child: PressableScale(
        child: Semantics(
          button: true,
          label: due == null
              ? '$name credit card. Opens card details.'
              : '$name credit card. $due. Opens card details.',
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openCard(context, row, AccountStore.debts),
              // A long press opens the account's own action sheet (QR, ledger,
              // log, statement, transfer, skin, edit, hide), all wired to flows
              // the app already has. A plain tap still opens the full details,
              // so nothing existing changes.
              onLongPress: () =>
                  _openAccountActions(context, row, AccountStore.debts),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The card follows its chosen skin: a skin is just a different
                  // seed colour handed to the same AA safe BankCard face, and
                  // CardSkinStore is a listenable so a pick repaints instantly.
                  ListenableBuilder(
                    listenable: CardSkinStore.instance,
                    builder: (context, _) => BankCard(
                      bankName: name,
                      accountType: 'Credit',
                      balance: amountOf(row['remaining']),
                      brandColor:
                          CardSkinStore.instance.seedFor('${row['id']}') ??
                          institutionBrandColor(instId),
                      last4: _last4Of(row),
                      monogram: institutionById(instId)?.initials,
                      logoAsset: institutionLogoAsset(instId),
                      creditLimit: amountOf(row['creditLimit']),
                      networkMark: cardNetworkWordmark(
                        row['cardNetwork']?.toString(),
                      ),
                      variant: BankCardVariant.credit,
                    ),
                  ),
                  if (due != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: Row(
                        children: [
                          Icon(
                            salapifyIcon('calendar'),
                            size: IconSizes.dense,
                            color: Barako.muted,
                          ),
                          const SizedBox(width: Gap.xs),
                          Expanded(
                            child: Text(
                              due,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The floating 3D version of a credit card, re-seeded by an optional skin.
  /// Used as the preview at the top of the action sheet and inside the skin
  /// studio. Tilt is opt in because the action sheet scrolls; the studio turns
  /// it on. Reads the same fields the flat card does, so the two never disagree.
  Widget _floatingCardFor(
    Map<String, dynamic> row, {
    Color? skinSeed,
    bool enableTilt = true,
  }) {
    final instId = row['institutionId']?.toString();
    return FloatingPanCard(
      bankName: row['name']?.toString() ?? 'Credit card',
      accountType: 'Credit',
      balance: amountOf(row['remaining']),
      brandColor: institutionBrandColor(instId),
      skinSeed: skinSeed,
      last4: _last4Of(row),
      monogram: institutionById(instId)?.initials,
      logoAsset: institutionLogoAsset(instId),
      creditLimit: amountOf(row['creditLimit']),
      networkMark: cardNetworkWordmark(row['cardNetwork']?.toString()),
      variant: BankCardVariant.credit,
      enableTilt: enableTilt,
    );
  }

  /// Open the per account action sheet for one card, wiring every action to a
  /// flow that already exists. No money behaviour is added here.
  void _openAccountActions(
    BuildContext context,
    Map<String, dynamic> row,
    AccountStore which,
  ) {
    final id = row['id']?.toString() ?? '';
    final name = row['name']?.toString() ?? 'Account';
    final qrRef = row['qrRef']?.toString();
    final hasQr = qrRef != null && qrRef.isNotEmpty;
    final isArchived = row['isArchived'] == true;
    final accountCount = (store.data['accounts'] as List?)?.length ?? 0;

    showAccountActionSheet(
      context,
      title: name,
      // The preview wears the card's chosen skin, matching the list card the
      // user just long-pressed rather than reverting to the brand colour.
      cardPreview: _floatingCardFor(
        row,
        enableTilt: false,
        skinSeed: CardSkinStore.instance.seedFor(id),
      ),
      canTransfer: accountCount >= 2,
      onViewLedger: () => Navigator.of(context).push(
        MaterialPageRoute(
          // Seed the ledger's text filter with the account name so it opens
          // showing that account's activity, the same seeding a search reveal
          // uses. No new filter, so no new behaviour to test.
          builder: (_) =>
              HistoryScreen(store: store, initialQuery: name, pushed: true),
        ),
      ),
      onLogExpense: () => showLogSheet(context, store),
      onTransfer: () => _openTransfer(context),
      onEditDetails: () => showDebtFormSheet(context, store, debt: row),
      onExportStatement: () =>
          shareAccountStatementPdf(store.data, row, DateTime.now()),
      onCustomizeSkin: () => showCardSkinStudio(
        context,
        accountId: id,
        previewBuilder: (seed) => _floatingCardFor(row, skinSeed: seed),
      ),
      onArchiveToggle: () {
        if (id.isEmpty) return;
        store.patchDebtMeta(id, {'isArchived': !isArchived});
      },
      isArchived: isArchived,
      // A saved receiving QR shows through the existing QR sheet. With none
      // saved yet, this opens the card's DETAIL screen, whose "Receiving QR"
      // section has an "Add a QR image" button, rather than the edit form (which
      // has no QR field) and never a fabricated code that could not be paid.
      onShowQr: hasQr
          ? () async {
              final vault = await QrVault.inAppDocuments();
              if (!context.mounted) return;
              await showAccountQrSheet(
                context,
                vault: vault,
                qrRef: qrRef,
                label: row['qrLabel']?.toString(),
              );
            }
          : () => _openCard(context, row, which),
    );
  }

  /// A calm state when a class filter matches nothing (for example the person
  /// taps Liabilities but owes nothing). Never the whole-screen empty state,
  /// which is the fresh-install case.
  Widget _emptyFilter({bool hasHidden = false}) {
    final (title, body) = switch (_filter) {
      'liabilities' => ('Nothing owed', 'You have no debts recorded. Nice.'),
      'assets' => ('No assets here', 'Add an account to see it in this view.'),
      'hidden' => (
        'Nothing hidden',
        'Accounts you hide from net worth show up here.',
      ),
      // When the "all" view is empty only because every account is hidden, point
      // to the Hidden chip rather than claiming there is nothing here at all.
      _ when hasHidden => (
        'All your accounts are hidden',
        'Tap the Hidden filter above to see them.',
      ),
      _ => ('Nothing here yet', 'Add an account to get started.'),
    };
    return Container(
      width: double.infinity,
      padding: Insets.hero,
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.hero),
        border: Border.all(color: Barako.border),
      ),
      child: Column(
        children: [
          Text(title, textAlign: TextAlign.center, style: AppText.body.w7),
          const SizedBox(height: Gap.xs),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  /// The per-category Add button inside an expanded group. It opens the one Add
  /// flow (which asks what is being added), so no money path is duplicated; the
  /// label just names where the person is adding.
  Widget _addInGroupButton(String label) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _add(context),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
        // A plain OutlinedButton with a max-width Row, not OutlinedButton.icon,
        // so the label sits in a Flexible and ellipsizes instead of overflowing
        // the button at a large system font on a narrow phone.
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(salapifyIcon('add'), size: IconSizes.inline),
            const SizedBox(width: Gap.sm),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  /// "View all", top-right of the section: stop filtering, open the whole
  /// assets-and-liabilities picture, the same destination the hero button uses.
  /// The four things a person opens Accounts to do, as one compact row under
  /// the net worth number. Icons carry the meaning, one short word confirms it.
  /// Every action routes to a flow that already exists: nothing here fakes a
  /// capability the app does not have.
  Widget _quickActions(BuildContext context, {required bool canTransfer}) {
    final items = <_QuickAction>[
      _QuickAction(
        'swap',
        'Transfer',
        'Move money between accounts',
        () => _onTransfer(context, canTransfer),
      ),
      _QuickAction(
        'add',
        'Add Account',
        'Add an account',
        () => _add(context),
        filled: true,
      ),
      _QuickAction(
        'receipt',
        'Pay',
        'Record a payment',
        () => _onRecordPayment(context),
      ),
      _QuickAction(
        'more',
        'More',
        'More account actions',
        () => _openMoreActions(context, canTransfer),
      ),
    ];
    // IntrinsicHeight so all four tiles match the tallest, which keeps the row
    // even when one label wraps at a large system font.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: Gap.md),
            Expanded(child: _quickActionButton(items[i])),
          ],
        ],
      ),
    );
  }

  Widget _quickActionButton(_QuickAction a) => PressableScale(
    child: Semantics(
      button: true,
      label: a.semantic,
      child: ExcludeSemantics(
        child: Material(
          color: Barako.card,
          borderRadius: BorderRadius.circular(Radii.field),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.field),
            onTap: a.onTap,
            child: Container(
              // Compacter than the old 78px tile: vertical space is expensive on
              // a finance screen, so the disc and label sit tighter while the
              // 44px minimum tap target is still cleared by the whole tile.
              constraints: const BoxConstraints(minHeight: 62),
              padding: const EdgeInsets.symmetric(
                vertical: Gap.sm,
                horizontal: Gap.xs,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.field),
                border: Border.all(color: Barako.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // The primary action fills its disc with the accent and a
                      // white glyph; the rest wear the quiet tinted wash. On is
                      // Colors.white deliberately, not a palette token, so the
                      // glyph clears the filled accent in every mood.
                      color: a.filled
                          ? Barako.primary
                          : Barako.primary.withValues(alpha: BarakoAlpha.tint),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      salapifyIcon(a.icon),
                      size: IconSizes.inline,
                      color: a.filled ? Colors.white : Barako.primaryText,
                    ),
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    a.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.small.w6.tint(Barako.text),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// Transfer, or a calm reason it cannot happen yet. Moving money needs two
  /// accounts to move between, so with one (or none) this points the way
  /// forward instead of opening a sheet with nothing to pick.
  void _onTransfer(BuildContext context, bool canTransfer) {
    // Writes off (data could not be read): do not open a sheet that could not
    // save the move. The old design hid the button entirely here; the quick
    // action stays visible but says why instead of leading to a dead end.
    if (!store.canWrite) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Saving is off because your data could not be read. Import a '
              'backup to recover first.',
            ),
          ),
        );
      return;
    }
    if (!canTransfer) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Add a second account, then you can move money between them.',
            ),
          ),
        );
      return;
    }
    _openTransfer(context);
  }

  /// Payments live on the Utang "I owe" tab, which owns interest, due dates and
  /// payment history. When this screen was opened with that jump wired, go
  /// there; otherwise say where payments are recorded rather than opening a
  /// form here that cannot do the job.
  void _onRecordPayment(BuildContext context) {
    final open = widget.onOpenPayables;
    if (open != null) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      open();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Record credit card and loan payments under the "I owe" tab.',
          ),
        ),
      );
  }

  /// The overflow menu: the same real actions, spelled out with a line of
  /// context each. It stays honest by listing only flows that exist; an
  /// "import statement" or "categories" row waits until there is one to open.
  void _openMoreActions(BuildContext context, bool canTransfer) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Barako.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.gutter,
                Gap.gutter,
                Gap.gutter,
                Gap.sm,
              ),
              child: Text('Account actions', style: AppText.subtitle),
            ),
            _moreTile(
              ctx,
              'add',
              'Add account',
              'Link a bank, e-wallet, or cash',
              () => _add(context),
            ),
            _moreTile(
              ctx,
              'swap',
              'Move money',
              'Transfer between accounts',
              () => _onTransfer(context, canTransfer),
            ),
            _moreTile(
              ctx,
              'receipt',
              'Record payment',
              'Pay a credit card or loan',
              () => _onRecordPayment(context),
            ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
  }

  Widget _moreTile(
    BuildContext sheetContext,
    String icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => ListTile(
    leading: SalapifyGlyph(icon, size: IconSizes.inline),
    title: Text(title, style: AppText.body.w6),
    subtitle: Text(subtitle, style: AppText.caption),
    onTap: () {
      Navigator.of(sheetContext).pop();
      onTap();
    },
  );

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
          meta: _dueMeta(row),
          amount: amountOf(row['remaining']),
          // Neutral ink on purpose: a borrower current on every payment is
          // not in an emergency, and a wall of red is visually punitive.
          // The class kicker above carries the owe meaning; red stays
          // reserved for the Total owed summary and true urgency.
        );
    }
  }

  /// "Due Jun 15 · in 3 days", bank adjusted for weekends and Philippine
  /// holidays, the SAME golden-locked `bankDueDate` the `bills` reminder
  /// itself schedules from (money/commitments.dart), so the promise on this
  /// row and the reminder that actually fires can never disagree. Gated
  /// identically to the reminder engine (remaining > 0, a resolvable
  /// schedule), so a row never shows a due date the app could not also remind
  /// about. Null for anything paid off or with no due day / statement day set.
  ///
  /// A moved date says only "(adjusted)", never the specific reason: a
  /// Philippine holiday name ("Feast of the Immaculate Conception of Mary")
  /// can run far longer than a Saturday, and this row is one MAXLINES-1 line
  /// wide. The full "why" already has room in the wizard's schedule-step
  /// preview; this compact row would rather say less than truncate mid-word.
  String? _dueMeta(Map<String, dynamic> row) {
    if (!(amountOf(row['remaining']) > 0)) return null;
    final due = bankDueDate(row, DateTime.now());
    if (due == null) return null;
    final days = daysUntil(due.date, DateTime.now());
    final when = '${shortDueDate(due.date)} · ${daysUntilWords(days)}';
    return due.moved ? 'Due $when (adjusted)' : 'Due $when';
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
    // The masked account number is the mockup's sub line (BDO Savings ·
    // ••••1234), the fact that answers "which of my accounts is this". It wins
    // over the subtype-and-institution line when a last4 is stored, since the
    // institution is already drawn as the avatar to the left. A savings TARGET
    // still wins over both: progress toward a goal is the more useful fact and a
    // third clause would not fit on one line at any font size.
    final last4 = _last4Of(a);
    double? progress;
    if (target > 0) {
      final pct = ((balance / target) * 100).clamp(0, 999).round();
      // Masked, the goal amount is dropped so the target (and the balance a
      // shoulder-surfer could derive from the percent and it) stays hidden; the
      // progress bar still shows the ratio, which is not a peso figure.
      sub = _hideBalances
          ? 'Savings goal'
          : '$pct% of ${formatMoneyText(target)}';
      progress = (balance / target).clamp(0.0, 1.0);
    } else if (last4 != null) {
      sub = '•••• $last4';
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

    /// A third line under [sub], for the bank-adjusted "Due Jun 15 · in 3
    /// days" fact on a debt row. Kept separate from [sub] rather than joined
    /// with a middot, because [sub] is subtype-and-institution (identity) and
    /// this is a live, changing fact; conflating them made the subtype the
    /// part that got truncated on a long row.
    String? meta,
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
                if (meta != null && meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.micro.w6.tint(Barako.primaryText),
                  ),
                ],
                if (progress != null) ...[
                  const SizedBox(height: 6),
                  SalapifyProgressBar(
                    value: progress,
                    size: ProgressBarSize.micro,
                    semanticsLabel: 'Savings progress',
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
                  // Masked to dots when the privacy toggle is on, so a shoulder
                  // glance never reads a balance. Otherwise the exact figure,
                  // byte for byte what it was before the toggle existed.
                  _hideBalances
                      ? '₱ ••••'
                      : (foreignCode == null
                            ? formatMoneyText(amount)
                            : formatConverted(amount, foreignCode)),
                  style: AppText.amountRow.tint(amountColor ?? Barako.text),
                ),
                if (foreignCode != null && !_hideBalances)
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

  /// The last four digits, only when a stored value is exactly four digits.
  /// Anything else (absent, or a longer string a backup should never carry)
  /// shows as masked dots with no digits.
  String? _last4Of(Map<String, dynamic> row) {
    final v = row['last4'];
    return (v is String && RegExp(r'^\d{4}$').hasMatch(v)) ? v : null;
  }

  /// Tapping a card opens its full detail screen, the wallet page for that one
  /// account: the card, its numbers, the secure information, a saved receiving
  /// QR, and recent activity, with Edit, Archive and Delete inside. A credit
  /// card's CARD reaches the right screen even though the debt LIST ROW stays
  /// non-tappable.
  void _openCard(
    BuildContext context,
    Map<String, dynamic> row,
    AccountStore which,
  ) {
    final id = row['id'];
    if (id is! String || id.isEmpty) {
      // A hand-edited backup row with no id cannot be addressed by the detail
      // screen, so fall back to the old editor rather than opening a blank page.
      if (which == AccountStore.debts) {
        showDebtFormSheet(context, store, debt: row);
      } else {
        _openForm(context, isAccount: true, item: row);
      }
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AccountDetailScreen(store: store, id: id, accountStore: which),
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

/// One entry in the quick-actions row: the glyph, the short visible word, the
/// full sentence a screen reader announces, and the tap. A tiny view model so
/// the row and its buttons stay declarative.
/// One "Accounts by category" tab: its stable key, chip label, net-worth class
/// (for the subtotal colour), the rows it holds, and the copy for its Add
/// button and empty state.
/// One overview category group: its stable id, mockup label, Salapify glyph
/// name, net-worth class (for the total colour), the rows it holds after the
/// active filter, and the copy for its per-category Add button.
class _GroupSpec {
  final String id;
  final String label;
  final String glyph;
  final AccountClass cls;
  final List<(Map<String, dynamic>, AccountStore)> rows;
  final String addLabel;
  const _GroupSpec(
    this.id,
    this.label,
    this.glyph,
    this.cls,
    this.rows,
    this.addLabel,
  );
}

/// A class-filter chip, optionally carrying a count badge. Not const: it reads
/// Barako colours, which change with the mood. Selected wears the filled accent
/// with white ink (the mockup's brown chip); unselected is an outlined card
/// chip. 44dp min height for the tap target, and `selected:` in semantics so a
/// screen reader announces the state, with the count spoken in the label.
class _CategoryChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  // ignore: prefer_const_constructors_in_immutables
  _CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final ink = selected ? Colors.white : Barako.textSecondary;
    return PressableScale(
      child: Semantics(
        button: true,
        selected: selected,
        label: count == null ? label : '$label, $count',
        child: ExcludeSemantics(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.control),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.control),
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: Gap.sm,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? Barako.primary : Barako.card,
                  borderRadius: BorderRadius.circular(Radii.control),
                  border: selected ? null : Border.all(color: Barako.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: selected
                          ? AppText.small.w7.tint(ink)
                          : AppText.small.w6.tint(ink),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: Gap.xs),
                      Text(
                        '$count',
                        style: AppText.small.w7.tint(
                          selected ? Colors.white : Barako.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  final String icon;
  final String label;
  final String semantic;
  final VoidCallback onTap;

  /// The primary action wears a filled accent disc with a white glyph, the way
  /// the mockup makes Add Account stand out from the outlined rest.
  final bool filled;
  const _QuickAction(
    this.icon,
    this.label,
    this.semantic,
    this.onTap, {
    this.filled = false,
  });
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
    // The mockup's success confirmation, replacing the old snackbar receipt: it
    // shows the move, both new balances, and a checkmark. Values are captured
    // BEFORE the pop, because the sheet's own context and state are gone the
    // moment it closes; the balances are already the post-transfer figures. No
    // Undo, the same reason as before (deleting a transfer row does not reverse
    // the balances, see transfers.dart), so the honest thing is to confirm.
    final nav = Navigator.of(context);
    final moved = amountOf(_amount.text.replaceAll(RegExp(r'[, ]'), ''));
    final fromName = _nameOf(_fromId);
    final toName = _nameOf(_toId);
    final fromBalance = _balanceOf(_fromId);
    final toBalance = _balanceOf(_toId);
    final fromColor = institutionBrandColor(
      _rowOf(_fromId)['institutionId']?.toString(),
    );
    final toColor = institutionBrandColor(
      _rowOf(_toId)['institutionId']?.toString(),
    );
    // Felt, not just shown, the word every committed money write speaks. A
    // transfer is a ROUTINE write, not a milestone, so it gets moneyWritten,
    // not milestone, and the success screen stays a calm confirmation with no
    // reserved celebration confetti. The refusal and error paths stay silent.
    Haptics.moneyWritten();
    nav.pop();
    await showDialog<void>(
      context: nav.context,
      barrierColor: Barako.overlay,
      builder: (_) => _TransferSuccessDialog(
        moved: moved,
        fromName: fromName,
        toName: toName,
        fromBalance: fromBalance,
        toBalance: toBalance,
        fromColor: fromColor,
        toColor: toColor,
      ),
    );
  }

  double _balanceOf(String id) {
    for (final a in _accounts) {
      if ('${a['id']}' == id) return amountOf(a['balance']);
    }
    return 0;
  }

  Map<String, dynamic> _rowOf(String id) {
    for (final a in _accounts) {
      if ('${a['id']}' == id) return a;
    }
    return const {};
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
                          borderRadius: BorderRadius.circular(Radii.field),
                          borderSide: BorderSide(color: Barako.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Radii.field),
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

/// The transfer success confirmation, the mockup's "Transfer successful" screen.
///
/// A calm confirmation, not a celebration: a transfer is a routine money write,
/// so this uses a checkmark that scales in (gated through Motion.of for
/// reduce-motion) rather than the reserved milestone confetti. It shows the two
/// accounts with their NEW balances and the amount moved, so the person sees
/// exactly what happened before dismissing.
class _TransferSuccessDialog extends StatelessWidget {
  final double moved;
  final String fromName;
  final String toName;
  final double fromBalance;
  final double toBalance;
  final Color? fromColor;
  final Color? toColor;
  // ignore: prefer_const_constructors_in_immutables
  _TransferSuccessDialog({
    required this.moved,
    required this.fromName,
    required this.toName,
    required this.fromBalance,
    required this.toBalance,
    this.fromColor,
    this.toColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(Gap.xl),
      child: Padding(
        padding: const EdgeInsets.all(Gap.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Transfer successful',
              style: AppText.subtitle.w8.tint(Barako.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.xl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _accountChip(fromName, fromBalance, fromColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                  child: _check(context),
                ),
                Expanded(child: _accountChip(toName, toBalance, toColor)),
              ],
            ),
            const SizedBox(height: Gap.xl),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatMoneyText(moved),
                maxLines: 1,
                style: AppText.amountLg.w8,
              ),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              'Successfully transferred',
              style: AppText.small.tint(Barako.muted),
            ),
            const SizedBox(height: Gap.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The checkmark, scaling in on first build, gated through Motion.of so
  /// reduce-motion shows it settled instantly.
  Widget _check(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, Motion.reveal),
      curve: Curves.elasticOut,
      builder: (context, t, child) =>
          Transform.scale(scale: t.clamp(0.0, 1.0), child: child),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Barako.income.withValues(alpha: BarakoAlpha.tint),
          shape: BoxShape.circle,
        ),
        child: Icon(
          salapifyIcon('done'),
          size: IconSizes.inline,
          color: Barako.income,
        ),
      ),
    );
  }

  /// One account, with its NEW balance, tinted by its brand colour where one is
  /// known. Never draws money in the brand colour: the tint is a thin top
  /// stripe, the figure stays in full ink so it always clears contrast.
  Widget _accountChip(String name, double balance, Color? brand) {
    final accent = brand ?? Barako.primary;
    return Container(
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: Barako.border),
      ),
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 4,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.small.w6.tint(Barako.text),
          ),
          const SizedBox(height: 2),
          Text('New balance', style: AppText.caption.tint(Barako.muted)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoneyText(balance),
              maxLines: 1,
              style: AppText.amountRow.tint(Barako.text),
            ),
          ),
        ],
      ),
    );
  }
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
