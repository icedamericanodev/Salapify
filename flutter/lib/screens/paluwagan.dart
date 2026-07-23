// Paluwagan: the rotating savings group (ROSCA) that runs on Filipino barkada
// and workplace trust. Everyone pays the same ambag each cycle and one member
// takes the whole pot; over a full round everyone pays in and takes out once,
// so it is interest free and zero sum. The ONLY variable is timing, and nobody
// explains it. This screen tracks each group and gives the honest read: an
// early turn is a 0% loan, a late turn is 0% forced savings. Every peso here
// comes from money/paluwagan.dart, never invented in the widget.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../money/debtmath.dart' show formatMoneyText;
import '../money/paluwagan.dart' as eng;
import '../theme.dart';
import '../widgets/pressable_scale.dart';

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Turn an ISO 'YYYY-MM-DD' into '10 Jul 2026'. Returns the raw string on
/// anything it does not recognize, so a hand-edited value never blanks out.
String _prettyDate(String? iso) {
  if (iso == null || iso.length < 10) return iso ?? '';
  final y = int.tryParse(iso.substring(0, 4));
  final m = int.tryParse(iso.substring(5, 7));
  final d = int.tryParse(iso.substring(8, 10));
  if (y == null || m == null || d == null || m < 1 || m > 12) return iso;
  return '$d ${_months[m - 1]} $y';
}

String _cadenceShort(String cadence) {
  switch (cadence) {
    case 'weekly':
      return 'weekly';
    case 'kinsenas':
      return 'twice a month';
    default:
      return 'monthly';
  }
}

class PaluwaganScreen extends StatelessWidget {
  final SalapifyStore store;
  const PaluwaganScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text('Paluwagan',
            style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: () => _openSheet(context, null),
            child: Text('+ Add',
                style: TextStyle(
                    color: Barako.primaryText, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final items = store.paluwagans;
            final now = DateTime.now();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'A paluwagan is interest free and zero sum. Everyone pays the '
                  'same ambag and takes the pot once. The only thing that '
                  'changes is your turn, so Salapify reads it honestly: an early '
                  'turn is like a 0% loan, a late turn is 0% forced savings.',
                  style: TextStyle(
                      color: Barako.textSecondary, fontSize: 14, height: 1.45),
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  _empty(context)
                else
                  for (final p in items)
                    _PaluwaganCard(
                      status: eng.paluwaganStatus(p, now),
                      onTap: () => _openSheet(context, p),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            Icon(Icons.groups_outlined, color: Barako.faint, size: 40),
            const SizedBox(height: 10),
            Text('No paluwagan yet',
                style: TextStyle(
                    color: Barako.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
                'Add your office or barkada paluwagan to see your payout date '
                'and where you stand.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Barako.muted, fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openSheet(context, null),
              style: FilledButton.styleFrom(
                  backgroundColor: Barako.primary,
                  foregroundColor: Barako.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add your first paluwagan',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  void _openSheet(BuildContext context, Map<String, dynamic>? item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaluwaganSheet(store: store, item: item),
    );
  }
}

class _PaluwaganCard extends StatelessWidget {
  final Map<String, dynamic> status;
  final VoidCallback onTap;
  const _PaluwaganCard({required this.status, required this.onTap});

  double _d(String k) => (status[k] as num?)?.toDouble() ?? 0;
  int _i(String k) => (status[k] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final name = status['name']?.toString() ?? 'Paluwagan';
    final cadence = status['cadence']?.toString() ?? 'monthly';
    final members = _i('members');
    final myTurn = _i('myTurn');
    final currentCycle = _i('currentCycle');
    final payoutAmount = _d('payoutAmount');
    final amount = _d('amount');
    final payoutDate = status['payoutDate'] as String?;
    final received = status['received'] == true;
    final done = status['done'] == true;
    final behind = status['behind'] == true;
    final behindBy = _d('behindBy');
    final cyclesToPayout = _i('cyclesToPayout');
    final dealType = status['dealType']?.toString() ?? 'middle';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PressableScale(
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.groups_outlined,
                          color: Barako.primaryText, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Barako.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 8),
                      _statusPill(done, received, behind, cyclesToPayout),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                      '${formatMoneyText(amount)} ${_cadenceShort(cadence)} · '
                      '$members members · you are turn $myTurn',
                      style: TextStyle(color: Barako.muted, fontSize: 12)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _figure('YOUR PAYOUT', formatMoneyText(payoutAmount),
                          Barako.primaryText),
                      Container(width: 1, height: 32, color: Barako.border),
                      _figure(
                          received ? 'RECEIVED ON' : 'PAYOUT DATE',
                          payoutDate != null ? _prettyDate(payoutDate) : 'n/a',
                          Barako.text),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _progress(currentCycle, members),
                  const SizedBox(height: 10),
                  if (behind && !done)
                    _note(
                        Icons.error_outline,
                        'Behind by ${formatMoneyText(behindBy)}. Catch up your '
                        'ambag so the group stays whole.',
                        Barako.warningStrong)
                  else
                    _dealRead(dealType, done),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusPill(bool done, bool received, bool behind, int cyclesToPayout) {
    String text;
    Color bg;
    Color fg;
    if (done) {
      text = 'Done';
      bg = Barako.card;
      fg = Barako.muted;
    } else if (behind) {
      text = 'Behind';
      bg = Barako.warningStrong.withValues(alpha: 0.14);
      fg = Barako.warningStrong;
    } else if (received) {
      text = 'Received';
      bg = Barako.positiveSurface;
      fg = Barako.primaryText;
    } else {
      text = cyclesToPayout <= 1 ? 'Your turn is near' : '$cyclesToPayout to go';
      bg = Barako.card;
      fg = Barako.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _figure(String label, String value, Color color) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Barako.kickerStyle),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    maxLines: 1,
                    style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            ],
          ),
        ),
      );

  Widget _progress(int currentCycle, int members) {
    final done = currentCycle.clamp(0, members);
    final frac = members > 0 ? done / members : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 6,
            backgroundColor: Barako.border,
            valueColor: AlwaysStoppedAnimation(Barako.primary),
          ),
        ),
        const SizedBox(height: 5),
        Text('Cycle $done of $members',
            style: TextStyle(color: Barako.faint, fontSize: 11)),
      ],
    );
  }

  Widget _dealRead(String dealType, bool done) {
    if (done) {
      return _note(Icons.check_circle_outline,
          'This round is finished. Everyone paid in and took out once.',
          Barako.primaryText);
    }
    switch (dealType) {
      case 'early':
        return _note(
            Icons.trending_up,
            'Early turn: like a 0% loan from the group. You get the pot now '
            'and pay it back over the rest of the round. Set the ambag aside.',
            Barako.primaryText);
      case 'late':
        return _note(
            Icons.savings_outlined,
            'Late turn: 0% forced savings. You pay in first and collect a lump '
            'sum later. Great if you struggle to save on your own.',
            Barako.primaryText);
      default:
        return _note(
            Icons.balance,
            'Middle turn: roughly even, no strong loan or savings tilt.',
            Barako.muted);
    }
  }

  Widget _note(IconData icon, String text, Color color) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style:
                    TextStyle(color: Barako.textSecondary, fontSize: 12.5, height: 1.4)),
          ),
        ],
      );
}

class _PaluwaganSheet extends StatefulWidget {
  final SalapifyStore store;
  final Map<String, dynamic>? item;
  const _PaluwaganSheet({required this.store, this.item});

  @override
  State<_PaluwaganSheet> createState() => _PaluwaganSheetState();
}

class _PaluwaganSheetState extends State<_PaluwaganSheet> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _members;
  late final TextEditingController _myTurn;
  late final TextEditingController _paidCycles;
  late final TextEditingController _note;
  late String _cadence;
  late String _startDate;
  String? _err;
  bool _confirmDel = false;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final p = widget.item;
    _cadence = eng.paluwaganCadences.any((c) => c['key'] == p?['cadence'])
        ? p!['cadence'] as String
        : 'monthly';
    _startDate = (p?['startDate'] is String && (p!['startDate'] as String).isNotEmpty)
        ? p['startDate'] as String
        : _todayISO(DateTime.now());
    _name = TextEditingController(text: p?['name']?.toString() ?? '');
    _amount = TextEditingController(text: p != null ? _numStr(p['amount']) : '');
    _members =
        TextEditingController(text: p != null ? _numStr(p['members']) : '5');
    _myTurn =
        TextEditingController(text: p != null ? _numStr(p['myTurn']) : '1');
    _paidCycles =
        TextEditingController(text: p != null ? _numStr(p['paidCycles']) : '0');
    _note = TextEditingController(text: p?['note']?.toString() ?? '');
  }

  static String _todayISO(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _numStr(dynamic v) {
    if (v is num) {
      return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    }
    return v?.toString() ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _members.dispose();
    _myTurn.dispose();
    _paidCycles.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final parts = _startDate.split('-');
    final initial = parts.length == 3
        ? DateTime(int.tryParse(parts[0]) ?? DateTime.now().year,
            int.tryParse(parts[1]) ?? 1, int.tryParse(parts[2]) ?? 1)
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) setState(() => _startDate = _todayISO(picked));
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _err = 'Give it a name, like Office paluwagan.');
      return;
    }
    final amount =
        double.tryParse(_amount.text.replaceAll(RegExp(r'[, ]'), '')) ?? 0;
    if (!amount.isFinite || amount <= 0) {
      setState(() => _err = 'Enter an ambag amount greater than 0.');
      return;
    }
    final members = int.tryParse(_members.text.trim()) ?? 0;
    if (members < 2 || members > 60) {
      setState(() => _err = 'A paluwagan has 2 to 60 members.');
      return;
    }
    final myTurn = int.tryParse(_myTurn.text.trim()) ?? 0;
    if (myTurn < 1 || myTurn > members) {
      setState(() => _err = 'Your turn should be from 1 to $members.');
      return;
    }
    final paidCycles = int.tryParse(_paidCycles.text.trim()) ?? 0;
    if (paidCycles < 0 || paidCycles > members) {
      setState(() => _err = 'Cycles paid should be from 0 to $members.');
      return;
    }
    if (!widget.store.canWrite) {
      setState(() => _err =
          'Saving is off because your data could not be read. Import a backup first.');
      return;
    }
    _saving = true;
    setState(() {});
    final fields = {
      'name': name,
      'amount': amount,
      'members': members,
      'cadence': _cadence,
      'startDate': _startDate,
      'myTurn': myTurn,
      'paidCycles': paidCycles,
      'note': _note.text.trim(),
    };
    try {
      final id = widget.item?['id'];
      if (id is String) {
        await widget.store.updatePaluwagan(id, fields);
      } else {
        await widget.store.addPaluwagan(fields);
      }
    } finally {
      _saving = false;
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _delete() {
    if (!_confirmDel) {
      setState(() => _confirmDel = true);
      return;
    }
    final id = widget.item?['id'];
    if (id is String && widget.store.canWrite) widget.store.deletePaluwagan(id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Barako.background,
          border: Border.all(color: Barako.border),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
            maxHeight:
                (MediaQuery.of(context).size.height - bottomInset) * 0.92),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEdit ? 'Edit paluwagan' : 'New paluwagan',
                  style: TextStyle(
                      color: Barako.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              _label('Name'),
              _input(_name, hint: 'e.g. Office paluwagan'),
              _label('Ambag per cycle'),
              _input(_amount, hint: '0', number: true),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Members'),
                        _input(_members,
                            hint: '5', digitsOnly: true, maxLen: 2),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Your turn'),
                        _input(_myTurn,
                            hint: '1', digitsOnly: true, maxLen: 2),
                      ],
                    ),
                  ),
                ],
              ),
              _label('How often is the draw?'),
              Row(
                children: [
                  for (final c in eng.paluwaganCadences) ...[
                    _cadenceChip(c['label']!, c['key']!),
                    if (c != eng.paluwaganCadences.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
              _label('Start date (first draw)'),
              _dateField(),
              _label('Cycles you have already paid'),
              _input(_paidCycles, hint: '0', digitsOnly: true, maxLen: 2),
              const SizedBox(height: 6),
              Text(
                  'This is how many ambag you have put in so far. It tells you '
                  'if you are behind.',
                  style: TextStyle(color: Barako.faint, fontSize: 11)),
              _label('Note (optional)'),
              _input(_note, hint: 'e.g. Kada 15 ng buwan'),
              if (_err != null) ...[
                const SizedBox(height: 12),
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
                          disabledBackgroundColor:
                              Barako.primary.withValues(alpha: 0.5),
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

  Widget _cadenceChip(String text, String value) {
    final on = _cadence == value;
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
                setState(() => _cadence = value);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: on ? Barako.primary : Barako.border),
                ),
                child: Text(
                    value == 'kinsenas' ? 'Kinsenas' : text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: on ? Barako.onPrimary : Barako.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateField() => PressableScale(
        child: Material(
          color: Barako.card,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickStartDate,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Barako.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 16, color: Barako.muted),
                  const SizedBox(width: 10),
                  Text(_prettyDate(_startDate),
                      style: TextStyle(color: Barako.text, fontSize: 15)),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text, style: TextStyle(color: Barako.muted, fontSize: 12)),
      );

  Widget _input(TextEditingController c,
      {String? hint,
      bool number = false,
      bool digitsOnly = false,
      int? maxLen}) {
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
