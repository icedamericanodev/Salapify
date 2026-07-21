// Accounts: see, add, edit, and delete your accounts and assets, and change a
// balance. Reached from the Overview. Ported from mobile/app/accounts.js, minus
// the transfer modal (a follow-up), which is the only part with genuinely new
// money math. A balance change to an existing account posts a recorded
// adjustment through the golden-verified ledger (reversible, shows in History)
// rather than silently overwriting the number.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../money/accounts_calc.dart';
import '../money/debtmath.dart' show formatMoneyText;
import '../money/ledger.dart' show amountOf;
import '../money/statements.dart' show netWorthParts;
import '../data/store.dart';
import '../theme.dart';
import '../widgets/pressable_scale.dart';

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
const _bankKinds = {'savings', 'checking', 'ewallet'};

String _todayISO() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

class AccountsScreen extends StatelessWidget {
  final SalapifyStore store;
  const AccountsScreen({super.key, required this.store});

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
        title: Text('Accounts',
            style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final accounts = _rows('accounts');
            final assets = _rows('assets');
            final debts = _rows('debts');
            final cash =
                accounts.where((a) => a['kind'] == 'cash').toList();
            final bank = accounts
                .where((a) => _bankKinds.contains(a['kind']))
                .toList();
            final parts = netWorthParts(store.data);

            double sum(List<Map<String, dynamic>> l, String k) =>
                l.fold(0.0, (t, x) => t + amountOf(x[k]));

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _summary(parts),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _addButton(context, '+ Account',
                            () => _openForm(context, isAccount: true))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _addButton(context, '+ Asset',
                            () => _openForm(context, isAccount: false))),
                  ],
                ),
                const SizedBox(height: 20),
                _section('CASH', sum(cash, 'balance'), [
                  for (final a in cash) _accountRow(context, a),
                  if (cash.isEmpty) _empty('No cash account yet.'),
                ]),
                _section('SAVINGS AND BANK', sum(bank, 'balance'), [
                  for (final a in bank) _accountRow(context, a),
                  if (bank.isEmpty) _empty('Nothing here yet.'),
                ]),
                _section('INVESTMENTS AND OTHER ASSETS', sum(assets, 'value'), [
                  for (final a in assets) _assetRow(context, a),
                  if (assets.isEmpty) _empty('No assets yet.'),
                ]),
                _section('DEBTS', parts['debts'] as double, [
                  for (final d in debts)
                    _plainRow('💳', d['name']?.toString() ?? 'Debt',
                        amountOf(d['remaining']),
                        amountColor: Barako.warningStrong),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Manage debts on the Debts screen.',
                        style: TextStyle(color: Barako.faint, fontSize: 12)),
                  ),
                ], subtotalColor: Barako.warningStrong),
              ],
            );
          },
        ),
      ),
    );
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
                child: Text(formatMoneyText(parts['netWorth'] as double),
                    maxLines: 1,
                    style: TextStyle(
                        fontFamily: Barako.displayFont,
                        color: Barako.text,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Flexible(
                      child: _miniStat('Total assets',
                          parts['assets'] as double, Barako.primaryText)),
                  const SizedBox(width: 12),
                  Flexible(
                      child: _miniStat('Total owed',
                          parts['liabilities'] as double, Barako.warningStrong)),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _miniStat(String label, double value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Barako.muted, fontSize: 12)),
          const SizedBox(height: 2),
          Text(formatMoneyText(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()])),
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
              child: Text(label,
                  style: TextStyle(
                      color: Barako.primaryText,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );

  Widget _section(String title, double subtotal, List<Widget> children,
      {Color? subtotalColor}) {
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
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Barako.kickerStyle),
                ),
                const SizedBox(width: 8),
                Text(formatMoneyText(subtotal),
                    style: TextStyle(
                        color: subtotalColor ?? Barako.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()])),
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
        child: Text(text, style: TextStyle(color: Barako.faint, fontSize: 13)),
      );

  Widget _accountRow(BuildContext context, Map<String, dynamic> a) {
    final target = amountOf(a['target']);
    final balance = amountOf(a['balance']);
    final brand = (a['brand'] ?? '').toString();
    String? sub;
    double? progress;
    if (target > 0) {
      final pct =
          ((balance / target) * 100).clamp(0, 999).round();
      sub = '${brand.isNotEmpty ? '$brand · ' : ''}$pct% of ${formatMoneyText(target)}';
      progress = (balance / target).clamp(0.0, 1.0);
    } else if (brand.isNotEmpty) {
      sub = brand;
    }
    return _row(
      icon: (a['icon'] ?? '').toString().isEmpty
          ? '💵'
          : a['icon'].toString(),
      name: a['name']?.toString() ?? 'Account',
      sub: sub,
      amount: balance,
      progress: progress,
      onTap: () => _openForm(context, isAccount: true, item: a),
    );
  }

  Widget _assetRow(BuildContext context, Map<String, dynamic> a) => _row(
        icon: '📈',
        name: a['name']?.toString() ?? 'Asset',
        sub: (a['kind'] ?? '').toString(),
        amount: amountOf(a['value']),
        onTap: () => _openForm(context, isAccount: false, item: a),
      );

  Widget _plainRow(String icon, String name, double amount,
          {Color? amountColor}) =>
      _row(icon: icon, name: name, amount: amount, amountColor: amountColor);

  Widget _row({
    required String icon,
    required String name,
    double? amount,
    String? sub,
    double? progress,
    Color? amountColor,
    VoidCallback? onTap,
  }) {
    final body = Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Barako.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                if (sub != null && sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Barako.muted, fontSize: 12)),
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
            Text(formatMoneyText(amount),
                style: TextStyle(
                    color: amountColor ?? Barako.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ],
      ),
    );
    if (onTap == null) return body;
    return PressableScale(child: InkWell(onTap: onTap, child: body));
  }

  void _openForm(BuildContext context,
      {required bool isAccount, Map<String, dynamic>? item}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _AccountForm(store: store, isAccount: isAccount, item: item),
    );
  }
}

/// The add/edit sheet for an account or an asset.
class _AccountForm extends StatefulWidget {
  final SalapifyStore store;
  final bool isAccount;
  final Map<String, dynamic>? item;
  const _AccountForm(
      {required this.store, required this.isAccount, this.item});

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
            : _numStr(widget.isAccount ? it['balance'] : it['value']));
    _target = TextEditingController(
        text: (it != null && amountOf(it['target']) > 0)
            ? _numStr(it['target'])
            : '');
    _brand = TextEditingController(text: it?['brand']?.toString() ?? '');
    _icon = TextEditingController(text: it?['icon']?.toString() ?? '');
    _kind = (it?['kind'] ?? (widget.isAccount ? 'cash' : 'crypto')).toString();
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
        await widget.store
            .updateAsset(aid, name: name, kind: _kind, value: amount);
      } else {
        await widget.store.addAsset(name: name, kind: _kind, value: amount);
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
    final icon = _icon.text.trim().isEmpty ? '💵' : _icon.text.trim();

    setState(() => _saving = true);
    final id = widget.item?['id'];
    if (id is String) {
      final oldBal = amountOf(widget.item!['balance']);
      await widget.store.updateAccountDetails(id,
          name: name, kind: _kind, brand: brand, icon: icon, target: target);
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
          balance: amount);
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
        title: Text('Was this money spent?',
            style: TextStyle(color: Barako.text)),
        content: Text(
            'Your balance is ${formatMoneyText(amt)} lower. Logging it as an expense keeps your spending reports right. If it is just a correction, we record a balance adjustment instead.',
            style: TextStyle(color: Barako.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Just a correction',
                style: TextStyle(color: Barako.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Log as expense',
                style: TextStyle(
                    color: Barako.primaryText, fontWeight: FontWeight.w700)),
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
      String id, String type, String? flow, double amount, String label) async {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not record the balance change. $e')));
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
      ..showSnackBar(const SnackBar(
          content: Text(
              'Saving is off because your data could not be read. Import a backup to recover first.')));
  }

  @override
  Widget build(BuildContext context) {
    final kinds = widget.isAccount ? _accountKinds : _assetKinds;
    final noun = widget.isAccount ? 'account' : 'asset';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Barako.background,
          border: Border.all(color: Barako.border),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
            maxHeight: (MediaQuery.of(context).size.height -
                    MediaQuery.of(context).viewInsets.bottom) *
                0.9),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_isEdit ? 'Edit' : 'Add'} $noun',
                  style: TextStyle(
                      color: Barako.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              _label('Name'),
              _input(_name, hint: 'e.g. GCash', action: TextInputAction.next),
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
                          fontWeight: FontWeight.w600),
                      side: BorderSide(color: Barako.border),
                    ),
                ],
              ),
              _label(widget.isAccount ? 'Balance' : 'Value'),
              _input(_amount,
                  hint: '0',
                  number: true,
                  action: widget.isAccount
                      ? TextInputAction.next
                      : TextInputAction.done),
              if (_isEdit && widget.isAccount) ...[
                const SizedBox(height: 6),
                Text(
                    'Set this to the real total in your account. We log the difference so your reports and History stay right.',
                    style: TextStyle(color: Barako.faint, fontSize: 12)),
              ],
              if (widget.isAccount) ...[
                _label('Bank or brand (optional)'),
                _input(_brand, hint: 'e.g. BPI', action: TextInputAction.next),
                _label('Icon emoji (optional)'),
                _input(_icon, hint: '💵', action: TextInputAction.next),
                _label('Savings target (optional)'),
                _input(_target,
                    hint: '0', number: true, action: TextInputAction.done),
              ],
              if (_err != null) ...[
                const SizedBox(height: 10),
                Text(_err!,
                    style:
                        TextStyle(color: Barako.warningStrong, fontSize: 13)),
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
                              backgroundColor:
                                  Barako.warningStrong.withValues(alpha: 0.12))
                          : null,
                      child: Text(
                          _confirmDel ? 'Tap again to delete' : 'Delete',
                          style: TextStyle(
                              color: Barako.warningStrong,
                              fontWeight: FontWeight.w600)),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel',
                            style: TextStyle(color: Barako.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: Barako.primary,
                          foregroundColor: Barako.onPrimary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                        ),
                        child: const Text('Save',
                            style: TextStyle(fontWeight: FontWeight.w700)),
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
        child: Text(t, style: TextStyle(color: Barako.muted, fontSize: 12)),
      );

  Widget _input(TextEditingController c,
      {String? hint, bool number = false, TextInputAction? action}) {
    return TextField(
      controller: c,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textInputAction: action,
      inputFormatters: number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      style: TextStyle(color: Barako.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Barako.faint),
        filled: true,
        fillColor: Barako.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
