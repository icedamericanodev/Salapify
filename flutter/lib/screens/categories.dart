// Categories: name them, nest them one level, give them a monthly cap (Pro),
// and delete one without losing the history attached to it.
//
// Ported from mobile/app/categories.js. The delete flow is the part that
// matters and it is the founder's decision made visible: deleting a category
// asks where its entries should go, shows how many there are, and only clears
// their tag if that is explicitly chosen. Nothing is ever dropped quietly.
//
// Every reshape of the data belongs to money/categories.dart, which is golden
// locked to the RN helpers. This screen picks the ids and shows the counts.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/categories.dart';
import '../money/debtmath.dart' show formatMoneyText;
import '../money/ledger.dart' show amountOf;
import '../theme.dart';
import '../widgets/section.dart';

class CategoriesScreen extends StatelessWidget {
  final SalapifyStore store;
  const CategoriesScreen({super.key, required this.store});

  bool get _pro => (store.data['settings'] as Map?)?['pro'] == true;

  List<Map<String, dynamic>> get _categories => [
    for (final c in (store.data['categories'] as List? ?? const []))
      if (c is Map) c.cast<String, dynamic>(),
  ];

  /// This month's spend per category id, so a cap can say whether it is being
  /// kept. Only expenses count: income tagged with a category is not spending.
  Map<dynamic, double> _spentThisMonth(DateTime now) {
    final prefix =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}';
    final out = <dynamic, double>{};
    for (final t in (store.data['transactions'] as List? ?? const [])) {
      if (t is! Map) continue;
      if (t['type'] != 'expense') continue;
      final date = t['date'];
      if (date is! String || !date.startsWith(prefix)) continue;
      final id = t['categoryId'];
      if (id == null) continue;
      out[id] = (out[id] ?? 0) + amountOf(t['amount']);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Categories',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final rows = categoryTree(_categories);
            final spent = _spentThisMonth(DateTime.now());
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'Categories keep your entries consistent. A monthly cap '
                  'gives one area its own limit, so Food can run out before '
                  'the whole budget does.',
                  style: TextStyle(
                    color: Barako.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: Gap.lg),
                if (store.canWrite)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _openForm(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Barako.primaryText,
                        side: BorderSide(color: Barako.primary),
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text(
                        '+ New category',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                const SizedBox(height: Gap.lg),
                Kicker('YOUR CATEGORIES'),
                const SizedBox(height: 8),
                if (rows.isEmpty)
                  Text(
                    'No categories yet.',
                    style: TextStyle(color: Barako.faint, fontSize: 13),
                  ),
                for (final row in rows)
                  _row(context, row, spent[row.cat['id']] ?? 0),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, CategoryRow row, double spent) {
    final cap = amountOf(row.cat['monthlyCap']);
    final over = cap > 0 && spent > cap;
    final name = '${row.cat['name'] ?? 'Category'}';
    return Padding(
      padding: EdgeInsets.only(left: row.depth == 1 ? 20 : 0, bottom: 8),
      child: Material(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: store.canWrite
              ? () => _openForm(context, item: row.cat)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Text(
                  '${row.cat['icon'] ?? '🏷️'}',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: Barako.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(spent, cap, over),
                        style: TextStyle(
                          color: over ? Barako.warningStrong : Barako.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Barako.faint, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(double spent, double cap, bool over) {
    final spentText = '${formatMoneyText(spent)} this month';
    if (cap <= 0) return spentText;
    final capText = '$spentText of ${formatMoneyText(cap)} cap';
    return over ? '$capText. Over the cap.' : capText;
  }

  void _openForm(BuildContext context, {Map<String, dynamic>? item}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryForm(store: store, item: item, pro: _pro),
    );
  }
}

/// Add or edit one category, and start the delete flow.
class _CategoryForm extends StatefulWidget {
  final SalapifyStore store;
  final Map<String, dynamic>? item;
  final bool pro;
  const _CategoryForm({required this.store, this.item, required this.pro});

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  late final _name = TextEditingController(
    text: '${widget.item?['name'] ?? ''}',
  );
  late final _icon = TextEditingController(
    text: '${widget.item?['icon'] ?? ''}',
  );
  late final _cap = TextEditingController(text: _initialCap());
  late String? _parentId = _initialParent();
  bool _saving = false;
  String? _err;

  bool get _isEdit => widget.item != null;

  String _initialCap() {
    final v = amountOf(widget.item?['monthlyCap']);
    if (v <= 0) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  String? _initialParent() {
    final p = widget.item?['parentId'];
    return p is String && p.isNotEmpty ? p : null;
  }

  List<Map<String, dynamic>> get _all => [
    for (final c in (widget.store.data['categories'] as List? ?? const []))
      if (c is Map) c.cast<String, dynamic>(),
  ];

  /// The categories this one may sit under: top level only (the tree is two
  /// deep by design), never itself, and never one of its own children.
  List<Map<String, dynamic>> get _parentOptions {
    final id = widget.item?['id'];
    return [
      for (final c in _all)
        if (c['id'] != id &&
            c['parentId'] == null &&
            !_all.any((x) => x['id'] == c['id'] && x['parentId'] == id))
          c,
    ];
  }

  @override
  void dispose() {
    _name.dispose();
    _icon.dispose();
    _cap.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _err = null;
    });
    String? error;
    try {
      error = await widget.store.saveCategory(
        id: widget.item?['id'] as String?,
        name: _name.text,
        icon: _icon.text,
        capText: _cap.text,
        parentId: _parentId,
      );
    } catch (e) {
      error = 'Could not save, nothing was changed. $e';
    }
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _err = error;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  void _startDelete() {
    final item = widget.item!;
    Navigator.of(context).pop();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeleteCategorySheet(store: widget.store, item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                _isEdit ? 'Edit category' : 'New category',
                style: TextStyle(
                  color: Barako.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _label('Name'),
              _field(_name, hint: 'Food'),
              _label('Icon'),
              _field(_icon, hint: '🍚'),
              _label('Sits under (optional)'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Top level'),
                    selected: _parentId == null,
                    onSelected: (_) => setState(() => _parentId = null),
                    selectedColor: Barako.primary,
                    backgroundColor: Barako.card,
                    labelStyle: TextStyle(
                      color: _parentId == null
                          ? Barako.onPrimary
                          : Barako.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: Barako.border),
                  ),
                  for (final c in _parentOptions)
                    ChoiceChip(
                      label: Text('${c['name']}'),
                      selected: _parentId == c['id'],
                      onSelected: (_) =>
                          setState(() => _parentId = '${c['id']}'),
                      selectedColor: Barako.primary,
                      backgroundColor: Barako.card,
                      labelStyle: TextStyle(
                        color: _parentId == c['id']
                            ? Barako.onPrimary
                            : Barako.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(color: Barako.border),
                    ),
                ],
              ),
              _label(
                widget.pro ? 'Monthly cap (optional)' : 'Monthly cap (Pro)',
              ),
              _field(
                _cap,
                hint: widget.pro ? 'e.g. 3000, empty for none' : 'Pro feature',
                number: true,
              ),
              if (!widget.pro)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Caps are part of Pro, free during early access. Unlock '
                    'it in Menu and this field starts working.',
                    style: TextStyle(color: Barako.muted, fontSize: 12),
                  ),
                ),
              if (_err != null) ...[
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _err!,
                    style: TextStyle(color: Barako.warningStrong, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_isEdit)
                    TextButton(
                      onPressed: _saving ? null : _startDelete,
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Barako.warningStrong),
                      ),
                    ),
                  const Spacer(),
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
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(t, style: TextStyle(color: Barako.muted, fontSize: 12)),
  );

  Widget _field(
    TextEditingController c, {
    required String hint,
    bool number = false,
  }) => TextField(
    controller: c,
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    style: TextStyle(color: Barako.text, fontSize: 16),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Barako.faint),
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
  );
}

/// Where should this category's entries go?
///
/// The founder's rule, made into a screen: the count is shown before anything
/// happens, moving is the default, and untagging is a deliberate second
/// choice rather than what happens when you do not read carefully.
class _DeleteCategorySheet extends StatefulWidget {
  final SalapifyStore store;
  final Map<String, dynamic> item;
  const _DeleteCategorySheet({required this.store, required this.item});

  @override
  State<_DeleteCategorySheet> createState() => _DeleteCategorySheetState();
}

class _DeleteCategorySheetState extends State<_DeleteCategorySheet> {
  /// Starts on a REAL category, not on "No category".
  ///
  /// The render caught this: the sheet opened with "No category" selected, so
  /// the default outcome of tapping Delete was untagging every entry. That is
  /// the exact opposite of the rule this screen exists to honour. Moving is
  /// the default; dropping the tag is the deliberate second choice, and now
  /// the highlighted chip says so before anything is read.
  late String? _toId = _others.isEmpty ? null : '${_others.first['id']}';
  bool _saving = false;
  String? _err;

  List<Map<String, dynamic>> get _others => [
    for (final c in (widget.store.data['categories'] as List? ?? const []))
      if (c is Map && c['id'] != widget.item['id']) c.cast<String, dynamic>(),
  ];

  int get _used =>
      taggedCount(widget.store.data['transactions'], widget.item['id']);

  Future<void> _delete() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      await widget.store.deleteCategory('${widget.item['id']}', _toId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _err = 'Could not delete it, nothing was changed. $e';
      });
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final used = _used;
    final name = '${widget.item['name'] ?? 'this category'}';
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete $name',
                style: TextStyle(
                  color: Barako.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                used == 0
                    ? 'Nothing is tagged with this category, so deleting it '
                          'changes no entries.'
                    : used == 1
                    ? '1 entry is tagged with this category. Your entries are '
                          'never deleted; pick where this one should go.'
                    : '$used entries are tagged with this category. Your '
                          'entries are never deleted; pick where they should '
                          'go.',
                style: TextStyle(
                  color: Barako.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (used > 0) ...[
                const SizedBox(height: Gap.md),
                Text('Move them to', style: Barako.cardKickerStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in _others)
                      ChoiceChip(
                        label: Text('${c['icon'] ?? ''} ${c['name']}'.trim()),
                        selected: _toId == c['id'],
                        onSelected: (_) => setState(() => _toId = '${c['id']}'),
                        selectedColor: Barako.primary,
                        backgroundColor: Barako.card,
                        labelStyle: TextStyle(
                          color: _toId == c['id']
                              ? Barako.onPrimary
                              : Barako.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(color: Barako.border),
                      ),
                    ChoiceChip(
                      label: const Text('No category'),
                      selected: _toId == null,
                      onSelected: (_) => setState(() => _toId = null),
                      selectedColor: Barako.primary,
                      backgroundColor: Barako.card,
                      labelStyle: TextStyle(
                        color: _toId == null
                            ? Barako.onPrimary
                            : Barako.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(color: Barako.border),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _toId == null
                      ? 'They stay in your history with no category, and you '
                            'can tag them again any time.'
                      : 'They keep every peso and every date. Only the '
                            'category label changes.',
                  style: TextStyle(color: Barako.muted, fontSize: 12),
                ),
              ],
              if (_err != null) ...[
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _err!,
                    style: TextStyle(color: Barako.warningStrong, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
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
                    onPressed: _saving ? null : _delete,
                    style: FilledButton.styleFrom(
                      backgroundColor: Barako.warningStrong,
                      foregroundColor: Barako.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                    child: const Text(
                      'Delete category',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
