// One account, in full: the card, the numbers, the secure information, a saved
// receiving QR, and the recent activity. Opened by tapping a card on the
// Accounts screen. A digital wallet page for money you already have, and
// deliberately NOT a pretend banking app: everything here is what YOU stored in
// Salapify, it says so, and it can never show a full card number, a PIN, a CVV
// or an OTP because none of those is ever stored.
//
// Built the way goal_detail.dart is: a Scaffold with a ListenableBuilder on the
// store, re-reading the row by id every build, so an edit, an archive or a QR
// change made here shows immediately and a row deleted elsewhere degrades to a
// calm message rather than a crash.
//
// The reveal follows the App Lock pattern (widgets/lock_gate.dart): the same
// BiometricAuthenticator, so the digits sit behind the phone's own fingerprint
// or passcode when it has one. It is only ever the LAST FOUR digits, which is
// all Salapify keeps, and they re-hide on a timer and when the screen closes, so
// they are never left on screen after you walk away.

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/qr_vault.dart';
import '../data/store.dart';
import '../money/account_taxonomy.dart';
import '../money/card_products.dart';
import '../money/format.dart' show formatMoney, prettyDay;
import '../money/ledger.dart' show amountOf;
import '../money/institutions.dart';
import '../services/secure_window.dart';
import '../theme.dart';
import '../typography.dart';
import '../widgets/bank_card.dart';
import '../widgets/lock_gate.dart'
    show BiometricAuthenticator, LockAuthenticator;
import '../widgets/salapify_icon.dart';
import '../widgets/section.dart';

class AccountDetailScreen extends StatefulWidget {
  final SalapifyStore store;

  /// The row id, and which collection it lives in. Passed rather than the row
  /// itself so the screen always reads the CURRENT row from the store, never a
  /// stale copy captured when it opened.
  final String id;
  final AccountStore accountStore;

  /// The vault, injectable so a test points it at a temp folder. Null in
  /// production, where it is loaded from the app documents directory.
  final QrVault? vault;

  /// The reveal authenticator, injectable so a widget test provides a fake
  /// (the real platform channel does not exist in a test).
  final LockAuthenticator? authenticator;

  const AccountDetailScreen({
    super.key,
    required this.store,
    required this.id,
    required this.accountStore,
    this.vault,
    this.authenticator,
  });

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen>
    with WidgetsBindingObserver {
  late final LockAuthenticator _auth =
      widget.authenticator ?? BiometricAuthenticator();
  QrVault? _vault;
  bool _revealed = false;

  /// True while this screen is holding FLAG_SECURE on through the force latch,
  /// so it releases exactly once however it closes (timer, tap, background, or
  /// dispose).
  bool _secured = false;
  Timer? _revealTimer;

  bool get _isDebt => widget.accountStore == AccountStore.debts;
  String get _collection => switch (widget.accountStore) {
    AccountStore.accounts => 'accounts',
    AccountStore.assets => 'assets',
    AccountStore.debts => 'debts',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vault = widget.vault;
    if (_vault == null) {
      // path_provider only exists on a device, so this is a no-op in a widget
      // test and the QR section simply shows its empty state there.
      QrVault.inAppDocuments()
          .then((v) {
            if (mounted) setState(() => _vault = v);
          })
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    // Never leave the force latch held: release it exactly once so a reveal on
    // this screen does not keep FLAG_SECURE on for the rest of the app's life.
    if (_secured) {
      SecureWindow.release();
      _secured = false;
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the foreground with digits on screen re-hides them, so a quick
    // background hop never leaves the last four sitting revealed on return.
    if (state != AppLifecycleState.resumed && _revealed) _hide();
  }

  Map<String, dynamic>? _row() {
    final list = widget.store.data[_collection];
    if (list is! List) return null;
    for (final r in list) {
      if (r is Map && r['id'] == widget.id) return r.cast<String, dynamic>();
    }
    return null;
  }

  String? _last4(Map<String, dynamic> row) {
    final v = row['last4'];
    return (v is String && RegExp(r'^\d{4}$').hasMatch(v)) ? v : null;
  }

  // --- Reveal ---------------------------------------------------------------

  Future<void> _toggleReveal() async {
    if (_revealed) {
      _hide();
      return;
    }
    // The last four digits are not, on their own, a secret; but when the phone
    // CAN check identity we ask, because the person chose to protect this and
    // the copy action right beside it puts the digits on the clipboard. When
    // the phone cannot lock at all, we still reveal, so a phone with no
    // biometrics never hides a number from its own owner.
    if (await _auth.canLock()) {
      if (!await _auth.authenticate()) return;
    }
    if (!mounted) return;
    if (!_secured) {
      SecureWindow.retain();
      _secured = true;
    }
    setState(() => _revealed = true);
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(seconds: 30), _hide);
  }

  void _hide() {
    _revealTimer?.cancel();
    if (_secured) {
      SecureWindow.release();
      _secured = false;
    }
    if (!mounted) return;
    setState(() => _revealed = false);
  }

  Future<void> _copyLast4(String last4) async {
    if (await _auth.canLock() && !_revealed) {
      if (!await _auth.authenticate()) return;
    }
    await Clipboard.setData(ClipboardData(text: last4));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Copied. It stays only until you copy something else.'),
        ),
      );
  }

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Barako.background,
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          _isDebt ? 'Card' : 'Account',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: Icon(salapifyIcon('edit'), color: Barako.text),
            onPressed: _editDetails,
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: Icon(salapifyIcon('more'), color: Barako.text),
            color: Barako.card,
            onSelected: (v) {
              if (v == 'archive') _toggleArchive();
              if (v == 'delete') _confirmDelete();
            },
            itemBuilder: (_) {
              final row = _row();
              final archived = row?['isArchived'] == true;
              return [
                PopupMenuItem(
                  value: 'archive',
                  child: Text(
                    archived ? 'Unarchive' : 'Archive',
                    style: TextStyle(color: Barako.text),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete',
                    style: TextStyle(color: Barako.warningStrong),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final row = _row();
            if (row == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'This account is gone from your book. Nothing else changed.',
                    textAlign: TextAlign.center,
                    style: AppText.label.w4.tint(Barako.muted),
                  ),
                ),
              );
            }
            return _body(row);
          },
        ),
      ),
    );
  }

  Widget _body(Map<String, dynamic> row) {
    final instId = row['institutionId']?.toString();
    final kind = resolveKind(row, widget.accountStore);
    final last4 = _last4(row);
    final archived = row['isArchived'] == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        if (archived)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _banner(
              'Archived. It stays here and keeps its history, but it is left '
              'out of your totals.',
            ),
          ),
        _heroCard(row, kind.subtype.label, last4),
        const SizedBox(height: 20),
        _summaryCard(row),
        const SizedBox(height: 20),
        _secureSection(row, instId, last4),
        const SizedBox(height: 20),
        _qrSection(row, instId),
        const SizedBox(height: 20),
        _historySection(row),
      ],
    );
  }

  Widget _heroCard(Map<String, dynamic> row, String typeLabel, String? last4) {
    final instId = row['institutionId']?.toString();
    final bankName = institutionLabel(row) ?? (row['name']?.toString() ?? '');
    // Physical cash is a wallet, not a card: the same honest visual the carousel
    // shows, so tapping the wallet never opens onto a bank card with a chip and
    // a masked number cash does not have.
    final isCash = !_isDebt && row['kind']?.toString() == 'cash';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isCash)
          CashBalanceTile(
            name: row['name']?.toString() ?? bankName,
            balance: amountOf(row['balance']),
          )
        // The hero follows the reveal: hidden by default it shows only dots, so
        // the digits are in one place on this screen (behind the reveal), not
        // stated on the card while the secure section below still gates them.
        // Revealing shows them here and there together.
        else if (_isDebt)
          CreditCardAccountCard(
            bankName: row['name']?.toString() ?? bankName,
            brandColor: institutionBrandColor(instId),
            last4: _revealed ? last4 : null,
            outstanding: amountOf(row['remaining']),
            creditLimit: amountOf(row['creditLimit']),
            monogram: institutionById(instId)?.initials,
            networkMark: cardNetworkWordmark(row['cardNetwork']?.toString()),
          )
        else
          BankAccountCard(
            bankName: row['name']?.toString() ?? bankName,
            accountType: _shortType(row['kind']?.toString()),
            brandColor: institutionBrandColor(instId),
            last4: _revealed ? last4 : null,
            balance: amountOf(row['balance']),
            monogram: institutionById(instId)?.initials,
          ),
        const SizedBox(height: 12),
        Text(
          [
            typeLabel,
            if (institutionLabel(row) != null) institutionLabel(row)!,
            if (_isDebt &&
                cardNetworkById(row['cardNetwork']?.toString()) != null)
              cardNetworkById(row['cardNetwork']?.toString())!.displayName,
            if (_isDebt &&
                cardProductLabel(instId, row['cardProductId']?.toString()) !=
                    null)
              cardProductLabel(instId, row['cardProductId']?.toString())!,
          ].join(' · '),
          style: AppText.small.tint(Barako.muted),
        ),
      ],
    );
  }

  String _shortType(String? kind) => switch (kind) {
    'savings' => 'Savings',
    'checking' => 'Checking',
    'ewallet' => 'E-wallet',
    'cash' => 'Cash',
    _ => 'Account',
  };

  Widget _summaryCard(Map<String, dynamic> row) {
    final rows = <Widget>[];
    if (_isDebt) {
      final outstanding = amountOf(row['remaining']);
      final limit = amountOf(row['creditLimit']);
      // Plain words: "outstanding" reads as praise to a first-jobber, and
      // this now agrees with the card face's YOU OWE kicker.
      rows.add(_stat('What you owe', formatMoney(outstanding)));
      if (limit > 0) {
        final available = (limit - outstanding)
            .clamp(0, double.infinity)
            .toDouble();
        rows.add(_stat('Credit limit', formatMoney(limit)));
        rows.add(
          _stat('Available credit', formatMoney(available), strong: true),
        );
      }
      final stmt = amountOf(row['statementDay']).round();
      final due = amountOf(row['dueDay']).round();
      if (stmt > 0) rows.add(_stat('Statement day', _dayLabel(stmt)));
      if (due > 0) rows.add(_stat('Payment due day', _dayLabel(due)));
      final fee = amountOf(row['annualFee']);
      if (fee > 0) rows.add(_stat('Annual fee', formatMoney(fee)));
    } else {
      rows.add(
        _stat(
          'Current balance',
          formatMoney(amountOf(row['balance'])),
          strong: true,
        ),
      );
      final target = amountOf(row['target']);
      if (target > 0) {
        rows.add(_stat('Maintaining or target', formatMoney(target)));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker(_isDebt ? 'CARD OVERVIEW' : 'OVERVIEW'),
        const SizedBox(height: 8),
        _panel(
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _dayLabel(int day) {
    final suffix = (day >= 11 && day <= 13)
        ? 'th'
        : switch (day % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
    return '$day$suffix of the month';
  }

  Widget _stat(String label, String value, {bool strong = false}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(child: Text(label, style: AppText.body.tint(Barako.muted))),
      const SizedBox(width: 12),
      // Scale down, never truncate: an ellipsized peso figure reads as a
      // DIFFERENT amount, which is worse than a smaller one.
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            style: strong
                ? AppText.amountRow.tint(Barako.primaryText)
                : AppText.body.w6,
          ),
        ),
      ),
    ],
  );

  // --- Secure information ---------------------------------------------------

  Widget _secureSection(
    Map<String, dynamic> row,
    String? instId,
    String? last4,
  ) {
    final holder = row['accountHolderName']?.toString();
    final branch = row['branchDetails']?.toString();
    final instructions = row['paymentInstructions']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker('SECURE INFORMATION'),
        const SizedBox(height: 8),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(salapifyIcon('lock'), size: 18, color: Barako.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isDebt ? 'Card number ending' : 'Account number ending',
                      style: AppText.body.tint(Barako.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (last4 == null)
                Text(
                  'No digits saved. Add the last four with Edit above.',
                  style: AppText.small.tint(Barako.faint),
                )
              else
                _revealRow(last4),
              const SizedBox(height: 12),
              // The honest boundary, stated where the fields are. The number
              // field keeps only four digits (a guarantee); the rest is advice,
              // because a person can still type anything into a note. A note
              // that contains a real card number is redacted before it is
              // stored (money/account_taxonomy.dart), but a PIN or CVV cannot be
              // told from other digits, so we ask rather than promise.
              Text(
                'This number field keeps only the last four digits. Never type '
                'your full number, PIN, CVV, password, or OTP anywhere.',
                style: AppText.caption.tint(Barako.muted),
              ),
              if (holder != null && holder.isNotEmpty) ...[
                const Divider(height: 24),
                _noteLine('Account holder', holder),
              ],
              if (branch != null && branch.isNotEmpty) ...[
                const SizedBox(height: 12),
                _noteLine('Branch or reference', branch),
              ],
              if (instructions != null && instructions.isNotEmpty) ...[
                const SizedBox(height: 12),
                _noteLine('Notes', instructions),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _revealRow(String last4) {
    // Semantics: when hidden, the screen reader hears "hidden", not the digits.
    final shown = _revealed ? '•••• $last4' : '•••• ••••';
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: _revealed
                ? 'Number ending $last4'
                : 'Number hidden. Reveal to see the last four digits.',
            child: ExcludeSemantics(
              child: Text(
                shown,
                style: AppText.title.copyWith(
                  fontSize: 20,
                  letterSpacing: 3,
                  color: Barako.text,
                ),
              ),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: _toggleReveal,
          icon: Icon(salapifyIcon(_revealed ? 'hide' : 'reveal'), size: 18),
          label: Text(_revealed ? 'Hide' : 'Reveal'),
        ),
        if (_revealed)
          IconButton(
            tooltip: 'Copy',
            onPressed: () => _copyLast4(last4),
            icon: Icon(
              salapifyIcon('copy'),
              size: 18,
              color: Barako.primaryText,
            ),
          ),
      ],
    );
  }

  Widget _noteLine(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: Barako.kickerStyle),
      const SizedBox(height: 2),
      Text(value, style: AppText.body.w6),
    ],
  );

  // --- QR vault -------------------------------------------------------------

  Widget _qrSection(Map<String, dynamic> row, String? instId) {
    final ref = row['qrRef']?.toString();
    final hasRef = isQrRef(ref);
    final label = row['qrLabel']?.toString();
    final suggests = institutionSupportsQrReceiving(instId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker('RECEIVING QR'),
        const SizedBox(height: 8),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasRef) ...[
                _QrThumb(
                  vault: _vault,
                  qrRef: ref!,
                  onView: () => _viewQr(ref, label),
                ),
                const SizedBox(height: 10),
                if (label != null && label.isNotEmpty)
                  Text(label, style: AppText.body.w6),
                const SizedBox(height: 6),
                // Wrap, not Row: three buttons at 1.5x on a narrow phone would
                // overrun a fixed row, so they reflow to a second line instead.
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      onPressed: () => _viewQr(ref, label),
                      child: const Text('View'),
                    ),
                    TextButton(
                      onPressed: _pickQr,
                      child: const Text('Replace'),
                    ),
                    TextButton(
                      onPressed: () => _confirmRemoveQr(ref),
                      child: Text(
                        'Remove',
                        style: TextStyle(color: Barako.warningStrong),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  suggests
                      ? 'Save your receiving QR so you always have it, even offline.'
                      : 'Save a payment or receiving QR for this account.',
                  style: AppText.body.tint(Barako.muted),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickQr,
                  icon: Icon(salapifyIcon('add'), size: 18),
                  label: const Text('Add a QR image'),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'This QR image stays on your device. It is not included when '
                'you export or share a backup.',
                style: AppText.caption.tint(Barako.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickQr() async {
    final vault = _vault;
    final messenger = ScaffoldMessenger.of(context);
    if (vault == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('QR storage is not ready yet. Try again.'),
        ),
      );
      return;
    }
    FilePickerResult? res;
    try {
      res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the picker.')),
      );
      return;
    }
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    final ext = (f.extension ?? 'png').toLowerCase();
    Uint8List? bytes = f.bytes;
    if (bytes == null && !kIsWeb && f.path != null) {
      bytes = await File(f.path!).readAsBytes();
    }
    if (bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not read that image.')),
      );
      return;
    }
    try {
      final ref = await vault.save(
        bytes,
        ext: kQrImageExtensions.contains(ext) ? ext : 'png',
        nonce: '${widget.id}_${bytes.length}',
      );
      final old = _row()?['qrRef']?.toString();
      await _patch({'qrRef': ref});
      // Replace deletes the previous file, so a swap never leaves an orphan.
      if (isQrRef(old) && old != ref) await vault.remove(old);
    } on QrSaveException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _confirmRemoveQr(String ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text('Remove this QR?', style: TextStyle(color: Barako.text)),
        content: Text(
          'The image is deleted from this device. You can add another anytime.',
          style: TextStyle(color: Barako.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Keep it',
              style: TextStyle(color: Barako.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _removeQr(ref);
              if (mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('QR removed.')));
              }
            },
            child: Text(
              'Remove',
              style: TextStyle(
                color: Barako.warningStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeQr(String ref) async {
    await _patch({'qrRef': ''});
    await _vault?.remove(ref);
  }

  void _viewQr(String ref, String? label) {
    showAccountQrSheet(context, vault: _vault, qrRef: ref, label: label);
  }

  // --- History --------------------------------------------------------------

  Widget _historySection(Map<String, dynamic> row) {
    final items = _isDebt ? _debtPayments() : _accountTxns();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker('RECENT ACTIVITY'),
        const SizedBox(height: 8),
        _panel(
          child: items.isEmpty
              ? Text(
                  'No activity here yet.',
                  style: AppText.small.tint(Barako.muted),
                )
              : Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const Divider(height: 18),
                      items[i],
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  List<Widget> _accountTxns() {
    final txs = (widget.store.data['transactions'] as List? ?? const [])
        .whereType<Map>()
        .where((t) => t['accountId'] == widget.id)
        .toList();
    txs.sort(
      (a, b) =>
          (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()),
    );
    return [
      for (final t in txs.take(8))
        _activityRow(
          (t['label'] ?? 'Activity').toString(),
          (t['date'] ?? '').toString(),
          amountOf(t['amount']),
          t['flow']?.toString(),
          t['type']?.toString(),
        ),
    ];
  }

  List<Widget> _debtPayments() {
    final ps = (widget.store.data['payments'] as List? ?? const [])
        .whereType<Map>()
        .where((p) => p['debtId'] == widget.id)
        .toList();
    ps.sort(
      (a, b) =>
          (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()),
    );
    return [
      for (final p in ps.take(8))
        _activityRow(
          p['status'] == 'pending' ? 'Payment (pending)' : 'Payment',
          (p['date'] ?? '').toString(),
          amountOf(p['amount']),
          'out',
          'payment',
        ),
    ];
  }

  Widget _activityRow(
    String label,
    String iso,
    double amount,
    String? flow,
    String? type,
  ) {
    final isIn = flow == 'in' || (flow == null && type == 'income');
    final sign = type == 'payment' ? '-' : (isIn ? '+' : '-');
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppText.body.w6,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (iso.isNotEmpty)
                Text(prettyDay(iso), style: AppText.caption.tint(Barako.muted)),
            ],
          ),
        ),
        Text(
          '$sign${formatMoney(amount)}',
          style: AppText.body.w6.tint(
            isIn && type != 'payment' ? Barako.primaryText : Barako.text,
          ),
        ),
      ],
    );
  }

  // --- Edit, archive, delete ------------------------------------------------

  Future<void> _patch(Map<String, dynamic> fields) async {
    switch (widget.accountStore) {
      case AccountStore.accounts:
        await widget.store.patchAccountMeta(widget.id, fields);
      case AccountStore.assets:
        await widget.store.patchAssetMeta(widget.id, fields);
      case AccountStore.debts:
        await widget.store.patchDebtMeta(widget.id, fields);
    }
  }

  Future<void> _toggleArchive() async {
    final archived = _row()?['isArchived'] == true;
    // Absent means "counts", so archiving writes true and unarchiving writes
    // false, which sanitizeData keeps only while it is the non-default true.
    await _patch({'isArchived': !archived});
  }

  void _editDetails() {
    final row = _row();
    if (row == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Barako.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _EditDetailsSheet(
          row: row,
          isDebt: _isDebt,
          onSave: (fields) async {
            await _patch(fields);
          },
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text(
          'Delete this account?',
          style: TextStyle(color: Barako.text),
        ),
        content: Text(
          _isDebt
              ? 'The debt is removed. Your logged payments and history stay.'
              : 'The account is removed. Transactions you logged stay in your history.',
          style: TextStyle(color: Barako.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Keep it',
              style: TextStyle(color: Barako.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ref = _row()?['qrRef']?.toString();
              switch (widget.accountStore) {
                case AccountStore.accounts:
                  await widget.store.deleteAccount(widget.id);
                case AccountStore.assets:
                  await widget.store.deleteAsset(widget.id);
                case AccountStore.debts:
                  await widget.store.deleteDebt(widget.id);
              }
              if (isQrRef(ref)) await _vault?.remove(ref);
              if (mounted) Navigator.of(context).pop();
            },
            child: Text(
              'Delete',
              style: TextStyle(
                color: Barako.warningStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Small shared pieces --------------------------------------------------

  Widget _panel({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Barako.card,
      borderRadius: BorderRadius.circular(Radii.lg),
      border: Border.all(color: Barako.border),
    ),
    child: child,
  );

  Widget _banner(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Barako.surfaceRaised,
      borderRadius: BorderRadius.circular(Radii.md),
      border: Border.all(color: Barako.border),
    ),
    child: Text(text, style: AppText.small.tint(Barako.muted)),
  );
}

/// A framed QR thumbnail. Reads bytes from the vault; when there is no readable
/// file (a restored backup, or a device where the vault has not loaded) it
/// shows a calm placeholder instead of a broken image.
///
/// Stateful, and the read future is created ONCE, not inline in build: a
/// FutureBuilder handed a fresh future every rebuild re-reads the file forever,
/// which spins the widget and never lets the frame settle.
class _QrThumb extends StatefulWidget {
  final QrVault? vault;
  final String qrRef;
  final VoidCallback onView;
  const _QrThumb({
    required this.vault,
    required this.qrRef,
    required this.onView,
  });

  @override
  State<_QrThumb> createState() => _QrThumbState();
}

class _QrThumbState extends State<_QrThumb> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = widget.vault?.readBytes(widget.qrRef) ?? Future.value(null);
  }

  @override
  void didUpdateWidget(_QrThumb old) {
    super.didUpdateWidget(old);
    if (old.qrRef != widget.qrRef || old.vault != widget.vault) {
      _bytes = widget.vault?.readBytes(widget.qrRef) ?? Future.value(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onView,
      child: Container(
        width: 132,
        height: 132,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Barako.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: FutureBuilder<Uint8List?>(
          future: _bytes,
          builder: (context, snap) {
            final bytes = snap.data;
            if (bytes == null) {
              return Center(
                child: Icon(
                  salapifyIcon('card'),
                  color: Barako.faint,
                  size: 40,
                ),
              );
            }
            return Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            );
          },
        ),
      ),
    );
  }
}

/// Open the focused QR viewer from anywhere, holding FLAG_SECURE for exactly
/// as long as the sheet is up. The flip card's QR shortcut reuses this so the
/// receiving QR is shown the one way it is shown here: a white field, on-device
/// only, screenshot-blocked, and never rendered onto the card face itself.
Future<void> showAccountQrSheet(
  BuildContext context, {
  required QrVault? vault,
  required String qrRef,
  String? label,
}) {
  SecureWindow.retain();
  try {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Barako.background,
      builder: (_) => _QrViewSheet(vault: vault, qrRef: qrRef, label: label),
    ).whenComplete(SecureWindow.release);
  } catch (_) {
    // showModalBottomSheet throws synchronously only with no Navigator in
    // context, so .whenComplete never attaches and the latch would be stranded
    // on for the app's life. Release it here and rethrow so the caller still
    // sees the failure.
    SecureWindow.release();
    rethrow;
  }
}

/// The focused, full-width QR viewer. A white field so a phone camera reads it.
/// Stateful for the same reason as [_QrThumb]: the read future is made once.
class _QrViewSheet extends StatefulWidget {
  final QrVault? vault;
  final String qrRef;
  final String? label;
  const _QrViewSheet({required this.vault, required this.qrRef, this.label});

  @override
  State<_QrViewSheet> createState() => _QrViewSheetState();
}

class _QrViewSheetState extends State<_QrViewSheet> {
  late final Future<Uint8List?> _bytes =
      widget.vault?.readBytes(widget.qrRef) ?? Future.value(null);

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Barako.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            if (label != null && label.isNotEmpty)
              Text(label, style: AppText.title.copyWith(fontSize: 18)),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.all(16),
                child: FutureBuilder<Uint8List?>(
                  future: _bytes,
                  builder: (context, snap) {
                    final bytes = snap.data;
                    if (bytes == null) {
                      return Center(
                        child: Text(
                          'This QR is not in this copy of your data.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }
                    return Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Only you see this, and only from your device.',
              style: AppText.caption.tint(Barako.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The edit sheet for the non-money details: last four, holder, branch, notes,
/// QR label, and, for a card, the network. Money and identity (balance, name,
/// remaining) are edited elsewhere; this only ever writes patchable metadata.
class _EditDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> row;
  final bool isDebt;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _EditDetailsSheet({
    required this.row,
    required this.isDebt,
    required this.onSave,
  });

  @override
  State<_EditDetailsSheet> createState() => _EditDetailsSheetState();
}

class _EditDetailsSheetState extends State<_EditDetailsSheet> {
  late final TextEditingController _last4;
  late final TextEditingController _holder;
  late final TextEditingController _branch;
  late final TextEditingController _notes;
  late final TextEditingController _qrLabel;
  String _network = '';
  String? _err;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    _last4 = TextEditingController(text: r['last4']?.toString() ?? '');
    _holder = TextEditingController(
      text: r['accountHolderName']?.toString() ?? '',
    );
    _branch = TextEditingController(text: r['branchDetails']?.toString() ?? '');
    _notes = TextEditingController(
      text: r['paymentInstructions']?.toString() ?? '',
    );
    _qrLabel = TextEditingController(text: r['qrLabel']?.toString() ?? '');
    _network = r['cardNetwork']?.toString() ?? '';
  }

  @override
  void dispose() {
    _last4.dispose();
    _holder.dispose();
    _branch.dispose();
    _notes.dispose();
    _qrLabel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final last4 = _last4.text.trim();
    if (last4.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(last4)) {
      setState(
        () => _err =
            'The last four digits are exactly four numbers, '
            'or leave it blank.',
      );
      return;
    }
    final fields = <String, dynamic>{
      // Empty clears: sanitizeData drops an empty value on the next load.
      'last4': last4,
      'accountHolderName': _holder.text.trim(),
      'branchDetails': _branch.text.trim(),
      'paymentInstructions': _notes.text.trim(),
      'qrLabel': _qrLabel.text.trim(),
      if (last4.isNotEmpty) 'sensitiveDataProtectionVersion': 1,
    };
    if (widget.isDebt) {
      fields['cardNetwork'] = _network;
      // A network the issuer is not known to use is still allowed (a catalog is
      // never complete), but only one of the five known ids ever persists.
      if (!kCardNetworks.contains(_network)) fields.remove('cardNetwork');
    }
    await widget.onSave(fields);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final instId = widget.row['institutionId']?.toString();
    final networks = networksForIssuer(instId);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit details', style: AppText.heading.w8),
            const SizedBox(height: 4),
            Text(
              'Save only the last four digits. Never your PIN, CVV, password, '
              'or OTP.',
              style: AppText.caption.tint(Barako.muted),
            ),
            const SizedBox(height: 14),
            _field(
              _last4,
              widget.isDebt
                  ? 'Card number, last 4 (optional)'
                  : 'Account number, last 4 (optional)',
              number: true,
              maxLen: 4,
            ),
            if (widget.isDebt) ...[
              _label('Card network (optional)'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in networks)
                    ChoiceChip(
                      label: Text(n.displayName),
                      selected: _network == n.id,
                      onSelected: (_) => setState(
                        () => _network = _network == n.id ? '' : n.id,
                      ),
                      selectedColor: Barako.primary,
                      backgroundColor: Barako.card,
                      labelStyle: TextStyle(
                        color: _network == n.id
                            ? Barako.onPrimary
                            : Barako.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            _field(_holder, 'Account holder name (optional)'),
            _field(_branch, 'Branch or reference (optional)'),
            _field(
              _notes,
              'Notes or payment instructions (optional)',
              maxLines: 3,
            ),
            _field(_qrLabel, 'QR label (optional)'),
            if (_err != null) ...[
              const SizedBox(height: 6),
              Text(_err!, style: AppText.caption.tint(Barako.warningStrong)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('Save')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 8),
    child: Text(t, style: AppText.small.tint(Barako.muted)),
  );

  Widget _field(
    TextEditingController c,
    String label, {
    bool number = false,
    int maxLines = 1,
    int? maxLen,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        maxLength: maxLen,
        inputFormatters: number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        style: TextStyle(color: Barako.text),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
