// Recurring bills and income. Rent, internet, Netflix, salary, allowance: set
// it once and the app logs it automatically every month on its day, into the
// chosen account. Free covers up to 5 recurring items; Pro is unlimited (and
// free during early access). Posting happens in the store on open and on resume
// through the golden-locked engine, so nothing here schedules background work.
// Ported from the RN recurring screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../money/debtmath.dart' show formatMoneyText;
import '../theme.dart';
import '../widgets/pressable_scale.dart';

// Free plan keeps up to five recurring items; Pro is unlimited.
const int freeLimit = 5;

class RecurringScreen extends StatelessWidget {
  final SalapifyStore store;
  const RecurringScreen({super.key, required this.store});

  bool get _pro => (store.data['settings'] as Map?)?['pro'] == true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Recurring',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: () => _onAdd(context),
            child: Text(
              '+ Add',
              style: TextStyle(
                color: Barako.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final items = store.recurringList;
            var monthlyOut = 0.0;
            var monthlyIn = 0.0;
            for (final r in items) {
              final amt = (r['amount'] as num?)?.toDouble() ?? 0;
              if (r['type'] == 'income') {
                monthlyIn += amt;
              } else {
                monthlyOut += amt;
              }
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'Set a bill or income once and Salapify logs it every month '
                  'on its day, into the account you pick.',
                  style: TextStyle(
                    color: Barako.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                if (items.isNotEmpty) _totals(monthlyOut, monthlyIn),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  _empty(context)
                else ...[
                  for (final r in items) _recurringCard(context, r),
                  const SizedBox(height: 4),
                  if (!_pro)
                    Text(
                      '${items.length} of $freeLimit free recurring items used. '
                      'Pro is unlimited.',
                      style: TextStyle(color: Barako.faint, fontSize: 12),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _totals(double out, double income) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _totalCol('MONEY OUT', out, Barako.warningStrong),
          Container(width: 1, height: 34, color: Barako.border),
          _totalCol('MONEY IN', income, Barako.primaryText),
        ],
      ),
    ),
  );

  Widget _totalCol(String label, double value, Color color) => Expanded(
    child: Column(
      children: [
        Text(label, style: Barako.kickerStyle),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatMoneyText(value),
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _empty(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      children: [
        Icon(Icons.event_repeat_outlined, color: Barako.faint, size: 40),
        const SizedBox(height: 10),
        Text(
          'No recurring items yet',
          style: TextStyle(
            color: Barako.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Add your rent, salary, or a subscription so it logs itself.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Barako.muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _onAdd(context),
          style: FilledButton.styleFrom(
            backgroundColor: Barako.primary,
            foregroundColor: Barako.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text(
            'Add your first recurring item',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  String _accountName(String? id) {
    if (id == null || id.isEmpty) return 'No account';
    for (final a in (store.data['accounts'] as List? ?? const [])) {
      if (a is Map && a['id'] == id) return a['name']?.toString() ?? 'Account';
    }
    return 'No account';
  }

  Widget _recurringCard(BuildContext context, Map<String, dynamic> r) {
    final isIncome = r['type'] == 'income';
    final amt = (r['amount'] as num?)?.toDouble() ?? 0;
    final day = (r['dayOfMonth'] as num?)?.toInt() ?? 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressableScale(
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openSheet(context, r),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isIncome ? Icons.south_west : Icons.north_east,
                    color: isIncome ? Barako.primaryText : Barako.warningStrong,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['label']?.toString() ?? 'Recurring',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Barako.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Day $day · ${_accountName(r['accountId'] as String?)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Barako.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${isIncome ? '+' : '-'}${formatMoneyText(amt)}',
                    style: TextStyle(
                      color: isIncome ? Barako.primaryText : Barako.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
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

  void _onAdd(BuildContext context) {
    if (!_pro && store.recurringList.length >= freeLimit) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _ProWall(
          store: store,
          onUnlockedProceed: () => _openSheet(context, null),
        ),
      );
      return;
    }
    _openSheet(context, null);
  }

  void _openSheet(BuildContext context, Map<String, dynamic>? item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecurringSheet(store: store, item: item),
    );
  }
}

class _ProWall extends StatelessWidget {
  final SalapifyStore store;
  final VoidCallback onUnlockedProceed;
  const _ProWall({required this.store, required this.onUnlockedProceed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Barako.background,
        border: Border.all(color: Barako.border),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unlimited recurring with Pro',
            style: TextStyle(
              color: Barako.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have $freeLimit recurring items, the free limit. Pro makes '
            'them unlimited. During early access Pro is free, and early users '
            'keep it free.',
            style: TextStyle(
              color: Barako.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Not now',
                  style: TextStyle(color: Barako.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  if (store.canWrite) await store.setPro(true);
                  nav.pop();
                  onUnlockedProceed();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Barako.primary,
                  foregroundColor: Barako.onPrimary,
                ),
                child: const Text(
                  'Unlock Pro free',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecurringSheet extends StatefulWidget {
  final SalapifyStore store;
  final Map<String, dynamic>? item;
  const _RecurringSheet({required this.store, this.item});

  @override
  State<_RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends State<_RecurringSheet> {
  late final TextEditingController _label;
  late final TextEditingController _amount;
  late final TextEditingController _day;
  late String _type;
  late String _accountId;
  String? _err;
  bool _confirmDel = false;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final r = widget.item;
    _type = r?['type'] == 'income' ? 'income' : 'expense';
    _accountId = r?['accountId'] is String ? r!['accountId'] as String : '';
    _label = TextEditingController(text: r?['label']?.toString() ?? '');
    _amount = TextEditingController(
      text: r != null ? _numStr(r['amount']) : '',
    );
    _day = TextEditingController(
      text: r != null
          ? ((r['dayOfMonth'] as num?)?.toInt() ?? 1).toString()
          : '',
    );
  }

  String _numStr(dynamic v) {
    if (v is num) {
      return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    }
    return v?.toString() ?? '';
  }

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    _day.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _accounts => [
    for (final a in (widget.store.data['accounts'] as List? ?? const []))
      if (a is Map) a.cast<String, dynamic>(),
  ];

  Future<void> _save() async {
    if (_saving) return;
    final label = _label.text.trim();
    if (label.isEmpty) {
      setState(() => _err = 'Give it a name, like Rent or Netflix.');
      return;
    }
    final amount =
        double.tryParse(_amount.text.replaceAll(RegExp(r'[, ]'), '')) ?? 0;
    if (!amount.isFinite || amount <= 0) {
      setState(() => _err = 'Enter an amount greater than 0.');
      return;
    }
    final day = int.tryParse(_day.text.trim()) ?? 0;
    if (day < 1 || day > 31) {
      setState(() => _err = 'The day should be from 1 to 31.');
      return;
    }
    if (!widget.store.canWrite) {
      setState(
        () => _err =
            'Saving is off because your data could not be read. Import a backup first.',
      );
      return;
    }
    _saving = true;
    setState(() {});
    try {
      final id = widget.item?['id'];
      if (id is String) {
        await widget.store.updateRecurring(
          id,
          type: _type,
          label: label,
          amount: amount,
          dayOfMonth: day,
          accountId: _accountId,
        );
      } else {
        await widget.store.addRecurring(
          type: _type,
          label: label,
          amount: amount,
          dayOfMonth: day,
          accountId: _accountId,
        );
      }
    } catch (_) {
      // Without this the exception escaped _save, pop() never ran, and
      // _saving was cleared with no setState, leaving the Save button
      // rendered as permanently disabled in a sheet the user could only
      // cancel out of, with no idea whether the bill had been saved.
      if (mounted) {
        setState(() {
          _saving = false;
          _err = 'That did not save. Please try again.';
        });
      }
      return;
    }
    if (mounted) {
      setState(() => _saving = false);
      Navigator.of(context).pop();
    } else {
      _saving = false;
    }
  }

  void _delete() {
    if (!_confirmDel) {
      setState(() => _confirmDel = true);
      return;
    }
    final id = widget.item?['id'];
    if (id is String && widget.store.canWrite) widget.store.deleteRecurring(id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isIncome = _type == 'income';
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Barako.background,
          border: Border.all(color: Barako.border),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: (MediaQuery.of(context).size.height - bottomInset) * 0.92,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit ? 'Edit recurring' : 'New recurring',
                style: TextStyle(
                  color: Barako.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _typeChip('Bill', 'expense'),
                  const SizedBox(width: 8),
                  _typeChip('Income', 'income'),
                ],
              ),
              _label2('Name'),
              _input(_label, hint: 'e.g. Rent, Netflix, Salary'),
              _label2('Amount'),
              _input(_amount, hint: '0', number: true),
              _label2('Day of the month (1 to 31)'),
              _input(_day, hint: 'e.g. 15', digitsOnly: true, maxLen: 2),
              const SizedBox(height: 6),
              Text(
                'Logs on this day. If a month is shorter, it uses the last '
                'day.',
                style: TextStyle(color: Barako.faint, fontSize: 11),
              ),
              if (_accounts.isNotEmpty) ...[
                _label2(
                  isIncome
                      ? 'Into which account? (optional)'
                      : 'From which account? (optional)',
                ),
                _accountPicker(),
              ],
              if (_err != null) ...[
                const SizedBox(height: 12),
                Text(
                  _err!,
                  style: TextStyle(color: Barako.warningStrong, fontSize: 13),
                ),
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
                          disabledBackgroundColor: Barako.primary.withValues(
                            alpha: 0.5,
                          ),
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

  Widget _typeChip(String text, String value) {
    final on = _type == value;
    return Expanded(
      child: Semantics(
        button: true,
        selected: on,
        label: text,
        child: PressableScale(
          child: Material(
            color: on ? Barako.primary : Barako.card,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _type = value);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: on ? Barako.primary : Barako.border,
                  ),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: on ? Barako.onPrimary : Barako.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _accountPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _acctChip('No account', ''),
        for (final a in _accounts)
          _acctChip(
            a['name']?.toString() ?? 'Account',
            a['id']?.toString() ?? '',
          ),
      ],
    );
  }

  Widget _acctChip(String label, String id) {
    final on = _accountId == id;
    return ChoiceChip(
      label: Text(label),
      selected: on,
      onSelected: (_) => setState(() => _accountId = id),
      selectedColor: Barako.primary,
      backgroundColor: Barako.card,
      labelStyle: TextStyle(
        color: on ? Barako.onPrimary : Barako.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: Barako.border),
    );
  }

  Widget _label2(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(text, style: TextStyle(color: Barako.muted, fontSize: 12)),
  );

  Widget _input(
    TextEditingController c, {
    String? hint,
    bool number = false,
    bool digitsOnly = false,
    int? maxLen,
  }) {
    final formatters = <TextInputFormatter>[
      if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
      if (number && !digitsOnly)
        FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
      if (maxLen != null) LengthLimitingTextInputFormatter(maxLen),
    ];
    return TextField(
      controller: c,
      keyboardType: (number || digitsOnly)
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: formatters.isEmpty ? null : formatters,
      style: TextStyle(color: Barako.text, fontSize: 15),
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
