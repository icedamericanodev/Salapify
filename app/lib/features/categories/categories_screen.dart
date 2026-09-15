// The categories screen: add one, rename one, change its emoji, retire one.
//
// The gap it closes is bigger than it looks. Every screen in this app READ
// `data['categories']` and nothing could write one, so a person had the eight
// the app shipped and no others, forever. Somebody who spends on tuition, or
// on a motorcycle loan, or on their parents, had nowhere to put it and their
// whole Insights breakdown said "Uncategorised".
//
// WHAT THIS SCREEN DELIBERATELY CANNOT DO is delete a category that entries
// point at. A recovery pass traced every reader and the finding was not that
// money disappears (it does not: Insights buckets an unknown tag as
// Uncategorised and the budget hero sums expenses whatever they carry), but
// that ATTRIBUTION disappears with no way back, and that re-creating the
// category mints a new id which the auto-tagger's keyword table will never
// match again. So a used category is HIDDEN, and the un-hide control sits
// permanently in the same list, which is a better undo than any card because
// it cannot expire.
import 'package:flutter/material.dart';

import '../../app/ledger_scope.dart';
import '../../core/money/ledger.dart' show amountOf;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'category_rows.dart';

const String categoriesRoutePath = '/categories';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final data = context.ledger.data;
    final all = allCategories(data);
    final live = [
      for (final c in all)
        if (!isArchivedCategory(c)) c,
    ];
    final hidden = [
      for (final c in all)
        if (isArchivedCategory(c)) c,
    ];

    return Scaffold(
      backgroundColor: skin.bg,
      body: Screen(
        children: [
          const BackBar(),
          const SizedBox(height: 6),
          const ScreenTitle(
            title: 'Categories',
            sub: 'How Salapify tells food money from fare money.',
          ),
          const SizedBox(height: 20),

          // THE ADD CONTROL IS OUTSIDE EVERY EMPTINESS CHECK, and that is not a
          // stylistic preference. Accounts shipped a bug where hiding your only
          // account hit an empty-state early return that swallowed the route to
          // Settings and the backup behind it. Zero categories is a real and
          // PERMANENT state here: `_migration4` refills the defaults only below
          // schemaVersion 4 and a live ledger is at 12, so an empty list stays
          // empty and nothing anywhere puts them back. If the only way to add
          // one lived inside the list, that state would be a locked door.
          if (live.isEmpty) ...[
            const EmptyState(
              icon: Icons.sell_outlined,
              title: 'No categories yet',
              body:
                  'Categories are how the app tells food money from fare '
                  'money. Add one and it shows up the next time you log '
                  'something.',
            ),
            const SizedBox(height: 14),
          ] else ...[
            const Head(title: 'Yours'),
            const SizedBox(height: 8),
            Group(
              children: [
                for (final c in live) _CategoryRow(cat: c, hidden: false),
              ],
            ),
            const SizedBox(height: 16),
          ],

          PillButton(
            label: 'Add a category',
            icon: Icons.add_rounded,
            onTap: () => showCategoryEditor(context),
          ),

          if (hidden.isNotEmpty) ...[
            const SizedBox(height: 26),
            const Head(title: 'Hidden'),
            const SizedBox(height: 6),
            Text(
              // SAYS WHAT HIDDEN MEANS, because the honest answer is not
              // obvious and the wrong guess is the dangerous one. Somebody who
              // thinks hiding removed the spending will go looking for a figure
              // that moved, and it did not.
              'These stay on every entry and every report that already uses '
              'them. They are only kept out of the list you pick from when '
              'you log something.',
              style: TypeScale.caption(skin.text3),
            ),
            const SizedBox(height: 8),
            Group(
              children: [
                for (final c in hidden) _CategoryRow(cat: c, hidden: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.cat, required this.hidden});
  final Map<String, dynamic> cat;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final data = context.ledger.data;
    return ItemRow(
      // The EMOJI the user picked, drawn as a monogram. Salapify's own icons
      // are Material glyphs in the accent and this is deliberately not one of
      // those: a category icon is user data, it lives in the backup file, and
      // replacing it would overwrite a choice that was never ours.
      monogram: (cat['icon'] ?? '').toString(),
      title: (cat['name'] ?? '').toString(),
      sub: categoryCaption(data, cat),
      amount: hidden ? 'Hidden' : '',
      onTap: () => showCategoryEditor(context, existing: cat),
    );
  }
}

/// Add or change one category.
Future<void> showCategoryEditor(
  BuildContext context, {
  Map<String, dynamic>? existing,
}) async {
  final store = context.ledger;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    // Or it lands under the nav bar. And every context INSIDE the builder is
    // the sheet's own: popping the caller's context here would take the screen
    // underneath with it, which is exactly the black screen the projection
    // help sheet shipped with.
    useRootNavigator: true,
    builder: (sheetContext) => LedgerScope(
      store: store,
      child: _CategorySheet(existing: existing),
    ),
  );
}

/// A small, deliberately short set. A grid of six hundred emoji is a worse
/// experience than eighteen good ones, and every one of these is a thing
/// Filipino users actually spend on.
const _icons = [
  '🍜',
  '🚌',
  '📱',
  '💡',
  '🛒',
  '🎉',
  '💸',
  '💊',
  '🏠',
  '🎓',
  '👕',
  '⛽',
  '🐶',
  '✂️',
  '🎁',
  '☕',
  '🏦',
  '🙏',
];

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final _name = TextEditingController(
    text: (widget.existing?['name'] ?? '').toString(),
  );
  late String _icon = (widget.existing?['icon'] ?? _icons.first).toString();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final data = context.ledger.data;
    final cat = widget.existing;
    final archived = isArchivedCategory(cat);

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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    _isEdit ? 'Edit category' : 'New category',
                    style: TypeScale.sheetTitle(skin.text),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TypeScale.action(skin.text2)),
                ),
              ],
            ),
            const SizedBox(height: 18),

            Text('Name', style: TypeScale.fieldLabel(skin.text2)),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
              style: TypeScale.rowTitle(skin.text),
              decoration: InputDecoration(
                hintText: 'Tuition, Pets, Gym',
                hintStyle: TypeScale.rowTitle(skin.text3),
                filled: true,
                fillColor: skin.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),

            // RENAMING IS SAFE AND NEEDS NO CEREMONY, which is worth stating
            // because it is not obvious. Entries reference a category by ID,
            // and the auto-tagger's keyword table maps typed words to the
            // eight default IDS rather than to names, so renaming Food to Kain
            // keeps every entry and every typed shortcut working.
            //
            // DELETING AND RE-CREATING IS NOT RENAMING, and that trap is worth
            // one sentence on the form rather than a lesson learned later.
            if (!_isEdit) ...[
              const SizedBox(height: 8),
              Text(
                'Salapify already recognises words like jollibee, grab and '
                'meralco for the categories it started you with. A new one is '
                'yours to tag by hand.',
                style: TypeScale.caption(skin.text3),
              ),
            ],

            const SizedBox(height: 18),
            Text('Icon', style: TypeScale.fieldLabel(skin.text2)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _icons)
                  PickChip(
                    label: e,
                    on: _icon == e,
                    onTap: () => setState(() => _icon = e),
                  ),
              ],
            ),

            const SizedBox(height: 22),
            PillButton(
              label: _busy ? 'Saving' : 'Save',
              onTap: _name.text.trim().isEmpty || _busy ? null : _save,
            ),

            if (_isEdit) ...[
              const SizedBox(height: 10),
              PillButton(
                secondary: true,
                label: archived
                    ? 'Bring it back'
                    : (canRemove(data, cat!) ? 'Remove it' : 'Hide it'),
                onTap: _busy
                    ? null
                    : () => archived
                          ? _setArchived(false)
                          : (canRemove(data, cat!)
                                ? _confirmRemove()
                                : _confirmHide()),
              ),
              const SizedBox(height: 8),
              Text(
                archived
                    ? 'It goes back into the list you pick from when you log '
                          'something.'
                    : canRemove(data, cat!)
                    ? 'Nothing is tagged with this one yet, so it can go '
                          'completely.'
                    : 'Hiding keeps every entry exactly as it is.',
                style: TypeScale.caption(skin.text3),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final name = _name.text.trim();
    final icon = _icon;
    final existing = widget.existing;
    try {
      await context.ledger.mutate((draft) {
        final list = [
          for (final c
              in (draft['categories'] is List
                  ? draft['categories'] as List
                  : const []))
            if (c is Map) c.cast<String, dynamic>(),
        ];
        if (existing == null) {
          list.add({
            'id': 'cat_${DateTime.now().microsecondsSinceEpoch}',
            'name': name,
            'icon': icon,
            'monthlyCap': 0,
          });
        } else {
          for (var i = 0; i < list.length; i++) {
            if (list[i]['id'] != existing['id']) continue;
            // SPREAD, never rebuild. A category can carry `parentId` and
            // `monthlyCap`, which this form does not edit, and rebuilding it
            // from two text fields would silently drop a sub-category
            // relationship and somebody's budget limit on a rename.
            list[i] = {...list[i], 'name': name, 'icon': icon};
          }
        }
        draft['categories'] = list;
      });
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The removal confirmation, which the first version did not have.
  ///
  /// Hide asked and Remove did not, which was exactly backwards: hiding has an
  /// un-hide control sitting permanently in the same list, and removal has no
  /// way back at all. A QA pass found the more destructive path was the one
  /// with no dialog on it.
  Future<void> _confirmRemove() async {
    final ok = await _ask(
      title: 'Remove ${widget.existing!['name']}?',
      body: removeConsequence(widget.existing!),
      confirm: 'Remove it',
    );
    if (ok == true) await _remove();
  }

  Future<void> _confirmHide() async {
    final cat = widget.existing!;
    final ok = await _ask(
      title: 'Hide ${cat['name']}?',
      body: hideConsequence(context.ledger.data, cat),
      confirm: 'Hide it',
    );
    if (ok == true) await _setArchived(true);
  }

  /// One dialog shape for both, so the two can never drift into saying the same
  /// kind of thing two different ways.
  Future<bool?> _ask({
    required String title,
    required String body,
    required String confirm,
  }) {
    final skin = context.skin;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: skin.card,
        title: Text(title, style: TypeScale.sheetTitle(skin.text)),
        content: Text(body, style: TypeScale.caption(skin.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Keep it', style: TypeScale.action(skin.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirm, style: TypeScale.action(skin.accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _setArchived(bool on) async {
    setState(() => _busy = true);
    final id = widget.existing!['id'];
    try {
      await context.ledger.mutate((draft) {
        final list = [
          for (final c
              in (draft['categories'] is List
                  ? draft['categories'] as List
                  : const []))
            if (c is Map) c.cast<String, dynamic>(),
        ];
        for (var i = 0; i < list.length; i++) {
          if (list[i]['id'] != id) continue;
          if (on) {
            // THE CAP GOES IN THE SAME WRITE. `budgetRows` emits a row for any
            // category with a cap above zero, and the editor that sets caps
            // only lists categories you can pick. Hiding one while its cap
            // stands leaves a capped row on Plan that no control in the app
            // can reach, which is a number the user can never change again.
            list[i] = {...list[i], 'isArchived': true, 'monthlyCap': 0};
          } else {
            // Absence IS the default, the same rule the account flags follow,
            // so un-hiding REMOVES the key rather than writing false. A backup
            // then carries exactly what it carried before the flag existed.
            list[i] = {...list[i]}..remove('isArchived');
          }
        }
        draft['categories'] = list;
      });
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Only reachable when nothing is tagged with it, by the button above.
  Future<void> _remove() async {
    setState(() => _busy = true);
    final id = widget.existing!['id'];
    try {
      await context.ledger.mutate((draft) {
        final list = (draft['categories'] is List
            ? draft['categories'] as List
            : const []);
        draft['categories'] = [
          for (final c in list)
            if (!(c is Map && c['id'] == id)) c,
        ];
      });
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// The sentence Settings shows under the row that opens this screen.
String categoriesSummary(Map<String, dynamic> data) {
  final all = allCategories(data);
  final hidden = all.where(isArchivedCategory).length;
  final live = all.length - hidden;
  final capped = all.where((c) => amountOf(c['monthlyCap']) > 0).length;
  if (all.isEmpty) return 'None yet';
  final bits = <String>[
    live == 1 ? '1 category' : '$live categories',
    if (capped > 0) '$capped with a limit',
    if (hidden > 0) '$hidden hidden',
  ];
  return bits.join(', ');
}
